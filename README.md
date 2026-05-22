# Blinkr

Real-time peer-to-peer staring contest app. On-device computer vision detects blinks via Eye Aspect Ratio; the first to blink loses. Built for a Gen-Z social audience — clean, minimal, no stranger matchmaking ever.

## Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| On-device ML | `mediapipe_face_mesh` + EAR algorithm |
| Live video | LiveKit (`livekit_client` Flutter + `livekit-server-sdk` Node) |
| State management | Riverpod |
| Navigation | `go_router` (deep-link challenge codes) |
| Backend | Node.js 20 + Fastify v4 + Drizzle ORM + PostgreSQL |
| Auth + Realtime | Supabase |
| Push notifications | Firebase Cloud Messaging |

## Repository structure

```
blinkr/
├── apps/
│   ├── mobile/          # Flutter app
│   └── backend/         # Fastify API
├── .github/workflows/   # CI + deploy
├── pnpm-workspace.yaml
└── .env.example
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.22
- [Node.js](https://nodejs.org/) 20
- [pnpm](https://pnpm.io/) 9 (`npm i -g pnpm`)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (for local Supabase)
- A LiveKit server (cloud or self-hosted) — [livekit.io](https://livekit.io)
- A Firebase project with FCM enabled

## Local setup

### 1. Clone and install

```bash
git clone <repo-url>
cd blinkr
pnpm install          # installs backend deps
cd apps/mobile
flutter pub get       # installs Flutter deps
```

### 2. Environment variables

```bash
cp .env.example apps/backend/.env
```

Fill in every value in `apps/backend/.env`:

| Variable | Where to get it |
|----------|----------------|
| `SUPABASE_URL` | Supabase project → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase project → Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase project → Settings → API |
| `SUPABASE_JWT_SECRET` | Supabase project → Settings → API → JWT Secret |
| `DATABASE_URL` | `postgresql://user:pass@host:5432/dbname` |
| `LIVEKIT_API_KEY` | LiveKit Cloud → Settings |
| `LIVEKIT_API_SECRET` | LiveKit Cloud → Settings |
| `LIVEKIT_WS_URL` | e.g. `wss://your-project.livekit.cloud` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON |
| `API_BASE_URL` | Your backend URL (local: `http://localhost:3000`) |

### 3. Database migrations

```bash
cd apps/backend
pnpm db:generate   # generate SQL migrations from schema
pnpm db:migrate    # apply migrations to your database
```

### 4. Flutter compile-time env vars

Pass Supabase credentials at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=API_BASE_URL=http://localhost:3000
```

### 5. Firebase setup

- Android: place `google-services.json` at `apps/mobile/android/app/google-services.json`
- iOS: place `GoogleService-Info.plist` at `apps/mobile/ios/Runner/GoogleService-Info.plist`
- Add the Firebase Flutter plugins to your `android/build.gradle` and `android/app/build.gradle` per the FlutterFire docs.

## Running locally

```bash
# Terminal 1 — backend API
pnpm dev

# Terminal 2 — Flutter app
cd apps/mobile
flutter run
```

## Deep links

Challenge invite links use the `blinkr://` scheme.

| Platform | Registration |
|----------|-------------|
| Android | `AndroidManifest.xml` intent filter (already configured) |
| iOS | `Info.plist` CFBundleURLTypes (already configured) |

A deep link `blinkr://match/ABC123` opens `JoinChallengeScreen` with the code pre-filled.

## Key constraints (enforced in code)

1. **No stranger matchmaking.** No route or queue that pairs unknown users.
2. **No video storage.** Video is never written to any persistent store.
3. **Challenge codes expire in 10 minutes.** Enforced server-side on every read.
4. `SIMULTANEOUS_BLINK_WINDOW_MS = 150` — named constant in `adjudicator.ts`.
5. `kBlinkEarThreshold = 0.20`, `kBlinkFrameDebounce = 2` — named constants in `ear_calculator.dart`.
6. **LiveKit rooms capped at 2 participants.** Hard-set at room creation.
7. **API envelope** — all responses are `{ data }` or `{ error: { code, message } }`.

## Running tests

```bash
# Flutter unit tests
cd apps/mobile
flutter test

# Backend type-check
cd apps/backend
pnpm build
```
