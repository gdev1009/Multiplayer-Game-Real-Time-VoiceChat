# Store release notes — Match Word 1.0.0

Production cleanup completed 2026-07-14.

## Removed from shipping app
- Quick Test Sign-In UI and all `quickTestSignIn` / `EASY_TEST_AUTH` code
- Test account credentials from the binary
- Milestone / scaffolding comment noise in shipping Dart sources

## Kept (internal tools only)
- `lib/demo_*.dart` — not linked from `main.dart`; used only with `-t` for recordings

## Build optimizations
- R8 minify + resource shrink (`isMinifyEnabled` / `isShrinkResources`)
- Dart obfuscation (`--obfuscate`) + split debug symbols
- Split-per-ABI APKs
- `android:allowBackup="false"`, `usesCleartextTraffic="false"`
- Version bumped to **1.0.0+1**

## Artifacts
| File | Use |
|------|-----|
| `apks/MatchWord-store-phone-arm64-20260714.apk` | Phones (arm64) |
| `apks/MatchWord-store-phone-arm32-20260714.apk` | Older 32-bit phones |
| `apks/MatchWord-store-LDPlayer-x86_64-20260714.apk` | Emulators |
| `apks/MatchWord-store-20260714.aab` | **Google Play** upload |

## Before App Store / Play publish
1. Create a **release keystore** and replace debug signing in `android/app/build.gradle.kts`.
2. Wire real StoreKit / Play Billing (paywall still shows a calm “coming soon” until products go live).
3. Confirm Supabase production project + schema migrations are applied.
4. iOS: follow `docs/TestFlight Setup.md` on a Mac with Apple Developer access.
