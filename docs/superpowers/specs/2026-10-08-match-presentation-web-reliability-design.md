# Match presentation and Web reliability — system design

**Date:** 2026-10-08  
**Status:** Approved for implementation
**Scope:** Normal-match KO and celebration flow, result presentation, combat HUD and touch controls, MAX input, and the Chrome startup shell.

## Purpose

Make the shipped game match the supplied fighting-game reference and remain playable in Chrome. A final hit must visibly put the defeated fighter on the floor, the winner's authored celebration must have an unobstructed readable interval, MAX must always provide the documented action when enough Special Energy is available, and the browser must always expose working startup actions.

This work preserves the existing fighter sprite pipeline, 1280×720 reference canvas, `FighterVisual` geometry, finisher catalog, hit ownership, pause contract and celebration assets.

## Confirmed root causes and gaps

- The current result flow calls `_show_result()` before starting the celebration. Even the newer corner card is therefore present from the first celebration frame. Existing tests inspect node sizes but do not prove that the authored celebration remains visually clear.
- Normal lethal hits initially set an indefinite knockdown. The ordinary Special branch then overwrites that state with a 0.62-second recoverable knockdown, which can make a final Special inconsistent with the permanent KO contract.
- The MAX regression calls the host input method directly in a synthetic state. It does not press the real UI button, advance the normal input loop, or verify feedback when a finisher is not eligible.
- The Chrome shell duplicates the menu in HTML and estimates its placement independently of the Godot UI. It has no explicit ready/menu-state handshake, so loading, canvas resizing and cached deployments can leave only background art or a misplaced fallback.
- The menu currently includes keyboard instructions inside its visual composition. Controls belong to combat/help context, not the loading or startup presentation.
- HUD tests assert the existence and rough dimensions of elements, but not their final composition at desktop and landscape-phone sizes.

## Match result state flow

The normal final-round sequence becomes:

`FIGHTING → KO_HOLD → CELEBRATION_CLEAR → RESULT`

`CELEBRATION_CLEAR` is the existing celebration runtime with a presentation rule: the result overlay and result actions remain hidden while the authored celebration receives its clear viewing interval.

Rules:

- The lethal hit changes the loser to the `knockdown` clip during the same combat update that applies zero health.
- The loser is locked on the final grounded knockdown frame and cannot enter `getup`, including when the lethal move is a Special/MAX attack.
- The winner celebration runs at a playback multiplier of `0.40` in normal matches and in its Fight Lab celebration preview.
- The celebration is unobstructed for at least 3.0 real seconds. If its authored `result_marker` occurs later, the marker controls the transition; if it occurs earlier, the minimum clear interval still applies.
- After the clear interval, the existing result state appears as a compact left-side card with its buttons. Static winner art stays hidden whenever a live celebration pose is available.
- Pause freezes the KO hold, celebration time, minimum-clear timer, actors, audio and transition to the result card.
- Result handoff remains single-shot. A frame hitch, repeated signal or pause/resume cannot create a second result transition.

The result card may overlap only the protected left UI zone. The winner and supporting celebration actors remain readable in the center/right action zone. The card must work for both `YOU WIN` and `YOU LOSE` without changing celebration ownership.

## Lethal hit contract

`fighter.gd` will resolve defeat before choosing recoverable reactions:

- A nonlethal Special keeps its brief knockdown and get-up behavior.
- Any lethal unblocked hit uses the permanent defeated lock, regardless of attack kind.
- A blocked hit that reduces health to zero follows the same defeated lock.
- The final knockdown retains normal `FighterVisual` scale and floor correction. No arbitrary transform is introduced.
- The shadow remains on the world floor and the defeated sprite's feet/body contact are checked in the visual capture.

The production test must deliver a real final attack through the combat update, not call only the presentation helper.

## MAX input contract

MAX is the touch label for the Special action and uses one-tap phone behavior:

