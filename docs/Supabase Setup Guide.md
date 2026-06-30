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

## Step 3: Create the Database Schema

1. In Supabase, go to **SQL Editor**
2. Click **New Query**
3. Copy and paste the entire contents of `app/supabase/migrations/0001_init.sql`
4. Click **Run** to execute the migration
5. Verify the tables exist:
   - Go to **Table Editor** and confirm you see `profiles` and `device_trials`

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

## Step 5: Configure Custom SMTP (Mailgun)

1. In Supabase go to **Authentication -> Providers -> Email**.
2. Keep **Enable email provider** ON.
3. In **Sign In / Providers**, set:
   - **Allow new users to sign up** = ON
   - **Confirm email** = OFF (important for this app's Milestone 1 flow)
4. Enable **Custom SMTP** and fill Mailgun values:
   - **Host**: `smtp.mailgun.org`
   - **Port**: `587`
   - **Username**: your Mailgun SMTP login (usually `postmaster@<your-domain>`)
   - **Password**: your Mailgun SMTP password
   - **Sender name**: `Match Word`
   - **Sender email**: a verified Mailgun sender/domain email

Important:
- Supabase Custom SMTP uses SMTP credentials, not Mailgun REST API calls.
- The Mailgun REST **API key** and **Base URL** are not used directly in Supabase SMTP fields.

5. Send a test email from Supabase and confirm delivery (inbox + spam check).

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
