# Character Safe-Zone & Registration Guide

**Companion to `ARTIST-BRIEF.md`.** Use this together with the two official base
bodies (`reference/body-female.png`, `reference/body-male.png`) and the visual
overlay `reference/safe-zone-guide.png`.

Everything is drawn on the same **1254 × 1254 px** square, transparent PNG,
**front-facing and centered**. The app draws parts with `BoxFit.contain` on a
square stage, so a pixel at (x, y) on your 1254 canvas lands at that same spot on
the assembled character. **Never reposition or resize between files** — that's
what keeps hair, eyes, glasses and outfits registered on the body.

---

## 1. Master landmarks (target for BOTH bodies)

The two official bodies are built to share these lines, so one set of parts
registers on both. Values are pixels from the **top** of the 1254 canvas.

| Landmark | y (px) | What sits here |
| --- | ---: | --- |
| Head top (crown outline) | **90** | Top of the hair/skull |
| Eye line | **250** | Center of the eyes — the eyes PNG registers to this |
| Chin / jaw | **360** | Bottom of the face |
| Shoulder line | **470** | Top of the shoulders / collar |
| Chest band (top) | **600** | Where the **name-on-shirt** text begins |
| Chest band (bottom) | **700** | Where the name-on-shirt text ends |
| Waist | **760** | Belt line |
| Hip / shorts hem | **860** | Bottom of shorts / top of legs |
| Knee | **1010** | Mid-leg |
| Feet baseline | **1200** | Soles of the feet |

**Vertical center line: x = 627.** The figure is symmetric about this line.

**Safe zone:** keep all artwork inside a **70 px margin** on every edge
(x: 70–1184, y: 70–1184). Nothing important should touch the canvas edge, so
rounded launcher/preview masks never clip it.

---

## 2. Per-layer registration notes

- **hair** — crown follows y≈90; must cover the skull and sit cleanly above the
  eye line (250). Deliver **neutral light-grey**, shading baked in (app tints it).
- **eyes** — center on the **eye line (y=250)**, symmetric about x=627. Deliver a
  **neutral/grey iris** (app tints it).
- **glasses** — bridge sits on the eye line (250), arms toward the ears.
  **Full colour** (frames already coloured).
- **outfit** — top begins around the shoulder line (470); the **chest band
  (600–700)** must stay a relatively flat, unbusy area so the player's name
  renders legibly on the shirt. **Full colour**, full garment (top + bottom).

> The app prints the player's name across the chest band (y 600–700). Please keep
> that zone free of large logos or seams so the name stays readable.

---

## 3. Two bodies, two files per part

The woman and man share the landmark lines above but have slightly different
widths, so each part still needs a version aligned to each body:

```
<id>__body-female.png     ← aligned to the woman
<id>__body-male.png       ← aligned to the man
```

The app loads `<id>__<body>.png` first, then `<id>.png`, then a built-in
placeholder.

---

## 4. Quick self-check before export

- [ ] Canvas exactly **1254 × 1254**, transparent PNG, nothing cropped.
- [ ] Part aligns to the landmark lines above when laid over the matching body.
- [ ] Symmetric about **x = 627** (unless intentionally asymmetric).
- [ ] Inside the **70 px safe margin**.
- [ ] Tintable parts (hair, eyes) painted **light/neutral**; glasses & outfits
      **full colour**.
- [ ] One composite per body (all parts stacked over the body) so we can verify
      registration fast.
