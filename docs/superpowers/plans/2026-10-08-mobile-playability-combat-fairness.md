# Mobile Playability and Combat Fairness Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Follow the AGENTS.md workflow (failing regression test first, smallest production change, full suites, 1280×720 + phone screen inspection).

**Goal:** On a real Android Chrome phone the game loads to a usable menu, fills the whole landscape screen without distortion, every touch button performs exactly the one action it is labelled with, and damage is visibly fair and explainable.

**User report (2026-10-08, Android + Chrome):**
1. Opening the site shows the fighters art with no text and no buttons; the game cannot be played.
2. The game does not use the full phone width.
3. One PUNCH or KICK tap seems to do "both"; controls are unclear.
4. The player seems to lose HP much faster than the CPU.

## Delivery record (2026-10-08)

| Phase | Status | Evidence |
|---|---|---|
| 0 Android diagnosis | Partly done: `?diag=1` overlay shipped; not yet checked on the real phone | Shell test `test_shell_fills_screen_and_gates_fullscreen` |
| 1 Web load | Done: single download (no worker reload), branded loading with % / MB / retry, patcher replaces blocks, lossy WebP imports (`.pck` 65 MB → 14.8 MB, local clean export) | `test_web_cache_policy.py` |
| 2 Full width + 2B fullscreen | Done: `expand` aspect, edge-anchored HUD/touch, centred menus, backdrop cover-fit; Android `TAP TO FIGHT` fullscreen gate, pause on exit, refusal fallback | Browser pane at 568×320, 740×360, 915×412 |
| 3 / 3B Controls + HUD restyle | Done: `JAB` / `CROSS` / `MAX` / `SP` / `GUARD` per reference, press-only dispatch, multi-touch, shape hit areas, electric SP at 100%; reference HUD panels and octagon clock | `test_mobile_control_contract.gd`, `test_ui_presentation.gd` |
| 4 / 4B Fairness, energy, finisher, rematch | Done: CPU guard 91% → 33% of player attacks at level 1, guard cooldown, slower energy economy, finisher = 30% HP blow, best-of-three flow, same-rival rematch + NEW OPPONENT | `test_combat_fairness.gd` (old code: player won 2/16 rounds; new: 15/16 for the scripted player), `test_finisher_match_integration.gd` |
| 5 Ideas | Not started (proposals) | — |

### Follow-up delivery (2026-10-09, phone play-test round 2)

| Issue | Root cause | Fix and evidence |
|---|---|---|
| Phone/PC showed art only, menus shifted/"zoomed" | Godot mirrored the whole UI right-to-left on Hebrew locales | Forced LTR root layout; reproduced and verified with Playwright `locale: he-IL` at 780×360 @3×; regression in `test_ui_presentation.gd` |
| `?diag=1` froze the game | Diagnostics created a WebGL context every 500 ms, exhausting the browser limit | GPU probed once and released; Python test |
| Black strip on the notch side | `viewport-fit=cover` had been removed | Restored full bleed; Godot insets HUD/touch/menu by the published safe area; Godot test |
| K showed a punch and a kick | 12-frame `hook` clip was `[0, 5, 6, 0]` (frame 6 = kick) | `[0, 5, 5, 0]`; `test_attack_clip_frames.gd` fails on the old map |
| Celebration off the fight floor line | `victory_low` (and lingering finisher framing) moved the camera while the stage backplate is camera-attached | Celebrations keep the fight framing; integration test compares the camera transform |
| Player died before SP; energy reset each round | High per-hit damage; meter cleared on round reset | `DAMAGE_SCALE 0.62`, energy carries over between rounds; fairness test (avg round 24 s, SP in 10/10 matches) |
| CPU too easy/predictable | Simple reactive rules | `cpu_brain.gd`: learning, prediction, whiff punish, spacing, weighted intents; 1.7 bits attack entropy, habit guard 40% → 76% |
| Select screen design | — | Rebuilt per reference; style shared by arena select, menu, pause and result |

