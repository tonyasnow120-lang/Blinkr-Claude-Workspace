export const SIMULTANEOUS_BLINK_WINDOW_MS = 150

export interface BlinkRecord {
  playerId: string
  detectedAt: Date
  earValue: number
  eventType: 'blink' | 'gaze_break'
}

export interface AdjudicationResult {
  winnerId: string
  loserId: string
  reason: 'blink' | 'gaze_break' | 'simultaneous'
}

export function adjudicate(
  events: BlinkRecord[],
  playerOneId: string,
  playerTwoId: string,
): AdjudicationResult {
  if (events.length === 0 || events.length > 2) {
    throw new Error(`adjudicate requires 1 or 2 events, got ${events.length}`)
  }

  const otherPlayer = (id: string) => (id === playerOneId ? playerTwoId : playerOneId)

  if (events.length === 1) {
    const loser = events[0]
    return {
      loserId: loser.playerId,
      winnerId: otherPlayer(loser.playerId),
      reason: loser.eventType,
    }
  }

  // 2 events — sort ascending by detectedAt
  const [first, second] = [...events].sort(
    (a, b) => a.detectedAt.getTime() - b.detectedAt.getTime(),
  )

  const deltaMs = second.detectedAt.getTime() - first.detectedAt.getTime()

  if (deltaMs <= SIMULTANEOUS_BLINK_WINDOW_MS) {
    return {
      loserId: first.playerId,
      winnerId: otherPlayer(first.playerId),
      reason: 'simultaneous',
    }
  }

  return {
    loserId: first.playerId,
    winnerId: otherPlayer(first.playerId),
    reason: first.eventType,
  }
}
