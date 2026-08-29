#!/usr/bin/env python3
"""Build the gentle in-game music bed, `app/assets/audio/theme_gentle.mp3`.

Ronna (Aug 2026): wants the light, easy-going bed throughout the game — not the
brassy two-second hook in `theme.mp3`, and not a bed that still feels brassy or
choppy on loop.

This version takes the calmest slice of `opening_bed.mp3` (roughly 5.5–12.5s),
pulls the mid-band brass down harder, softens the top with a gentle low-pass,
and builds a longer crossfade so the loop is less obvious.

Run from the repository root:
    python3 tools/make_gentle_bed.py
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

# Calmer than the first cut — brass share drops below 30% here.
REGION_START_S = 5.5
REGION_END_S = 12.5

# Longer crossfade = less obvious loop seam.
CROSSFADE_S = 1.5

# Pull brass / horn energy down; soften harsh highs.
MID_CUTS = (
    (900.0, 3.5, 1.0),
    (1400.0, 5.0, 1.1),
    (2200.0, 4.5, 1.2),
    (3200.0, 2.5, 0.9),
)
LOWPASS_HZ = 7500.0

# Slightly quieter than before — sits under Guy without competing.
TARGET_RMS_DB = -18.5


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
    a = 10 ** (-gain_db / 40.0)
    w0 = 2 * np.pi * freq / SAMPLE_RATE
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w0), 1 - alpha * a]
    aa = [1 + alpha / a, -2 * np.cos(w0), 1 - alpha / a]
    return signal.filtfilt(np.array(b) / aa[0], np.array(aa) / aa[0], x)


def lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    nyq = SAMPLE_RATE / 2
    norm = min(cutoff_hz / nyq, 0.99)
    b, a = signal.butter(2, norm, btype="low")
    return signal.filtfilt(b, a, x)


def brass_share(x: np.ndarray) -> float:
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

    loop = region[:loop_len].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    loop[:fade] = loop[:fade] * ramp + region[loop_len:loop_len + fade] * (1 - ramp)

    for freq, gain, q in MID_CUTS:
        loop = peaking_cut(loop, freq, gain, q)
    loop = lowpass(loop, LOWPASS_HZ)

    loop *= 10 ** ((TARGET_RMS_DB - rms_db(loop)) / 20.0)
    peak = np.abs(loop).max()
    if peak > 0.98:
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
    seam = abs(float(new[-1] - new[0]))
    print(f"\nloop seam discontinuity: {seam:.4f}")


if __name__ == "__main__":
    main()
