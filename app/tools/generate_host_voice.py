"""Generate warm, male Guy Smiley host voice-over clips (Milestone 6).

Voice profile — an ORIGINAL cheerful animated male game-show host (not an
impression of any real actor, celebrity or existing character):

    Male, North American accent, age 35–50, bright and friendly, medium-high
    energy, smooth announcer style with a warm smile in the delivery. Clear
    pronunciation, moderate pacing so older players follow easily, light
    enthusiasm on important words — encouraging and patient, never shouting,
    sarcastic or cartoonishly exaggerated.

We synthesise this with **Piper** (neural TTS, offline) using the original
`en_US-ryan-high` male voice model — a bright, clear announcer-style voice.
Pacing is slowed slightly (length_scale) for senior clarity, and each clip is
loudness-normalised. Output is MP3 so the files are pure drop-in by filename
(see `assets/audio/voice/README.md`); replace any file with a studio recording
of the same name and it plays automatically.

Run from the `app/` directory (first run downloads the ~120 MB voice model):
    python3 tools/generate_host_voice.py
"""

from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg

VOICE = "en_US-ryan-high"
VOICE_DIR = Path("tools/piper_voices")
MODEL = VOICE_DIR / f"{VOICE}.onnx"
OUT = Path("assets/audio/voice")

# Slightly slower than default (1.0) for calm, senior-friendly pacing.
LENGTH_SCALE = 1.12
# A touch of expressive variation without sounding unstable.
NOISE_SCALE = 0.6
NOISE_W = 0.8

# Filename -> spoken line. Names match SoundCue voice paths in host_audio.dart.
# Commas / em-dashes give the host natural pauses; warm beats land gently.
LINES = {
    "rules_intro": (
        "Welcome to Match Word! Here's how we play. "
        "Give a one-word clue, guess the secret word, "
        "and the fastest team wins. Let's have some fun!"
    ),
    "your_turn": "You're on the clock! Take your time — give it your best.",
    "nice_guess": "That's it! Wonderful guess — beautifully done!",
    "good_try": "Good try! Nice effort. The other team gets a shot.",
    "halftime": "It's halftime! Switch it up, and keep on having fun.",
    "winner": "And we have our winners! Congratulations — wonderfully played!",
    "disconnect": (
        "Hold on a moment, friends. A player dropped out. "
        "Don't you worry — we'll wait right here for them."
    ),
}

# A spare sample line for voice auditions. Written OUTSIDE the bundled assets
# folder so it never ships in the app — it's just for the client to hear.
SAMPLE_TEXT = "Rosa, it's your turn — give a clue!"
SAMPLE_OUT = Path("../docs/screenshots/milestone6/host-voice-sample.mp3")


def _ensure_model() -> None:
    if MODEL.exists() and MODEL.stat().st_size > 1_000_000:
        return
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    print(f"downloading Piper voice {VOICE} (~120 MB, one time)…")
    subprocess.run(
        ["python3", "-m", "piper.download_voices", VOICE,
         "--data-dir", str(VOICE_DIR)],
        check=True,
    )


def _synth_wav(text: str, wav_path: Path) -> None:
    subprocess.run(
        ["python3", "-m", "piper",
         "-m", str(MODEL),
         "--length-scale", str(LENGTH_SCALE),
         "--noise-scale", str(NOISE_SCALE),
         "--noise-w-scale", str(NOISE_W),
         "-f", str(wav_path)],
        input=text.encode("utf-8"),
        check=True,
    )


def _wav_to_mp3(wav_path: Path, mp3_path: Path) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [ffmpeg, "-y", "-i", str(wav_path),
         # Loudness-normalise so every line sits at a comfortable, even level.
         "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
         "-ar", "44100", "-ac", "1", "-b:a", "128k",
         str(mp3_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _duration(wav_path: Path) -> float:
    with wave.open(str(wav_path)) as w:
        return w.getnframes() / w.getframerate()


def main() -> None:
    _ensure_model()
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = Path("/tmp/host_voice")
    tmp.mkdir(parents=True, exist_ok=True)

    for name, line in LINES.items():
        wav = tmp / f"{name}.wav"
        _synth_wav(line, wav)
        mp3 = OUT / f"{name}.mp3"
        _wav_to_mp3(wav, mp3)
        print(f"wrote {mp3}  ({_duration(wav):.1f}s, {mp3.stat().st_size} bytes)")

    # Audition sample — outside the bundled assets folder.
    if SAMPLE_OUT.parent.exists():
        wav = tmp / "sample.wav"
        _synth_wav(SAMPLE_TEXT, wav)
        _wav_to_mp3(wav, SAMPLE_OUT)
        print(f"wrote {SAMPLE_OUT} (audition, not bundled)")

    print(f"done — male host voice ({VOICE}); {len(LINES)} game clips in {OUT}")


if __name__ == "__main__":
    main()
