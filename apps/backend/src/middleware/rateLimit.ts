import type { FastifyInstance } from 'fastify'
import rateLimit from '@fastify/rate-limit'

export async function registerRateLimit(app: FastifyInstance) {
  await app.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    errorResponseBuilder: () => ({
      error: {
        code: 'RATE_LIMITED',
        message: 'Too many requests — please slow down.',
      },
    }),
  })
}
