#!/usr/bin/env python3
"""Match Word — placeholder audio cue generator (Milestone 6).

Synthesises royalty-free, developer-generated placeholder sounds for the Guy
Smiley host + audio system so the whole cue pipeline is demonstrable today. The
final licensed theme / announcer clips and recorded host voice-over are a pure
drop-in by filename later (same pattern as the character art pack) — replace the
files in ``assets/audio/`` and nothing else changes.

Everything here is generated from scratch with numpy (simple oscillators +
envelopes + shaped noise), so the output carries no third-party licensing.

Run from the ``app/`` folder:

    python3 tools/generate_audio_cues.py

Requires numpy and an ffmpeg binary (system ffmpeg or the one bundled with the
``imageio-ffmpeg`` pip package) to encode the WAV render to small MP3s.
"""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import wave

import numpy as np

SR = 44100  # sample rate
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


# --- oscillators + helpers ---------------------------------------------------

def _t(dur: float) -> np.ndarray:
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def sine(freq: float, dur: float) -> np.ndarray:
    return np.sin(2 * np.pi * freq * _t(dur))


def saw(freq: float, dur: float) -> np.ndarray:
    t = _t(dur)
    return 2.0 * (t * freq - np.floor(0.5 + t * freq))


def square(freq: float, dur: float) -> np.ndarray:
    return np.sign(sine(freq, dur))


def glide(f0: float, f1: float, dur: float, kind: str = "saw") -> np.ndarray:
    t = _t(dur)
    freq = np.linspace(f0, f1, t.size)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    if kind == "sine":
        return np.sin(phase)
    return 2.0 * (phase / (2 * np.pi) - np.floor(0.5 + phase / (2 * np.pi)))


def adsr(n: int, a=0.01, d=0.06, s=0.7, r=0.2) -> np.ndarray:
    """Attack/decay/sustain/release envelope of length n samples."""
    a_n = max(1, int(SR * a))
    d_n = max(1, int(SR * d))
    r_n = max(1, int(SR * r))
    s_n = max(1, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, a_n),
        np.linspace(1, s, d_n),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    if env.size < n:
        env = np.concatenate([env, np.zeros(n - env.size)])
    return env[:n]


def bell(freq: float, dur: float, detune=1.0) -> np.ndarray:
    """A soft bell/marimba-ish tone: fundamental + a couple of partials."""
    tone = (
        1.0 * sine(freq, dur)
        + 0.5 * sine(freq * 2.01 * detune, dur)
        + 0.25 * sine(freq * 3.0, dur)
    )
    env = adsr(tone.size, a=0.004, d=0.25, s=0.0, r=0.4)
    return tone * env


