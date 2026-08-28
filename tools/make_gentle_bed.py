#!/usr/bin/env python3
"""Build the gentle in-game music bed, `app/assets/audio/theme_gentle.mp3`.

Why this exists
---------------
Ronna, Aug 2026: "The music at the end of the game is pretty light and easy
going. I like that. I think we should use that throughout the game." Earlier:
"I don't mind the beginning part where it's just sort of a gentle beat, but when
the horns or trumpets come in, it gets annoying very quickly."

`theme.mp3` — the track that looped for the whole game — is 8.0s long and is a
two-second brass stab riff repeated four times. Measured in 250ms windows, the
400–2500Hz band (where trumpets and trombones sit) is 56–71% of its entire
spectrum, and its level alternates -13dB / -20dB every 250ms with a hard dip
every 2s. There is no gentle passage in it to fall back on, and looping it means
that brass hook returns every two seconds for the length of a game.

`opening_bed.mp3` (13.0s, the show-open bed) has a much lighter second half:
from about 4s in, the brass band share falls to 33–50%, the level settles into
an even -17 to -19dB, and the character becomes a light, bright groove with no
stab pattern. That is the closest thing in the project to what Ronna asked for,
and it is music she has already said she likes.

So the in-game bed is derived from that section:
  * take the light region of `opening_bed.mp3`,
  * pull back the brass presence with two gentle mid-band cuts,
  * build a seamless loop by folding the tail back over the head, and
  * trim the level so it sits under Guy and the crowd.

Run from the repository root:
    python3 tools/make_gentle_bed.py

Requires ffmpeg. `pip install imageio-ffmpeg` supplies one if the system has
none. The generated MP3 is committed, so this only needs re-running to change
how the bed is built.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SRC = Path("app/assets/audio/opening_bed.mp3")
OUT = Path("app/assets/audio/theme_gentle.mp3")
REFERENCE = Path("app/assets/audio/theme.mp3")

SAMPLE_RATE = 44100

# The light region of the source, measured above.
REGION_START_S = 4.0
REGION_END_S = 13.0

# Crossfade folded back over the head so the loop has no seam.
CROSSFADE_S = 1.0

# Gentle mid-band cuts where brass is most forward.
MID_CUTS = ((1200.0, 4.0, 1.2), (2000.0, 3.0, 1.2))  # (Hz, dB down, Q)

# Target level, a touch below the old theme's -15.4dB. Kept close on purpose:
# the in-app music slider is already calibrated for that level, so matching it
# means the bed's *character* changes without the mix needing to be re-tuned.
TARGET_RMS_DB = -17.0


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
    except ImportError:
        sys.exit("ffmpeg not found. Try: pip install imageio-ffmpeg")
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path: Path, rate: int = SAMPLE_RATE) -> np.ndarray:
    out = subprocess.run(
        [ffmpeg(), "-v", "error", "-i", str(path),
         "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


def peaking_cut(x: np.ndarray, freq: float, gain_db: float, q: float) -> np.ndarray:
    """A standard peaking EQ with negative gain, applied without phase shift."""
    a = 10 ** (-gain_db / 40.0)
    w0 = 2 * np.pi * freq / SAMPLE_RATE
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w0), 1 - alpha * a]
    aa = [1 + alpha / a, -2 * np.cos(w0), 1 - alpha / a]
    return signal.filtfilt(np.array(b) / aa[0], np.array(aa) / aa[0], x)


def brass_share(x: np.ndarray) -> float:
    """Fraction of spectral energy in the 400–2500Hz brass band."""
    hop = int(SAMPLE_RATE * 0.25)
    shares = []
    for i in range(0, max(len(x) - hop, 1), hop):
        seg = x[i:i + hop]
        if len(seg) < hop:
            break
        spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
        freqs = np.fft.rfftfreq(len(seg), 1 / SAMPLE_RATE)
        total = spec.sum() + 1e-12
        shares.append(spec[(freqs >= 400) & (freqs <= 2500)].sum() / total)
    return float(np.mean(shares)) if shares else 0.0


def rms_db(x: np.ndarray) -> float:
    return float(20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12))


def main() -> None:
    if not SRC.exists():
        sys.exit(f"missing {SRC} — run from the repository root")

    source = decode(SRC)
    region = source[int(REGION_START_S * SAMPLE_RATE):int(REGION_END_S * SAMPLE_RATE)]

    fade = int(CROSSFADE_S * SAMPLE_RATE)
    loop_len = len(region) - fade
    if loop_len <= fade:
        sys.exit("region too short for the requested crossfade")

    # Fold the tail back over the head: the first `fade` samples become a blend
    # of the head and the material that follows the loop point, so playing the
    # loop end into the loop start is continuous.
    loop = region[:loop_len].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    loop[:fade] = loop[:fade] * ramp + region[loop_len:loop_len + fade] * (1 - ramp)

    for freq, gain, q in MID_CUTS:
        loop = peaking_cut(loop, freq, gain, q)

    loop *= 10 ** ((TARGET_RMS_DB - rms_db(loop)) / 20.0)
    peak = np.abs(loop).max()
    if peak > 0.98:  # keep headroom so the encoder does not clip
        loop *= 0.98 / peak

    tmp = Path("/tmp/theme_gentle.wav")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes((np.clip(loop, -1, 1) * 32767).astype("<i2").tobytes())

    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [ffmpeg(), "-v", "error", "-y", "-i", str(tmp),
         "-codec:a", "libmp3lame", "-b:a", "128k", "-ac", "1", str(OUT)],
        check=True,
    )

    old = decode(REFERENCE)
    new = decode(OUT)
    print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB)")
    print()
    print(f"{'':16} {'length':>8} {'level':>9} {'brass 400-2500Hz':>18}")
    for label, clip in (("theme.mp3 (old)", old), ("theme_gentle.mp3", new)):
        print(f"{label:16} {len(clip)/SAMPLE_RATE:7.2f}s "
              f"{rms_db(clip):8.1f}dB {brass_share(clip)*100:17.1f}%")

    # Loop seam: the step between the last and first sample should be small.
    seam = abs(float(new[-1] - new[0]))
    print(f"\nloop seam discontinuity: {seam:.4f} (0 = perfectly seamless)")


if __name__ == "__main__":
    main()
