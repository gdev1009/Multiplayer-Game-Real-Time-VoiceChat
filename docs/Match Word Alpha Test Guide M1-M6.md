# Match Word — Alpha Test Guide (Milestones 1–6)

**For:** Ronna (Grandma Mac)  
**Build date:** 2026-07-13  
**Latest APKs** (in the `apks/` folder shared with this note):

| Device | File |
|--------|------|
| Most phones (recommended) | `MatchWord-stagefix2-phone-arm64-20260713.apk` |
| Older 32-bit phones | `MatchWord-stagefix2-phone-arm32-20260713.apk` |
| LDPlayer emulator | `MatchWord-stagefix2-LDPlayer-x86_64-20260713.apk` |

**App ID:** `com.matchword.app` · **Backend:** live Supabase  
**Scope covered:** Sign-in (M1) → Opening screen (M2) → Character Studio (M3) → Lobby & matchmaking (M4) → Core gameplay (M5) → Guy Smiley host + audio + studio stage (M6)

> Work top to bottom. Each check has a ☐ box — mark **PASS / FAIL** and note anything unexpected.  
> Exact on-screen labels are quoted in **bold**.

---

## 1. Before you start

### 1.1 What you need
- **Two Android phones** when possible (best way to prove online play). One phone still works for a solo game with studio players filling seats.
- **Working internet** on each device (Wi‑Fi or mobile data). Phones do **not** need to be on the same Wi‑Fi — they sync through the server.
- **Volume up**, silent / Do Not Disturb **off**, so you can hear Guy Smiley and the music.
- Allow **“Install unknown apps”** when installing the APK.

### 1.2 Install
1. Copy the matching APK to the phone (USB, Drive, AirDrop‑to‑PC, etc.).
2. Open the file → install → launch **Match Word**.

### 1.3 About **Quick Test Sign-In** (important)

This test build includes a large purple button labeled **“Quick Test Sign-In”** on the Welcome (and Daily Login) screen.

- It exists **only so testers can jump in quickly** without creating an email + PIN account.
- **It is temporary.** It will **not** appear in the productive / store version. Real players will only use Create Account / Daily Login / Forgot My PIN.
- Prefer Quick Test Sign-In for this alpha pass; optionally also try the real account flow (§3.2) once if you have time.

---

## 2. How the game works (quick refresher)

Match Word is a calm, Password-style team word game:

1. Four seats, two teams (**Team A** and **Team B**), with **Guy Smiley** hosting in the middle.
2. For each secret word, one team is “on the clock”: a **clue-giver** and a **guesser**.
3. The **clue-giver** sees the secret word (e.g. **PANCAKE**) and types **one different word** that hints at it — they must **not** say the secret word itself.
4. The **guesser** does **not** see the secret word. They try to guess it from the clue.
5. **Correct guess** → that team scores the word’s current points (starts at 5, drops after failed tries).
6. **Wrong guess** → a **steal**: the other team gets a turn to clue/guess for fewer points.
7. After enough failed exchanges, the word is **revealed** for **no points**.
8. Mid-game there is a **halftime** role switch; at the end, a winner (or tie) is announced.

**Total words:** usually **8** (4 + 4). A final score like **5–5** *can* be a valid tie if only a few words were guessed; with studio players helping, scores often climb higher. Looking for scores that **move off 0–0** as words are solved is the main check.

---

## 3. Sign-in (Milestone 1)

### 3.1 Quick Test Sign-In (recommended for this build)
1. On **Welcome to Match Word**, tap **“Quick Test Sign-In”**.
2. ☐ You land on the **Opening Screen** with a Guy Smiley greeting (e.g. *“Hello …! So glad you are here.”*).
3. Do this on **both** phones so each has its own test identity.

### 3.2 Real account flow (optional)
1. Tap **“Create My Account”**.
2. Enter **first name** → **Next**.
3. Enter a real **email** → **Next**.
4. Choose a **4-digit PIN** → confirm the same PIN.
5. ☐ You reach the Opening Screen.
6. ☐ Optional: Sign out, reopen → **Daily Login** with name + PIN.
7. ☐ Optional: **Forgot My PIN** → email code → set a new PIN.

