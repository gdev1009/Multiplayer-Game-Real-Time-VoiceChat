# Match Word — Live ElevenLabs Voice Plan

**Goal:** Drive Guy Smiley from Ronna’s script banks at runtime via ElevenLabs TTS, instead of hand-generating dozens of MP3s.

**Voice:** `Game Show Host` · Voice ID `DHeX7CCuOXUPRpnb0AdT`  
**Script source:** `docs/Guy Smiley Script.pdf` (+ wrap-up lines from Ronna’s chat)

---

## Why live TTS

- 1 intro + 15 correct + 15 wrong + wrap-up (+ more later) = too many files to regenerate by hand
- Lines can rotate each game so Guy doesn’t sound repetitive
- Same voice + SFX source Ronna already approved

## Architecture

```
HostAudio.cuesForTransition(prev, next)
        │
        ▼
AudioController.playCue(cue)
        │
        ├─ SFX (bundled ding / buzzer / cheer) — unchanged
        │
        └─ HostVoiceScripts.lineFor(cue)  →  random / fixed text
                    │
                    ▼
           ElevenLabsTtsService.speak(text)
                    │
           ┌────────┴────────┐
           │ cache hit (disk)│  miss → POST /v1/text-to-speech/{voice_id}
           └────────┬────────┘
                    ▼
           AudioService.playVoiceFile(path) + synthetic lipsync envelope
                    │
                    ▼ (API / network fail)
           fallback bundled Piper MP3 (rules_intro, nice_guess, …)
```

## Security

- **Alpha:** `ELEVENLABS_API_KEY` + `ELEVENLABS_VOICE_ID` in `app/.env` (TTS-only key Ronna issued).
- **Warning:** `.env` is listed under Flutter assets, so the key ships in the APK. Acceptable only while the key is restricted to TTS/SFX.
- **Production:** move the key into a Supabase Edge Function proxy; app calls the function with the user’s JWT — never ship the raw key.

## Caching

- Cache key = SHA-256(voiceId + model + text)
- Files under app documents `elevenlabs_tts_cache/*.mp3`
- Replay is instant after first generation; offline uses cache or Piper fallback

## Cue → script mapping

| SoundCue     | Script bank                          |
|--------------|--------------------------------------|
| `gameStart`  | Full introduction (PDF)              |
| `correct`    | Random of 15 correct lines           |
| `steal`      | Random of 15 wrong / steal lines     |
| `winner`     | Random wrap-up / thanks-for-playing  |
| others       | Keep short bundled lines for now     |

## Also shipping with this pass

- Guess clock: **18 seconds** (Ronna: 15–20) then buzzer / steal path
- Prize / games room: **Wins · Ties · Losses** + “stay tuned for annual tournament” teaser

## Rollout

1. Wire scripts + TTS + cache + fallback  
2. Generate intro once on first launch (warm cache) optional  
3. Ronna reviews a live recording  
4. Later: Edge Function, more cues (halftime personalized), ElevenLabs SFX for ding/buzzer  
