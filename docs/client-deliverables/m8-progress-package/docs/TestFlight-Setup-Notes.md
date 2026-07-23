# TestFlight Setup — Match Word (Milestone 9)

Short reference for getting Match Word onto TestFlight. **One-time setup** below is
click-by-click on a MacBook. For build/upload/troubleshooting, see
`TestFlight-Setup-Guide.md` in this same folder.

> iOS builds cannot be signed on Linux. Run all steps on a **Mac** with **Xcode**.

---

## App identity

| Item | Value |
|------|--------|
| Home-screen name | **Match Word** |
| Bundle ID | `com.matchword.matchWord` |
| Xcode file to open | `app/ios/Runner.xcworkspace` |
| Version (current) | `0.1.0+1` in `app/pubspec.yaml` |
| Monthly product ID | `matchword_monthly_599` ($5.99/mo) |

---

## One-time setup (click by click on MacBook)

Do these steps **once**. After this, you only repeat **Build & upload** for each new TestFlight version.

**Time:** about 2–4 hours the first time (mostly waiting on Apple approval).

---

### Step 1 — Install Xcode and developer tools

1. On the MacBook, open the **App Store** (dock icon or Spotlight: ⌘ Space → **App Store**).
2. Search **Xcode** → click **Get** / **Install** (large download; can take 30+ minutes).
3. When finished, open **Xcode** from **Applications**.
4. If prompted, click **Agree** on the license → wait for **Installing additional components…** to finish.
5. Menu bar: **Xcode → Settings…** → **Platforms** tab → confirm **iOS** is listed and installed.
6. Open **Terminal** (Applications → Utilities → Terminal) and run:
   ```bash
   xcode-select --install
   ```
   - If it says *command line tools are already installed*, continue.
7. Install **Flutter** for macOS: [flutter.dev/docs/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos)
8. In Terminal, verify:
   ```bash
   flutter doctor
   ```
   - Fix any ✗ items. If CocoaPods is missing:
     ```bash
     sudo gem install cocoapods
     ```

☐ **Checkpoint:** `flutter doctor` shows Xcode and CocoaPods OK.

---

### Step 2 — Enroll in the Apple Developer Program

Skip if you already have access to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) and see the **Apps** tab.

