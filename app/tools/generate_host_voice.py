"""Generate natural male Guy Smiley host voice-over clips.

Voice profile — an ORIGINAL warm adult male game-show host (not an impression
of any real actor/celebrity/existing character):

    Male, North American, age ~40, clear announcer diction, friendly and
    patient. Sounds like a real human speaking — never cartoon, chipmunk,
    or "minion" pitch.

We synthesise with **Piper** (`en_US-joe-medium`) — a natural adult male voice.
We deliberately do **not** pitch-shift with asetrate/playbackRate hacks (those
create the cartoon formant problem). Loudness is normalised only.

Run from the `app/` directory:
    python3 tools/generate_host_voice.py
"""

from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg

# Natural adult male — clearer human timbre than ryan-high + pitch hacks.
VOICE = "en_US-joe-medium"
VOICE_DIR = Path("tools/piper_voices")
MODEL = VOICE_DIR / f"{VOICE}.onnx"
OUT = Path("assets/audio/voice")

# Calm senior-friendly pacing (slightly slower than default 1.0).
LENGTH_SCALE = 1.12
NOISE_SCALE = 0.667
NOISE_W = 0.8

# Loudness only — NO pitch shift (asetrate was making it sound non-human).
VOICE_AF = "loudnorm=I=-14:TP=-1.0:LRA=11"

# Filename -> spoken line. Names match SoundCue voice paths in host_audio.dart.
LINES = {
    "rules_intro": (
        "Welcome to Match Word! Here's how we play. "
        "Give a one-word clue, guess the secret word, "
        "and the fastest team wins. Let's have some fun!"
    ),
    "your_turn": "You're on the clock! Take your time — give it your best.",
    "nice_guess": "That's it! Wonderful guess — beautifully done!",
    "good_try": "Good try! Nice effort. The other team gets a shot.",
    "word_revealed": "Time's up — here is the word. Let's keep going!",
    "halftime": "It's half time! Switch it up, and keep on having fun.",
    "winner": "And we have our winners! Congratulations — wonderfully played!",
    "disconnect": (
        "Hold on a moment, friends. A player dropped out. "
        "Don't you worry — we'll wait right here for them."
    ),
}

SAMPLE_TEXT = "Rosa, it's your turn — give a clue!"
SAMPLE_OUT = Path("../docs/screenshots/milestone6/host-voice-sample.mp3")


def _ensure_model() -> None:
    if MODEL.exists() and MODEL.stat().st_size > 1_000_000:
        return
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    print(f"downloading Piper voice {VOICE} (~one time)…")
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
         "-af", VOICE_AF,
         "-ar", "44100", "-ac", "1", "-b:a", "160k",
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

    if SAMPLE_OUT.parent.exists():
        wav = tmp / "sample.wav"
        _synth_wav(SAMPLE_TEXT, wav)
        _wav_to_mp3(wav, SAMPLE_OUT)
        print(f"wrote {SAMPLE_OUT} (audition, not bundled)")

    print(f"done — natural male host voice ({VOICE}); {len(LINES)} clips in {OUT}")


if __name__ == "__main__":
    main()
