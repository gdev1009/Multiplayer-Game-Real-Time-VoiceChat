# Match Word — Project Delivery Plan

**Product:** Match Word (Grandma Mac)
**Developer:** Gregory H. (@HamparProd)
**Stack:** Flutter (iOS + Android) · Supabase (Postgres, Auth, Realtime, Storage)
**Engagement:** Fixed-price, milestone-based · **$6,550 CAD** · Phase 1
**Spec:** Match Word Developer Technical Specification v2.0

This document is the working delivery plan. Each milestone lists scope, deliverables, the
"definition of done" used before requesting payment, and the proof-of-work shared with the client.

---

## Guiding Principles (apply to every milestone)

- **Senior-first UI** — 18pt+ body, 22pt+ game actions, 48×48pt tap targets, high contrast, one
  primary action per screen, text labels on every control, no rushed timers, **no ads**, and the
  word "AI" never appears anywhere in the app.
- **Server-authoritative** — game state lives in Supabase, never trusted from the client alone.
- **Proof before payment** — screenshots / test build shared before each milestone is released.
- **Communication** — Freelancer chat only, grouped scheduled updates, weekdays, weekends off.
- **Quality gates** — each milestone must pass: builds clean, no analyzer warnings, manual test
  pass on a small screen (iPhone SE class), and the milestone's done-criteria below.

---

## Architecture Overview

```
Flutter app (lib/)
├── core/        design system, shared widgets, config, utils
├── models/      typed data models
├── services/    Supabase-facing services (auth, profile, device, trial, game, audio…)
└── features/    one folder per feature area (auth, lobby, game, host, prizes, billing…)

Supabase
├── auth.users               native auth (email identity, used for recovery)
├── profiles                 player profile, PIN hash, device id, trial state
├── device_trials            device-id trial-abuse ledger
├── games / game_players     lobby + room state (M4)
├── rounds / turns / clues   gameplay records (M5)
├── friendships              friend connections (M7)
├── trophies / prizes        prize room (M8)
└── subscriptions            entitlement mirror (M9)
```

---

## Milestone 1 — Sign In & Account System · $550 · 5–7 days · **COMPLETE**

**Scope**
- First-time account creation: first name → email (once) → 4-digit PIN, one decision per screen.
- Daily login: first name + 4-digit PIN.
- Forgot-PIN recovery via email one-time code, then set a new PIN.
- Silent device-ID trial-abuse prevention (device fingerprint recorded at trial start, checked at
  account creation). *(IP layer is a later phase.)*
- Foundation: Supabase wiring, secure local session storage, base senior-friendly theme/widgets.

**Deliverables**
- Running auth flow on iOS + Android.
- Supabase schema migration (`profiles`, `device_trials`) with row-level security.
- `AuthGate` that routes: no account → Welcome/Create; account on device → Daily Login; signed in → Home placeholder.

**Definition of done**
- New user can create an account and reach the (placeholder) home screen.
- Returning user logs in with name + PIN.
- Wrong PIN is rejected with a calm, large-text message.
- Forgot-PIN sends a code and lets the user set a new PIN.
- Re-using a device that already consumed a trial does not grant a second trial (silent).
- All screens meet the senior-first UI checklist.

**Proof of work:** screen recording of create → logout → daily login → forgot-PIN, plus a debug build.

Checklist: `docs/Milestone 1 Sign-off Checklist.md`

---

## Milestone 2 — Opening Screen & Navigation · $400 · 4–5 days · **COMPLETE**

**Scope**
- App navigation shell and routing.
- Opening screen with Guy Smiley greeting and two large buttons: *Check Upcoming Games* and
  *Enter the Studio*.
- Formalize the senior-friendly **design system** (color tokens, typography scale, spacing,
  button/field components, accessibility helpers) so all later screens reuse it.

