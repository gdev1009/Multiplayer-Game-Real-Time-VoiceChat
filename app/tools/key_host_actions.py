#!/usr/bin/env python3
"""Key Guy Smiley action GIFs → transparent PNG frames + WebP.

Hard-won rules:
1. Flood-fill purple plate from the border through WIDE passages only
   (3×3 plate blocks). Narrow purple channels through the suit must not
   become holes.
2. Protect figure materials (blue suit ≠ purple plate; g>r for dark folds).
3. Density-fill small interior bites; inpaint plate-colored restores from
   nearby suit colors — never reintroduce plate as opaque purple blobs.
4. Hard-zero leftover plate fringe so purple stages stay seamless.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from numpy.lib.stride_tricks import sliding_window_view

ACTIONS = Path(__file__).resolve().parents[1] / "assets/images/host/actions"
FRAMES = ACTIONS / "frames"

PLATE_SAMPLES = np.array(
    [
        [31, 13, 74],
        [33, 7, 68],
        [34, 15, 76],
        [35, 16, 78],
        [38, 11, 77],
        [38, 12, 82],
        [38, 17, 86],
        [38, 18, 82],
        [39, 11, 78],
        [40, 12, 77],
        [40, 19, 89],
        [42, 19, 78],
        [43, 14, 85],
        [45, 21, 82],
        [45, 22, 76],
        [47, 22, 81],
        [48, 19, 87],
        [48, 21, 86],
        [50, 23, 83],
        [50, 25, 86],
        [51, 21, 90],
        [51, 21, 91],
        [52, 25, 86],
        [52, 26, 93],
        [53, 27, 91],
        [54, 25, 93],
        [55, 24, 98],
        [55, 26, 89],
        [55, 26, 96],
        [56, 23, 94],
        [56, 29, 94],
        [58, 28, 93],
        [58, 29, 99],
        [59, 28, 99],
        [61, 32, 102],
        [62, 32, 102],
        [63, 33, 105],
        [64, 31, 103],
    ],
    dtype=np.float32,
)


def _plate_dist(rgb: np.ndarray) -> np.ndarray:
    diff = rgb[:, :, None, :].astype(np.float32) - PLATE_SAMPLES[None, None, :, :]
    return np.sqrt((diff * diff).sum(axis=3)).min(axis=2)


def _is_figure(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = mx - mn

    # Cobalt suit ≈ (10,58,148). Winner-plate blotch ≈ (49,37,118) must NOT match:
    # require low R and g roughly in the suit band (not plate-purple).
    blue_suit = (
        (b > 100)
        & (r < 55)
        & (g > 32)
        & (g < b - 45)
        & (b > r + 55)
        & (b > g + 40)
        & (sat > 55)
        & (g + 8 >= r)  # suit g >> r; blotch often r > g
    )
    dark_suit = (
        (b > 72) & (r < 40) & (g > r) & (g < 70) & (b > r + 30) & (b >= g + 12)
    )
    skin = (r > 110) & (g > 70) & (b > 40) & (r > g) & (g >= b - 10) & (r - b > 25)
    blonde = (r > 120) & (g > 90) & (b < r - 10) & (r + g > 220)
    white = (r > 200) & (g > 200) & (b > 200)
    black = (mx < 55) & (sat < 35)
    green_flag = (g > 120) & (g > r + 30) & (g > b + 20)
    red_flag = (r > 140) & (r > g + 40) & (r > b + 40)
    gold = (r > 140) & (g > 100) & (b < 90) & (r > b + 40)
    # Tie / pocket — brighter saturated purple (not dark plate).
    purple_prop = (
        (b > 105)
        & (r > 55)
        & (r < 150)
        & (g > 30)
        & (g < 95)
        & (b > r + 20)
        & (b > g + 30)
        & (mx > 120)
        & (sat > 50)
        & (g + 15 > r)
    ) | (
        (b > 130)
        & (r > 60)
        & (r < 160)
        & (g < 100)
        & (b > r + 25)
        & (sat > 60)
        & (mx > 140)
    )
    motion = (sat < 25) & (mx > 60) & (mx < 160) & (np.abs(r.astype(int) - g) < 15)

    return (
        blue_suit
        | dark_suit
        | skin
        | blonde
        | white
        | black
        | green_flag
        | red_flag
        | gold
        | purple_prop
        | motion
    )


def _is_plate_seed(rgb: np.ndarray, dist: np.ndarray, figure: np.ndarray) -> np.ndarray:
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = mx - mn
    plateish = (dist < 48) | (
        (dist < 68)
        & (sat < 80)
        & (rgb[:, :, 2] >= rgb[:, :, 0])
        & (mx < 140)
        & (rgb[:, :, 1] < 55)
    )
    return plateish & ~figure


def _suitish_fill(rgb: np.ndarray, dist: np.ndarray, figure: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    suit = (
        (b > 85) & (r < 80) & (g > 24) & (b > r + 40) & (b > g + 25) & (dist > 28)
    )
    dark = (
        (b > 70) & (r < 48) & (g > r) & (g < 65) & (b > r + 28) & (dist > 22)
    )
    return figure | suit | dark


def _dilate(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        pad = np.pad(out, 1, constant_values=False)
        out = sliding_window_view(pad, (3, 3)).any(axis=(2, 3))
    return out


def key_frame(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[:, :, :3]
    h, w, _ = rgb.shape
    dist = _plate_dist(rgb)
    figure = _is_figure(rgb)
    plateish = _is_plate_seed(rgb, dist, figure)
    fillable = _suitish_fill(rgb, dist, figure)
    near_fig = _dilate(figure | fillable, 10)

    # Wide-passage plate: mostly-plate 3×3 (won't thread narrow suit folds).
    pad_p = np.pad(plateish, 1, constant_values=False)
    wide = sliding_window_view(pad_p, (3, 3)).sum(axis=(2, 3)) >= 8
    border = np.zeros((h, w), dtype=bool)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    passable = (wide | (plateish & border)) & ~figure

    visited = np.zeros((h, w), dtype=bool)
    dq: deque[tuple[int, int]] = deque()

    def seed(y: int, x: int, allow: np.ndarray) -> None:
        if allow[y, x] and not visited[y, x]:
            visited[y, x] = True
            dq.append((y, x))

    for x in range(w):
        seed(0, x, passable)
        seed(h - 1, x, passable)
    for y in range(h):
        seed(y, 0, passable)
        seed(y, w - 1, passable)

    while dq:
        y, x = dq.popleft()
        if y > 0:
            seed(y - 1, x, passable)
        if y < h - 1:
            seed(y + 1, x, passable)
        if x > 0:
            seed(y, x - 1, passable)
        if x < w - 1:
            seed(y, x + 1, passable)

    # Clear plate islands far from the body via normal connectivity.
    plate_far = plateish & ~near_fig & ~figure
    # Reseed from visited into plate_far
    ys, xs = np.where(visited)
    dq.clear()
    for y, x in zip(ys.tolist()[::20], xs.tolist()[::20], strict=False):
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and plate_far[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True
                dq.append((ny, nx))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and plate_far[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True
                dq.append((ny, nx))

    # Clean edge: absorb plate next to cleared.
    # Strong plate (very close to samples) may be cleared even near the body;
    # weaker plate only when outside the body halo — protects suit folds.
    for _ in range(4):
        pad_v = np.pad(visited, 1, constant_values=False)
        near = sliding_window_view(pad_v, (3, 3)).any(axis=(2, 3))
        strong = plateish & (dist < 22) & ~figure
        weak = plateish & ~figure & ~near_fig
        visited |= near & (strong | weak)

    keep = (~visited) | figure

    # Density-fill interior bites (suit preferred; deep interiors always).
    for thresh, rad in ((16, 2), (28, 3), (45, 4)):
        k = 2 * rad + 1
        pad_k = np.pad(keep, rad, constant_values=False)
        neigh = sliding_window_view(pad_k, (k, k)).sum(axis=(2, 3))
        keep |= (~keep) & (neigh >= thresh) & fillable
        keep |= (~keep) & (neigh >= int(k * k * 0.68))

    restored = keep & visited

    # Inpaint plate-colored restored pixels from nearby body colors.
    body = figure | fillable
    masked = rgb.astype(np.float32) * body.astype(np.float32)[:, :, None]
    weight = Image.fromarray((body.astype(np.uint8) * 255), mode="L").filter(
        ImageFilter.BoxBlur(4)
    )
    warr = np.array(weight).astype(np.float32) / 255.0 + 1e-3
    blurred = np.zeros_like(rgb, dtype=np.float32)
    for c in range(3):
        ch = Image.fromarray(masked[:, :, c].astype(np.uint8), mode="L").filter(
            ImageFilter.BoxBlur(4)
        )
        blurred[:, :, c] = np.array(ch).astype(np.float32) / warr

    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    plate_like = (dist < 38) & (g < 50) & (b >= r - 5) & (r < 80)
    out_rgb = rgb.copy()
    use_inp = restored & plate_like
    if use_inp.any():
        out_rgb[use_inp] = np.clip(blurred[use_inp], 0, 255).astype(np.uint8)

    plate_px = (dist < 28) & (g < 45) & (r < 72) & (b < 112) & (b >= r - 5)
    keep = keep & ~(plate_px & ~figure & ~restored)

    soft = np.array(
        Image.fromarray(np.where(keep, 255, 0).astype(np.uint8), mode="L").filter(
            ImageFilter.GaussianBlur(0.4)
        )
    ).astype(np.uint8)
    soft[~keep] = 0
    soft[figure | restored] = 255
    soft[(soft > 0) & (soft < 240) & plate_px & ~figure & ~restored] = 0

    out = np.dstack([out_rgb, soft]).astype(np.uint8)
    out[soft < 8] = 0
    return out


def process_gif(src: Path) -> None:
    stem = src.stem
    im = Image.open(src)
    frames: list[Image.Image] = []
    durations: list[int] = []
    n = 0
    while True:
        try:
            im.seek(n)
        except EOFError:
            break
        keyed = key_frame(np.array(im.convert("RGBA")))
        frames.append(Image.fromarray(keyed, mode="RGBA"))
        durations.append(max(int(im.info.get("duration") or 200), 80))
        n += 1

    if not frames:
        raise RuntimeError(f"no frames in {src}")

    out_dir = FRAMES / stem
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, frame in enumerate(frames):
        frame.save(out_dir / f"{i:02d}.png", optimize=True)

    frames[0].save(
        ACTIONS / f"{stem}.webp",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        lossless=True,
        quality=100,
        method=6,
    )
    print(f"{stem}: {len(frames)} frames → {stem}.webp + frames/{stem}")


def main() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    for gif in sorted(ACTIONS.glob("*.gif")):
        process_gif(gif)


if __name__ == "__main__":
    main()
