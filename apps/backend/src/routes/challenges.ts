import type { FastifyInstance } from 'fastify'
import { eq } from 'drizzle-orm'
import { db } from '../db/index.js'
import { challenges, matches, users } from '../db/schema.js'
import { requireAuth } from '../middleware/auth.js'
import { createChallenge, getChallengeByCode } from '../services/challengeService.js'
import { createMatch } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import { Errors } from '../lib/errors.js'

const DEEP_LINK_SCHEME = process.env.DEEP_LINK_SCHEME ?? 'blinkr'

export async function challengeRoutes(app: FastifyInstance) {
  app.post('/challenges', { preHandler: requireAuth }, async (request, reply) => {
    const challengerId = (request.user as { sub: string }).sub
    const challenge = await createChallenge(db, challengerId)

    return reply.code(201).send({
      data: {
        id: challenge.id,
        code: challenge.code,
        deepLink: `${DEEP_LINK_SCHEME}://match/${challenge.code}`,
        expiresAt: challenge.expiresAt,
      },
    })
  })

  app.get(
    '/challenges/:code',
    { preHandler: requireAuth },
    async (request, reply) => {
      const { code } = request.params as { code: string }
      const challenge = await getChallengeByCode(db, code)

      const [challenger] = await db
        .select({ displayName: users.displayName, username: users.username })
        .from(users)
        .where(eq(users.id, challenge.challengerId))
        .limit(1)

      return reply.send({ data: { ...challenge, challenger } })
    },
  )

  app.post(
    '/challenges/:code/accept',
    { preHandler: requireAuth },
    async (request, reply) => {
      const acceptorId = (request.user as { sub: string }).sub
      const { code } = request.params as { code: string }

      const challenge = await getChallengeByCode(db, code)

      if (challenge.status !== 'pending') {
        throw Errors.conflict('Challenge is no longer pending')
      }
      if (challenge.challengerId === acceptorId) {
        throw Errors.validation('You cannot accept your own challenge')
      }

      const match = await createMatch(
        db,
        challenge.id,
        challenge.challengerId,
        acceptorId,
        'pending-room',
      )

      const roomName = await livekitService.createRoom(match.id)

      await db
        .update(matches)
        .set({ livekitRoomName: roomName })
        .where(eq(matches.id, match.id))

      await db
        .update(challenges)
        .set({ opponentId: acceptorId, status: 'accepted' })
        .where(eq(challenges.id, challenge.id))

      const [acceptorUser] = await db
        .select({ displayName: users.displayName, username: users.username })
        .from(users)
        .where(eq(users.id, acceptorId))
        .limit(1)

      const acceptorToken = livekitService.createParticipantToken(
        roomName,
        acceptorId,
        acceptorUser?.displayName ?? acceptorUser?.username ?? acceptorId,
      )

      return reply.send({
        data: {
          matchId: match.id,
          livekitToken: acceptorToken,
          livekitUrl: process.env.LIVEKIT_WS_URL,
          livekitRoomName: roomName,
        },
      })
    },
  )

  app.delete(
    '/challenges/:code',
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = (request.user as { sub: string }).sub
      const { code } = request.params as { code: string }

      const [challenge] = await db
        .select()
        .from(challenges)
        .where(eq(challenges.code, code))
        .limit(1)

      if (!challenge) throw Errors.notFound('Challenge')
      if (challenge.challengerId !== userId) throw Errors.forbidden()

      await db
        .update(challenges)
        .set({ status: 'cancelled' })
        .where(eq(challenges.id, challenge.id))

      return reply.send({ data: { cancelled: true } })
    },
  )
}
