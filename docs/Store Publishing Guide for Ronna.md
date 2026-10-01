# Match Word — putting it in the stores

This is the step-by-step for you, Ronna. You own the Apple and Google accounts, so you are the one who taps Submit. I put iPhone builds on TestFlight and send you the Android file. I cannot sign in to your stores.

**Version in this package:** 1.0.0 (build 109)

| Store | ID to type exactly | File |
|---|---|---|
| Apple App Store | `com.matchword.matchWord` | Build 109 on TestFlight. Do not upload an iPhone file yourself. |
| Google Play | `com.matchword.app` | `MatchWord-v109-play-20260930.aab` |

The two IDs are different on purpose. If Play Console asks for a package name, it must be `com.matchword.app`. If you type the Apple ID there, Google will reject the file.

Sign in to both sites with `rljjmckenzie@gmail.com`.

In this package:

- `MatchWord-v109-play-20260930.aab` — the Android app
- `MatchWord-store-pages.zip` — privacy policy, terms, and support pages
- `MatchWord-screenshots.zip` — the eight pictures for each store, already in order
- this guide

---

## Read this first: how charging works in build 109

Build 109 has Apple and Google checkout built in. It switches itself on:

- **Before your subscription is live in a store,** the membership screen says Match Word will be $6.99 CAD a month and shows **Keep Playing**. Nobody is blocked and nobody is charged.
- **Once the subscription is live,** the same screen shows **Subscribe for $6.99 CAD a month**, with Restore Purchases, the renewal wording, and links to your Terms and Privacy pages. After the 5-day free trial, players see that screen before they enter a game.

You do not need a new build to turn charging on. You turn it on by finishing the subscription steps below.

**Price:** $6.99 CAD a month, which is what build 109 shows. You had asked earlier for $5.99. If you still want $5.99, tell me before you create the product and I will send a new build and a new product ID. Do not create `matchword_monthly_699` at $5.99. The app shows the price the store sends, so the store price and the screen stay matched.

**Product ID**, both stores, typed exactly:

`matchword_monthly_699`

**Where players find it:** on the home screen, the free-trial banner says *Tap to see membership*. That opens the Membership screen. Apple's reviewer will use the same path, and it is in the review note below.

---

## 1. Put three pages on the web first

Both stores refuse the app until a privacy page and a support page load in a browser.

Unzip `MatchWord-store-pages.zip`. Inside the `store-pages` folder:

- `privacy-policy.html`
- `terms-of-service.html`
- `support.html`

Upload them to your site so these addresses open:

- https://grandmamac.com/matchword/privacy-policy.html
- https://grandmamac.com/matchword/terms-of-service.html
- https://grandmamac.com/matchword/support.html

Open each link on your phone before you continue. The Membership screen in the app links to the first two, so they must load. Support email on those pages: `support@grandmamac.com`

---

## 2. Screenshots

Unzip `MatchWord-screenshots.zip`. Inside the `screenshots` folder:

- `app-store` — iPhone pictures, 1290 × 2796
- `play-store` — Android pictures, 1080 × 1920

Each folder has the same eight pictures. Upload them in this order on both stores:

1. `01_welcome`
2. `05_opening_home`
3. `06_character_builder`
4. `08_studio`
5. `10_lobby_room`
6. `11_play_kickoff` (Guy opening the show, in place of the prize room)
7. `12_play_clue`
8. `13_play_winner`

All eight were taken from build 109. The zip also has a separate `review-only` folder with `15_paywall`. Do not put that one in the store listing. Apple asks for it when you set up the subscription (step 25 in section 4).

---

## 3. Words you can paste

**Apple subtitle** (30 characters):

`Social word game for friends`

**Google short description** (80 characters):

`Team up, give one-word clues, and guess before time runs out!`

**Description** (both stores):

Match Word is a lively social word game for friends and family. Four players team up. One player gives a one-word clue. Their partner guesses the secret word.

Build your own character, invite friends with a room code, and play in a game-show studio with your host, Guy Smiley. Win games, collect trophies, and come back for another round.

