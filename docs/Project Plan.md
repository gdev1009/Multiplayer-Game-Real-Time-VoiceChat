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


## Milestone 6 — Guy Smiley Host + Audio System · $750 · 8–9 days

**Scope**
- Host character with voice (pre-recorded clips) + idle animations.
- Rules intro every game, round announcements, winner fanfare, disconnect commentary.
- Audio: opening theme + announcer intro, applause/cheer SFX, mute/volume control, respects silent
  mode.
- Full disconnect alarm sequence: red screen flash + ALERT audio + AWOOGA horn.

**Dependency:** Guy Smiley art; licensed theme/announcer audio (developer-sourced).
**Definition of done:** host narrates a full game; all audio cued correctly; disconnect alarm fires;
volume/mute respected. *(ElevenLabs dynamic lines are a later phase.)*

---

## Milestone 7 — AI Characters & Friend Connection · $450 · 7–9 days

**Scope**
- AI clue-giving/guessing logic (moderate difficulty); AI never disconnects.
- Starter idle-animation set (selfie, tongue, hair-fix, worry, smug, shrug…).
- **Friend connection:** after a matched game, "Play again with [Player]?" → in-app friend request
  → friends list → invite to future games. No personal info exchanged.

**Definition of done:** AI fills seats and plays a coherent game; mutual friend requests create a
friendship; friends can be invited from the list. *(Full animation library is a later phase.)*

---

## Milestone 8 — Prize Room & Trophy System · $550 · 5–6 days

**Scope**
- Personal prize room with trophy/prize shelves in clay style.
- Earning logic (first win, 10/50 games, etc.); room expands as items are earned.

**Dependency:** trophy/prize art.
**Definition of done:** trophies/prizes award on the right milestones and persist; room renders and
expands; viewable from profile.

---

## Milestone 9 — Subscription Billing & Free Trial · $800 · 7–9 days

**Scope**
- $5.99/mo products on Apple App Store + Google Play.
- 7-day free trial (no card up front), Day-3 countdown timer, warm Day-7 prompt.
- Access gating after trial; entitlement mirrored server-side.

**Definition of done:** trial starts and counts down; purchase unlocks access on both stores; expiry
gates play; restore-purchases works.

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
