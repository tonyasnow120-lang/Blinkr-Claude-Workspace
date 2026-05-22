import { RoomServiceClient, AccessToken } from 'livekit-server-sdk'

// TODO: set env vars LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_WS_URL
const apiKey = process.env.LIVEKIT_API_KEY ?? ''
const apiSecret = process.env.LIVEKIT_API_SECRET ?? ''
const wsUrl = process.env.LIVEKIT_WS_URL ?? ''

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
  const token = new AccessToken(apiKey, apiSecret, {
    identity: userId,
    name: displayName,
  })
  token.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  })
  return token.toJwt()
}

export async function deleteRoom(roomName: string): Promise<void> {
  await roomService.deleteRoom(roomName)
}
