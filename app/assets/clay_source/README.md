# Clay Asset Library — Match Word

A simple, consistent home for Ronna's clay creations so nothing gets lost as
new pieces arrive.

## Folders

- `assets/clay_source/` — original files exactly as the client sends them
  (full resolution, untouched). Never edit these; treat as the master copy.
- `assets/images/host/` — app-ready host (Guy Smiley) images used in the UI
  (trimmed/sized PNGs with transparent backgrounds).

## Naming convention

Use lowercase words separated by hyphens, with a category prefix:

- Host: `host-avatar.png`, `host-fullbody.png`, `host-wave.png`
- Trophies: `trophy-first-win.png`, `trophy-10-games.png`
- Characters: `char-base-1.png`, `char-hair-curly.png`, `char-glasses-round.png`
- Prizes: `prize-*.png`

Add a short suffix for variants/states: `-idle`, `-cheer`, `-worry`, `-2x`.

## Preferred format (works best in the app)

- PNG with a transparent background (the circular avatar you sent is perfect).
- Square canvas for avatars (e.g. 512×512 or 1024×1024).
- Keep the original high-res file in `clay_source/`; we down-size as needed.

## Incoming log

| Date | File received | Category | Status |
|------|---------------|----------|--------|
| 2026-06-30 | Guy Smiley chat avatar (circular) | host | added as `host-avatar.png` (live in chats/host greeting) |
| 2026-06-30 | Guy Smiley full-body (microphone) | host | added as `host-fullbody.png` (ready for studio/host use) |
| 2026-07-14 | *(placeholders)* trophy-first-win, trophy-10-games, trophy-50-games, prize-sports-car, prize-vacation, prize-tv | trophies/prizes | temporary app PNGs until client clay art arrives |
