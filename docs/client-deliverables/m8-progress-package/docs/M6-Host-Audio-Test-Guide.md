# Match Word — Milestone 6 Test Guide (Guy Smiley Host + Audio)

**Build:** `MatchWord-M6-phone-arm64-20260712.apk` (and `-arm32`, `-LDPlayer-x86_64`) in [apks/](../apks)
**App ID:** `com.matchword.app` · **Backend:** Supabase (live)
**Goal:** Verify the game-show studio stage, the male Guy Smiley host voice, all audio cues,
the disconnect alarm, mute/volume controls, and a full two-phone online match.

> This is a manual QA guide. Work top to bottom. Each check has a ☐ box — mark **PASS/FAIL**
> and note anything unexpected. Exact on-screen button labels are quoted in **bold**.

---

## 1. Before you start

### 1.1 What you need
- **Two Android phones** (arm64 — any normal phone from the last ~8 years). Use the `arm32`
  APK only for a very old device; use the `LDPlayer-x86_64` APK only for the LDPlayer emulator.
- Both phones on **working internet** (WiFi or mobile data). They do **not** need to be on the
  same network — they sync through the Supabase server.
- **Volume up** and the **silent switch OFF** on both phones (the host respects the hardware
  silent switch by design, so a muted phone will play no sound — that is correct behaviour, but
  for testing you want to hear the host).

### 1.2 Install
1. Copy the arm64 APK to each phone (USB, Google Drive, or email link).
2. On each phone, open the file and allow **"Install from unknown sources"** if prompted.
3. Launch **Match Word**.

### 1.3 Test accounts (fast path)
This test build ships with **`EASY_TEST_AUTH=true`**, which adds a **"Quick Test Sign-In"**
button on the Welcome and Daily-Login screens so you can skip email/PIN setup.

- ☐ For the quickest run, tap **"Quick Test Sign-In"** on each phone (see §2.1).
- ☐ To test the *real* account flow instead, follow §2.2.

> ⚠️ **Before store release, `EASY_TEST_AUTH` must be turned OFF.** Confirm the button disappears
> in a production build during Milestone 10.

---

## 2. Sign in

### 2.1 Quick test sign-in (recommended for M6 testing)
1. On the **Welcome** screen ("Welcome to Match Word"), tap **"Quick Test Sign-In"**.
2. ☐ You land on the **Opening Screen** with a Guy Smiley greeting: *"Hello …! So glad you are here."*

> Do this on **both** phones. Each gets its own test identity so they can be different players.

### 2.2 Real account flow (optional, thorough)
On **Phone A**:
1. Tap **"Create My Account"**.
2. **First name** → type a name → **"Next"**.
3. **Email** → type a real email you can open → **"Next"**.
4. **PIN** → enter a 4-digit PIN on the big keypad → it auto-advances.
5. **Confirm PIN** → re-enter the same PIN.
   - ☐ Mismatch shows *"The two PINs do not match. Let's try again."* and resets.
6. ☐ Account is created and you land on the **Opening Screen**.

On **Phone B**: repeat with a **different** name and email so you have two distinct players.

Extra auth checks (optional):
- ☐ **Daily login:** fully close and reopen the app → **"Welcome back, [name]"** → entering the
  PIN signs you straight in.
- ☐ **Forgot My PIN:** tap it, request a code, check the email arrives, set a new PIN, sign in.
- ☐ **Sign Out** (bottom of Opening Screen) returns to Welcome.

---

## 3. Make a character (both phones)

From the **Opening Screen**, the character card shows **"Create a Character"** (or
**"Edit My Character"** if one exists). Tap it to open **Character Studio** (7-step wizard).
The live preview at the top updates as you choose.

