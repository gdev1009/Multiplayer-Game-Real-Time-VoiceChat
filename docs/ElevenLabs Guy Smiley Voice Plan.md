# Match Word — ElevenLabs Voice Design (Click-by-Click)

**Goal:** Design **Guy Smiley’s** production voice in the **Voice Design** dialog (screenshot UI), save it, then generate the **8 drop-in host MP3s**.  
**App integration:** replace files in `app/assets/audio/voice/` — **no code changes**.  
**Approve with Ronna** after the Voice Design preview, before generating the full pack.

This guide matches the dialog fields you see:

| UI control | What it does |
|------------|--------------|
| **Prompt** | Describes *who* the voice is (age, gender, tone, pacing, quality) |
| **Preview text** | The sample line the three candidates will speak |
| **Loudness** | How loud the preview / saved voice feels |
| **Guidance scale** | How strictly the model follows your Prompt |
| **Generate voice** | Creates **3** voice candidates (credit cost shown on the button) |
| **Generate Preview Text** (toggle) | Leave **Off** — we paste our own preview text |
| **Settings** | Optional extras; leave defaults unless noted |

---

## Part A — Open Voice Design

1. Go to [https://elevenlabs.io](https://elevenlabs.io) and sign in.
2. Open **Voices** (left sidebar / top nav).
3. Click **My Voices**.
4. Click **Add a new voice** (or **+**).
5. Choose **Voice Design**.

You should see the dialog:

- Left: **Prompt** + **Preview text** + **Generate voice**
- Right: **Generate Preview Text** toggle, **Loudness**, **Guidance Scale**

---

## Part B — Fill the Voice Design dialog (Guy Smiley)

### B1. Turn off auto preview text

1. On the **right** panel, find **Generate Preview Text**.
2. Set the toggle to **Off** (so ElevenLabs does not invent preview copy).
3. We will paste our own **Preview text** below.

### B2. Set Loudness

1. On the **right** panel, find **Loudness** (`Quiet` ← → `Loud`).
2. Drag the handle to about **75–85% toward Loud**  
   (similar to the screenshot’s position — clear on phone speakers, not clipping).
3. Do **not** slam it fully to Loud (distortion risk).

### B3. Set Guidance Scale

1. On the **right** panel, find **Guidance Scale** (`Low` ← → `High`).
2. Drag to about **mid–high** (roughly **60–70%** toward High).

**Why:** Guy Smiley needs a **specific** warm host identity (not random creativity).  
Higher guidance = closer to the Prompt. Too low (like the ogre example’s “Low”) drifts.

| If result feels… | Move Guidance… |
|------------------|-----------------|
| Too generic / wrong vibe | **Higher** |
| Stiff, unnatural, or “over-prompted” | **Slightly lower** |
| Accent / age wrong | **Higher** + tighten Prompt |

### B4. Paste the Prompt (left panel)

1. Click inside the **Prompt** text area.
2. Select all and delete the Evil Ogre example (or any preset).
3. Paste **exactly** this Prompt:

```text
Native English, neutral North American. Male, mid-40s. Broadcast quality.
Persona: warm game-show host. Emotion: friendly, patient, encouraging.
Clear, smooth adult-male timbre with a gentle smile in the voice. Speaks at a calm, slightly measured pace so seniors can follow every word. Handheld studio microphone feel, clean and natural. Never cartoon, never gravelly villain, never sarcastic, never a celebrity impression. Perfect audio quality.
```

**Prompt rules used here (ElevenLabs best practices):**

- Lead with **language + gender + age + quality**
- Short **Persona** + **Emotion**
- 1–2 sentences on **timbre / pacing / delivery**
- End with **Perfect audio quality** / broadcast quality
- Avoid FX words (no “reverb”, “echo”, “phone filter”)

### B5. Paste the Preview text (left panel)

1. Click inside **Preview text**.
2. Clear any ogre / preset sample.
3. Paste this **long, on-character** preview (ElevenLabs tip: longer relevant text = better previews):

```text
Welcome to Match Word! Here's how we play. Give a one-word clue, guess the secret word, and the fastest team wins. You're on the clock — take your time and give it your best. That's it! Wonderful guess. Good try, nice effort. Hold on a moment, friends — don't you worry, we'll wait right here.
```

**Why this text:** It mixes welcome / turn / praise / comfort — the same emotional range Guy uses in-game.

Optional tags (only if you want a tiny smile break):

```text
Welcome to Match Word! [warm chuckle] Here's how we play…
```

Prefer **no tags** for the first generate — keep it clean for seniors.

### B6. Ignore preset chips

Do **not** click **Evil Ogre**, **Little Mouse**, **Southern Woman**, or shuffle unless you want to reset. Stay with the Guy Smiley Prompt above.

### B7. Generate the three candidates

1. Check the **Generate voice** button — note the credit cost (e.g. coin + number).
2. Click **Generate voice**.
3. Wait for **three** preview cards / play buttons.

### B8. Listen and pick

Play all three. Use this checklist (Pass/Fail):

| Check | Pass sounds like… |
|-------|-------------------|
| Age | Mid-40s adult male (not teen, not elderly croak) |
| Warmth | Smiling host, not angry / scary / silly |
| Pace | Slightly slow, easy to understand |
| Clarity | Clean words; no mushy consonants |
| Identity | Original host — **not** a famous announcer impression |
| Fit for seniors | Patient; never shouting |

**If none pass:**

1. Adjust **one** thing only:
   - Prompt wording, **or**
   - Guidance Scale ± a little, **or**
   - Loudness slightly down if harsh
2. Click **Generate voice** again.
3. Repeat until one candidate is clearly best.

**Recommended first tweak if too “TV loud”:** soft Prompt line →  
`Speaks gently into a handheld mic, warm living-room game show, never stadium loud.`  
and lower Loudness a notch.

**If too soft / dull:** raise Loudness slightly; add `bright and cheerful` to Emotion.

### B9. Save the voice

1. Select the winning candidate.
2. Click **Save** / **Add to My Voices** (wording may vary).
3. Name it exactly:

```text
Guy Smiley — Match Word
```

4. Confirm it appears under **My Voices**.

You now have a reusable voice ID. All 8 game lines must use **this same voice**.

---

## Part C — Send Ronna a direction sample (before the full pack)

1. Still in ElevenLabs, open **Speech Synthesis** / **Text to Speech**.
2. Select voice: **Guy Smiley — Match Word**.
3. Paste this short audition script:

```text
Welcome to Match Word! You're on the clock — take your time. That's it! Wonderful guess. Hold on a moment, friends — don't you worry.
```

4. Generate → Download MP3.
5. Message Ronna (optional):

> Hi Ronna — here’s a short sample of Guy Smiley’s proposed ElevenLabs voice (warm, clear, senior-friendly game-show host). If the tone feels right, I’ll generate all eight in-game lines next. If you want him softer / brighter / slower, tell me and I’ll redesign once before the full pack.

**Stop here until Ronna OK’s the direction** (or you decide to proceed).

---

## Part D — Generate the 8 game clips (Speech Synthesis)

Use **Speech Synthesis** (not Voice Design again). Same voice for every file.

### D1. Shared TTS settings (keep constant)

Exact labels vary by UI version; aim for:

| Control | Start value |
|---------|-------------|
| Voice | **Guy Smiley — Match Word** |
| Model | Multilingual v2 or highest-quality English model available |
| Stability | ~**50%** |
| Similarity / Clarity | ~**75%** |
| Style exaggeration | ~**20%** (if present) |
| Speaker boost | **On** (if present) |
| Output | **MP3** |

Do **not** redesign the voice between clips.

### D2. Generate each clip (repeat 8 times)

For each row:

1. Clear the text box.
2. Paste the **Script**.
3. (Optional) Paste the **Direction** into any “style” / note field if the UI has one — otherwise skip; the voice already carries the identity.
4. Click **Generate**.
5. Listen once.
6. **Download** as MP3.
7. Rename the file to the **Exact filename** (case-sensitive).

| # | Exact filename | Script | Direction (performance) | Target length |
|---|----------------|--------|-------------------------|---------------|
| 1 | `rules_intro.mp3` | Welcome to Match Word! Here's how we play. Give a one-word clue, guess the secret word, and the fastest team wins. Let's have some fun! | Warm open; tiny pause after “Match Word!”; clear “one-word clue” / “secret word”; unhurried | 7–10 s |
| 2 | `your_turn.mp3` | You're on the clock! Take your time — give it your best. | Gentle nudge, not pressure | 2–3.5 s |
| 3 | `nice_guess.mp3` | That's it! Wonderful guess — beautifully done! | Happy, not yelling | 2–3 s |
| 4 | `good_try.mp3` | Good try! Nice effort. The other team gets a shot. | Kind, never mocking | 2–3.5 s |
| 5 | `word_revealed.mp3` | Time's up — here is the word. Let's keep going! | Neutral + encouraging | 2–3.5 s |
| 6 | `halftime.mp3` | It's half time! Switch it up, and keep on having fun. | Breezy mid-show | 2–3.5 s |
| 7 | `winner.mp3` | And we have our winners! Congratulations — wonderfully played! | Warm finale | 2.5–4 s |
| 8 | `disconnect.mp3` | Hold on a moment, friends. A player dropped out. Don't you worry — we'll wait right here for them. | Calm over alarm; never frantic | 3–5 s |

### D3. Folder ready for the app

Put all eight files in one folder, e.g. `Desktop/guy-smiley-voice/`, with **only** these names:

```text
rules_intro.mp3
your_turn.mp3
nice_guess.mp3
good_try.mp3
word_revealed.mp3
halftime.mp3
winner.mp3
disconnect.mp3
```

---

## Part E — Drop into Match Word

```bash
cd /path/to/Multiplayer-Game-Real-Time-VoiceChat/app

# Copy the 8 MP3s over the placeholders:
cp /path/to/guy-smiley-voice/*.mp3 assets/audio/voice/

# Rebuild lipsync envelopes for pose-swap:
python3 tools/generate_voice_envelopes.py
```

Then rebuild / install the APK (or TestFlight later) and spot-check:

- Match start → hears `rules_intro`
- New turn → `your_turn`
- Correct → `nice_guess`
- Wrong → `good_try`
- Disconnect → calm `disconnect` over alarm

Mute / volume sliders should still work; disconnect alarm remains a safety cue.

---

## Part F — Quick reference (copy/paste)

### Voice Design — Prompt

```text
Native English, neutral North American. Male, mid-40s. Broadcast quality.
Persona: warm game-show host. Emotion: friendly, patient, encouraging.
Clear, smooth adult-male timbre with a gentle smile in the voice. Speaks at a calm, slightly measured pace so seniors can follow every word. Handheld studio microphone feel, clean and natural. Never cartoon, never gravelly villain, never sarcastic, never a celebrity impression. Perfect audio quality.
```

### Voice Design — Preview text

```text
Welcome to Match Word! Here's how we play. Give a one-word clue, guess the secret word, and the fastest team wins. You're on the clock — take your time and give it your best. That's it! Wonderful guess. Good try, nice effort. Hold on a moment, friends — don't you worry, we'll wait right here.
```

### Voice Design — Sliders

| Control | Position |
|---------|----------|
| Generate Preview Text | **Off** |
| Loudness | ~**80%** toward Loud |
| Guidance Scale | ~**65%** toward High |

### Save name

```text
Guy Smiley — Match Word
```

---

## Part G — Troubleshooting

| Problem | Fix |
|---------|-----|
| Sounds like a cartoon / ogre / silly | Prompt still polluted — clear Prompt, re-paste Guy Smiley block; raise Guidance |
| Sounds like a celebrity | Add `original character, not an impression of any famous host` to Prompt; regenerate |
| Too fast | Add `slow, measured pacing` to Prompt; regenerate Voice Design |
| Too quiet on phone | Raise Loudness; or normalize MP3s later to −14 LUFS |
| Three candidates all weak | Rewrite Prompt shorter; regenerate; try Guidance mid, then High |
| Clip identity drifts across files | Confirm same saved voice selected in Speech Synthesis every time |
| Wrong file plays in app | Filename mismatch — must match table in Part D exactly |

---

## Related files

- Scripts source: `app/tools/generate_host_voice.py`  
- Drop-in README: `app/assets/audio/voice/README.md`  
- Cue wiring: `app/lib/features/host/host_audio.dart`  
- Envelopes: `app/tools/generate_voice_envelopes.py`  
- Earlier overview (kept as companion): this document supersedes the click path for **Voice Design**
