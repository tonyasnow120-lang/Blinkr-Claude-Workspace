import 'dotenv/config'
import Fastify, { type FastifyRequest } from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import jwt from '@fastify/jwt'
import jwksClient from 'jwks-rsa'
import { registerRateLimit } from './middleware/rateLimit.js'
import { authRoutes } from './routes/auth.js'
import { userRoutes } from './routes/users.js'
import { challengeRoutes } from './routes/challenges.js'
import { matchRoutes } from './routes/matches.js'
import { wellKnownRoutes } from './routes/wellKnown.js'
import { AppError } from './lib/errors.js'
import { logSecurityEvent } from './services/securityLogger.js'

const app = Fastify({
  logger: true,
  bodyLimit: 1_048_576, // 1 MB — prevents memory-exhaustion DoS (H7)
})

// Security headers (H1)
await app.register(helmet, {
  contentSecurityPolicy: false, // API server — no HTML served
  hsts: {
    maxAge: 31_536_000,
    includeSubDomains: true,
    preload: true,
  },
})

// CORS — explicit allowlist, no wildcard, credentials not needed for Bearer auth (C1, GAP-19)
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean)
await app.register(cors, {
  origin: allowedOrigins.length > 0 ? allowedOrigins : false,
  credentials: false, // Bearer token auth — cookies not used
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

const supabaseUrl = process.env.SUPABASE_URL ??
  (() => { throw new Error('SUPABASE_URL required') })()

// Legacy HS256 secret — still needed while Supabase issues HS256 tokens
const legacySecret = process.env.SUPABASE_JWT_SECRET?.trim()

// RS256 public keys from Supabase JWKS — used once Supabase issues RS256 tokens
const jwks = jwksClient({
  jwksUri: `${supabaseUrl}/auth/v1/.well-known/jwks.json`,
  cache: true,
  cacheMaxAge: 600_000, // 10 minutes
  rateLimit: true,
  jwksRequestsPerMinute: 10,
})

app.log.info({
  jwtMode: legacySecret ? 'dual (HS256 legacy + RS256 JWKS)' : 'JWKS-only (RS256)',
  jwksUri: `${supabaseUrl}/auth/v1/.well-known/jwks.json`,
  legacySecretSet: !!legacySecret,
  legacySecretLength: legacySecret?.length ?? 0,
}, 'JWT configuration')

await app.register(jwt, {
  secret: async (_request: FastifyRequest, tokenOrHeader: { header?: { kid?: string; alg?: string }; kid?: string; alg?: string }) => {
    const header = 'header' in tokenOrHeader ? tokenOrHeader.header : tokenOrHeader
    const alg = header?.alg
    const kid = header?.kid

    app.log.debug({ alg, kid }, 'JWT secret resolver called')

    if (alg === 'RS256' && kid) {
      const signingKey = await jwks.getSigningKey(kid)
      return signingKey.getPublicKey()
    }

    if (legacySecret) return legacySecret

    throw new Error(`Cannot verify JWT: alg=${alg}, kid=${kid ?? 'none'}, SUPABASE_JWT_SECRET not set`)
  },
  verify: { algorithms: ['RS256', 'HS256'] },
})

await registerRateLimit(app)

// Routes that do not require a JWT
const PUBLIC_ROUTES = new Set([
  'GET /health',
  'GET /.well-known/apple-app-site-association',
  'GET /.well-known/assetlinks.json',
])

// Global auth preHandler — every non-public route requires a valid Supabase JWT (GAP-13)
app.addHook('preHandler', async (request, reply) => {
  const routeKey = `${request.method} ${request.routerPath}`
  if (PUBLIC_ROUTES.has(routeKey)) return
  try {
    await request.jwtVerify()
  } catch (err) {
    app.log.warn({
      msg: 'JWT verification failed',
      reason: err instanceof Error ? err.message : String(err),
      path: request.url,
      ip: request.ip,
    })
    logSecurityEvent(app.log, 'jwt_validation_failure', {
      ip: request.ip,
      path: request.url,
      method: request.method,
    })
    reply
      .code(401)
      .send({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } })
  }
})

// Unified error envelope: { error: { code, message } }
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

// Register routes — public well-known first, then /v1 groups
await app.register(wellKnownRoutes)
await app.register(authRoutes, { prefix: '/v1' })
await app.register(userRoutes, { prefix: '/v1' })
await app.register(challengeRoutes, { prefix: '/v1' })
await app.register(matchRoutes, { prefix: '/v1' })

app.get('/health', async () => ({ status: 'ok' }))

const port = Number(process.env.PORT ?? 3000)
await app.listen({ port, host: '0.0.0.0' })