1. Open **Safari** → go to [developer.apple.com/programs](https://developer.apple.com/programs/).
2. Click **Enroll** (top right).
3. Click **Start Your Enrollment** → sign in with your **Apple ID**.
4. Choose account type:
   - **Individual** — fastest; your name is the seller name.
   - **Organization** — requires a D-U-N-S number; allow extra days.
5. Complete the form (legal name, address, phone).
6. Pay **$99 USD/year**.
7. Wait for Apple’s email: **“Welcome to the Apple Developer Program.”** (Often 24–48 hours.)
8. After approval, open [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) and sign in.
   - ☐ You should see **Apps** in the top menu — not “Request Access.”

☐ **Checkpoint:** App Store Connect opens and shows **Apps**.

---

### Step 3 — Put the Match Word project on the Mac

1. Copy or clone the repo onto the Mac, e.g.:
   ```bash
   cd ~/Projects
   git clone <your-repo-url> Multiplayer-Game-Real-Time-VoiceChat
   cd Multiplayer-Game-Real-Time-VoiceChat/app
   ```
2. Create the environment file:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` in **TextEdit** or **VS Code** and set real values:
   ```
   SUPABASE_URL=https://YOUR-PROJECT.supabase.co
   SUPABASE_ANON_KEY=your-anon-public-key
   EASY_TEST_AUTH=false
   ```
   > For TestFlight, keep `EASY_TEST_AUTH=false` so testers use the real sign-in flow.
4. Install dependencies:
   ```bash
   flutter pub get
   cd ios
   pod install
   cd ..
   ```
5. Confirm Flutter sees iOS:
   ```bash
   flutter doctor
   flutter devices
   ```

☐ **Checkpoint:** `pod install` finished with no errors; `flutter devices` lists iOS.

---

### Step 4 — Add your Apple Developer account to Xcode

1. Open **Xcode**.
2. Menu bar: **Xcode → Settings…** (older macOS: **Preferences…**).
3. Click **Accounts** (top of the window).
4. Click **+** (bottom left) → **Apple ID…**
5. Sign in with the **same Apple ID** used for the Developer Program.
6. In the left list, click your Apple ID.
7. On the right, under **Team**, confirm your team name appears with role **Admin** or **Agent**.
   - If **Team** is empty → Developer enrollment is not finished yet (go back to Step 2).

☐ **Checkpoint:** Your developer **Team** appears in Xcode Accounts.

---

### Step 5 — Configure code signing (Signing & Capabilities)

1. In **Finder**, open:
   ```
   Multiplayer-Game-Real-Time-VoiceChat/app/ios/
   ```
2. **Double-click** `Runner.xcworkspace` (opens Xcode — use this file, **not** `Runner.xcodeproj`).
3. In Xcode’s **left sidebar**, click the blue **Runner** icon at the top (Project Navigator).
4. In the centre panel, under **TARGETS**, click **Runner** (single-click — not RunnerTests).
5. Click the **Signing & Capabilities** tab (top of centre panel).
6. Under **Signing**:
   - ☑ Turn on **Automatically manage signing**.
   - **Team:** click the dropdown → choose **your developer team** (not “None”).
   - **Bundle Identifier:** must be exactly:
     ```
     com.matchword.matchWord
     ```
   - Wait a few seconds. Xcode should show **Signing Certificate** and **Provisioning Profile** without red errors.
7. Set **Archive** to use Release builds (required for TestFlight):
   - Menu bar: **Product → Scheme → Edit Scheme…**
   - Left sidebar: click **Archive**
   - **Build Configuration:** choose **Release**
   - Click **Close**
8. *(Optional — for real subscription testing later)* On **Signing & Capabilities**:
   - Click **+ Capability** (top left of that tab)
   - Search **In-App Purchase** → double-click to add
   - Skip this for the very first TestFlight smoke test if you are not testing purchases yet.

☐ **Checkpoint:** No red signing errors; Bundle ID = `com.matchword.matchWord`.

---

### Step 6 — Register the Bundle ID (only if App Store Connect cannot find it)

Usually Xcode’s “Automatically manage signing” registers the ID. If App Store Connect’s dropdown does **not** list `com.matchword.matchWord`, register it manually:

1. Safari → [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list)
2. Sign in → click **+** (next to Identifiers).
3. Select **App IDs** → **Continue**.
4. Select type **App** → **Continue**.
5. Fill in:
   - **Description:** `Match Word`
   - **Bundle ID:** select **Explicit** → type `com.matchword.matchWord`
6. Under **Capabilities**, leave defaults (add **In-App Purchase** later if needed).
7. Click **Continue** → **Register**.
8. Return to App Store Connect and refresh the Bundle ID dropdown.

☐ **Checkpoint:** `com.matchword.matchWord` appears in the Apple Developer identifiers list.

---

### Step 7 — Create the app record in App Store Connect

1. Safari → [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) → sign in.
2. Click **Apps** (top navigation bar).
3. Click the **+** button → **New App**.
4. Fill the form exactly:

   | Field | Value |
   |-------|--------|
   | Platforms | ☑ **iOS** only |
   | Name | `Match Word` |
   | Primary Language | English (U.S.) |
   | Bundle ID | `com.matchword.matchWord` (from dropdown) |
   | SKU | `matchword-001` (any internal code; users never see it) |
   | User Access | **Full Access** |

5. Click **Create**.
6. You land on the app’s **App Store** tab — that is correct. **TestFlight** is a separate tab at the top.

☐ **Checkpoint:** **Match Word** appears in your Apps list in App Store Connect.

---

### Step 8 — Create a TestFlight tester group and invite Ronna

Do this once; you will add new **builds** to the same group after each upload.

#### Option A — Internal testing (fastest; no Beta App Review)

Best if Ronna’s email can be added to your App Store Connect team, or for testing yourself first.

1. App Store Connect → **Apps** → **Match Word**.
2. Click the **TestFlight** tab (top).
3. Left sidebar → **Internal Testing**.
4. Under **Internal Groups**, click **+** (or open the default group).
5. Name the group: `Core testers`.
6. Click **+** next to **Testers**:
   - Add **your** Apple ID email (smoke-test yourself first).
   - Add **Ronna’s Apple ID email** — the address she uses on her iPhone (**Settings → [her name]**).
7. Click **Save** / **Add**.
8. *(After your first build is uploaded and processed)* under **Builds** for this group:
   - Click **+** → select the iOS build → **Add**.

Testers receive an email: **“You're invited to test Match Word.”**

#### Option B — External testing (Ronna not on your team)

1. **TestFlight** tab → left sidebar → **External Testing**.
2. Click **+** to create a group → name it `Ronna — iPhone`.
3. Click **+** next to **Testers** → enter Ronna’s email → **Add**.
4. After a build is uploaded, add it to the group (**+** under **Builds**).
5. First external build needs **Beta App Review** (~24–48 h):
   - Fill **What to Test**, contact email, and a short description.
   - Click **Submit for Review**.

☐ **Checkpoint:** Tester group exists; Ronna’s email is added (build assigned after first upload).

---

### One-time setup checklist

| Step | Done? |
|------|-------|
| Xcode + Flutter + CocoaPods installed | ☐ |
| Apple Developer Program active | ☐ |
| `app/.env` has Supabase URL + anon key; `EASY_TEST_AUTH=false` | ☐ |
| `pod install` succeeded | ☐ |
| Xcode **Accounts** shows your Team | ☐ |
| `Runner.xcworkspace` → signing ON, correct Team + Bundle ID | ☐ |
| App **Match Word** created in App Store Connect | ☐ |
| TestFlight tester group created; Ronna’s email added | ☐ |

When every box is checked, proceed to **Build & upload** below.

---

## Build & upload (each new version)

After one-time setup, repeat this for every TestFlight release:

1. Bump build number in `app/pubspec.yaml` (e.g. `0.1.0+1` → `0.1.0+2`).
2. Build:
   ```bash
   cd app
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ipa --release
   ```
3. Upload:
   - **Xcode → Window → Organizer → Archives → Distribute App → App Store Connect → Upload**, or
   - Drag `build/ios/ipa/match_word.ipa` into the **Transporter** app.
4. App Store Connect → **Match Word → TestFlight** → wait until build status is **Ready** (not *Processing*).
5. Answer **Export Compliance** if prompted (HTTPS only → usually “No” for custom encryption).
6. Add the build to your tester group (**Internal Testing** or **External Testing** → **+** under Builds).

Full click-by-click for upload, compliance, and troubleshooting: **`TestFlight-Setup-Guide.md`**.

---

## What Ronna does on iPhone

1. Install **TestFlight** from the App Store (free, purple icon).
2. Open the email **“You're invited to test Match Word”** on her iPhone.
3. Tap **View in TestFlight** → **Accept** → **Install**.
4. Open **Match Word** from the home screen (or TestFlight → **Open**).
5. Create an account, build a character, and play.

If no email: check Spam; confirm the invite went to the same Apple ID as **Settings → [her name]**. Resend from App Store Connect → TestFlight → tester → **Resend Invitation**.

---

## Billing note (not required for first TestFlight)

- `PaywallScreen` and `BillingService` are in the app; the **Subscribe** button shows a “coming soon” message until StoreKit is wired.
- When you test real purchases, create subscription product `matchword_monthly_599` in App Store Connect → **Subscriptions** (see **Part 10** in `TestFlight-Setup-Guide.md`).
- The in-app **7-day free trial** is tracked in Supabase; App Store introductory offers are configured separately.

---

## Not possible on Linux

- Signed `.ipa` file
- TestFlight invite link
- Live App Store purchase sheet
