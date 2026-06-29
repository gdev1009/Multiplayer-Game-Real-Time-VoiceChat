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

## Milestone 1 — Sign In & Account System · $550 · 5–7 days · **IN PROGRESS**

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

---

## Milestone 2 — Opening Screen & Navigation · $400 · 4–5 days

**Scope**
- App navigation shell and routing.
- Opening screen with Guy Smiley greeting and two large buttons: *Check Upcoming Games* and
  *Enter the Studio*.
- Formalize the senior-friendly **design system** (color tokens, typography scale, spacing,
  button/field components, accessibility helpers) so all later screens reuse it.

**Definition of done:** navigable shell; opening screen matches brand colours (#5B2D8E etc.); design
system documented and reused; passes UI checklist on iPhone SE.

---

## Milestone 3 — Character Creation System · $650 · 6–7 days

**Scope**
- Step-by-step wizard (one choice per screen): base figure → hair → eyes → glasses → outfit →
  display name → preview/confirm.
- Paper-doll assembly engine that layers client-provided PNG assets.
- Save character to profile; allow later editing from settings.

**Dependency:** client-provided layered PNG character assets.
**Definition of done:** a character can be built, previewed, saved, reloaded, and edited; renders
crisply on small screens; assembly engine handles missing/None layers gracefully.

---

## Milestone 4 — Lobby, Game Codes & Matchmaking · $600 · 7–8 days

**Scope**
- Create game → generates a 4-digit code; share outside the app.
- Join by code; *Check Upcoming Games* list with player counts.
- Solo stranger matchmaking; AI seat-fill when a full group isn't found.
- Role assignment (Player 1/2/A/B), team formation, greet each player by first name.

**Definition of done:** four devices (or device + AI fill) can land in one lobby with correct roles
and teams; Realtime lobby state stays in sync; codes are unique and expire sensibly.

---

## Milestone 5 — Core Gameplay Engine · $1,350 · 12–14 days

**Scope**
- Server-authoritative turn system: first half / halftime / second half, role switch.
- Dual input (voice **or** text) for clues and guesses, with text fallback always available.
- Clues and guesses visible to all players in real time.
- Steal mechanic; ~5-exchange auto-reveal; scoring.

**Definition of done:** a full game can be played end-to-end across devices; turns, steals, reveals,
and scoring all enforced server-side; voice input degrades gracefully to text.

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
