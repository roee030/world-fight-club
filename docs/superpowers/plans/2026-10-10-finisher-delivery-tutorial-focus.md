# Finisher Delivery, Combat Focus, and Tutorial Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship all finisher assets in the main Web package, reduce centre-fight feedback to one raised combo/damage lane, and make the first-fight tutorial begin and end with explicit spotlight overlays.

**Architecture:** The Web export becomes a one-pack deployment so the existing finisher combat path needs no asynchronous readiness state. `main.gd` owns compact combat feedback and tutorial match handoff, while `tutorial.gd` owns the dimmer, target spotlight, and intro/completion gate UI. Existing finisher and tutorial signals remain the authority for cinematic completion.

**Tech Stack:** Godot 4.7 GDScript, Godot headless tests, Python `unittest`, GitHub Pages export workflow.

**Spec:** `docs/superpowers/specs/2026-10-10-finisher-delivery-tutorial-focus-design.md`

## Global Constraints

- Keep the 1280×720 reference layout usable under Godot `expand` scaling and force LTR UI layout.
- Never alter the 12-frame fighter contract, floor grounding, finisher hit ownership, 30% damage budget, or celebration contract.
- SP remains one dispatch on touch press at 100% Special Energy; range still resolves through the authored hit/miss sequence.
- The tutorial must not auto-start headlessly; its finisher step must remain signal-driven.
- Preserve all unrelated user changes and push each completed task to `main` as an isolated commit.
- Run focused tests, then relevant full Godot/Python suites, and inspect both 1280×720 and landscape-phone presentation for visual tasks.

## Review Focus

- Fresh browser load: no request for `finishers.pck`; an eligible first SP starts immediately.
- Cached or slow browser: no stale deferred-pack gate can make a full SP unavailable.
- Non-combo combat: no centre-playfield instruction, readiness, or breaker text appears.
- Tutorial input: a dimmer never consumes a highlighted joystick/action input; only explicit overlay buttons consume clicks.
- Tutorial completion: an SP miss retries safely, while a landed SP waits for `sequence_finished` and only starts a live CPU round after `START FIGHT`.

---

### Task 1: Single-package Web finisher delivery

**Files:**
- Modify: `export_presets.cfg`, `.github/workflows/deploy-pages.yml`, `scripts/main.gd`, `tests/test_web_cache_policy.py`, `README.md`, `AGENTS.md`
- Delete: `scripts/web_pack_loader.gd`
- Test: `tests/test_web_cache_policy.py`, `tests/test_mobile_control_contract.gd`, `tests/test_finisher_match_integration.gd`

**Interfaces:**
- Consumes: `FinisherRules.is_eligible(context, definition)` and `_current_finisher_context()`.
- Produces: SP eligibility independent of a `WebPackLoader`; Web export emits only `index.pck`.

- [x] **Step 1: Add failing single-package assertions to `tests/test_web_cache_policy.py`**

Assert that preset 0 does not exclude `assets/finishers/*`, there is no `Web Finishers Pack` preset or workflow `--export-pack`, and `scripts/web_pack_loader.gd` is absent.

- [x] **Step 2: Run the Python test to verify it fails**

Run: `python -m unittest tests.test_web_cache_policy.WebCachePolicyTests.test_finisher_art_ships_with_main_package`

Expected: FAIL because the deferred pack configuration still exists.

- [x] **Step 3: Remove the deferred pack path and SP readiness gate**

Put finisher assets in preset 0, remove preset 1 and its workflow export, delete `WebPackLoaderScript`/`_pack_loader`, and remove only pack-readiness branches from `_current_finisher_context()` and `_submit_touch_special()`. Keep all ordinary combat eligibility checks unchanged.

- [x] **Step 4: Run focused Web and finisher tests**

Run: `python -m unittest tests.test_web_cache_policy` and `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_mobile_control_contract.gd`, then `res://tests/test_finisher_match_integration.gd`.

Expected: all pass; full-meter SP starts without a pack loader.

- [x] **Step 5: Update packaging documentation and commit/push Task 1**

Update README/AGENTS from two-pack language to one complete game package. Commit message: `fix: ship finishers with the web game package`.

### Task 2: Compact raised combo-and-damage feedback

**Files:**
- Modify: `scripts/main.gd`, `scripts/ui/callout.gd`, `tests/test_ui_presentation.gd`
- Create: `tests/test_combat_feedback.gd`
- Test: `tests/test_combat_feedback.gd`, `tests/test_combo_strings.gd`, `tests/test_mobile_control_contract.gd`

**Interfaces:**
- Consumes: fighter `combo_changed`, `combo_string`, and `combo_broken` signals.
- Produces: one `combo_label` whose public text is `<HITS> HITS · <DAMAGE> DMG` and whose design-frame Y position is above the former 232 px origin.

- [x] **Step 1: Add failing Godot feedback-contract tests**

