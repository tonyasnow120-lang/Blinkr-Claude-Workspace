import { randomInt } from 'crypto'
import { eq } from 'drizzle-orm'
import type { DrizzleDB } from '../db/index.js'
import { challenges } from '../db/schema.js'

// Excludes visually ambiguous characters: O, 0, I, 1
// 32-char alphabet × 9 chars = 45.0 bits entropy — meets ≥41-bit requirement (GAP-23, GAP-27)
// Uses crypto.randomInt (CSPRNG) — NOT Math.random()
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const CODE_LENGTH = 9

const ENTROPY_BITS = Math.log2(Math.pow(ALPHABET.length, CODE_LENGTH))
// Entropy assertion fires at startup if alphabet or length is ever shortened below the minimum
console.assert(
  ENTROPY_BITS >= 41,
  `Challenge code entropy ${ENTROPY_BITS.toFixed(1)} bits is below the 41-bit minimum`,
)

export function generateCode(): string {
  return Array.from({ length: CODE_LENGTH }, () => ALPHABET[randomInt(ALPHABET.length)]).join('')
}

export async function generateShortCode(db: DrizzleDB): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateCode()
    const existing = await db
      .select({ id: challenges.id })
      .from(challenges)
      .where(eq(challenges.code, code))
      .limit(1)

    if (existing.length === 0) {
      return code
    }
  }
  throw new Error('Failed to generate a unique short code after 5 attempts')
}
