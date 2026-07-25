# TestFlight Setup — Match Word (Milestone 9)

**Click-by-click guide for MacBook**

This guide walks you through getting **Match Word** onto **TestFlight** so Ronna can install it on her iPhone. iOS builds must be done on a **Mac** with **Xcode**. The Linux dev machine cannot produce a signed IPA.

**Time estimate:** 2–4 hours the first time (mostly waiting on Apple). Repeat uploads are ~30 minutes.

---

## App identity (use these exact values)

| Item | Value |
|------|--------|
| App name (on home screen) | **Match Word** |
| Bundle ID | `com.matchword.matchWord` |
| Version (current) | `0.1.0` (build `1`) — from `app/pubspec.yaml` |
| Monthly subscription product ID | `matchword_monthly_599` ($5.99/mo) |
| Xcode project to open | `app/ios/Runner.xcworkspace` (not `.xcodeproj`) |

---

## Part 0 — Before you start

### What you need

- A **MacBook** running a recent macOS (Ventura / Sonoma / Sequoia).
- An **Apple ID** you control (personal or business).
- **Apple Developer Program** membership — **$99 USD/year**.
  - Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/)
  - Approval can take **24–48 hours** (sometimes same day).
- The Match Word project on the Mac (git clone, USB drive, or cloud sync).
- A real **Supabase** project URL + anon key for `app/.env`.
- Ronna’s **Apple ID email** (the one she uses on her iPhone).

### Install tools on the Mac (one-time)

1. **Xcode** — open the **App Store** on the Mac → search **Xcode** → **Get** / **Install**.
   - First launch: open **Xcode** from Applications → accept the license → wait for “Installing additional components…”
   - Menu bar: **Xcode → Settings… → Platforms** → confirm **iOS** is installed.
2. **Xcode command-line tools** — open **Terminal** and run:
   ```bash
   xcode-select --install
   ```
   If it says already installed, you are fine.
3. **Flutter** — follow [flutter.dev/docs/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos), then verify:
   ```bash
   flutter doctor
   ```
   Fix anything marked with ✗ (especially **Xcode** and **CocoaPods**).
4. **CocoaPods** (if `flutter doctor` asks for it):
   ```bash
   sudo gem install cocoapods
   ```

---

## Part 1 — Enroll in the Apple Developer Program

Skip this part if you are already enrolled and can sign in to App Store Connect.

