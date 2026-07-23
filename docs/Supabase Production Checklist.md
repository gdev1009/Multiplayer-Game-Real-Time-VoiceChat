# Supabase Production Checklist — Match Word

**Audience:** You (or Ronna) verifying the **live** Supabase project before TestFlight / Play Store.  
**Assumption:** All SQL migrations (`0001` → `0016`) are **already applied**. This doc does **not** re-run migrations.

**App needs only two client values** (in `app/.env`):

```env
SUPABASE_URL=https://YOUR-REF.supabase.co
SUPABASE_ANON_KEY=your-anon-public-key
```

**Never** put the **service role key**, Mailgun API key, or hook secret in `app/.env` — those ship inside every APK/IPA.

---

## Phase 1 — Confirm you are on the right project

### Step 1.1 — Open the production project

- [ ] Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
- [ ] Open the project that **production builds** use (not an old test project)
- [ ] Note the project ref from the URL: `https://supabase.com/dashboard/project/<ref>`

### Step 1.2 — Match URL to the app build

- [ ] Open `app/.env` on the machine used to build store APKs/IPAs
- [ ] Confirm `SUPABASE_URL` is exactly `https://<ref>.supabase.co` (no trailing slash, no spaces)
- [ ] Confirm `SUPABASE_ANON_KEY` matches **Settings → API → anon public** key for this same project

☐ **Checkpoint:** A wrong project ref is the #1 cause of “works on my machine” / “crashes on Ronna’s phone.”

---

## Phase 2 — Verify database schema (read-only checks)

Run these in **SQL Editor → New query**. Each should return rows — empty means something is missing.

### Step 2.1 — Core tables exist

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles', 'device_trials', 'pin_attempts',
    'characters',
    'games', 'game_players',
    'game_state', 'game_words', 'game_plays',
    'friendships', 'game_invites',
    'prize_catalog', 'player_awards',
    'subscriptions'
  )
order by 1;
```

- [ ] **15 tables** listed (all names above)

### Step 2.2 — Prize catalog seeded

```sql
select id, kind, title from public.prize_catalog order by sort_order;
```

- [ ] **6 rows:** `trophy-first-win`, `trophy-10-games`, `trophy-50-games`, `prize-sports-car`, `prize-vacation`, `prize-tv`

### Step 2.3 — `profiles` has play stats columns (M8)

```sql
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'profiles'
  and column_name in ('games_played', 'games_won');
```

- [ ] Both columns present

### Step 2.4 — `pgcrypto` extension (PIN verification)

```sql
select extname from pg_extension where extname = 'pgcrypto';
```

- [ ] One row: `pgcrypto`  
  (Required by `mw_hash_pin` / `mw_verify_pin` in migration `0003_pin_verify.sql`)

### Step 2.5 — Key `mw_*` functions exist

```sql
select proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname like 'mw_%'
order by 1;
```

- [ ] At least **35** functions, including all of:

| Function | Used for |
|----------|----------|
| `mw_verify_pin` | Email sign-in on new device, before OTP |
| `mw_create_game`, `mw_join_game`, `mw_join_seat`, `mw_peek_game` | Lobby |
| `mw_quick_match`, `mw_fill_seats`, `mw_start_game`, `mw_leave_game` | Matchmaking / room |
| `mw_list_open_games` | Upcoming games list |
| `mw_begin_play`, `mw_submit_clue`, `mw_submit_guess`, `mw_next_word`, `mw_begin_second_half` | Live gameplay |
| `mw_game_characters` | Character busts on stage |
| `mw_send_friend_request`, `mw_list_friends`, `mw_list_friend_requests` | Friends |
| `mw_invite_friend`, `mw_list_my_invites`, `mw_respond_invite` | Game invites |
| `mw_my_prize_room`, `mw_record_match_result` | Prize room |
| `mw_my_subscription`, `mw_sync_subscription` | Billing mirror |

### Step 2.6 — Row Level Security enabled

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;
```

- [ ] `rowsecurity = true` on every app table (all tables in Step 2.1)

☐ **Checkpoint:** If any table or `mw_*` function is missing, gameplay / friends / prizes will fail with “Something went wrong” even though sign-in works.

---

## Phase 3 — Realtime (live multiplayer)

The app subscribes to Postgres changes on these tables. If they are not in the `supabase_realtime` publication, lobbies and scores will feel frozen.

### Step 3.1 — Confirm publication membership

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and tablename in (
    'games', 'game_players', 'game_state', 'game_plays',
    'friendships', 'game_invites'
  )
