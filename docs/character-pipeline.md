# Fighter Asset Contract

Use this contract for every fighter added to World Fight.

## Required source asset

- One transparent PNG sheet.
- Exactly 4 columns by 3 rows.
- Full body, including feet and accessories, inside every cell.
- All poses face screen-right.
- Same identity, outfit, lighting and camera in all cells.
- No floor, shadow, grid, labels or text.

## Fixed pose order

1. Idle guard
2. Walk contact
3. Walk passing
4. Crouching guard
5. Jab
6. Cross
7. Signature kick
8. High block
9. Hit recoil
10. Falling backward
11. Grounded knockdown
12. Getting up

## Integration checklist

For additional cinematic poses, `figure_height_px` measures head-to-foot body height. Exclude raised hands, weapons, flags and other accessories from that measurement; keep the entire pose in its atlas region. `foot_baseline` still marks the boots within the region. This preserves body scale when switching to an uppercut or victory pose.

1. Save the sheet as `assets/characters/sprite-sheets/new-roster/<id>-sheet.png`.
2. Add `<id>` to `FIGHTER_GEOMETRY` in `scripts/fighter_visual.gd` with `height_m`, `pixel_scale` and `ground_offset_m`.
3. Add `<id>` to `TWELVE_FRAME_IDS`.
4. Run `python tools/slice_sprite_sheets.py`.
5. Add the fighter data and ID to `scripts/main.gd` and `scripts/character_debug.gd`.
6. Run the Python slicing tests and all Godot tests.
7. Capture Sprite Lab, selection and combat at 1280x720. Verify visible height, feet touching the floor, direction, name fit and all twelve poses.

The slicer uses one shared scale across all poses, keeps transparent edge padding and aligns standing frames to a common foot baseline. It assigns complete connected alpha components across the full sheet instead of cropping each 4x3 cell independently, so a hand, boot, coat or accessory that crosses a grid line stays with its real pose. Remote pieces from neighbouring poses must be rejected. Do not manually stretch individual animation frames.

In Sprite Lab, trigger JAB, CROSS, KICK, GUARD, HIT, FALL, GET UP and JUMP in both directions. Every normalized frame must keep at least 99.9% of its visible alpha in the primary silhouette and keep its lowest real foot on the shared floor line.