**Definition of done:** navigable shell; opening screen matches brand colours (#5B2D8E etc.); design
system documented and reused; passes UI checklist on iPhone SE.

Design system: `docs/Design System.md`

---

## Milestone 3 — Character Creation System · $650 · 6–7 days · **90% (final art pending)**

**Milestone 3+ add-on (approved 2026-07-03): official base body renders · +$120 CAD, rolled into M3.**
- Deliver 2 master base bodies (female + male), 1254×1254 transparent PNG, front-facing, warm
  Guy Smiley clay style with bigger/rounder heads — to serve as the artist's north-star reference.
- Includes a "safe zone" registration guide (head centre, eye line, shoulder line, hem line) so the
  Fiverr artist paints hair/eyes/glasses/outfits in perfect alignment.
- One revision round with the client before the bodies are finalized and sent to the artist.

**Update — base bodies DELIVERED (2026-07-06):** both master base bodies generated and installed as
spec-perfect 1254×1254 transparent PNGs (`assets/images/character/base/body-female.png`,
`body-male.png`), auto-registered to the safe-zone landmarks (head-top y90, feet y1200, centre x627).
Repeatable pipeline lives in `app/tools/generate_base_bodies.py` (`--dry-run` previews prompt + cost).
The safe-zone guide + references ship in `app/dist/MatchWord-Character-Artist-Pack.zip`.

**Scope**
- Step-by-step wizard (one choice per screen): base figure → hair → eyes → glasses → outfit →
  display name → preview/confirm.
- Paper-doll assembly engine that layers client-provided PNG assets.
- Save character to profile; allow later editing from settings.
- Neutral-PNG colour tinting for hair and eyes: one colourless PNG per style, coloured in-app
  (hair: black/brown/auburn/blonde/grey/white; eyes: brown/hazel/green/blue/grey).

**Dependency:** client-provided layered PNG character assets.
**Definition of done:** a character can be built, previewed, saved, reloaded, and edited; renders
crisply on small screens; assembly engine handles missing/None layers gracefully.

**Proof of work:** `app/screenshots/` — face selection, hair-colour tint (auburn), eye-colour tint
(blue), and the review/save screen, captured from the running builder.

**Update — premium "Character Studio" + body types (new art):**
- Rebuilt around Ronna's real clay art: a spotlit **Character Studio** stage (backdrop, floor
  shadow, progress bar, animated glossy tiles).
- **Two body types** — Woman and Man — each a real full-body clay render, selectable in step 1.
- **Skin-tone tinting** on the body (Light / Medium / Tan / Deep) via in-app colour modulation.
- **Real drop-in hair**: the client's spiky hair PNG loads and tints across all six hair colours
  (black/brown/auburn/blonde/grey/white), aligned to the head on both bodies.
- Every other layer (eyes, glasses, outfit) still drops in by filename with a graceful vector
  fallback until final art arrives.
- Validated: `flutter analyze` clean, all tests pass. Release APKs built for phone (arm64/arm32)
  and LDPlayer (x86_64) in `app/dist/`.
- Proof screenshots: `app/screenshots/new_08_female_spiky.png`, `new_10_blonde.png`,
  `new_11_male_spiky.png`.

**Update — name-on-shirt + edit-later (spec parity):**
- **Name-on-shirt** implemented: the player's name now prints across the front of the shirt in the
  live preview (uppercase jersey style, auto-scales to fit long names, dark outline so it reads on
  any outfit colour). Shows whenever an outfit is worn.
- **Edit later** verified working: the home screen's **Edit** button re-opens the wizard with every
  saved choice (body, colours, hair, eyes, glasses, outfit, name) pre-filled, and re-saves in place.
- **Per-body art support** added to the engine: each accessory can load a body-specific render
  (`<id>__body-female.png` / `<id>__body-male.png`) so parts fit each figure precisely, falling back
  to the shared file, then the vector placeholder. Artist brief updated in
  `app/assets/images/character/README.md`.
- Validated: `flutter analyze` clean, 16/16 tests pass, APKs rebuilt in `app/dist/`.

