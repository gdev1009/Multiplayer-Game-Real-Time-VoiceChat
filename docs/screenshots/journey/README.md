# Match Word — Milestone Journey Reel

A single continuous walkthrough that chains **Milestone 3 (Character Creation)**,
**Milestone 4 (Lobby & Matchmaking)** and **Milestone 5 (Core Gameplay)** through the
real app screens — the same flow a player experiences, driven end‑to‑end.

## Files

| File | What it is |
| --- | --- |
| `match-word-journey.mp4` | 35‑second captioned reel (608×944, 25 fps). Best for sharing. |
| `match-word-journey.gif` | Lightweight looping preview (~0.5 MB) for chat/email. |
| `scene_*.png` | The 12 individual captioned frames, in order. |

## The story (12 scenes)

1. **M3 · Meet Grandma Mac** — Sunny's friendly home screen.
2. **M3 · Character Studio** — choose a body and skin tone.
3. **M3 · Style your look** — hair, eyes and colours.
4. **M3 · Dress your character** — the clay figure comes to life.
5. **M3 · Looking great, Rosie!** — name and save.
6. **M3 · Character saved** — ready to play.
7. **M4 · Play a game** — find a game, host, or join by code.
8. **M4 · Game Room** — studio players join in a few seconds (adjustable pre‑AI wait).
9. **M4 · Teams are set** — four players across Team A and Team B.
10. **M5 · Match Word begins** — Sunny gives a one‑word clue.
11. **M5 · The clue is in** — "Petals" → teammates guess.
12. **M5 · Correct, +5 points!** — Team A guessed "Flower".

## How it was produced

The reel is captured from the unified demo entry `app/lib/demo_journey.dart`, which
wires the **real** OpeningScreen → Character Studio → Lobby → Play screens with
in‑memory fakes (no Supabase needed). Because the lobby→play handoff and the local
match engine are the production code paths, the recording reflects genuine behaviour,
not a mock‑up.

To regenerate:

```bash
cd app
flutter build web -t lib/demo_journey.dart --no-tree-shake-icons
python3 -m http.server 8091 --directory "$PWD/build/web"
# capture frames to /tmp/journey_frames, then:
python3 tools/build_journey_reel.py
```
