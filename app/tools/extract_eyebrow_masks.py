#!/usr/bin/env python3
"""Extract neutral eyebrow pixels from base bodies and face poses.

The hair colour picker tints the hair PNGs, but the visible eyebrow arches live
on the base body (and some expression poses) as light grey strokes. Without a
mask those brows stay white no matter which hair colour is chosen.

This script writes companion *-brows.png files: only the eyebrow pixels are kept,
everything else is transparent. The app multiplies them by the hair tint at paint
time, same as the hair layer.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHAR = ROOT / "assets" / "images" / "character"


def _is_brow_pixel(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """True where [rgb] looks like a neutral, light eyebrow stroke."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    neutral = (np.abs(r.astype(int) - g.astype(int)) < 28) & (
        np.abs(r.astype(int) - b.astype(int)) < 32
    )
    light = r > 158
    return neutral & light & (alpha > 20)


def extract_brows(src: Path, dest: Path) -> int:
    im = np.array(Image.open(src).convert("RGBA"))
    h, w = im.shape[:2]
    y0, y1 = int(h * 0.145), int(h * 0.205)
    x0, x1 = int(w * 0.28), int(w * 0.72)

    out = np.zeros_like(im)
    band = im[y0:y1, x0:x1]
    mask = _is_brow_pixel(band[:, :, :3], band[:, :, 3])
    band_out = np.zeros_like(band)
    band_out[mask] = band[mask]
    out[y0:y1, x0:x1] = band_out

    count = int(mask.sum())
    if count:
        dest.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out).save(dest)
    elif dest.exists():
        dest.unlink()
    return count


def main() -> int:
    jobs: list[tuple[Path, Path]] = []

    for body in ("body-female", "body-male"):
        src = CHAR / "base" / f"{body}.png"
        jobs.append((src, CHAR / "base" / f"{body}-brows.png"))

    hair_dir = CHAR / "hair"
    if hair_dir.is_dir():
        for src in sorted(hair_dir.glob("*.png")):
            if src.stem.endswith("-brows"):
                continue
            jobs.append((src, src.with_name(f"{src.stem}-brows.png")))

    for gender in ("female", "male"):
        folder = CHAR / "poses" / gender
        if not folder.is_dir():
            continue
        for src in sorted(folder.glob("*.png")):
            if src.stem.endswith("-brows"):
                continue
            jobs.append((src, src.with_name(f"{src.stem}-brows.png")))

    wrote = 0
    for src, dest in jobs:
        if not src.is_file():
            print(f"skip (missing): {src.relative_to(ROOT)}")
            continue
        n = extract_brows(src, dest)
        if n:
            print(f"{dest.relative_to(ROOT)}  ({n} px)")
            wrote += 1
        elif dest.exists():
            print(f"removed empty mask {dest.relative_to(ROOT)}")

    print(f"done — {wrote} brow mask(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
