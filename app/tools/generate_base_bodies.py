#!/usr/bin/env python3
"""
Generate Match Word base bodies with OpenAI's image model (OPTIONAL TOOL).

 ⚠️  SOURCE OF TRUTH FOR SHIPPED BODIES
 --------------------------------------
 The bodies currently in `assets/images/character/base/` come from the artist's
 pack, imported by `tools/import_character_art.py`. They are **not** produced by
 this script. Landmark registration for hair/outfit/glasses/hat is locked to
 those artist PNGs (head-top ≈ y114–116, feet ≈ y1047–1049 on the 1254 canvas).

 The landmark targets below (HEAD_TOP_Y=90, FEET_BASE_Y=1200) are the *older*
 AI-body convention and **do not match** the shipped artist bodies. Running this
 tool and writing into `base/` would replace the artist bodies with differently-
 registered figures and break every layered part.

 Use this script only when deliberately producing a new AI body pair for review
 in `tools/out/`. To install into `base/` you must pass `--force-overwrite-artist`.

 Prefer editing the *current* bodies instead when generating idle poses — see
 `tools/generate_idle_poses.py`.

USAGE
-----
    cd app
    python3 -m pip install --user openai pillow numpy
    export OPENAI_API_KEY="sk-..."   # or set in app/.env
    python3 tools/generate_base_bodies.py --dry-run
    python3 tools/generate_base_bodies.py --no-write-base   # review in tools/out/
    python3 tools/generate_base_bodies.py --force-overwrite-artist  # DANGEROUS
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
from pathlib import Path

# ---- Spec (LEGACY AI-body landmarks — not the shipped artist pack) ---------
CANVAS = 1254
CENTER_X = 627
HEAD_TOP_Y = 90       # legacy AI target; artist bodies sit ~y114
FEET_BASE_Y = 1200    # legacy AI target; artist bodies sit ~y1048
GEN_SIZE = "1024x1024"
GEN_QUALITY = "high"

IMAGE_PRICE_USD = {
    ("1024x1024", "low"): 0.011,
    ("1024x1024", "medium"): 0.042,
    ("1024x1024", "high"): 0.167,
    ("1024x1536", "high"): 0.25,
    ("1536x1024", "high"): 0.25,
}

PROMPTS = {
    "female": (
        "A full-body 3D clay-render character of a friendly woman, front view, "
        "standing straight and symmetrical, arms relaxed but slightly away from "
        "the body, feet together and fully visible. Cute stylized proportions "
        "with a BIG ROUND HEAD (head about one third of total height), soft "
        "rounded body, warm friendly face, gentle smile, small nose. Soft matte "
        "clay / plasticine material with subtle sheen, smooth surfaces, soft "
        "studio top light, soft contact shadow. Bald / no hair, wearing only "
        "plain simple fitted neutral basewear (like a plain leotard), neutral "
        "warm skin tone. Style of a warm, cheerful game-show mascot (Pixar / The "
        "Sims / Toca Boca clay look). Fully transparent background, no floor, no "
        "props, no text. Centered, whole body inside frame with headroom and "
        "footroom."
    ),
    "male": (
        "A full-body 3D clay-render character of a friendly man, front view, "
        "standing straight and symmetrical, arms relaxed but slightly away from "
        "the body, feet together and fully visible. Cute stylized proportions "
        "with a BIG ROUND HEAD (head about one third of total height), soft "
        "rounded body, warm friendly face, gentle smile, small nose. Soft matte "
        "clay / plasticine material with subtle sheen, smooth surfaces, soft "
        "studio top light, soft contact shadow. Bald / no hair, wearing only "
        "plain simple fitted neutral basewear (plain shorts), neutral warm skin "
        "tone. Style of a warm, cheerful game-show mascot (Pixar / The Sims / "
        "Toca Boca clay look). Fully transparent background, no floor, no props, "
        "no text. Centered, whole body inside frame with headroom and footroom. "
        "Match the woman version so they look like a consistent pair."
    ),
}

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = Path(__file__).resolve().parent / "out"
BASE_DIR = ROOT / "assets" / "images" / "character" / "base"


def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_api_key() -> str | None:
    key = os.environ.get("OPENAI_API_KEY")
    if key:
        return key
    env_path = ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("OPENAI_API_KEY="):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                return value or None
    return None


def estimate_cost_usd(count: int) -> float | None:
    price = IMAGE_PRICE_USD.get((GEN_SIZE, GEN_QUALITY))
    return None if price is None else round(price * count, 4)


def print_dry_run(kinds: list[str]):
    print("DRY RUN — no API calls, no charges.\n")
    print("NOTE: shipped bodies come from import_character_art.py, not this tool.")
    print("      Prefer tools/generate_idle_poses.py to edit the CURRENT bodies.\n")
    print(f"model    : gpt-image-1")
    print(f"size     : {GEN_SIZE}")
    print(f"quality  : {GEN_QUALITY}")
    print(f"count    : {len(kinds)} image(s) -> {', '.join(kinds)}\n")
    for kind in kinds:
        print(f"----- PROMPT [{kind}] -----")
        print(PROMPTS[kind])
        print()
    est = estimate_cost_usd(len(kinds))
    if est is None:
        print("estimated cost: unknown")
    else:
        print(f"estimated cost: ~${est:.2f} USD")


def generate_raw(kind: str, client) -> Path:
    print(f"[{kind}] requesting image from gpt-image-1 ...")
    resp = client.images.generate(
        model="gpt-image-1",
        prompt=PROMPTS[kind],
        size=GEN_SIZE,
        background="transparent",
        quality=GEN_QUALITY,
        n=1,
    )
    b64 = resp.data[0].b64_json
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    raw_path = OUT_DIR / f"body-{kind}.raw.png"
    raw_path.write_bytes(base64.b64decode(b64))
    print(f"[{kind}] saved raw -> {raw_path}")
    return raw_path


def align_to_canvas(kind: str, raw_path: Path) -> Path:
    from PIL import Image
    import numpy as np

    im = Image.open(raw_path).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 16)
    if ys.size == 0:
        die(f"[{kind}] generated image has no opaque pixels (no transparency?)")

    top, bot = int(ys.min()), int(ys.max())
    left, right = int(xs.min()), int(xs.max())
    fig = im.crop((left, top, right + 1, bot + 1))

    target_h = FEET_BASE_Y - HEAD_TOP_Y
    scale = target_h / fig.height
    new_w = max(1, round(fig.width * scale))
    new_h = max(1, round(fig.height * scale))
    fig = fig.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    paste_x = round(CENTER_X - new_w / 2)
    paste_y = HEAD_TOP_Y
    canvas.alpha_composite(fig, (paste_x, paste_y))

    aligned = OUT_DIR / f"body-{kind}.png"
    canvas.save(aligned)
    print(f"[{kind}] aligned -> {aligned}  "
          f"(legacy landmarks y={HEAD_TOP_Y}..{FEET_BASE_Y})")
    return aligned


def main():
    ap = argparse.ArgumentParser(
        description="Generate Match Word base bodies (optional AI tool).",
    )
    ap.add_argument("--only", choices=["female", "male"], help="generate one")
    ap.add_argument("--raw-only", action="store_true",
                    help="only generate; skip landmark alignment")
    ap.add_argument("--no-write-base", action="store_true",
                    help="do not copy aligned PNGs into assets/.../base/")
    ap.add_argument(
        "--force-overwrite-artist",
        action="store_true",
        help="REQUIRED to write into base/ — overwrites the artist's shipped "
             "bodies and will break layered part registration",
    )
    ap.add_argument("--dry-run", action="store_true",
                    help="print prompt(s) and estimated cost; spend nothing")
    args = ap.parse_args()

    kinds = [args.only] if args.only else ["female", "male"]

    if args.dry_run:
        print_dry_run(kinds)
        return

    write_base = not args.no_write_base
    if write_base and not args.force_overwrite_artist:
        die(
            "Refusing to overwrite the artist's shipped bodies in "
            "assets/images/character/base/.\n"
            "  • Those bodies come from tools/import_character_art.py and every "
            "hair/outfit/glasses layer is registered to them.\n"
            "  • Re-run with --no-write-base to review AI bodies in tools/out/, OR\n"
            "  • Pass --force-overwrite-artist if you truly mean to replace them "
            "(breaks layer registration).\n"
            "  • For idle poses on the CURRENT bodies, use "
            "tools/generate_idle_poses.py instead."
        )

    key = load_api_key()
    if not key:
        die("OPENAI_API_KEY is not set. Add it to app/.env or run: "
            "export OPENAI_API_KEY=sk-...")

    try:
        from openai import OpenAI
    except ImportError:
        die("The 'openai' package is missing. Run: pip install --user openai")

    client = OpenAI(api_key=key)

    est = estimate_cost_usd(len(kinds))
    if est is not None:
        print(f"Estimated image cost: ~${est:.2f} USD for {len(kinds)} "
              f"image(s) at {GEN_SIZE}/{GEN_QUALITY}.\n")

    for kind in kinds:
        raw = generate_raw(kind, client)
        if args.raw_only:
            continue
        aligned = align_to_canvas(kind, raw)
        if write_base:
            BASE_DIR.mkdir(parents=True, exist_ok=True)
            dest = BASE_DIR / f"body-{kind}.png"
            dest.write_bytes(aligned.read_bytes())
            print(f"[{kind}] FORCE-installed over artist body -> {dest}")

    print("\nDone. Review the images in tools/out/.")
    if write_base:
        print("WARNING: artist bodies in base/ were overwritten. Re-import with "
              "import_character_art.py if you need them back.")


if __name__ == "__main__":
    main()
