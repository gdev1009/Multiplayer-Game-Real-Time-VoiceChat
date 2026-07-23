"""Cut the near-white studio background out of the full-body Guy Smiley art.

The delivered `host-fullbody.png` ships on a near-white (JPEG-ish) backdrop, but
the Milestone 6 play stage places the host on a deep-purple studio set, so we
need a clean transparent cut-out. We flood the background in from every border
pixel (4-connected) over a "near white" mask, which keeps the white shirt/teeth
inside the figure intact (they are not connected to the border), then feather
the resulting alpha by one pixel so the edge is not harsh against the purple.

Run from the `app/` directory:
    python3 tools/cutout_host.py
Writes `assets/images/host/host-stage.png` (RGBA, transparent background).
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SRC = Path("assets/images/host/host-fullbody.png")
DST = Path("assets/images/host/host-stage.png")

# A pixel counts as "background-ish" when every channel is this bright or more.
WHITE_MIN = 222


def main() -> None:
    im = Image.open(SRC).convert("RGB")
    arr = np.asarray(im)
    h, w, _ = arr.shape

    near_white = (arr >= WHITE_MIN).all(axis=2)

    # Flood the background inward from the border over the near-white mask.
    visited = np.zeros((h, w), dtype=bool)
    dq: deque[tuple[int, int]] = deque()

    def seed(y: int, x: int) -> None:
        if near_white[y, x] and not visited[y, x]:
            visited[y, x] = True
            dq.append((y, x))

    for x in range(w):
        seed(0, x)
        seed(h - 1, x)
    for y in range(h):
        seed(y, 0)
        seed(y, w - 1)

    while dq:
        y, x = dq.popleft()
        if y > 0:
            seed(y - 1, x)
        if y < h - 1:
            seed(y + 1, x)
        if x > 0:
            seed(y, x - 1)
        if x < w - 1:
            seed(y, x + 1)

    alpha = np.where(visited, 0, 255).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, mode="L").filter(
        ImageFilter.GaussianBlur(0.6)
    )

    out = im.convert("RGBA")
    out.putalpha(alpha_img)

    # Trim to the figure's bounding box so it centres cleanly in the UI.
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)

    DST.parent.mkdir(parents=True, exist_ok=True)
    out.save(DST)
    print(f"wrote {DST} {out.size} (from {SRC.name} {im.size})")


if __name__ == "__main__":
    main()