## Evidence gathered before planning

| # | Observation | Source | Status |
|---|---|---|---|
| E1 | Live build is ~105 MB before first frame: `index.pck` 65.6 MB + `index.wasm` 39.5 MB. Desktop Chromium needs ~15 s. | `curl` of the live Pages site | Confirmed |
| E2 | In Chromium phone emulation (740×360 landscape) the menu renders with text and START FIGHT works. Bug 1 is not reproducible off-device. | Browser pane | Confirmed |
| E3 | Engine boot banner printed twice in one page load. Suspect: the retire worker's `client.navigate()` reloads the page, doubling the 105 MB download. | Console + `tools/patch_web_export.py` `RETIRE_WORKER` | Suspect, verify |
| E4 | Portrait shows `rotate-device-ensemble.webp` (the same fighters art) with a bottom card. If the card is hidden by Android browser chrome, the user sees "art with no text". | Browser pane 412×780 | Suspect, verify |
| E5 | Canvas is fitted to 16:9, so 844×390 / 740×360 phones get black side bars. | `fit_viewport()` and `project.godot` (no `window/stretch/aspect`) | Confirmed |
| E6 | **Double attack per tap:** touch PUNCH/KICK set `_input_down[action]` on `button_down` **and** on `pressed` (fires on release by default). One tap = attack on press + a second buffered attack on release. | `scripts/main.gd:789-798` | Confirmed in code |
| E7 | Touch buttons are `Button` controls. They respond to emulated mouse events, which are generated only for touch index 0. If a thumb is already on the virtual stick, another finger may not be able to press an attack button. | `scripts/main.gd:_build_touch_controls`, `scripts/virtual_stick.gd` | Suspect, verify on device |
| E8 | Diamond plates are drawn at 108 % of a square hit rect. Hit areas (squares) and visuals (diamonds) disagree, and neighbouring rects touch (FINISH/PUNCH/GUARD). | `TOUCH_CONTROL_LAYOUT` | Confirmed in code |
| E9 | Keyboard has light/heavy (J/K) and no kick key; touch has PUNCH/KICK and no heavy. Same game, two different move sets. | `KEYMAP`, `TOUCH_CONTROL_LAYOUT` | Confirmed |
| E10 | Quick Fight CPU is level 1: its damage is ×0.79. But it *reads* the player's attack startup and blocks 60 % of the time (`0.50 + 0.10 * level`), and blocked hits deal only 22 %. The CPU also auto-cancels into combos. A touch player rarely guards. Net effect: the player's damage mostly gets blocked, the CPU's mostly lands. | `scripts/fighter.gd:_run_cpu`, `_try_hit`, `receive_hit` | Confirmed in code; magnitude unmeasured |
| E11 | Max HP differs per fighter (96–116). Bars are normalised, so the same hit moves a 96-HP bar ~20 % further than a 116-HP bar. | `fighter.gd:max_health` | Confirmed |
| E12 | Local `export/web/index.html` is a mix of two patcher versions (body calls an undefined `initializeWorldFightShell`). The patcher skips blocks by marker instead of replacing them. CI exports fresh, so this only breaks local testing. | `export/web/index.html` | Confirmed |

## Phase 0 — Diagnose the Android blank menu (needs the user's phone, ~15 min)

Bug 1 cannot be fixed responsibly without device evidence.

- [ ] **0.1 Remote-debug the real phone.** Android: enable Developer options → USB debugging, connect to the PC, open `chrome://inspect/#devices` in desktop Chrome, inspect the game tab. Capture: console errors, Network sizes/timings, whether `#worldFightRotateGate` or `#canvas` is visible, the WebGL renderer string.
- [ ] **0.2 Add `?diag=1` overlay to the Web shell** (in `tools/patch_web_export.py`). It shows load stage (download % → engine start → first Godot frame → menu ready), `innerWidth×innerHeight`, `visualViewport`, orientation, `navigator.deviceMemory`, the WebGL renderer, and the last JS error. This is the fallback when USB debugging is not possible: the user sends one screenshot.
- [ ] **0.3 Decide the branch from the evidence:**
  - Rotate gate visible in landscape, or card off-screen → fix the gate (Phase 1.4).
  - Canvas visible but Godot text missing → GPU font issue; test MSDF/oversampling settings and the default font import on that device.
  - Stuck or killed while loading → size and memory (Phase 1.1–1.3).