- If all finisher eligibility rules are true, one MAX press starts the authored finisher immediately.
- Otherwise, if the player has at least 55 Special Energy and can act, the press starts the normal Special and spends exactly 55 energy.
- If the player cannot act or lacks energy, the HUD gives short, explicit feedback instead of silently ignoring the press.
- Keyboard `L`/`3` retains the existing hold-to-finish contract.
- One press can launch only one action; the button's down, pressed and up signals cannot double-submit it.
- Pause or result state cannot buffer a hidden MAX action into later combat.

Regression coverage will emit the real touch button signals, advance the host and fighter physics frames, and verify attack state, meter cost, feedback and single dispatch for both eligible and non-eligible paths.

## HUD and touch-control composition

The combat HUD remains authored on the 1280×720 reference canvas and follows the supplied reference:

- Player and CPU portrait/name blocks anchor to the upper left and upper right edges.
- Wide cyan/red segmented health bars run inward toward a prominent central timer medallion.
- The thin gold bars below health are explicitly labelled `SPECIAL ENERGY` and show percentage/readiness.
- Round markers and `BEST OF 3 · ROUND N` remain legible around the timer without covering health.
- The left touch joystick is a large circular control with center nub and directional guides, fully inside the lower safe frame.
- The right controls form the same readable cluster as the reference: MAX upper-left, CROSS upper-right, JAB lower-left, round SP/jump near center-right and GUARD below.
- Touch targets remain at least 68×68 reference pixels, do not overlap, and remain within the 1280×720 safe frame after canvas scaling.
- Combat HUD and controls never appear on the loading/menu screen. The two keyboard-guide lines are removed from the main menu.

The implementation will use named layout constants or a compact data table for the shared control geometry instead of unrelated positional corrections.

## Phone responsiveness contract

The Web build must adapt to the usable viewport of current phones rather than target one captured device size.

- Godot keeps one 1280×720 gameplay coordinate system. Responsive behavior scales and positions that reference canvas; it does not maintain separate combat implementations per device.
- The HTML shell measures `window.visualViewport` when available and falls back to the layout viewport. Browser address bars, toolbars and keyboard changes therefore cannot push the canvas or startup controls outside the visible area.
- CSS safe-area insets (`env(safe-area-inset-*)`) are removed from the usable rectangle before fitting the 16:9 canvas. Notches, rounded corners and home indicators cannot cover required controls.
- In landscape, the largest centered 16:9 rectangle that fits inside the usable viewport is used. Letterboxing is allowed; stretching or cropping the reference canvas is not.
- In portrait, the game shows a bilingual illustrated rotate/full-screen gate instead of shrinking combat into an unreadable strip. The portrait art shows the complete roster, a landscape-phone cue and the Knesset menorah; a persistent full-screen button remains available below it.
- Orientation changes, browser chrome expansion/collapse, full-screen entry/exit and `visualViewport` resize/scroll events trigger one shared layout function. Rotation to landscape also makes a best-effort full-screen request; browsers that require a fresh user gesture fall back to the gate or in-game full-screen button.
- The touch cluster uses a protected lower-left and lower-right safe zone. Every required action remains visible, non-overlapping and physically usable after scaling; the smallest round action is increased where necessary so it does not fall below a 44-CSS-pixel target on the supported small-phone matrix.
- Desktop and mouse-only Web sessions may hide the combat touch controls, while every touch-capable landscape Web session shows them.

The acceptance matrix covers at least these CSS viewports in both relevant orientations: 568×320, 667×375, 740×360, 844×390, 915×412, 1024×600 and 1280×720. The layout must also be formula-driven for intermediate sizes rather than selected from device-specific branches.

## Chrome startup shell

The HTML shell is a recovery surface, not an independently positioned permanent duplicate of the Godot menu.

