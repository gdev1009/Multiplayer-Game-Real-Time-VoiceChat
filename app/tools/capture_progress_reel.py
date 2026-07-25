#!/usr/bin/env python3
"""Capture autoplay scenes from demo_progress web build into captioned frames,
then stitch mp4/gif under docs/screenshots/progress/.

Prereq:
  cd app
  flutter build web -t lib/demo_progress.dart --no-tree-shake-icons
  python3 -m http.server 8092 --directory build/web   # in background

Or this script starts the server itself if --serve is passed.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
OUT_DIR = ROOT / "docs" / "screenshots" / "progress"
RAW = Path(os.environ.get("PROGRESS_FRAMES", "/tmp/progress_frames"))
URL = os.environ.get("PROGRESS_URL", "http://127.0.0.1:8092")

SCENES = [
    ("01_home_idle", "M7", "Home with Rosie", "Idle poses bring characters to life"),
    ("02_prize_room", "M8", "Prize Room", "Trophies and novelty prizes on the shelf"),
    ("03_lobby_filled", "M4", "Game Room", "Studio teammates fill the seats"),
    ("04_play_kickoff", "M6", "Lights, camera…", "Guy Smiley opens the show"),
    ("05_play_clue", "M5", "The clue is in", "One word — then a teammate guesses"),
    ("06_play_score", "M5", "Points on the board", "Scores move as the game unfolds"),
    ("07_halftime", "M5", "Halftime!", "Teams switch roles for the second half"),
    ("08_winner", "M5", "We have a winner!", "Clay characters celebrate the finish"),
    (
        "09_subscription_paywall",
        "M8",
        "5-day free trial + subscription",
        "$5.99/month after trial — cancel anytime",
    ),
]

CHIP = {
    "M4": (212, 164, 49),
    "M5": (91, 45, 142),
    "M6": (91, 45, 142),
    "M7": (123, 79, 176),
    "M8": (212, 164, 49),
}


def capture_with_chrome() -> None:
    from PIL import Image

    RAW.mkdir(parents=True, exist_ok=True)
    # Use Chrome DevTools Protocol via a short Node puppeteer script if
    # available; else screenshot via chromium headless once per wait.
    script = r"""
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
(async () => {
  const url = process.env.PROGRESS_URL || 'http://127.0.0.1:8092';
  const out = process.env.PROGRESS_FRAMES || '/tmp/progress_frames';
  fs.mkdirSync(out, { recursive: true });
  // Flutter web (CanvasKit) needs WebGL. --disable-gpu leaves Image.asset
  // bitmaps blank while text/boxes still paint — that was why Team A/B busts,
  // Guy Smiley, and Rosie never showed in the progress reel.
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/usr/bin/google-chrome',
    headless: 'new',
    args: [
      '--no-sandbox',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--window-size=420,900',
    ],
    defaultViewport: { width: 420, height: 860, deviceScaleFactor: 2 },
  });
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 120000 });
  await page.waitForFunction(() => (document.title || '').includes('PROGRESS_SCENE:'), { timeout: 90000 });
  // Let CanvasKit finish decoding the first wave of character PNGs.
  await new Promise(r => setTimeout(r, 4000));
  const wanted = %SCENES%;
  const seen = new Set();
  const deadline = Date.now() + 180000;
  while (seen.size < wanted.length && Date.now() < deadline) {
    const title = await page.title();
    const m = title.match(/PROGRESS_SCENE:([a-z0-9_]+)/);
    if (m && wanted.includes(m[1]) && !seen.has(m[1])) {
      await new Promise(r => setTimeout(r, 2800));
      const file = path.join(out, m[1] + '.png');
      await page.screenshot({ path: file, type: 'png' });
      seen.add(m[1]);
      console.log('captured', m[1], 'title=', title);
    }
    await new Promise(r => setTimeout(r, 300));
  }
  console.log('done', [...seen].join(','));
  await browser.close();
  if (seen.size < wanted.length) process.exit(2);
})().catch(e => { console.error(e); process.exit(1); });
""".replace("%SCENES%", repr([s[0] for s in SCENES]))

    js_path = Path("/tmp/capture_progress.js")
    js_path.write_text(script)
    # Ensure puppeteer-core
    subprocess.run(
        ["npm", "install", "--no-save", "puppeteer-core@23"],
        cwd="/tmp",
        check=False,
        capture_output=True,
    )
    env = os.environ.copy()
    env["PROGRESS_URL"] = URL
    env["PROGRESS_FRAMES"] = str(RAW)
    env["CHROME"] = shutil.which("google-chrome") or "/usr/bin/google-chrome"
    r = subprocess.run(["node", str(js_path)], env=env, cwd="/tmp")
    if r.returncode != 0:
        raise SystemExit(f"capture failed ({r.returncode})")
    # touch import so Image is “used”
    _ = Image


def compose_and_stitch() -> None:
    import imageio.v2 as imageio
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PURPLE = (91, 45, 142)
    PURPLE_DARK = (59, 26, 99)
    GOLD = (212, 164, 49)
    WHITE = (255, 255, 255)
    APP_W, APP_H = 552, 745
    PAD_X = 24
    HEADER_H = 74
    CAPTION_H = 116
    CANVAS_W = APP_W + PAD_X * 2
    CANVAS_H = HEADER_H + APP_H + CAPTION_H
    VW = (CANVAS_W + 15) // 16 * 16
    VH = (CANVAS_H + 15) // 16 * 16

    def font(sz, bold=False):
        p = (
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
            if bold
            else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        )
        return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()

    F_TITLE = font(26, True)
    F_CHIP = font(18, True)
    F_CAP = font(23, True)
    F_SUB = font(18)

    def vgradient(w, h, top, bot):
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

    frames = []
    for key, ms, cap, sub in SCENES:
        fp = RAW / f"{key}.png"
        if not fp.is_file():
            raise SystemExit(f"missing capture: {fp}")
        canvas = vgradient(VW, VH, PURPLE, PURPLE_DARK)
        d = ImageDraw.Draw(canvas)
        ox = (VW - CANVAS_W) // 2
        oy = (VH - CANVAS_H) // 2
        d.text((ox + PAD_X, oy + 22), "Match Word", font=F_TITLE, fill=WHITE)
        chip_txt = f"{ms} · Current"
        tb = d.textbbox((0, 0), chip_txt, font=F_CHIP)
        cw, ch = tb[2] - tb[0], tb[3] - tb[1]
        chip_w = cw + 28
        chip_x1 = ox + CANVAS_W - PAD_X - chip_w
        d.rounded_rectangle(
            [chip_x1, oy + 20, chip_x1 + chip_w, oy + 20 + ch + 16],
            radius=16,
            fill=CHIP.get(ms, PURPLE),
        )
        d.text((chip_x1 + 14, oy + 28), chip_txt, font=F_CHIP, fill=WHITE)
        app = Image.open(fp).convert("RGB")
        app = app.resize((APP_W, APP_H), Image.Resampling.LANCZOS)
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
        d.text((ox + PAD_X, cy), cap, font=F_CAP, fill=WHITE)
        d.text((ox + PAD_X, cy + 34), sub, font=F_SUB, fill=(226, 214, 240))
        d.rounded_rectangle(
            [ox + PAD_X, cy - 12, ox + PAD_X + 46, cy - 8], radius=3, fill=GOLD
        )
        composed = OUT_DIR / f"scene_{key}.png"
        canvas.save(composed)
        frames.append(canvas)
        print("composed", composed)

    FPS, HOLD, XF = 25, int(2.8 * 25), 8
    seq = []
    for i, img in enumerate(frames):
        cur = img.convert("RGB")
        if i > 0:
            prev = frames[i - 1].convert("RGB")
            for k in range(1, XF + 1):
                seq.append(Image.blend(prev, cur, k / (XF + 1)))
        seq.extend([cur] * HOLD)

    mp4 = OUT_DIR / "match-word-progress-m3-m8.mp4"
    w = imageio.get_writer(
        str(mp4), fps=FPS, codec="libx264", macro_block_size=None,
        pixelformat="yuv420p", quality=8,
    )
    for im in seq:
        w.append_data(np.asarray(im))
    w.close()
    print("wrote", mp4)

    gif_frames = [f.resize((int(VW * 0.55), int(VH * 0.55))) for f in frames]
    gif = OUT_DIR / "match-word-progress-m3-m8.gif"
    gif_frames[0].save(
        gif, save_all=True, append_images=gif_frames[1:],
        duration=1400, loop=0, optimize=True,
    )
    print("wrote", gif)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-capture", action="store_true")
    ap.add_argument("--serve", action="store_true", help="start http.server 8092")
    args = ap.parse_args()
    server = None
    if args.serve:
        server = subprocess.Popen(
            [sys.executable, "-m", "http.server", "8092", "--directory", str(APP / "build" / "web")],
            cwd=str(APP),
        )
        time.sleep(1.5)
    try:
        if not args.skip_capture:
            capture_with_chrome()
        compose_and_stitch()
    finally:
        if server:
            server.terminate()


if __name__ == "__main__":
    main()
