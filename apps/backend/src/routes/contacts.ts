import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, eq, inArray, ne } from 'drizzle-orm'
import { db } from '../db/index.js'
import { users } from '../db/schema.js'

// SHA-256 hex digests — 64 lowercase hex chars. Raw phone numbers are
// hashed ON DEVICE and must never appear in a request (or a log line).
const MatchContactsSchema = z.object({
  hashes: z.array(z.string().regex(/^[a-f0-9]{64}$/)).min(1).max(5000),
})

const UpdatePhoneHashSchema = z.object({
  // null clears the hash and removes the user from contact discovery
  phoneHash: z.string().regex(/^[a-f0-9]{64}$/).nullable(),
})

export async function contactRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts

  // Feature 2: which of the caller's contacts are on Blinkr?
  // Only returns users who opted into contact discovery. The echoed
  // phoneHash lets the client merge results with device contact names.
  app.post('/contacts/match', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { hashes } = MatchContactsSchema.parse(request.body)

    const matched = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
        phoneHash: users.phoneHash,
      })
      .from(users)
      .where(
        and(
          inArray(users.phoneHash, hashes),
          eq(users.allowContactDiscovery, true),
          ne(users.id, userId),
        ),
      )
      .limit(500)

    return reply.send({ data: matched })
  })

  // Registers (or clears) the caller's own phone hash so contacts who have
  // their number can discover them. Hashing happens on the client.
  app.put('/contacts/phone-hash', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { phoneHash } = UpdatePhoneHashSchema.parse(request.body)

    await db
      .update(users)
      .set({ phoneHash, updatedAt: new Date() })
      .where(eq(users.id, userId))

    return reply.send({ data: { updated: true } })
  })

  // Opt in/out of being discoverable via contacts.
  app.put('/contacts/discovery', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { allow } = z.object({ allow: z.boolean() }).parse(request.body)

    await db
      .update(users)
      .set({ allowContactDiscovery: allow, updatedAt: new Date() })
      .where(eq(users.id, userId))

    return reply.send({ data: { allowContactDiscovery: allow } })
  })
}
