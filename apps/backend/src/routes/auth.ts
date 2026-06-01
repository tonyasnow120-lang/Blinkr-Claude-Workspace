import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq } from 'drizzle-orm'
import { db } from '../db/index.js'
import { users, userStats } from '../db/schema.js'
import { Errors } from '../lib/errors.js'
import { getSupabaseAdmin } from '../services/supabaseAdmin.js'

const RegisterProfileSchema = z.object({
  username: z
    .string()
    .min(3)
    .max(20)
    .regex(/^[a-zA-Z0-9_]+$/, 'Username may only contain letters, numbers, and underscores'),
  displayName: z.string().max(50).optional(),
  avatarUrl: z.string().url().optional(),
})

const FcmTokenSchema = z.object({
  fcmToken: z.string().min(1),
})

export async function authRoutes(app: FastifyInstance) {
  // All routes in this plugin are protected by the global JWT preHandler in server.ts

  app.post('/auth/register-profile', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const body = RegisterProfileSchema.parse(request.body)

    const existing = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1)

    if (existing.length > 0) {
      throw Errors.conflict('Profile already exists for this user')
    }

    const usernameTaken = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.username, body.username))
      .limit(1)

    if (usernameTaken.length > 0) {
      throw Errors.conflict('Username is already taken')
    }

    const [newUser] = await db.transaction(async (tx) => {
      const [user] = await tx
        .insert(users)
        .values({
          id: userId,
          username: body.username,
          displayName: body.displayName,
          avatarUrl: body.avatarUrl,
        })
        .returning()

      await tx.insert(userStats).values({ userId })
      return [user]
    })

    return reply.code(201).send({ data: newUser })
  })

  app.patch('/auth/fcm-token', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { fcmToken } = FcmTokenSchema.parse(request.body)

    await db.update(users).set({ fcmToken }).where(eq(users.id, userId))
    return reply.send({ data: { updated: true } })
  })

  // Server-side session invalidation — prevents revoked tokens from remaining valid (GAP-20)
  app.post('/auth/logout', async (request, reply) => {
    const claims = request.user as { sub: string; session_id?: string }
    const supabaseAdmin = getSupabaseAdmin()

    if (claims.session_id) {
      // Invalidate the specific session
      await supabaseAdmin.auth.admin.signOut(claims.session_id)
    } else {
      // Fallback: sign out all sessions for the user
      await supabaseAdmin.auth.admin.signOut(claims.sub)
    }

    return reply.send({ data: { loggedOut: true } })
  })
}
