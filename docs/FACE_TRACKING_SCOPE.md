# Face Tracking Scope — Blink Detection + AR Lens Effects

Status: scoped 2026-06-12. Phases 1–2 approved for build pending go-ahead;
Phase 3 deferred.

## Problem

Two needs share one missing capability — real-time face data from the camera:

1. **Blink detection is not functional.** `BlinkDetector` (EAR math, debounce,
   event stream, backend POST) is fully wired, but nothing feeds it frames.
   No face-detection library is in the app. Matches currently cannot end by
   an actual detected blink.
2. **AR lens effects** (Snapchat-style) were requested as match power-ups.

The central technical constraint: **LiveKit owns the camera.** Flutter cannot
open a second camera session for ML processing, and the LiveKit Flutter SDK
has no working per-frame callback API (open issues
[#670](https://github.com/livekit/client-sdk-flutter/issues/670),
[#880](https://github.com/livekit/client-sdk-flutter/issues/880)). The
documented workaround is polling `captureFrame()` on the track's underlying
`MediaStreamTrack` — usable at ~8–10 Hz with known CPU costs on low-end
devices.

## Phase 1 — Blink detection (no paid SDK, ~2–4 days + device testing)

Use `google_mlkit_face_detection` with `enableClassification: true`, which
returns `leftEyeOpenProbability` / `rightEyeOpenProbability` per face —
simpler and more robust than reconstructing EAR from landmarks. All
processing is on-device.

Pipeline:

```
LiveKit LocalVideoTrack ──captureFrame() @ ~8–10 Hz──► decode
  ──► ML Kit FaceDetector (classification mode)
  ──► eyeOpenProbability < 0.35 ──► BlinkDetector ──► POST /matches/:id/blink
```

Work items:
- Add `google_mlkit_face_detection` to pubspec (Android minSdk 21+ and iOS
  targets already satisfied; CI regenerates platform dirs so no workflow
  changes expected).
- New `core/blink_detection/face_tracking_service.dart`: owns the capture
  timer, frame decode, ML Kit detector, and feeds `BlinkDetector` via a new
  probability-based entry point (EAR path kept for future landmark sources).
- `MatchNotifier`: start tracking when phase becomes `live` and video is
  connected; stop on result/abandon/dispose.
- Tune debounce for low frame rate (at 8 Hz a 150–300 ms blink spans 1–2
  frames → debounce 1, threshold ~0.35).

Risks:
- `captureFrame()` polling cost on low-end Android — mitigate by capping at
  8 Hz and skipping frames when a detection is still in flight.
- Very fast blinks could fall between frames — the open-eye probability
  drops during partial closure, which widens the detection window; needs
  real-device tuning.
- If LiveKit video fails to connect, blink detection is unavailable (same
  as today); the match still resolves via abandon/disconnect.

## Phase 2 — 2D lens power-ups, receiver-side (~3–5 days after Phase 1)

Key insight: `captureFrame()` also works on **remote** tracks. Lens effects
can be rendered on the *viewer's* device, anchored to the face in the video
feed, without ever modifying the published stream — no AR SDK, no native
code.

- ML Kit (landmark mode) gives face bounding box + eye/nose/mouth positions.
- Map frame coordinates → widget space; draw lens graphics (line-art style
  to match the app aesthetic: spinning hypno-eyes, tears, laser eyes) with
  CustomPaint over `RemoteVideoFeed` / `CameraFeed`.
- Interpolate anchor positions between detections (~8 Hz detection, 60 fps
  rendering with lerp) so the lens tracks smoothly.
- Ships as new power-up types on the existing system (`match.powerup`
  broadcast; old clients ignore unknown types — already handled).

Limitation to accept: the lens is rendered by the receiving client, so each
side computes its own overlay. Both players still *see* lenses; they are
just not burned into the video. This is invisible to users in practice.

## Phase 3 — True burned-in AR lenses (deferred, v1.2+)

Snapchat-quality 3D masks rendered into the published video require
modifying frames before they reach WebRTC — a custom native capturer
(Kotlin + Swift) or a commercial AR SDK bridged into flutter_webrtc:

| Option | Flutter support | Pricing | Risk |
|---|---|---|---|
| Banuba | First-party `banuba_sdk` on pub.dev | Custom MAU-based, no public list | Cost opacity |
| DeepAR | Community plugin only, not vendor-supported | From ~$25/mo MAU-based | Acquired by Zalando 2025; plugin maintenance uncertain |

Either path is 2–4 weeks of native integration work on top of license cost,
and the LiveKit Flutter SDK's lack of a processor API means custom frame
injection plumbing regardless of vendor. Recommendation: ship Phases 1–2,
revisit only if receiver-side lenses prove insufficient.

## Recommended order

1. Phase 1 — fixes the core game mechanic (real blink detection).
2. Phase 2 — delivers "AR lens" power-ups with zero licensing cost.
3. Re-evaluate Phase 3 after user feedback.
