# Prompts and settings

Replace the `{PLACEHOLDERS}`. Keep the **style header** word-for-word in every generation so all characters share one look.

## 0. Tool settings (any image model)

| Setting | Value |
|---|---|
| Aspect / size | single pose: 1024x1024 (1:1). Full sheet: 2048x1536 (4:3) |
| Style | high realism, "3D character render"; not painterly, not anime |
| Seed | fix the seed for all poses of one character; change only the pose line |
| Reference | always attach the approved character reference image (identity and outfit lock), weight high (about 0.8) |
| Guidance / CFG | medium-high (6-8 for SD-type models); follow the pose line strictly |
| Variations | generate 4 per pose, pick the cleanest silhouette |
| Output | PNG; no upscaler that alters the face |
| Background | flat chroma green #00B140 |

## 1. Style header (paste at the start of every prompt)

```
Photorealistic 3D-rendered video game fighter, full body, centered, shown from a flat side-on camera at chest height, character facing screen-right, soft even studio lighting, high detail fabric and skin, athletic proportions, subtly stylised and slightly caricatured face that stays recognisable, clean silhouette, isolated on a flat pure green (#00B140) background, no floor, no shadow, no text, no logo, no watermark, no frame.
```

## 2. One-shot sheet prompt (workflow A)

```
{STYLE HEADER}
A character sheet laid out as a strict grid of 4 columns by 3 rows, 12 equal cells, same character in every cell:
{CHARACTER DESCRIPTION}
Same face, same outfit, same colours, same lighting and camera in all cells. Every figure fully inside its own cell with padding, all facing right.
Row 1: (1) idle fighting guard, (2) walking, front foot landing, (3) walking, legs passing, (4) deep crouching guard.
Row 2: (5) jab, front fist fully extended, no kick, (6) cross punch, rear fist extended with hip rotation, (7) high front kick with fully extended leg, (8) high block with forearms crossed in front of the face.
Row 3: (9) hit recoil, head snapped back, (10) falling backward in mid-air, (11) lying on the back on the floor, (12) getting up from one knee.
```

## 3. Character reference prompt (workflow B, step 1)

```
{STYLE HEADER}
Character turnaround reference: three views of the same fighter side by side (front, three-quarter right, side right), neutral standing guard, full body, same height in all three.
{CHARACTER DESCRIPTION}
```

`{CHARACTER DESCRIPTION}` template (fill every field; it keeps the roster consistent):

```
{age range} {gender presentation} fighter, {height and build, e.g. 180 cm lean athletic}, {skin tone}, {hair: colour, length, style}, {facial hair}, {distinctive face features}, wearing {top}, {bottoms}, {shoes}, {gloves or wraps}, {one signature accessory}, colour palette: {3 colours max, name each}.
```

## 4. Per-pose prompt (workflow B, step 2)

Prompt = `{STYLE HEADER} {CHARACTER DESCRIPTION}` plus exactly one of these lines (the attached reference locks identity):

| # | Pose line |
|---|---|
| 1 | `Idle fighting stance, both fists raised near the chin, knees slightly bent, weight centred, feet shoulder-width apart.` |
| 2 | `Mid-walk, front foot just touching the ground, rear heel lifted, arms in guard swinging slightly.` |
| 3 | `Mid-walk, legs passing under the body, body slightly higher, arms in guard.` |
| 4 | `Deep crouching guard, hips low, both hands raised in front of the face, rear knee bent.` |
| 5 | `Jab: lead fist fully extended forward at chest height, rear fist guarding the chin, both feet on the ground, no leg raised.` |
| 6 | `Cross punch: rear fist fully extended forward, hips and shoulders rotated into the punch, deeper lunge, both feet on the ground.` |
| 7 | `High front kick: standing leg planted, kicking leg fully extended forward at head height, torso leaning back slightly, fists up.` |
| 8 | `High block: both forearms crossed in front of the face, elbows tight, bent knees, braced.` |
| 9 | `Hit reaction: head snapped back, torso leaning away from the opponent, eyes squeezed, arms thrown out, still standing.` |
| 10 | `Falling backward through the air, body tilted about 45 degrees, arms flailing, feet leaving the ground.` |
| 11 | `Lying on the back on the ground, completely flat, limbs loose, head turned toward the camera, knocked out.` |
| 12 | `Getting up: one knee on the ground, one hand pushing off, head raised, determined expression.` |

## 5. Negative prompt (models that support it)

```
cropped, cut off feet, cut off hands, multiple characters, extra limbs, extra fingers, deformed hands, wrong anatomy, facing left, back view, text, letters, logo, watermark, signature, frame, border, floor, cast shadow, ground plane, background scenery, motion blur, blurry, low resolution, painting, cartoon, anime, flat colours, different outfit, different face, green clothing
```

## 6. Portrait prompt (roster and VS screen)

```
{STYLE HEADER, replacing "full body ... side-on camera" with "bust portrait, head and shoulders, three-quarter view facing right"} {CHARACTER DESCRIPTION} intense confident fighting expression, rim light.
```

## 7. Fix-up prompts (when one pose is off)

- Wrong direction: mirror the image horizontally.
- Jab showing a kick: regenerate adding `both feet planted flat on the ground, no leg lifted`.
- Cropped limb: regenerate adding `wide framing, 15% empty space on every side`.
- Identity drift: raise the reference weight and reuse the original seed; never repaint the face by hand per frame.

## 8. Archetype description presets (engine stat templates, art cues only)

| Archetype | Build and look cue to add to `{CHARACTER DESCRIPTION}` |
|---|---|
| Rushdown | lean, light, tight sporty clothing, fast-looking, forward-leaning stance |
| Tank | broad, heavy, thick armour or padding, planted stance |
| Zoner | tall, long limbs, loose clothing, tool or gadget accessory |
| Counter | medium build, calm posture, layered clothing, a protective accessory |
| Acrobat | very flexible look, light shoes, ribbons or scarf for motion |
