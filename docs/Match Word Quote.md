# MATCH WORD — Developer Proposal & Milestone Quote

**Prepared for:** Ronna McKenzie / Grandma Mac (grandmamac.com)
**Prepared by:** Gregory H. (@HamparProd)
**Spec reference:** Match Word Developer Technical Specification, Version 2.0 (June 29, 2026)
**Date:** June 29, 2026 (Final — Phase 1 scope agreed at $6,550 CAD)
**Currency:** All prices in **CAD**
**Engagement type:** Fixed-price, milestone-based — payment released only on review and approval
**Communication:** Freelancer platform chat only

---

## 1. Summary

Thank you for sharing the full specification. I have read all 23 sections carefully. Below is my proposed
build plan: a recommended technology stack, a milestone-by-milestone fixed price, an estimated timeline,
and the assumptions the quote depends on.

The plan follows your milestone order exactly so each payment maps to a clearly demonstrable deliverable.
Every screen is built to your non-negotiable senior-friendly standards (18pt+ body text, 22pt+ game
actions, 48x48pt tap targets, high contrast, one primary action per screen, no ads, and the word "AI"
never shown anywhere in the app).

**Total fixed price: $6,550 CAD** across 10 Phase 1 milestones.
**Estimated build duration: ~13–15 working weeks** (single developer, sequential milestones).

This plan keeps the **social heart of Match Word in Phase 1** — the friend-connection feature (meeting
someone in a game and choosing to reconnect) and the Prize Room are both included, alongside the full
core game-show experience: characters, lobby, complete gameplay, Guy Smiley host, billing, and store
launch. Only a small set of polish items remains for a later phase (see Section 6).

---

## 2. Recommended Technology Stack

| Layer | Recommendation | Why |
|---|---|---|
| **App framework** | **Flutter** (Dart) | Single codebase for iOS + Android, excellent for image-layered/paper-doll UI, smooth animation, strong on small screens (iPhone SE). |
| **Backend / Realtime** | **Supabase** (Postgres + Realtime + Auth + Storage) | Server-authoritative game state, realtime sync of clues/guesses, secure storage of email + device fingerprints, generous free tier for MVP. |
| **Realtime gameplay** | Supabase Realtime channels (WebSocket-based) | Reliable multi-screen sync for clues, guesses, turns, and lobby state. |
| **Voice input** | Native iOS `SFSpeechRecognizer` / Android `SpeechRecognizer` | No per-use cost, on-device, fast. **Text fallback always available** per spec §12. |
| **Guy Smiley voice (TTS)** | **Pre-recorded clips for fixed lines + ElevenLabs** for generated lines | Pre-recorded keeps quality high and cost predictable; ElevenLabs used for dynamic announcements. Final approach confirmed with you before §6 work. |
| **Subscriptions** | Apple **StoreKit 2** (iOS) + **Google Play Billing** (Android) | Native billing as required; 7-day trial with no card up front. |
| **Auth model** | First name + 4-digit PIN, email used only for PIN recovery | Exactly as specified — familiar and simple for seniors. |

> Note on "no credit card required" trial: the 7-day trial, in-app countdown, and access gating are fully
> under our control. The store checkout flow itself is controlled by Apple/Google. Configured correctly,
> the trial starts with no card required; I will confirm the exact store configuration during Milestone 9.

---

## 3. Milestone Pricing & Timeline (Phase 1 — $6,550 CAD)

| # | Milestone | Key Deliverables | Est. Days | Price (CAD) |
|---|---|---|---|---|
| **1** | **Sign In & Account System** | First name + 4-digit PIN login, one-time email capture, Forgot-PIN email reset flow, **device-ID** fingerprint trial-abuse prevention (silent). *(IP-based layer → later phase.)* | 5–7 | **$550** |
| **2** | **Opening Screen & Navigation** | App shell + navigation, Guy Smiley greeting screen, *Check Upcoming Games* + *Enter the Studio* buttons, senior-friendly design system (fonts, contrast, tap targets) established here. | 4–5 | **$400** |
| **3** | **Character Creation System** | 7-step one-choice-per-screen wizard, paper-doll assembly from client PNG layers, name-on-shirt, preview/confirm, save to profile, edit later. | 6–7 | **$650** |
| **4** | **Lobby, Game Codes & Matchmaking** | Create game + 4-digit code, join by code, *Check Upcoming Games* list, **solo stranger matchmaking**, role assignment (Player 1/2/A/B), team formation, AI seat-fill. | 7–8 | **$600** |
| **5** | **Core Gameplay Engine** | Server-authoritative turn system, dual input (voice + text) for clues & guesses, clue/guess visible to all, steal mechanic, ~5-exchange word reveal, scoring, first half / halftime / second half, role switch. | 12–14 | **$1,350** |
| **6** | **Guy Smiley Host + Audio System** | Host character with voice + idle animations, rules intro every game, round announcements, theme music + announcer intro, applause/cheer SFX, full disconnect alarm (red flash + ALERT + AWOOGA horn), mute/volume control, silent-mode respect. *(MVP uses pre-recorded clips; ElevenLabs dynamic lines → later phase.)* | 8–9 | **$750** |
| **7** | **AI Characters & Friend Connection** | AI clue-giving/guessing logic (moderate difficulty) + a fun starter idle-animation set; **in-game friend requests + friends list** (meet in a game → reconnect → invite to future games), no personal info exchanged. *(Full animation library → later phase.)* | 7–9 | **$450** |
| **8** | **Prize Room & Trophy System** | Personal trophy/prize room, milestone earning logic, shelves + room expansion, clay-style item display. | 5–6 | **$550** |
| **9** | **Subscription Billing & Free Trial** | $5.99/mo products on both stores, 7-day no-card trial, Day-3 countdown timer, warm Day-7 prompt, access gating after trial. | 7–9 | **$800** |
| **10** | **Testing, Bug Fixes & Store Submission** | QA pass, senior-usability checks, performance testing on small screens, bug fixes, Apple App Store + Google Play submission support. | 6–8 | **$450** |
| | **TOTAL** | | **~67–82 days** | **$6,550** |