1. ☐ **Body** — pick a body → **"Next"**. (Changing body resets other choices and auto-dresses it.)
2. ☐ **Hair** — pick a style or **"None"** → **"Next"**.
3. ☐ **Outfit** — pick an outfit → **"Next"**.
4. ☐ **Glasses** — pick or **"None"** → **"Next"**.
5. ☐ **Accessories** — hat / earrings / held item (each has **"None"**) → **"Next"**.
6. ☐ **Name** — type a name (required) → **"Next"**.
7. ☐ **Review** ("You look great!") → **"Save my character"** → *"Your character is saved!"*.

- ☐ Back on the Opening Screen the card now shows your saved character.

Give the two phones **different** character names (e.g. **Rosa** and **Walter**) so you can tell
them apart on the stage.

---

## 4. Start a two-phone online game

One phone is the **Host**, the other is the **Joiner**.

### 4.1 Host creates the game (Phone A)
1. Tap **"Check Upcoming Games"** → **"Play a Game"** hub.
2. Tap **"Start a New Game"**.
3. ☐ You land in the **Game Room** and a big **"Your game code"** card shows a **4-digit code**
   (e.g. `1234`). Tap the code to copy it — you should see *"Code copied"*.
4. Read the 4 digits out to whoever holds Phone B.

### 4.2 Joiner joins by code (Phone B)
1. Tap **"Check Upcoming Games"** → **"Join with a Code"**.
2. Type the 4 digits on the keypad → **"See the Game"**.
3. ☐ The **Join Game** preview shows who's already in the room (Team A = seats left,
   Team B = seats right).
4. Tap an **open seat** → **"Pick this seat"**.
5. ☐ You arrive in the same **Game Room**; Phone A sees Phone B's name/character appear in the
   seat **within a second or two** (this proves realtime sync).

### 4.3 Fill and start (Phone A, the host)
1. ☐ (Optional) Tap **"Add Players"** to fill the remaining empty seats with studio (AI) players.
2. ☐ Tap **"Start Game"** (needs at least 2 players).
3. ☐ **Both phones** navigate to the **studio stage** together.

> Alternative quick path: on the hub tap **"Find a Game"** — it matchmakes into an open public
> game (or opens one) and holds seats for a few seconds for real players before studio players
> fill in. The banner reads *"Looking for players… studio players join in X second(s)."*

---

## 5. The game-show studio stage (the M6 visual)

When the match opens, check the stage matches the concept mockup and feels premium:

- ☐ **Deep-purple studio** backdrop with soft **spotlight beams** and a lit floor.
- ☐ Gold-framed **MATCH WORD scoreboard** at the top: **TEAM A  n — n  TEAM B**.
- ☐ **Word tile** (cream, gold border) under the scoreboard.
- ☐ **Two team podiums** with **realistic clay character busts** (head + shoulders) — not flat
  circles. The **active player's bust** scales up with a **gold spotlight halo**.
- ☐ **Guy Smiley** stands **centre-stage, full body, holding his microphone**, with a **speech
  bubble** above him and a gold **GUY SMILEY** nameplate below.
- ☐ **Animations feel alive:** host gently bobs; busts bob; the host does a little bounce/tilt
  when he speaks; the speech bubble and word tile **pop** when they change; team scores **pop**
  when they change.

---

## 6. Host voice + audio cues (the M6 sound)

> Turn the volume up. The host voice is an **original male game-show announcer** voice.

### 6.1 Show opening
- ☐ On the first screen of the match you hear the **theme music** start and the **announcer intro**.
- ☐ The host **voice** speaks the rules-intro line (male voice), and the speech bubble shows a
  matching line.

### 6.2 Turn + clue/guess
The **clue-giver's** phone shows the **secret word** in the word tile (e.g. `FLOWER`); the other
phones show only the word counter (e.g. *"Word 1 of 8"*) so nobody can read the answer.

1. On the clue-giver's phone: the input says **"Your clue"**, placeholder *"One word…"*.
   - ☐ Type a one-word clue → **"Send"**. (You may also tap the mic; if speech isn't wired it
     shows *"You can type your word here any time."* — typing always works.)
