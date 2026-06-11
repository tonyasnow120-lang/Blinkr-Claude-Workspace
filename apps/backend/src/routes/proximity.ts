import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, sql } from 'drizzle-orm'
import { db } from '../db/index.js'
import { userLocations } from '../db/schema.js'

const LocationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
})

const NearbyQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radiusMeters: z.coerce.number().min(50).max(5000).default(500),
})

// Profiles older than this are "ghosts" — the app heartbeats every 30s
// while proximity mode is on, so 2 minutes means roughly 4 missed beats.
const STALENESS_INTERVAL = "interval '2 minutes'"

export async function proximityRoutes(app: FastifyInstance) {
  // All routes protected by global JWT preHandler in server.ts.
  // Location data privacy invariants (Feature 5):
  //   - coordinates live in user_locations, which has deny-all RLS — only
  //     this backend (service role) can read them
  //   - nearby results return DISTANCE ONLY, never coordinates
  //   - rows are upserted only while the user's visibility toggle is on,
  //     and erased (not just hidden) when it turns off

  // Heartbeat: update my location while visible. Called every ~30s.
  app.put('/proximity/location', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { lat, lng } = LocationSchema.parse(request.body)

    await db
      .insert(userLocations)
      .values({
        userId,
        location: sql`ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography` as never,
        visible: true,
        updatedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: userLocations.userId,
        set: {
          location: sql`ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography`,
          visible: true,
          updatedAt: new Date(),
        },
      })

    return reply.send({ data: { visible: true } })
  })

  // Go invisible: erase coordinates entirely, not just the flag.
  app.delete('/proximity/location', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub

    await db
      .update(userLocations)
      .set({ visible: false, location: null, updatedAt: new Date() })
      .where(eq(userLocations.userId, userId))

    return reply.send({ data: { visible: false } })
  })

  // Nearby visible players, fresh within 2 minutes, distance only.
  app.get('/proximity/nearby', async (request, reply) => {
    const userId = (request.user as { sub: string }).sub
    const { lat, lng, radiusMeters } = NearbyQuerySchema.parse(request.query)

    const rows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.avatar_url AS "avatarUrl",
        COALESCE(s.wins, 0) AS wins,
        COALESCE(s.losses, 0) AS losses,
        ROUND(ST_Distance(l.location, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography)) AS "distanceMeters"
      FROM user_locations l
      JOIN users u ON u.id = l.user_id
      LEFT JOIN user_stats s ON s.user_id = u.id
      WHERE l.visible = true
        AND l.location IS NOT NULL
        AND l.updated_at > now() - ${sql.raw(STALENESS_INTERVAL)}
        AND l.user_id != ${userId}::uuid
        AND ST_DWithin(l.location, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, ${radiusMeters})
      ORDER BY "distanceMeters" ASC
      LIMIT 20
    `)

    return reply.send({ data: rows })
  })
}
