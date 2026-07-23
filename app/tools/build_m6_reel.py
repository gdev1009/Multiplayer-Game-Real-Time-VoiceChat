#!/usr/bin/env python3
"""Stitch the captured Milestone 6 (host + audio) frames into a captioned
MP4 + GIF reel — same branded style as the M3->M5 journey reel."""
import glob
import os
from PIL import Image, ImageChops, ImageDraw, ImageFont
import imageio.v2 as imageio
import numpy as np

SRC = os.environ.get("M6_FRAMES", "/tmp/m6_frames")
OUT_DIR = ("/home/dev/Downloads/Multiplayer-Game-Real-Time-VoiceChat/"
           "docs/screenshots/milestone6")
os.makedirs(OUT_DIR, exist_ok=True)

# Brand tokens
PURPLE = (91, 45, 142)
PURPLE_DARK = (59, 26, 99)
GOLD = (212, 164, 49)
WHITE = (255, 255, 255)

APP_W, APP_H = 552, 660        # cropped app region (white margin trimmed)
PAD_X = 24
HEADER_H = 74
CAPTION_H = 116
CANVAS_W = APP_W + PAD_X * 2
CANVAS_H = HEADER_H + APP_H + CAPTION_H
VW = (CANVAS_W + 15) // 16 * 16
VH = (CANVAS_H + 15) // 16 * 16


def font(sz, bold=False):
    p = ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
         else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()


F_TITLE = font(26, bold=True)
F_CHIP = font(18, bold=True)
F_CAP = font(23, bold=True)
F_SUB = font(18)

# frame key -> (caption, subtitle)
SCENES = {
    "01_kickoff": ("Guy Smiley takes the stage",
                   "Theme music + announcer intro open every game"),
    "02_sound_settings": ("Sound, your way",
                          "Big mute switch and music / effects volume"),
    "03_correct_celebration": ("\u201cNice work!\u201d",
                               "Cheer + host voice on every correct guess"),
    "04_disconnect_alarm": ("Disconnect alarm",
                            "Red flash + ALERT horn when a player drops"),
    "05_halftime": ("Halftime fanfare",
                    "The host calls the role switch and the score"),
}

CHIP = (91, 45, 142)
CHIP_LABEL = "M6 \u00b7 Host & Audio"


def vgradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=(
            int(top[0] + (bot[0] - top[0]) * t),
            int(top[1] + (bot[1] - top[1]) * t),
            int(top[2] + (bot[2] - top[2]) * t),
        ))
    return base


def crop_app(fp):
    """Load a raw capture, crop tightly to the rendered content (trimming the
    white right/bottom margins the Flutter web canvas leaves), then fit it into
    the fixed app region on a matching background so nothing is distorted."""
    img = Image.open(fp).convert("RGB")
    bg = Image.new("RGB", img.size, (255, 255, 255))
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Fit (contain) into APP_W x APP_H, centred on a cream card colour.
    target = Image.new("RGB", (APP_W, APP_H), (248, 244, 236))
    scale = min(APP_W / img.width, APP_H / img.height)
    nw, nh = int(img.width * scale), int(img.height * scale)
    img = img.resize((nw, nh))
    target.paste(img, ((APP_W - nw) // 2, (APP_H - nh) // 2))
    return target


def compose(fp):
    key = os.path.splitext(os.path.basename(fp))[0]
    cap, sub = SCENES[key]
    canvas = vgradient(VW, VH, PURPLE, PURPLE_DARK)
    d = ImageDraw.Draw(canvas)
    ox = (VW - CANVAS_W) // 2
    oy = (VH - CANVAS_H) // 2

    d.text((ox + PAD_X, oy + 22), "Match Word", font=F_TITLE, fill=WHITE)
    tb = d.textbbox((0, 0), CHIP_LABEL, font=F_CHIP)
    cw, ch = tb[2] - tb[0], tb[3] - tb[1]
    chip_w = cw + 28
    chip_x1 = ox + CANVAS_W - PAD_X - chip_w
    chip_y0 = oy + 20
    d.rounded_rectangle([chip_x1, chip_y0, chip_x1 + chip_w, chip_y0 + ch + 16],
                        radius=16, fill=CHIP)
    d.text((chip_x1 + 14, chip_y0 + 8), CHIP_LABEL, font=F_CHIP, fill=WHITE)

    app = crop_app(fp)
    ax, ay = ox + PAD_X, oy + HEADER_H
    d.rounded_rectangle([ax - 3, ay + 6, ax + APP_W + 3, ay + APP_H + 8],
                        radius=20, fill=(40, 18, 70))
    mask = Image.new("L", (APP_W, APP_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, APP_W, APP_H], radius=18, fill=255)
    canvas.paste(app, (ax, ay), mask)

    cy = oy + HEADER_H + APP_H + 14
    d.text((ox + PAD_X, cy), cap, font=F_CAP, fill=WHITE)
    d.text((ox + PAD_X, cy + 34), sub, font=F_SUB, fill=(226, 214, 240))
    d.rounded_rectangle([ox + PAD_X, cy - 12, ox + PAD_X + 46, cy - 8],
                        radius=3, fill=GOLD)
    return canvas


files = [f for f in sorted(glob.glob(f"{SRC}/*.png"))
         if os.path.splitext(os.path.basename(f))[0] in SCENES]
frames = [compose(f) for f in files]
print(f"composed {len(frames)} scene frames at {VW}x{VH}")

for f, img in zip(files, frames):
    name = os.path.splitext(os.path.basename(f))[0]
    img.save(f"{OUT_DIR}/scene_{name}.png")

FPS = 25
HOLD = int(3.0 * FPS)
XF = 8
seq = []
for i, img in enumerate(frames):
    cur = img.convert("RGB")
    if i > 0 and XF > 0:
        prev = frames[i - 1].convert("RGB")
        for k in range(1, XF + 1):
            seq.append(Image.blend(prev, cur, k / (XF + 1)))
    seq.extend([cur] * HOLD)

mp4_path = f"{OUT_DIR}/match-word-host-audio.mp4"
w = imageio.get_writer(mp4_path, fps=FPS, codec="libx264",
                       macro_block_size=None, pixelformat="yuv420p", quality=8)
for im in seq:
    w.append_data(np.asarray(im))
w.close()
print("wrote", mp4_path, "frames:", len(seq))

gif_scale = 0.62
gif_frames = [img.convert("RGB").resize((int(VW * gif_scale), int(VH * gif_scale)))
              for img in frames]
gif_path = f"{OUT_DIR}/match-word-host-audio.gif"
gif_frames[0].save(gif_path, save_all=True, append_images=gif_frames[1:],
                   duration=1600, loop=0, optimize=True)
print("wrote", gif_path)
print("done ->", OUT_DIR)
