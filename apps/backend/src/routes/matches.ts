import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, sql } from 'drizzle-orm'
import { db } from '../db/index.js'
import { matches, users, userStats } from '../db/schema.js'
import { getMatchById, processBlinkAndAdjudicate } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import { Errors } from '../lib/errors.js'
import { logSecurityEvent } from '../services/securityLogger.js'

const BlinkEventSchema = z.object({
  detectedAt: z.string().datetime(),
  earValue: z.number().min(0).max(1),
  eventType: z.enum(['blink', 'gaze_break']),
})

function broadcastMatchEvent(
  matchId: string,
  event: string,
) {
  // Supabase Realtime broadcast from server requires the Supabase admin client.
  // The mobile client subscribes to channel `match:{matchId}:{userId}` (GAP-10).
  // TODO: initialise supabase admin client and call:
  // supabaseAdmin.channel(`match:${matchId}:${userId}`).send({ type: 'broadcast', event })
  // Do NOT log payload — it may contain match state (GAP-18)
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

    const startsAt = new Date(Date.now() + 3000)

    await db
      .update(matches)
      .set({ status: 'countdown', startedAt: startsAt })
      .where(eq(matches.id, id))

    broadcastMatchEvent(id, 'match.countdown_start')

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
      broadcastMatchEvent(id, 'match.result')
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
