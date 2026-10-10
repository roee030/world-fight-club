# Cinematic UI and Sprite Repair Plan

## Goal

Deliver a clean 1280x720 presentation with a cinematic main menu, a complete non-scrolling 13-fighter select grid, reliable sprite frames grounded on the arena floor, an interactive pose lab, and Tekken-inspired combat/result presentation.

## Workstreams

### 1. Sprite extraction and grounding

- Inspect every source sheet for alpha fragments and cell spill.
- Keep meaningful detached body/equipment pieces inside the pose frame.
- Reject fragments that cross into a neighboring pose.
- Normalize all 12 poses with one character scale and one foot baseline.
- Derive in-game ground position from the real normalized alpha bounds.
- Add regression coverage for Bibi and Mansour attack/hit poses.

### 2. Interactive Sprite Lab

- Expose direct controls for idle, movement, jump, attacks, guard, hit, knockdown and recovery.
- Keep fighter switching and direction flipping.
- Display current pose and keyboard mapping on screen.
- Use the same animation mapping as the actual match.

### 3. Main menu and fighter selection

- Remove the roster browser from the main menu.
- Present one full-roster cinematic hero image/lineup behind the three main actions.
- Fit all 13 roster cards into one fixed grid without scroll bars.
- Preserve single player selection and hidden random CPU flow.

### 4. Combat HUD and match result

- Replace the heavy boxed HUD with thin angular health rails, edge portraits and a central timer.
- Keep health, recoverable health, meter and round state readable.
- Show victory/defeat as an arena overlay with large central typography and impact treatment.
- Reveal rematch/menu actions after the result title while retaining the fight image behind it.

### 5. Verification

- Run sprite slicing and geometry tests.
- Run every Godot test.
- Capture main menu, select, HUD, result, Sprite Lab poses, and Bibi/Mansour fight screenshots.
- Inspect at 1280x720 for scroll bars, clipping, floating feet and UI overlap.
