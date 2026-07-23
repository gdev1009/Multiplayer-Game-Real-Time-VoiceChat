#!/usr/bin/env python3
"""Stitch latest store full-journey captures into a captioned client reel.

Prereq:
  python3 tools/capture_store_screenshots.py --serve
  (after: flutter build web -t lib/demo_store_screens.dart --no-tree-shake-icons)

Outputs:
  docs/screenshots/store/match-word-latest-studio.mp4
  docs/screenshots/store/match-word-latest-studio.gif
  screenshots/match-word-latest-studio.mp4  (easy drop for Freelancer)
"""
from __future__ import annotations

import shutil
from pathlib import Path

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "docs" / "screenshots" / "store" / "full-journey"
OUT_DIR = ROOT / "docs" / "screenshots" / "store"
DROP = ROOT / "screenshots"
PACKAGE = ROOT / "docs" / "client-deliverables" / "m8-progress-package" / "videos"

PURPLE = (91, 45, 142)
PURPLE_DARK = (59, 26, 99)
GOLD = (212, 164, 49)
WHITE = (255, 255, 255)

APP_W, APP_H = 420, 860
PAD_X = 24
HEADER_H = 74
CAPTION_H = 116
CANVAS_W = APP_W + PAD_X * 2
CANVAS_H = HEADER_H + APP_H + CAPTION_H
VW = (CANVAS_W + 15) // 16 * 16
VH = (CANVAS_H + 15) // 16 * 16

# Focus on the studio-first pass Ronna is waiting on, plus the surrounding journey.
SCENES = [
    ("05_opening_home", "Home stage", "Clay characters ready for the show"),
    ("06_character_builder", "Build your look", "Larger, higher-contrast senior-friendly faces"),
    ("08_studio", "Enter the Studio", "Invite friends and fill every seat"),
    ("10_lobby_room", "Game room ready", "Four players, two teams, one host"),
    ("11_play_kickoff", "Guy Smiley opens", "Welcome-wave host GIF + studio seats"),
    ("12_play_clue", "One-word clues", "Bubbles sit by each mouth — no host caption"),
    ("12b_play_bubbles", "Wrong / steal beat", "Red-flag host GIF + clear wrong bubbles"),
    ("13_play_winner", "We have a winner!", "Winner-announce pose ends the match"),
    ("14_prize_room", "Trophies & prizes", "Shelf rewards after you play"),
]


def _font(sz: int, bold: bool = False) -> ImageFont.ImageFont:
    p = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    )
    return ImageFont.truetype(p, sz) if Path(p).exists() else ImageFont.load_default()


def _gradient(w: int, h: int, top: tuple, bot: tuple) -> Image.Image:
    base = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line(
            [(0, y), (w, y)],
            fill=(
                int(top[0] + (bot[0] - top[0]) * t),
                int(top[1] + (bot[1] - top[1]) * t),
                int(top[2] + (bot[2] - top[2]) * t),
            ),
        )
    return base


def compose(key: str, cap: str, sub: str) -> Image.Image:
    fp = RAW / f"{key}.png"
    if not fp.is_file():
        raise SystemExit(f"missing capture: {fp}")

    f_title = _font(26, True)
    f_chip = _font(18, True)
    f_cap = _font(23, True)
    f_sub = _font(18)

    canvas = _gradient(VW, VH, PURPLE, PURPLE_DARK)
    d = ImageDraw.Draw(canvas)
    ox = (VW - CANVAS_W) // 2
    oy = (VH - CANVAS_H) // 2

    d.text((ox + PAD_X, oy + 22), "Match Word", font=f_title, fill=WHITE)
    chip = "Studio pass"
    tb = d.textbbox((0, 0), chip, font=f_chip)
    cw, ch = tb[2] - tb[0], tb[3] - tb[1]
    chip_w = cw + 28
    chip_x1 = ox + CANVAS_W - PAD_X - chip_w
    d.rounded_rectangle(
        [chip_x1, oy + 20, chip_x1 + chip_w, oy + 20 + ch + 16],
        radius=16,
        fill=GOLD,
    )
    d.text((chip_x1 + 14, oy + 28), chip, font=f_chip, fill=PURPLE_DARK)

    app = Image.open(fp).convert("RGB").resize((APP_W, APP_H), Image.Resampling.LANCZOS)
    ax, ay = ox + PAD_X, oy + HEADER_H
    d.rounded_rectangle(
        [ax - 3, ay + 6, ax + APP_W + 3, ay + APP_H + 8],
        radius=20,
        fill=(40, 18, 70),
    )
    mask = Image.new("L", (APP_W, APP_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, APP_W, APP_H], radius=18, fill=255)
    canvas.paste(app, (ax, ay), mask)

    cy = oy + HEADER_H + APP_H + 14
    d.text((ox + PAD_X, cy), cap, font=f_cap, fill=WHITE)
    d.text((ox + PAD_X, cy + 34), sub, font=f_sub, fill=(226, 214, 240))
    d.rounded_rectangle(
        [ox + PAD_X, cy - 12, ox + PAD_X + 46, cy - 8], radius=3, fill=GOLD
    )
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    DROP.mkdir(parents=True, exist_ok=True)
    PACKAGE.mkdir(parents=True, exist_ok=True)

    frames = []
    for key, cap, sub in SCENES:
        img = compose(key, cap, sub)
        scene_path = OUT_DIR / f"reel_scene_{key}.png"
        img.save(scene_path)
        frames.append(img)
        print("composed", scene_path.name)

    fps, hold, xf = 25, int(2.8 * 25), 8
    seq: list[Image.Image] = []
    for i, img in enumerate(frames):
        cur = img.convert("RGB")
        if i > 0:
            prev = frames[i - 1].convert("RGB")
            for k in range(1, xf + 1):
                seq.append(Image.blend(prev, cur, k / (xf + 1)))
        seq.extend([cur] * hold)

    mp4 = OUT_DIR / "match-word-latest-studio.mp4"
    writer = imageio.get_writer(
        str(mp4),
        fps=fps,
        codec="libx264",
        macro_block_size=None,
        pixelformat="yuv420p",
        quality=8,
    )
    for im in seq:
        writer.append_data(np.asarray(im))
    writer.close()
    print("wrote", mp4, "frames", len(seq))

    gif_frames = [
        f.resize((int(VW * 0.55), int(VH * 0.55)), Image.Resampling.LANCZOS)
        for f in frames
    ]
    gif = OUT_DIR / "match-word-latest-studio.gif"
    gif_frames[0].save(
        gif,
        save_all=True,
        append_images=gif_frames[1:],
        duration=1400,
        loop=0,
        optimize=True,
    )
    print("wrote", gif)

    for dest_dir in (DROP, PACKAGE):
        shutil.copy2(mp4, dest_dir / mp4.name)
        shutil.copy2(gif, dest_dir / gif.name)
        print("copied ->", dest_dir)


if __name__ == "__main__":
    main()
