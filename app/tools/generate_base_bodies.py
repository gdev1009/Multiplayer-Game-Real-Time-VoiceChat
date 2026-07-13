#!/usr/bin/env python3
"""
Generate the two Match Word base bodies with OpenAI's image model, then align
each to the Character Studio safe-zone landmarks and export spec-perfect PNGs:

    app/assets/images/character/base/body-female.png
    app/assets/images/character/base/body-male.png

Each output is 1254 x 1254, transparent, front-facing, centered, with the figure
registered so head-top ~ y90 and feet ~ y1200 (matches SAFE-ZONES.md).

SECURITY
--------
The API key is read from the OPENAI_API_KEY environment variable, falling back
to the app's local .env file. The key is never printed or written by this tool.
Rotate the key at https://platform.openai.com/api-keys.

USAGE
-----
    cd app
    python3 -m pip install --user openai pillow numpy      # one-time
    export OPENAI_API_KEY="sk-...your-key..."
    python3 tools/generate_base_bodies.py                  # both bodies
    python3 tools/generate_base_bodies.py --only female     # just one
    python3 tools/generate_base_bodies.py --raw-only        # skip alignment
    python3 tools/generate_base_bodies.py --no-write-base   # keep out of base/
    python3 tools/generate_base_bodies.py --dry-run         # print prompt+cost, spend nothing

Outputs land in tools/out/ (raw + aligned). Aligned copies are also written into
assets/images/character/base/ unless --no-write-base is given.
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
from pathlib import Path

# ---- Spec ------------------------------------------------------------------
CANVAS = 1254
CENTER_X = 627
HEAD_TOP_Y = 90       # from SAFE-ZONES.md
FEET_BASE_Y = 1200    # from SAFE-ZONES.md
GEN_SIZE = "1024x1024"  # gpt-image-1 square; upscaled to CANVAS on align
GEN_QUALITY = "high"    # gpt-image-1 quality tier

# Approx gpt-image-1 output-image price (USD) per image, by size + quality.
# Source: OpenAI image pricing for gpt-image-1. Update if pricing changes.
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

ROOT = Path(__file__).resolve().parent.parent          # app/
OUT_DIR = Path(__file__).resolve().parent / "out"
BASE_DIR = ROOT / "assets" / "images" / "character" / "base"


def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_api_key() -> str | None:
    """Return the OpenAI key from the environment, falling back to the app's
    local .env file. The key is never printed or written anywhere."""
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
    """Show exactly what would be sent and the estimated spend. No API calls."""
    print("DRY RUN \u2014 no API calls, no charges.\n")
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
        print("estimated cost: unknown (no price entry for this size/quality)")
    else:
        print(f"estimated cost: ~${est:.2f} USD "
              f"(~${est / max(1, len(kinds)):.3f} per image, output tokens extra)")
    print("\nNote: this is an estimate of the image output price only. Actual "
          "billing also includes a small text-input token charge and may vary "
          "with OpenAI pricing. Remove --dry-run to generate for real.")


def generate_raw(kind: str, client) -> Path:
    """Call the image API and save the raw transparent PNG."""
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
    """Trim to the opaque figure, scale so head-top->feet map to the landmark
    lines, and center on the 1254x1254 canvas."""
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

    target_h = FEET_BASE_Y - HEAD_TOP_Y          # 1110 px
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
    print(f"[{kind}] aligned -> {aligned}  (figure {new_w}x{new_h}, "
          f"head_top y={paste_y}, feet y={paste_y + new_h})")
    return aligned


def main():
    ap = argparse.ArgumentParser(description="Generate Match Word base bodies.")
    ap.add_argument("--only", choices=["female", "male"], help="generate one")
    ap.add_argument("--raw-only", action="store_true",
                    help="only generate; skip landmark alignment")
    ap.add_argument("--no-write-base", action="store_true",
                    help="do not copy aligned PNGs into assets/.../base/")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the exact prompt(s) and estimated cost, then "
                         "exit without calling the API or spending anything")
    args = ap.parse_args()

    kinds = [args.only] if args.only else ["female", "male"]

    if args.dry_run:
        print_dry_run(kinds)
        return

    key = load_api_key()
    if not key:
        die("OPENAI_API_KEY is not set. Add it to app/.env or run: "
            "export OPENAI_API_KEY=sk-...")

    try:
        from openai import OpenAI
    except ImportError:
        die("The 'openai' package is missing. Run: pip install --user openai")

    client = OpenAI(api_key=key)  # key sourced from env or app/.env

    est = estimate_cost_usd(len(kinds))
    if est is not None:
        print(f"Estimated image cost: ~${est:.2f} USD for {len(kinds)} "
              f"image(s) at {GEN_SIZE}/{GEN_QUALITY}.\n")

    for kind in kinds:
        raw = generate_raw(kind, client)
        if args.raw_only:
            continue
        aligned = align_to_canvas(kind, raw)
        if not args.no_write_base:
            BASE_DIR.mkdir(parents=True, exist_ok=True)
            dest = BASE_DIR / f"body-{kind}.png"
            dest.write_bytes(aligned.read_bytes())
            print(f"[{kind}] installed -> {dest}")

    print("\nDone. Review the images in tools/out/ (and base/ if installed).")
    print("Reminder: rotate your OpenAI API key now that generation is complete.")


if __name__ == "__main__":
    main()
