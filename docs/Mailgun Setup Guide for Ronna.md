# Match Word — Mailgun Setup Guide for Ronna

**Your part only.** This guide covers **Mailgun and DNS** for Grandma Mac.

**Gregory (developer) handles Supabase** — deploying the email function, wiring
the auth hook, and saving server secrets. You do **not** need Supabase access.

---

## Why this is needed

Match Word sends sign-in codes and forgot-PIN emails through **Mailgun**. The
app backend (Supabase) calls Mailgun using an API key and a **verified sending
domain**.

An API key alone is **not** enough. You also need:

1. A custom sending domain (recommended: `mg.grandmamac.com`)
2. DNS records added for that domain (SPF, DKIM, and any others Mailgun shows)
3. The domain verified as **Active** in Mailgun
4. A domain sending key to hand off securely to Gregory

No database or SQL work is required on your side.

---

## Who does what

| Task | Ronna (Mailgun + DNS) | Gregory (Supabase) |
|------|------------------------|---------------------|
| Mailgun account | ✓ | |
| Add sending domain | ✓ | |
| DNS records for `grandmamac.com` | ✓ | |
| Verify domain in Mailgun | ✓ | |
| Create domain sending API key | ✓ | |
| Send credentials to Gregory securely | ✓ | |
| Deploy `send-email` function | | ✓ |
| Auth Send Email hook | | ✓ |
| Save Mailgun secrets in Supabase | | ✓ |
| Test Forgot PIN in the app | | ✓ (after handoff) |

---

## Before you start

