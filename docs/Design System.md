# Match Word — Design System

The senior-first design system for Match Word. Every screen reuses these tokens
and components so the app stays consistent, high-contrast, and easy to read.

Source of truth (code):
- Colors: app/lib/core/theme/app_colors.dart
- Typography: app/lib/core/theme/app_text.dart
- Spacing: app/lib/core/theme/app_spacing.dart
- Material theme: app/lib/core/theme/app_theme.dart

---

## Senior-first principles

- Body text 18pt or larger; primary actions 22pt or larger.
- Minimum 48×48pt tap targets.
- High contrast: dark foreground on light background (or the reverse).
- One clear primary action per screen.
- Every control has a visible text label (never icon-only).
- No rushed timers, no ads, and the word "AI" never appears in the UI.

---

## Color tokens

Brand:
- Deep Purple `#5B2D8E` — primary brand / actions
- Lavender `#E9DDF7` — soft surfaces, host speech bubble
- Warm Beige `#F7F1E6` — app background
- Gold `#D4A431` — accents / highlights
- Black `#1A1A1A` — primary text

Semantic:
- background = Warm Beige
- surface = White
- primary = Deep Purple / onPrimary = White
- textPrimary = Black / textSecondary = `#4A4458`
- error = `#B3261E` / success = `#2E7D32`
- divider = `#D8CDEA`

## Typography scale (Roboto)

- display — 40 / w800 / Deep Purple
- title — 30 / w700
- body — 20 / w500 (>= 18pt minimum)
- bodyMuted — 20 / w500 / secondary
- action — 24 / w700 (button labels, >= 22pt)
- error — 18 / w600 / error

## Spacing scale

- xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48
- minTapTarget 48 · buttonHeight 64 · pagePadding 24

---

## Components

- AppPage (app/lib/core/widgets/app_page.dart)
  - Page wrapper: SafeArea, generous padding, optional title bar with a large
    back button, and a scroll view so content is never cut off on small screens.

- BigButton (app/lib/core/widgets/big_button.dart)
  - Full-width, 64pt tall, 24pt label, primary/secondary variants, Semantics
    label, loading state. The standard call-to-action.

- BigTextField (app/lib/core/widgets/big_text_field.dart)
  - Large labelled input with always-visible text label and clear error text.

- PinPad (app/lib/core/widgets/pin_pad.dart)
  - On-screen number pad for the 4-digit PIN, large keys with Semantics.

- HostGreeting (app/lib/core/widgets/host_greeting.dart)
  - The show host ("Guy Smiley") greeting banner: avatar + speech-bubble message.
    Reused anywhere the host speaks. Final host art/voice arrive in Milestone 6.

---

## Navigation shell

- Routes: app/lib/core/navigation/app_routes.dart
- The post-login Opening screen (app/lib/features/home/opening_screen.dart) is
  the MaterialApp `home` (via AuthGate). From it the player can reach:
  - Check Upcoming Games → `/upcoming-games`
    (app/lib/features/lobby/upcoming_games_screen.dart)
  - Enter the Studio → `/studio`
    (app/lib/features/studio/studio_screen.dart)

---

## UI checklist (run per screen)

- [ ] Body text >= 18pt; primary action >= 22pt
- [ ] All tap targets >= 48×48pt
- [ ] High contrast foreground/background
- [ ] One primary action; every control has a text label
- [ ] Reuses AppPage + design tokens (no ad-hoc colors/sizes)
- [ ] Reads well on a small screen (iPhone SE class)