**Remaining 10% (final art):** the flow, save/edit, name-on-shirt and assembly are all done and
shipping. The last 10% is swapping the placeholder hair/eyes/glasses/outfit vectors for the
premium rendered art pack — a pure drop-in by filename, **no code changes**. Marked COMPLETE once
the art pack lands.


---

## Milestone 4 — Lobby, Game Codes & Matchmaking · $600 · 7–8 days

**Scope**
- Create game → generates a 4-digit code; share outside the app.
- Join by code; *Check Upcoming Games* list with player counts.
- Solo stranger matchmaking; AI seat-fill when a full group isn't found.
- Role assignment (Player 1/2/A/B), team formation, greet each player by first name.

**Definition of done:** four devices (or device + AI fill) can land in one lobby with correct roles
and teams; Realtime lobby state stays in sync; codes are unique and expire sensibly.

**Update — build in progress (2026-07-06):** the lobby vertical slice is implemented and passing all
quality gates (analyze clean, 25/25 tests).
- **Server-authoritative schema** (`supabase/migrations/0004_lobby.sql`, applied to live DB): `games`
  + `game_players` tables, RLS with SELECT-only client access, and `SECURITY DEFINER` functions as the
  only write path — `mw_create_game`, `mw_join_game`, `mw_quick_match`, `mw_fill_seats`,
  `mw_start_game`, `mw_leave_game`, plus seat/role helpers.
- **4-digit codes**: unique among active lobbies (partial unique index), auto-expire after 24h.
- **Teams & roles**: seats map 0→A1, 1→B1, 2→A2, 3→B2 (Team A / Team B); SQL and Dart
  (`LobbyRoles`) mapping verified identical.
- **Matchmaking**: "Find a Game" quick-matches into the oldest open public lobby or opens a new one;
  join-by-code; host "Add Players" fills empty seats with studio players (the word "AI" never appears
  in the UI, per the guiding principles).
- **Realtime**: `games` + `game_players` on the `supabase_realtime` publication; the client subscribes
  via `.stream()` so seats update live as players join/leave and when the host starts.
- **UI** (senior-first, reuses the design system): lobby hub (`upcoming_games_screen.dart`),
  4-digit code entry (`join_by_code_screen.dart`), and the live room with shareable code, team seats,
  and host controls (`lobby_room_screen.dart`).

**Update — premium completion (2026-07-08):** closed the remaining spec gaps so both lobby entry
points are fully live and the "definition of done" is met end to end.
- **Player counts in "Check Upcoming Games"** — the open-games list now shows live occupancy
  ("2 / 4 players") for each joinable lobby, and full games drop off the list automatically. Backed
  by a single `SECURITY DEFINER` function (`supabase/migrations/0005_lobby_counts.sql` →
  `mw_list_open_games`) that returns each open public game with its live `player_count`, avoiding
  per-row count queries.
- **"Enter the Studio" now hosts/joins** — the Studio screen (previously a Milestone-2 placeholder)
  is wired to the lobby: **Start a New Game** opens a private room to share by code, and **Join with
  a Code** enters a friend's game. Public matchmaking stays on the "Check Upcoming Games" hub.
- **Share the code outside the app** — the game room's code card now opens the **native share sheet**
  (`share_plus`) so a host can send the code by text, email, or any messaging app, in addition to
  copy-to-clipboard. Fulfils "generates a 4-digit code; share outside the app."
- Validated: `flutter analyze` clean, **28/28 tests** pass (added occupancy/`player_count` coverage),
  and the arm64 release APK builds cleanly with the new plugin.

**Update — sign-off build (2026-07-08):** `0005_lobby_counts.sql` applied to the live Supabase
project. Full `--split-per-abi` release APK set rebuilt and refreshed in `app/dist/`
(`MatchWord-phone-arm64.apk`, `MatchWord-phone-arm32.apk`, `MatchWord-LDPlayer-x86_64.apk`).

