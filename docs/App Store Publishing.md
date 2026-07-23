# App Store & Play Store Publishing

**App:** Match Word · **Publisher:** Grandma Mac  
**Bundle ID (iOS):** `com.matchword.matchWord`  
**Package (Android):** `com.matchword.matchWord`  
**Version:** 1.0.0 (build 1)

---

## Client store accounts (Ronna)

Ronna owns both store accounts. **Send all collaboration / access invites to the same email:**

| Platform | Account email |
|----------|----------------|
| **Apple** (App Store Connect / Apple Developer) | `rljjmckenzie@gmail.com` |
| **Google** (Play Console) | `rljjmckenzie@gmail.com` |

She will accept the invites on her end. Do **not** create new Apple/Google developer accounts under Greg’s email for the public listings — use invites into Ronna’s orgs.

---

## How to send access requests

### A) Apple — App Store Connect / Apple Developer

You need access so you can upload builds (TestFlight / App Store), manage certificates/profiles, and edit listing metadata.

#### Option 1 — App Store Connect user (usual for day-to-day publishing)

1. Sign in at [App Store Connect](https://appstoreconnect.apple.com/) with an account that is **Account Holder** or **Admin** on Ronna’s team  
   *(If you are not already on the team, Ronna must invite you first — see Option 2 / ask her to invite Greg from her side.)*
2. Go to **Users and Access** → **People** (or **Users**).
3. Click **+** (Invite Users / Add).
4. **Email:** `rljjmckenzie@gmail.com`  
   *(Only if inviting Ronna onto a team you control. More often Ronna invites **you** — then use **your** Freelancer/work email in her invite.)*
5. Assign a role that can ship the app:
   - **Admin** — full App Store Connect access (simplest for a small team), or  
   - **App Manager** — enough for most listing + TestFlight work, or  
   - **Developer** — builds / TestFlight; limited listing rights  
6. Under **Apps**, grant access to **Match Word** (or “All Apps” if preferred).
7. Send the invite. Ronna accepts via the email from Apple.

**Typical flow for this project:** Ronna (Account Holder) invites **Greg** from App Store Connect → Users and Access, using Greg’s email. Greg accepts, then can upload with Xcode / Transporter.

#### Option 2 — Apple Developer Program membership (certificates / provisioning)

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account) as Account Holder / Admin.
2. **People** → **Invite People** (wording may be **Users** / **Access**).
3. Enter the invitee email.
4. Choose access level (e.g. **Admin** or **Developer**).
5. Send invite → invitee accepts and may need to join the team in Xcode (**Xcode → Settings → Accounts**).

#### After access is granted (Greg checklist)

- [ ] Accept Apple invite email  
- [ ] Add Apple ID in **Xcode → Settings → Accounts**  
- [ ] Download/create Distribution certificate + App Store provisioning for `com.matchword.matchWord`  
- [ ] Archive → Upload to App Store Connect / TestFlight  

See also: [TestFlight Setup.md](TestFlight%20Setup.md)

---

### B) Google — Play Console

You need access so you can upload AABs, edit the store listing, and manage testing tracks.

