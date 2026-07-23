#!/usr/bin/env python3
"""Generate lipsync amplitude envelopes for host voice MP3s.

Writes `assets/audio/voice/envelopes/{stem}.json` plus `catalog.json`.

Without ffmpeg we synthesise a speech-like syllable curve from MP3 duration
(parsed from Xing/bitrate headers). Re-run after replacing voice clips:

    python3 tools/generate_voice_envelopes.py
"""

from __future__ import annotations

import json
import math
import os
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VOICE = ROOT / "assets" / "audio" / "voice"
OUT = VOICE / "envelopes"


def mp3_duration(path: Path) -> float:
    data = path.read_bytes()
    i = 0
    while i < len(data) - 4:
        if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0:
            break
        i += 1
    else:
        return os.path.getsize(path) * 8 / 128000

    br_table = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
    sr_table = [44100, 48000, 32000]
    b1, b2 = data[i + 1], data[i + 2]
    version = (b1 >> 3) & 3
    layer = (b1 >> 1) & 3
    br_idx = (b2 >> 4) & 0xF
    sr_idx = (b2 >> 2) & 3
    if version != 3 or layer != 1 or br_idx in (0, 15) or sr_idx == 3:
        return os.path.getsize(path) * 8 / 128000
    bitrate = br_table[br_idx] * 1000
    sr = sr_table[sr_idx]
    xing_off = i + 4 + 32
    if data[xing_off : xing_off + 4] in (b"Xing", b"Info"):
        flags = struct.unpack(">I", data[xing_off + 4 : xing_off + 8])[0]
        if flags & 1:
            frames = struct.unpack(">I", data[xing_off + 8 : xing_off + 12])[0]
            return frames * 1152 / sr
    return os.path.getsize(path) * 8 / bitrate


def speech_envelope(duration_s: float, hop_ms: int = 40, seed: int = 0) -> list[float]:
    rng = random.Random(seed)
    n = max(1, int(duration_s * 1000 / hop_ms))
    samples: list[float] = []
    while len(samples) < n:
        for _ in range(rng.randint(1, 3)):
            if len(samples) >= n:
                break
            samples.append(0.02)
        burst = rng.randint(3, 8)
        peak = rng.uniform(0.55, 1.0)
        for k in range(burst):
            if len(samples) >= n:
                break
            env = math.sin(math.pi * (k + 0.5) / burst) * peak
            flutter = 0.85 + 0.15 * math.sin(len(samples) * 0.9)
            samples.append(round(min(1.0, env * flutter), 3))
    fade = min(4, max(1, len(samples) // 8))
    for i in range(fade):
        samples[i] *= (i + 1) / fade
        samples[-1 - i] *= (i + 1) / fade
    return samples


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    catalog: dict[str, str] = {}
    for path in sorted(VOICE.glob("*.mp3")):
        dur = mp3_duration(path)
        samples = speech_envelope(dur, seed=hash(path.name) & 0xFFFF)
        payload = {
            "asset": f"audio/voice/{path.name}",
            "durationMs": int(dur * 1000),
            "hopMs": 40,
            "samples": samples,
        }
        out = OUT / f"{path.stem}.json"
        out.write_text(json.dumps(payload, separators=(",", ":")))
        catalog[path.stem] = f"audio/voice/envelopes/{path.stem}.json"
        print(f"{path.name} -> {out.name} ({dur:.2f}s, {len(samples)} bins)")
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")
    print("wrote", OUT / "catalog.json")


if __name__ == "__main__":
    main()
