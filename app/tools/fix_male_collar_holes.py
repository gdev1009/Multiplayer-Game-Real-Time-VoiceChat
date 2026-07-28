#!/usr/bin/env python3
"""Fix male paper-doll necks: clear painted collar fills so base skin shows.

Male outfits (unlike female) often paint an opaque dark/blue "stump" inside the
collar opening. Stacked over body-male that reads as a floating chin above a
hollow collar. This script:

  1. Restores outfit-m*.png from tools/collar_fix_backup/ (first run backs up).
  2. Soft-heals the harsh dark ring across body-male.png's neck column.
  3. Punches transparent holes where outfits overlap the neck / collar V
     (preserving white tees and bright collar rims).

Run from app/:  python3 tools/fix_male_collar_holes.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CH = ROOT / "assets" / "images" / "character"
BACKUP = ROOT / "tools" / "collar_fix_backup"
CX = 627


def load(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def save(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(path)


def backup(rel: Path) -> Path:
    dst = BACKUP / rel
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(CH / rel, dst)
    return dst


def heal_neck_shadow(body: np.ndarray) -> np.ndarray:
    """Soften the harsh dark band that visually severs the male neck."""
    out = body.copy()
    opaque = out[:, :, 3] > 200
    for y in range(298, 312):
        xs = np.where(opaque[y])[0]
        if len(xs) < 8:
            continue
        left, right = int(xs[0]), int(xs[-1])
        if right - left > 120:
            continue
        for x in range(left, right + 1):
            p = out[y, x, :3].astype(np.float32)
            if p.mean() >= 140:
                continue
            ya, yb = y - 1, y + 1
            while ya > 290 and out[ya, x, :3].mean() < 140:
                ya -= 1
            while yb < 330 and out[yb, x, :3].mean() < 140:
                yb += 1
            t = (y - ya) / max(1, yb - ya)
            blend = (
                out[ya, x, :3].astype(np.float32) * (1 - t)
                + out[yb, x, :3].astype(np.float32) * t
            )
            out[y, x, :3] = (blend * 0.85 + p * 0.15).astype(np.uint8)
    return out


def punch_collar(outfit: np.ndarray, body: np.ndarray) -> tuple[np.ndarray, int]:
    rgb = outfit[:, :, :3].astype(np.float32)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    alpha = outfit[:, :, 3]
    opaque = alpha > 80
    body_a = body[:, :, 3] > 200

    true_neck = np.zeros(alpha.shape, dtype=bool)
    for y in range(270, 370):
        xs = np.where(body_a[y])[0]
        if len(xs) == 0:
            continue
        left, right = int(xs[0]), int(xs[-1])
        width = right - left
        if width > 115:
            half = 42
            true_neck[y, CX - half : CX + half + 1] = True
        else:
            true_neck[y, left : right + 1] = True

    white_tee = opaque & (lum > 200) & (sat < 40)
    # Anything painted on the neck column (except white tee) must be transparent.
    punch = opaque & true_neck & ~white_tee

    center = np.zeros_like(true_neck)
    for y in range(300, 400):
        half = 28 if y < 350 else max(10, 28 - (y - 350) // 2)
        center[y, CX - half : CX + half + 1] = True
    dark = opaque & (lum < 105)
    inner = (
        opaque
        & (lum < 170)
        & (rgb[:, :, 2] + 5 >= rgb[:, :, 0])
        & (sat < 80)
    )
    punch |= center & (dark | inner) & ~white_tee

    fixed = outfit.copy()
    fixed[punch, 3] = 0
    return fixed, int(punch.sum())


def main() -> None:
    body_rel = Path("base/body-male.png")
    backup(body_rel)
    body = heal_neck_shadow(load(BACKUP / body_rel))
    # Prefer live body if already healed/extended; else healed backup.
    live = CH / body_rel
    if live.exists():
        # Re-heal live so reruns stay idempotent on the shadow band.
        body = heal_neck_shadow(load(live))
    save(body, live)

    for outfit_path in sorted((CH / "outfit").glob("outfit-m*.png")):
        rel = Path("outfit") / outfit_path.name
        src = backup(rel)
        fixed, n = punch_collar(load(src), body)
        save(fixed, outfit_path)
        print(f"{outfit_path.name}: cleared {n} collar pixels")

    print("Done. Male collar holes punched; neck shadow softened.")


if __name__ == "__main__":
    main()
