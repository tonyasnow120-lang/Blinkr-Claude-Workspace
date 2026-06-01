# App Store & Google Play Compliance Checklist

**Last Updated:** 2026-05-27

---

## Apple App Store

| Item | Status | Notes |
|------|--------|-------|
| App Transport Security (ATS) | ✅ Pass | `NSAllowsArbitraryLoads: false` in Info.plist |
| iOS Privacy Manifest (PrivacyInfo.xcprivacy) | ✅ Created | Camera + email declared; Required Reason APIs TBD |
| Associated Domains (Universal Links) | ✅ Created | `applinks:blinkr.app` in Runner.entitlements |
| AASA served at /.well-known/apple-app-site-association | ✅ Backend route | PRODUCTION_TODO: replace TEAM_ID placeholder |
| NSCameraUsageDescription | ✅ Pass | Present in Info.plist |
| No IDFA usage | ✅ Pass | Firebase Analytics default config does not collect IDFA; no ATT prompt required |
| Age Rating | ⚠️ TODO | Set "4+" in App Store Connect; see COPPA note in PRIVACY_COMPLIANCE.md |
| Sign In with Apple | ✅ Pass | Delegated to supabase_flutter; SHA-256 nonce enforced |
| PKCE on OAuth | ✅ Pass | Enforced by supabase_flutter built-in handler |
| Build obfuscation | ✅ Created | Run `make build-ios-release` — see apps/mobile/Makefile |
| Privacy Policy URL | ⚠️ TODO | Required in App Store Connect before submission |
| Screen recording protection (contest/result) | ✅ Pass | iOS handles this at OS level; FLAG_SECURE is Android-only |
| Certificate Pinning | ⚠️ Deferred v1.1 | Risk accepted — see SECURITY_AUDIT_REPORT.md |
| App Attest | ⚠️ Deferred v1.1 | P0 requirement for v1.1 — see SECURITY_AUDIT_REPORT.md |

---

## Google Play

| Item | Status | Notes |
|------|--------|-------|
| `android:allowBackup="false"` | ✅ Pass | Set in AndroidManifest.xml |
| `android:usesCleartextTraffic="false"` | ✅ Pass | Set in AndroidManifest.xml |
| Network Security Config | ✅ Pass | `network_security_config.xml` created |
| Digital Asset Links (assetlinks.json) | ✅ Backend route | PRODUCTION_TODO: replace sha256_cert_fingerprints |
| HTTPS App Links with `autoVerify="true"` | ✅ Pass | Set in AndroidManifest.xml |
| ProGuard / R8 rules | ✅ Pass | `proguard-rules.pro` — no blanket -keep on own code |
| Build obfuscation | ✅ Created | Run `make build-android-release` or `make build-appbundle-release` |
| Debug symbol maps | ✅ Pass | Written to `build/debug-info/` (gitignored) — store securely for crash symbolication |
| FLAG_SECURE on sensitive screens | ✅ Pass | contest_screen.dart + result_screen.dart |
| Target API level ≥ 34 | ⚠️ TODO | Confirm `targetSdkVersion` in build.gradle |
| Data Safety form | ⚠️ TODO | Must match PrivacyInfo.xcprivacy + Privacy Policy |
| Play Integrity API | ⚠️ Deferred v1.1 | P0 requirement for v1.1 — see SECURITY_AUDIT_REPORT.md |

---

## Release Build Process

```bash
# From apps/mobile/
make build-android-release    # Produces build/app/outputs/apk/release/app-release.apk
make build-appbundle-release  # Produces build/app/outputs/bundle/release/app-release.aab (preferred)
make build-ios-release        # Produces build/ios/ipa/blinkr.ipa
```

Store the `build/debug-info/` symbol maps in a secure location (e.g., S3 with restricted access) for crash symbolication. **Do not commit these files.**

---

## v1.1 P0 Requirements (Pre-release Blockers)

- [ ] Implement certificate pinning (H2)
- [ ] Implement App Attest (iOS) (GAP-6)
- [ ] Implement Play Integrity API (Android) (GAP-6)
- [ ] Replace Digital Asset Links SHA-256 placeholder with actual keystore fingerprint (GAP-9)
- [ ] Replace Apple App Site Association TEAM_ID placeholder (GAP-9)
- [ ] Verify Supabase dashboard OTP rate limits are configured (GAP-8)
- [ ] Complete Privacy Policy and link in App Store Connect / Play Store
- [ ] Complete Data Safety form (Google Play)
- [ ] Legal review: COPPA age gate sufficiency (GAP-21)
- [ ] Legal review: DPAs with Supabase, LiveKit, Firebase

---

## Final Pre-Submission Checklist

- [ ] Run `gitleaks detect --source .` → zero findings
- [ ] Run `pnpm audit --audit-level=high` in apps/backend → zero HIGH/CRITICAL
- [ ] Run `flutter pub outdated` in apps/mobile → no known CVEs in outdated packages
- [ ] Test Universal Links: `adb shell pm get-app-links com.blinkr.app` → `verified`
- [ ] Test FLAG_SECURE: open contest screen, run `adb shell screencap /sdcard/t.png` → black image
- [ ] Test auth guard: navigate to `/home` when logged out → redirects to welcome
- [ ] Test IDOR: POST to another user's match → 403
- [ ] Test body limit: POST 2 MB body → 413