Large type, a Pass button, and the choice to type or speak. Made for people who want a calm, friendly game they can play together.

Your first 5 days are free. After that, a Match Word membership is $6.99 CAD a month and keeps the game ad-free. Payment is charged to your App Store or Google Play account. The membership renews each month unless you cancel at least 24 hours before the end of the current month. You can manage or cancel it anytime in your account settings.

Terms of Use: https://grandmamac.com/matchword/terms-of-service.html
Privacy Policy: https://grandmamac.com/matchword/privacy-policy.html

**Keywords** (Apple only, 100 characters, commas, no spaces after commas):

`word game,party,family,seniors,friends,clues,multiplayer,trivia`

**Category**

- Apple: Games → Word
- Google: Game → Word

**Age**

- Apple: 4+
- Google: Everyone

---

## 4. Apple App Store

I put build 109 on TestFlight. You fill in the store page, set up the subscription, and choose that build.

### Before anything else: paid agreement

1. Open https://appstoreconnect.apple.com and sign in.
2. Go to **Business** (or **Agreements, Tax, and Banking**).
3. Accept the **Paid Apps** agreement, then add your bank account and complete the tax forms.

Apple will not sell a subscription until this says **Active**. It can take a day or two after you submit the bank and tax details.

### The app page

4. Click **Apps**. If Match Word is not there yet, click **+** and choose **New App**.
   - Platforms: **iOS**
   - Name: **Match Word**
   - Primary language: **English (Canada)** or English (U.S.), whichever you prefer
   - Bundle ID: **com.matchword.matchWord**
   - SKU: `matchword` (any private code; players never see it)
   - User Access: Full Access
5. Open the app, then the **iOS App** version **1.0** page (Prepare for Submission).

### Listing

6. Paste the subtitle, description, and keywords from section 3.
7. Support URL: `https://grandmamac.com/matchword/support.html`
8. Marketing URL: you can leave this blank.
9. Upload the eight iPhone screenshots into **iPhone 6.7" Display** (1290 × 2796). If Apple also asks for 6.5", use the same pictures there.
10. App icon: leave the icon that came with the build.
11. Copyright: `2026 Grandma Mac`
12. Contact email: `support@grandmamac.com`

### The build

13. In the **Build** section, click **+** and select version **1.0.0**, build **109**.
14. If 109 is not listed yet, open the **TestFlight** tab and wait until it says Ready to Test. I will tell you when it is there. Do not pick 108, which has no checkout.
15. If Apple asks about encryption: the app only uses standard secure web connections (HTTPS). Choose **No** for proprietary encryption, or the exemption for standard encryption. Do not say the app has custom encryption.

### Privacy

16. Privacy Policy URL: `https://grandmamac.com/matchword/privacy-policy.html`
17. App Privacy (nutrition labels). Answer from what the game actually does:
    - Contact info: **email address** (account)
    - User content: **gameplay** (names, scores, clues, guesses)
    - Identifiers: **user ID** (the account)
    - Audio: **microphone**, only when a player taps Speak. Not used for ads.
    - Purchases: **purchase history** (whether the membership is active)
    - All of it is linked to the player's account and used for app functionality
    - Not used for tracking across other companies' apps
    - Not sold

### Age rating

18. Complete the questionnaire. No violence, no gambling, no unrestricted web, no user-generated public posts. Cartoon game-show play. Result should be **4+**.

### Subscription

19. In the left sidebar open **Subscriptions** (under Monetization).
20. Create a group named **Match Word Membership**.
21. Inside the group, create a subscription:
    - Reference name: `Match Word Monthly`
    - Product ID: `matchword_monthly_699`
22. Fill in the subscription page:
    - Duration: **1 month**
    - Price: **$6.99 CAD** for Canada. Let Apple fill in the other countries, or pick the ones you want.
    - Do **not** add a free introductory offer. The 5-day free trial already lives inside the game.
23. Under **App Store Localization**, add English:
    - Display name: `Monthly membership`
    - Description: `Keeps Match Word ad-free for you and your friends.`
