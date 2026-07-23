# Character art drop-in spec (premium, 3D-style)

This is the **artist brief** for the Character Studio. Match this exactly and
the parts load automatically — no code changes needed. Until real art arrives,
the app draws clay-styled vector placeholders so everything stays testable.

The look we're matching: a soft, rounded, **3D clay-render** style (think The
Sims / Toca Boca), consistent with the two body renders already in
`base/body-female.png` and `base/body-male.png`.

---

## 1. Global rules (every part)

| Rule            | Value                                                        |
| --------------- | ----------------------------------------------------------- |
| Format          | **PNG, 32-bit, transparent background** (no JPEG)           |
| Canvas          | **1254 × 1254 px, square** — identical for every file       |
| View            | **Front, centered**, same as the delivered bodies           |
| Alignment       | Draw each part **in place over the body** so it stacks 1:1  |
| Style           | 3D clay render: soft shadows, rounded forms, gentle sheen   |
| Scale           | One part per file; do **not** trim/crop — keep full canvas  |

> The engine draws parts with `BoxFit.contain` on a square stage, so a part at
> pixel (x, y) on the 1254 canvas lands at that same spot on the character.
> **Do not reposition or resize between files** — that's what keeps hair, eyes,
> glasses and outfits registered on the face/body.

---

## 2. Two bodies → two options per part

The woman and man renders have **different head and body positions**, so each
accessory needs a version aligned to each body. Name them with a body suffix:

```
<id>__body-female.png     ← aligned to the woman
<id>__body-male.png       ← aligned to the man
```

Example: `hair-short__body-female.png` and `hair-short__body-male.png`.

The engine loads in this order and uses the first it finds:

1. `<id>__<body>.png` — body-specific (preferred, best fit)
2. `<id>.png` — one shared file (OK if a part sits identically on both)
3. built-in vector placeholder

So: deliver **body-specific files** for hair, eyes, glasses and outfits.
A single shared `<id>.png` is only fine for parts that overlap both heads
identically (rare).

---

## 3. Tintable vs full-colour parts

Some layers are **recoloured in-app** so one neutral render covers many colours.

| Layer   | Tinted? | Deliver as…                                                    |
| ------- | ------- | ------------------------------------------------------------- |
| base    | yes (skin) | **Light / near-white** clay shading; app multiplies tone   |
| hair    | yes (hair) | **Neutral light-grey** hair; app multiplies the colour     |
| eyes    | yes (eyes) | **Neutral/grey iris**; app multiplies the colour           |
| glasses | no       | **Full colour** (frames already coloured)                     |
| outfit  | no       | **Full colour** (each outfit is its own garment)              |

**How tint works:** the app uses *multiply* blending. So a tintable part must be
painted **light** (whites/light greys) with the shading baked in — the colour is
multiplied on top. If you paint hair dark brown, tinting to blonde won't work.
Paint it light grey with soft shadows; the app makes it brown/blonde/black/etc.

Colours the app offers (for your reference; you only supply neutral art):

- **Skin:** Light, Medium, Tan, Deep
- **Hair:** Black, Brown, Auburn, Blonde, Grey, White
- **Eyes:** Brown, Hazel, Green, Blue, Grey

---

## 4. Exact file list

Deliver each as `…__body-female.png` **and** `…__body-male.png`.

### base/ — required (already delivered)
- `body-female.png` (1254², light clay woman)
- `body-male.png` (1254², light clay man)

### hair/ — tintable, light-grey neutral
- `hair-spiky` (already delivered as `hair-spiky.png`)
- `hair-short`
- `hair-curly`
- `hair-bun`
- `hair-long`

### eyes/ — tintable, neutral iris
- `eyes-round`
- `eyes-almond`
- `eyes-wide`

### glasses/ — full colour
- `glasses-round`  (thin dark round frames)
- `glasses-square` (purple square frames)
- `glasses-gold`   (gold metal frames)

### outfit/ — full colour, full garment (top + bottom together)
- `outfit-blue`   (blue suit + trousers)
- `outfit-rose`   (rose dress / skirt)
- `outfit-green`  (green top + shorts)
- `outfit-purple` (purple set + trousers)
- `outfit-sunny`  (sunny tee + shorts)
- `outfit-teal`   (teal hoodie + trousers)

---

## 5. Delivery checklist

- [ ] Every file **1254 × 1254**, transparent PNG.
- [ ] Two files per part: `__body-female` and `__body-male`.
- [ ] Tintable parts (hair, eyes) painted **light/neutral**, shading baked in.
- [ ] Glasses & outfits **full colour**.
- [ ] Nothing cropped or re-centered — parts align to the shared bodies.
- [ ] One quick composite per body showing all parts stacked, so we can verify
      registration before final export.

To add **new** styles later: pick a new id (e.g. `hair-wavy`), add one line in
`app/lib/features/character/character_catalog.dart`, and drop the matching PNGs
here. That's the only code touch needed.
