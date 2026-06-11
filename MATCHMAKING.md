# Blinkr Matchmaking

Five ways for two players to land in the same match lobby. All flows ride the
existing Supabase auth session (JWT attached by the Dio interceptor — no
re-authentication anywhere) and converge on `/match/:matchId/lobby`.

> **Architecture note.** The original spec assumed Supabase Edge Functions.
> Blinkr already has a dedicated Fastify backend (`apps/backend`) that fronts
> the same Supabase Postgres with Drizzle, global JWT verification, rate
> limiting, and security logging — so the "edge function" responsibilities are
> implemented as backend routes instead of a parallel Functions stack:
>
> | Spec (edge function)                | Actual endpoint                          |
> |-------------------------------------|------------------------------------------|
> | `create-challenge-link`             | `POST /v1/challenges` (kind: `link`)     |
> | `verify-challenge-token`            | `GET /v1/challenges/:code` + `POST /v1/challenges/:code/accept` |
> | `match-contacts`                    | `POST /v1/contacts/match`                |
> | `create-qr-token`                   | `POST /v1/challenges` (kind: `qr`)       |
> | `proximity-search`                  | `GET /v1/proximity/nearby`               |
>
> Challenge links use single-use, TTL-bound, 45-bit random codes
> (`/match/:code`) rather than signed JWT query params — equivalent security
> properties (unguessable, expiring, one-time) and they reuse the
> universal-link configuration that already exists for the app.

## The 5 flows

### 1. Deep Link Challenge
- **Create**: `POST /v1/challenges` `{ kind: 'link' }` → `{ code, deepLink, expiresAt }`
  (15-minute TTL). The share screen opens the native share sheet
  (`share_plus`) with `https://blinkr.app/match/<CODE>`.
- **Join**: tapping the link opens the app (iOS Universal Links / Android App
  Links, `app_links` package — already wired); the router validates the code
  format and `JoinChallengeScreen` auto-accepts via
  `POST /v1/challenges/:code/accept`. Acceptance is atomic
  (`UPDATE ... WHERE used_at IS NULL AND expires_at > now()`) — a second
  acceptor gets 409.
- **Both into the lobby**: the accept handler creates the match + LiveKit room
  and broadcasts `challenge.accepted { matchId }` on Realtime topic
  `challenge:<challengeId>`. The waiting challenger receives it, fetches its
  own LiveKit token over authenticated HTTP (`POST /v1/matches/:id/token` —
  tokens are never sent over broadcast), and both navigate to the lobby.
- Expired/used codes → "Challenge has already been accepted or expired"
  (mapped to `MatchmakingAlreadyAccepted` / `MatchmakingExpired`).

### 2. Contacts
- `ContactsService` shows an in-app privacy disclosure **before** the OS
  permission prompt, reads contacts (`flutter_contacts`), normalises numbers
  to E.164 (preferring the platform-normalised form), hashes each with
  SHA-256 **on-device**, and posts only hashes to `POST /v1/contacts/match`.
- The backend returns users whose `phone_hash` matches AND who have
  `allow_contact_discovery = true`. Results are merged with device contact
  names locally and cached in `SharedPreferences` for 24 h (manual refresh
  button on the screen).
- To be discoverable, a user registers their own number's hash via
  `PUT /v1/contacts/phone-hash` (hash computed on-device;
  `ContactsService.registerMyNumber`). Opt-out:
  `PUT /v1/contacts/discovery { allow: false }`.
- Challenging a contact creates a **targeted** challenge
  (`kind: 'contact', opponentId`) — only that user can accept it — and sends
  an FCM invite if they have a token registered.

### 3. Username Search + Friends
- `GET /v1/users/search?q=<prefix>` — ILIKE prefix match, limit 20, each row
  annotated with win/loss and the caller's friendship status (drives the
  Add Friend / Requested / Challenge / Blocked button).
- `friendships` table (`pending`/`accepted`/`blocked`, unique pair, RLS:
  participants only). Sending a request to someone who already requested you
  auto-accepts. Endpoints: `POST /v1/friends/requests`,
  `POST /v1/friends/requests/:id/accept|decline`,
  `POST /v1/friends/:userId/block`, `DELETE /v1/friends/:userId`,
  `GET /v1/friends` (accepted list + incoming requests).
- Challenge = targeted challenge (`kind: 'friend'`) + FCM push; the
  challenger waits on the same Realtime-driven screen as flow 1.

### 4. QR Code
- Display side (`/qr`): creates a challenge with `kind: 'qr'` (**60-second
  TTL**), renders the standard deep link as a QR (`qr_flutter`), shows a
  countdown and auto-regenerates a fresh code on expiry (the old one is
  cancelled). Leaving the screen cancels the pending challenge.
