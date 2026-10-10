# UI and combat polish implementation plan

## Goal

Replace the split roster menu with cinematic title art and floating actions, make fighter selection face-readable, align the Knesset chamber floor, freeze all match progression during pause, ground jump shadows and make damage and special feedback unambiguous.

## Work items

- [x] Generate two 16:9 title-art candidates with protected menu space.
- [x] Add a full-screen hero background and floating text menu.
- [x] Derive dedicated face-focused portraits for all 13 fighters.
- [x] Use those portraits in selection tiles and the HUD.
- [x] Add a Knesset chamber background alignment value.
- [x] Keep shadows on the world floor during jumps.
- [x] Mark the lower HUD bar as Special Energy and show percentage and readiness.
- [x] Prevent timers and round transitions from advancing while paused.
- [x] Add regression coverage for damage, hit reaction, shadow, pause, stage alignment and UI structure.
- [x] Run the full headless suite and visual screen review.
- [x] Commit and push the complete project to the new GitHub repository.

## 2026-10-08 result, mobile and Chrome correction

- [x] Move `YOU WIN / YOU LOSE` and result actions into a compact left corner card so the live celebration remains visible.
- [x] Play normal match celebrations at 55% speed in the match and Fighter Lab.
- [x] Lock the defeated fighter on the final knockdown frame for ordinary KOs and celebration playback.
- [x] Make an eligible phone `MAX` tap launch the finisher immediately; keep a non-eligible tap as the 55-energy special attack.
- [x] Refine the phone joystick with directional guides and align the `MAX`, `CROSS`, `JAB`, `SP` and `GUARD` cluster to the supplied reference.
- [x] Keep the segmented cyan/red health HUD, central timer and explicitly labelled gold `SPECIAL ENERGY` bars.
- [x] Add a Chrome-only HTML start menu backed by a Godot JavaScript bridge so startup actions remain available even when Chrome fails to display the canvas controls.
- [x] Add regression coverage for celebration speed and visibility, lethal knockdown, touch MAX behavior and the patched Chrome shell.
- [x] Inspect new HUD and result captures at 1280×720.