## Phase 1 — Reliable Web load (Bug 1)

- [ ] **1.1 Stop double loading (E3).** Regression in `tests/test_web_cache_policy.py`: the retire worker must not call `client.navigate()` (or must do so at most once per worker generation via a guard). Verify in the browser that a single engine banner prints.
- [ ] **1.2 Shrink the package (E1).** Report the 30 largest files in the exported `.pck`. Expected wins: large PNG stage/hero art → lossy WebP/VRAM-compressed imports at ≤2048 px; drop assets not referenced at runtime via `exclude_filter`. Target: `.pck` ≤ 30 MB. Add a Python test that fails if `export_presets.cfg` stops excluding source-only folders and a CI step that fails if `index.pck` > 40 MB.
- [ ] **1.3 Honest loading screen.** Replace the Godot logo splash with the game's own loading screen: percent + MB downloaded, a "slow connection" hint after 10 s, a visible error message plus a **Retry** button on failure. Never show art without a status line.
- [ ] **1.4 Rotate gate always readable (E4).** Size the card using `visualViewport` and `100dvh`, keep the text above the bottom safe area, and add a test that the gate never shows when `width > height`.
- [ ] **1.5 Make the patcher replace blocks (E12)** instead of skipping by marker, and regenerate the local export. Test: patching an old-format HTML yields exactly one current shell block and a defined `initializeWorldFightShell`.

## Phase 2 — Full-width responsive layout (Bug 2, chosen: "expand the arena")

Keep 1280×720 as the *minimum* design area; wider screens show more horizontally. Nothing is stretched or cropped.

- [ ] **2.1 Godot:** set `window/stretch/aspect="expand"` (keep `canvas_items`). The 3D camera keeps vertical FOV, so wider phones see more arena width.
- [ ] **2.2 Web shell:** `fit_viewport()` fills the entire safe visible viewport instead of a centred 16:9 box. Update `tests/test_web_responsive_layout.py`: for the matrix 568×320 … 1280×720 (plus 2400×1080-class 20:9 phones), canvas = safe viewport, never cropped, portrait → rotate gate.
- [ ] **2.3 Anchor the UI.** Right-side HUD (enemy bar/portrait), touch action pad and FINISH must anchor to the right edge; stick and player HUD to the left; menus/backgrounds `PRESET_FULL_RECT` with `KEEP_ASPECT_COVERED` art. Convert `TOUCH_CONTROL_LAYOUT` from absolute 1280-space positions to edge-relative offsets.
- [ ] **2.4 World edges.** Confirm stage backdrops cover the widest aspect (20:9) and `ARENA_EDGE`/camera framing never reveals empty space; extend or mirror-pad backdrops if needed.
- [ ] **2.5 Phone-readable menu.** Menu items get a visible button plate (not bare text) and ≥ 44 CSS px touch height at 568×320; minimum on-screen font ~12 CSS px.
- [ ] **2.6 Inspect** 740×360, 844×390, 915×412 and 1280×720 screenshots: no bars, no clipping, fighters grounded.

## Phase 3 — Unambiguous touch controls (Bug 3)

