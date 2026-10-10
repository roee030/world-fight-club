# Roster and Interface Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize all fighters, add Trump and Joint List, fix grounding and height variation, randomize opponents, and rebuild the main menu, fight HUD and result screen.

**Architecture:** Sprite generation and slicing feed a single fighter manifest. `FighterVisual` consumes scale and baseline metadata, while `main.gd` owns selection/random-opponent flow and presentation. Existing combat rules remain intact.

**Tech Stack:** Godot 4.7.2, GDScript, Python/Pillow, transparent PNG sprite sheets.

**Spec:** `docs/superpowers/specs/2026-10-07-roster-ui-polish-design.md`

## Global Constraints

- Preserve the fixed 12-pose 4x3 sprite contract.
- Player selects one fighter; CPU opponent is random and always different.
- Character height changes visuals and collider height without changing floor contact.
- All satire remains clearly fictional.
- Run all Godot tests and visual capture checks.

## Tasks

### Task 1: Sprite geometry and fighter manifest

- [ ] Add per-fighter height, pixel scale and ground offset metadata.
- [ ] Make the slicer preserve padding and calculate consistent foot baselines.
- [ ] Test that standing frames touch the baseline and do not touch cell edges.

### Task 2: Regenerate legacy fighters and add two fighters

- [ ] Generate six transparent 12-pose sheets.
- [ ] Slice them and update cards.
- [ ] Add Trump and Joint List to roster data and Sprite Lab.

### Task 3: Single-choice random opponent flow

- [ ] Remove fixed rival preview from selection.
- [ ] Draw an opponent from all fighter IDs excluding the selected ID at fight start.
- [ ] Add deterministic tests for exclusion and roster coverage.

### Task 4: Main menu and character select presentation

- [ ] Build diagonal full-roster lineup background.
- [ ] Compact action panel and improve roster browsing.
- [ ] Show mystery CPU slot until confirmation.

### Task 5: HUD and result presentation

- [ ] Rebuild HUD frames, health bars, timer and round indicators.
- [ ] Rebuild win/loss overlay with winner art and clear actions.
- [ ] Capture victory and defeat states at 1280x720.

### Task 6: Integration verification

- [ ] Run asset validation and all Godot tests.
- [ ] Capture menu, selection, fight, Sprite Lab and result screens.
- [ ] Fix visual clipping, floor gaps and name overflow found in captures.
