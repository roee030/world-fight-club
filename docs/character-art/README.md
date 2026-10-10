# Character art: specification for AI image tools

Everything here feeds the existing sprite pipeline (see `docs/character-pipeline.md`). Read that file too.
The engine never changes per character: a fighter is **one 4x3 sheet + a data file**.

## What the engine needs per fighter

| Item | Spec |
|---|---|
| Sheet | PNG, transparent background, **exactly 4 columns x 3 rows**, recommended **2048 x 1536** (512 x 512 per cell; the existing roster uses this size and a photoreal 3D-render look) |
| Direction | every pose faces **screen-right** |
| Framing | full body (feet and accessories) fully inside its cell, never crossing a cell edge, ~10% padding |
| Consistency | identical face, outfit, colours, lighting, camera height and lens in all 12 cells |
| Floor | no floor, no shadow, no grid, no text, no labels |
| Scale | the same standing height in cells 1-8; lying poses (10-12) keep the same body scale |
| Portrait | 1 extra image: bust, 3/4 view facing right, same character, for roster/VS screens (`tools/build_portraits.py` can derive one from the sheet) |

## The 12 poses, in fixed order (row by row)

| # | Pose | Gameplay meaning | Notes for the image tool |
|---|---|---|---|
| 1 | Idle guard | standing/idle | fists up, knees bent, weight centred |
| 2 | Walk contact | walk frame A | front foot just landed, arms swinging |
| 3 | Walk passing | walk frame B | legs passing, body slightly higher |
| 4 | Crouching guard | crouch / duck | deep crouch, hands up, back leg bent |
| 5 | Jab | light attack | front fist fully extended at chest height. **Must not look like a kick.** |
| 6 | Cross | heavy attack | rear fist extended, hips rotated, deeper lunge |
| 7 | Signature kick | kick, also special | high kick, leg fully extended forward; the only pose with a raised leg |
| 8 | High block | guard | both forearms crossed in front of the face |
| 9 | Hit recoil | hit reaction | head snapped back, body leaning away, eyes squeezed |
| 10 | Falling backward | knockdown start | body airborne, tilting back, arms flailing |
| 11 | Grounded knockdown | lying on floor | on the back, limbs loose |
| 12 | Getting up | get-up | one knee down, pushing up with one hand |

## Two workflows (use B; A is a lottery)

**A. One-shot sheet.** Paste the sheet prompt (`prompts.md` section 2) and hope all 12 stay consistent. Works only with
strong image models that accept a reference image; expect several regenerations and manual cell fixes.

**B. Reference-then-poses (recommended).**
1. Generate the **character reference** (front, 3/4 and side turnaround on a flat background) until the identity is right.
2. Generate each of the 12 poses separately **with the reference image attached** (same seed, same prompt header, only the
   pose line changes).
3. Remove the background, scale all poses with one shared scale, and paste into the 4x3 grid. The slicer
   (`tools/slice_sprite_sheets.py`) normalises feet and scale afterwards; never stretch individual frames.

## Background and cut-out

Generate on a **flat chroma-green `#00B140` background** (never green clothing or props) or flat neutral grey, then remove
it with a tool that keeps hair and fabric edges (rembg, Photoshop "Select subject", Krita). The final PNG must have a real
alpha channel. Check for green fringes on dark hair and sleeves.

## Acceptance checklist (before a character goes to the engine)

- [ ] 12 cells, 4x3, 2048x1536, alpha present, no background remnants.
- [ ] Same face, outfit and colours in all cells (flip through them quickly).
- [ ] All poses face right; feet visible in poses 1-9 and 12.
- [ ] Jab (5) and cross (6) contain no kicking leg; kick (7) is the only extended leg.
- [ ] No pose crosses a cell border; no cropped fists, boots, hair or accessories.
- [ ] Standing height in cells 1-8 matches within a few pixels.
- [ ] No text, logos, watermarks, floor or cast shadow.
- [ ] Then follow the integration checklist in `docs/character-pipeline.md` and review in Sprite Lab at 1280x720.

## Files in this folder

- `prompts.md`: ready-to-paste prompts, negative prompts and tool settings.
- `personal-fighter-flow.md`: what we do with a real user's selfie, what we tell them, consent and safety rules.
