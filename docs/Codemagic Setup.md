# Codemagic Setup — Match Word

We use [Codemagic](https://codemagic.io/) to build and upload Match Word to **TestFlight / App Store Connect**. Ronna does **not** share her Apple ID password — only an App Store Connect API key.

Flutter project lives in **`app/`**. Bundle ID: **`com.matchword.matchWord`**.

---

## Why the last build failed

Codemagic log:

> `Cannot save signing certificates without certificate private key`

The App Store Connect API key (`.p8`) is enough to **talk to Apple**. To **create/save an Apple Distribution certificate**, Codemagic also needs a separate RSA key: **`CERTIFICATE_PRIVATE_KEY`**. That is different from Ronna’s `.p8`.

---

## 1. Add the app in Codemagic

1. Sign in at [codemagic.io](https://codemagic.io/)
2. **Add application** → connect GitHub repo `Multiplayer-Game-Real-Time-VoiceChat`
3. Project type: **Flutter**
4. Codemagic uses root **`codemagic.yaml`**

---

## 2. Load App Store Connect secrets

In the Codemagic app → **Environment variables**, create group **`appstore_credentials`** (mark each as **Secret**):

| Variable | Value |
|----------|--------|
| `APP_STORE_CONNECT_ISSUER_ID` | From App Store Connect → Users and Access → Integrations → Keys |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID (e.g. `LU7T485R97`) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Full text of the `.p8` file (including `BEGIN` / `END` lines) |
| `CERTIFICATE_PRIVATE_KEY` | **Required** — RSA PEM for Distribution cert (generate below) |

### Generate `CERTIFICATE_PRIVATE_KEY` (on your Mac / Linux)

```bash
openssl genrsa -out certificate_private_key.pem 2048
cat certificate_private_key.pem
```

1. Copy the **entire** output (from `-----BEGIN` through `-----END`)
2. In Codemagic → `appstore_credentials` → add **`CERTIFICATE_PRIVATE_KEY`** → paste → save as **Secret**
3. Keep a backup of `certificate_private_key.pem` offline — do **not** commit it to git
4. Re-run workflow **iOS → TestFlight**

Optional:

| Variable | Value |
|----------|--------|
| `APP_STORE_APPLE_ID` | Numeric Apple ID of the Match Word app in App Store Connect (auto build numbers) |

Also make sure no old env var named **`BUNDLE_ID`** points at another app (e.g. a sports app). Match Word is always `com.matchword.matchWord` in `codemagic.yaml`.

---

## 3. Load app runtime secrets

Create group **`matchword_app_secrets`** (Secret) so CI can write `app/.env`:

| Variable | Notes |
|----------|--------|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | Anon / public key |
| `ELEVENLABS_API_KEY` | TTS key (alpha) |
| `ELEVENLABS_VOICE_ID` | Defaults in yaml if omitted |

Never commit `app/.env` or any `AuthKey_*.p8` / `certificate_private_key.pem`.

---

## 4. App Store Connect prerequisite

Create / confirm the **Match Word** app record in App Store Connect with bundle ID `com.matchword.matchWord` before the first automated upload. The App ID `com.matchword.matchWord` must also exist under [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).

---

## 5. Run a build

1. Codemagic → **Start new build**
2. Workflow **`ios-testflight`** (iOS → TestFlight)
3. Branch: `main`
4. Watch step **Check App Store signing secrets** — it should pass once `CERTIFICATE_PRIVATE_KEY` is set

---

## Security

- Do **not** commit API keys or certificate private keys
- After publishing, Ronna can revoke the App Store Connect API key anytime and issue a new one
