# Base Body Generation — AI Tool Guide (Match Word)

**Goal:** produce **2 official base bodies** (female + male) for the Match Word
Character Studio, in the warm **Guy Smiley clay style** (bigger, rounder heads),
each **1254 × 1254 px, transparent PNG, front-facing, centered**, that become the
master reference the Fiverr artist paints against.

This guide covers: which AI tool to use and why, the exact step-by-step process,
copy-paste prompts, and how to post-process the output to hit the spec.

---

## 0. TL;DR (the fast path)

1. Generate the character in **ChatGPT (GPT-4o image generation)** or **Midjourney v6** — both are best-in-class for the soft 3D clay look.
2. Ask for a **full-body, front-facing, T-pose-ish, plain flat background** render.
3. Remove the background (transparent) — the model rarely gives clean alpha, so use **remove.bg** or Photopea.
4. Place it on a **1254 × 1254** transparent canvas, centered, using the landmark
   lines in `app/assets/images/character/SAFE-ZONES.md`.
5. Do the same twice with **one consistent prompt** so the two bodies match.

---

## 1. Which tool? (recommendation + comparison)

**Primary recommendation: ChatGPT (GPT-4o native image generation).**
Best balance of style control, consistency between the two bodies (you can say
"same style, now male"), and plain-language iteration. Ideal here because you
need **two matching characters**, not one hero image.

**Strong alternative: Midjourney v6.** The most beautiful clay/3D render quality,
but consistency between two separate generations is harder and it has a learning
curve (Discord + parameters).

| Tool | Clay-style quality | 2-body consistency | Transparent PNG | Ease | Cost | Best for |
| --- | --- | --- | --- | --- | --- | --- |
| **ChatGPT / GPT-4o** | Excellent | **Excellent** (conversational "same but male") | No (post-process) | **Easiest** | ~US$20/mo Plus | **Recommended** — matched pair |
| **Midjourney v6** | **Best** | Medium (needs `--cref`, seeds) | No (post-process) | Medium | US$10–30/mo | Highest visual polish |
| **Leonardo.ai** | Very good | Medium | Some models | Medium | Free tier + paid | Budget, 3D-render presets |
| **Adobe Firefly** | Good | Medium | **Yes (native)** | Easy | Adobe sub / credits | If you want native alpha |
| **Meshy / Tripo (3D)** | N/A (true 3D) | High | Yes (renders) | Hard | Freemium | Only if you later want real 3D models |

> Honesty note: none of these output a game-ready transparent PNG at an exact
> pixel size in one click. The AI makes the *artwork*; you (or a 10-minute
> post-process) put it on the 1254² transparent canvas. That's normal and fast.

**My pick for you:** **ChatGPT Plus (GPT-4o)** for generation + **remove.bg** and
**Photopea** (free) for cleanup and canvas placement. The rest of this guide uses
that path, with Midjourney notes where it differs.

---

## 2. What "good" looks like (acceptance checklist)

Before generating, know the target so you can reject bad outputs fast:

- [ ] **Full body** visible head-to-feet, **front-facing**, arms slightly away
      from the body (so the artist can add outfits cleanly).
- [ ] **Bigger, rounder head** — cute Guy Smiley / Sims proportions (head roughly
      1/4 to 1/3 of total height, not realistic 1/7).
- [ ] **Warm clay render** — soft matte "clay/putty" material, gentle top light,
      soft contact shadow, rounded forms, subtle sheen.
- [ ] **Neutral base** — bald or minimal hair (hair is a separate layer!), simple
      underwear/plain fitted basewear (outfits are a separate layer), neutral skin.
- [ ] **Plain, flat, single-colour background** (makes cut-out clean).
- [ ] **The two bodies match** each other in style, camera, lighting, and scale.

> IMPORTANT: the base body should be **bald / minimal** and wear only plain
> basewear, because hair, glasses, and outfits are painted as **separate layers**
> on top. If the AI gives great hair or clothes, that's actually the *wrong*
> deliverable for the base — keep it plain.

---

## 3. Step-by-step — ChatGPT (GPT-4o) path

### Step 1 — Start the female body
Open ChatGPT (GPT-4o, image generation on). Paste **Prompt A (Female)** from §5.

### Step 2 — Judge & iterate
Check against the §2 checklist. If needed, refine in plain language:
- "Make the head bigger and rounder, more cartoon/clay."
- "Full body, show the feet, arms away from the sides."
- "Plain flat light-grey background, no floor, no props."
- "Remove the hair — make the head bald/smooth. No clothing except plain
  fitted basewear."

### Step 3 — Lock the style, generate the male
Once the female is right, in the **same chat** say:
> "Perfect. Now create the **male** version — **exact same clay style, same
> camera, same lighting, same scale and framing**, just a male body with the same
> bigger rounder head. Keep him bald and in plain basewear on the same flat
> background."

Using the same conversation is what keeps them a matched pair.

### Step 4 — Upscale (optional but recommended)
Ask: "Render/output at the highest resolution you can, at least 1024×1024,
square." (You'll scale to 1254² in post; more pixels = cleaner.)

### Step 5 — Download both PNGs (they'll have a background — that's fine).

---

## 4. Step-by-step — Midjourney v6 path (alternative)

1. In Discord: `/imagine` then paste **Prompt A** + append parameters:
   `--ar 1:1 --style raw --v 6.1`
2. Upscale your favourite (U1–U4).
3. For the male, reuse the **same seed** and character reference:
   - Get the seed (react with ✉️ / envelope on the job).
   - New prompt: same text but "male body", add `--seed <number>` and
     `--cref <url-of-female-image> --cw 60` to carry the style.
4. Download both. (Midjourney has no transparency — go to §6.)

---

## 5. Copy-paste prompts

