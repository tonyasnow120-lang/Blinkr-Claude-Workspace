import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, and, or, ilike, ne, sql } from 'drizzle-orm'
import { db } from '../db/index.js'
import { friendships, users, userStats } from '../db/schema.js'
import { Errors } from '../lib/errors.js'
import { logSecurityEvent } from '../services/securityLogger.js'

const SendRequestSchema = z.object({
  addresseeId: z.string().uuid(),
})

const SearchQuerySchema = z.object({
  q: z
    .string()
    .min(2)
    .max(20)
    .regex(/^[a-zA-Z0-9_]+$/, 'Invalid search query'),
})

// Resolves the friendship row between two users regardless of direction.
async function getFriendshipBetween(userA: string, userB: string) {
  const [row] = await db
    .select()
    .from(friendships)
    .where(
      or(
        and(eq(friendships.requesterId, userA), eq(friendships.addresseeId, userB)),
        and(eq(friendships.requesterId, userB), eq(friendships.addresseeId, userA)),
      ),
    )
    .limit(1)
  return row
}

export async function friendRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  // Username search (Feature 3). ILIKE prefix match, capped at 20 rows.
  // Each hit is annotated with the caller's friendship status so the UI
  // can render Add Friend / Pending / Challenge / Blocked directly.
  app.get('/users/search', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { q } = SearchQuerySchema.parse(request.query)

    const results = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
        wins: userStats.wins,
        losses: userStats.losses,
      })
      .from(users)
      .leftJoin(userStats, eq(userStats.userId, users.id))
      .where(and(ilike(users.username, `${q}%`), ne(users.id, userId)))
      .limit(20)

    const annotated = await Promise.all(
      results.map(async (u) => {
        const friendship = await getFriendshipBetween(userId, u.id)
        return {
          ...u,
          wins: u.wins ?? 0,
          losses: u.losses ?? 0,
          friendshipStatus: friendship?.status ?? null,
          // Lets the UI distinguish "request sent" from "request received"
          friendshipRequestedByMe: friendship?.requesterId === userId,
          friendshipId: friendship?.id ?? null,
        }
      }),
    )

    return reply.send({ data: annotated })
  })

  // Friends list + incoming pending requests in one call.
  app.get('/friends', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub

    const rows = await db
      .select({
        id: friendships.id,
        requesterId: friendships.requesterId,
        addresseeId: friendships.addresseeId,
        status: friendships.status,
        createdAt: friendships.createdAt,
        otherUsername: users.username,
        otherDisplayName: users.displayName,
        otherAvatarUrl: users.avatarUrl,
        otherWins: userStats.wins,
        otherLosses: userStats.losses,
      })
      .from(friendships)
      .innerJoin(
        users,
        sql`${users.id} = CASE WHEN ${friendships.requesterId} = ${userId}::uuid THEN ${friendships.addresseeId} ELSE ${friendships.requesterId} END`,
      )
      .leftJoin(userStats, eq(userStats.userId, users.id))
      .where(
        and(
          or(eq(friendships.requesterId, userId), eq(friendships.addresseeId, userId)),
          ne(friendships.status, 'blocked'),
        ),
      )

    const friends = []
    const incomingRequests = []
    for (const row of rows) {
      const otherId = row.requesterId === userId ? row.addresseeId : row.requesterId
      const entry = {
        friendshipId: row.id,
        userId: otherId,
        username: row.otherUsername,
        displayName: row.otherDisplayName,
        avatarUrl: row.otherAvatarUrl,
        wins: row.otherWins ?? 0,
        losses: row.otherLosses ?? 0,
        since: row.createdAt,
      }
      if (row.status === 'accepted') {
        friends.push(entry)
      } else if (row.status === 'pending' && row.addresseeId === userId) {
        incomingRequests.push(entry)
      }
      // Outgoing pending requests are visible via /users/search annotations.
    }

    return reply.send({ data: { friends, incomingRequests } })
  })

  app.post('/friends/requests', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { addresseeId } = SendRequestSchema.parse(request.body)

    if (addresseeId === userId) {
      throw Errors.validation('You cannot friend yourself')
    }

    const [addressee] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.id, addresseeId))
      .limit(1)
    if (!addressee) throw Errors.notFound('User')

    const existing = await getFriendshipBetween(userId, addresseeId)
    if (existing) {
      if (existing.status === 'blocked') throw Errors.forbidden()
      if (existing.status === 'accepted') {
        throw Errors.conflict('Already friends')
      }
      // Reverse pending request exists — accept it instead of duplicating.
      if (existing.requesterId === addresseeId) {
        await db
          .update(friendships)
          .set({ status: 'accepted' })
          .where(eq(friendships.id, existing.id))
        return reply.send({ data: { friendshipId: existing.id, status: 'accepted' } })
      }
      throw Errors.conflict('Request already sent')
    }

    const [created] = await db
      .insert(friendships)
      .values({ requesterId: userId, addresseeId })
      .returning()

    return reply.code(201).send({ data: { friendshipId: created.id, status: created.status } })
  })

  app.post('/friends/requests/:id/accept', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const [friendship] = await db
      .select()
      .from(friendships)
      .where(eq(friendships.id, id))
      .limit(1)

    if (!friendship) throw Errors.notFound('Friend request')
    // Only the addressee can accept, and only while pending.
    if (friendship.addresseeId !== userId || friendship.status !== 'pending') {
      logSecurityEvent(request.log, 'idor_attempt', {
        userId,
        friendshipId: id,
        route: 'POST /friends/requests/:id/accept',
      })
      throw Errors.forbidden()
    }

    await db
      .update(friendships)
      .set({ status: 'accepted' })
      .where(eq(friendships.id, id))

    return reply.send({ data: { friendshipId: id, status: 'accepted' } })
  })

  app.post('/friends/requests/:id/decline', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const [friendship] = await db
      .select()
      .from(friendships)
      .where(eq(friendships.id, id))
      .limit(1)

    if (!friendship) throw Errors.notFound('Friend request')
    if (friendship.addresseeId !== userId || friendship.status !== 'pending') {
      throw Errors.forbidden()
    }

    await db.delete(friendships).where(eq(friendships.id, id))
    return reply.send({ data: { declined: true } })
  })

  // Block a user: replaces any existing friendship row. The blocker becomes
  // the requester so unblock authorization is unambiguous.
  app.post('/friends/:userId/block', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { userId: targetId } = request.params as { userId: string }

    if (targetId === userId) throw Errors.validation('You cannot block yourself')

    const existing = await getFriendshipBetween(userId, targetId)
    if (existing) {
      if (existing.status === 'blocked' && existing.requesterId !== userId) {
        // They blocked us first — leave their block in place.
        return reply.send({ data: { blocked: true } })
      }
      await db.delete(friendships).where(eq(friendships.id, existing.id))
    }

    await db
      .insert(friendships)
      .values({ requesterId: userId, addresseeId: targetId, status: 'blocked' })

    return reply.send({ data: { blocked: true } })
  })

  // Unfriend (or unblock, if the caller is the blocker).
  app.delete('/friends/:userId', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { userId: targetId } = request.params as { userId: string }

    const existing = await getFriendshipBetween(userId, targetId)
    if (!existing) throw Errors.notFound('Friendship')
    if (existing.status === 'blocked' && existing.requesterId !== userId) {
      throw Errors.forbidden()
    }

    await db.delete(friendships).where(eq(friendships.id, existing.id))
    return reply.send({ data: { removed: true } })
  })
}