- Scanner side (`/qr/scan`): `mobile_scanner` with camera permission
  handling; accepts both `https://blinkr.app/match/<CODE>` and
  `blinkr://match/<CODE>`, validates the code format, shows a brief
  confirmation, then runs the exact same join flow as flow 1.

### 5. GPS Radius (Nearby)
- PostGIS. Coordinates live in `user_locations` (separate table, **deny-all
  RLS** — only the backend's service-role connection can read them).
- Toggle ON → first-use privacy disclosure, then `PUT /v1/proximity/location`
  every 30 s and `GET /v1/proximity/nearby?lat&lng&radiusMeters=500`, which
  returns username/avatar/record/**distance in meters only** (never
  coordinates), max 20, ordered by distance, freshness window 2 minutes.
- Toggle OFF, screen close, or 10 minutes elapsed →
  `DELETE /v1/proximity/location` erases the coordinates (not just a flag).

## Shared lobby
Every flow lands on `/match/:matchId/lobby` with
`{ matchId, livekitToken, livekitUrl, livekitRoomName }` as `extra`.
The lobby shows both avatars with live ready indicators
(`match.player_ready` broadcast). `POST /v1/matches/:id/ready` records a
per-player flag; **the countdown starts only when both players are ready**
(atomic status flip prevents double-starts), then the server transitions the
match to `live` when the countdown elapses and broadcasts `match.live`
(blink events are rejected until then).

## Realtime events (server → client, Supabase Realtime broadcast)
| Topic | Event | Payload |
|---|---|---|
| `challenge:<challengeId>` | `challenge.accepted` | `{ matchId }` |
| `match:<matchId>` | `match.player_ready` | `{ userId }` |
| `match:<matchId>` | `match.countdown_start` | `{ startsAt }` |
| `match:<matchId>` | `match.live` | `{}` |
| `match:<matchId>` | `match.result` | `{ winnerId, loserId, reason }` |
| `match:<matchId>` | `match.abandoned` | `{}` |

Server-side sends use the Realtime HTTP broadcast API
(`services/realtimeService.ts`) with the service-role key — this replaced the
previous stub, so the countdown/result events now actually fire.

## DB schema changes
Migrations in `apps/backend/db/migrations/` (run in order in the Supabase SQL
editor; `004_proximity.sql` needs the `postgis` extension enabled):

1. `001_contact_discovery.sql` — `users.phone_hash` (indexed),
   `users.allow_contact_discovery`
2. `002_friendships.sql` — `friendships` table + RLS
3. `003_challenge_kind_match_ready.sql` — `challenges.kind`,
   `matches.player_one_ready/player_two_ready`
4. `004_proximity.sql` — PostGIS, `user_locations` + deny-all RLS

## Error handling
`MatchmakingError` (sealed): `MatchmakingExpired`, `MatchmakingAlreadyAccepted`,
`MatchmakingNotFound`, `MatchmakingNetworkError`, `MatchmakingPermissionDenied`,
`MatchmakingUnknown`. `MatchmakingNotifier` phases:
`idle → creating → waiting → ready | error`.

## Push notifications
Backend sends FCM invites for targeted challenges
(`notificationService.sendMatchInvite`, payload: type enum + challenge code,
no PII/JWT). **Mobile-side FCM handling remains stubbed** — `firebase_messaging`
was deliberately deferred to v1.1 for flutter_webrtc compatibility
(`fcm_handler.dart`); when it lands, `challenge_invite` notifications should
deep-link to `/match/<code>`. Friends-list online presence (Supabase Presence)
is likewise deferred.

## Testing each flow locally
1. **Link**: Home → "Challenge a friend" → share → open link on device B (or
   `adb shell am start -a android.intent.action.VIEW -d "https://blinkr.app/match/<CODE>"`).
   Device A should auto-advance when B accepts. Also verify: accepting twice →
   409 snackbar; waiting >15 min → expired error.
2. **Contacts**: register the hash on device B
   (`ContactsService.registerMyNumber`), add B's number to A's contacts, open
   Contacts screen on A → B appears → Challenge → push lands on B (once FCM is
   wired; until then B finds the invite via the deep link code).
3. **Friends**: search username → Add Friend → accept on B (Friends screen) →
   Challenge from list.
4. **QR**: device A `/qr`, device B `/qr/scan`, scan → both reach lobby in
   <5 s. Wait 60 s without scanning → QR regenerates.
5. **Nearby**: both devices toggle visibility within 500 m (or spoof
   locations) → both appear with distance → challenge. Turn toggle off →
   row disappears for the other device within 2 min (staleness) or
   immediately on refresh.
