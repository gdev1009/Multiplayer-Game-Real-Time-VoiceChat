# Supabase Setup & Configuration Guide for Milestone 1

This guide ensures your Supabase project is correctly configured for the Match Word app to work on real devices.

## Step 1: Create/Access Your Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in or create a free account
3. Create a new project or open an existing one
4. Note your project name (you'll use it shortly)

## Step 2: Get Your API Credentials

1. In the Supabase dashboard, go to **Settings → API**
2. Find and copy:
   - **Project URL** (looks like `https://your-ref.supabase.co`)
   - **Anon Public Key** (the anon/public key, NOT the service role key)
3. Keep these safe; you'll need them in the next step

## Step 3: Create the Database Schema (apply ALL of it)

> ⚠️ **This is the #1 cause of "Something went wrong".** The app needs the
> **entire** schema, not just the first file. If you apply only
> `0001_init.sql`, sign-in will work but **every** other action (save
> character, start a game, join a game) will fail with "Something went wrong",
> because the tables and functions those actions use live in later migrations.

**Easiest way — one paste:**

1. In Supabase, go to **SQL Editor**
2. Click **New Query**
3. Copy and paste the **entire** contents of
   [app/supabase/schema.sql](../app/supabase/schema.sql). This single file
   contains every migration (0001 → 0012) already stitched together in order.
4. Click **Run**. It should finish with "Success. No rows returned."
5. Verify the tables exist — go to **Table Editor** and confirm you see all of:
   - `profiles`, `device_trials`
   - `characters`
   - `games`, `game_players`
   - `game_rounds`, `game_turns` (gameplay)
6. Verify the functions exist — go to **Database → Functions** and confirm you
   see the `mw_*` functions (e.g. `mw_create_game`, `mw_join_game`,
   `mw_start_game`, `mw_begin_play`).

**Alternative — apply the numbered migrations one by one:** if you prefer, run
each file in `app/supabase/migrations/` **in order** (0001 → 0002 → 0003 → …
→ 0012). You must run **all twelve**. Re-running is safe (the schema uses
`create ... if not exists` and `drop policy if exists`).

> If you already applied only `0001` earlier, just paste
> `app/supabase/schema.sql` now — it will add everything that is missing
> without breaking the tables you already have.

## Step 4: Enable Email Authentication

1. Go to **Authentication → Providers**
2. Find **Email / Password** and toggle it **ON**
3. Go to **Authentication → Email Templates**
4. Find **Magic Link** template
5. Ensure the template includes the token. It should contain something like:
   ```
   Your code is: {{ .Token }}
   ```
   (The exact format depends on your Supabase version; consult Supabase docs if unclear)

## Step 5: Send Auth Emails Through Mailgun

Supabase Auth sends the forgot-PIN one-time code. There are two ways to route
those emails through Mailgun. **Pick ONE.**

### Which credential do I have?

- A Mailgun **API key** (looks like `key-...` or `xxxxxxxx-xxxxxxxx-xxxxxxxx`)
  is a **REST API** credential. It does **not** work in Supabase's SMTP fields.
  Use **Option A** below.
- A Mailgun **SMTP username + password** (`postmaster@<domain>` + password)
  works in Supabase's built-in Custom SMTP fields. Use **Option B** below.

> The key the client provided is an **API key**, so this project is wired for
> **Option A**.

### Option A — Send Email hook + Mailgun REST API (uses the API key)

This uses the `send-email` Edge Function in `app/supabase/functions/send-email`,
which calls Mailgun's REST API with the API key.

1. Put the server secrets in `app/supabase/functions/.env` (copy from
   `.env.example`). This file is gitignored and is **never** bundled into the
   app. Set:
   - `MAILGUN_API_KEY` — the Mailgun API key
   - `MAILGUN_DOMAIN` — your verified sending domain (e.g. `mg.grandmamac.com`)
   - `MAILGUN_BASE_URL` — `https://api.mailgun.net` (or `https://api.eu.mailgun.net` for EU)
   - `MAILGUN_SENDER` — e.g. `Match Word <no-reply@mg.grandmamac.com>`
   - `SEND_EMAIL_HOOK_SECRET` — create the Supabase Send Email HTTPS hook,
     click **Generate Secret**, and copy the full `v1,whsec_...` value
2. Push the secrets and deploy the function:
   ```bash
   cd app
   supabase secrets set --env-file ./supabase/functions/.env
   supabase functions deploy send-email --no-verify-jwt
   ```
3. In Supabase go to **Authentication → Hooks**, create a **Send Email** HTTPS
   hook, point it at the deployed `send-email` function, and click **Generate
   Secret**. Save the hook, put the generated value in
   `supabase/functions/.env`, and run the secrets command again.
4. In **Authentication -> Providers -> Email**: keep **Enable email provider** ON,
   **Allow new users to sign up** = ON, **Confirm email** = OFF.

### Option B — Custom SMTP (only if you have Mailgun SMTP credentials)

1. In Supabase go to **Authentication -> Providers -> Email**, keep **Enable
   email provider** ON, set **Allow new users to sign up** = ON and
   **Confirm email** = OFF.
2. Enable **Custom SMTP** and fill Mailgun SMTP values:
   - **Host**: `smtp.mailgun.org`
   - **Port**: `587`
   - **Username**: Mailgun SMTP login (usually `postmaster@<your-domain>`)
   - **Password**: Mailgun SMTP password
   - **Sender name**: `Match Word`
   - **Sender email**: a verified Mailgun sender/domain email

### Both options

Send a test email from Supabase (or trigger forgot-PIN) and confirm delivery
(inbox + spam check).

> Security: never put the Mailgun API key in `app/.env` — that file is bundled
> into the app and would leak to every device. Server secrets belong only in
> `app/supabase/functions/.env` / Supabase secrets.

## Step 6: Fill in App Credentials

1. Open `app/.env` in the app folder
2. Replace the placeholder values:
   ```env
   SUPABASE_URL=https://your-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-public-key
   ```
   with your **actual** Project URL and Anon Public Key from Step 2.

3. Save the file (do NOT commit this to git; .env is in .gitignore)

## Step 7: Rebuild and Test

1. Delete the old APKs or build output:
   ```bash
   cd app
   flutter clean
   ```

2. Build new APKs:
   ```bash
   flutter build apk --split-per-abi
   ```

3. Install on your device:
   - For LDPlayer: use `app-x86_64-release.apk`
   - For modern phones: use `app-arm64-v8a-release.apk`

4. Test the flows:
   - Create account (use a real email you can access)
   - Logout and daily login
   - Test wrong PIN rejection
   - Test forgot PIN (check your inbox for the code)

## Troubleshooting

**Every game/character action says "Something went wrong" (but sign-in works):**
- This almost always means the database schema was only **partly** applied
  (usually just `0001_init.sql`). Go back to **Step 3** and paste the full
  [app/supabase/schema.sql](../app/supabase/schema.sql). Sign-in only needs the
  `profiles` table (from 0001), but saving a character needs `characters`
  (0002) and starting/joining games needs the `mw_*` functions (0004+).
- After applying the full schema, confirm in **Database → Functions** that
  `mw_create_game` and friends exist.
- The app now prints the real reason to the device log (look for
  `[LobbyService]`, `[GameplayService]`, `[ProfileService]`,
  `[CharacterService]` lines in `flutter run`/`adb logcat`). A message like
  `relation "characters" does not exist` or `function mw_create_game(...) does
  not exist` confirms the schema is incomplete.

**Account creation still fails after filling in credentials:**
- Verify the email format is valid
- Confirm Email/Password provider is enabled in Supabase
- Check your Supabase project is not in restricted mode

**Forgot PIN doesn't send emails:**
- Verify the Email/Password provider is enabled
- Check your email spam folder
- Confirm the Magic Link template includes the token

**App crashes on startup:**
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are exactly correct (no extra spaces)
- Check your internet connection

## Next Steps After Successful Testing

Once all flows work on your device:
1. Capture the Milestone 1 proof-of-work screen recording
2. Share APKs and recording with the client
3. Request payment release for Milestone 1