- The patched export creates a startup layer centered inside the measured canvas rectangle.
- It contains `START FIGHT`, `CAMPAIGN` and `FIGHTER LAB` actions from first paint, plus a short loading state while Godot initializes.
- Godot installs a stable JavaScript bridge and explicitly publishes `ready` plus current menu visibility.
- A click before readiness stores exactly one pending action and shows immediate pressed/loading feedback. Godot consumes it after the bridge is ready.
- The fallback is loading-only: it disappears as soon as Godot publishes readiness and never floats over the real Godot menu. A pre-ready action still hides only after Godot confirms the requested transition.
- A loading-action tap requests browser full screen from that same user gesture; failure is non-blocking and the in-game full-screen control remains available.
- Placement is recalculated from the canvas rectangle on resize, orientation change and visual viewport change. It does not guess from page percentages alone.
- The HTML patch remains idempotent, retires obsolete service workers and clears obsolete caches without registering a new persistent worker.
- Non-Chrome browsers continue to use the Godot menu; the recovery layer may be enabled by capability/readiness rather than user-agent string if that is more reliable.

Generated HTML will be tested structurally and then exercised in an actual browser against a local Web export.

## Testing and visual acceptance

### Automated regressions

- A normal lethal light/heavy hit locks the loser on the final knockdown frame.
- A lethal Special/MAX hit cannot schedule get-up or replace the indefinite defeated lock.
- A normal winner celebration advances at 0.40 speed, keeps the result UI hidden for at least 3.0 real seconds, then reveals exactly one result card.
- Win and loss paths select the correct winner and preserve the loser on the floor.
- Pause freezes celebration playback and the clear-view timer.
- The five phone actions are `PUNCH`, `KICK`, `FINISH`, `JUMP` and `GUARD`. KICK uses the real kick clip without spending Special Energy; FINISH starts one eligible finisher at 100 energy and otherwise provides failure feedback without launching another attack.
- A lethal hit remains locked on its knockdown frame through the round intermission, while the next-round reset immediately returns both fighters to idle.
- HUD nodes and hit targets stay inside the 1280×720 safe frame with no overlap in the action cluster.
- The patched Web shell contains the readiness handshake, pending-action queue, responsive canvas measurement, safe-area handling, portrait gate and cache retirement behavior.
- The phone viewport matrix preserves a centered uncropped 16:9 canvas in landscape and a readable rotate gate in portrait.

Run the focused regressions first, then every Godot test and:

```powershell
python -m unittest discover -s tests -p 'test_*.py'
```

### Required screen inspection

Capture and inspect:

1. Combat at 1280×720 with full HUD and touch controls visible.
2. Landscape-phone Web combat with the complete joystick/action cluster.
3. The exact final-hit frame and grounded KO hold.
4. An unobstructed celebration frame before result UI.
5. The later compact `YOU WIN` card over the still-readable arena.
6. The corresponding `YOU LOSE` flow.
7. Chrome first paint, startup actions, click-before-ready behavior and the selected Godot screen after handoff.
8. The full phone viewport matrix, including a notched safe-area simulation and browser-toolbar resize.

No item is complete from node assertions alone. Visual claims require these captures, and Chrome claims require the generated Web build rather than a mocked HTML fragment.

## Files expected to change

- `scripts/main.gd` — match presentation states, result timing, HUD/touch layout, MAX feedback and Web handshake.
- `scripts/fighter.gd` — lethal-reaction ordering and permanent knockdown.
- `scripts/finishers/finisher_lab.gd` — shared 0.40 celebration preview speed.
- `tools/patch_web_export.py` — readiness-driven startup shell and responsive placement.
- Focused Godot and Python regression tests.
- `README.md` and the implementation plan if player-visible behavior or verification commands change.

No fighter assets, roster definitions, finisher hit ownership or catalog celebration objects will be changed.

## Definition of complete

The work is complete only when the full automated suites pass, the required desktop and Web captures have been inspected, the phone viewport matrix remains uncropped and usable, Chrome exposes working startup actions from first paint, MAX produces an observable documented result, the defeated fighter remains grounded after the final blow, and the winner's celebration is clearly visible before the result card appears.
