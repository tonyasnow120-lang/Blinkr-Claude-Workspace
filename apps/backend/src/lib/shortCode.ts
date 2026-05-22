import { customAlphabet } from 'nanoid'
import { eq } from 'drizzle-orm'
import type { DrizzleDB } from '../db/index.js'
import { challenges } from '../db/schema.js'

// Excludes visually ambiguous characters: O, 0, I, 1
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const generate = customAlphabet(ALPHABET, 6)

export async function generateShortCode(db: DrizzleDB): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generate()
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
