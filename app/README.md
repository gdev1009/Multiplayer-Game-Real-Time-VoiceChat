# Match Word — Flutter App

Cross-platform (iOS + Android) Flutter app for **Match Word**, built on **Supabase**.

This repository currently contains **Milestone 1 — Sign In & Account System**.

---

## Milestone 1 — what's built

- **Account creation wizard** (one decision per screen): first name → email → choose
  4-number PIN → confirm PIN.
- **Daily login**: greet by name + 4-number PIN.
- **Forgot My PIN**: email one-time code → set a new PIN.
- **Silent trial-abuse prevention**: a persistent device fingerprint is recorded when a
  trial starts and checked on new-account creation (device-id is primary; the IP layer is a
  later phase).
- **Senior-first design system foundation**: large fonts (18pt+/22pt+ actions), 48×48pt+ tap
  targets, high contrast, one primary action per screen, friendly error messages.

### Key files

| Area | Path |
|---|---|
| App entry / DI | `lib/main.dart`, `lib/app.dart` |
| Design system | `lib/core/theme/`, `lib/core/widgets/` |
| Services | `lib/services/` (auth, profile, device, trial) |
| Auth feature | `lib/features/auth/` |
| Home placeholder | `lib/features/home/home_screen.dart` |
| Database schema | `supabase/migrations/0001_init.sql` |
| Tests | `test/` |

---

## Prerequisites

- **Flutter SDK** 3.19+ (Dart 3.3+) — <https://docs.flutter.dev/get-started/install>
- A device/emulator: Android Studio (Android) and/or Xcode (iOS, on macOS)
- A free **Supabase** project — <https://supabase.com>

Verify your toolchain:

```bash
flutter doctor
```

---

## Setup

1. **Install dependencies**

   ```bash
   cd app
   flutter pub get
   ```

2. **Configure Supabase**

   - Create a project at supabase.com.
   - Copy `.env.example` to `.env` and paste your values (Dashboard → Settings → API):

     ```env
     SUPABASE_URL=https://your-ref.supabase.co
     SUPABASE_ANON_KEY=your-anon-public-key
     ```

3. **Create the database schema**

   - Open the Supabase **SQL editor** and run `supabase/migrations/0001_init.sql`.
     This creates the `profiles` and `device_trials` tables with row-level security.

4. **Enable the email one-time code (for Forgot PIN)**

   - Dashboard → **Authentication → Providers → Email**: enable Email.
   - Dashboard → **Authentication → Sign In / Providers**: set **Confirm email** to OFF for this Milestone 1 flow.
   - Dashboard → **Authentication → Email Templates → Magic Link**: make sure the template
     includes the token, e.g. `Your code is: {{ .Token }}`. The app verifies this 6-digit
     code in the Forgot-PIN flow.

5. **(Recommended for production) Use custom SMTP with Mailgun**

   - Dashboard → **Authentication → Providers → Email**: enable Custom SMTP.
   - Use Mailgun SMTP credentials:
     - Host: `smtp.mailgun.org`
     - Port: `587`
     - Username: Mailgun SMTP login (typically `postmaster@<your-domain>`)
     - Password: Mailgun SMTP password
   - Use a verified sender email/domain in Mailgun.

6. **Run**

   ```bash
   flutter run
   ```

---

## How the login model works

The spec calls for *first name + 4-digit PIN*. Under the hood each account uses Supabase
email/password auth:

- The **email** is collected once and lives in Supabase Auth for **recovery only** — it is
  never shown in the app.
- A **strong random password** backs the Supabase session and is kept in secure storage so the
  device can re-authenticate silently.
- The **PIN** is the local gate. It is salted + stretched-SHA-256 hashed and stored in
  `profiles`; the app verifies it on daily login.
- **Forgot PIN** sends an email one-time code; verifying it establishes a session and lets the
  player set a new PIN.

---

## Quality

```bash
flutter analyze
flutter test
```

Unit tests cover PIN hashing/verification and input validation.

---

## Next milestone

**Milestone 2 — Opening Screen & Navigation**: the Guy Smiley opening screen, *Check Upcoming
Games* / *Enter the Studio*, and the formalized navigation shell. See
`../docs/Project Plan.md`.