24. Group localization (Apple asks for this too): display name `Match Word Membership`.
25. **Review information:**
    - Screenshot: `review-only/15_paywall_1290x2796.png` from the screenshots zip
    - Review notes: `Home screen → tap the free-trial banner ("Tap to see membership") → Membership screen → Subscribe.`
26. Save. The status should become **Ready to Submit**.

### Attach the subscription to this version

27. Go back to the **iOS App 1.0** page. Scroll to **In-App Purchases and Subscriptions**, click **+** (or Select), tick **Match Word Monthly**, and click **Done**.

Apple requires the first subscription to go in with a new version, and build 109 is the one that sells it. The reviewer will find the purchase through the home banner.

### Review notes (paste this in App Review Information)

```
Match Word is a four-player word game. Create an account with email, build a character, then start a game or join with a 4-digit code. One player gives a one-word clue; their partner guesses.

To review alone, start a game and the empty seats are filled so play can continue.

Membership (auto-renewable, 1 month, $6.99 CAD): on the home screen tap the free-trial banner ("Tap to see membership"). The Membership screen has Subscribe and Restore Purchases, the renewal terms, and links to our Terms of Use and Privacy Policy. After the 5-day free trial this screen appears before entering a game.

Microphone is used only if the player taps Speak. The game is fully playable by typing.

Account: create a new email account in the app. No demo password is needed.
```

28. Version release: **Manually release this version**. That way it does not appear in the store the moment Apple says yes. You choose the day.
29. Click **Add for Review**, then **Submit to App Review**.

Apple usually answers in one to three days, sometimes longer. You will get an email. If they reject it, forward me the exact text and I will tell you what to change.

### Try the purchase yourself (optional, no charge)

In App Store Connect open **Users and Access → Sandbox → Test Accounts** and add a test Apple ID. On your iPhone, open TestFlight, install build 109, and tap Subscribe. TestFlight purchases are free. It will say it is a test purchase.

---

## 5. Google Play

You will upload the `.aab` file from this package. That file is the Android app. Do not upload an `.apk`.

1. Open https://play.google.com/console and sign in.
2. If Google still wants identity or phone checks on the Grandma Mac account, finish those first. Play will not accept an app until the account is verified.
3. Click **Create app**.
   - App name: **Match Word**
   - Default language: **English (Canada)** or English (United States)
   - App or game: **Game**
   - Free or paid: **Free** (the membership is an in-app subscription, not a price to download)
   - Accept the declarations.
4. The package name comes from the file you upload. It will become `com.matchword.app`. Do not create a different app under another name.

### Payments profile

5. In Play Console go to **Settings → Payments profile** and finish it: business name, address, bank account, and tax details. Google cannot sell a subscription or pay you until this is done.

### Dashboard tasks

Play shows a list on the dashboard. Work through it in this order.

6. **App access:** All functionality is available without special access. Reviewers create their own account in the app. Paste the same review note as Apple (section 4) into the instructions box.
7. **Ads:** No, the app does not contain ads.
8. **Content rating:** Start the questionnaire. Category **Game**. No violence, no sexuality, no gambling. Players only interact in game rooms and with their friends list, and no location is shared. Submit. You should land on **Everyone** or a low rating. Apply the rating to the app.
9. **Target audience:** choose **18 and over**. The game is made for adults and seniors, not children, and this keeps it out of the children's policy. Do not select under 13.
10. **News app:** No.
11. **Data safety:**
    - Collects data: Yes
    - Encrypted in transit: Yes
    - Users can request deletion: Yes, by emailing `support@grandmamac.com`
    - Data types: email, name, app interactions (gameplay), audio (microphone, only when Speak is used), device or other IDs for the account, **purchase history** (membership status)
    - Purpose: app functionality and account management
    - Not sold, not used for ads, not shared for advertising
