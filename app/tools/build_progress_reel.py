#!/usr/bin/env python3
"""Combine existing captioned M3–M5 journey + M6 host/audio frames into one
client-facing progress reel (mp4 + gif). Frames are already branded — do not
double-caption."""
from __future__ import annotations

import os
from pathlib import Path

import imageio.v2 as imageio
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
JOURNEY = ROOT / "docs" / "screenshots" / "journey"
M6 = ROOT / "docs" / "screenshots" / "milestone6"
OUT_DIR = ROOT / "docs" / "screenshots" / "progress"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Target canvas = journey size (letterbox shorter M6 frames).
VW, VH = 608, 944
PURPLE_DARK = (59, 26, 99)

JOURNEY_SCENES = [
    "scene_01_home.png",
    "scene_02_char_body.png",
    "scene_03_char_hair.png",
    "scene_04_char_outfit.png",
    "scene_05_char_accessories.png",
    "scene_06_char_final.png",
    "scene_07_home_saved.png",
    "scene_08_upcoming.png",
    "scene_09_lobby_countdown.png",
    "scene_10_lobby_filled.png",
    "scene_11_play_turn.png",
    "scene_12_play_clue.png",
    "scene_13_play_score.png",
    "scene_14_halftime.png",
    "scene_15_second_half.png",
    "scene_16_winner.png",
]

M6_SCENES = [
    "scene_01_kickoff.png",
    "scene_02_sound_settings.png",
    "scene_03_correct_celebration.png",
    "scene_04_disconnect_alarm.png",
    "scene_05_halftime.png",
]


def letterbox(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGB")
    if img.size == (VW, VH):
        return img
    canvas = Image.new("RGB", (VW, VH), PURPLE_DARK)
    w, h = img.size
    scale = min(VW / w, VH / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    ox, oy = (VW - nw) // 2, (VH - nh) // 2
    canvas.paste(resized, (ox, oy))
    return canvas


def main() -> None:
    paths = [JOURNEY / n for n in JOURNEY_SCENES] + [M6 / n for n in M6_SCENES]
    missing = [str(p) for p in paths if not p.is_file()]
    if missing:
        raise SystemExit(f"missing frames:\n" + "\n".join(missing))

    frames = [letterbox(p) for p in paths]
    print(f"loaded {len(frames)} captioned frames at {VW}x{VH}")

    FPS = 25
    HOLD = int(2.6 * FPS)
    XF = 8
    seq: list[Image.Image] = []
    for i, img in enumerate(frames):
        cur = img
        if i > 0 and XF > 0:
            prev = frames[i - 1]
            for k in range(1, XF + 1):
                seq.append(Image.blend(prev, cur, k / (XF + 1)))
        seq.extend([cur] * HOLD)

    mp4_path = OUT_DIR / "match-word-progress-m3-m6.mp4"
    writer = imageio.get_writer(
        str(mp4_path),
        fps=FPS,
        codec="libx264",
        macro_block_size=None,
        pixelformat="yuv420p",
        quality=8,
    )
    for im in seq:
        writer.append_data(np.asarray(im))
    writer.close()
    print("wrote", mp4_path, "video_frames:", len(seq))

    gif_scale = 0.55
    gw, gh = int(VW * gif_scale), int(VH * gif_scale)
    gif_frames = [img.resize((gw, gh)) for img in frames]
    gif_path = OUT_DIR / "match-word-progress-m3-m6.gif"
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=1300,
        loop=0,
        optimize=True,
    )
    print("wrote", gif_path)
    print("done ->", OUT_DIR)


if __name__ == "__main__":
    main()
