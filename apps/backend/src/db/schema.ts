import {
  pgTable,
  uuid,
  text,
  char,
  integer,
  numeric,
  timestamp,
  boolean,
  index,
  uniqueIndex,
  customType,
} from 'drizzle-orm/pg-core'
import { sql } from 'drizzle-orm'

// PostGIS geography(Point, 4326) — Drizzle has no native type; raw SQL passthrough.
const geographyPoint = customType<{ data: string }>({
  dataType() {
    return 'geography(Point, 4326)'
  },
})

export const users = pgTable('users', {
  id: uuid('id').primaryKey(),
  username: text('username').unique().notNull(),
  displayName: text('display_name'),
  avatarUrl: text('avatar_url'),
  fcmToken: text('fcm_token'),
  // SHA-256 of the user's own E.164 phone number, hashed on-device — the
  // server never sees the raw number. Powers contact discovery (Feature 2).
  phoneHash: text('phone_hash'),
  allowContactDiscovery: boolean('allow_contact_discovery').default(true).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (t) => ({
  phoneHashIdx: index('users_phone_hash_idx').on(t.phoneHash),
}))

export const userPhotos = pgTable(
  'user_photos',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    url: text('url').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    userIdx: index('user_photos_user_id_idx').on(t.userId),
  }),
)

export const userStats = pgTable('user_stats', {
  userId: uuid('user_id')
    .primaryKey()
    .references(() => users.id, { onDelete: 'cascade' }),
  wins: integer('wins').default(0).notNull(),
  losses: integer('losses').default(0).notNull(),
  currentStreak: integer('current_streak').default(0).notNull(),
  longestStreak: integer('longest_streak').default(0).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
})

export const challenges = pgTable(
  'challenges',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    // 9-char code from 32-char alphabet = 45 bits entropy (C5, GAP-23)
    code: char('code', { length: 9 }).unique().notNull(),
    challengerId: uuid('challenger_id')
      .notNull()
      .references(() => users.id),
    opponentId: uuid('opponent_id').references(() => users.id),
    // How the challenge was issued — drives TTL (qr: 60s, others: 15min)
    // and whether opponentId is pre-targeted (friend/contact/proximity).
    kind: text('kind', {
      enum: ['link', 'qr', 'friend', 'contact', 'proximity'],
    })
      .default('link')
      .notNull(),
    status: text('status', {
      enum: ['pending', 'accepted', 'expired', 'cancelled'],
    })
      .default('pending')
      .notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    // Tracks one-time-use acceptance — null until a match is created (GAP-11)
    usedAt: timestamp('used_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    codeIdx: index('challenges_code_idx').on(t.code),
    challengerIdx: index('challenges_challenger_id_idx').on(t.challengerId),
  }),
)

export const matches = pgTable(
  'matches',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    challengeId: uuid('challenge_id')
      .notNull()
      .references(() => challenges.id),
    playerOneId: uuid('player_one_id')
      .notNull()
      .references(() => users.id),
    playerTwoId: uuid('player_two_id')
      .notNull()
      .references(() => users.id),
    winnerId: uuid('winner_id').references(() => users.id),
    loserId: uuid('loser_id').references(() => users.id),
    livekitRoomName: text('livekit_room_name').notNull(),
    // Per-player lobby ready flags — countdown starts only when both are true.
    playerOneReady: boolean('player_one_ready').default(false).notNull(),
    playerTwoReady: boolean('player_two_ready').default(false).notNull(),
    status: text('status', {
      enum: ['waiting', 'countdown', 'live', 'adjudicating', 'completed', 'abandoned'],
    })
      .default('waiting')
      .notNull(),
    startedAt: timestamp('started_at', { withTimezone: true }),
    endedAt: timestamp('ended_at', { withTimezone: true }),
    durationMs: integer('duration_ms'),
    resultReason: text('result_reason', {
      enum: ['blink', 'gaze_break', 'disconnect', 'simultaneous'],
    }),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    playerOneIdx: index('matches_player_one_id_idx').on(t.playerOneId),
    playerTwoIdx: index('matches_player_two_id_idx').on(t.playerTwoId),
    challengeIdx: index('matches_challenge_id_idx').on(t.challengeId),
  }),
)

export const blinkEvents = pgTable(
  'blink_events',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    matchId: uuid('match_id')
      .notNull()
      .references(() => matches.id, { onDelete: 'cascade' }),
    playerId: uuid('player_id')
      .notNull()
      .references(() => users.id),
    detectedAt: timestamp('detected_at', { withTimezone: true }).notNull(),
    receivedAt: timestamp('received_at', { withTimezone: true }).defaultNow().notNull(),
    earValue: numeric('ear_value', { precision: 5, scale: 4 }).notNull(),
    eventType: text('event_type', { enum: ['blink', 'gaze_break'] }).notNull(),
  },
  (t) => ({
    matchIdx: index('blink_events_match_id_idx').on(t.matchId),
  }),
)

export const friendships = pgTable(
  'friendships',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    requesterId: uuid('requester_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    addresseeId: uuid('addressee_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: text('status', { enum: ['pending', 'accepted', 'blocked'] })
      .default('pending')
      .notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    pairUnique: uniqueIndex('friendships_pair_idx').on(t.requesterId, t.addresseeId),
    addresseeStatusIdx: index('friendships_addressee_status_idx').on(t.addresseeId, t.status),
  }),
)

// Separate table (not columns on users) so RLS can deny ALL client access —
// coordinates are only ever read by the backend, which returns distances.
export const userLocations = pgTable('user_locations', {
  userId: uuid('user_id')
    .primaryKey()
    .references(() => users.id, { onDelete: 'cascade' }),
  location: geographyPoint('location'),
  visible: boolean('visible').default(false).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
})

export type User = typeof users.$inferSelect
export type UserPhoto = typeof userPhotos.$inferSelect
export type UserStats = typeof userStats.$inferSelect
export type Challenge = typeof challenges.$inferSelect
export type Match = typeof matches.$inferSelect
export type BlinkEvent = typeof blinkEvents.$inferSelect
export type Friendship = typeof friendships.$inferSelect
export type UserLocation = typeof userLocations.$inferSelect
