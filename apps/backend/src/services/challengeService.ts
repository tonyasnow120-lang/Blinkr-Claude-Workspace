import { eq, and, sql } from 'drizzle-orm'
import type { DrizzleDB } from '../db/index.js'
import { challenges } from '../db/schema.js'
import { generateShortCode } from '../lib/shortCode.js'
import { Errors } from '../lib/errors.js'

const CHALLENGE_TTL_MINUTES = 10

export async function createChallenge(db: DrizzleDB, challengerId: string) {
  const code = await generateShortCode(db)
  const expiresAt = new Date(Date.now() + CHALLENGE_TTL_MINUTES * 60 * 1000)

  const [challenge] = await db
    .insert(challenges)
    .values({ code, challengerId, expiresAt })
    .returning()

  return challenge
}

export async function getChallengeByCode(db: DrizzleDB, code: string) {
  const [challenge] = await db
    .select()
    .from(challenges)
    .where(eq(challenges.code, code))
    .limit(1)

  if (!challenge) {
    throw Errors.notFound('Challenge')
  }

  // Enforce expiry on every read
  if (challenge.status === 'pending' && challenge.expiresAt < new Date()) {
    await db
      .update(challenges)
      .set({ status: 'expired' })
      .where(eq(challenges.id, challenge.id))
    challenge.status = 'expired'
    throw Errors.gone('Challenge')
  }

  return challenge
}
