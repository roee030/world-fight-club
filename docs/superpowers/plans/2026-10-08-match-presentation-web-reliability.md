# Match Presentation and Web Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an unobstructed slow winner celebration, permanent final-hit KO, reliable MAX input, reference-accurate combat controls, and a responsive startup/game canvas on every supported phone viewport.

**Architecture:** Keep the 1280×720 Godot reference canvas and existing finisher runtime. Fix state ownership at its source (`fighter.gd` for lethal reactions, `main.gd` for match/result/input state) and make the exported HTML shell own only viewport fitting and readiness recovery through an explicit Godot↔JavaScript handshake.

**Tech Stack:** Godot 4.7 GDScript, Python 3 `unittest`, generated HTML/CSS/JavaScript, GitHub Pages Web export.

**Spec:** `docs/superpowers/specs/2026-10-08-match-presentation-web-reliability-design.md`

## Global Constraints

- Preserve the existing 12-frame sprite fighter pipeline and `FighterVisual` geometry.
- Keep one 1280×720 gameplay coordinate system with `canvas_items` scaling; do not crop or stretch it.
- Celebration playback multiplier is `0.40`; the unobstructed real-time interval is at least `3.0` seconds.
- A lethal hit permanently locks the defeated fighter on the grounded final knockdown frame.
- Keyboard and phone FINISH are one press at 100% energy. Range determines hit or opening miss; round wins and rival health do not gate activation.
- Support the formula-driven viewport matrix 568×320, 667×375, 740×360, 844×390, 915×412, 1024×600 and 1280×720.
- Preserve pause freezing, single result handoff, finisher hit ownership and cleanup contracts.
- Do not commit `.godot`, exports, browser traces, temporary renders or unrelated `.uid` files.

## Review Focus

- A lethal Special must not re-enable `getup_pending`; Task 1 tests this through the ordinary damage path.
- A pause during the three-second clear celebration must freeze both authored time and the presentation deadline; Task 2 tests both clocks.
- Repeated touch signals from one MAX gesture must dispatch exactly one attack; Task 3 emits down/pressed/up signals.
- A click before the Web bridge exists must survive initialization exactly once; Task 4 tests queued-action acknowledgement.
- Dynamic browser chrome, safe-area insets and orientation changes must reuse one layout function without cropping; Task 4 exercises the full viewport matrix.

---

### Task 1: Permanent lethal knockdown

**Files:**
- Modify: `scripts/fighter.gd:501-557`
- Modify: `tests/test_live_combat_damage.gd`

**Interfaces:**
- Consumes: `GameFighter.receive_hit(damage: float, direction: float, kind: String) -> void`
- Produces: lethal hits with `round_over == true`, `knockdown_time == 999.0`, `getup_pending == false`, and a paused final `knockdown` frame.

- [x] **Step 1: Extend the failing production-path test**

Add `test` assertions after separate lethal `light`, `special`, and blocked-hit cases. Each must assert zero health, permanent knockdown, no get-up, `knockdown` animation, stopped playback and the final frame.

- [x] **Step 2: Run the focused test and verify RED**

Run: `godot --headless --path . --script res://tests/test_live_combat_damage.gd`

Expected: FAIL for lethal Special because its recoverable Special branch overwrites the permanent defeated lock.

- [x] **Step 3: Correct reaction ordering in `receive_hit(...)`**

Apply the recoverable Special knockdown only when `not defeated_now`; keep the existing permanent defeated state authoritative for every lethal attack kind and blocked lethal hit.

- [x] **Step 4: Run focused combat regressions and verify GREEN**

Run:

```powershell
godot --headless --path . --script res://tests/test_live_combat_damage.gd
godot --headless --path . --script res://tests/test_combat_sprite_regressions.gd
```

Expected: both print `PASS` and exit 0.

- [x] **Step 5: Commit**

```powershell
git add scripts/fighter.gd tests/test_live_combat_damage.gd
git commit -m "fix: preserve lethal knockdown state"
```

### Task 2: Clear celebration phase and delayed result card

**Files:**
- Modify: `scripts/main.gd:1-190, 1037-1080, 1466-1576`
- Modify: `scripts/finishers/finisher_lab.gd`
- Modify: `tests/test_normal_match_celebration.gd`
- Modify: `tests/test_finisher_lab.gd`
- Modify: `tests/test_ui_presentation.gd`

**Interfaces:**
- Consumes: `FinisherDirector.begin_celebration(...) -> bool`, `FinisherDirector.advance(delta: float)`, `result_ready(winner)`.
- Produces: `CELEBRATION_PLAYBACK_SCALE := 0.40`, `CELEBRATION_CLEAR_SECONDS := 3.0`, `_begin_match_celebration(won: bool) -> void`, and `_reveal_result_after_celebration() -> void`.

- [x] **Step 1: Rewrite the celebration regression for the required sequence**

