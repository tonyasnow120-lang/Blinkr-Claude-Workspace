import { RoomServiceClient, AccessToken } from 'livekit-server-sdk'

// Explicit validation at startup — fail fast rather than silently using empty strings (H6)
const apiKey = process.env.LIVEKIT_API_KEY
const apiSecret = process.env.LIVEKIT_API_SECRET
const wsUrl = process.env.LIVEKIT_WS_URL

if (!apiKey || !apiSecret || !wsUrl) {
  throw new Error('LIVEKIT_API_KEY, LIVEKIT_API_SECRET, and LIVEKIT_WS_URL are required')
}

const PARTICIPANT_TOKEN_TTL_SECONDS = 900 // 15-minute TTL (H8)

const roomService = new RoomServiceClient(wsUrl, apiKey, apiSecret)

export async function createRoom(matchId: string): Promise<string> {
  const roomName = `match-${matchId}`
  await roomService.createRoom({
    name: roomName,
    maxParticipants: 2,
    emptyTimeout: 300,
  })
  return roomName
}

export function createParticipantToken(
  roomName: string,
  userId: string,
  displayName: string,
): string {
  const token = new AccessToken(apiKey!, apiSecret!, {
    identity: userId,
    name: displayName,
    ttl: PARTICIPANT_TOKEN_TTL_SECONDS,
  })
  token.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: false, // Data channel not needed; reduces attack surface
  })
  return token.toJwt()
}

export async function deleteRoom(roomName: string): Promise<void> {
  await roomService.deleteRoom(roomName)
}