### Prompt A — Female base body
```
A full-body 3D clay-render character of a friendly woman, front view, standing
straight and symmetrical, arms relaxed but slightly away from the body, feet
together and fully visible. Cute stylized proportions with a BIG ROUND HEAD
(head about one third of total height), soft rounded body, warm friendly face,
gentle smile, small nose. Soft matte CLAY / PLASTICINE material with subtle sheen,
smooth surfaces, soft studio top light, soft contact shadow. Bald / no hair,
wearing only plain simple fitted neutral basewear (like a plain leotard),
neutral warm skin tone. Style of a warm, cheerful game-show mascot (think Pixar /
The Sims / Toca Boca clay look). PLAIN FLAT LIGHT-GREY BACKGROUND, no floor lines,
no props, no text. Centered, whole body inside frame with headroom and footroom.
Square image.
```

### Prompt B — Male base body (use AFTER the female, same chat)
```
Now the MALE version — EXACTLY the same clay-render style, same camera angle,
same lighting, same scale and framing, same plain flat light-grey background.
A friendly man with the same BIG ROUND HEAD cartoon proportions, soft rounded
body, warm friendly face, gentle smile. Bald / no hair, wearing only plain simple
fitted neutral basewear (plain shorts), neutral warm skin tone. Front view,
standing straight and symmetrical, arms slightly away from the body, feet fully
visible. Match the woman so they look like a matched pair. Square image.
```

### Style booster (append if the look is too realistic)
```
More stylized and cartoony, softer and rounder, more clay/putty material,
less realistic, bigger head, cuter, warm and playful.
```

### Negative / avoid (Midjourney: add with --no; ChatGPT: say "avoid …")
```
avoid: realistic human proportions, small head, hair, hairstyle, hat, detailed
clothing, logos, text, watermark, busy background, floor, shadows on wall,
multiple characters, side view, cropped feet, harsh lighting.
```

> A ready-to-paste copy of all prompts lives in `docs/base-body-prompts.txt`.

---

## 5.5 Midjourney parameter cheat-sheet

Only needed if you go the Midjourney route.

| Parameter | What it does | Use for the bodies |
| --- | --- | --- |
| `--ar 1:1` | Aspect ratio | Always — square canvas |
| `--v 6.1` | Model version | Latest, best clay quality |
| `--style raw` | Less "auto-beautify" | Truer to your prompt |
| `--s 100` (`--stylize`) | Stylization strength (0–1000) | Keep low–mid (~50–150) so it obeys "big round head" |
| `--seed <n>` | Fixes randomness | **Reuse the female's seed for the male** so they match |
| `--cref <url>` | Character reference | Point the male at the female image URL |
| `--cw 60` | Character-ref weight (0–100) | ~60 carries style but allows a male body |
| `--no <things>` | Negatives | `--no hair, hat, text, props, floor, realistic proportions, small head` |
| `--q 2` (`--quality`) | Render detail | Optional, cleaner result |

**Getting the seed:** after a job finishes, react to it with the ✉️ (envelope)
emoji; the bot DMs you the seed number. Put that number in the male prompt's
`--seed`.

**Consistency recipe (male after female):**
`<male prompt text> --ar 1:1 --v 6.1 --style raw --seed <female_seed> --cref <female_image_url> --cw 60 --no hair, hat, text, props, floor, realistic proportions, small head`

---

## 6. Post-processing to the exact spec (free, ~10 min each)

You now have two nice renders on a background. Turn each into a
**1254 × 1254 transparent PNG, centered** on the landmark lines.

### 6a. Remove the background
- Easiest: **remove.bg** (drag the image in → download the transparent PNG).
- Free alternative: **Photopea** (photopea.com, works in browser, like Photoshop):
  Select Subject → invert → delete background → export PNG.

### 6b. Place on the 1254² canvas (Photopea)
1. **File → New**: 1254 × 1254 px, **transparent** background.
2. **File → Open & Place** your cut-out body.
3. Scale/position so it lines up with the master landmarks from
   `app/assets/images/character/SAFE-ZONES.md`:
   - Head top ≈ **y 90**, eye line ≈ **y 250**, shoulders ≈ **y 470**,
     hip/hem ≈ **y 860**, feet baseline ≈ **y 1200**.
   - Horizontally centered on **x = 627**; keep everything inside the **70 px**
     safe margin.
   - Tip: open `reference/safe-zone-guide.png` as a top layer at low opacity and
     nudge the body until it matches the lines. Delete the guide layer before export.
4. **File → Export as → PNG.** Name them exactly:
   - `body-female.png`
   - `body-male.png`

### 6c. Sanity-check the file
- Must be **1254 × 1254**, **PNG**, with a **transparent** background.
- Both bodies should share the same head height and feet baseline so parts
  register on both.

---

## 7. Where the files go

Drop the two finished PNGs into:
```
app/assets/images/character/base/body-female.png
app/assets/images/character/base/body-male.png
```
That's it — the app picks them up automatically (no code changes). Send me a
ping and I'll rebuild the artist pack + composite previews with the final bodies.

---

## 8. Cost & time expectations

- **ChatGPT Plus**: ~US$20/month (cancel anytime). Generation: minutes.
- **remove.bg**: free for a couple of images; ~US$0.20–0.90/image after, or use
  Photopea free.
- **Photopea**: free.
- Total realistic effort: **~1–2 hours** for a clean, matched pair including
  iteration and canvas placement.

---

## 9. If you'd rather not do the cut-out yourself

Generate the two raw images (with backgrounds) in ChatGPT/Midjourney and send
them to me. I can do the background removal + 1254² canvas placement against the
safe-zone lines and hand you final, spec-perfect `body-female.png` /
`body-male.png`. Your call — whichever is easier for you.