- [ ] Login to [Mailgun](https://app.mailgun.com)
- [ ] Access to DNS for **grandmamac.com** (Cloudflare, GoDaddy, Namecheap,
  your web host, etc.)
- [ ] A way to send Gregory **four values** securely (see Part 5 — not via
  Freelancer chat if it blocks secrets)

If you are not sure who manages the domain DNS, ask whoever hosts the Grandma
Mac website.

---

## Part 1 — API key vs SMTP (read this once)

Match Word uses Mailgun’s **REST API**, not SMTP.

| Credential | Used for Match Word? |
|------------|----------------------|
| **API key** / **Domain sending key** | **Yes** — Gregory enters this in Supabase |
| SMTP username + password | **No** — do not use for this project |

**Do not** paste an API key into an SMTP password field anywhere. It will not
work.

---

## Part 2 — Add the sending domain in Mailgun

### Step 2.1 — Open Domains

1. Sign in at [https://app.mailgun.com](https://app.mailgun.com)
2. Go to **Send → Sending → Domains** (wording may be **Domains** only)

### Step 2.2 — Check what you already have

| What you see | What to do |
|--------------|------------|
| `mg.grandmamac.com` (or similar) **Active / Verified** | Skip to Part 4 |
| Only a `*.mailgun.org` sandbox domain | Add a real domain (Step 2.3) |
| No custom domain | Add one (Step 2.3) |

**Sandbox domains** can only send to a few test addresses. They are **not**
suitable for real Match Word players.

### Step 2.3 — Add a new domain

1. Click **Add new domain** / **Add sending domain**
2. Enter:

   ```text
   mg.grandmamac.com
   ```

3. Choose region:
   - **United States** → Gregory will use API URL `https://api.mailgun.net`
   - **European Union** → Gregory will use `https://api.eu.mailgun.net`
4. Finish creation and leave the **DNS records** page open

Using a subdomain (`mg.`) keeps app email separate from normal business mail.

---

## Part 3 — Add DNS records (grandmamac.com)

Mailgun shows the **exact** records for your domain. Use **those** values — do
not copy DKIM strings from this document or from another site.

### Step 3.1 — Open your DNS provider

1. Sign in where `grandmamac.com` DNS is managed
2. Open **DNS**, **DNS records**, or **Zone editor**
3. Keep Mailgun’s verification page open in another tab

### Step 3.2 — SPF (TXT)

Mailgun usually shows something like:

```text
Type:  TXT
Host:  mg          (or mg.grandmamac.com — depends on provider)
Value: v=spf1 include:mailgun.org ~all
```

- [ ] Add exactly what Mailgun displays
- [ ] TTL: default / Auto
- [ ] **Only one SPF record per hostname** — if `mg` already has SPF, merge
  senders into a single record; do not add a second SPF TXT

### Step 3.3 — DKIM (TXT or CNAME)

- [ ] Copy **Host** and **Value** exactly from Mailgun
- [ ] Paste the full DKIM value — do not shorten or retype it
- [ ] Save

### Step 3.4 — Tracking CNAME (if Mailgun lists it)

- [ ] Add host and target exactly as shown
- [ ] On **Cloudflare**: set to **DNS only** (grey cloud), not proxied
- [ ] Save

### Step 3.5 — MX records (only if Mailgun marks them required)

- [ ] Add both MX records with the priorities Mailgun shows
- [ ] Apply them to the **mg** subdomain unless Mailgun says otherwise
- [ ] Save

### Step 3.6 — Verify in Mailgun

1. Back in Mailgun: **Sending → Domains → mg.grandmamac.com**
2. Click **Verify DNS settings** / **Check DNS** / **Verify**
3. Wait until required records (at least **SPF** and **DKIM**) show green

DNS can take from a few minutes up to **24–48 hours**. Do not hand off to
Gregory for production until the domain is **Active** or **Verified**.

---

## Part 4 — Create a domain sending key

A **domain sending key** is safer than sharing your full account API key.

1. In Mailgun: **Send → Sending → Domain settings → Sending API keys**
2. Select **mg.grandmamac.com**
3. Click **Add sending key**
4. Description: `Match Word production`
5. **Create** and **copy the key immediately** — Mailgun often will not show it
   again

If you already gave Gregory a working **account** API key for this domain, that
can still work; a domain key is preferred.

---

## Part 5 — Hand off to Gregory (secure delivery)

Send Gregory these **four items** once the domain is verified. Use a method you
both trust (password manager share, phone, encrypted note — **not** plain
Freelancer chat if it is visible or logged).

```text
1. MAILGUN_API_KEY
   (the domain sending key from Part 4)

2. MAILGUN_DOMAIN
   mg.grandmamac.com

3. MAILGUN_BASE_URL
   https://api.mailgun.net
   — OR, if you chose EU in Part 2 —
   https://api.eu.mailgun.net

4. MAILGUN_SENDER (display name + address)
   Match Word <no-reply@mg.grandmamac.com>
```

Gregory will enter these into Supabase server secrets only. They are **never**
put inside the mobile app.

**You do not need to:** log into Supabase, run terminal commands, edit email
templates, or deploy anything.

---

## Part 6 — Optional: test from Mailgun before Gregory connects Supabase

After DNS is green, you can confirm Mailgun itself sends mail:

1. In Mailgun, open **Sending → Logs** or use **Send a test** if your plan
   offers it
2. Send a test message **from** `no-reply@mg.grandmamac.com` **to** your own
   inbox
3. Check inbox and spam

This proves Mailgun + DNS work. End-to-end app testing (Forgot PIN in Match
Word) happens **after** Gregory completes Supabase setup.

---

## Part 7 — What Gregory will do after your handoff

For your reference only — **you do not do these steps:**

1. Save your four Mailgun values as Supabase Edge Function secrets
2. Deploy the `send-email` function
3. Enable **Authentication → Hooks → Send Email**
4. Test **Forgot PIN** and new-device sign-in in the app
5. Tell you when production email is live

---

## Part 8 — Status report back to Gregory

You can paste this checklist in Freelancer (no secrets):

```text
Match Word — Mailgun status (Ronna)

[ ] Mailgun account access confirmed
[ ] Sending domain added: mg.grandmamac.com
[ ] Mailgun region: US / EU
[ ] SPF DNS record added
[ ] DKIM DNS record added
[ ] CNAME (tracking) added if required
[ ] MX added if required
[ ] Domain status in Mailgun: Active / Verified
[ ] Domain sending key created
[ ] Four Mailgun values sent to Gregory securely (not in this message)

Sender we will use:
Match Word <no-reply@mg.grandmamac.com>
```

---

## Troubleshooting (Mailgun side only)

### Domain stays unverified

- Wait up to 48 hours for DNS propagation
- Confirm records were added at the **mg** host, not only at `@` (root)
- Click **Verify** again in Mailgun
- Compare each record character-for-character with Mailgun’s panel

### “Sandbox” or can only send to authorized recipients

You are still on a `mailgun.org` sandbox domain. Add and verify
`mg.grandmamac.com` as in Part 2.

### Emails go to spam during Mailgun test

- Confirm SPF and DKIM are green in Mailgun
- Avoid spammy test subject lines
- Gregory can retest after Supabase is wired; deliverability often improves
  once sending volume is consistent

### Wrong region

If you picked **EU** in Mailgun but Gregory uses the US API URL (or the
reverse), sending will fail. Tell him clearly: **US** or **EU**.

### Lost the API key

Revoke the old key in Mailgun, create a new domain sending key, and send the
new key to Gregory securely.

---

## Questions for Gregory (not Mailgun)

If Forgot PIN still fails **after** you completed this guide and Gregory
confirmed Supabase is wired, that is on the Supabase side — ask him to check
hook logs, not Mailgun DNS.

---

## Official Mailgun links

- [Verify a sending domain](https://documentation.mailgun.com/docs/mailgun/user-manual/domains/domains-verify)
- [API keys and SMTP credentials](https://help.mailgun.com/hc/en-us/articles/203380100-Where-can-I-find-my-API-keys-and-SMTP-credentials)
- [Domain verification setup guide](https://help.mailgun.com/hc/en-us/articles/32884700912923-Domain-Verification-Setup-Guide)