- [ ] **3.1 One tap = one attack (E6).** Failing test in `tests/test_mobile_control_contract.gd`: emit the real PUNCH button's `button_down`, `pressed`, `button_up`, advance physics 1 s, assert exactly one `attack_started` of kind `light`; same for KICK. Fix: dispatch only on `button_down`; delete the `pressed` handler.
- [ ] **3.2 True multi-touch (E7).** Verify on the phone whether attacks work while the stick is held. Replace the touch `Button`s with a single `TouchActionPad` control that handles `InputEventScreenTouch`/`ScreenDrag` per finger index (or Godot `TouchScreenButton`, which is multi-touch). Test: stick held with index 0 + PUNCH with index 1 → movement continues and one punch fires.
- [ ] **3.3 Hit areas match the art (E8).** The hit test uses the same diamond polygon that is drawn, with a small gap between buttons. Test: a point inside PUNCH's diamond never activates FINISH/GUARD.
- [ ] **3.4 One move set everywhere (E9).** PUNCH / KICK / FINISH / JUMP / GUARD on both keyboard (J / K / L / W / S) and touch. Punch→punch chains into the existing cross/hook clip so the heavy move stays reachable through combos. Update README and the pause-screen controls list.
- [ ] **3.5 Press feedback.** Button flash + `navigator.vibrate(15)` on Android when an attack actually starts, and a short "BLOCKED" / "MISS" tag over the target so the player understands the result.

## Phase 4 — Fair, explainable damage (Bug 4)

Measure first, then tune.

- [ ] **4.1 Damage ledger.** Add a debug-only `CombatLedger` (signals already exist: `strike_landed`, `health_changed`) recording attacker, move, blocked, damage. Expose it in Fight Lab and a `?diag=1` HUD line: "You dealt X (Y blocked) / CPU dealt Z".
- [ ] **4.2 Headless fairness simulation.** New `tests/test_combat_fairness.gd`: a scripted "average touch player" (attacks in range at a human cadence, guards 20 % of the time) vs CPU levels 1–4 over N seeded rounds. Record average HP lost per side. Make it fail if level-1 CPU wins more than ~45 % of these rounds.
- [ ] **4.3 Tune the AI, not the numbers the player sees.** Expected changes, which the simulation will confirm:
  - Reactive block chance by level: 1 → 20 %, 2 → 35 %, 3 → 50 %, 4 → 65 % (now 60–90 %).
  - Block cooldown after a successful guard so the CPU cannot guard every hit of a chain.
  - CPU cancel-combo probability scaled down at level 1–2.
- [ ] **4.4 HP readability (E11).** Keep per-fighter max HP, but show the stat on the select screen ("HP 116 · TANK") so the difference is intentional and visible. Optional: floating damage numbers.

## Phase 4B — Energy economy, finisher damage and rematch (user follow-up, 2026-10-08)

Additional evidence:

| # | Observation | Source |
|---|---|---|
| E13 | The attacker gains `16 + 0.45 × damage` energy per hit (11 on block). A 7-damage jab gives ~19 energy, so ~5 jabs (≈35 HP) fill the 100 % FINISH bar. The defender gains nothing. Energy fills far faster than HP drains. | `fighter.gd:_try_hit` |
| E14 | A finisher's final hit always moves the match to `KO_HOLD`, awards the round and goes to the celebration/result, whatever HP the rival has. | `main.gd:_on_finisher_final_hit` |
| E15 | Quick Fight "continue/rematch" calls `_start_quick_fight()`, which picks a new random rival. | `main.gd:_continue_from_result` |
| E16 | User phone screenshot: two layers of bars (page bars plus bars inside the canvas). The menu art is shown cropped at about 4:3, with no wash panel and no menu text. The inner bars come from Godot's default `keep` aspect when the canvas buffer is not 16:9. Phase 2.1 (`expand`) removes them. The missing UI needs Phase 0. | Screenshot from user |

