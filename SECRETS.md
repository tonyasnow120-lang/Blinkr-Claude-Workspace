# Required Secrets & Environment Variables

All variables listed here must be set as environment variables or in `.env` (gitignored).
**Never commit actual values to the repository.**

---

## Backend (`apps/backend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | ✅ | Supabase project URL (e.g., `https://xxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | ✅ | Supabase anon/public key — safe to expose in browser, but not in server-side code |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | Supabase service_role key — grants full DB access, bypasses RLS. **Never expose client-side.** |
| `SUPABASE_JWT_SECRET` | ✅ | JWT secret from Supabase project settings (used to verify user tokens) |
| `DATABASE_URL` | ✅ | PostgreSQL connection string (from Supabase → Settings → Database) |
| `LIVEKIT_API_KEY` | ✅ | LiveKit Cloud API key |
| `LIVEKIT_API_SECRET` | ✅ | LiveKit Cloud API secret — keep this server-side only |
| `LIVEKIT_WS_URL` | ✅ | LiveKit WebSocket URL (e.g., `wss://xxx.livekit.cloud`) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | ✅ | Full Firebase service account JSON as a single-line string. Load the JSON file contents into this variable. **Never commit the `.json` file.** |
| `ALLOWED_ORIGINS` | ✅ | Comma-separated list of allowed CORS origins (e.g., `https://blinkr.app,https://www.blinkr.app`) |
| `APP_BASE_URL` | ✅ | Base URL for HTTPS deep links (e.g., `https://blinkr.app`) |
| `PORT` | Optional | HTTP port (default: 3000) |

---

## Mobile (`apps/mobile` — build-time via `--dart-define-from-file`)

Create `apps/mobile/.env.dart-define` (gitignored):

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | ✅ | Same as backend SUPABASE_URL |
| `SUPABASE_ANON_KEY` | ✅ | Supabase anon key — safe for mobile builds |

---

## CI/CD Secrets

Set these in your GitHub repository secrets (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `SUPABASE_SERVICE_ROLE_KEY` | For database migrations in CI |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | For backend deployment with FCM |
| `LIVEKIT_API_KEY` | For integration tests |
| `LIVEKIT_API_SECRET` | For integration tests |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore for Play Store signing |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |
| `IOS_CERTIFICATE_BASE64` | Base64-encoded iOS distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded provisioning profile |

---

## Play Integrity (v1.1 — GAP-6)

| Variable | Description |
|----------|-------------|
| `PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON` | Google service account with `playintegrity.googleapis.com` access |

---

## Pin Rotation Procedure (v1.1 — H2)

When the server TLS certificate rotates:
1. Extract the new SPKI SHA-256 fingerprint: `openssl s_client -connect api.blinkr.app:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64`
2. In `api_client.dart`, set the NEW fingerprint as `PRIMARY_PIN` and the OLD fingerprint as `BACKUP_PIN`
3. Ship the app update and maintain a 30-day overlap window before removing the old `BACKUP_PIN`
4. Remove the old pin after the overlap window