2. ☐ The clue appears in the shared **feed** on **all** phones (💡 icon).
3. On the guesser's phone: input says **"Your guess"**, placeholder *"Your best guess…"*.
   - ☐ Type the correct word → **"Send"**.
4. ☐ **Correct guess:** you hear a **cheer + the host say a "nice work" line**; the feed shows a
   green ✓; the scoreboard **pops** up by the word's value.
5. ☐ Tap **"Next word"** to continue.

Also verify:
- ☐ A **wrong guess** passes the word to the other team (steal) with its own sound.
- ☐ If a word is never guessed it is **revealed** ("The word was revealed…") with a reveal sound.

### 6.3 Halftime
- ☐ At halftime you get the **"Halftime!"** panel, a **halftime voice line**, and the role-switch
  message ("… you're now the clue-giver …").
- ☐ Tap **"Start second half"** to resume.

### 6.4 Winner
- ☐ At the end you get the **trophy panel** ("Team A wins!" / "It's a tie!"), **applause + a winner
  voice line**, and the music stops for the fanfare.

---

## 7. Sound settings (mute + volume)

Open the **sound button** in the top-right of the app bar during play.

- ☐ Icon shows **🔊** when on and **🔇** when muted.
- ☐ Tapping it opens the **"Sound"** sheet with:
  - ☐ A **mute switch** ("Sound is on" / "Sound is off").
  - ☐ A **"Music"** volume slider.
  - ☐ A **"Host & effects"** volume slider.
- ☐ Muting silences music, effects, and host voice.
- ☐ Sliders change the levels live.
- ☐ **Persistence:** set mute/volume, leave and re-enter a game → your settings are remembered.
- ☐ **Silent switch:** flip the phone's hardware silent switch → the game goes quiet (respecting
  the switch is intended senior-friendly behaviour). *(Exception: the disconnect alarm in §8 is a
  safety cue and still plays.)*

---

## 8. Disconnect alarm (safety cue)

Simulate a real drop:

1. During an active match, on **Phone B** turn on **Airplane mode** (or force-close the app).
2. On **Phone A**, within a few seconds:
   - ☐ The whole screen **flashes red**.
   - ☐ You hear the **ALERT / AWOOGA** alarm **even if the game was muted**.
   - ☐ A big **"Hold on!"** message names the dropped player, with a **"Keep Playing"** button.
3. Turn Phone B's internet back on / reopen the app.
   - ☐ Tap **"Keep Playing"** on Phone A to dismiss the alarm and continue.
   - ☐ Phone B can rejoin the same game (state is saved on the server).

---

## 9. Senior-friendliness spot checks

- ☐ Text is large and high-contrast throughout.
- ☐ Buttons are big and easy to tap.
- ☐ The host pace is **calm and clear** — not rushed, not shouting.
- ☐ Nothing makes a **surprise loud noise** when the phone is muted (except the safety alarm).

---

## 10. Known notes for this build

- **`EASY_TEST_AUTH=true`** is enabled for testing (the "Quick Test Sign-In" button). Turn OFF
  before release.
- **Host voice clips are original TTS placeholders** (male, Piper `en_US-ryan-high`). A
  studio-recorded voice-over can be dropped in later using the same filenames — no code change.
- **Podium busts** use the base body art (not yet each player's full custom hair/outfit); wiring
  the full custom character onto the podium is a planned follow-up.
- The **speak-to-guess microphone** is present but speech-to-text is a later phase — typing is the
  supported path and always works.

---

## 11. Result log

| Area | Pass/Fail | Notes |
|------|-----------|-------|
| 2 Sign in |  |  |
| 3 Character |  |  |
| 4 Two-phone join + start |  |  |
| 5 Studio stage visuals |  |  |
| 6 Host voice + cues |  |  |
| 7 Sound settings |  |  |
| 8 Disconnect alarm |  |  |
| 9 Senior-friendliness |  |  |

**Tester:** ________________  **Devices:** ________________  **Date:** ____________
