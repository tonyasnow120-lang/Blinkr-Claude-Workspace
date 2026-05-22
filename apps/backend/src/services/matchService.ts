import { eq, or, and, desc } from 'drizzle-orm'
import type { DrizzleDB } from '../db/index.js'
import { matches, blinkEvents, userStats, users, challenges } from '../db/schema.js'
import { adjudicate, type BlinkRecord } from '../lib/adjudicator.js'
import { Errors } from '../lib/errors.js'

export async function createMatch(
  db: DrizzleDB,
  challengeId: string,
  playerOneId: string,
  playerTwoId: string,
  livekitRoomName: string,
) {
  const [match] = await db
    .insert(matches)
    .values({ challengeId, playerOneId, playerTwoId, livekitRoomName })
    .returning()
  return match
}

export async function getMatchById(db: DrizzleDB, matchId: string) {
  const [match] = await db
    .select()
    .from(matches)
    .where(eq(matches.id, matchId))
    .limit(1)

  if (!match) throw Errors.notFound('Match')
  return match
}

export async function getMatchesForUser(
  db: DrizzleDB,
  userId: string,
  limit: number,
  offset: number,
) {
  return db
    .select()
    .from(matches)
    .where(or(eq(matches.playerOneId, userId), eq(matches.playerTwoId, userId)))
    .orderBy(desc(matches.createdAt))
    .limit(limit)
    .offset(offset)
}

export async function processBlinkAndAdjudicate(
  db: DrizzleDB,
  matchId: string,
  playerId: string,
  detectedAt: Date,
  earValue: number,
  eventType: 'blink' | 'gaze_break',
) {
  const match = await getMatchById(db, matchId)

  if (match.status !== 'live') {
    throw Errors.validation('Match is not in live state')
  }

  await db.insert(blinkEvents).values({
    matchId,
    playerId,
    detectedAt,
    earValue: earValue.toString(),
    eventType,
  })

  const events = await db
    .select()
    .from(blinkEvents)
    .where(eq(blinkEvents.matchId, matchId))

  if (events.length > 2) return null

  const records: BlinkRecord[] = events.map((e) => ({
    playerId: e.playerId,
    detectedAt: e.detectedAt,
    earValue: Number(e.earValue),
    eventType: e.eventType as 'blink' | 'gaze_break',
  }))

  const result = adjudicate(records, match.playerOneId, match.playerTwoId)
  const endedAt = new Date()
  const startedAt = match.startedAt ?? match.createdAt
  const durationMs = endedAt.getTime() - startedAt.getTime()

  await db.transaction(async (tx) => {
    await tx
      .update(matches)
      .set({
        status: 'completed',
        winnerId: result.winnerId,
        loserId: result.loserId,
        resultReason: result.reason === 'simultaneous' ? 'blink' : result.reason,
        endedAt,
        durationMs,
      })
      .where(eq(matches.id, matchId))

    await updateStats(tx, result.winnerId, result.loserId)
  })

  return result
}

async function updateStats(
  tx: DrizzleDB,
  winnerId: string,
  loserId: string,
) {
  const [winnerStats] = await tx
    .select()
    .from(userStats)
    .where(eq(userStats.userId, winnerId))
    .limit(1)

  const newStreak = (winnerStats?.currentStreak ?? 0) + 1
  const longestStreak = Math.max(newStreak, winnerStats?.longestStreak ?? 0)

  await tx
    .update(userStats)
    .set({
      wins: (winnerStats?.wins ?? 0) + 1,
      currentStreak: newStreak,
      longestStreak,
      updatedAt: new Date(),
    })
    .where(eq(userStats.userId, winnerId))

  const [loserStats] = await tx
    .select()
    .from(userStats)
    .where(eq(userStats.userId, loserId))
    .limit(1)

  await tx
    .update(userStats)
    .set({
      losses: (loserStats?.losses ?? 0) + 1,
      currentStreak: 0,
      updatedAt: new Date(),
    })
    .where(eq(userStats.userId, loserId))
}
