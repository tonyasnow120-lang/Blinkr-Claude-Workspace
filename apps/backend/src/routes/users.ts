import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq } from 'drizzle-orm'
import { db } from '../db/index.js'
import { users, userStats } from '../db/schema.js'
import { requireAuth } from '../middleware/auth.js'
import { Errors } from '../lib/errors.js'
import { getMatchesForUser } from '../services/matchService.js'

const UpdateMeSchema = z.object({
  displayName: z.string().max(50).optional(),
  avatarUrl: z.string().url().optional(),
})

const MatchQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  offset: z.coerce.number().int().min(0).default(0),
})

export async function userRoutes(app: FastifyInstance) {
  app.get('/users/me', { preHandler: requireAuth }, async (request, reply) => {
    const userId = (request.user as { sub: string }).sub

    const [profile] = await db
      .select()
      .from(users)
      .leftJoin(userStats, eq(users.id, userStats.userId))
      .where(eq(users.id, userId))
      .limit(1)

    if (!profile) throw Errors.notFound('User')
    return reply.send({ data: profile })
  })

  app.patch('/users/me', { preHandler: requireAuth }, async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const body = UpdateMeSchema.parse(request.body)

    if (!body.displayName && !body.avatarUrl) {
      throw Errors.validation('At least one field required')
    }

    const [updated] = await db
      .update(users)
      .set({ ...body, updatedAt: new Date() })
      .where(eq(users.id, userId))
      .returning()

    if (!updated) throw Errors.notFound('User')
    return reply.send({ data: updated })
  })

  app.get(
    '/users/me/matches',
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = (request.user as { sub: string }).sub
      const { limit, offset } = MatchQuerySchema.parse(request.query)
      const results = await getMatchesForUser(db, userId, limit, offset)
      return reply.send({ data: results })
    },
  )

  app.get('/users/:id', { preHandler: requireAuth }, async (request, reply) => {
    const { id } = request.params as { id: string }

    const [user] = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, id))
      .limit(1)

    if (!user) throw Errors.notFound('User')
    return reply.send({ data: user })
  })
}
