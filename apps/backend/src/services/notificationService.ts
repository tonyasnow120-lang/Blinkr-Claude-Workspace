import admin from 'firebase-admin'
import { maskEmail } from './securityLogger.js'

// Credential loaded from environment — never from a committed JSON file (GAP-7)
let app: admin.app.App | null = null

function getApp(): admin.app.App {
  if (!app) {
    const credJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
    if (!credJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON environment variable is required')
    }
    app = admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(credJson)),
    })
  }
  return app
}

// Valid notification type enum — validated on the mobile client before routing (GAP-7)
export type NotificationType = 'challenge_invite' | 'match_result'

export async function sendMatchInvite(
  fcmToken: string,
  challengerName: string,
  code: string,
): Promise<void> {
  // FCM payload contains NO JWT, NO session data, NO PII — only type enum + public code (GAP-7)
  await getApp().messaging().send({
    token: fcmToken,
    notification: {
      title: `${challengerName} challenges you to a stare-down!`,
      body: 'Tap to accept the Blinkr challenge.',
    },
    data: {
      type: 'challenge_invite' satisfies NotificationType,
      code,
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  })
}

export async function sendMatchResult(
  fcmToken: string,
  won: boolean,
): Promise<void> {
  await getApp().messaging().send({
    token: fcmToken,
    notification: {
      title: won ? 'You won the stare-down!' : 'You blinked!',
      body: won ? 'Your opponent blinked first.' : 'Better luck next time.',
    },
    data: {
      type: 'match_result' satisfies NotificationType,
      result: won ? 'win' : 'loss',
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  })
}