> Timeline assumes one milestone at a time, sequential. Days are working days. Calendar duration is longer
> due to your scheduled-update / weekday / weekends-off working agreement, which I fully respect.

---

## 4. What's Included

- Cross-platform iOS + Android app from a single Flutter codebase
- Server-authoritative game logic (game state managed server-side, not client-only)
- Senior-friendly UI standards applied to every screen (§4 compliance)
- Proof of work (screenshots / test builds) before each milestone payment is released
- Clean, version-controlled (Git) delivery
- Full ownership of all code, assets, and IP transferred to client (§23)

---

## 5. Assumptions & Client-Provided Items

To keep pricing accurate, the quote assumes the **client provides** the following (as stated in the spec):

- **All character art** as layered PNG files (bases, hair, eyes, glasses, outfits) — §8
- **AI idle animation assets** — the starter set for Phase 1, full library in a later phase — §11
- **Guy Smiley character art** and any reference avatars — §5
- **Brand assets and colours** (#5B2D8E etc.) — §5
- **Trophy and prize art** in clay style — §18

The developer will **source licensed theme music + announcer audio** (warm, classic game-show style) as
part of Phase 1 — §16. The developer builds the assembly, rendering, logic, and integration systems around
the client-provided assets.

The developer builds the assembly, rendering, logic, and integration systems around these assets.

---

## 6. Later Phase — Deferred Polish (optional, after launch)

The social heart of Match Word — the **friend-connection feature** and the **Prize Room** — is **included in
Phase 1**. Only the following polish items are deferred, and each can be quoted as its own milestone when
you're ready:

| Deferred item | Spec ref | Indicative price (CAD) |
|---|---|---|
| **Full AI idle-animation library** (Phase 1 ships a fun starter set) | §11 | ~$400 |
| **ElevenLabs dynamic Guy Smiley announcements** (Phase 1 uses warm pre-recorded clips) | §14 | ~$300 |
| **IP-based trial-abuse layer** (Phase 1 uses device-ID fingerprinting) | §6 | ~$150 |
| **Physical mailed trophies** (already a later phase in your spec) | §18 | TBD |

> Phase 1 delivers the complete experience players see and feel — characters, studio, teams, clues,
> guesses, steals, scoring, Guy Smiley host with voice, the disconnect alarm, the friend connection,
> the Prize Room, billing, and store launch.

---

## 7. Out of Scope (not planned)

- Tournament bracket system (beyond basic trophy milestone)
- Advanced AI behaviour beyond "moderate difficulty" baseline
- Backend infrastructure costs (Supabase paid tier, ElevenLabs usage, Apple/Google developer accounts) — these are operating costs billed to the client's own accounts, not developer fees
- Localization / multi-language support

---

## 8. Payment & Working Terms

- Fixed price per milestone, agreed before that milestone begins
- No full payment up front; each milestone is funded, then built, then reviewed, then released
- Proof of work provided before each release
- Any scope change agreed in writing before work begins (§23)
- All communication on Freelancer platform chat only; questions grouped into scheduled updates; weekends respected
- Prices quoted in **CAD** to match your Freelancer budget

---

## 9. Starting Point

We begin with **Milestone 1 (Sign In & Account System)** as agreed. The senior-friendly design system
(fonts, contrast, tap targets) is established in Milestone 2 so you can approve the visual direction early.

---

## 10. Confirmed Decisions

1. **Tech stack** — **Flutter + Supabase** (confirmed; client already uses Supabase elsewhere).
2. **Guy Smiley voice** — Mix of **pre-recorded clips + ElevenLabs** for dynamic lines (ElevenLabs dynamic layer scheduled for a later phase).
3. **Audio assets** — Developer to **source licensed audio** for theme music + announcer (warm, fun, classic game-show style).
4. **Asset delivery** — Client is preparing character art now; ready before the dependent milestones (3, 6, 7).
5. **Starting milestone** — **Milestone 1** confirmed.

---

*Honesty note (per spec §2): I have flagged the Apple/Google trial-checkout nuance and the dependency on
client-provided art/audio assets up front. I am confident in delivering every component to the standard
described. If any asset or scope detail shifts during the build, I will raise it immediately rather than
absorb it silently.*
