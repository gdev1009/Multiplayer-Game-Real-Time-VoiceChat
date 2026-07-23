#!/usr/bin/env python3
"""Give the two base bodies a natural-length neck.

The artist's base bodies have a very short neck, so the head reads as sitting
directly on the shoulders ("a person without a neck"). This script inserts a
band of the body's own neck-skin just above the shoulders (so the head moves
up while the shoulders — and therefore every outfit — stay exactly where they
are), then shifts every head-attached layer (hair, hats, glasses, earrings) up
by the same amount so they still line up on the raised head.

Outfits and held items are NOT shifted: they attach at the shoulders/hands,
which do not move. This keeps the whole pre-registered layer system aligned.

Run from the app/ directory:  python3 tools/extend_neck.py [--apply]
Without --apply it writes previews to /tmp/neck_preview and touches nothing.
Pristine originals are copied to tools/body_originals/ the first time.
"""
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # app/
CH = os.path.join(ROOT, "assets", "images", "character")
BACKUP = os.path.join(ROOT, "tools", "body_originals")

# How many pixels of neck to add. Same for both bodies so the single, shared
# head-layer shift lines up on either body.
NECK_PX = 44

# The neck zone (jaw-bottom .. shoulder-top) for each body, measured from the
# per-row silhouette width. This whole zone — with its natural shading and side
# contours — is stretched taller, so the longer neck still looks hand-painted.
NECK_ZONE = {
    "body-male.png": (262, 322),
    "body-female.png": (270, 336),
}

# Every layer folder whose art attaches to the HEAD and must move up with it.
HEAD_FOLDERS = ["hair", "hat", "glasses", "earrings"]


def _open(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)


def _backup(rel):
    src = os.path.join(CH, rel)
    dst = os.path.join(BACKUP, rel)
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        Image.open(src).save(dst)


def _src(rel):
    """Load from the pristine backup if present, else the live file."""
    b = os.path.join(BACKUP, rel)
    return _open(b if os.path.exists(b) else os.path.join(CH, rel))


def extend_body(name):
    """Return an RGBA array whose neck zone is stretched taller by NECK_PX.

    The head above the zone shifts up by NECK_PX; the shoulders and everything
    below stay put. Because we resize the real neck (not a flat band) its
    shading and tapered sides are preserved, so the longer neck looks natural.
    """
    img = Image.open(
        os.path.join(BACKUP, "base", name)
        if os.path.exists(os.path.join(BACKUP, "base", name))
        else os.path.join(CH, "base", name)
    ).convert("RGBA")
    a = np.asarray(img, dtype=np.uint8)
    h, w = a.shape[0], a.shape[1]
    y_a, y_b = NECK_ZONE[name]
    n = NECK_PX
    new_top = y_a - n  # where the stretched zone now begins

    out = np.zeros((h, w, 4), dtype=np.uint8)
    # Head (rows above the zone), shifted up by n.
    out[:new_top] = a[n:y_a]
    # Neck zone stretched from (y_b - y_a) tall to (y_b - new_top) tall.
    zone = img.crop((0, y_a, w, y_b)).resize(
        (w, y_b - new_top), Image.LANCZOS
    )
    out[new_top:y_b] = np.asarray(zone, dtype=np.uint8)
    # Shoulders / torso / legs unchanged.
    out[y_b:] = a[y_b:]
    return out


def shift_up(rel, n):
    """Return an RGBA array shifted up by n px (transparent fill at bottom)."""
    a = _src(rel)
    out = np.zeros_like(a)
    out[:-n] = a[n:]
    return out


def main(apply):
    dst_root = CH if apply else "/tmp/neck_preview"
    # Bodies
    for name in NECK_ZONE:
        if apply:
            _backup(os.path.join("base", name))
        out = extend_body(name)
        p = os.path.join(dst_root, "base", name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        Image.fromarray(out, "RGBA").save(p)
    # Head-attached layers
    for folder in HEAD_FOLDERS:
        d = os.path.join(CH, folder)
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png"):
                continue
            rel = os.path.join(folder, f)
            if apply:
                _backup(rel)
            out = shift_up(rel, NECK_PX)
            p = os.path.join(dst_root, folder, f)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            Image.fromarray(out, "RGBA").save(p)
    print(("APPLIED to assets" if apply else "PREVIEW written to /tmp/neck_preview")
          + f" (neck +{NECK_PX}px)")


if __name__ == "__main__":
    main("--apply" in sys.argv)