- [ ] **4B.1 Energy economy (E13).** Target: FINISH is available about once per round, not after five jabs. Proposed: attacker `+5 + 0.6 × damage` on hit, `+3` on block; defender `+0.5 × damage taken` (comeback energy). The Phase 4.2 simulation asserts that the average time to 100 % falls in a target window (e.g. 35–55 s at level 1). Update the HUD label "SPECIAL ENERGY".
- [ ] **4B.2 Finisher = heavy blow, not instant win (E14).** **This changes the approved finisher spec;** update `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md` first. The cinematic's final hit applies fixed damage (proposed 30 % of the rival's max HP, data-driven per finisher in `data/finishers.json`). If the rival survives, return to `FIGHTING` with both fighters reset to neutral spacing. If the rival reaches 0 HP, it is a normal round KO. The match ends only when a fighter has won 2 rounds; otherwise the next round starts. The celebration plays only on match end. Tests: finisher on a full-HP rival leaves HP > 0 and the match continues; finisher on a low-HP rival in round 1 starts round 2, not the result screen.
- [ ] **4B.3 Rematch keeps the rival (E15).** Result screen buttons: **REMATCH** (same player, same rival, same stage) and **NEW OPPONENT** (random rival, different from the player). Test both paths.

## Phase 2B — Mandatory fullscreen (user follow-up)

- [ ] **2B.1** In landscape on touch devices, show a "TAP TO FIGHT" gate before the game is interactive. The tap calls `requestFullscreen()` + `screen.orientation.lock('landscape')`.
- [ ] **2B.2** If fullscreen is exited (`fullscreenchange`), pause the game and show the gate again; resuming re-enters fullscreen.
- [x] **2B.3** iPhone Safari has no element-fullscreen API. There, fall back to the full-viewport layout plus an "Add to Home Screen" hint. Android Chrome gets true 100 % fullscreen.
- [ ] **2B.4** Tests in `test_web_responsive_layout.py` / a shell JS test for gate visibility states.

## Phase 3B — HUD and controls restyle to the user's reference image

**Blocked until the user sends the reference image** (top bars, round clock, right-side button cluster).

- [ ] **3B.1** Map reference buttons → our actions: PUNCH, KICK, GUARD, JUMP, and **SP** = FINISH.
- [ ] **3B.2** SP is locked/dim below 100 % energy. At 100 % it unlocks with an electric animation (shader or animated sprite arcs + pulse), and a sound cue plays once.
- [ ] **3B.3** Top HUD: HP bars, Special Energy bars and the clock styled to the reference. Edge-anchored per Phase 2.3; readable at 568×320.
- [ ] **3B.4** Screen inspection against the reference at 740×360, 844×390 and 1280×720.

## Phase 5 — Upgrade ideas (proposals; not scheduled until approved)

1. **Training mode**: a dummy that can be set to stand, block or attack, with live damage numbers and move list.
2. **Difficulty choice** in Quick Fight (Easy / Normal / Hard) mapped to `cpu_level`.
3. **First-fight tutorial**: three prompts (punch, kick, guard), then FINISH when energy is full.
4. **Combo display + hit sparks per move type**, plus a stronger hit-stop on KICK to separate it from PUNCH.
5. **Hebrew UI option** (RTL labels), matching the Hebrew rotate screen.
6. **Shareable result card** (winner art + finisher name) using the Web Share API.
7. **Installable PWA** done correctly *after* the package shrinks, with versioned cache names so stale builds never return.
8. **Data-driven tuning** (`data/fighters.json`) for speed, HP and damage modifiers, as the AGENTS roadmap already requests.

## Recommended execution order

1. Quick confirmed fixes: 3.1 (double attack), 4B.3 (rematch), 4B.2 (finisher as damage, after the spec update).
2. Phase 0 diagnosis on the phone, in parallel with Phase 4.1–4.2 measurement.
3. Phase 1 (load), then Phase 2 + 2B (full width + mandatory fullscreen); all of these touch the Web shell.
4. Phase 4B.1 + 4.3 tuning against the simulation.
5. Phase 3.2–3.5 together with 3B (new control pad and HUD in one pass, once the reference image arrives).
6. Phase 5 by user choice.

## Verification per phase

- `godot --headless --path . --script res://tests/<focused>.gd`, then the full Godot suite.
- `python -m unittest discover -s tests -p 'test_*.py'`.
- Push → Pages deploy → test on the user's Android Chrome (landscape + portrait), plus browser-pane screenshots at the viewport matrix.
