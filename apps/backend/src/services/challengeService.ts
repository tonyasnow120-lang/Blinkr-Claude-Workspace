import { eq, and, isNull, gt } from 'drizzle-orm'
import type { DrizzleDB } from '../db/index.js'
import { challenges } from '../db/schema.js'
import { generateShortCode } from '../lib/shortCode.js'
import { Errors } from '../lib/errors.js'

const CHALLENGE_TTL_MINUTES = 15 // GAP-11: 15-minute TTL

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

// Atomically marks a challenge as used, preventing replay. Returns false if already used (GAP-11).
export async function markChallengeUsed(db: DrizzleDB, challengeId: string): Promise<boolean> {
  const updated = await db
    .update(challenges)
    .set({ usedAt: new Date() })
    .where(
      and(
        eq(challenges.id, challengeId),
        isNull(challenges.usedAt),  // Only update if not already used
        gt(challenges.expiresAt, new Date()), // Must not be expired
      ),
    )
    .returning({ id: challenges.id })

  return updated.length > 0
}
