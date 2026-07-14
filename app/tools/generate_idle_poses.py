#!/usr/bin/env python3
"""
Generate the Milestone 7 idle-pose set by *editing* the CURRENT artist base
bodies — never inventing new ones.

Source of truth (do not replace):
    assets/images/character/base/body-female.png
    assets/images/character/base/body-male.png

Those come from tools/import_character_art.py. Hair / outfit / glasses / hat
layers are registered to them (head-top ≈ y114, feet ≈ y1048). This tool calls
OpenAI images.edit with each body as the input image and re-aligns every
result to the *same* bounding box as that source body, so a pose can stand in
as a temporary base layer under the existing accessories.

Poses (per body):
    tongue, worry, smug, shrug, hairfix, selfie

USAGE
-----
    cd app
    python3 tools/generate_idle_poses.py --dry-run
    python3 tools/generate_idle_poses.py                  # both bodies, all poses
    python3 tools/generate_idle_poses.py --only female --poses tongue,smug
    python3 tools/generate_idle_poses.py --quality medium # cheaper (default)
    python3 tools/generate_idle_poses.py --quality high
    python3 tools/generate_idle_poses.py --no-install     # tools/out/ only

Outputs
-------
    tools/out/poses/{female,male}/{pose}.raw.png
    tools/out/poses/{female,male}/{pose}.png          (aligned)
    assets/images/character/poses/{female,male}/{pose}.png   (installed)
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
from pathlib import Path

CANVAS = 1254
GEN_SIZE = "1024x1024"
DEFAULT_QUALITY = "medium"
MODEL = "gpt-image-1"

IMAGE_PRICE_USD = {
    ("1024x1024", "low"): 0.011,
    ("1024x1024", "medium"): 0.042,
    ("1024x1024", "high"): 0.167,
}

# Pose instructions. Every prompt starts with a shared LOCK preamble so the
# model keeps the same character, clothes, scale and head placement.
POSE_ACTIONS = {
    "tongue": (
        "Change ONLY the facial expression: stick the tongue out playfully, "
        "cheerful eyes. Keep the rest of the face, head, body, arms and feet "
        "exactly as in the source. Head must stay in the exact same place."
    ),
    "worry": (
        "Change ONLY the facial expression: worried / concerned look — raised "
        "inner brows, slightly open mouth. Keep head, body, arms and feet "
        "exactly as in the source. Head must stay in the exact same place."
    ),
    "smug": (
        "Change ONLY the facial expression: a smug, pleased little smirk with "
        "narrowed confident eyes. Keep head, body, arms and feet exactly as in "
        "the source. Head must stay in the exact same place."
    ),
    "shrug": (
        "Raise both shoulders into a gentle shrug and turn the palms slightly "
        "outward (a friendly 'I don't know' gesture). Keep the head in the "
        "exact same place and size. Keep the same face, clothes, colours and "
        "feet position. Subtle motion only — do not lean or step aside."
    ),
    "hairfix": (
        "Raise one hand toward the side of the head as if casually fixing "
        "hair (even though the character is bald — the gesture still reads). "
        "Keep the head in the exact same place and size. Keep the same face, "
        "clothes, colours and feet. Subtle arm motion only."
    ),
    "selfie": (
        "Raise one arm and hand toward the upper corner as if holding a phone "
        "for a selfie (no phone prop — empty hand gesture only). Keep the head "
        "mostly in the same place with a slight lean toward the raised hand. "
        "Keep the same face style, clothes, colours and feet. No props, no "
        "phone, no camera in the image."
    ),
}

LOCK_PREAMBLE = (
    "Edit this EXACT character image. Keep the identical person: same clay "
    "3D-render style, same skin tone, same big round bald head, same face "
    "structure, same body proportions, same clothes and colours, same soft "
    "studio lighting. Fully transparent background, no floor, no props, no "
    "text, no extra accessories. Front view, centered on the same canvas. "
)

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = Path(__file__).resolve().parent / "out" / "poses"
BASE_DIR = ROOT / "assets" / "images" / "character" / "base"
INSTALL_DIR = ROOT / "assets" / "images" / "character" / "poses"

BODIES = {
    "female": BASE_DIR / "body-female.png",
    "male": BASE_DIR / "body-male.png",
}


def die(msg: str, code: int = 1) -> None:
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


def measure_bbox(path: Path) -> tuple[int, int, int, int]:
    """Return (top, bot, left, right) of opaque pixels on a source body."""
    from PIL import Image
    import numpy as np

    im = Image.open(path).convert("RGBA")
    if im.size != (CANVAS, CANVAS):
        die(f"{path.name} must be {CANVAS}x{CANVAS}, got {im.size}")
    alpha = np.array(im)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    if ys.size == 0:
        die(f"{path.name} has no opaque pixels")
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


def prompt_for(pose: str) -> str:
    action = POSE_ACTIONS[pose]
    return f"{LOCK_PREAMBLE}{action}"


def estimate_cost_usd(count: int, quality: str) -> float | None:
    price = IMAGE_PRICE_USD.get((GEN_SIZE, quality))
    return None if price is None else round(price * count, 4)


def print_dry_run(bodies: list[str], poses: list[str], quality: str) -> None:
    count = len(bodies) * len(poses)
    print("DRY RUN — no API calls, no charges.\n")
    print("Source bodies (will NOT be replaced):")
    for b in bodies:
        p = BODIES[b]
        top, bot, left, right = measure_bbox(p)
        print(f"  {p.relative_to(ROOT)}  bbox y={top}..{bot} x={left}..{right}")
    print()
    print(f"model      : {MODEL} (images.edit)")
    print(f"size       : {GEN_SIZE}")
    print(f"quality    : {quality}")
    print(f"fidelity   : high (keep identity of source)")
    print(f"background : transparent")
    print(f"count      : {count} image(s)")
    print(f"bodies     : {', '.join(bodies)}")
    print(f"poses      : {', '.join(poses)}")
    print()
    for pose in poses:
        print(f"----- PROMPT [{pose}] -----")
        print(prompt_for(pose))
        print()
    est = estimate_cost_usd(count, quality)
    if est is None:
        print("estimated cost: unknown")
    else:
        print(f"estimated cost: ~${est:.2f} USD "
              f"(~${est / max(1, count):.3f} per image)")


def edit_pose(body: str, pose: str, client, quality: str) -> Path:
    """Call images.edit with the current base body; save the raw PNG."""
    from PIL import Image

    src = BODIES[body]
    # API accepts common raster sizes; feed a 1024 square crop of the figure
    # on transparent so edit has a clean canvas, but KEEP the full 1254 for
    # identity — OpenAI resize handles it. Pass the source PNG as-is.
    print(f"[{body}/{pose}] editing current {src.name} ...")
    with src.open("rb") as fh:
        resp = client.images.edit(
            model=MODEL,
            image=fh,
            prompt=prompt_for(pose),
            size=GEN_SIZE,
            background="transparent",
            quality=quality,
            input_fidelity="high",
            n=1,
        )
    b64 = resp.data[0].b64_json
    out_dir = OUT_DIR / body
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_path = out_dir / f"{pose}.raw.png"
    raw_path.write_bytes(base64.b64decode(b64))
    # Sanity: ensure RGBA
    Image.open(raw_path).convert("RGBA").save(raw_path)
    print(f"[{body}/{pose}] raw -> {raw_path}")
    return raw_path


def align_to_source(body: str, pose: str, raw_path: Path,
                      src_bbox: tuple[int, int, int, int]) -> Path:
    """Scale+place the edited figure onto the same bbox as the source body."""
    from PIL import Image
    import numpy as np

    top_t, bot_t, left_t, right_t = src_bbox
    target_h = bot_t - top_t + 1
    target_cx = (left_t + right_t) / 2

    im = Image.open(raw_path).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 16)
    if ys.size == 0:
        die(f"[{body}/{pose}] edited image has no opaque pixels")

    top, bot = int(ys.min()), int(ys.max())
    left, right = int(xs.min()), int(xs.max())
    fig = im.crop((left, top, right + 1, bot + 1))

    scale = target_h / fig.height
    new_w = max(1, round(fig.width * scale))
    new_h = max(1, round(fig.height * scale))
    fig = fig.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    paste_x = round(target_cx - new_w / 2)
    paste_y = top_t
    canvas.alpha_composite(fig, (paste_x, paste_y))

    aligned = OUT_DIR / body / f"{pose}.png"
    canvas.save(aligned)
    print(f"[{body}/{pose}] aligned -> {aligned}  "
          f"(matched source bbox y={top_t}..{bot_t})")
    return aligned


def install(body: str, pose: str, aligned: Path) -> Path:
    dest_dir = INSTALL_DIR / body
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / f"{pose}.png"
    dest.write_bytes(aligned.read_bytes())
    print(f"[{body}/{pose}] installed -> {dest.relative_to(ROOT)}")
    return dest


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Generate idle poses by editing the CURRENT base bodies.",
    )
    ap.add_argument("--only", choices=["female", "male"],
                    help="edit only one body")
    ap.add_argument("--poses", default=",".join(POSE_ACTIONS),
                    help="comma-separated pose names "
                         f"(default: {','.join(POSE_ACTIONS)})")
    ap.add_argument("--quality", choices=["low", "medium", "high"],
                    default=DEFAULT_QUALITY,
                    help=f"image quality (default: {DEFAULT_QUALITY})")
    ap.add_argument("--no-install", action="store_true",
                    help="keep results in tools/out/poses only")
    ap.add_argument("--dry-run", action="store_true",
                    help="print prompts + cost; spend nothing")
    args = ap.parse_args()

    bodies = [args.only] if args.only else ["female", "male"]
    poses = [p.strip() for p in args.poses.split(",") if p.strip()]
    unknown = [p for p in poses if p not in POSE_ACTIONS]
    if unknown:
        die(f"Unknown pose(s): {unknown}. "
            f"Known: {', '.join(POSE_ACTIONS)}")

    for b in bodies:
        if not BODIES[b].exists():
            die(f"Missing source body: {BODIES[b]}. "
                "Import artist art first (import_character_art.py).")

    if args.dry_run:
        print_dry_run(bodies, poses, args.quality)
        return

    key = load_api_key()
    if not key:
        die("OPENAI_API_KEY is not set. Add it to app/.env or export it.")

    try:
        from openai import OpenAI
    except ImportError:
        die("The 'openai' package is missing. Run: pip install --user openai")

    client = OpenAI(api_key=key)
    count = len(bodies) * len(poses)
    est = estimate_cost_usd(count, args.quality)
    if est is not None:
        print(f"Estimated image cost: ~${est:.2f} USD for {count} "
              f"edit(s) at {GEN_SIZE}/{args.quality}.\n")

    # Measure each source body once — poses must land on the same bbox.
    bboxes = {b: measure_bbox(BODIES[b]) for b in bodies}
    for b, (t, bot, l, r) in bboxes.items():
        print(f"source {b}: bbox y={t}..{bot} x={l}..{r}  "
              f"(from {BODIES[b].name})")
    print()

    for body in bodies:
        for pose in poses:
            raw = edit_pose(body, pose, client, args.quality)
            aligned = align_to_source(body, pose, raw, bboxes[body])
            if not args.no_install:
                install(body, pose, aligned)

    print("\nDone. Review tools/out/poses/ "
          "(and assets/images/character/poses/ if installed).")
    print("Source bodies in base/ were NOT modified.")


if __name__ == "__main__":
    main()