Assert that a final match win starts the correct celebration with `result_root.visible == false`; 2.99 unpaused seconds do not reveal it; pause advances neither timeline nor clear timer; 3.0 seconds plus any later authored marker reveal one compact result card; the loser remains permanently knocked down. Repeat ownership assertions for the loss path.

- [x] **Step 2: Run the focused celebration tests and verify RED**

Run:

```powershell
godot --headless --path . --script res://tests/test_normal_match_celebration.gd
godot --headless --path . --script res://tests/test_ui_presentation.gd
```

Expected: FAIL because `_show_result_with_celebration()` currently exposes result UI before celebration begins and uses 0.55 speed.

- [x] **Step 3: Implement explicit clear-celebration state ownership**

Keep result data preparation separate from visibility. Start the celebration, hide result UI/static winner art, advance authored time at `0.40`, accumulate only unpaused real time, and reveal the prepared compact result exactly once after both the 3.0-second minimum and the authored result marker are satisfied.

- [x] **Step 4: Apply the same 0.40 playback multiplier to Fight Lab celebration preview**

Use the shared constant or identical named constant; update `test_finisher_lab.gd` to prove one real second advances 0.40 authored seconds.

- [x] **Step 5: Run result, pause and finisher integration tests and verify GREEN**

Run:

```powershell
godot --headless --path . --script res://tests/test_normal_match_celebration.gd
godot --headless --path . --script res://tests/test_finisher_lab.gd
godot --headless --path . --script res://tests/test_finisher_match_integration.gd
godot --headless --path . --script res://tests/test_gameplay_polish.gd
godot --headless --path . --script res://tests/test_ui_presentation.gd
```

Expected: every script prints `PASS` or exits 0 without assertion errors.

- [x] **Step 6: Commit**

```powershell
git add scripts/main.gd scripts/finishers/finisher_lab.gd tests/test_normal_match_celebration.gd tests/test_finisher_lab.gd tests/test_ui_presentation.gd
git commit -m "fix: reveal results after clear celebration"
```

### Task 3: Real MAX gesture and reference control layout

**Files:**
- Modify: `scripts/main.gd:217-310, 560-765, 766-803`
- Modify: `scripts/virtual_stick.gd`
- Modify: `tests/test_mobile_control_contract.gd`
- Modify: `tests/test_ui_presentation.gd`

**Interfaces:**
- Consumes: `_finisher_eligible() -> bool`, `_sample_special_input(delta: float) -> String`, `buttons: Dictionary`.
- Produces: `_submit_touch_special() -> void`, `_show_special_feedback(message: String) -> void`, and one data-driven `TOUCH_CONTROL_LAYOUT` in 1280×720 coordinates.

- [x] **Step 1: Add failing real-button regressions**

Historical implementation note: the original MAX dual-purpose contract below was superseded on 2026-10-08 by direct phone feedback. The final phone contract is five unambiguous actions (`PUNCH`, `KICK`, `FINISH`, `JUMP`, `GUARD`); FINISH never falls back to a different attack.

Emit the actual FINISH button's `button_down`, `pressed` and `button_up` signals and advance host/fighter physics. Assert no attack or meter spend when conditions are false; one director activation when eligible; no buffered attack while paused/result; visible unmet-condition feedback; and no double dispatch.

- [x] **Step 2: Add failing HUD/control geometry regressions**

Assert all five controls are inside the safe frame, pairwise non-overlapping, at least 100 reference pixels on their smallest dimension, and positioned in the FINISH/KICK/PUNCH/JUMP/GUARD cluster. Assert the menu no longer contains the two keyboard-guide labels.

- [x] **Step 3: Run mobile/UI tests and verify RED**

Run:

```powershell
godot --headless --path . --script res://tests/test_mobile_control_contract.gd
godot --headless --path . --script res://tests/test_ui_presentation.gd
```

Expected: FAIL on actual-signal single-dispatch, smallest SP size and menu guide removal.

- [x] **Step 4: Centralize touch Special submission and feedback**

Route touch FINISH through one edge-triggered method. Consume the gesture once, launch only an eligible finisher, reject invalid match states, and show a short reason when a requirement prevents activation.

- [x] **Step 5: Refine HUD, joystick and action cluster from one layout table**

Keep segmented cyan/red health and labelled gold Special Energy bars. Increase the smallest touch target to 88×88, retain directional joystick guides, remove keyboard instructions from the startup menu and keep every target inside the lower safe zones.

- [x] **Step 6: Run mobile, UI and combat tests and verify GREEN**

Run:

```powershell
godot --headless --path . --script res://tests/test_mobile_control_contract.gd
godot --headless --path . --script res://tests/test_ui_presentation.gd
godot --headless --path . --script res://tests/test_finisher_input.gd
godot --headless --path . --script res://tests/test_finisher_match_integration.gd
```

Expected: all exit 0.

- [x] **Step 7: Commit**

