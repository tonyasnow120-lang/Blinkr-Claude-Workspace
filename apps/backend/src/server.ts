import 'dotenv/config'
import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import { registerRateLimit } from './middleware/rateLimit.js'
import { authRoutes } from './routes/auth.js'
import { userRoutes } from './routes/users.js'
import { challengeRoutes } from './routes/challenges.js'
import { matchRoutes } from './routes/matches.js'
import { AppError } from './lib/errors.js'

const app = Fastify({ logger: true })

await app.register(cors, {
  origin: process.env.API_BASE_URL ?? true,
})

await app.register(jwt, {
  secret: process.env.SUPABASE_JWT_SECRET ?? (() => { throw new Error('SUPABASE_JWT_SECRET required') })(),
})

await registerRateLimit(app)

// Global error handler — enforces { error: { code, message } } envelope
app.setErrorHandler((error, _request, reply) => {
  if (error instanceof AppError) {
    return reply
      .code(error.statusCode)
      .send({ error: { code: error.code, message: error.message } })
  }
  if (error.validation) {
    return reply
      .code(422)
      .send({ error: { code: 'VALIDATION_ERROR', message: error.message } })
  }
  app.log.error(error)
  return reply
    .code(500)
    .send({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } })
})

// Register all route groups under /v1
await app.register(authRoutes, { prefix: '/v1' })
await app.register(userRoutes, { prefix: '/v1' })
await app.register(challengeRoutes, { prefix: '/v1' })
await app.register(matchRoutes, { prefix: '/v1' })

app.get('/health', async () => ({ status: 'ok' }))

const port = Number(process.env.PORT ?? 3000)
await app.listen({ port, host: '0.0.0.0' })