Assert that a two-hit player combo shows hits and damage without `GOOD`/`GREAT`, a named combo retains only its damage line, breaker/special-feedback paths do not reveal a centre combat callout, and `combo_label.position.y < 232`.

- [x] **Step 2: Run the feedback test to verify it fails**

Run: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_combat_feedback.gd`

Expected: FAIL because current messages include quality, name/breaker, and special instructional strings and the label is at Y 232.

- [x] **Step 3: Implement the one-lane feedback policy**

Raise the combo lane into the HUD-safe upper fight area; make combo signal handlers set hits/damage only; silence centre-playfield special and breaker feedback while retaining round-state callouts. Update `CalloutScript.style_for()` only for the retained combo format.

- [x] **Step 4: Run focused combo and UI tests**

Run: `res://tests/test_combat_feedback.gd`, `res://tests/test_combo_strings.gd`, `res://tests/test_ui_presentation.gd`, and `res://tests/test_mobile_control_contract.gd`.

Expected: all pass and the combo engine remains the sole combo tracker.

- [x] **Step 5: Inspect fight presentation and commit/push Task 2**

Capture 1280×720 and 780×360 fight/combo views; confirm the lone lane sits above fighters without colliding with HUD. Commit message: `feat: focus combat feedback on combos and damage`.

### Task 3: Tutorial spotlight introduction and completion gates

**Files:**
- Modify: `scripts/ui/tutorial.gd`, `scripts/main.gd`, `tests/test_tutorial.gd`, `tests/test_tutorial_exit.gd`, `README.md`
- Test: `tests/test_tutorial.gd`, `tests/test_tutorial_exit.gd`, `tests/test_ui_presentation.gd`

**Interfaces:**
- Consumes: `Tutorial.begin()`, `Tutorial.finished(skipped)`, `target_rect()`, finisher `sequence_started`, `sequence_finished`, and `cancelled` signals.
- Produces: `Tutorial.begin()` initially enters an intro gate; `Tutorial.start_practice()` starts step zero; `Tutorial.confirm_completion()` emits `finished(false)` only after the completion gate.

- [x] **Step 1: Extend tutorial tests with failing gate/spotlight assertions**

Assert that begin shows `TutorialIntro`, the intro starts no action until `start_practice()`, spotlight drawing has a non-empty target during steps without intercepting it, landed SP reaches `TutorialComplete`, and `confirm_completion()` is required before the CPU is restored and the real round begins.

- [x] **Step 2: Run tutorial tests to verify they fail**

Run: `res://tests/test_tutorial.gd` and `res://tests/test_tutorial_exit.gd`.

Expected: FAIL because the current tutorial begins immediately and emits completion directly after SP.

- [x] **Step 3: Implement tutorial phases and spotlight overlay**

Add explicit intro/practice/completion state within `tutorial.gd`; draw four dimmer regions around a grown `target_rect()` plus the existing gold ring. Put intro/completion buttons in the overlay, keep the spotlight target input pass-through, and retain signal-driven SP behavior. Update `main.gd` so only the confirmation handoff calls `_restart_after_tutorial()`.

- [x] **Step 4: Run focused tutorial and presentation tests**

Run: `res://tests/test_tutorial.gd`, `res://tests/test_tutorial_exit.gd`, and `res://tests/test_ui_presentation.gd`.

Expected: all pass; miss retry, skip, replay, pause, and fresh CPU handoff remain safe.

- [x] **Step 5: Inspect tutorial at desktop and phone sizes, update docs, commit/push Task 3**

Capture the intro, one highlighted action, and completion gate at 1280×720 and 780×360. Confirm no overlay crops or blocks controls. Commit message: `feat: clarify first-fight tutorial with spotlight gates`.

### Task 4: Whole-batch verification and release record

**Files:**
- Modify: `docs/superpowers/plans/2026-10-09-presentation-campaign-legal-analytics.md`
- Test: all `tests/test_*.gd`; `python -m unittest discover -s tests -p 'test_*.py'`

**Interfaces:**
- Consumes: completed Tasks 1–3.
- Produces: a documented, verified release record.

- [x] **Step 1: Run the full Godot suite with a writable isolated `APPDATA` directory**

Run every `tests/test_*.gd` with the portable Godot console binary and `APPDATA` directed to `tmp/godot-test-data`.

Expected: all tests pass.

- [x] **Step 2: Run the full Python suite**

Run: `python -m unittest discover -s tests -p 'test_*.py'`

Expected: all tests pass.

- [x] **Step 3: Perform Web smoke verification**

Export/serve the Web build, inspect that no `finishers.pck` request occurs, and use `?qa=finisher` plus the tutorial route at desktop and phone dimensions.

- [x] **Step 4: Record evidence and commit/push Task 4**

Update the current handoff delivery record with test totals, captures, and package behavior. Commit message: `docs: verify finisher and tutorial focus release`.
