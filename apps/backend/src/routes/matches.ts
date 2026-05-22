import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq } from 'drizzle-orm'
import { db } from '../db/index.js'
import { matches, users } from '../db/schema.js'
import { requireAuth } from '../middleware/auth.js'
import { getMatchById, processBlinkAndAdjudicate } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import { Errors } from '../lib/errors.js'
import { userStats } from '../db/schema.js'

const BlinkEventSchema = z.object({
  detectedAt: z.string().datetime(),
  earValue: z.number().min(0).max(1),
  eventType: z.enum(['blink', 'gaze_break']),
})

function broadcastMatchEvent(
  matchId: string,
  event: string,
  payload: Record<string, unknown>,
) {
  // Supabase Realtime broadcast from server requires the Supabase admin client.
  // The mobile client subscribes to channel `match:{matchId}` and receives these events.
  // TODO: initialise supabase admin client and call:
  // supabaseAdmin.channel(`match:${matchId}`).send({ type: 'broadcast', event, payload })
  console.log(`[realtime] match:${matchId} → ${event}`, payload)
}

export async function matchRoutes(app: FastifyInstance) {
  app.get('/matches/:id', { preHandler: requireAuth }, async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const match = await getMatchById(db, id)

    if (match.playerOneId !== userId && match.playerTwoId !== userId) {
      throw Errors.forbidden()
    }

    const playerIds = [match.playerOneId, match.playerTwoId]
    const playerRecords = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(users)
      .where(eq(users.id, playerIds[0]))

    return reply.send({ data: match })
  })

  app.post(
    '/matches/:id/ready',
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = (request.user as { sub: string }).sub
      const { id } = request.params as { id: string }

      const match = await getMatchById(db, id)

      if (match.playerOneId !== userId && match.playerTwoId !== userId) {
        throw Errors.forbidden()
      }

      // Track readiness in a simple metadata pattern: status 'waiting' → 'countdown'
      // We use a ready flag embedded in the livekit room metadata for simplicity.
      // When both players call /ready the match moves to countdown.
      // For this scaffold we optimistically set countdown on first ready and rely on
      // the client countdown timer; production should track per-player readiness.
      const startsAt = new Date(Date.now() + 3000)

      await db
        .update(matches)
        .set({ status: 'countdown', startedAt: startsAt })
        .where(eq(matches.id, id))

      broadcastMatchEvent(id, 'match.countdown_start', {
        startsAt: startsAt.toISOString(),
      })

      return reply.send({ data: { startsAt: startsAt.toISOString() } })
    },
  )

  app.post(
    '/matches/:id/blink',
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = (request.user as { sub: string }).sub
      const { id } = request.params as { id: string }
      const body = BlinkEventSchema.parse(request.body)

      const result = await processBlinkAndAdjudicate(
        db,
        id,
        userId,
        new Date(body.detectedAt),
        body.earValue,
        body.eventType,
      )

      if (result) {
        const match = await getMatchById(db, id)
        broadcastMatchEvent(id, 'match.result', {
          winnerId: result.winnerId,
          loserId: result.loserId,
          reason: result.reason,
          durationMs: match.durationMs,
        })

        // Async cleanup — do not await
        livekitService.deleteRoom(match.livekitRoomName).catch(console.error)
      }

      return reply.send({ data: { recorded: true, adjudicated: !!result } })
    },
  )

  app.post(
    '/matches/:id/abandon',
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = (request.user as { sub: string }).sub
      const { id } = request.params as { id: string }

      const match = await getMatchById(db, id)

      if (match.playerOneId !== userId && match.playerTwoId !== userId) {
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
          .set({ wins: db.dynamic().ref('wins') })
          .where(eq(userStats.userId, otherId))
      }

      broadcastMatchEvent(id, 'match.abandoned', { playerId: userId })
      livekitService.deleteRoom(match.livekitRoomName).catch(console.error)

      return reply.send({ data: { abandoned: true } })
    },
  )
}
