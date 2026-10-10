# Finisher "Super-Move Card" Art Brief

This brief is for an image generator (Midjourney, DALL·E, Flux, Ideogram, …) and for the agent who integrates the results. Each fighter needs **one** illustrated pose. It appears on the full-screen card that opens every finisher (`scripts/ui/super_move_card.gd`).

Until an image exists, the game uses the fighter's transparent cross-punch sprite (frame 5), so the game is complete without these. They are a visual upgrade.

## 1. Deliverable per fighter

| Item | Requirement |
|---|---|
| File path | `assets/finishers/<fighter_id>/super-card.png` (exact name; picked up automatically, no code change) |
| Format | PNG with a **transparent background** (alpha). No frame, no text, no logo, no watermark. |
| Size | 1200 × 1400 px (portrait). The figure fills 85–95% of the height and is centred horizontally. |
| Pose | A dynamic three-quarter "power-up" pose, **facing left** (toward the title on the left of the card). Fists, energy or prop at chest height. Full body or knees-up. |
| Lighting | Strong rim light in the fighter's accent colour, plus a cyan/electric glow on the hands or prop. |
| Style | Stylised, exaggerated **caricature** game art (fighting-game key art). **Not photorealistic.** The face must read as a parody, not a photo. |
| Safety | No blood or gore. No weapon aimed at the viewer or at a person. No real party logos, hate symbols or text. Props are cartoon-like. |

Why: the legal guidance (see the disclaimer in `tools/patch_web_export.py`) relies on obvious satire and caricature and on no depiction of real violence. Keep every image clearly cartoonish.

### Background removal
If the generator cannot output transparency, generate on a flat pure green (`#00FF00`) background. Then remove it (for example `rembg`, Photoshop "Remove background", or remove.bg) and clean the edges, so no green fringe remains.

## 2. Shared prompt

Combine **[shared style]** + **[fighter line]** + **[shared negative]**.

**Shared style:**
> stylized fighting-game character key art, exaggerated political-cartoon caricature, heroic three-quarter power pose facing left, full body, dramatic cyan electric energy crackling around the fists, strong rim lighting, crisp painterly cel-shaded rendering, high contrast, clean silhouette, isolated on a plain flat green background, no text, no logo, game splash art quality, 4k detail

**Shared negative:**
> photorealistic, photograph, real photo face, blood, gore, injury, weapon pointed at viewer, gun aimed at camera, text, letters, watermark, logo, signature, frame, border, extra limbs, deformed hands, cropped feet, multiple characters, busy background

## 3. Fighter lines

Each line describes the costume and personality already used in the game (`assets/characters/<id>-card.png` is the visual reference: attach it as an image reference when the tool supports it). The finisher name is the `display_name` already set in `data/finishers.json`.

