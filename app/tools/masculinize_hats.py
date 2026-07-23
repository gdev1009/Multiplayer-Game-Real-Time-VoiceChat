#!/usr/bin/env python3
"""Make the two male hats actually look masculine.

The artist delivered "male" hats that are styled/coloured for women:
  - hat-m-knit  : a *pink* pom-pom beanie
  - hat-m-brim  : a *teal* boater with a green feather

Both filenames say "Male" but the art reads female, so a man building a
character is offered women's hats. This script recolours them into masculine
colourways (and removes the feather) while preserving all of the original
shading/texture, by shifting hue/saturation in HSV and keeping value (V).

Run from the app/ directory:  python3 tools/masculinize_hats.py
Originals are copied to <hat>.orig.png the first time so the change is
reversible.
"""
import os
import colorsys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # app/
HAT = os.path.join(ROOT, "assets", "images", "character", "hat")
# Backups live OUTSIDE the bundled asset tree so they never bloat the APK.
BACKUP = os.path.join(ROOT, "tools", "hat_originals")

# Vectorised RGB<->HSV over an (H, W, 3) float array in [0, 1].
_rgb_to_hsv = np.vectorize(colorsys.rgb_to_hsv)
_hsv_to_rgb = np.vectorize(colorsys.hsv_to_rgb)


def load(name):
    return np.asarray(Image.open(os.path.join(HAT, name)).convert("RGBA"),
                      dtype=np.float32) / 255.0


def load_orig(name):
    """Load a hat's pristine backup (falls back to the live file first time)."""
    path = os.path.join(BACKUP, name)
    if not os.path.exists(path):
        path = os.path.join(HAT, name)
    return np.asarray(Image.open(path).convert("RGBA"),
                      dtype=np.float32) / 255.0


def save(name, arr):
    img = Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(HAT, name))


def backup(name):
    os.makedirs(BACKUP, exist_ok=True)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst):
        Image.open(os.path.join(HAT, name)).save(dst)


def masculinize_knit(out="hat-m-knit.png"):
    """Pink pom-pom beanie -> charcoal-navy beanie (shape is already unisex)."""
    a = load_orig("hat-m-knit.png")
    rgb, alpha = a[..., :3], a[..., 3]
    h, s, v = _rgb_to_hsv(rgb[..., 0], rgb[..., 1], rgb[..., 2])
    opaque = alpha > 0.05
    # Recolour to a deep, muted navy-charcoal. Keep V so every knit-rib shadow
    # and highlight survives untouched.
    h = np.where(opaque, 0.60, h)          # blue family (~216 deg)
    s = np.where(opaque, s * 0.28 + 0.06, s)  # mostly desaturated -> greyish
    v = np.where(opaque, v * 0.78, v)      # a touch darker for a wool look
    r, g, b = _hsv_to_rgb(h, s, v)
    out_arr = np.dstack([r, g, b, alpha]).astype(np.float32)
    save(out, out_arr)


def masculinize_brim(out="hat-m-brim.png"):
    """Teal feathered boater -> brown felt brim hat.

    The green feather is recoloured brown (not deleted) so it becomes a small,
    tasteful quill accent — a classic masculine Tyrolean/outback look — and no
    cut-out artefacts are left behind. The black hatband and gold buckle are
    preserved.
    """
    a = load_orig("hat-m-brim.png")
    rgb, alpha = a[..., :3], a[..., 3]
    h, s, v = _rgb_to_hsv(rgb[..., 0], rgb[..., 1], rgb[..., 2])

    opaque = alpha > 0.05
    # Everything coloured teal (the felt) OR green (the feather): hue ~72-223.
    felt_or_feather = opaque & (h > 0.20) & (h < 0.62) & (s > 0.12)
    h = np.where(felt_or_feather, 0.075, h)   # brown/orange family (~27 deg)
    s = np.where(felt_or_feather, np.clip(s * 0.95 + 0.15, 0, 0.75), s)
    v = np.where(felt_or_feather, v * 0.62, v)  # brown is much darker than teal
    r, g, b = _hsv_to_rgb(h, s, v)
    out_arr = np.dstack([r, g, b, alpha]).astype(np.float32)
    save(out, out_arr)


if __name__ == "__main__":
    for name in ("hat-m-knit.png", "hat-m-brim.png"):
        backup(name)
    masculinize_knit()
    masculinize_brim()
    print("Masculinised hat-m-knit and hat-m-brim "
          "(pristine originals kept in tools/hat_originals/)")
