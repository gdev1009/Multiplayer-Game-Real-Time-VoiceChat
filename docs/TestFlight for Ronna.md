# TestFlight — Match Word (for Ronna)

**Status (Aug 13, 2026):** The latest build is **already uploaded** to App Store Connect and Apple has **finished processing** it. Codemagic’s red “failed” step only means it could not auto-submit for **external** beta review — because TestFlight contact fields are still empty. That does **not** undo the upload.

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

## Part C — External testers (friends / players outside your team)

Use this when you want people who are **not** on your App Store Connect team.

1. Complete **Part A** (Test Information) if you have not already.
2. TestFlight → **External Testing** → create a group (e.g. **Friends**).
3. Add the latest build to that group.
4. Submit for **Beta App Review** when Apple asks (this is the step Codemagic could not finish automatically).
5. After Apple approves (often same day to a couple of days), add emails or share a **public link**.
6. Testers install via the TestFlight invite.

Until Beta App Review is approved, stick with **Internal** testing (Part B).

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

- [ ] Open https://appstoreconnect.apple.com/apps/6800935274/testflight/test-info  
- [ ] Save Feedback Email + Beta Review name / phone / email  
- [ ] Add your iPhone Apple ID as an **Internal** tester  
- [ ] Enable the latest **Ready to Test** build on that group  
- [ ] Install **TestFlight** on iPhone → install **Match Word**  
- [ ] Play a short session and note anything to change  

---

## Need help?

If anything on these screens looks different (Apple renames menus sometimes), send Gregory a screenshot of the TestFlight page and the build status line (version + “Ready to Test” / “Missing Compliance” / etc.).

**Export compliance:** If Apple asks about encryption, for a normal HTTPS app the usual answer is that you only use standard/exempt encryption (HTTPS). Choose the option that matches “uses encryption only for HTTPS” / exempt, unless your lawyer says otherwise.
