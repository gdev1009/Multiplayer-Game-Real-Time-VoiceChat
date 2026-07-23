#!/usr/bin/env python3
"""Generate talk-mid / talk-open mouth variants for host action PNG frames.

Only the four voice-driven action stems (correct / wrong / reveal / winner).
Listening + welcome keep using the full-body stage host lipsync.

    cd app
    python3 tools/generate_action_talk_frames.py --dry-run
    python3 tools/generate_action_talk_frames.py --quality medium

Installs beside each base frame:
    assets/images/host/actions/frames/{stem}/00-talk-mid.png
    assets/images/host/actions/frames/{stem}/00-talk-open.png
    ...
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "assets" / "images" / "host" / "actions" / "frames"
OUT = Path(__file__).resolve().parent / "out" / "action_talk"
MODEL = "gpt-image-1"
GEN_SIZE = "1024x1024"

# Voice plays on these action poses (stage host covers listening/welcome).
STEMS = (
    "green-flag-wave",
    "red-flag-shake",
    "golden-card-reveal",
    "winner-announce",
)

PROMPTS = {
    "talk-closed": (
        "Edit ONLY the mouth of this exact game-show host character for lipsync. "
        "CLOSE the mouth to a friendly closed-lip smile — lips together, NO teeth "
        "visible, NO open oval, jaw fully up. Keep the identical head, hair, eyes, "
        "body pose, props, suit, lighting, scale, crop, and fully transparent "
        "background. No props added."
    ),
    "talk-mid": (
        "Edit ONLY the mouth of this exact game-show host character for lipsync. "
        "Show a SMALL speaking aperture: lips parted just enough to see a thin "
        "line of upper teeth, jaw barely dropped — clearly mid-speech but NOT a "
        "wide oval. Keep the identical head, hair, eyes, body pose, props, suit, "
        "lighting, scale, crop, and fully transparent background. No props added."
    ),
    "talk-open": (
        "Edit ONLY the mouth of this exact game-show host character for lipsync. "
        "Open the mouth wider mid-speech — clear oval cavity, visible upper teeth, "
        "friendly announcer look (not screaming). Keep the identical head, hair, "
        "eyes, body pose, props, suit, lighting, scale, crop, and fully "
        "transparent background. No props added."
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


def align_to_source(edited: Image.Image, src: Image.Image) -> Image.Image:
    """Place edited figure onto src canvas matched to source opaque bbox height."""
    src_a = src.split()[-1]
    src_bbox = src_a.getbbox()
    alpha = edited.split()[-1]
    bbox = alpha.getbbox()
    fig = edited.crop(bbox) if bbox else edited
    if not src_bbox or fig.height <= 0:
        return edited.resize(src.size, Image.LANCZOS)
    target_h = src_bbox[3] - src_bbox[1]
    scale = target_h / fig.height
    new_size = (max(1, round(fig.width * scale)), max(1, round(fig.height * scale)))
    fig = fig.resize(new_size, Image.LANCZOS)
    canvas = Image.new("RGBA", src.size, (0, 0, 0, 0))
    paste_x = round((src_bbox[0] + src_bbox[2]) / 2 - fig.width / 2)
    paste_y = src_bbox[1]
    canvas.alpha_composite(fig, (paste_x, paste_y))
    return canvas


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--stems",
        default=",".join(STEMS),
        help="Comma-separated stem folders (default: voice-driven actions)",
    )
    ap.add_argument("--skip-existing", action="store_true", default=True)
    ap.add_argument("--force", action="store_true", help="Regenerate even if files exist")
    ap.add_argument(
        "--poses",
        default=",".join(PROMPTS),
        help="Comma-separated poses to generate (default: all)",
    )
    ap.add_argument(
        "--frames",
        default="",
        help="Comma-separated base stems like 01 (default: all 00/01/02)",
    )
    args = ap.parse_args()
    stems = [s.strip() for s in args.stems.split(",") if s.strip()]
    poses = [p.strip() for p in args.poses.split(",") if p.strip()]
    only_frames = {f.strip().zfill(2) for f in args.frames.split(",") if f.strip()}

    jobs: list[tuple[Path, str, Path]] = []
    for stem in stems:
        folder = FRAMES / stem
        if not folder.is_dir():
            print(f"WARN: missing {folder}", file=sys.stderr)
            continue
        for src in sorted(folder.glob("[0-9][0-9].png")):
            if only_frames and src.stem not in only_frames:
                continue
            for pose in poses:
                if pose not in PROMPTS:
                    print(f"WARN: unknown pose {pose}", file=sys.stderr)
                    continue
                dest = src.with_name(f"{src.stem}-{pose}.png")
                if dest.exists() and args.skip_existing and not args.force:
                    print(f"skip {dest.relative_to(ROOT)}")
                    continue
                jobs.append((src, pose, dest))

    print(f"jobs: {len(jobs)}  model={MODEL} quality={args.quality}")
    if args.dry_run:
        for src, pose, dest in jobs:
            print(f"  {src.name} -> {dest.name}  ({pose})")
        return

    key = load_api_key()
    if not key:
        print("ERROR: OPENAI_API_KEY not set (env or app/.env)", file=sys.stderr)
        sys.exit(1)

    from openai import OpenAI

    client = OpenAI(api_key=key)
    OUT.mkdir(parents=True, exist_ok=True)

    for i, (src, pose, dest) in enumerate(jobs, 1):
        print(f"[{i}/{len(jobs)}] {src.relative_to(ROOT)} -> {pose} ...")
        src_im = Image.open(src).convert("RGBA")
        # Feed square canvas (action frames are 480×480).
        feed_im = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        thumb = src_im.copy()
        thumb.thumbnail((1024, 1024), Image.LANCZOS)
        feed_im.alpha_composite(
            thumb, ((1024 - thumb.width) // 2, (1024 - thumb.height) // 2)
        )
        feed = OUT / f"feed-{src.parent.name}-{src.stem}.png"
        feed_im.save(feed)

        with feed.open("rb") as fh:
            resp = client.images.edit(
                model=MODEL,
                image=fh,
                prompt=PROMPTS[pose],
                size=GEN_SIZE,
                background="transparent",
                quality=args.quality,
                input_fidelity="high",
                n=1,
            )
        raw = OUT / f"{src.parent.name}-{src.stem}-{pose}.raw.png"
        raw.write_bytes(base64.b64decode(resp.data[0].b64_json))
        edited = Image.open(raw).convert("RGBA")
        aligned = align_to_source(edited, src_im)
        aligned.save(dest)
        print(f"  installed {dest.relative_to(ROOT)}")

    print("done")


if __name__ == "__main__":
    main()