---

## 4. Opening screen (Milestone 2)

From the Opening Screen, check:

- ☐ Large, calm greeting and senior-friendly buttons.
- ☐ **“Check Upcoming Games”** and **“Enter the Studio”** (or equivalent Play hub entry) are obvious.
- ☐ Character card shows **“Create a Character”** or your saved character with **Edit**.
- ☐ Trial / remaining-days messaging (if shown) is readable and not crowded.
- ☐ **Sign Out** works and returns to Welcome.

---

## 5. Character Studio (Milestone 3)

Create a character on **each** phone (use **different display names**, e.g. **Rosa** and **Walter**).

1. Open **Character Studio**.
2. ☐ **Body** — Woman / Man → **Next**.
3. ☐ **Hair** — style or None → **Next**.
4. ☐ **Outfit** → **Next**.
5. ☐ **Glasses** — style or None → **Next**.
6. ☐ **Accessories** (hat / earrings / etc., each may have None) → **Next**.
7. ☐ **Name** (required) → **Next**.
8. ☐ **Review** → **“Save my character”** → confirmation.
9. ☐ Opening Screen now shows your character.
10. ☐ **Edit** reopens the wizard with choices pre-filled; save again works.

Tips:
- The live preview should update as you choose.
- Name appears on the shirt in the preview when an outfit is worn.

---

## 6. Lobby, codes & matchmaking (Milestone 4)

### 6.1 Host creates a private game (Phone A)
1. Open the Play hub (**Check Upcoming Games** / Studio).
2. Tap **“Start a New Game”**.
3. ☐ **Game Room** shows a large **4-digit code**.
4. ☐ **Share code** opens the phone’s share sheet; **Copy code** shows *“Code copied”*.

### 6.2 Friend joins by code (Phone B)
1. **“Join with a Code”** → enter the 4 digits → **“See the Game”** (or similar).
2. ☐ **Join preview** shows teams / seats.
3. ☐ Pick an **open seat** → land in the same Game Room.
4. ☐ Phone A sees Phone B appear within a couple of seconds (live sync).

### 6.3 Fill seats & start
1. Host: **“Add Players”** fills empty seats with **studio players** (friendly computer teammates — the app never says “AI”).
2. ☐ Seat names and teams look sensible.
3. Host: **“Start Game”** (needs enough players).
4. ☐ Both phones go to the live **Match Word** studio stage together.

### 6.4 Optional alternatives
- ☐ **Find a Game** / quick match: joins or creates a public lobby; may show *“Looking for players… studio players join in X seconds.”*
- ☐ **Upcoming games** list shows occupancy like **2 / 4 players** when available.

---

## 7. Core gameplay (Milestone 5)

Once the stage loads, play through at least a few words (ideally a full match).

### 7.1 Turning & input
- ☐ Only the player **on the clock** sees the clue/guess input; others see a calm **waiting** message.
- ☐ Clue-giver’s device: word tile shows **YOUR SECRET WORD** + the word + *“Get your team to say it — don't say it yourself!”*
- ☐ Other devices: word tile shows **Word N of 8** (not the secret).
- ☐ Input labels are clear, e.g. **“Your one-word clue”** / **“Your guess”**.
- ☐ Type and tap **Send** (mic may gently say typing is fine — text always works).

### 7.2 Scoring & flow
1. Clue-giver sends a one-word **hint** (not the secret word).
2. ☐ Clue appears in the shared feed on all devices.
3. Guesser sends a guess.
4. ☐ **Correct:** celebration / score increases on the **MATCH WORD** scoreboard (not stuck at **0 — 0** forever).
5. ☐ **Wrong:** steal — turn passes to the other team; word value can drop.
6. ☐ After a word is resolved, the host **auto-advances** to the next word after a short pause (you may also see a **Next word** control on some turns).
7. ☐ **Halftime:** roles switch; then second half continues (auto or **Start second half**).
8. ☐ **Game over:** winner or **tie** panel with final score; **Back to home** works.