```powershell
git add scripts/main.gd scripts/virtual_stick.gd tests/test_mobile_control_contract.gd tests/test_ui_presentation.gd
git commit -m "fix: make MAX and touch HUD reliable"
```

### Task 4: Responsive phone canvas and readiness-driven Web shell

**Files:**
- Modify: `tools/patch_web_export.py`
- Modify: `scripts/main.gd:293-315` and screen-navigation helpers
- Modify: `tests/test_web_cache_policy.py`
- Create: `tests/test_web_responsive_layout.py`

**Interfaces:**
- Consumes: generated `export/web/index.html`, browser `visualViewport`, CSS safe-area values and Godot `JavaScriptBridge`.
- Produces: JavaScript `layoutWorldFightViewport()`, `window.worldFightSetReady(ready)`, `window.worldFightSetMenuVisible(visible)`, and a single pending-action slot acknowledged after transition.

- [x] **Step 1: Add failing HTML-shell contract tests**

Patch a minimal export and assert one idempotent startup layer, `visualViewport` listeners, safe-area CSS variables, portrait gate markup, one shared layout function, readiness/menu callbacks, pending-action acknowledgement and no persistent service worker.

- [x] **Step 2: Add the viewport-matrix calculation regression**

Test the pure fit calculation for 568×320, 667×375, 740×360, 844×390, 915×412, 1024×600 and 1280×720 plus simulated left/right safe-area insets. Landscape output must be centered, 16:9 and bounded; portrait output must select the rotate gate.

- [x] **Step 3: Run Python Web tests and verify RED**

Run:

```powershell
python -m unittest tests.test_web_cache_policy tests.test_web_responsive_layout
```

Expected: FAIL because the current shell uses user-agent detection, CSS-only sizing and no readiness handshake or portrait gate.

- [x] **Step 4: Implement one responsive layout and startup state machine**

Use measured visual-viewport bounds minus safe-area insets, fit the largest centered 16:9 canvas, display the bilingual portrait gate when height exceeds width, and reposition the startup actions from the resulting canvas rectangle. Register resize, orientation and visual-viewport resize/scroll with the same function.

- [x] **Step 5: Implement the Godot bridge handshake**

Publish ready/menu state after `_show_menu()`, hide the recovery layer only after the requested screen is visible, restore it on return to menu, and consume at most one pre-ready pending action.

- [x] **Step 6: Run Python and focused Godot bridge tests and verify GREEN**

Run:

```powershell
python -m unittest tests.test_web_cache_policy tests.test_web_responsive_layout
godot --headless --path . --script res://tests/test_ui_presentation.gd
```

Expected: all exit 0.

- [x] **Step 7: Commit**

```powershell
git add tools/patch_web_export.py scripts/main.gd tests/test_web_cache_policy.py tests/test_web_responsive_layout.py tests/test_ui_presentation.gd
git commit -m "fix: make Web startup responsive and reliable"
```

### Task 5: Full verification, browser inspection and documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-10-08-match-presentation-web-reliability.md`
- Create only as ignored evidence: local captures/browser traces under an existing ignored output directory.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: verified 1280×720 and viewport-matrix evidence plus updated player-facing behavior documentation.

- [x] **Step 1: Run the complete Python suite**

Run: `python -m unittest discover -s tests -p 'test_*.py'`

Expected: all tests pass.

- [x] **Step 2: Run every Godot regression**

Run:

```powershell
Get-ChildItem tests/test_*.gd | ForEach-Object {
  godot --headless --path . --script ("res://tests/" + $_.Name)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: every script exits 0.

- [x] **Step 3: Export and patch the Web build locally**

Run the Web export with Godot 4.7.2, then `python tools/patch_web_export.py`. Verify non-empty HTML, WASM and PCK outputs. Keep the export ignored.

- [x] **Step 4: Inspect desktop gameplay at 1280×720**

Capture the full combat HUD, lethal final frame, unobstructed celebration, delayed win card and delayed loss card. Verify grounding, readability and no overlap/cropping.

- [x] **Step 5: Inspect the Web viewport matrix in a real browser**

At every specified landscape viewport, verify centered uncropped canvas, usable touch targets and startup actions. At portrait sizes verify the rotate/full-screen gate. Simulate safe-area insets and a visual-viewport height change.

- [x] **Step 6: Exercise MAX in the rendered phone UI**

Verify normal Special, eligible finisher, unavailable feedback and no double dispatch with actual pointer input.

- [x] **Step 7: Update documentation and checklist**

Document the delayed result presentation, 0.40 celebration speed, permanent final KO, MAX behavior and responsive phone contract. Mark only steps backed by the completed evidence.

- [ ] **Step 8: Commit final verification record**

```powershell
git add README.md docs/superpowers/plans/2026-10-08-match-presentation-web-reliability.md
git commit -m "docs: record responsive match polish verification"
```
