#!/usr/bin/env python3
"""Capture full-journey store screenshots from demo_store_screens web build.

Prereq:
  cd app
  flutter build web -t lib/demo_store_screens.dart --no-tree-shake-icons
  python3 tools/capture_store_screenshots.py --serve

Outputs:
  docs/screenshots/store/full-journey/     raw phone captures
  docs/screenshots/store/app-store/        1290×2796 App Store frames
  docs/screenshots/store/play-store/       1080×1920 Play Store frames
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
OUT = ROOT / "docs" / "screenshots" / "store"
RAW = OUT / "full-journey"
APP_STORE = OUT / "app-store"
PLAY_STORE = OUT / "play-store"
URL = os.environ.get("STORE_URL", "http://127.0.0.1:8093")
RAW_TMP = Path(os.environ.get("STORE_FRAMES", str(RAW)))

# key, store headline, store subtitle
SCENES = [
    ("01_welcome", "Welcome to Match Word", "A friendly social word game for everyone"),
    ("02_create_account", "Create your account", "Sign up in seconds with email"),
    ("03_daily_login", "Welcome back", "Quick daily login keeps you in the game"),
    ("04_email_sign_in", "Sign in securely", "Your account syncs across devices"),
    ("05_opening_home", "Your home stage", "Clay characters come alive on the couch"),
    ("06_character_builder", "Build your look", "Mix hair, outfits, glasses, and more"),
    ("07_upcoming_games", "Find a match", "Browse open games or start your own"),
    ("08_studio", "The Studio", "Invite friends and fill every seat"),
    ("09_join_by_code", "Join by code", "Enter a four-digit room code from a friend"),
    ("10_lobby_room", "Game room ready", "Four players, two teams, one host"),
    ("11_play_kickoff", "Lights, camera…", "Guy Smiley opens the show"),
    ("12_play_clue", "One word clues", "Give a hint — teammates guess the secret"),
    ("12b_play_bubbles", "Everyone speaks", "Clues and guesses appear beside each player"),
    ("13_play_winner", "We have a winner!", "Celebrate with clay characters"),
    ("14_prize_room", "Trophies & prizes", "Earn shelf items as you play"),
    ("15_paywall", "5-day free trial", "Then $5.99/month — cancel anytime"),
    ("16_friends", "Play with friends", "Requests, invites, and your crew"),
]


def capture_with_chrome() -> None:
    from PIL import Image  # noqa: F401

    RAW_TMP.mkdir(parents=True, exist_ok=True)
    script = r"""
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
(async () => {
  const url = process.env.STORE_URL || 'http://127.0.0.1:8093';
  const out = process.env.STORE_FRAMES || '/tmp/store_frames';
  fs.mkdirSync(out, { recursive: true });
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
  await page.waitForFunction(() => (document.title || '').includes('STORE_SCENE:'), { timeout: 90000 });
  await new Promise(r => setTimeout(r, 4500));
  const wanted = %SCENES%;
  const seen = new Set();
  const deadline = Date.now() + 240000;
  while (seen.size < wanted.length && Date.now() < deadline) {
    const title = await page.title();
    const m = title.match(/STORE_SCENE:([a-z0-9_]+)/);
    if (m && wanted.includes(m[1]) && !seen.has(m[1])) {
      await new Promise(r => setTimeout(r, 3200));
      const file = path.join(out, m[1] + '.png');
      await page.screenshot({ path: file, type: 'png' });
      seen.add(m[1]);
      console.log('captured', m[1]);
    }
    await new Promise(r => setTimeout(r, 300));
  }
  console.log('done', [...seen].join(','));
  await browser.close();
  if (seen.size < wanted.length) process.exit(2);
})().catch(e => { console.error(e); process.exit(1); });
""".replace("%SCENES%", repr([s[0] for s in SCENES]))

    js_path = Path("/tmp/capture_store.js")
    js_path.write_text(script)
    subprocess.run(
        ["npm", "install", "--no-save", "puppeteer-core@23"],
        cwd="/tmp",
        check=False,
        capture_output=True,
    )
    env = os.environ.copy()
    env["STORE_URL"] = URL
    env["STORE_FRAMES"] = str(RAW_TMP)
    env["CHROME"] = shutil.which("google-chrome") or "/usr/bin/google-chrome"
    r = subprocess.run(["node", str(js_path)], env=env, cwd="/tmp")
    if r.returncode != 0:
        raise SystemExit(f"capture failed ({r.returncode})")


def _font(sz: int, bold: bool = False):
    from PIL import ImageFont

    p = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    )
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()


def _gradient(w: int, h: int, top: tuple, bot: tuple):
    from PIL import Image, ImageDraw

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


def _paste_phone(canvas, app_img, cx: int, cy: int, pw: int, ph: int):
    from PIL import Image, ImageDraw

    app = app_img.convert("RGB").resize((pw, ph), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(
        [cx - 6, cy + 10, cx + pw + 6, cy + ph + 14],
        radius=36,
        fill=(40, 18, 70),
    )
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw, ph], radius=32, fill=255)
    canvas.paste(app, (cx, cy), mask)
    return canvas


def compose_store_frames() -> None:
    from PIL import Image, ImageDraw

    PURPLE = (91, 45, 142)
    PURPLE_DARK = (59, 26, 99)
    GOLD = (212, 164, 49)
    WHITE = (255, 255, 255)
    MUTED = (226, 214, 240)

    APP_STORE.mkdir(parents=True, exist_ok=True)
    PLAY_STORE.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)

    # Copy raw captures into full-journey (when capture used a temp dir)
    for key, _, _ in SCENES:
        src = RAW_TMP / f"{key}.png"
        if not src.is_file():
            raise SystemExit(f"missing capture: {src}")
        dst = RAW / f"{key}.png"
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
        print("raw", dst)

    # App Store — iPhone 6.7" portrait
    AS_W, AS_H = 1290, 2796
    F_BRAND = _font(44, True)
    F_HEAD = _font(72, True)
    F_SUB = _font(38)
    PH_W, PH_H = 1000, 1620
    for i, (key, headline, sub) in enumerate(SCENES, start=1):
        fp = RAW_TMP / f"{key}.png"
        canvas = _gradient(AS_W, AS_H, PURPLE, PURPLE_DARK)
        d = ImageDraw.Draw(canvas)
        d.text((80, 120), "Match Word", font=F_BRAND, fill=GOLD)
        d.text((80, 220), headline, font=F_HEAD, fill=WHITE)
        # wrap-ish: truncate long subs
        d.text((80, 320), sub, font=F_SUB, fill=MUTED)
        d.rounded_rectangle([80, 300, 180, 308], radius=3, fill=GOLD)
        px = (AS_W - PH_W) // 2
        py = 420
        _paste_phone(canvas, Image.open(fp), px, py, PH_W, PH_H)
        out = APP_STORE / f"{key}_1290x2796.png"
        canvas.save(out)
        print("app-store", out)

    # Play Store — phone portrait 1080×1920
    PS_W, PS_H = 1080, 1920
    F_HEAD_P = _font(58, True)
    F_SUB_P = _font(30)
    PH_W_P, PH_H_P = 860, 1390
    for i, (key, headline, sub) in enumerate(SCENES, start=1):
        fp = RAW_TMP / f"{key}.png"
        canvas = _gradient(PS_W, PS_H, PURPLE, PURPLE_DARK)
        d = ImageDraw.Draw(canvas)
        d.text((60, 80), "Match Word", font=_font(36, True), fill=GOLD)
        d.text((60, 150), headline, font=F_HEAD_P, fill=WHITE)
        d.text((60, 230), sub, font=F_SUB_P, fill=MUTED)
        px = (PS_W - PH_W_P) // 2
        py = 300
        _paste_phone(canvas, Image.open(fp), px, py, PH_W_P, PH_H_P)
        out = PLAY_STORE / f"{key}_1080x1920.png"
        canvas.save(out)
        print("play-store", out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-capture", action="store_true")
    ap.add_argument("--serve", action="store_true", help="start http.server 8093")
    args = ap.parse_args()
    server = None
    if args.serve:
        server = subprocess.Popen(
            [sys.executable, "-m", "http.server", "8093", "--directory", str(APP / "build" / "web")],
            cwd=str(APP),
        )
        time.sleep(1.5)
    try:
        if not args.skip_capture:
            capture_with_chrome()
        compose_store_frames()
    finally:
        if server:
            server.terminate()


if __name__ == "__main__":
    main()