**Update — visual verification pass (2026-07-09):** M3 and M4 re-checked end to end and captured as
proof in `docs/screenshots/milestone3-4/`. M3: character studio wizard (body → hair → eyes →
glasses → outfit → name → review), with glasses/eyes/outfit now placed correctly on the clay body,
name-on-shirt, save, and edit-later (all choices pre-filled) all confirmed. M4: Play-a-Game hub
(Find a Game / Start a New Game / Join with a Code), the live Game Room with a shareable 4-digit
code, Team A/B seats filling with players, and the "game is starting" hand-off, plus the
Join-with-a-Code number pad. The M4 screens run against an in-memory lobby (`lib/demo_lobby.dart`,
a dev-only entry mirroring `lib/demo_character.dart`) so the flow can be shown without a live
backend. `flutter analyze` clean, 28/28 tests pass.

**Remaining before sign-off:** multi-device manual test pass on the live backend.


---

## Milestone 5 — Core Gameplay Engine · $1,350 · 12–14 days

**Scope**
- Server-authoritative turn system: first half / halftime / second half, role switch.
- Dual input (voice **or** text) for clues and guesses, with text fallback always available.
- Clues and guesses visible to all players in real time.
- Steal mechanic; ~5-exchange auto-reveal; scoring.

**Definition of done:** a full game can be played end-to-end across devices; turns, steals, reveals,
and scoring all enforced server-side; voice input degrades gracefully to text.

**Update — engine + play screen built (2026-07-09):** the full gameplay vertical slice is implemented
and passing all quality gates (`flutter analyze` clean, **45/45 tests** — 17 new engine tests).
- **Authoritative rules engine** (`lib/features/game/game_engine.dart`): a pure-Dart reducer with an
  explicit state machine — `firstHalf → halftime → secondHalf → gameOver`, and per-turn
  `awaitingClue → awaitingGuess → resolved`. Handles clue/guess, the **steal** (a wrong guess drops
  the word value by 1 and passes to the other team), **~5-exchange auto-reveal** for no points, and
  the **halftime role switch** (each team swaps clue-giver ↔ guesser). Seat→role mapping (0→A1,
  1→B1, 2→A2, 3→B2) matches the lobby exactly, so gameplay greets each player **by name *and* role**
  ("Sunny, you're Player A1") — the behaviour Ronna asked about.
- **Server-authoritative writes** (`supabase/migrations/0007_gameplay.sql`): `game_state`,
  `game_words`, `game_plays` tables; the same rules mirrored in `SECURITY DEFINER` functions
  (`mw_begin_play`, `mw_submit_clue`, `mw_submit_guess`, `mw_next_word`, `mw_begin_second_half`) as
  the only write path, with turn validation (`mw_actor_ok`) and SELECT-only RLS for clients. Live
  updates flow over the `supabase_realtime` publication.
- **Voice-or-text input** (`lib/features/game/word_input.dart`): a big press-to-speak mic beside a
  large text field with a Send button — the **text fallback is always available**, so the flow never
  dead-ends before the speech engine (M6+) is wired.
- **Play screen** (`lib/features/game/play_screen.dart`): scoreboard, both team desks with Guy Smiley
  in the middle, the host turn banner, the shared real-time clue/guess feed, and calm halftime /
  game-over panels. Wired into the lobby room so the host's **Start Game** hands every player off to
  the live board (`gameplay_controller.dart` + `gameplay_service.dart`).
- **Verified end to end** and captured in `docs/screenshots/milestone5/`: a complete 8-word game —
  clue → guess, a steal (word value 5 → 4, turn passes teams), correct-guess scoring, the halftime
  role switch (Walter/Mabel become clue-givers, Sunny/Rosa become guessers), and the winner
  announcement (Team B 24 – 15). Runs offline via a dev-only entry (`lib/demo_game.dart`).

**Remaining before sign-off:** apply `0007_gameplay.sql` to the live Supabase project and run a
multi-device manual test pass; the speech-to-text provider is scoped with the M6 host/audio work.

