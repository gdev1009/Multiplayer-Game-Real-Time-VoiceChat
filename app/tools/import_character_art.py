#!/usr/bin/env python3
"""Import the artist's real character art (All (1)) into the app's character
asset tree with clean, stable option ids.

Run from the app/ directory:  python3 tools/import_character_art.py
"""
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # app/
SRC = os.path.join(ROOT, "assets", "images", "All (1)")
DST = os.path.join(ROOT, "assets", "images", "character")

# Per-asset vertical nudges (destination id -> pixels to move UP on the 1254
# canvas). A few source garments are drawn a little lower than the rest, so
# their collar/shoulders leave the body's shoulders bare. Nudging them up aligns
# them with the other outfits. Applied after copying so re-imports stay fixed.
NUDGE_UP = {
    # The navy blazer sits ~38px lower than the other male outfits, exposing the
    # shoulders; lift it so the collar meets the neck like the rest.
    "outfit-m4": 38,
}

# (source-relative-path, destination folder, destination id)
MAP = [
    # ----- base bodies -----
    ("Female All/Main Female.png", "base", "body-female"),
    ("Male all/Main Main character.png", "base", "body-male"),

    # ----- female hair (8) -----
    *[(f"Female All/Feamale hair/{i}.png", "hair", f"hair-f{i}") for i in range(1, 9)],
    # ----- male hair (4) -----
    *[(f"Male all/Male Hair/{i}.png", "hair", f"hair-m{i}") for i in range(1, 5)],

    # ----- female outfits (7) -----
    *[(f"Female All/Female Outfit/{i}.png", "outfit", f"outfit-f{i}") for i in range(1, 8)],
    # ----- male outfits (6) -----
    ("Male all/Male outfit/body-male1.png", "outfit", "outfit-m1"),
    ("Male all/Male outfit/body-male2.png", "outfit", "outfit-m2"),
    ("Male all/Male outfit/body-male 3.png", "outfit", "outfit-m3"),
    ("Male all/Male outfit/body-male4.png", "outfit", "outfit-m4"),
    ("Male all/Male outfit/body-male 5.png", "outfit", "outfit-m5"),
    ("Male all/Male outfit/body-male6.png", "outfit", "outfit-m6"),

    # ----- female glasses (4) -----
    ("Female All/Accsesoricess Female/Cat-Eye Glasses female.png", "glasses", "glasses-f-cateye"),
    ("Female All/Accsesoricess Female/Rectangular Glasses Female.png", "glasses", "glasses-f-rect"),
    ("Female All/Accsesoricess Female/Rounded Glass Female.png", "glasses", "glasses-f-round"),
    ("Female All/Accsesoricess Female/Square Glass Female.png", "glasses", "glasses-f-square"),
    # ----- male glasses (4) -----
    ("Male all/Accsesoricess Male/Cat-Eye Glasses Male.png", "glasses", "glasses-m-cateye"),
    ("Male all/Accsesoricess Male/Rectangular Glasses Male.png", "glasses", "glasses-m-rect"),
    ("Male all/Accsesoricess Male/Rounded Glass Male.png", "glasses", "glasses-m-round"),
    ("Male all/Accsesoricess Male/Square-Glass-Male.png", "glasses", "glasses-m-square"),

    # ----- female hats (4) -----
    ("Female All/Accsesoricess Female/Cozy Knit Hat Female.png", "hat", "hat-f-knit"),
    ("Female All/Accsesoricess Female/Elegant Small Brim Hat Female.png", "hat", "hat-f-brim"),
    ("Female All/Accsesoricess Female/Simple Cap Female.png", "hat", "hat-f-cap"),
    # (the sun hat was misfiled in the Male folder but is a woman's hat)
    ("Male all/Accsesoricess Male/Soft-Sun-Hat-Female.png", "hat", "hat-f-sun"),
    # ----- male hats (3) -----
    ("Male all/Accsesoricess Male/Cozy Knit Hat Male.png", "hat", "hat-m-knit"),
    ("Male all/Accsesoricess Male/Elegant Small Brim Hat Male.png", "hat", "hat-m-brim"),
    ("Male all/Accsesoricess Male/Simple Cap Male.png", "hat", "hat-m-cap"),

    # ----- earrings (4, shared) -----
    *[(f"Earring/{i}.png", "earrings", f"earring-{i}") for i in range(1, 5)],

    # ----- female held items (5) -----
    ("Female All/Accsesoricess Female/Crossbody Bag Female.png", "accessory", "acc-f-crossbody"),
    ("Female All/Accsesoricess Female/Simple Carrying Tote Female.png", "accessory", "acc-f-tote"),
    ("Female All/Accsesoricess Female/Small Purse Female.png", "accessory", "acc-f-purse"),
    ("Female All/Accsesoricess Female/Female kane.png", "accessory", "acc-f-cane"),
    ("Female All/Accsesoricess Female/Female walker.png", "accessory", "acc-f-walker"),
    # ----- male held items (4) -----
    ("Male all/Accsesoricess Male/Crossbody Bag Male.png", "accessory", "acc-m-crossbody"),
    ("Male all/Accsesoricess Male/Simple Carrying Tote Male.png", "accessory", "acc-m-tote"),
    ("Male all/Accsesoricess Male/Cane male.png", "accessory", "acc-m-cane"),
    ("Male all/Accsesoricess Male/Male walker.png", "accessory", "acc-m-walker"),
]


def main():
    copied, missing = 0, []
    for rel, folder, dst_id in MAP:
        src = os.path.join(SRC, rel)
        dst_dir = os.path.join(DST, folder)
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, dst_id + ".png")
        if not os.path.exists(src):
            missing.append(rel)
            continue
        shutil.copyfile(src, dst)
        copied += 1
        dy = NUDGE_UP.get(dst_id)
        if dy:
            img = Image.open(dst).convert("RGBA")
            out = Image.new("RGBA", img.size, (0, 0, 0, 0))
            out.alpha_composite(img, (0, -dy))
            out.save(dst)
            print(f"  nudged {dst_id} up {dy}px to cover the shoulders")
    print(f"copied {copied} files")
    if missing:
        print("MISSING sources:")
        for m in missing:
            print("  -", m)
    # report per-folder counts
    for folder in ["base", "hair", "outfit", "glasses", "hat", "earrings", "accessory"]:
        d = os.path.join(DST, folder)
        n = len([f for f in os.listdir(d) if f.endswith(".png")]) if os.path.isdir(d) else 0
        print(f"  {folder}: {n} png")


if __name__ == "__main__":
    main()
