# Host voice-over clips (drop-in)

The Guy Smiley **host voice** lines currently ship as an **original male
game-show-host voice** generated offline with Piper neural TTS (voice model
`en_US-ryan-high`) via `tools/generate_host_voice.py`. Voice profile: male,
North-American, age 35–50, bright/friendly, smooth announcer style, warm and
patient with clear, moderately-paced delivery for seniors. These are original
(no impression of any real actor/celebrity/existing character) and are a pure
drop-in — a studio voice-over of the same filenames replaces them with no code
changes. Re-run `python3 tools/generate_host_voice.py` from `app/` to rebuild
them (first run downloads the ~120 MB voice model into `tools/piper_voices/`).

Drop MP3s here with these exact names and they play automatically at the right
moment (see `lib/features/host/host_audio.dart` → `SoundCue`):

| File               | When it plays                                  |
|--------------------|------------------------------------------------|
| `rules_intro.mp3`  | Once at the start of every game (rules intro). |
| `your_turn.mp3`    | When a player is put on the clock.             |
| `nice_guess.mp3`   | On a correct guess (over the cheer).           |
| `good_try.mp3`     | On a steal / wrong guess.                       |
| `halftime.mp3`     | At the halftime role switch.                    |
| `winner.mp3`       | Winner announcement.                            |
| `disconnect.mp3`   | Disconnect commentary, over the alarm.          |

Until a file is present, the host still "speaks" via the on-screen speech
bubble and the announcer/effect cues — the voice line simply no-ops, so nothing
breaks. Keep clips short (1–3s), mono, MP3, normalised.