12. **Government apps:** No.
13. **Financial features:** No.
14. **Store settings → App category:** Game → Word
15. **Store listing:**
    - Short description and full description from section 3
    - App icon: 512 × 512 PNG. If Play asks and you do not have one, tell me and I will send it.
    - Feature graphic: 1024 × 500. If you do not have one, tell me and I will make it.
    - Phone screenshots: the eight `play-store` pictures, in order
    - Email: `support@grandmamac.com`
    - Privacy policy: `https://grandmamac.com/matchword/privacy-policy.html`

### Closed test: 12 testers for 14 days

Google requires this for personal developer accounts created after November 13, 2023. Your Play Console dashboard shows the requirement if it applies to your account. Organization accounts do not have it.

The rule:

- At least **12 testers**, each with an **Android phone** and a Google account
- They must join through Google's opt-in link and install Match Word from the Play Store
- They must stay opted in for **14 days in a row**. If someone leaves, the count can drop below 12 and the 14 days start again.

I suggest inviting 14 to 16 people so one or two dropping out does not reset the clock. iPhone users cannot count.

16. Open **Test and release → Testing → Closed testing**. Create a track (Play may name it **Alpha**).
17. Click **Create new release**.
18. If Google offers **Play App Signing**, accept it. Google keeps the key players' phones use. You only upload this file. You do not need a password from me.
19. Upload `MatchWord-v109-play-20260930.aab`.
20. Release name: `1.0.0 (109)`
21. Release notes (paste):

```
First version of Match Word. Play with friends, give one-word clues, and guess the secret word with host Guy Smiley.
```

22. **Testers:** create an email list and add your testers' Gmail addresses (yours too). Save.
23. **Countries:** choose Canada, and any others your testers live in.
24. Click **Review release**, then **Start rollout to Closed testing**. Google reviews the test release first, often within a day or two.
25. When it is approved, copy the **opt-in link** from the Testers tab and send it to your testers. Each person opens it on their Android phone, taps **Become a tester**, then installs Match Word from the Play Store.
26. Check the Testers tab after a day or two to confirm at least 12 have opted in. The 14 days count from there.

You can do this while Apple reviews the iPhone version. The two do not wait on each other.

### Subscription

The subscription menu only unlocks after a file that includes checkout is uploaded. Build 109 does, so this works once step 19 is done.

27. Open **Monetize with Play → Products → Subscriptions** and click **Create subscription**.
    - Product ID: `matchword_monthly_699`
    - Name: `Monthly membership`
28. Add a **base plan**:
    - Base plan ID: `monthly`
    - Type: **Auto-renewing**
    - Billing period: **1 month**
    - Price: **$6.99 CAD**. Let Google convert other countries, or set them yourself.
    - No free trial or introductory offer. The 5-day free trial is already inside the game.
29. Save, then **Activate** the base plan.
30. Optional, no charge: **Settings → License testing**, add your Gmail and your testers. Their purchases are marked as tests and are not charged.

Once the base plan is active, the Membership screen in the app switches from Keep Playing to Subscribe by itself.

### Production

31. After 12 or more testers have been opted in for 14 days in a row, the dashboard shows **Apply for production**. Answer Google's questions about the test. Their review usually takes about a week.
32. When Google approves production access, open **Test and release → Production → Create new release**, choose **Add from library**, and pick the same 109 file.
33. **Countries:** Canada, the United States, and any others you want.
34. **Start rollout to Production.**

---

## 6. After both say yes

- Apple: you chose manual release, so open the app in App Store Connect and click **Release this version** when you want it public.
- Google: production rollout can take a few hours to show up in search.
- Search the store for **Match Word** from a phone signed in with a normal store account, not only your developer account.
- Create an account and play a game. On the home screen, tap the free-trial banner. The Membership screen should show **Subscribe for $6.99 CAD a month**.

If either store sends a rejection, forward me the exact text. Do not upload a different file until I send you one.

---

## 7. What I keep

I keep the Android upload key so future updates are accepted as the same app. You do not need that password to publish this file. Please do not try to re-sign the `.aab`.

Future iPhone updates go on TestFlight the same way as build 109. You select the new build in App Store Connect when you want it reviewed.
