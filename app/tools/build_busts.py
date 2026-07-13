"""Crop head-and-shoulders "busts" from the clay base-body art.

The Milestone 6 studio podiums show each player as a small character bust, the
way the concept mockup does. Rather than draw flat placeholders we reuse the
real artist base bodies (`assets/images/character/base/body-*.png`, 1254x1254
transparent clay figures) and crop the head + shoulders into a clean bust so the
podium reads as premium and realistic.

For each base we:
  1. find the figure's alpha bounding box,
  2. take the top slice (head through upper chest/shoulders),
  3. centre it horizontally on the head,
  4. export a tidy transparent PNG.

Run from the `app/` directory:
    python3 tools/build_busts.py
Writes `assets/images/host/bust-female.png` and `bust-male.png`.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

BASE = Path("assets/images/character/base")
OUT = Path("assets/images/host")

# Fraction of the figure height (from the top of the head) to keep for the bust.
BUST_HEIGHT_FRACTION = 0.36
# Extra padding around the crop, as a fraction of the crop size.
PAD = 0.06


def bust(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGBA")
    alpha = np.asarray(im)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    top, bottom = ys.min(), ys.max()
    left, right = xs.min(), xs.max()
    fig_h = bottom - top

    crop_bottom = int(top + fig_h * BUST_HEIGHT_FRACTION)

    # Head centre: use the horizontal centre of the topmost 20% of the figure.
    head_band = ys < top + fig_h * 0.2
    head_xs = xs[head_band]
    head_cx = int(head_xs.mean()) if head_xs.size else (left + right) // 2

    # Shoulders span within the kept slice — use it to size the crop width.
    slice_band = ys < crop_bottom
    slice_xs = xs[slice_band]
    half_w = int((slice_xs.max() - slice_xs.min()) / 2)

    pad = int((crop_bottom - top) * PAD)
    box_left = max(0, head_cx - half_w - pad)
    box_right = min(im.width, head_cx + half_w + pad)
    box_top = max(0, top - pad)
    box_bottom = min(im.height, crop_bottom + pad)

    crop = im.crop((box_left, box_top, box_right, box_bottom))
    crop.save(dst)
    print(f"wrote {dst} {crop.size} (from {src.name})")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bust(BASE / "body-female.png", OUT / "bust-female.png")
    bust(BASE / "body-male.png", OUT / "bust-male.png")


if __name__ == "__main__":
    main()