---


## Milestone 6 — Guy Smiley Host + Audio System · $750 · 8–9 days · **COMPLETE (code)**

**Scope**
- Host character with voice (pre-recorded clips) + idle animations.
- Rules intro every game, round announcements, winner fanfare, disconnect commentary.
- Audio: opening theme + announcer intro, applause/cheer SFX, mute/volume control, respects silent
  mode.
- Full disconnect alarm sequence: red screen flash + ALERT audio + AWOOGA horn.

**Dependency:** Guy Smiley art; licensed theme/announcer audio (developer-sourced).
**Definition of done:** host narrates a full game; all audio cued correctly; disconnect alarm fires;
volume/mute respected. *(ElevenLabs dynamic lines are a later phase.)*

**Delivered:** pure cue mapper `features/host/host_audio.dart` (SoundCue → announcer/effect/voice,
mapped from each game-state transition) + `services/audio_controller.dart` (theme loop, layered SFX,
host voice, persisted mute + music/effects volume, silent-mode-respecting session). Animated Guy
Smiley (`features/host/host_stage.dart`, idle bob + excited bounce/glow, real host art) and the
full-screen `DisconnectAlarm` (red flash + host commentary + Keep Playing). Sound button + settings
sheet (`features/host/sound_settings.dart`) wired into `PlayScreen`; `AudioController` provided in
`main.dart`. Placeholder royalty-free audio via `tools/generate_audio_cues.py`; real theme/announcer/
host voice are drop-in by filename (`assets/audio/`, `assets/audio/voice/README.md`). Validated:
`flutter analyze` clean, 63 tests pass (13 new host-audio cue tests). Proof: screenshots + reel in
`docs/screenshots/milestone6/` (kickoff, sound settings, correct celebration, disconnect alarm,
halftime; `match-word-host-audio.mp4`/`.gif`).

