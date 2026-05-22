import type { FastifyRequest, FastifyReply } from 'fastify'
import { Errors } from '../lib/errors.js'

export async function requireAuth(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  try {
    await request.jwtVerify()
  } catch {
    const err = Errors.unauthorized()
    reply.code(err.statusCode).send({ error: { code: err.code, message: err.message } })
  }
}

// Attached to request after JWT verification — mirrors Supabase JWT sub claim
export interface AuthUser {
  sub: string
  email?: string
}

declare module 'fastify' {
  interface FastifyRequest {
    authUser: AuthUser
  }
}