order by tablename;
```

- [ ] **6 tables** listed

### Step 3.2 — Dashboard toggle (if Step 3.1 is short)

- [ ] Go to **Database → Replication**
- [ ] Under **supabase_realtime**, ensure these tables are enabled:
  - `games`, `game_players`, `game_state`, `game_plays`, `friendships`, `game_invites`

☐ **Checkpoint:** Game still “works” without realtime (polling fallback exists) but seats and scores update slower; fix realtime before client demo.

---

## Phase 4 — Authentication (dashboard, click by click)

Match Word uses **Email** auth with a **random password** stored on-device plus a **4-digit PIN** in `profiles`. OTP emails are sent for: new-device sign-in, forgot PIN.

### Step 4.1 — Enable Email provider

- [ ] **Authentication → Providers → Email**
- [ ] **Enable Email provider** = **ON**
- [ ] **Confirm email** = **OFF** (users must not be blocked waiting for a confirmation link)
- [ ] **Allow new users to sign up** = **ON**
- [ ] **Secure email change** = ON (recommended)
- [ ] Save

### Step 4.2 — OTP / magic link settings

- [ ] **Authentication → Providers → Email** (or **Auth → Settings** depending on UI version)
- [ ] **OTP expiry** — default (e.g. 3600s) is fine; app shows “code expired” if too short
- [ ] **OTP length** — must match what Supabase sends (typically **6 digits**); app accepts the token from the email body

### Step 4.3 — Disable unused providers

- [ ] Turn **OFF** providers you do not use: Phone, Google, Apple, etc.  
  (Fewer providers = smaller attack surface.)

### Step 4.4 — URL configuration

- [ ] **Authentication → URL Configuration**
- [ ] **Site URL** — set to a stable HTTPS URL you control, e.g. `https://grandmamac.com`  
  (Not `localhost` for production.)
- [ ] **Redirect URLs** — add any domains you use for auth callbacks; for this app the OTP flow is in-app, so Site URL alone is usually enough
- [ ] Save

### Step 4.5 — Rate limits (recommended)

- [ ] **Authentication → Rate Limits** (or **Auth → Settings → Rate limits**)
- [ ] Review defaults for **OTP / email send** and **sign-in** — tighten if you see abuse in logs
- [ ] Note: `mw_verify_pin` also locks accounts after repeated wrong PINs (`pin_attempts` table)

### Step 4.6 — Email templates (required for OTP)

Forgot PIN / new-device sign-in call `signInWithOtp`. Supabase’s **default**
Magic Link template emails a **“Sign in” link** (`noreply@mail.app.supabase.io`).
Match Word needs a **6-digit code**.

- [ ] **Authentication → Email Templates → Magic Link**
- [ ] Subject: `Your Match Word code`
- [ ] Body: paste from `app/supabase/email-templates/magic-link.html`
      (must include `{{ .Token }}`; remove `{{ .ConfirmationURL }}`)
- [ ] Save, then smoke-test Forgot PIN — inbox must show digits, not a link
- [ ] When the **Send Email hook** (Phase 5) is active, Mailgun formats the
      code from `email_data.token`; keep the Magic Link template on `{{ .Token }}`
      anyway as a fallback if the hook is off

**Mailgun is client-owned.** Ronna completes DNS + domain verification only;
see [Mailgun Setup Guide for Ronna.md](Mailgun%20Setup%20Guide%20for%20Ronna.md).
You (developer) complete Phase 5 below after she sends the four Mailgun values
securely.

☐ **Checkpoint:** Create account + forgot PIN must deliver a **numeric code** email, not a broken template.

---

## Phase 5 — Outbound email (Mailgun + Edge Function)

Production auth emails should go through **Mailgun** via the `send-email` Edge Function (API key stays server-side).

### Step 5.1 — Mailgun domain ready

- [ ] Mailgun account active
- [ ] Sending domain verified (e.g. `mg.grandmamac.com`)
- [ ] DNS records (SPF, DKIM) green in Mailgun dashboard
- [ ] **From address** decided, e.g. `Match Word <no-reply@mg.grandmamac.com>`

### Step 5.2 — Create local secrets file (never commit)

On a dev machine with Supabase CLI linked to this project:

```bash
cd app
cp supabase/functions/.env.example supabase/functions/.env
```

Edit `supabase/functions/.env`:

- [ ] `MAILGUN_API_KEY` — Mailgun REST API key (`key-...`)
- [ ] `MAILGUN_DOMAIN` — verified domain
- [ ] `MAILGUN_BASE_URL` — `https://api.mailgun.net` (or EU URL if applicable)
- [ ] `MAILGUN_SENDER` — `Match Word <no-reply@mg.yourdomain.com>`
- [ ] Add `SEND_EMAIL_HOOK_SECRET` after Supabase generates it in Step 5.5.

### Step 5.3 — Push secrets to Supabase

```bash
cd app
supabase link --project-ref YOUR_REF   # if not already linked
supabase secrets set --env-file ./supabase/functions/.env
```

- [ ] Command succeeds with no errors
- [ ] **Project Settings → Edge Functions → Secrets** shows `MAILGUN_*` and `SEND_EMAIL_HOOK_SECRET` (values hidden)

### Step 5.4 — Deploy Edge Function

```bash
cd app
supabase functions deploy send-email --no-verify-jwt
```

- [ ] Deploy finishes successfully
- [ ] **Edge Functions** list shows `send-email` with a recent deploy time

### Step 5.5 — Wire Auth Send Email hook

- [ ] Go to **Authentication → Hooks** and create a **Send Email** HTTPS hook
- [ ] Enter
  `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-email`
- [ ] Click **Generate Secret** and copy the complete `v1,whsec_...` value
- [ ] Save/enable the hook
- [ ] Put that generated value in `supabase/functions/.env` as
  `SEND_EMAIL_HOOK_SECRET`
- [ ] Upload the updated secrets:

  ```bash
  supabase secrets set --env-file ./supabase/functions/.env
  ```

### Step 5.6 — Smoke-test email delivery

- [ ] In the app: **Forgot PIN** → enter a real inbox you control
- [ ] Email arrives within ~1 minute (check spam)
- [ ] Subject like **“Your Match Word sign-in code”**
- [ ] Body shows a **large numeric code**
- [ ] Code works in the app

If email fails:

- [ ] **Edge Functions → send-email → Logs** — look for Mailgun 401/403 or “Invalid signature”
- [ ] **Authentication → Logs** — failed send attempts
- [ ] Mailgun **Sending → Logs** — rejected/bounced messages

☐ **Checkpoint:** No hook + no custom SMTP = OTP flows fail in production.

---

## Phase 6 — API keys & security

### Step 6.1 — Anon key only in the app

- [ ] `app/.env` contains **only** `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- [ ] **No** `SERVICE_ROLE` key in repo, `.env`, or CI logs
- [ ] Store builds rebuilt **after** final `.env` values are set

### Step 6.2 — Service role key secured

- [ ] **Settings → API → service_role** — copy only when needed for admin tasks; store in a password manager
- [ ] Never embed in the Flutter app, never send to Ronna for TestFlight builds

### Step 6.3 — JWT / API settings (defaults usually OK)

- [ ] **Settings → API** — note JWT expiry (default 3600s); app refreshes session automatically
- [ ] **Settings → API → Exposed schemas** — `public` enabled (default)

### Step 6.4 — Network restrictions (optional, Pro plan)

- [ ] If using **Database → Network restrictions**, ensure Supabase Edge / client IPs are not blocked

### Step 6.5 — Leaked password protection (optional)

- [ ] **Authentication → Providers → Email → Security** — enable leaked-password protection if available (accounts use random passwords; low priority)

☐ **Checkpoint:** Rotating the anon key requires a new app build; rotating service role does not.

---

## Phase 7 — Edge Functions & server secrets hygiene

### Step 7.1 — Function inventory

- [ ] Only **`send-email`** is required for production M1–M8
- [ ] No test functions deployed with open CORS or `--no-verify-jwt` beyond `send-email` (that one is intentional for Auth hooks)

### Step 7.2 — Logs retention

- [ ] **Logs → Edge Functions** — confirm you can see recent `send-email` invocations after Step 5.6

---

## Phase 8 — Project health & billing

### Step 8.1 — Plan limits

- [ ] **Settings → Billing** — project on a plan that covers expected MAU + realtime connections
- [ ] Free tier pauses after inactivity — **upgrade or keep project active** before client testing

### Step 8.2 — Region

- [ ] **Settings → General → Region** — note region (US/EU); pick Mailgun API base URL accordingly

### Step 8.3 — Backups (Pro recommended for launch)

- [ ] **Database → Backups** — daily backups enabled if on Pro
- [ ] Know how to restore if a bad manual SQL run happens

### Step 8.4 — Advisors

- [ ] **Database → Security Advisor** — resolve any **critical** RLS or exposed-table warnings
- [ ] **Performance Advisor** — optional before scale

---

## Phase 9 — App build alignment

### Step 9.1 — Rebuild after `.env` is final

```bash
cd app
flutter clean
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
# iOS (on Mac):
# flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```

