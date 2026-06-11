// Server-side Supabase Realtime broadcast via the HTTP API — no websocket
// join needed. Clients subscribe to the same topic with channel().onBroadcast.
// Do NOT log payloads — they may contain match state (GAP-18).

export async function broadcastEvent(
  topic: string,
  event: string,
  payload: Record<string, unknown> = {},
): Promise<void> {
  const url = process.env.SUPABASE_URL
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required')
  }

  const res = await fetch(`${url}/realtime/v1/api/broadcast`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      messages: [{ topic, event, payload, private: false }],
    }),
  })

  if (!res.ok) {
    throw new Error(`Realtime broadcast failed: HTTP ${res.status}`)
  }
}

export function matchTopic(matchId: string): string {
  return `match:${matchId}`
}

export function challengeTopic(challengeId: string): string {
  return `challenge:${challengeId}`
}
