import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, desc, eq } from 'drizzle-orm'
import { db } from '../db/index.js'
import { users, userPhotos, userStats } from '../db/schema.js'
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

const AddPhotoSchema = z.object({
  url: z.string().url(),
})

// Caps how many photos a user can keep in their collage
const MAX_PHOTOS_PER_USER = 12

export async function userRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  app.get('/users/me', async (request, reply) => {
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

  app.patch('/users/me', async (request, reply) => {
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

  app.get('/users/me/photos', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const photos = await db
      .select()
      .from(userPhotos)
      .where(eq(userPhotos.userId, userId))
      .orderBy(desc(userPhotos.createdAt))
    return reply.send({ data: photos })
  })

  app.post('/users/me/photos', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { url } = AddPhotoSchema.parse(request.body)

    const existing = await db
      .select({ id: userPhotos.id })
      .from(userPhotos)
      .where(eq(userPhotos.userId, userId))

    if (existing.length >= MAX_PHOTOS_PER_USER) {
      throw Errors.validation(`You can upload up to ${MAX_PHOTOS_PER_USER} photos`)
    }

    const [photo] = await db
      .insert(userPhotos)
      .values({ userId, url })
      .returning()

    return reply.code(201).send({ data: photo })
  })

  app.delete('/users/me/photos/:id', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { id } = request.params as { id: string }

    const [deleted] = await db
      .delete(userPhotos)
      .where(and(eq(userPhotos.id, id), eq(userPhotos.userId, userId)))
      .returning()

    if (!deleted) throw Errors.notFound('Photo')
    return reply.send({ data: deleted })
  })

  app.get('/users/me/matches', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { limit, offset } = MatchQuerySchema.parse(request.query)
    const results = await getMatchesForUser(db, userId, limit, offset)
    return reply.send({ data: results })
  })

  app.get('/users/:id', async (request, reply) => {
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

  app.get('/users/:id/photos', async (request, reply) => {
    const { id } = request.params as { id: string }
    const photos = await db
      .select()
      .from(userPhotos)
      .where(eq(userPhotos.userId, id))
      .orderBy(desc(userPhotos.createdAt))
    return reply.send({ data: photos })
  })
}