1. Sign in at [Google Play Console](https://play.google.com/console/) with an account that is **Account owner** or **Admin** on Ronna’s developer account  
   *(Usually Ronna invites Greg; she is Account owner.)*
2. Open the developer account → **Users and permissions** (left nav; sometimes under **Settings**).
3. Click **Invite new users**.
4. **Email address:** Greg’s work/Freelancer Google email (the address he will use daily).  
   To invite **Ronna onto a console Greg owns**, use: `rljjmckenzie@gmail.com`.
5. Set permissions (minimum useful set for publishing Match Word):
   - **App access:** grant the **Match Word** app (`com.matchword.matchWord`), or all apps  
   - **Release apps to production / testing tracks** (or Admin)  
   - **Edit store listing**  
   - **View app information and download bulk reports** (optional)  
6. Send the invite. Recipient accepts from the Google email.

**Typical flow for this project:** Ronna (Play Console Account owner) invites **Greg** with Admin or “Release + Store listing” rights. Greg accepts, then uploads `apks/MatchWord-store-*.aab`.

#### After access is granted (Greg checklist)

- [ ] Accept Play Console invite  
- [ ] Confirm package `com.matchword.matchWord` is visible  
- [ ] Create/upload **upload keystore** (not debug) for release signing  
- [ ] Upload AAB to internal / closed testing, then production when ready  

---

### Quick reference — who invites whom

| Goal | Who sends invite | Invite email |
|------|------------------|--------------|
| Greg can publish on **Apple** | Ronna (Account Holder) | Greg’s Apple ID email |
| Greg can publish on **Google Play** | Ronna (Account owner) | Greg’s Google account email |
| Confirm Ronna’s store emails (record only) | — | `rljjmckenzie@gmail.com` for both |

When ready to start store setup, message Ronna: *“Please send App Store Connect + Play Console invites to [Greg’s email]. I’ll accept on my end.”* She already confirmed her side accepts at `rljjmckenzie@gmail.com` if you ever need to invite her.

---

## Is the project “fully optimized and production-ready”?

**Mostly yes for alpha / TestFlight / internal review**, with these remaining items before public store launch:

| Area | Status |
|------|--------|
| Debug / test auth removed | Done |
| R8 minify, shrink resources, ProGuard | Done (Android) |
| Store builds (APK, AAB) | Done — see `apks/MatchWord-store-*` |
| Screenshots (full journey + store frames) | Generated — see `docs/screenshots/store/` |
| Policy pages (privacy, terms, support) | Draft HTML in `docs/store-pages/` |
| **Android release signing** | Still debug keystore — need upload key for Play |
| **Live IAP** | Paywall UI only; wire StoreKit / Play Billing |
| **iOS TestFlight** | Needs Apple Developer account (Ronna) |

---

## Required URLs for store listings

Upload `docs/store-pages/` to your website (e.g. `grandmamac.com/matchword/`) and use these URLs in App Store Connect and Google Play Console.

| Purpose | File | Example URL (after hosting) |
|---------|------|-----------------------------|
| **Privacy Policy** (required) | `privacy-policy.html` | `https://grandmamac.com/matchword/privacy-policy.html` |
| **Terms of Service** (recommended) | `terms-of-service.html` | `https://grandmamac.com/matchword/terms-of-service.html` |
| **Support / contact** (required) | `support.html` | `https://grandmamac.com/matchword/support.html` |
| **Security** (optional, good practice) | `security.html` | `https://grandmamac.com/matchword/security.html` |
| **Marketing URL** (optional) | main site | `https://grandmamac.com` |

**Support email:** `support@grandmamac.com` (must match listing and be monitored)

### Hosting the policy pages

1. Copy `docs/store-pages/*.html` to your web host under `/matchword/` (or similar).
2. Ensure pages are served over **HTTPS**.
3. Paste the live URLs into App Store Connect → App Information → Privacy Policy URL, and Google Play → Store settings → Privacy policy.

---

## Screenshots

Generated assets live under `docs/screenshots/store/`:

| Folder | Contents |
|--------|----------|
| `full-journey/` | Raw phone captures, all 16 screens in user flow order |
| `app-store/` | **1290×2796** framed screenshots (iPhone 6.7") |
| `play-store/` | **1080×1920** framed screenshots (phone) |

### Screen order (start → end)

1. Welcome  
2. Create account  
3. Daily login  
4. Email sign-in  
5. Opening / home  
6. Character builder  
7. Upcoming games  
8. Studio  
9. Join by code  
10. Lobby room  
11. Play — kickoff  
12. Play — clue  
13. Play — winner  
14. Prize room  
15. Paywall / free trial  
16. Friends  

### Recommended subset for store listing (5–8 slides)

Pick the strongest story arc for the public listing:

1. `05_opening_home` — hero / home  
2. `06_character_builder` — customization  
3. `11_play_kickoff` — game show moment  
4. `12_play_clue` — core gameplay  
5. `14_prize_room` — progression  
6. `15_paywall` — subscription (optional for marketing)  
7. `16_friends` — social  

### Regenerating screenshots

```bash
cd app
flutter build web -t lib/demo_store_screens.dart --no-tree-shake-icons
python3 tools/capture_store_screenshots.py --serve
```

Requires Chrome and Node (`puppeteer-core`). Uses WebGL (SwiftShader) so character art renders correctly.

---

## App Store Connect checklist

- [ ] Apple Developer Program enrolled  
- [ ] App record created — bundle `com.matchword.matchWord`  
- [ ] Privacy Policy URL live  
- [ ] Support URL live  
- [ ] Screenshots uploaded (6.7" iPhone: 1290×2796)  
- [ ] App description, keywords, subtitle  
- [ ] Age rating questionnaire  
- [ ] Subscription `matchword_monthly_599` created ($5.99/mo)  
- [ ] TestFlight build uploaded from Mac/Xcode  
- [ ] Export compliance / encryption (typically “standard encryption only”)  

See also: [TestFlight Setup.md](TestFlight%20Setup.md)

---

## Google Play Console checklist

- [ ] Developer account ($25 one-time)  
- [ ] App created — package `com.matchword.matchWord`  
- [ ] **Release signing** — upload keystore, not debug  
- [ ] Upload `MatchWord-store-*.aab` from `apks/`  
- [ ] Privacy Policy URL  
- [ ] Store listing screenshots (1080×1920 or larger)  
- [ ] Content rating questionnaire  
- [ ] Subscription product `matchword_monthly_599`  
- [ ] Banking & tax profile complete  

---

## Store copy (starter)

**Subtitle (iOS, 30 chars):** Social word game for friends  

**Short description (Play, 80 chars):** Team up, give one-word clues, and guess before time runs out!  

**Description (long):**  
Match Word is a lively social word game where four players team up, give clever one-word clues, and race to guess secret words. Build your clay character, invite friends, earn trophies on your prize shelf, and enjoy the full game-show experience with host Guy Smiley. Start with a 7-day free trial, then continue for $5.99/month.

---

## Contact

**Store account email (Ronna):** `rljjmckenzie@gmail.com` — Apple Developer / App Store Connect and Google Play Console (same address for both).

For client handoff, share this doc plus `docs/store-pages/` and `docs/screenshots/store/app-store/` with Ronna for App Store Connect upload. Use the **How to send access requests** section above when exchanging invites.
