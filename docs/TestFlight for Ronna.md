# TestFlight — Match Word (for Ronna)

**Status (Sep 9, 2026):** Build **102** is the current build. Testers must see `Build 102` in the corner of the app — anything lower is a stale install.

**Goal for Thursday:** a **public TestFlight link** Ronna can text to her friends, so nobody has to be added by email one at a time. That link needs Apple's Beta App Review first — see [Part C](#part-c--public-testflight-link-share-one-url-with-anyone). Start it as early as possible: review is usually same-day but can take 24–48 hours. **Part B (internal testers) works immediately and needs no review** — that is the safe fallback for Thursday.

| Item | Value |
|------|--------|
| App name | **Match Word** |
| Bundle ID | `com.matchword.matchWord` |
| App Store Connect App ID | `6800935274` |
| Direct TestFlight info page | https://appstoreconnect.apple.com/apps/6800935274/testflight/test-info |
| Apps home | https://appstoreconnect.apple.com/apps |

Use the Apple ID that owns the **Match Word** app (the same account that created the App Store Connect record).

---

## What you can do right now

1. **Fill in TestFlight contact info** (required once — see Part A).
2. **Install on your iPhone** via TestFlight as an **Internal** tester (fastest — see Part B).
3. Optional later: invite friends as **External** testers (needs Apple beta review — see Part C).

Publishing to the public App Store is a separate later step. This guide is only for **TestFlight**.

---

## Privacy Policy URL (Test Information)

Apple asks for a Privacy Policy URL on TestFlight Test Information.

1. Upload the folder `docs/store-pages/` to your site as:  
   `https://grandmamac.com/matchword/`
2. Then paste this URL into App Store Connect → TestFlight → Test Information → Privacy Policy URL:  
   **https://grandmamac.com/matchword/privacy-policy.html**

Files ready to upload: `privacy-policy.html`, `terms-of-service.html`, `support.html`, `security.html`.

Until that path is live on grandmamac.com, the Match Word pages are not served yet (the site currently shows other Grandma Mac tools).

---

## Part A — Fill TestFlight “Test Information” (do this first)

Codemagic stopped at: *“Complete test information is required…”*  
Missing items were: **Feedback Email**, and Beta App Review **First Name / Last Name / Phone / Email**.

