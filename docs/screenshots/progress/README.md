# Match Word — Progress Reel (current M3–M8)

Fresh capture from the **current** app via `lib/demo_progress.dart` (autoplay)
on 2026-07-14 — not the older M3–M5 journey collage.

## Files

| File | What it is |
| --- | --- |
| `match-word-progress-m3-m8.mp4` | Current-version reel. Included in the client package. |
| `match-word-progress-m3-m8.gif` | Lightweight preview |
| `scene_*.png` | Captioned frames |
| `match-word-progress-m3-m6.*` | Older combined reel (superseded) |

## Scenes

1. Home + Rosie idle poses (M7)  
2. Prize Room shelves (M8)  
3. Lobby filled with studio teammates  
4. Live stage kickoff (Guy Smiley)  
5. Clue beat  
6. Score on the board  
7. Halftime  
8. Winner  
9. Free-trial / subscription paywall  

## Regenerate

```bash
cd app
flutter build web -t lib/demo_progress.dart --no-tree-shake-icons
python3 tools/capture_progress_reel.py --serve
```
