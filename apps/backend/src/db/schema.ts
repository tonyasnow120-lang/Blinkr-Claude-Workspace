import {
  pgTable,
  uuid,
  text,
  char,
  integer,
  numeric,
  timestamp,
  index,
} from 'drizzle-orm/pg-core'
import { sql } from 'drizzle-orm'

export const users = pgTable('users', {
  id: uuid('id').primaryKey(),
  username: text('username').unique().notNull(),
  displayName: text('display_name'),
  avatarUrl: text('avatar_url'),
  fcmToken: text('fcm_token'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
})

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
    code: char('code', { length: 6 }).unique().notNull(),
    challengerId: uuid('challenger_id')
      .notNull()
      .references(() => users.id),
    opponentId: uuid('opponent_id').references(() => users.id),
    status: text('status', {
      enum: ['pending', 'accepted', 'expired', 'cancelled'],
    })
      .default('pending')
      .notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
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

export type User = typeof users.$inferSelect
export type UserStats = typeof userStats.$inferSelect
export type Challenge = typeof challenges.$inferSelect
export type Match = typeof matches.$inferSelect
export type BlinkEvent = typeof blinkEvents.$inferSelect