1. Open Safari on your Mac or iPhone and go to:  
   https://appstoreconnect.apple.com/apps/6800935274/testflight/test-info  
   (Or: [App Store Connect](https://appstoreconnect.apple.com/apps) → **Match Word** → **TestFlight** tab → **Test Information** in the left sidebar.)
2. Sign in with your Apple Developer / App Store Connect account.
3. Under **Beta App Information**, enter:
   - **Feedback Email** — an email you check (your usual contact email is fine).
4. Under **Beta App Review Information**, enter:
   - **First Name**
   - **Last Name**
   - **Phone Number** (with country code, e.g. `+1 …`)
   - **Email**
5. Optional but helpful:
   - **Demo account** — leave blank unless Apple asks, or note that the app uses first name + PIN (no password for daily play).
   - **Notes** — e.g. `Portrait-only senior word game. Sign up with email + 4-digit PIN, then play Upcoming Games or Studio.`
6. Click **Save** (top right).

You only need to do this once (update later if your contact details change).

---

## Part B — Install Match Word on your iPhone (Internal TestFlight)

Internal testing is for people on your **App Store Connect** team. It does **not** need Apple’s external beta review.

### B1 — Add yourself as an Internal tester

1. App Store Connect → **Match Word** → **TestFlight**.
2. Left sidebar: **Internal Testing** (or **Users and Access** / testers — labels can vary slightly).
3. Open the default internal group (often named **App Store Connect Users**) or create a group, e.g. **Ronna**.
4. Click the **+** / **Add Testers** and add the Apple ID email you use on your **iPhone**.
5. Make sure the latest processed build is **enabled** / **added** to that internal group.
   - Builds appear under **iOS** with a version like **1.0.0 (5)** or higher.
   - Status should show **Ready to Test** (or similar) after processing finishes.

### B2 — Install TestFlight + the app on your phone

1. On your iPhone, open the **App Store** and install **TestFlight** (Apple’s free app), if it is not already installed.
2. Open the invitation email (or the App Store Connect notification) on the iPhone and tap **View in TestFlight** / **Start Testing**.
3. In **TestFlight**, open **Match Word** → tap **Install**.
4. When it finishes, open **Match Word** from your home screen like any other app.

**Tip:** Keep TestFlight installed. New builds from Codemagic will show up there as updates when we upload again.

### B3 — If you do not see the build

- Wait 5–15 minutes after “processing finished” (sometimes longer).
- Confirm you are signed into App Store Connect with the **same Apple ID** that owns the app.
- Confirm your iPhone Apple ID is listed as an Internal tester and the build is checked for that group.
- On the phone: TestFlight → Account → make sure you accepted the invitation.

---

## Part C — Public TestFlight link (share one URL with anyone)

This is the "just send me a link" option: one URL, up to 10,000 testers, no
email addresses needed. Apple calls it a **public link** on an **external**
group, and it is the only TestFlight link that can be shared freely.

**It requires Apple's Beta App Review.** Internal testing (Part B) does not.
So do Part B first as the Thursday fallback, and run Part C alongside it.

### C1 — Create the external group and attach the build

1. Complete **Part A** first — review is rejected without the contact fields.
2. Go to https://appstoreconnect.apple.com/apps/6800935274/testflight/groups
3. Click **+** next to **External Testing** → name the group **Match Word Testers**.
4. In the group, open the **Builds** tab → **+** → pick **1.0.0 (102)**.
5. Apple asks **"What to Test"** — paste the notes from `docs/Store Release Notes.md`, or:
   > Play a full game with friends. Check that the stand-ins guess sensibly, that the second half does not skip ahead, and that Guy Smiley's sign-off is clear.
6. Answer the **export compliance** question: the app uses encryption **only for HTTPS**, which is exempt.
7. Click **Submit for Review**.

### C2 — Turn the public link on

Once the build shows **Approved** (email from Apple; usually same day):

1. Same group → **Testers** tab → **Enable Public Link**.
2. Optionally set a tester limit (leave it high — 10,000 is the max).
3. Copy the URL. It looks like `https://testflight.apple.com/join/XXXXXXXX`.
4. Text or email that one URL to everyone. They tap it, install **TestFlight**
   from the App Store if they do not have it, then tap **Install** for Match Word.

**Paste the link back into this file** under Part E so there is one place to find it.

### C3 — Keeping the link on the current build

A public link always serves whatever build is attached to that group. Every new
Codemagic upload has to be added to the group, or friends keep installing the old
one — this is exactly how "Build 6" happened before.

To make Codemagic do it automatically, uncomment `beta_groups` in `codemagic.yaml`
under `publishing → app_store_connect` **once the group exists**, with the name
spelled exactly as in App Store Connect:

```yaml
beta_groups:
  - Match Word Testers
```

A name that does not match an existing group fails the publish step (the build
still uploads), so only enable it after C1.

---

## Part D — What Gregory / Codemagic already did

- Built and signed the iOS app.
- Uploaded the IPA to App Store Connect for **Match Word** (`com.matchword.matchWord`).
- Apple finished **processing** the build (so it exists in TestFlight).

What still needs a human in App Store Connect (you):

- TestFlight contact / feedback fields (Part A).
- Adding yourself (and others) as testers (Parts B–C).
- Later: full App Store listing, screenshots, privacy, and **Submit for Review** for public release — not required for TestFlight.

---

## Part E — Quick checklist

**Public link:** _paste the `https://testflight.apple.com/join/…` URL here once Part C2 is done._

- [ ] Open https://appstoreconnect.apple.com/apps/6800935274/testflight/test-info  
- [ ] Save Feedback Email + Beta Review name / phone / email  
- [ ] Add your iPhone Apple ID as an **Internal** tester  
- [ ] Enable build **1.0.0 (102)** on that group  
- [ ] Install **TestFlight** on iPhone → install **Match Word**  
- [ ] Confirm the corner of the app reads **Build 102**  
- [ ] Create the **Match Word Testers** external group and **Submit for Review** (Part C1)  
- [ ] When approved: **Enable Public Link** and paste it above (Part C2)  

---

## Part F — Answers to the other Thursday questions

**Which build is live?** Build **102**. The app prints its own build number in the
screen corner, so anyone unsure can read it off their phone. TestFlight's build
number now comes from `pubspec.yaml`, not Codemagic's own counter — that counter
restarting is what showed "Build 6" for build 84.

**Will the paywall lock anyone out?** No. Play is not gated: `TrialPolicy.enforcePaywall`
is `false`, so an expired trial still plays every screen. Nobody needs comping for
Thursday. (The Subscribe screen is still reachable, but "Keep Playing" exits it.)

**How do we all get into the same game?** With the **4-digit game code**:

1. One person taps **Enter the Studio** (or **Upcoming Games** → start a game).
   Their lobby shows **Your game code** with Share and Copy buttons.
2. Everyone else taps **Join with a Code**, types those 4 digits, and taps
   **See the Game**.
3. The preview screen shows all four seats. **Tap the seat you want** —
   that is how you pick your team — then confirm.

Seats map to teams like this, so pick with a partner in mind:

| Seat | Team | Role |
|------|------|------|
| 1 | A | A1 |
| 2 | B | B1 |
| 3 | A | A2 |
| 4 | B | B2 |

Seats 1 and 3 are Team A; seats 2 and 4 are Team B. Any seat left empty is filled
by a stand-in. Tapping **Join** straight from the open-games list skips the seat
picker and drops you in the first free seat — use **Join with a Code** instead when
you care which team you land on.

---

## Need help?

If anything on these screens looks different (Apple renames menus sometimes), send Gregory a screenshot of the TestFlight page and the build status line (version + “Ready to Test” / “Missing Compliance” / etc.).

**Export compliance:** If Apple asks about encryption, for a normal HTTPS app the usual answer is that you only use standard/exempt encryption (HTTPS). Choose the option that matches “uses encryption only for HTTPS” / exempt, unless your lawyer says otherwise.