**Game-show studio stage (follow-up to `studio-concept-mockup.png`).** Rebuilt the play stage to
match the approved concept: a deep-purple studio lit by soft spotlights (`features/host/
studio_stage.dart`), a gold-framed **MATCH WORD** scoreboard, the current-word tile (shows the secret
word to the clue-giver during the clue step, the word counter otherwise so the guesser can't read it),
two team podiums with character busts + gold nameplates that glow gold for the active seat, and a
full-body **Guy Smiley** centre-stage holding his microphone with a lavender speech bubble + gold
nameplate. Uses a transparent cut-out of the delivered host art (`assets/images/host/host-stage.png`
via `tools/cutout_host.py`). Wired into `PlayScreen` (replaces the old score-chip/desk widgets).
Re-validated: `flutter analyze` clean, 63 tests pass. Live proof:
`docs/screenshots/milestone6/studio-stage-live.png`.

**Premium polish pass.** Podium busts are now the **real artist clay characters** — head-and-shoulders
crops of the base bodies (`tools/build_busts.py` → `assets/images/host/bust-female.png` /
`bust-male.png`), chosen per player, replacing the flat placeholder avatars. Added stage animations:
per-seat idle head-bob, active-seat scale-up + gold spotlight halo, host bob + speaking bounce/tilt,
pop-in speech bubble, and pop transitions on the word tile + team scores. **Host voice is now live**:
seven spoken Guy Smiley lines in an **original male game-show-host voice** — generated offline with
Piper neural TTS (voice `en_US-ryan-high`; warm, clear, senior-paced, North-American, original — no
actor/celebrity impression) via `tools/generate_host_voice.py` → `assets/audio/voice/*.mp3`
(rules_intro, your_turn, nice_guess, good_try, halftime, winner, disconnect). A studio voice-over drops
in by the same filenames. Audition clip: `docs/screenshots/milestone6/host-voice-sample.mp3`. Verified
the audio path plays them on device (`AssetSource('audio/voice/…')`; iOS ambient category still respects
the silent switch).

**Two-phone test build.** Release APKs built and published to `apks/` for live two-device testing over
the existing Supabase online path (`MatchWord-M6-phone-arm64`, `-arm32`, `-LDPlayer-x86_64`).
**Security hardening:** the app-bundled `app/.env` was carrying server secrets (`OPENAI_API_KEY`,
`MAILGUN_API_KEY`) that would ship inside every APK — moved `OPENAI_API_KEY` to
`supabase/functions/.env`, removed both from the client `.env` (only `SUPABASE_URL`/`SUPABASE_ANON_KEY`/
`EASY_TEST_AUTH` remain), and hardened `.gitignore` to ignore `.env.*` backups.

---

## Milestone 7 — AI Characters & Fun Idle Animations · $450 · 7–9 days · **COMPLETE (code)**

**MVP scope**
- AI clue-giving/guessing logic (moderate difficulty); AI never disconnects.
- A **fun starter idle-animation set** for the clay characters (tongue, worry, smug, shrug,
  hair-fix, selfie…) plus a subtle procedural breathe/sway.

**Definition of done (MVP):** AI fills seats and plays a coherent game; character avatars come to
life with the starter idle poses.

**Deferred to Phase 2 (post-MVP):**
- **Full animation library** (the complete pose/expression set beyond the starter poses).
- **In-game friend-request flow** — "Play again with [Player]?" → friend request → friends list →
  invite to future games. *Not part of the MVP.*

**Delivered (MVP)**
- **Moderate-difficulty AI** (`ai_player.dart`): studio players give varied one-word clues (never the
  word) and guess with ~70% accuracy, offering a plausible related-but-wrong guess otherwise so steals,
  reveals and realistic scores happen naturally. Guesses are seeded per turn (word + exchange) so the
  host produces a stable result even after a retried request. Host-driven, so a studio player never
  disconnects. Covered by `test/ai_player_test.dart`.
- **Starter idle animation** (`core/widgets/idle_animation.dart` + named pose
  frames): procedural breathe/sway, plus pose PNGs generated by editing the
  **current artist** `body-female` / `body-male` via `tools/generate_idle_poses.py`
  (tongue / worry / smug / shrug / hairfix / selfie × both bodies). Face poses
  cycle on the Opening character card **and on live stage busts** through
  `IdleCharacterPreview`. Source bodies in `base/` were **not** replaced.
  (`generate_base_bodies.py` is now gated — artist bodies are the source of
  truth via `import_character_art.py`.)

**Phase 2 groundwork already in the repo (not wired into the MVP build):**
- Friend connection server layer — migration `app/supabase/migrations/0014_friends.sql` (`friendships`
  + `game_invites`, `SECURITY DEFINER` functions, RLS; returns only display name + cosmetic layers,
  no personal info) — and the app layer (`FriendService`, `FriendController`, `Friend`/`FriendRequest`/
  `GameInvite` models, `FriendsScreen`). Kept for Phase 2; the MVP does not surface the friend flow.

---

## Milestone 8 — Prize Room & Trophy System · $550 · 5–6 days · **COMPLETE (code; placeholder art)**

**Scope**
- Personal prize room with trophy/prize shelves in clay style.
- Earning logic (first win, 10/50 games, etc.); room expands as items are earned.

**Dependency:** trophy/prize art.
**Definition of done:** trophies/prizes award on the right milestones and persist; room renders and
expands; viewable from profile.

**Delivered**
- Migration `0015_prizes.sql` — catalog, `player_awards`, profile `games_played` / `games_won`,
  `mw_my_prize_room` / `mw_record_match_result`.
- App: `PrizeService`, `PrizeController`, `PrizeRoomScreen` (Opening → Prize Room), award hook on
  game-over in `PlayScreen`.
- **Placeholder** trophy/prize PNGs under `assets/images/trophies/` and `assets/images/prizes/`
  (IDs match `clay_source/README.md` naming). Swap when client clay art arrives.

---

## Milestone 9 — Subscription Billing & Free Trial · $800 · 7–9 days · **IN PROGRESS (scaffold)**

**Scope**
- $5.99/mo products on Apple App Store + Google Play.
- 7-day free trial (no card up front), Day-3 countdown timer, warm Day-7 prompt.
- Access gating after trial; entitlement mirrored server-side.
- **iOS TestFlight** delivery for client testing (upload from Mac — see `docs/TestFlight Setup.md`).

**Definition of done:** trial starts and counts down; purchase unlocks access on both stores; expiry
gates play; restore-purchases works.

**Delivered so far (scaffold — no live store / no signed IPA on Linux)**
- Migration `0016_subscriptions.sql` + `BillingService` / `EntitlementService` / `PaywallScreen`.
- Day-3+ countdown banner copy; soft-gate to paywall when trial expired.
- Product id `matchword_monthly_599`; purchase/restore return calm “coming soon” until StoreKit /
  Play Billing are wired on a Mac with App Store Connect products.
- `docs/TestFlight Setup.md` for archive + invite (Ronna).

---

## Milestone 10 — Testing, Bug Fixes & Store Submission · $450 · 6–8 days

**Scope**
- Full QA pass, senior-usability review, performance testing on small/old devices.
- Bug-fix pass; store assets; submission to Apple App Store and Google Play.

**Definition of done:** clean QA sheet; builds signed; both store submissions completed; launch
checklist signed off.

---

## Later-Phase Backlog (not in Phase 1)

- Full AI idle-animation library
- ElevenLabs dynamic Guy Smiley announcements
- IP-based trial-abuse layer
- Physical mailed trophies
- Tournament brackets · localization

---

## Cross-Cutting Tracks (run alongside milestones)

- **Security:** RLS on every table, PIN hashing, secrets out of the repo, least-privilege keys.
- **Testing:** unit tests for services/logic, widget tests for key screens, manual device matrix.
- **CI/Build:** consistent `flutter analyze` + format gate; tagged builds per milestone.
- **Docs:** keep this plan and the quote in sync as scope is confirmed in writing.


Guy Smiley Action List
1. Game Start
Welcome wave
Guy Smiley waves to players with a big smile.
Microphone intro
Holds microphone close and introduces the game.
Point to Start button
Gestures toward the start area or room code.
2. Player Turn
Point to current player
Open-hand gesture toward the active player.
Give a clue prompt
Holds microphone forward like he is inviting the player to speak.
Listening pose
Leans slightly forward with microphone ready.
Thinking pose
Hand on chin, friendly curious expression.
3. Correct Answer
Green flag wave
Waves small green flag up and down.
Thumbs up
Gives a big friendly thumbs up.
Applause pose
Claps hands with happy expression.
Celebration pose
Raises one arm with confetti or sparkle effect.
4. Wrong Answer / Steal
Red flag shake
Shakes small red flag up and down.
Gentle no gesture
Friendly head shake, not harsh.
Open palm stop gesture
Soft “not quite” pose.
Steal prompt
Points to the next player/team for a steal chance.
5. Reveal
Golden card reveal
Presents a glowing gold card/panel with open hand.
Ta-da gesture
One hand out, smiling, like revealing the answer.
Card flip animation
Holds a card that flips over to show the answer.
Spotlight reveal
Points toward a glowing answer area.
6. Timer / Pressure
Clock warning pose
Holds or points to a small clock.
Finger raised reminder
Raises one finger like “time is almost up.”
Gentle hurry gesture
Small hand motion, still friendly and not stressful.
7. Score / Round End
Scoreboard point
Points to the score area.
Happy nod
Nods approvingly after points are added.
Round complete pose
Hands open, proud host expression.
Game End
Winner announcement pose
Holds microphone high and gestures to winner.
Trophy presentation
Presents a small trophy.
Final applause
Claps for all players.
Goodbye wave
Friendly wave to end the game.