# Match Word Progress Package — Current Build Through M8

Prepared for Ronna review before TestFlight.

This package is meant to be easier to review than one fast screen recording. It separates the general app progress from the details that are easy to miss: M6 voice/animation/disconnect behavior, Prize Room progress, and the free-trial/subscription gate.

## Start Here

1. Watch `videos/01-current-progress-m3-m8-plus-billing.mp4`
   - Current app flow: home, Prize Room, lobby, live stage, score/halftime/winner, subscription paywall.
2. Watch `videos/02-m6-host-voice-animation-disconnect.mp4`
   - Focused M6 video for Guy Smiley, sound settings, correct-answer cue, disconnect alarm, and halftime.
3. Listen to `audio/m6-host-voice-sample.mp3`
   - Short sample of the current male host voice placeholder.
4. Review the screenshots:
   - `screenshots/overview/` for the broad app flow.
   - `screenshots/m6-host-audio/` for M6 voice/animation/alarm proof.
   - `screenshots/billing-free-trial/` for trial/subscription UI.

## What Is Demonstrated

### M6 — Guy Smiley, Voice, Animations, Disconnect Alarm

- Guy Smiley host appears in the live game.
- Host and player busts animate so the stage feels alive.
- Host/audio cues are represented by a dedicated M6 video and voice sample.
- Disconnect alarm screenshot shows the full red overlay with “Hold on!” and “Keep Playing.”
- Sound settings show mute plus music/effects sliders.

### M7 — Character Polish

- Home screen shows Rosie’s character card with idle animation.
- Team A / Team B stage seats show character busts above the desks.
- The current app video now records with character art visible.

### M8 — Prize Room + Access/Billing Preparation

- Prize Room screen shows games played, games won, trophies, and prize shelves.
- Free-trial countdown appears on the home screen.
- Subscription paywall screen shows the $5.99/month messaging, Subscribe button, Restore Purchases, and “Not now.”

## Important Notes

- The media is captured from a Flutter web demo that uses the same app screens/widgets as the APK. Tiny rendering differences from Android are expected.
- The subscription screen is scaffolded for store setup. Real App Store/TestFlight purchase sheets are still part of the iOS/TestFlight phase.
- Trophy/prize art is placeholder-quality and can be replaced with final clay art later.
- The Android APKs are included only for reference/testing by someone with Android. Ronna can review the videos/screenshots on iPhone now.

## Included Android Builds

The latest Android builds are under `android-builds/` in the full folder copy.
They are intentionally excluded from the smaller review zip because Ronna is on
iPhone and the APKs make the zip much larger.

- `MatchWord-m8-phone-arm64-20260714.apk`
- `MatchWord-m8-phone-arm32-20260714.apk`
- `MatchWord-m8-LDPlayer-x86_64-20260714.apk`

## TestFlight (iOS install for Ronna)

- **One-time setup (click-by-click):** `docs/TestFlight-Setup-Notes.md`
- **Full guide (build, upload, troubleshooting):** `docs/TestFlight-Setup-Guide.md`

## Suggested Review Questions

- Does the app feel clear enough for a senior player?
- Is Guy Smiley’s voice/animation direction acceptable for this stage?
- Is the disconnect alarm understandable and reassuring?
- Does the Prize Room direction feel fun enough?
- Does the subscription/free-trial wording feel calm and not pushy?