| `fighter_id` | Finisher (display name) | Fighter line for the prompt | Accent rim colour |
|---|---|---|---|
| `bibi` | FAMILY BUSINESS | a silver-haired statesman caricature in an ornate royal-blue and gold armoured long coat, regal confident smirk, one fist raised, golden throne motifs on the armour | royal blue + gold |
| `bennet` | STARTUP EXIT | a bald tech-founder caricature in a black tactical shirt and cargo pants, a glowing laptop held like a throwing disc in one hand, pixel sparks swirling | cyan |
| `yair_lapid` | PRIME TIME RUSH | a silver-haired TV-host boxer caricature in blue and white boxing gear with blue gloves, mid-combo punch, studio spotlight flares | white + blue |
| `benny_gantz` | INDEPENDENCE FLAG | a tall silver-haired general caricature in a navy tactical outfit, a large blue-and-white flag on a pole held like a spear, cloth sweeping behind him | blue + white |
| `avigdor` | 48-HOUR COUNTDOWN | a stern grey-bearded politician caricature in a dark suit and a red shirt, an oil barrel balanced on one shoulder, a glowing digital clock showing 48:00 floating behind him | red |
| `mansour_abbas` | COALITION CASHSTORM | a bearded statesman caricature in an ornate green and gold robe with gauntlets, bundles of banknotes swirling around his raised fists | green + gold |
| `gadi_eisenkot` | BAZOOKA COMMAND | a stocky general caricature in an olive uniform and a maroon beret, a chunky cartoon bazooka resting on his shoulder and pointed upward (never at the viewer) | olive + maroon |
| `yair_golan` | FIELD COMMAND | a grey-haired commander caricature with sunglasses in an olive field uniform, one hand raised in a rallying gesture, a cartoon rifle slung safely across his back, protest crowd silhouettes behind | olive + cyan |
| `itamar_ben_gvir` | CROCODILE RELEASE | a curly-haired caricature with glasses and a kippah in an orange tactical vest, three cartoon crocodiles snapping playfully at his feet | orange |
| `bezalel_smotrich` | CATTLE CHARGE | a lean bearded caricature in an orange prison-style jumpsuit with a ranch whistle, cartoon cattle stampeding in dust behind him | orange + dust brown |
| `aryeh_deri` | CAMPAIGN ENTOURAGE | a bearded caricature in a purple and gold robe and a black kippah, a campaign folder raised like a banner, cartoon campaign signs fanning out behind | purple + gold |
| `joint_list` | TWO-HEADED CHAOS | a comic two-headed character in a single brown and teal suit, the two heads arguing and pointing in opposite directions, fists glowing | teal + brown |
| `trump` | B-2 FLYOVER | a blond showman caricature in a navy suit, red tie and red boxing gloves, one finger pointing to the sky where a stylised stealth-bomber silhouette passes | red + navy |

Example full prompt (Mansour Abbas):
> stylized fighting-game character key art, exaggerated political-cartoon caricature, heroic three-quarter power pose facing left, full body, dramatic cyan electric energy crackling around the fists, strong rim lighting, crisp painterly cel-shaded rendering, high contrast, clean silhouette, isolated on a plain flat green background, no text, no logo, game splash art quality, 4k detail — a bearded statesman caricature in an ornate green and gold robe with gauntlets, bundles of banknotes swirling around his raised fists — green and gold rim light. Negative: photorealistic, photograph, real photo face, blood, gore, injury, weapon pointed at viewer, gun aimed at camera, text, letters, watermark, logo, signature, frame, border, extra limbs, deformed hands, cropped feet, multiple characters, busy background

## 4. Integration checklist (for the agent)
1. Save each PNG as `assets/finishers/<fighter_id>/super-card.png` (1200×1400, transparent).
2. Check transparency and edges: no green fringe, and the alpha is clean around the hair and hands.
3. The figure must face **left**. If it faces right, flip the image file. Illustrated art is shown as is; only the fallback sprite is mirrored by code.
4. Run `godot --headless --path . --import` once, so the new textures are imported.
5. Run the full Godot and Python test suites (see `AGENTS.md`).
6. Inspect:
   - Mansour Abbas: open the Web build with `?qa=finisher`.
   - Any other fighter: use Fight Lab (`scenes/character_debug.tscn`), whose `FINISH` button for every fighter shows the card.

   Confirm the art does not cover the title on the left and is not cropped at 568×320, 780×360 and 1280×720.
7. Optional: rename a finisher by editing its `display_name` in `data/finishers.json` (short, 2–3 words, uppercase).
8. Commit the PNGs (they are game assets) and update the delivery record in `docs/superpowers/plans/2026-10-09-presentation-campaign-legal-analytics.md`.

## 5. Optional extras (same style)
- A matching **result-screen victory pose** per fighter: `assets/finishers/<fighter_id>/victory-card.png`. This is not wired yet; the result screen currently shows the live 3D arena. Wiring it is a small task in `_show_result()`.
- A **menu creator card** photo is already in place (`assets/ui/creator.png`).
