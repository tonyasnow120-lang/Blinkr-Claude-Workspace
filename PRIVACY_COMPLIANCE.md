# Privacy & Regulatory Compliance — Blinkr

**Last Updated:** 2026-05-27  
**Status:** REQUIRES LEGAL REVIEW BEFORE LAUNCH

---

## Biometric Data Assessment

Blinkr uses MediaPipe Face Mesh to compute the Eye Aspect Ratio (EAR) for blink detection.

### What is processed

- 468 facial landmark coordinates (x, y, z) are computed per frame on-device
- EAR value is derived and compared against a threshold (0.20)
- A binary blink event (`true`/`false` + timestamp + EAR value) is the only output sent to the server

### What is NOT stored or transmitted

- Raw camera frames: **NOT stored, NOT transmitted**
- Facial landmark coordinates: **NOT stored, NOT transmitted**
- EAR values beyond the match event: **NOT stored persistently**
- Biometric templates or identifiers: **NOT generated**

### Live Video (LiveKit WebRTC)

The opponent's camera feed is transmitted peer-to-peer via LiveKit WebRTC for the duration of a match. This is:
- Real-time only — not recorded or stored server-side (confirm with LiveKit room configuration — `emptyTimeout: 300`, no recording enabled)
- Disclosed in the Privacy Policy at [URL] — **REQUIRED before launch**
- Consented to by users at first match via [mechanism] — **REQUIRED before launch**

---

## Regulatory Analysis

| Regulation | Jurisdiction | Trigger | Obligation | Status |
|-----------|-------------|---------|-----------|--------|
| BIPA | Illinois, USA | Processing biometric identifiers | Written release + retention/destruction policy required IF biometric data is stored or transmitted | ✅ Not triggered — no biometric data stored or transmitted |
| GDPR Art. 9 | EU/EEA | Processing biometric data to uniquely identify | Explicit consent + DPA required IF biometric data is processed server-side | ✅ Not triggered — processing is on-device only |
| CCPA/CPRA | California, USA | Collecting biometric identifiers | Disclosure + opt-out rights IF collected | ✅ Not triggered — not collected |
| COPPA | USA | Users under 13 | Verifiable parental consent required | ⚠️ **REQUIRES LEGAL REVIEW** — no age gate implemented; see below |
| GDPR | EU/EEA | Processing personal data (email) | Lawful basis + DSR rights + Privacy Policy required | ⚠️ Privacy Policy required before launch |
| PIPEDA | Canada | Personal data collection | Privacy Policy + consent required | ⚠️ Privacy Policy required before launch |

---

## COPPA Compliance Gap

**Current state:** Blinkr's email OTP sign-up flow does not collect date of birth. There is no mechanism to prevent users under 13 from creating an account.

**Required before launch in USA:**
1. Add a date-of-birth field to the registration flow
2. Block account creation for users under 13 with a clear message
3. Consider parental consent flows for users aged 13–17 in applicable states

**Legal determination required:** Confirm with counsel whether the DOB gate is sufficient, or whether age verification (e.g., credit card verification) is required for COPPA compliance given the product's target demographic.

**Technical implementation target:** v1.0.1 (before App Store / Play Store submission)

---

## Data Inventory

| Data Type | Collection Point | Storage | Purpose | Retention |
|-----------|-----------------|---------|---------|-----------|
| Email address | OTP sign-in | Supabase Auth | Authentication | Until account deletion |
| Username / display name | Profile registration | `users` table | Game identity | Until account deletion |
| Avatar URL | Profile registration | `users` table | Game identity | Until account deletion |
| FCM token | Device registration | `users` table | Push notifications | Refreshed on each login |
| Blink event (timestamp + EAR value + type) | Match play | `blink_events` table | Adjudication | Until match deletion |
| Win/loss record | Match adjudication | `user_stats` table | Leaderboard | Until account deletion |
| LiveKit room (camera stream) | Match play | NOT stored — real-time only | Match video | Not retained |

---

## Legal Review Required Before Launch

- [ ] Counsel to confirm COPPA age gate is legally sufficient for US market
- [ ] Counsel to confirm Privacy Policy covers live video transmission (LiveKit)
- [ ] Counsel to confirm no BIPA obligation is triggered in target markets
- [ ] DPA (Data Processing Agreement) with Supabase, LiveKit, Firebase — obtain or confirm SaaS terms cover this
- [ ] GDPR DPA with Supabase (they provide a standard DPA — verify it covers your use case)
- [ ] Privacy Policy must be published at a URL before App Store / Play Store submission
- [ ] Cookie policy / tracking disclosure (if any analytics are enabled)
