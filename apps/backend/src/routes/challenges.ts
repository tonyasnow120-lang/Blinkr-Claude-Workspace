import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, and, isNull, desc, gt } from 'drizzle-orm'
import { db } from '../db/index.js'
import { challenges, matches, users } from '../db/schema.js'
import { createChallenge, getChallengeByCode, markChallengeUsed } from '../services/challengeService.js'
import { createMatch } from '../services/matchService.js'
import * as livekitService from '../services/livekitService.js'
import * as notificationService from '../services/notificationService.js'
import { broadcastEvent, challengeTopic, userTopic } from '../services/realtimeService.js'
import { Errors } from '../lib/errors.js'
import { logSecurityEvent } from '../services/securityLogger.js'

const CreateChallengeSchema = z.object({
  kind: z.enum(['link', 'qr', 'friend', 'contact', 'proximity']).default('link'),
  opponentId: z.string().uuid().optional(),
})

// Primary deep link scheme — HTTPS Universal Link (GAP-9)
// blinkr:// custom scheme kept as fallback for backward compat.
// Default is the Railway deployment domain (which also serves the
// /.well-known association files); override via APP_BASE_URL if a custom
// domain is added later.
const HTTPS_BASE_URL =
  process.env.APP_BASE_URL ?? 'https://blinkr-production-80d5.up.railway.app'

// Artificial delay for not-found responses to prevent timing-based code enumeration (GAP-12)
const NOT_FOUND_DELAY_MS = 50

export async function challengeRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  app.post('/challenges', async (request, reply) => {
    const challengerId = (request.user as { sub: string }).sub
    const { kind, opponentId } = CreateChallengeSchema.parse(request.body ?? {})

    if (opponentId === challengerId) {
      throw Errors.validation('You cannot challenge yourself')
    }

    const challenge = await createChallenge(db, challengerId, kind, opponentId)

    // Targeted challenge (friend/contact/proximity): push-notify the opponent.
    // Best-effort — the challenge stands even if the push fails or the
    // opponent has no FCM token registered.
    if (opponentId) {
      const [challenger] = await db
        .select({ displayName: users.displayName, username: users.username })
        .from(users)
        .where(eq(users.id, challengerId))
        .limit(1)
      const [opponent] = await db
        .select({ fcmToken: users.fcmToken })
        .from(users)
        .where(eq(users.id, opponentId))
        .limit(1)

      if (opponent?.fcmToken) {
        notificationService
          .sendMatchInvite(
            opponent.fcmToken,
            challenger?.displayName ?? challenger?.username ?? 'Someone',
            challenge.code,
          )
          .catch((err) =>
            request.log.warn({ err: err?.message }, 'Match invite push failed'),
          )
      }

      // In-app invite: shown immediately if the opponent's app is running,
      // independent of (and in addition to) the push notification above.
      broadcastEvent(userTopic(opponentId), 'challenge.invite', {
        code: challenge.code,
        kind: challenge.kind,
        challengerName: challenger?.displayName ?? challenger?.username ?? 'Someone',
      }).catch((err) =>
        request.log.warn({ err: err?.message }, 'Challenge invite broadcast failed'),
      )
    }

    return reply.code(201).send({
      data: {
        id: challenge.id,
        code: challenge.code,
        kind: challenge.kind,
        deepLink: `${HTTPS_BASE_URL}/match/${challenge.code}`,
        deepLinkFallback: `blinkr://match/${challenge.code}`,
        expiresAt: challenge.expiresAt,
      },
    })
  })

  // Polling fallback to the `challenge.invite` Realtime broadcast — lets the
  // challenged player's app pick up a pending targeted challenge
  // (friend/contact/proximity) even if the broadcast was missed.
  app.get('/challenges/incoming', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub

    const [challenge] = await db
      .select({
        code: challenges.code,
        kind: challenges.kind,
        challengerId: challenges.challengerId,
      })
      .from(challenges)
      .where(
        and(
          eq(challenges.opponentId, userId),
          eq(challenges.status, 'pending'),
          gt(challenges.expiresAt, new Date()),
        ),
      )
      .orderBy(desc(challenges.createdAt))
      .limit(1)

    if (!challenge) {
      return reply.send({ data: null })
    }

    const [challenger] = await db
      .select({ displayName: users.displayName, username: users.username })
      .from(users)
      .where(eq(users.id, challenge.challengerId))
      .limit(1)

    return reply.send({
      data: {
        code: challenge.code,
        kind: challenge.kind,
        challengerName: challenger?.displayName ?? challenger?.username ?? 'Someone',
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

    // Full details for participants. When accepted, include the resulting
    // match id so the challenger can poll for it as a fallback to the
    // realtime challenge.accepted broadcast.
    let matchId: string | undefined
    if (challenge.status === 'accepted') {
      const [match] = await db
        .select({ id: matches.id })
        .from(matches)
        .where(eq(matches.challengeId, challenge.id))
        .limit(1)
      matchId = match?.id
    }

    return reply.send({
      data: {
        ...challenge,
        challenger,
        matchId,
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
    // Targeted challenges (friend/contact/proximity) may only be accepted
    // by the invited opponent.
    if (challenge.opponentId && challenge.opponentId !== acceptorId) {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId: acceptorId,
        challengeId: challenge.id,
        reason: 'accept_not_invited_opponent',
      })
      throw Errors.forbidden()
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

    // Wake the waiting challenger (link/QR share screens subscribe to this
    // topic). Payload carries only the matchId — the challenger fetches
    // their own LiveKit token over authenticated HTTP, never via broadcast.
    broadcastEvent(challengeTopic(challenge.id), 'challenge.accepted', {
      matchId: match.id,
    }).catch((err) =>
      request.log.warn({ err: err?.message }, 'challenge.accepted broadcast failed'),
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

    // Only cancel while still pending — avoids clobbering a challenge that
    // was accepted concurrently (e.g. QR auto-regeneration racing a
    // last-second scan).
    await db
      .update(challenges)
      .set({ status: 'cancelled' })
      .where(and(eq(challenges.id, challenge.id), eq(challenges.status, 'pending')))

    return reply.send({ data: { cancelled: true } })
  })
}
