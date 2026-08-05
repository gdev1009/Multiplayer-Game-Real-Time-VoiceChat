#!/usr/bin/env python3
"""Fix paper-doll necks: clear painted collar fills over the neck column.

Male and female outfits can paint an opaque fill inside the collar (dark stump,
blue-gray, or warm light-gray). That covers body-*-neck and reads as a floating
chin.

Approach (kept intentionally minimal — aggressive widen/punch looked worse):
  1. Restore outfit-{m,f}*.png from tools/collar_fix_backup/.
  2. Restore body-{male,female}.png from tools/body_originals with a gentle
     under-chin shadow lift only (no rectangular "neck slabs").
  3. Punch cavity pixels only where the body already has neck skin
     (dilated 1px), preserving bright collar rims / yellow / jacket chroma.

Flutter: do not paint a NeckBridge oval — it sat on top of collars.

Run from app/:  python3 tools/fix_male_collar_holes.py
                python3 tools/fix_male_collar_holes.py --sex female
                python3 tools/fix_male_collar_holes.py --sex both
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
CH = ROOT / "assets" / "images" / "character"
BACKUP = ROOT / "tools" / "collar_fix_backup"
BODY_ORIG_DIR = ROOT / "tools" / "body_originals" / "base"
CX = 627
W = H = 1254

SEXES = {
    "male": {
        "body": "body-male.png",
        "outfit_glob": "outfit-m*.png",
        "label": "male",
    },
    "female": {
        "body": "body-female.png",
        "outfit_glob": "outfit-f*.png",
        "label": "female",
    },
}


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


def soft_chin(body: np.ndarray) -> np.ndarray:
    out = body.copy()
    for y in range(300, 312):
        for x in range(CX - 35, CX + 36):
            if out[y, x, 3] < 200:
                continue
            p = out[y, x, :3].astype(float)
            if p.mean() >= 145:
                continue
            if not (p[0] > 180 and p[0] > p[2] + 15):
                continue
            tgt = np.array([248.0, 186.0, 130.0])
            t = min(0.2, (145 - p.mean()) / 90)
            out[y, x, :3] = (p * (1 - t) + tgt * t).astype(np.uint8)
    return out


def neck_skin_mask(body: np.ndarray) -> np.ndarray:
    rgb = body[:, :, :3].astype(float)
    a = body[:, :, 3]
    skin = (
        (a > 200)
        & (rgb[:, :, 0] > 180)
        & (rgb[:, :, 1] > 100)
        & (rgb[:, :, 0] > rgb[:, :, 2] + 15)
        & (rgb[:, :, 0] > rgb[:, :, 1] + 10)
    )
    nmask = ndimage.binary_dilation(skin, iterations=1)
    nmask[:278, :] = False
    nmask[335:, :] = False
    for y in range(278, 335):
        xs = np.where(nmask[y])[0]
        if len(xs) > 120:
            nmask[y, :] = False
            nmask[y, CX - 40 : CX + 41] = True
    return nmask


def is_keep(c, a, x: int) -> bool:
    if a < 20:
        return False
    r, g, b = map(float, c)
    lum = (r + g + b) / 3
    sat = max(r, g, b) - min(r, g, b)
    if lum >= 235 and sat < 55:
        return True
    if r > 190 and g > 150 and b < 120:
        return True
    if sat >= 75 and lum >= 90 and abs(x - CX) > 40:
        return True
    return False


def is_cavity(c, a) -> bool:
    if a < 20:
        return True
    r, g, b = map(float, c)
    lum = (r + g + b) / 3
    sat = max(r, g, b) - min(r, g, b)
    if lum >= 235 and sat < 55:
        return False
    if r > 190 and g > 150 and b < 120:
        return False
    if lum < 155:
        return True
    if b >= r + 2 and sat <= 85 and lum <= 205:
        return True
    if sat < 50 and 160 <= lum <= 228:
        return True
    return False


def punch_collar(outfit: np.ndarray, nmask: np.ndarray) -> tuple[np.ndarray, int]:
    punch = np.zeros((H, W), dtype=bool)
    for y in range(280, 335):
        for x in range(CX - 70, CX + 71):
            if not nmask[y, x]:
                continue
            c = outfit[y, x, :3]
            a = int(outfit[y, x, 3])
            if a < 20:
                continue
            if is_keep(c, a, x):
                continue
            if is_cavity(c, a):
                punch[y, x] = True
    punch = ndimage.binary_dilation(punch, iterations=1) & nmask
    ys, xs = np.where(punch)
    for y, x in zip(ys, xs):
        if is_keep(outfit[y, x, :3], outfit[y, x, 3], x):
            punch[y, x] = False
    fixed = outfit.copy()
    fixed[punch, 3] = 0
    return fixed, int(punch.sum())


def fix_sex(sex: str) -> None:
    cfg = SEXES[sex]
    body_name = cfg["body"]
    body_orig = BODY_ORIG_DIR / body_name
    if not body_orig.exists():
        raise SystemExit(f"missing original body: {body_orig}")

    body_rel = Path("base") / body_name
    backup(body_rel)
    body = soft_chin(load(body_orig))
    save(body, CH / body_rel)
    nmask = neck_skin_mask(body)

    for outfit_path in sorted((CH / "outfit").glob(cfg["outfit_glob"])):
        rel = Path("outfit") / outfit_path.name
        src = backup(rel)
        fixed, n = punch_collar(load(src), nmask)
        save(fixed, outfit_path)
        print(f"{outfit_path.name}: cleared {n} collar pixels over neck skin")

    print(f"Done. Minimal {cfg['label']} collar punch applied.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sex",
        choices=("male", "female", "both"),
        default="both",
        help="Which body/outfits to fix (default: both)",
    )
    args = parser.parse_args()
    sexes = ("male", "female") if args.sex == "both" else (args.sex,)
    for sex in sexes:
        fix_sex(sex)


if __name__ == "__main__":
    main()
