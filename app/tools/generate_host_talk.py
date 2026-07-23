#!/usr/bin/env python3
"""Generate Guy Smiley idle + speaking mouth variants from host-stage.png via OpenAI.

    cd app
    python3 tools/generate_host_talk.py --dry-run
    python3 tools/generate_host_talk.py --quality medium

Installs:
    assets/images/host/host-idle.png
    assets/images/host/talk/host-talk-mid.png
    assets/images/host/talk/host-talk-open.png
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "images" / "host" / "host-stage.png"
OUT_DIR = Path(__file__).resolve().parent / "out" / "host_talk"
INSTALL_DIR = ROOT / "assets" / "images" / "host" / "talk"
MODEL = "gpt-image-1"
GEN_SIZE = "1024x1536"

PROMPTS = {
    "idle": (
        "Edit ONLY the mouth of this exact game-show host character. "
        "Close the mouth into a soft friendly closed smile — lips gently "
        "together, NO open cavity, NO visible teeth gap, calm resting "
        "expression while still warm and welcoming. Keep the identical head, "
        "hair, eyes, suit, microphone, pose, lighting, and fully transparent "
        "background. Do not change body scale or crop. No props added."
    ),
    "talk-mid": (
        "Edit ONLY the mouth of this exact game-show host character for lipsync. "
        "Show a SMALL speaking aperture: lips parted just enough to see a thin "
        "line of upper teeth, jaw barely dropped — clearly mid-speech but NOT a "
        "wide oval. Keep the identical head, hair, eyes, suit, microphone, pose, "
        "lighting, and fully transparent background. Do not change body scale "
        "or crop. No props added."
    ),
    "talk-open": (
        "Edit ONLY the mouth of this exact game-show host character for lipsync. "
        "Open the mouth wider mid-speech — clear oval cavity, visible upper teeth, "
        "friendly announcer look (not screaming). Keep the identical head, hair, "
        "eyes, suit, microphone, pose, lighting, and fully transparent background. "
        "Do not change body scale or crop. No props added."
    ),
}


def load_api_key() -> str | None:
    key = os.environ.get("OPENAI_API_KEY")
    if key:
        return key
    env_path = ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("OPENAI_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'") or None
    return None


def main() -> None:
    from PIL import Image

    ap = argparse.ArgumentParser()
    ap.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-install", action="store_true")
    args = ap.parse_args()

    if not SRC.exists():
        print(f"ERROR: missing {SRC}", file=sys.stderr)
        sys.exit(1)

    src_full = Image.open(SRC).convert("RGBA")
    print(f"source: {SRC.relative_to(ROOT)}  {src_full.size}")
    print(f"poses : {', '.join(PROMPTS)}")
    print(f"model : {MODEL}  size={GEN_SIZE}  quality={args.quality}")
    if args.dry_run:
        for k, v in PROMPTS.items():
            print(f"\n----- {k} -----\n{v}")
        return

    key = load_api_key()
    if not key:
        print("ERROR: OPENAI_API_KEY not set (env or app/.env)", file=sys.stderr)
        sys.exit(1)

    from openai import OpenAI

    client = OpenAI(api_key=key)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)

    # Fit source onto API canvas while preserving aspect.
    thumb = src_full.copy()
    thumb.thumbnail((1024, 1536), Image.LANCZOS)
    feed_im = Image.new("RGBA", (1024, 1536), (0, 0, 0, 0))
    feed_im.alpha_composite(
        thumb, ((1024 - thumb.width) // 2, (1536 - thumb.height) // 2)
    )
    feed = OUT_DIR / "feed.png"
    feed_im.save(feed)

    for pose, prompt in PROMPTS.items():
        print(f"[{pose}] editing...")
        with feed.open("rb") as fh:
            resp = client.images.edit(
                model=MODEL,
                image=fh,
                prompt=prompt,
                size=GEN_SIZE,
                background="transparent",
                quality=args.quality,
                input_fidelity="high",
                n=1,
            )
        raw = OUT_DIR / f"host-{pose}.raw.png"
        raw.write_bytes(base64.b64decode(resp.data[0].b64_json))
        edited = Image.open(raw).convert("RGBA")
        # Crop opaque content and place onto original canvas size.
        alpha = edited.split()[-1]
        bbox = alpha.getbbox()
        fig = edited.crop(bbox) if bbox else edited
        # Scale to match original figure height
        src_bbox = src_full.split()[-1].getbbox()
        if src_bbox and fig.height > 0:
            target_h = src_bbox[3] - src_bbox[1]
            scale = target_h / fig.height
            new_size = (
                max(1, round(fig.width * scale)),
                max(1, round(fig.height * scale)),
            )
            fig = fig.resize(new_size, Image.LANCZOS)
            canvas = Image.new("RGBA", src_full.size, (0, 0, 0, 0))
            paste_x = round((src_bbox[0] + src_bbox[2]) / 2 - fig.width / 2)
            paste_y = src_bbox[1]
            canvas.alpha_composite(fig, (paste_x, paste_y))
        else:
            canvas = edited.resize(src_full.size, Image.LANCZOS)

        aligned = OUT_DIR / f"host-{pose}.png"
        canvas.save(aligned)
        print(f"[{pose}] aligned -> {aligned}")
        if not args.no_install:
            if pose == "idle":
                dest = ROOT / "assets" / "images" / "host" / "host-idle.png"
            else:
                dest = INSTALL_DIR / f"host-{pose}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(aligned.read_bytes())
            print(f"[{pose}] installed -> {dest.relative_to(ROOT)}")

    print("done")


if __name__ == "__main__":
    main()
