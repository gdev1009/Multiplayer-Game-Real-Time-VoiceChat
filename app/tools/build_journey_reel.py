#!/usr/bin/env python3
"""Stitch the captured journey frames into a captioned MP4 + GIF reel."""
import glob
import os
from PIL import Image, ImageDraw, ImageFont
import imageio.v2 as imageio

SRC = os.environ.get("JOURNEY_FRAMES", "/tmp/journey_frames")
OUT_DIR = "/home/dev/Downloads/Multiplayer-Game-Real-Time-VoiceChat/docs/screenshots/journey"
os.makedirs(OUT_DIR, exist_ok=True)

# Brand tokens
PURPLE = (91, 45, 142)
PURPLE_DARK = (59, 26, 99)
GOLD = (212, 164, 49)
CREAM = (248, 244, 236)
WHITE = (255, 255, 255)

APP_W, APP_H = 552, 745
PAD_X = 24
HEADER_H = 74
CAPTION_H = 116
CANVAS_W = APP_W + PAD_X * 2            # 600
CANVAS_H = HEADER_H + APP_H + CAPTION_H  # 935
# pad to multiples of 16 for H.264
VW = (CANVAS_W + 15) // 16 * 16          # 608
VH = (CANVAS_H + 15) // 16 * 16          # 944


def font(sz, bold=False):
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


F_TITLE = font(26, bold=True)
F_CHIP = font(18, bold=True)
F_CAP = font(23, bold=True)
F_SUB = font(18)

# frame -> (milestone, caption, subtitle)
SCENES = {
    "01_home":            ("M3", "Meet Grandma Mac", "Sunny's warm, friendly home screen"),
    "02_char_body":       ("M3", "Character Studio", "Pick a body \u2014 auto-dressed, ready to go"),
    "03_char_hair":       ("M3", "Style the hair", "Hand-painted styles in soft silver"),
    "04_char_outfit":     ("M3", "Dress your character", "Real artwork, layered to fit perfectly"),
    "05_char_accessories":("M3", "Add the finishing touches", "Hats, glasses, earrings and a cane"),
    "06_char_final":      ("M3", "Looking great, Rosie!", "Name your character and save"),
    "07_upcoming":        ("M4", "Play a game", "Find a game, host, or join by code"),
    "08_lobby_countdown": ("M4", "Game Room", "Studio players join in a few seconds"),
    "09_lobby_filled":    ("M4", "Teams are set", "Four players across Team A and Team B"),
    "10_play_turn":       ("M5", "Match Word begins", "Sunny gives a one-word clue"),
    "11_play_clue":       ("M5", "The clue is in", "\u201cPetals\u201d \u2014 now teammates guess"),
    "12_play_score":      ("M5", "Correct \u2014 +5 points!", "Team A guessed \u201cFlower\u201d"),
}

CHIP_COLORS = {"M3": (123, 79, 176), "M4": (212, 164, 49), "M5": (91, 45, 142)}
CHIP_LABEL = {"M3": "M3 · Character", "M4": "M4 · Lobby", "M5": "M5 · Gameplay"}


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


def rounded(draw, box, r, fill):
    draw.rounded_rectangle(box, radius=r, fill=fill)


def compose(fp):
    key = os.path.splitext(os.path.basename(fp))[0]
    ms, cap, sub = SCENES[key]
    canvas = vgradient(VW, VH, PURPLE, PURPLE_DARK)
    d = ImageDraw.Draw(canvas)
    ox = (VW - CANVAS_W) // 2
    oy = (VH - CANVAS_H) // 2

    # Header title
    d.text((ox + PAD_X, oy + 22), "Match Word", font=F_TITLE, fill=WHITE)
    # milestone chip (right aligned in header)
    chip_txt = CHIP_LABEL[ms]
    tb = d.textbbox((0, 0), chip_txt, font=F_CHIP)
    cw, ch = tb[2] - tb[0], tb[3] - tb[1]
    chip_w = cw + 28
    chip_x1 = ox + CANVAS_W - PAD_X - chip_w
    chip_y0 = oy + 20
    rounded(d, [chip_x1, chip_y0, chip_x1 + chip_w, chip_y0 + ch + 16], 16, CHIP_COLORS[ms])
    d.text((chip_x1 + 14, chip_y0 + 8), chip_txt, font=F_CHIP, fill=WHITE)

    # App screenshot with rounded corners + shadow
    app = Image.open(fp).convert("RGB")
    if app.size != (APP_W, APP_H):
        app = app.resize((APP_W, APP_H))
    ax, ay = ox + PAD_X, oy + HEADER_H
    # subtle shadow
    d.rounded_rectangle([ax - 3, ay + 6, ax + APP_W + 3, ay + APP_H + 8], radius=20,
                        fill=(40, 18, 70))
    mask = Image.new("L", (APP_W, APP_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, APP_W, APP_H], radius=18, fill=255)
    canvas.paste(app, (ax, ay), mask)

    # Caption strip
    cy = oy + HEADER_H + APP_H + 14
    d.text((ox + PAD_X, cy), cap, font=F_CAP, fill=WHITE)
    d.text((ox + PAD_X, cy + 34), sub, font=F_SUB, fill=(226, 214, 240))
    # gold accent underline
    d.rounded_rectangle([ox + PAD_X, cy - 12, ox + PAD_X + 46, cy - 8], radius=3, fill=GOLD)

    return canvas


files = sorted(glob.glob(f"{SRC}/*.png"))
frames = [compose(f) for f in files]
print(f"composed {len(frames)} scene frames at {VW}x{VH}")

# Save a contact-sheet style poster (first, mid, last) + all composed frames
for f, img in zip(files, frames):
    name = os.path.splitext(os.path.basename(f))[0]
    img.save(f"{OUT_DIR}/scene_{name}.png")

# Build MP4: hold each scene ~2.6s at 25fps, with brief crossfades
FPS = 25
HOLD = int(2.6 * FPS)
XF = 8  # crossfade frames

seq = []
for i, img in enumerate(frames):
    cur = img.convert("RGB")
    if i > 0 and XF > 0:
        prev = frames[i - 1].convert("RGB")
        for k in range(1, XF + 1):
            a = k / (XF + 1)
            seq.append(Image.blend(prev, cur, a))
    seq.extend([cur] * HOLD)

mp4_path = f"{OUT_DIR}/match-word-journey.mp4"
w = imageio.get_writer(mp4_path, fps=FPS, codec="libx264",
                       macro_block_size=None, pixelformat="yuv420p", quality=8)
for im in seq:
    w.append_data(_as := __import__("numpy").asarray(im))
w.close()
print("wrote", mp4_path, "frames:", len(seq))

# Build GIF (lighter: hold ~0.9s, no crossfade, half-ish scale)
gif_scale = 0.62
gif_frames = []
for img in frames:
    gw, gh = int(VW * gif_scale), int(VH * gif_scale)
    gif_frames.append(img.convert("RGB").resize((gw, gh)))
gif_path = f"{OUT_DIR}/match-word-journey.gif"
gif_frames[0].save(gif_path, save_all=True, append_images=gif_frames[1:],
                   duration=1400, loop=0, optimize=True)
print("wrote", gif_path)

print("done ->", OUT_DIR)