### 7.3 Solo / one-phone path
If only one phone is available:
1. Start a game → **Add Players** → **Start Game**.
2. ☐ Studio players take their turns automatically.
3. ☐ When it is **your** turn, give a clue or guess.
4. ☐ Scores move as correct words are found; the match reaches a natural ending.

---

## 8. Studio stage, host & audio (Milestone 6)

### 8.1 Look of the stage
- ☐ Deep-purple studio, soft spotlights, lit floor.
- ☐ Gold **MATCH WORD** scoreboard: **TEAM A  n — n  TEAM B**.
- ☐ Cream/gold **word tile**.
- ☐ Two team podiums with **character busts** and nameplates; **active** seat glows gold.
- ☐ **Guy Smiley** full-body centre stage with microphone.
- ☐ Host **speech bubble** sits in the **centre column above the host**, **narrow**, and **does not cover** the players.
- ☐ There is **no** gold **“GUY SMILEY”** nameplate under him (intentionally removed so the stage stays cleaner).
- ☐ Light motion: host bob / talk, bust bob, score / tile pop when things change.

### 8.2 Sound (turn volume up)
- ☐ Theme / intro when the match starts.
- ☐ Male **Guy Smiley** host voice for rules / turns / correct / try again / halftime / winner (and disconnect if tested).
- ☐ Cheer / applause feel on correct guesses; separate feel for steals / reveals.

### 8.3 Sound settings
During play, open the **sound** control in the app bar:

- ☐ Mute toggle silences music + host + effects.
- ☐ **Music** and **Host & effects** sliders change levels.
- ☐ Settings are remembered after leaving and rejoining a game.
- ☐ Hardware silent / DND quietens the game (senior-friendly). Exception: disconnect alarm is meant as a safety cue.

### 8.4 Disconnect alarm (optional but valuable)
1. During a live match, put Phone B on Airplane mode (or force-close).
2. On Phone A within a few seconds:
   - ☐ Red flash / **Hold on!** style alert.
   - ☐ Alarm sound.
   - ☐ **Keep Playing** dismisses it.
3. Restore Phone B’s network and continue if possible.

---

## 9. Senior-friendliness spot check

- ☐ Large text, high contrast, big tap targets.
- ☐ One clear job per screen; no cluttered dashboards.
- ☐ Calm pace — no rushed countdown forcing mistakes.
- ☐ No ads; the word **“AI”** does not appear in the player-facing UI.
- ☐ Errors are friendly and readable.

---

## 10. Known notes for this alpha build

| Note | Detail |
|------|--------|
| **Quick Test Sign-In** | Temporary testing button only — **removed in the productive / store build**. |
| Host voice | Clear male game-show style clips; final studio-recorded lines can replace the same files later. |
| Microphone button | Present for future speech-to-text; **typing always works** today. |
| Auto-advance | Host advances resolved words / second half so games with studio players don’t stall. |
| Art / polish | Character art and stage layout continue to be refined; please flag any remaining overlaps or hard-to-read names. |

---

## 11. Result log (please fill and reply)

| Area | Pass / Fail | Notes |
|------|-------------|-------|
| 3 Sign-in |  |  |
| 4 Opening screen |  |  |
| 5 Character Studio |  |  |
| 6 Lobby / join / start |  |  |
| 7 Gameplay + scoring |  |  |
| 8 Stage + host audio |  |  |
| 8.4 Disconnect alarm (if tried) |  |  |
| 9 Senior-friendliness |  |  |

**Tester:** ________________  
**Devices:** ________________  
**APK used:** `MatchWord-stagefix2-…-20260713.apk`  
**Date:** ____________  

Thank you — your notes on what felt confusing, overlapping, or lovely are especially helpful for the next polish pass.