- [ ] New APK/IPA tested against **this** Supabase project

### Step 9.2 — Confirm `.env` is bundled intentionally

- [ ] `pubspec.yaml` lists `assets: - .env` — correct for this project; only public keys inside

---

## Phase 10 — End-to-end smoke tests (one flow at a time)

Use a **real device** and a **fresh email** you control. Check off each in order.

### Auth & account

- [ ] **10.1** Create account (first name, email, PIN) → lands on character / home
- [ ] **10.2** Sign out / lock → **Daily login** with name + PIN works
- [ ] **10.3** Wrong PIN → friendly error, no crash
- [ ] **10.4** **Forgot PIN** → email code → set new PIN → daily login works
- [ ] **10.5** Second device: **I already have an account** → email → PIN → email code → signed in

### Character & profile

- [ ] **10.6** Build and **save character** → reopen app → character persists
- [ ] **10.7** `profiles.first_name` updates when character display name changes (visible in lobby)

### Lobby & matchmaking

- [ ] **10.8** **Studio** → create game → you are host in seat 0
- [ ] **10.9** **Fill seats** (AI players) → four seats occupied
- [ ] **10.10** **Join by code** from second account/device → joins correct room
- [ ] **10.11** **Upcoming games** lists open public games
- [ ] **10.12** **Quick match** → joins or creates a room (AI fill may apply)

### Gameplay

- [ ] **10.13** Host **starts game** → play screen loads, Guy Smiley / stage visible
- [ ] **10.14** Submit **clue** and **guess** → scores update
- [ ] **10.15** Finish match → **winner** state; no stuck screen

### Friends (M7)

- [ ] **10.16** Send friend request after game → other account sees request
- [ ] **10.17** Accept → appears in **Friends** list with character avatar
- [ ] **10.18** Invite friend to lobby → invitee sees invite on games hub

### Prizes (M8)

- [ ] **10.19** After a completed game, **Prize room** loads (`mw_my_prize_room`)
- [ ] **10.20** Stats increment (`games_played`; `games_won` when on winning team)
- [ ] **10.21** Trophy unlocks at milestones (e.g. first win)

### Subscription mirror (M8 — backend ready, store IAP not live yet)

- [ ] **10.22** **Paywall** opens without error
- [ ] **10.23** `mw_my_subscription` returns `status: none` for new users (SQL or app logs)
- [ ] **10.24** When StoreKit/Play Billing is wired, `mw_sync_subscription` updates `subscriptions` row

---

## Phase 11 — Production sign-off

| Item | Owner | Done |
|------|-------|------|
| Correct project URL + anon key in store build | Dev | ☐ |
| All 15 tables + `mw_*` functions verified | Dev | ☐ |
| Realtime on 6 tables | Dev | ☐ |
| Email provider + Send Email hook + Mailgun | Dev / Ronna | ☐ |
| Auth smoke tests 10.1–10.5 | QA | ☐ |
| Game smoke tests 10.8–10.15 | QA | ☐ |
| Friends + prizes 10.16–10.21 | QA | ☐ |
| Service role not in client | Dev | ☐ |
| Billing plan / no pause risk | Ronna | ☐ |

---

## Quick troubleshooting

| Symptom | Likely cause | Fix |
|---------|----------------|-----|
| Sign-in works; everything else “Something went wrong” | Incomplete schema | Re-verify Phase 2 (missing `characters`, `games`, or `mw_*`) |
| OTP never arrives | Hook / Mailgun | Phase 5 logs; DNS; hook secret mismatch |
| “Invalid signature” in function logs | Hook secret mismatch | Same secret in `.env` secrets and Auth hook UI |
| Lobby seats don’t update live | Realtime | Phase 3 |
| `mw_verify_pin` always fails | `pgcrypto` missing | Step 2.4 |
| Prize room empty error | `prize_catalog` not seeded | Step 2.2 |
| App crash on launch | Bad `.env` | Phase 1.2 + rebuild |

---

## Related docs

- [Supabase Setup Guide.md](Supabase%20Setup%20Guide.md) — first-time setup (includes migration instructions)
- [App Store Publishing.md](App%20Store%20Publishing.md) — store URLs, screenshots, Play/App checklists
- [TestFlight Setup.md](TestFlight%20Setup.md) — iOS build + `.env` on Mac

**Edge function source:** `app/supabase/functions/send-email/index.ts`  
**Server secrets template:** `app/supabase/functions/.env.example`
