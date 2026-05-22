import admin from 'firebase-admin'

// TODO: set env var GOOGLE_APPLICATION_CREDENTIALS pointing to your service account JSON
let app: admin.app.App | null = null

function getApp(): admin.app.App {
  if (!app) {
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    })
  }
  return app
}

export async function sendMatchInvite(
  fcmToken: string,
  challengerName: string,
  code: string,
): Promise<void> {
  await getApp().messaging().send({
    token: fcmToken,
    notification: {
      title: `${challengerName} challenges you to a stare-down!`,
      body: 'Tap to accept the Blinkr challenge.',
    },
    data: {
      type: 'challenge_invite',
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
      title: won ? 'You won the stare-down! 🏆' : 'You blinked! 😅',
      body: won ? 'Your opponent blinked first.' : 'Better luck next time.',
    },
    data: { type: 'match_result', result: won ? 'win' : 'loss' },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  })
}
