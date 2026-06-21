import 'dotenv/config'
import Fastify, { type FastifyRequest } from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import jwt from '@fastify/jwt'
import { createRemoteJWKSet, jwtVerify as joseVerify } from 'jose'
import { registerRateLimit } from './middleware/rateLimit.js'
import { authRoutes } from './routes/auth.js'
import { userRoutes } from './routes/users.js'
import { challengeRoutes } from './routes/challenges.js'
import { matchRoutes } from './routes/matches.js'
import { friendRoutes } from './routes/friends.js'
import { contactRoutes } from './routes/contacts.js'
import { proximityRoutes } from './routes/proximity.js'
import { wellKnownRoutes } from './routes/wellKnown.js'
import { runMigrations } from './db/migrate.js'
import { AppError } from './lib/errors.js'
import { logSecurityEvent } from './services/securityLogger.js'

const app = Fastify({
  logger: true,
  bodyLimit: 1_048_576,
})

await app.register(helmet, {
  contentSecurityPolicy: false,
  hsts: { maxAge: 31_536_000, includeSubDomains: true, preload: true },
})

const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean)
await app.register(cors, {
  origin: allowedOrigins.length > 0 ? allowedOrigins : false,
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

const supabaseUrl = process.env.SUPABASE_URL ??
  (() => { throw new Error('SUPABASE_URL required') })()

// Legacy HS256 secret — fallback for tokens issued before Supabase key migration
const legacySecret = process.env.SUPABASE_JWT_SECRET?.trim()

// jose JWKS client — handles ES256/RS256 from Supabase JWT Signing Keys natively
const JWKS = createRemoteJWKSet(
  new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
  { cacheMaxAge: 600_000 },
)

// Register @fastify/jwt only for its request.user decoration (HS256 legacy fallback)
await app.register(jwt, {
  secret: legacySecret ?? 'unused-no-legacy-secret-configured',
  verify: { algorithms: ['HS256'] },
})

app.log.info({
  jwksUri: `${supabaseUrl}/auth/v1/.well-known/jwks.json`,
  legacySecretSet: !!legacySecret,
  legacySecretLength: legacySecret?.length ?? 0,
}, 'JWT configuration')

await registerRateLimit(app)

const PUBLIC_ROUTES = new Set([
  'GET /health',
  'GET /.well-known/apple-app-site-association',
  'GET /.well-known/assetlinks.json',
])

function parseJwtHeader(authHeader: string | undefined): Record<string, unknown> | null {
  try {
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!token) return null
    return JSON.parse(Buffer.from(token.split('.')[0], 'base64url').toString())
  } catch {
    return null
  }
}

app.addHook('preHandler', async (request, reply) => {
  const routeKey = `${request.method} ${request.routeOptions.url}`
  if (PUBLIC_ROUTES.has(routeKey)) return

  try {
    const authHeader = request.headers.authorization
    const tokenHeader = parseJwtHeader(authHeader)
    const alg = tokenHeader?.alg as string | undefined
    const kid = tokenHeader?.kid as string | undefined

    if ((alg === 'ES256' || alg === 'RS256') && kid) {
      // New Supabase JWT Signing Keys — use jose's JWKS client (handles ES256 natively)
      const token = authHeader!.slice(7)
      const { payload } = await joseVerify(token, JWKS)
      request.user = payload as Record<string, unknown>
    } else {
      // Legacy HS256 — delegate to @fastify/jwt
      await request.jwtVerify()
    }
  } catch (err) {
    const tokenHeader = parseJwtHeader(request.headers.authorization)
    app.log.warn({
      msg: 'JWT verification failed',
      reason: err instanceof Error ? err.message : String(err),
      tokenAlg: tokenHeader?.alg,
      tokenKid: tokenHeader?.kid ?? 'none',
      hasAuthHeader: !!request.headers.authorization,
      legacySecretSet: !!legacySecret,
      path: request.url,
    })
    logSecurityEvent(app.log, 'jwt_validation_failure', {
      ip: request.ip,
      path: request.url,
      method: request.method,
    })
    reply.code(401).send({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } })
  }
})

app.setErrorHandler((error, _request, reply) => {
  if (error instanceof AppError) {
    return reply.code(error.statusCode).send({ error: { code: error.code, message: error.message } })
  }
  if (error.validation) {
    return reply.code(422).send({ error: { code: 'VALIDATION_ERROR', message: error.message } })
  }
  app.log.error(error)
  return reply.code(500).send({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } })
})

await app.register(wellKnownRoutes)
await app.register(authRoutes, { prefix: '/v1' })
await app.register(userRoutes, { prefix: '/v1' })
await app.register(challengeRoutes, { prefix: '/v1' })
await app.register(matchRoutes, { prefix: '/v1' })
await app.register(friendRoutes, { prefix: '/v1' })
await app.register(contactRoutes, { prefix: '/v1' })
await app.register(proximityRoutes, { prefix: '/v1' })

app.get('/health', async () => ({ status: 'ok' }))

// Apply idempotent SQL migrations before accepting traffic — the schema
// must match what the Drizzle models select or every query 500s.
await runMigrations(app.log)

const port = Number(process.env.PORT ?? 3000)
await app.listen({ port, host: '0.0.0.0' })