1. In **Safari**, go to [developer.apple.com/programs](https://developer.apple.com/programs/).
2. Click **Enroll**.
3. Sign in with your **Apple ID**.
4. Choose account type:
   - **Individual** — simplest; your name appears as seller.
   - **Organization** — needs a D-U-N-S number; takes longer.
5. Complete identity verification and pay **$99/year**.
6. Wait for the approval email (“Welcome to the Apple Developer Program”).
7. After approval, open [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) and sign in.
   - ☐ You should see the **Apps** tab (not “Request Access”).

---

## Part 2 — Copy the project onto the Mac

1. Clone or copy the repo to the Mac, e.g.:
   ```bash
   cd ~/Projects
   git clone <your-repo-url> Multiplayer-Game-Real-Time-VoiceChat
   cd Multiplayer-Game-Real-Time-VoiceChat/app
   ```
2. Create the env file:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` in **TextEdit** or **VS Code** and set:
   ```
   SUPABASE_URL=https://YOUR-PROJECT.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   EASY_TEST_AUTH=false
   ```
   > **Production TestFlight:** set `EASY_TEST_AUTH=false` so the “Quick Test Sign-In” button is hidden.
4. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
5. Install iOS pods:
   ```bash
   cd ios
   pod install
   cd ..
   ```
6. Quick sanity check:
   ```bash
   flutter doctor
   flutter devices
   ```
   You should see at least one iOS device or simulator listed.

---

## Part 3 — Sign in to Xcode with your Apple Developer account

1. Open **Xcode** (Applications folder or Spotlight: ⌘ Space → type **Xcode**).
2. Menu bar: **Xcode → Settings…** (on older macOS: **Xcode → Preferences…**).
3. Click the **Accounts** tab.
4. Click **+** (bottom left) → **Apple ID…**
5. Sign in with the **same Apple ID** tied to your Developer Program membership.
6. Select your account in the list → under **Team**, you should see your team name and role **Admin** or **Agent**.
   - ☐ If no team appears, Developer enrollment is not complete yet.

---

## Part 4 — Configure signing in Xcode (click by click)

1. In **Finder**, go to:
   ```
   Multiplayer-Game-Real-Time-VoiceChat/app/ios/
   ```
2. **Double-click** `Runner.xcworkspace` (white Xcode icon — **not** `Runner.xcodeproj`).
3. Xcode opens. In the **left sidebar** (Project Navigator), click the blue **Runner** project icon at the very top.
4. In the centre column under **TARGETS**, click **Runner** (not RunnerTests).
5. Click the **Signing & Capabilities** tab at the top.
6. Under **Signing**:
   - ☑ Check **Automatically manage signing**.
   - **Team:** open the dropdown → select **your developer team** (not “None” / “Add an Account…”).
   - **Bundle Identifier** should read: `com.matchword.matchWord`
     - If Xcode shows a red error about the bundle ID being unavailable, someone else owns it — change only after agreeing a new ID with the client, then update App Store Connect to match.
7. Confirm **Release** signing (important for TestFlight):
   - Menu bar: **Product → Scheme → Edit Scheme…**
   - Left sidebar: **Archive**
   - **Build Configuration:** set to **Release** → **Close**
8. (Optional, for later billing) add In-App Purchase capability:
   - Still on **Signing & Capabilities** → click **+ Capability**
   - Search **In-App Purchase** → double-click to add
   - You do **not** need this for the first TestFlight smoke test unless you are testing real purchases.

---

## Part 5 — Create the app in App Store Connect

1. In **Safari**, go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/).
2. Sign in with your Developer Apple ID.
3. Click **Apps** (top navigation).
4. Click the **+** button (or **Add Apps** / **New App**).
5. Fill the form:
   - **Platforms:** ☑ **iOS**
   - **Name:** `Match Word` (App Store listing name; can differ slightly from home-screen name)
   - **Primary Language:** English (U.S.) or your preference
   - **Bundle ID:** open dropdown → select `com.matchword.matchWord`
     - If it is missing: go to [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list) → **+** → **App IDs** → **App** → Description `Match Word` → Bundle ID **Explicit** → `com.matchword.matchWord` → register → return to App Store Connect and refresh.
   - **SKU:** `matchword-001` (internal only; any unique string)
   - **User Access:** Full Access
6. Click **Create**.
7. You land on the app’s **App Store** page. That is normal — TestFlight is a separate tab.

---

## Part 6 — Build the release IPA

### Option A — Flutter command line (recommended)

1. Open **Terminal**.
2. Run:
   ```bash
   cd ~/Projects/Multiplayer-Game-Real-Time-VoiceChat/app
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ipa --release
   ```
3. Wait for **✓ Built IPA to** … a path like:
   ```
   build/ios/ipa/match_word.ipa
   ```
4. If the build fails on signing, open `Runner.xcworkspace` and fix **Part 4**, then retry.

### Option B — Archive from Xcode

1. Open `app/ios/Runner.xcworkspace` in Xcode.
2. Top toolbar: click the device menu (next to the Run ▶ button) → select **Any iOS Device (arm64)** (not a simulator).
3. Menu bar: **Product → Archive**.
4. Wait for the archive to finish → **Organizer** window opens automatically.
5. Skip to **Part 7** if using Organizer upload.

### Bump version for each new upload

Before every new TestFlight upload, increment the build number in `app/pubspec.yaml`:

```yaml
version: 0.1.0+2   # bump the number after +
```

Example progression: `0.1.0+1` → `0.1.0+2` → `0.1.0+3`.

---

## Part 7 — Upload the build to App Store Connect

### Method 1 — Xcode Organizer (after Archive or `flutter build ipa`)

1. In Xcode: **Window → Organizer** (or it opens after Archive).
2. Click **Archives** (top of Organizer).
3. Select the newest **Runner** / **Match Word** archive (today’s date).
4. Click **Distribute App** (blue button, right side).
5. **Select a method of distribution:** choose **App Store Connect** → **Next**.
6. **Select a destination:** **Upload** → **Next**.
7. Distribution options (defaults are usually fine):
   - ☑ Upload your app’s symbols… (recommended)
   - ☐ Manage Version and Build Number — leave unchecked unless you know you need it
   - **Next**
8. **Signing:** **Automatically manage signing** → **Next**.
9. Review the summary → **Upload**.
10. Wait for “Upload Successful” → **Done**.

### Method 2 — Transporter app (if you have only the `.ipa` file)

1. Install **Transporter** from the Mac App Store.
2. Open **Transporter** → sign in with your Developer Apple ID.
3. Drag `app/build/ios/ipa/match_word.ipa` into the window.
4. Click **Deliver**.
5. Wait for the green checkmark.

### After upload — processing wait

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) → **Apps** → **Match Word**.
2. Click the **TestFlight** tab (top).
3. Under **iOS Builds**, status will show **Processing** (usually **5–30 minutes**, sometimes up to an hour).
4. Refresh until status becomes **Ready to Submit** or shows a build number without “Processing”.
5. First-time builds may ask for **Export Compliance**:
   - Click the build → answer **App Encryption**
   - Match Word uses HTTPS only → typically select **No** for proprietary encryption (or use the standard exemption). If unsure, choose “Yes” and check “exempt” per Apple’s questionnaire.
6. If **Missing Compliance** appears on the build row, click it and complete the form.

---

## Part 8 — Add testers and invite Ronna

### Internal testers (fastest — up to 100, no Beta App Review)

Use this for Ronna if she is on your App Store Connect team, or for yourself first.

1. App Store Connect → **Match Word** → **TestFlight** tab.
2. Left sidebar: **Internal Testing**.
3. Click **+** next to **Internal Groups** (or open default **App Store Connect Users**).
4. Name the group: `Core testers`.
5. Click **+** next to **Testers** → add email addresses.
   - Add **your** Apple ID email first (smoke test).
   - Add **Ronna’s** Apple ID email.
6. Under **Builds**, click **+** → select the processed iOS build → **Add**.
7. Each tester receives an email: **“You're invited to test Match Word.”**

### External testers (if Ronna is not on your team)

1. **TestFlight** tab → left sidebar: **External Testing**.
2. Click **+** to create a group, e.g. `Ronna — iPhone`.
3. Click **+** next to **Testers** → enter Ronna’s email → **Add**.
4. Add the build to the group (**+** under Builds).
5. First external build requires **Beta App Review** (usually 24–48 hours):
   - Fill **Test Information**: description, feedback email, contact info.
   - **What to Test:** “Sign in, create character, join game, play one round, Prize Room.”
   - Submit for review.
6. After approval, Ronna gets the invite email.

### Public link (optional)

1. External group → enable **Public Link**.
2. Copy the link and send it in Freelancer chat.
3. Anyone with the link can join (up to your tester limit).

---

## Part 9 — What Ronna does on her iPhone

Send her these steps (or a short Loom if helpful):

1. Install **TestFlight** from the App Store (purple icon).
2. Open the email **“You're invited to test Match Word”** on the iPhone.
3. Tap **View in TestFlight** (or **Start Testing**).
   - If the link opens in Safari first, tap **Accept** → **Install**.
4. In TestFlight, tap **Install** next to Match Word.
5. When iOS asks, tap **Trust** / allow notifications (optional but helps with update prompts).
6. Open **Match Word** from the home screen (or from TestFlight → **Open**).
7. Create an account or sign in, build a character, and play.

**If she does not see the email:** check Spam; confirm the invite went to the **same Apple ID** she uses in Settings → [her name]. You can resend from App Store Connect → TestFlight → tester row → **Resend Invitation**.

---

## Part 10 — Subscription product (when you test billing)

The app already shows the paywall UI and uses product ID `matchword_monthly_599`. Store purchases are **not live** until you create the product in App Store Connect and wire StoreKit in code.

1. App Store Connect → **Match Word** → **Subscriptions** (left sidebar, under **Monetization**).
2. Click **+** → **Subscription Group** → name: `Match Word Premium` → **Create**.
3. Inside the group, click **+** → **Auto-Renewable Subscription**:
   - **Reference Name:** `Monthly`
   - **Product ID:** `matchword_monthly_599` (must match code exactly)
   - **Subscription Duration:** 1 month
   - **Price:** $5.99 USD (or equivalent tier)
4. Add localization (display name + description).
5. Submit the subscription for review with the app (or test in **Sandbox** first).
6. On the iPhone: **Settings → App Store → Sandbox Account** → sign in with a **Sandbox Tester** (create under App Store Connect → **Users and Access → Sandbox → Testers**).

> The in-app 5-day free trial is enforced in Supabase (`profiles` / `device_trials`). App Store introductory offers are a separate layer — align wording with Ronna before go-live.

---

## Part 11 — Repeat uploads (each new build)

1. Bump `version: 0.1.0+N` in `app/pubspec.yaml`.
2. `flutter build ipa --release` (or **Product → Archive**).
3. Upload via Organizer or Transporter.
4. Wait for processing in TestFlight.
5. Add the new build to the tester group (old builds stay available until you expire them).

TestFlight builds expire after **90 days**.

---

## Troubleshooting

| Problem | What to try |
|--------|-------------|
| **No signing certificate** | Xcode → Settings → Accounts → select team → **Manage Certificates…** → **+** Apple Development / Distribution. Or let “Automatically manage signing” create them. |
| **Bundle ID not in dropdown** | Register it at [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list), then retry App Store Connect. |
| **“Team has no devices”** | Not required for TestFlight; use **Any iOS Device (arm64)** archive, not a simulator build. |
| **Archive is greyed out** | Select **Any iOS Device (arm64)** as run destination, not a simulator. |
| **flutter build ipa fails** | Run `flutter doctor -v`; open `Runner.xcworkspace` and build once in Xcode (⌘B) to see clearer errors. |
| **Pod install fails** | `cd ios && pod repo update && pod install` |
| **Build stuck Processing** | Wait up to 60 minutes; check email for Apple compliance messages. |
| **Tester sees no app** | Confirm invite email matches Apple ID; build is added to their group; build finished processing. |
| **App crashes on launch** | Verify `app/.env` has valid `SUPABASE_URL` and `SUPABASE_ANON_KEY` before building. |

---

## Checklist — first TestFlight for Ronna

- [ ] Apple Developer Program active
- [ ] Xcode installed; signed in under **Accounts**
- [ ] `app/.env` filled; `EASY_TEST_AUTH=false`
- [ ] `Runner.xcworkspace` → **Automatically manage signing** + correct **Team**
- [ ] App created in App Store Connect with bundle `com.matchword.matchWord`
- [ ] `flutter build ipa --release` succeeded
- [ ] IPA uploaded; build **Ready** in TestFlight
- [ ] Export compliance answered
- [ ] Ronna added as internal or external tester; build assigned to group
- [ ] Ronna installed via TestFlight and can open the app

---

## Related docs

- Client progress package: `docs/client-deliverables/m8-progress-package/README.md`
- M6 host/audio manual test: `docs/Milestone 6 Test Guide.md`
- Supabase backend: `docs/Supabase Setup Guide.md`
