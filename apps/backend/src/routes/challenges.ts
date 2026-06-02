import type { FastifyInstance } from 'fastify'
import { eq, and, isNull } from 'drizzle-orm'
import { db } from '../db/index.js'
import { challenges, matches, users } from '../db/schema.js'
import { createChallenge, getChallengeByCode, markChallengeUsed } from '../services/challengeService.js'
import { createMatch } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import { Errors } from '../lib/errors.js'
import { logSecurityEvent } from '../services/securityLogger.js'

// Primary deep link scheme — HTTPS Universal Link (GAP-9)
// blinkr:// custom scheme kept as fallback for backward compat
const HTTPS_BASE_URL = process.env.APP_BASE_URL ?? 'https://blinkr.app'

// Artificial delay for not-found responses to prevent timing-based code enumeration (GAP-12)
const NOT_FOUND_DELAY_MS = 50

export async function challengeRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  app.post('/challenges', async (request, reply) => {
    const challengerId = (request.user as { sub: string }).sub
    const challenge = await createChallenge(db, challengerId)

    return reply.code(201).send({
      data: {
        id: challenge.id,
        code: challenge.code,
        deepLink: `${HTTPS_BASE_URL}/match/${challenge.code}`,
        deepLinkFallback: `blinkr://match/${challenge.code}`,
        expiresAt: challenge.expiresAt,
      },
    })
  })

  app.get('/challenges/:code', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { code } = request.params as { code: string }

    const [challenge] = await db
      .select()
      .from(challenges)
      .where(eq(challenges.code, code))
      .limit(1)

    if (!challenge) {
      // Constant-time response on not-found to prevent timing-based enumeration (GAP-12)
      await new Promise((r) => setTimeout(r, NOT_FOUND_DELAY_MS))
      throw Errors.notFound('Challenge')
    }

    const isParticipant =
      challenge.challengerId === userId || challenge.opponentId === userId

    // Fetch challenger display name for join screen
    const [challenger] = await db
      .select({ displayName: users.displayName, username: users.username })
      .from(users)
      .where(eq(users.id, challenge.challengerId))
      .limit(1)

    if (!isParticipant) {
      // Non-participants get only what's needed to render the join screen (GAP-12)
      // Same shape for both valid and invalid codes (handled by not-found above)
      return reply.send({
        data: {
          challengerDisplayName: challenger?.displayName ?? challenger?.username,
          expiresAt: challenge.expiresAt,
          status: challenge.status,
        },
      })
    }

    // Full details for participants
    return reply.send({
      data: {
        ...challenge,
        challenger,
      },
    })
  })

  app.post('/challenges/:code/accept', async (request, reply) => {
    const acceptorId = (request.user as { sub: string }).sub
    const { code } = request.params as { code: string }

    const challenge = await getChallengeByCode(db, code)

    if (challenge.status !== 'pending') {
      throw Errors.conflict('Challenge is no longer pending')
    }
    if (challenge.challengerId === acceptorId) {
      throw Errors.validation('You cannot accept your own challenge')
    }

    // Atomically mark the challenge as used — prevents double-accept race conditions (GAP-11)
    const claimed = await markChallengeUsed(db, challenge.id)
    if (!claimed) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId: acceptorId,
        challengeId: challenge.id,
        reason: 'challenge_already_used_or_expired',
      })
      throw Errors.conflict('Challenge has already been accepted or expired')
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

    const acceptorToken = await livekitService.createParticipantToken(
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
  })

  app.delete('/challenges/:code', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { code } = request.params as { code: string }

    const [challenge] = await db
      .select()
      .from(challenges)
      .where(eq(challenges.code, code))
      .limit(1)

    if (!challenge) throw Errors.notFound('Challenge')
    if (challenge.challengerId !== userId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        challengeId: challenge.id,
        reason: 'delete_not_challenger',
      })
      throw Errors.forbidden()
    }

    await db
      .update(challenges)
      .set({ status: 'cancelled' })
      .where(eq(challenges.id, challenge.id))

    return reply.send({ data: { cancelled: true } })
  })
}