def noise(dur: float) -> np.ndarray:
    return np.random.uniform(-1.0, 1.0, int(SR * dur))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole low-pass, cheap and stable."""
    rc = 1.0 / (2 * np.pi * cutoff)
    alpha = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def pad(x: np.ndarray, head=0.0, tail=0.05) -> np.ndarray:
    return np.concatenate([np.zeros(int(SR * head)), x, np.zeros(int(SR * tail))])


def norm(x: np.ndarray, peak=0.89) -> np.ndarray:
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


NOTE = {  # equal-temperament, a handful of octaves
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
    "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
    "F5": 698.46, "G5": 783.99, "A5": 880.00, "C6": 1046.50, "E6": 1318.51,
    "G6": 1567.98,
}


# --- individual cue builders -------------------------------------------------

def build_theme() -> np.ndarray:
    """Warm, upbeat, loop-friendly jingle (~8s) — the opening/lobby theme."""
    chords = [  # I - V - vi - IV, one bar (2s) each
        ("C4", "E4", "G4"),
        ("G4", "B4", "D5"),
        ("A4", "C5", "E5"),
        ("F4", "A4", "C5"),
    ]
    melody = ["C5", "E5", "G5", "E5", "D5", "G5", "B4", "D5",
              "E5", "A5", "C6", "A5", "F5", "A5", "C6", "G5"]
    bar = 2.0
    out = np.zeros(int(SR * bar * len(chords)))
    # pad chords
    for i, ch in enumerate(chords):
        seg = np.zeros(int(SR * bar))
        for nm in ch:
            tone = saw(NOTE[nm] / 2, bar) * 0.25
            tone = lowpass(tone, 900) * adsr(tone.size, a=0.05, d=0.3, s=0.6, r=0.5)
            seg += tone
        start = int(SR * bar * i)
        out[start:start + seg.size] += seg
    # melody, eighth notes
    step = bar / 4
    for i, nm in enumerate(melody):
        tone = bell(NOTE[nm], step * 0.95) * 0.6
        start = int(SR * step * i)
        out[start:start + tone.size] += tone[: out.size - start]
    return norm(out, 0.82)


def build_announcer_intro() -> np.ndarray:
    """Brassy rising fanfare — 'And now… Match Word!' announcer sting (~2.4s)."""
    seq = [("C4", 0.3), ("E4", 0.3), ("G4", 0.3), ("C5", 0.9)]
    out = np.array([])
    for nm, d in seq:
        base = NOTE[nm]
        tone = (saw(base, d) + 0.5 * saw(base * 2, d)) * 0.4
        tone = lowpass(tone, 2600) * adsr(tone.size, a=0.02, d=0.1, s=0.8, r=0.15)
        out = np.concatenate([out, tone])
    # sparkle tail
    spark = bell(NOTE["G5"], 0.6) * 0.4 + bell(NOTE["C6"], 0.6) * 0.4
    out = np.concatenate([out, spark])
    return norm(pad(out, tail=0.1), 0.85)


def build_round_start() -> np.ndarray:
    """Short bright two-note 'here we go' sting (~0.6s)."""
    out = np.concatenate([bell(NOTE["G5"], 0.22) * 0.8, bell(NOTE["C6"], 0.5) * 0.9])
    return norm(pad(out, tail=0.08))


def build_correct() -> np.ndarray:
    """Happy ascending chime for a correct guess (~0.7s)."""
    out = np.concatenate([
        bell(NOTE["E5"], 0.16) * 0.8,
        bell(NOTE["G5"], 0.16) * 0.9,
        bell(NOTE["C6"], 0.5) * 1.0,
    ])
    return norm(pad(out, tail=0.08))


def build_steal() -> np.ndarray:
    """Playful descending 'whoop' for a steal (~0.7s)."""
    g = glide(700, 260, 0.55, "sine")
    vib = 1 + 0.06 * np.sin(2 * np.pi * 9 * _t(0.55))
    tone = g * vib * adsr(g.size, a=0.01, d=0.1, s=0.7, r=0.3)
    return norm(pad(tone, tail=0.1), 0.8)


def build_reveal() -> np.ndarray:
    """Soft neutral 'time up, here it is' chime (~0.8s)."""
    out = bell(NOTE["A4"], 0.7) * 0.7 + bell(NOTE["D5"], 0.7) * 0.6
    return norm(pad(out, tail=0.1), 0.75)


def build_halftime() -> np.ndarray:
    """Referee-style whistle trill for halftime (~0.9s)."""
    base = sine(2600, 0.8)
    trill = 1 + 0.5 * np.sin(2 * np.pi * 18 * _t(0.8))
    air = lowpass(noise(0.8), 4000) * 0.15
    tone = (base * trill + air) * adsr(base.size, a=0.02, d=0.05, s=0.9, r=0.2)
    return norm(pad(tone, tail=0.1), 0.7)


def build_winner() -> np.ndarray:
    """Triumphant winner fanfare (~2.4s)."""
    seq = [("C5", 0.25), ("E5", 0.25), ("G5", 0.25), ("C6", 1.0)]
    out = np.array([])
    for nm, d in seq:
        base = NOTE[nm]
        tone = (saw(base, d) * 0.35 + 0.6 * bell(base, d))
        tone = lowpass(tone, 3200) * adsr(tone.size, a=0.02, d=0.12, s=0.8, r=0.2)
        out = np.concatenate([out, tone])
    sparkle = np.zeros(int(SR * 1.0))
    for nm in ("C6", "E6", "G6"):
        s = bell(NOTE[nm], 0.9) * 0.3
        sparkle[: s.size] += s
    out = np.concatenate([out[: -sparkle.size], out[-sparkle.size:] + sparkle])
    return norm(pad(out, tail=0.15), 0.9)


def build_applause() -> np.ndarray:
    """Crowd applause — shaped noise with a swell and flutter (~2.6s)."""
    n = noise(2.5)
    n = lowpass(n, 5500) - lowpass(n, 700)  # band-ish
    flutter = 1 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * _t(2.5)))
    swell = np.concatenate([
        np.linspace(0.2, 1.0, int(SR * 0.4)),
        np.full(int(SR * 1.7), 1.0),
        np.linspace(1.0, 0.0, int(SR * 0.4)),
    ])
    swell = swell[: n.size]
    return norm(pad(n * flutter * swell, tail=0.1), 0.75)


def build_cheer() -> np.ndarray:
    """Brighter crowd cheer (applause + a rising 'yeah' band) (~2.6s)."""
    app = build_applause() * 0.8
    rise = lowpass(noise(0.8), 1800) - lowpass(noise(0.8), 500)
    rise *= np.linspace(0.2, 1.0, rise.size)
    yeah = np.zeros_like(app)
    yeah[: rise.size] += rise * 0.5
    return norm(app + yeah, 0.8)


def build_alert() -> np.ndarray:
    """Disconnect ALERT — urgent alternating alarm beeps, loopable (~1.6s)."""
    out = np.array([])
    for _ in range(4):
        a = square(880, 0.16) * adsr(int(SR * 0.16), a=0.005, d=0.02, s=0.9, r=0.02)
        b = square(660, 0.16) * adsr(int(SR * 0.16), a=0.005, d=0.02, s=0.9, r=0.02)
        gap = np.zeros(int(SR * 0.04))
        out = np.concatenate([out, a, gap, b, gap])
    return norm(out * 0.6, 0.8)


def build_awooga() -> np.ndarray:
    """AWOOGA klaxon horn — descending sawtooth glides, twice (~1.6s)."""
    out = np.array([])
    for _ in range(2):
        up = glide(180, 520, 0.18, "saw")
        hold = saw(520, 0.12)
        down = glide(520, 170, 0.42, "saw")
        horn = np.concatenate([up, hold, down])
        horn = lowpass(horn, 2200) * adsr(horn.size, a=0.02, d=0.05, s=0.9, r=0.1)
        out = np.concatenate([out, horn * 0.6, np.zeros(int(SR * 0.05))])
    return norm(out, 0.85)


CUES = {
    "theme": build_theme,
    "announcer_intro": build_announcer_intro,
    "round_start": build_round_start,
    "correct": build_correct,
    "steal": build_steal,
    "reveal": build_reveal,
    "halftime": build_halftime,
    "winner": build_winner,
    "applause": build_applause,
    "cheer": build_cheer,
    "alert": build_alert,
    "awooga": build_awooga,
}


# --- encode ------------------------------------------------------------------

def _ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception as err:  # pragma: no cover
        raise SystemExit("ffmpeg not found (install ffmpeg or imageio-ffmpeg)") from err


def _write_wav(path: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack("<%dh" % data.size, *data.tolist()))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "voice"), exist_ok=True)
    ff = _ffmpeg()
    np.random.seed(20260711)  # deterministic renders
    for name, build in CUES.items():
        audio = build().astype(np.float32)
        wav = os.path.join(OUT_DIR, name + ".wav")
        mp3 = os.path.join(OUT_DIR, name + ".mp3")
        _write_wav(wav, audio)
        subprocess.run(
            [ff, "-y", "-loglevel", "error", "-i", wav,
             "-codec:a", "libmp3lame", "-b:a", "128k", mp3],
            check=True,
        )
        os.remove(wav)
        secs = audio.size / SR
        print(f"  {name+'.mp3':22s} {secs:4.1f}s  {os.path.getsize(mp3)//1024:4d} KB")
    print(f"wrote {len(CUES)} cues to {os.path.normpath(OUT_DIR)}")


if __name__ == "__main__":
    main()
