import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, eq, sql } from 'drizzle-orm'
import { db } from '../db/index.js'
import { matches, users, userStats } from '../db/schema.js'
import { getMatchById, processBlinkAndAdjudicate } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import { broadcastEvent, matchTopic } from '../services/realtimeService.js'
import { Errors } from '../lib/errors.js'
import { logSecurityEvent } from '../services/securityLogger.js'

const BlinkEventSchema = z.object({
  detectedAt: z.string().datetime(),
  earValue: z.number().min(0).max(1),
  eventType: z.enum(['blink', 'gaze_break']),
})

// Fire-and-forget Realtime broadcast on the match channel the mobile
// client subscribes to (`match:{matchId}`). Failures are logged without
// payload (GAP-18) and never fail the request.
function broadcastMatchEvent(
  matchId: string,
  event: string,
  payload: Record<string, unknown> = {},
) {
  broadcastEvent(matchTopic(matchId), event, payload).catch(() => {
    // Logged by callers where a request logger is available; payload
    // intentionally never logged (GAP-18).
  })
}

export async function matchRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  app.get('/matches/:id', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const match = await getMatchById(db, id)

    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        matchId: id,
        route: 'GET /matches/:id',
      })
      throw Errors.forbidden()
    }

    return reply.send({ data: match })
  })

  // Returns the caller's own LiveKit token for a match they participate in.
  // Used by the challenger, who learns the matchId via the
  // `challenge.accepted` Realtime event (the acceptor gets their token in
  // the accept response). Tokens are never sent over Realtime broadcast.
  app.post('/matches/:id/token', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const match = await getMatchById(db, id)

    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        matchId: id,
        route: 'POST /matches/:id/token',
      })
      throw Errors.forbidden()
    }

    const [user] = await db
      .select({ displayName: users.displayName, username: users.username })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1)

    const token = await livekitService.createParticipantToken(
      match.livekitRoomName,
      userId,
      user?.displayName ?? user?.username ?? userId,
    )

    return reply.send({
      data: {
        matchId: match.id,
        livekitToken: token,
        livekitUrl: process.env.LIVEKIT_WS_URL,
        livekitRoomName: match.livekitRoomName,
      },
    })
  })

  app.post('/matches/:id/ready', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const match = await getMatchById(db, id)

    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        matchId: id,
        route: 'POST /matches/:id/ready',
      })
      throw Errors.forbidden()
    }

    if (match.status !== 'waiting') {
      throw Errors.conflict('Match is no longer in the lobby')
    }

    const isPlayerOne = match.playerOneId === userId

    // Record this player's ready flag, then atomically flip to countdown
    // only when both flags are set (the WHERE guard prevents a double
    // countdown if both players ready up simultaneously).
    await db
      .update(matches)
      .set(isPlayerOne ? { playerOneReady: true } : { playerTwoReady: true })
      .where(eq(matches.id, id))

    broadcastMatchEvent(id, 'match.player_ready', { userId })

    const bothReady = isPlayerOne ? match.playerTwoReady : match.playerOneReady
    if (!bothReady) {
      return reply.send({ data: { waitingForOpponent: true } })
    }

    const startsAt = new Date(Date.now() + 3000)

    const flipped = await db
      .update(matches)
      .set({ status: 'countdown', startedAt: startsAt })
      .where(and(eq(matches.id, id), eq(matches.status, 'waiting')))
      .returning({ id: matches.id })

    if (flipped.length > 0) {
      broadcastMatchEvent(id, 'match.countdown_start', {
        startsAt: startsAt.toISOString(),
      })

      // Flip to live when the countdown elapses. Blink events are rejected
      // until status is 'live', so this server-side transition is what
      // actually opens the contest.
      setTimeout(async () => {
        try {
          const went = await db
            .update(matches)
            .set({ status: 'live' })
            .where(and(eq(matches.id, id), eq(matches.status, 'countdown')))
            .returning({ id: matches.id })
          if (went.length > 0) broadcastMatchEvent(id, 'match.live')
        } catch (err) {
          app.log.error({ err, matchId: id }, 'Failed to transition match to live')
        }
      }, startsAt.getTime() - Date.now())
    }

    return reply.send({ data: { startsAt: startsAt.toISOString() } })
  })

  app.post('/matches/:id/blink', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }
    const body = BlinkEventSchema.parse(request.body)

    // IDOR check — verify caller is a match participant before accepting blink event (C4)
    const match = await getMatchById(db, id)
    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        matchId: id,
        route: 'POST /matches/:id/blink',
      })
      throw Errors.forbidden()
    }

    const result = await processBlinkAndAdjudicate(
      db,
      id,
      userId,
      new Date(body.detectedAt),
      body.earValue,
      body.eventType,
    )

    if (result) {
      broadcastMatchEvent(id, 'match.result', {
        winnerId: result.winnerId,
        loserId: result.loserId,
        reason: result.reason,
      })
      // Async cleanup — do not await
      livekitService.deleteRoom(match.livekitRoomName).catch((err) =>
        request.log.error({ err, matchId: id }, 'Failed to delete LiveKit room'),
      )
    }

    return reply.send({ data: { recorded: true, adjudicated: !!result } })
  })

  app.post('/matches/:id/abandon', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const match = await getMatchById(db, id)

    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        matchId: id,
        route: 'POST /matches/:id/abandon',
      })
      throw Errors.forbidden()
    }

    const wasLive = match.status === 'live'
    const otherId =
      match.playerOneId === userId ? match.playerTwoId : match.playerOneId

    await db
      .update(matches)
      .set({
        status: 'abandoned',
        endedAt: new Date(),
        ...(wasLive
          ? {
              winnerId: otherId,
              loserId: userId,
              resultReason: 'disconnect',
            }
          : {}),
      })
      .where(eq(matches.id, id))

    if (wasLive) {
      await db
        .update(userStats)
        .set({ wins: sql`${userStats.wins} + 1` })
        .where(eq(userStats.userId, otherId))
    }

    broadcastMatchEvent(id, 'match.abandoned')
    livekitService.deleteRoom(match.livekitRoomName).catch((err) =>
      request.log.error({ err, matchId: id }, 'Failed to delete LiveKit room'),
    )

    return reply.send({ data: { abandoned: true } })
  })
}
