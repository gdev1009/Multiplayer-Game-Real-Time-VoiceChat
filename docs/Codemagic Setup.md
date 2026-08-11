# Codemagic Setup — Match Word

We use [Codemagic](https://codemagic.io/) to build and upload Match Word to **TestFlight / App Store Connect**. Ronna does **not** share her Apple ID password — only an App Store Connect API key.

Flutter project lives in **`app/`**. Bundle ID: **`com.matchword.matchWord`**.

---

## 1. Add the app in Codemagic

1. Sign in at [codemagic.io](https://codemagic.io/)
2. **Add application** → connect the GitHub repo `Multiplayer-Game-Real-Time-VoiceChat`
3. Project type: **Flutter**
4. Codemagic will pick up root **`codemagic.yaml`**

---

## 2. Load App Store Connect secrets (from Ronna)

In the Codemagic app → **Environment variables**, create group **`appstore_credentials`** (mark each as **Secret**):

| Variable | Value |
|----------|--------|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations → Keys |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID (e.g. `LU7T485R97`) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Full text of the `.p8` file (including `BEGIN` / `END` lines) |

Optional but recommended for automatic Distribution certificates:

| Variable | Value |
|----------|--------|
| `CERTIFICATE_PRIVATE_KEY` | A new RSA private key PEM used to create/fetch Apple Distribution certs ([docs](https://docs.codemagic.io/yaml-code-signing/signing-ios/)) |

Generate one on a Mac if needed:

```bash
ssh-keygen -t rsa -b 2048 -m PEM -f ./asc_distribution_key -q -N ""
# Paste contents of asc_distribution_key (not .pub) into CERTIFICATE_PRIVATE_KEY
```

Also optional:

| Variable | Value |
|----------|--------|
| `APP_STORE_APPLE_ID` | Numeric Apple ID of the Match Word app record in App Store Connect (for auto build numbers) |

---

## 3. Load app runtime secrets

Create group **`matchword_app_secrets`** (Secret) so CI can write `app/.env`:

| Variable | Notes |
|----------|--------|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | Anon / public key |
| `ELEVENLABS_API_KEY` | TTS key (alpha) |
| `ELEVENLABS_VOICE_ID` | Defaults in yaml if omitted |

Never commit `app/.env` or any `AuthKey_*.p8`.

---

## 4. App Store Connect prerequisite

Create / confirm the **Match Word** app record in App Store Connect with bundle ID `com.matchword.matchWord` before the first automated upload. First-time listing metadata (screenshots, privacy URL) may still need a pass in ASC after the first build lands.

---

## 5. Run a build

1. Open the app in Codemagic → **Start new build**
2. Select workflow **`ios-testflight`** (iOS → TestFlight)
3. Branch: `main`
4. After success, check TestFlight; Ronna’s email gets a Codemagic notify if configured

Workflow **`android-apk`** builds a release APK for QA (separate from Play upload until a Play service-account key is added).

---

## Security

- Do **not** commit `docs/AuthKey_*.p8` or paste API keys into git.
- After publishing, Ronna can revoke the API key in App Store Connect anytime and issue a new one.
