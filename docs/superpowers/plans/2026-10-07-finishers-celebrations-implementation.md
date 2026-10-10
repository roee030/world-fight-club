# Finish Attacks and Celebrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one data-driven Finish Attack and Celebration system for all 13 fighters, with real match integration, deterministic hit timing, Fighter Lab previews, desktop/mobile visual review, and a separate pushed delivery for every fighter.

**Architecture:** A pure rules module decides eligibility, a catalog loads and validates JSON definitions, and a timeline emits ordered one-shot events. A `FinisherDirector` composes fighters, temporary actors, props, camera and HUD while `main.gd` owns the explicit match state and result handoff. Fighter-specific behavior lives in data and assets; `fighter.gd` exposes only shared cinematic lock and authored-reaction APIs.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, transparent PNG/WebP sprite assets, headless Godot regression scripts, Python asset checks, GitHub Actions and GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`

## Global Constraints

- Preserve the existing 1280×720 layout and `canvas_items` scaling.
- Preserve ordinary Special behavior: a tap spends 55 meter and uses the current special; an eligible `0.55` second hold spends 100 meter and starts a finisher.
- Eligibility requires match point, defender health ratio `<= 0.15`, attacker meter `>= 100`, correct facing/range, grounded actionable fighters, and match state `FIGHTING`.
- The match state sequence is `ROUND_INTRO → FIGHTING → FINISHER_PROMPT → FINISHER_CINEMATIC → KO_HOLD → CELEBRATION → RESULT`.
- Fighter-specific story logic belongs in `data/finishers.json`; do not add per-fighter branches to `fighter.gd` or `main.gd`.
- Finish Attack and Celebration timelines are separate catalog objects joined by `celebration_id`; a celebration is never embedded as an implicit tail of the attack timeline.
- Each timeline `hit` has a unique event ID and may execute once.
- Pause freezes match timer, AI, timeline time, actors, camera motion, effects and sound progression.
- Reduced motion replaces repeated camera/effect/actor motion with the authored final tableau while preserving hit order, timing ownership and the single result marker.
- Use generated painted sprite assets; never paste photographs into the arena.
- The supplied Sarah/Yair photograph is a generation reference only and is not committed unless its license is verified.
- All required actors stay within the 16:9 safe frame; grounded actors declare and respect a foot baseline.
- Mobile reduced density allows at most 12 visible support actors and must preserve the defining action.
- Each fighter task ends with focused tests, the full test suite, desktop and landscape-phone capture review, a pushed implementation commit, then a pushed documentation record containing the implementation commit hash.
- Review captures are temporary evidence under ignored `output/finisher-review/` and must never be staged or committed.
- Work directly on `main` because the user requested incremental pushes after every completed fighter. Before each task, require a clean working tree and pull only when the remote has advanced.

## Review Focus

- **Special release at the `0.55` second boundary:** exactly one action occurs; Task 3 adds boundary tests at `0.549`, `0.55` and release-after-confirmation.
- **Pause on the same frame as a hit event:** damage executes zero or one time, never twice; Task 4 adds pause/resume event-ID assertions.
- **Defender defeated by unrelated damage during an eligibility hold:** prompt cancels and ordinary KO flow wins; Task 5 adds the race regression.
- **Missing or corrupt asset in an implemented catalog entry:** validation fails before a match begins and Lab shows the exact path; Task 2 adds missing-resource and wrong-type tests.
- **Phone loses focus or rotates during a cinematic:** timeline pauses with the tree and resumes inside the safe frame; Task 21 adds visibility/resize checks to the published Web build.

## Self-review record

Self-reviewed against the approved design and current `main.gd`, `fighter.gd`, `character_debug.gd` and test layout on 2026-10-07. The review resolved these gaps before implementation:

- The catalog contract now explicitly stores separate attack and celebration timelines and validates their `celebration_id` link.
- Catalog reads return deep copies so runtime consumption cannot mutate the loaded source definitions.
- Timeline consumption uses stable source indices while hit deduplication uses authored hit IDs, including same-time events and pause/resume.
- The Fighter Lab task now includes every required scenario, overlay, speed and mobile/reduced-motion preview.
- Presentation tests now cover sound pause, all allowed event families, reduced motion and cleanup.
- Visual captures are temporary evidence and cannot enter Git.
- The per-fighter table below is the operational delivery ledger and must be updated after each fighter.

## File Structure

### New runtime files

- `scripts/finishers/match_state.gd` — named match-state constants and transition validation.
- `scripts/finishers/finisher_rules.gd` — pure eligibility and input decision rules.
- `scripts/finishers/finisher_catalog.gd` — JSON loading, roster coverage and definition validation.
- `scripts/finishers/finisher_timeline.gd` — ordered time advancement and one-shot event consumption.
- `scripts/finishers/finisher_actor.gd` — temporary sprite/prop actor with grounding and cleanup.
- `scripts/finishers/finisher_director.gd` — match-facing cinematic coordinator and event executor.
- `data/finishers.json` — all 13 attack definitions plus their separately keyed celebration definitions; entries remain `"implemented": false` until their own delivery task.

### Existing files modified by the foundation

- `scripts/main.gd:119-204, 339-487, 960-1205` — state ownership, Special hold input, HUD prompt, pause, result handoff and director wiring.
- `scripts/fighter.gd:117-240, 317-511` — cinematic lock, authored damage/reaction, stable pose and input reset APIs.
- `scripts/character_debug.gd` — Finisher Lab controls and preview viewport.
- `README.md` — controls and feature status.
- `AGENTS.md` — implementation source-of-truth and progress rules.
- `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md` — checklist and delivery records.

### New tests and tools

- `tests/test_finisher_rules.gd`
- `tests/test_finisher_catalog.gd`
- `tests/test_finisher_timeline.gd`
- `tests/test_finisher_director.gd`
- `tests/test_finisher_match_integration.gd`
- `tests/test_finisher_lab.gd`
- `tests/test_finisher_roster.gd`
- `tests/test_finisher_visual_budget.gd`
- `tools/capture_finisher.gd`
- `tools/validate_finisher_assets.py`

### Fighter assets

Each fighter task owns `assets/finishers/<fighter_id>/` with `actors/`, `props/`, `effects/`, `celebration/` and `preview.png` as required by the approved spec.

## Post-roster result and Web delivery polish (2026-10-08)

- Normal match wins and losses reuse the winning fighter's authored celebration while the arena, `YOU WIN` / `YOU LOSE`, winner name and result options remain visible.
- `J` is the fast jab, `K` is the slower heavy attack and `L` is the Special/MAX input. A finisher requires one prior round win, 100% Special Energy, rival health at or below 15%, close range and a 0.55-second hold; the HUD reports the first missing requirement.
- GitHub Pages exports disable the old PWA worker and inject service-worker/cache cleanup so phones do not remain pinned to an earlier build.
- Chrome recovery now publishes a no-fetch `index.service.worker.js` retirement worker at the legacy URL; it deletes the old caches, unregisters itself and reloads controlled tabs without reproducing the invalid opaque-response status bug.
- The combat HUD and touch controls follow the supplied reference: angular cyan/red fighter wings, segmented health, thin gold Special Energy, central timer, large joystick and outlined `MAX` / `CROSS` / `JAB` / `GUARD` diamond cluster.
- Fighters now use pausable processing explicitly, preventing the player, CPU, movement, AI clock and sprite motion from inheriting the always-running UI root during Pause.
- Finisher Lab exposes `WIN CELEBRATION` for the selected fighter, and the result wash/title were reduced so the authored winner pose remains readable behind `YOU WIN` / `YOU LOSE` and the result actions.
- Chrome receives a centered, contained 16:9 canvas sized against `100dvh`; all mobile controls have automated right/bottom safe-frame bounds, and a successful MAX tap shows explicit feedback.

## Per-fighter delivery tracker

Update one row after each fighter's focused/full tests and visual inspection. `Implementation commit` records the pushed code/assets commit; `Record commit` records the subsequent pushed documentation commit that adds the implementation hash and review notes. Use `Not started`, `In progress`, `Blocked` or `Complete` only.

| Order | Fighter | `fighter_id` | `finisher_id` | Status | Tests | Lab | Desktop | Phone | Implementation commit | Record commit / notes |
|---:|---|---|---|---|---|---|---|---|---|---|
| 1 | Bennet | `bennet` | `startup_exit` | Not started | — | — | — | — | — | — |
| 2 | Bibi | `bibi` | `family_business` | Not started | — | — | — | — | — | — |
| 3 | Yair Lapid | `yair_lapid` | `prime_time_rush` | Not started | — | — | — | — | — | — |
| 4 | Benny Gantz | `benny_gantz` | `independence_flag` | Not started | — | — | — | — | — | — |
| 5 | Avigdor Lieberman | `avigdor` | `oil_barrel_48` | Not started | — | — | — | — | — | — |
| 6 | Mansour Abbas | `mansour_abbas` | `coalition_cashstorm` | Not started | — | — | — | — | — | — |
| 7 | Gadi Eisenkot | `gadi_eisenkot` | `bazooka_command` | Not started | — | — | — | — | — | — |
| 8 | Yair Golan | `yair_golan` | `m16_burst` | Not started | — | — | — | — | — | — |
| 9 | Itamar Ben-Gvir | `itamar_ben_gvir` | `crocodile_release` | Not started | — | — | — | — | — | — |
| 10 | Bezalel Smotrich | `bezalel_smotrich` | `cattle_charge` | Not started | — | — | — | — | — | — |
| 11 | Aryeh Deri | `aryeh_deri` | `campaign_entourage` | Not started | — | — | — | — | — | — |
| 12 | Joint List | `joint_list` | `two_headed_chaos_squad` | Not started | — | — | — | — | — | — |
| 13 | Donald Trump | `trump` | `b2_flyover` | Not started | — | — | — | — | — | — |

---

### Task 1: Explicit match state and pure eligibility rules

**Files:**
- Create: `scripts/finishers/match_state.gd`
- Create: `scripts/finishers/finisher_rules.gd`
- Create: `tests/test_finisher_rules.gd`
- Modify: `scripts/main.gd:119-131, 960-1040, 1137-1205`

**Interfaces:**
- Produces: `MatchState.Value` enum with `ROUND_INTRO`, `FIGHTING`, `FINISHER_PROMPT`, `FINISHER_CINEMATIC`, `KO_HOLD`, `CELEBRATION`, `RESULT`.
- Produces: `MatchState.can_transition(from: int, to: int) -> bool`.
- Produces: `FinisherRules.is_eligible(context: Dictionary, definition: Dictionary) -> bool`.
- Produces: `FinisherRules.match_point_for(attacker: int, player_rounds: int, enemy_rounds: int) -> bool`.
- Consumes: fighter action data as plain context values, without scene dependencies.

- [ ] **Step 1: Write `test_finisher_rules.gd` with failing eligibility and transition cases**

Assert the exact health ratio `0.15`, meter `100`, state `FIGHTING`, match-point score, grounded/actionable flags, range and facing requirements. Assert invalid state jumps are rejected.

- [ ] **Step 2: Run the focused test and verify RED**

Run `Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/test_finisher_rules.gd`. Expected: failure because the scripts and interfaces do not exist.

- [ ] **Step 3: Implement `MatchState` and `FinisherRules` minimally**

Add `var match_state: int = MatchState.Value.ROUND_INTRO` to `main.gd` and update round start, active fight, KO and result entry points to assign the corresponding state without changing visible behavior yet.

- [ ] **Step 4: Run the focused test and existing combat tests**

Expected: `test_finisher_rules.gd`, `test_live_combat_damage.gd`, `test_gameplay_polish.gd` and `test_combat_sprite_regressions.gd` exit `0`.

- [ ] **Step 5: Update foundation checklist, commit and push**

Commit message: `Add match state and finisher eligibility rules`. Push `main`, then record the commit hash in the spec delivery record in a follow-up documentation commit and push it.

---

### Task 2: Catalog, complete roster stubs and strict validation

**Files:**
- Create: `scripts/finishers/finisher_catalog.gd`
- Create: `data/finishers.json`
- Create: `tests/test_finisher_catalog.gd`
- Create: `tests/test_finisher_roster.gd`
- Create: `tools/validate_finisher_assets.py`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: `FinisherCatalog.load_default() -> bool`.
- Produces: `FinisherCatalog.definition_for(fighter_id: String) -> Dictionary`, returning a deep copy.
- Produces: `FinisherCatalog.celebration_for(celebration_id: String) -> Dictionary`, returning a deep copy.
- Produces: `FinisherCatalog.validate_definition(fighter_id: String, definition: Dictionary) -> PackedStringArray`.
- Produces: `FinisherCatalog.validate_celebration(celebration_id: String, definition: Dictionary) -> PackedStringArray`.
- Produces: `FinisherCatalog.validate_roster(fighter_ids: Array[String]) -> PackedStringArray`.
- Produces: `FinisherCatalog.is_implemented(fighter_id: String) -> bool`.
- Consumes: `main.gd.PLAYABLE_IDS` only in tests; runtime catalog remains independent.

- [ ] **Step 1: Write failing catalog and roster tests**

Assert all 13 exact `fighter_id` and `finisher_id` pairs from the spec, a valid `celebration_id` link, monotonic event times, allowed event and camera-preset values, unique hit IDs, one portrait lightbox, final hit before celebration handoff, celebration duration `1.8–2.8`, exactly one result marker for implemented entries, and clear errors for missing resources and wrong JSON types. Mutate a returned definition and assert a second lookup is unchanged.

- [ ] **Step 2: Run both tests and verify RED**

Expected: missing catalog implementation and JSON.

- [ ] **Step 3: Implement the loader and add 13 non-runtime stubs**

Every attack entry contains fixed trigger values, a `celebration_id` and `"implemented": false`; every referenced celebration has its own timeline object. Stubs may contain approved metadata but cannot become eligible at runtime.

- [ ] **Step 4: Implement `validate_finisher_assets.py`**

Expose `validate(root: Path, data: dict) -> list[str]`. It validates only entries with `implemented=true` and never rewrites art.

- [ ] **Step 5: Run Godot catalog tests and Python validator tests**

Expected: both Godot tests and `python -m unittest` exit successfully.

- [ ] **Step 6: Update checklist, commit and push**

Commit message: `Add validated finisher catalog`. Push implementation and follow-up delivery record.

---

### Task 3: Special hold input and FINISH READY HUD

**Files:**
- Create: `tests/test_finisher_input.gd`
- Modify: `scripts/main.gd:62-204, 339-487, 1026-1098`
- Modify: `README.md`

**Interfaces:**
- Produces: `main._update_special_hold(delta: float, pressed: bool, released: bool) -> String`, returning `"none"`, `"special"` or `"finisher"`.
- Produces: `main._cancel_special_hold() -> void`.
- Consumes: `FinisherRules.is_eligible` and catalog definition.

- [ ] **Step 1: Write failing tap, hold and boundary tests**

Assert ineligible press launches ordinary Special immediately; eligible release at `0.549` seconds launches one ordinary Special; reaching `0.55` returns one finisher; later release returns `none`; eligibility loss cancels without meter cost.

- [ ] **Step 2: Run the focused test and verify RED**

- [ ] **Step 3: Implement held-state input for keyboard and touch**

Track `_input_held["special"]` from `button_down/button_up` and keyboard state. Keep light/heavy edge input unchanged.

- [ ] **Step 4: Add HUD prompt and hold progress**

Reuse the Special label region. Text is `FINISH READY` while eligible and `FINISH 0–100%` during confirmation; cancel returns to the existing percentage.

- [ ] **Step 5: Run input, UI and live combat tests**

- [ ] **Step 6: Capture desktop and phone HUD states**

Use a temporary capture script under `tools/`; confirm prompt readability and no overlap with pause/fullscreen buttons.

- [ ] **Step 7: Update documentation, commit and push**

Commit message: `Add finisher hold input and HUD prompt`. Push implementation and follow-up delivery record.

---

### Task 4: Deterministic timeline engine

**Files:**
- Create: `scripts/finishers/finisher_timeline.gd`
- Create: `tests/test_finisher_timeline.gd`

**Interfaces:**
- Produces: `FinisherTimeline.start(definition: Dictionary) -> void`.
- Produces: `FinisherTimeline.advance(delta: float) -> Array[Dictionary]`.
- Produces: `FinisherTimeline.set_paused(paused: bool) -> void`.
- Produces: `FinisherTimeline.cancel() -> void`.
- Produces: `FinisherTimeline.is_finished() -> bool`, `elapsed() -> float`, `current_event_key() -> String`, `consumed_hit_ids() -> PackedStringArray`.

- [ ] **Step 1: Write failing order, hitch, pause and cancellation tests**

Include two events sharing a timestamp, a single large delta crossing several events, pause on a hit timestamp, repeated zero-delta advances and cancellation cleanup. Assert each source index is emitted once in source order and each authored hit ID is consumed once. `current_event_key()` uses the hit ID when present and otherwise a stable `<type>:<source-index>` key.

- [ ] **Step 2: Run the test and verify RED**

- [ ] **Step 3: Implement ordered one-shot advancement**

Deep-duplicate the input definition. Track general event consumption by source index and hit deduplication by authored hit ID so runtime advancement cannot mutate catalog data or drop same-time events.

- [ ] **Step 4: Run the focused test and full Godot suite**

- [ ] **Step 5: Update checklist, commit and push**

Commit message: `Add deterministic finisher timeline`. Push implementation and follow-up delivery record.

---

### Task 5: Director, actors, cinematic fighter API and match handoff

**Files:**
- Create: `scripts/finishers/finisher_actor.gd`
- Create: `scripts/finishers/finisher_director.gd`
- Create: `tests/test_finisher_director.gd`
- Create: `tests/test_finisher_match_integration.gd`
- Modify: `scripts/fighter.gd:117-240, 317-511`
- Modify: `scripts/main.gd:119-204, 960-1205`

**Interfaces:**
- Produces: `GameFighter.enter_cinematic_lock(anchor: Vector3, facing_value: float) -> void`.
- Produces: `GameFighter.apply_authored_hit(event_id: String, damage: float, direction: float, reaction: String) -> bool`.
- Produces: `GameFighter.exit_cinematic_lock() -> void`.
- Produces: `FinisherDirector.configure(host: Node, arena: Node3D, camera: Camera3D) -> void`.
- Produces: `FinisherDirector.begin(attacker: GameFighter, defender: GameFighter, definition: Dictionary) -> bool`.
- Produces: `FinisherDirector.advance(delta: float) -> void`, `set_paused(value: bool) -> void`, `cancel() -> void`.
- Produces signals: `sequence_started(attacker_id: String)`, `final_hit(defender_index: int)`, `celebration_started(id: String)`, `result_ready(winner_index: int)`.

- [ ] **Step 1: Write failing director and end-to-end match tests**

Use a small in-test attack definition linked to a separate celebration definition. Assert locks, meter spend at confirmed start, timer freeze, one defeat, one result, cleanup, missed-opening recovery and unrelated-KO hold cancellation. Simulate a rejected first authored hit before any damage and assert the director cancels, restores camera/control and resumes ordinary combat without a result.

- [ ] **Step 2: Run tests and verify RED**

- [ ] **Step 3: Implement cinematic fighter APIs**

Authored hit IDs are stored per sequence and cleared on reset. Ordinary `receive_hit` remains backward compatible.

- [ ] **Step 4: Implement actor and director event dispatch**

Dispatch `fighter_clip`, `spawn_actor`, `spawn_prop`, `move_actor`, `launch_prop`, `hit`, `defender_reaction` and `cleanup` through shared handlers. Unknown events cancel safely and emit a diagnostic; they never continue with partial damage.

- [ ] **Step 5: Wire main state, timer, pause and result handoff**

Remove any direct finisher-specific result call. The result enters only on `result_ready`.

- [ ] **Step 6: Run focused tests and all existing combat/pause tests**

- [ ] **Step 7: Update checklist, commit and push**

Commit message: `Integrate finisher director with match flow`. Push implementation and follow-up delivery record.

---

### Task 6: Fighter Lab finisher playground

**Files:**
- Create: `tests/test_finisher_lab.gd`
- Modify: `scripts/character_debug.gd`
- Modify: `scenes/character_debug.tscn` only if persistent nodes are required

**Interfaces:**
- Produces: `CharacterDebug.preview_finisher(fighter_id: String, outcome: String) -> void`.
- Produces: `CharacterDebug.seek_finisher(seconds: float) -> void`.
- Produces: `CharacterDebug.set_finisher_speed(multiplier: float) -> void`.
- Consumes: the real catalog, timeline and director.

- [ ] **Step 1: Write failing Lab control and shared-data tests**

Assert attacker/defender and eligible/hit/miss/pause-resume scenario selection, speed values `0.25`, `0.5`, `1.0`, frame stepping while paused, stable event-key display, ground/safe-frame plus collision/hurt/guard/attack-bound overlays, mobile density, reduced motion and catalog error display.

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Add the Finisher Lab mode**

The Lab must not copy timeline logic or use a separate definition format. Its toggles call the same director settings used by the match runtime.

- [ ] **Step 4: Run tests and inspect the Lab at 1280×720**

- [ ] **Step 5: Update checklist, commit and push**

Commit message: `Add finisher playground to Fighter Lab`. Push implementation and follow-up delivery record.

---

### Task 7: Shared cinematic presentation primitives

**Files:**
- Create: `tests/test_finisher_presentation.gd`
- Create: `tools/capture_finisher.gd`
- Modify: `scripts/finishers/finisher_director.gd`
- Modify: `scripts/main.gd:339-487, 1066-1136`

**Interfaces:**
- Produces director handlers covering every allowed event type: `portrait_lightbox`, `fighter_clip`, `spawn_actor`, `spawn_prop`, `move_actor`, `launch_prop`, `caption`, `sound`, `camera_preset`, `camera_impact`, `screen_flash`, `hit`, `defender_reaction`, `celebration_start`, `result_marker`, `cleanup`.
- Produces: `FinisherDirector.set_reduced_motion(value: bool) -> void` and `set_effect_density(value: String) -> void` for `desktop` or `mobile`.
- Produces: `capture_finisher.gd --fighter=<id> --phase=<finisher|celebration> --density=<desktop|mobile>` through project settings or environment arguments accepted by the script.

- [ ] **Step 1: Write failing event-handler and safe-frame tests**

Assert one lightbox per sequence, camera restore after cancel/result, paused audio resumes at the same cue position, impact/actor caps on mobile, reduced motion reaches the same final hit and result marker through a stable tableau, result marker order and no orphan actors.

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement presentation handlers and capture tool**

- [ ] **Step 4: Render the placeholder timeline at desktop and landscape-phone sizes**

- [ ] **Step 5: Run focused and full suites**

- [ ] **Step 6: Update checklist, commit and push**

Commit message: `Add shared finisher presentation`. Push implementation and follow-up delivery record.

---

## Fighter Delivery Template

Tasks 8–20 repeat this exact gate. Asset generation begins only after the failing catalog assertions are committed locally. Use the `imagegen` skill for new raster actors, props and effects; use code-native controls for captions and clocks. For every fighter:

1. Add failing event-sequence assertions to `tests/test_finisher_roster.gd`.
2. Run the focused test and observe the expected failure because the entry is not implemented or assets are missing.
3. Generate and inspect only that fighter's required assets.
4. Add assets under `assets/finishers/<fighter_id>/` and set `implemented=true` with the exact timeline.
5. Run catalog, roster, director and match integration tests.
6. Preview hit, miss, pause and celebration in Fighter Lab.
7. Render finisher and celebration captures for desktop and landscape phone under ignored `output/finisher-review/<fighter_id>/`; inspect safe frame, grounding and clarity and confirm `git status` does not list the captures.
8. Run the full Godot suite and Python suite.
9. Mark the fighter checkbox complete in the spec and update the matching delivery-tracker row in this plan with date, test result and visual notes.
10. Commit with the message specified below and push `main`.
11. Capture the implementation hash with `git rev-parse HEAD`; append it to the spec delivery record and this plan's tracker, commit `Record <fighter> finisher delivery`, and push again.

---

### Task 8: Bennet — thrown-prop vertical slice

**Files:**
- Create: `assets/finishers/bennet/props/laptop-*.png`
- Create: `assets/finishers/bennet/effects/pixel-impact-*.png`
- Create: `assets/finishers/bennet/celebration/exit-success-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Consumes all shared foundation interfaces. Produces implemented entry `bennet/startup_exit` and proves the thrown-prop path.

- [x] Follow the Fighter Delivery Template with assertions for one portrait, laptop spawn/launch, unique final hit, celebration and result marker.
- [x] Verify the laptop remains readable at mobile density and never covers either face before impact; both attacker sides reviewed.
- [x] Commit and push `Add Bennet startup exit finisher` (`8e3538d`); then record and push its hash.

---

### Task 9: Bibi — Sarah and Yair guest actors

**Files:**
- Create: `assets/finishers/bibi/actors/sarah-*.png`
- Create: `assets/finishers/bibi/actors/yair-*.png`
- Create: `assets/finishers/bibi/props/throne-*.png`
- Create: `assets/finishers/bibi/effects/sound-wave-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces implemented entry `bibi/family_business` and validates multiple guest actors plus a multi-character celebration.

- [x] Follow the Fighter Delivery Template; use the supplied photo only as image-generation reference.
- [x] Assert two non-final sound-wave hits, one Yair final hit, guest safe-frame positions and throne celebration order.
- [x] Verify Sarah, Yair and Bibi share the game's painted caricature style and contain no pasted photo regions.
- [x] Commit and push `Add Bibi family business finisher` (`c35b8b7`); then record and push its hash.

---

### Task 10: Yair Lapid — rapid multi-hit timing

**Files:**
- Create: `assets/finishers/yair_lapid/effects/boxing-speed-*.png`
- Create: `assets/finishers/yair_lapid/celebration/glove-pose-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `yair_lapid/prime_time_rush`; proves six ordered hit events and time-slow presentation.

- [x] Follow the template; assert five stagger hit IDs, one uppercut final ID, monotonic combo numbers and one result.
- [x] Commit and push `Add Yair Lapid boxing rush finisher` (`1ce769a`); then record and push its hash.

---

### Task 11: Benny Gantz — large flag framing

**Files:**
- Create: `assets/finishers/benny_gantz/props/independence-flag-*.png`
- Create: `assets/finishers/benny_gantz/effects/blue-white-confetti-*.png`
- Create: `assets/finishers/benny_gantz/celebration/flag-salute-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `benny_gantz/independence_flag`; proves a large animated prop can remain within safe UI zones.

- [x] Follow the template; assert the flag never covers both fighters or the central timer at review markers.
- [x] Commit and push `Add Benny Gantz flag finisher` (`3a524af`); then record and push its hash.

---

### Task 12: Avigdor Lieberman — oil barrel and 48-hour clock

**Files:**
- Create: `assets/finishers/avigdor/props/oil-barrel-*.png`
- Create: `assets/finishers/avigdor/effects/barrel-explosion-*.png`
- Create: `assets/finishers/avigdor/celebration/folded-arms-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `avigdor/oil_barrel_48`; the `48:00 → 00:00` countdown is a code-native caption/clock and the celebration clock remains fixed at `48:00`.

- [x] Follow the template; assert barrel spawn/throw precede countdown, explosion at zero is the sole final hit, and celebration clock text is exactly `48:00`.
- [x] Commit and push `Add Lieberman oil barrel finisher` (`91a1aa5`); then record and push its hash.

---

### Task 13: Mansour Abbas — money storm actors

**Files:**
- Create: `assets/finishers/mansour_abbas/props/dollar-bundle-*.png`
- Create: `assets/finishers/mansour_abbas/effects/money-storm-*.png`
- Create: `assets/finishers/mansour_abbas/celebration/counting-cash-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `mansour_abbas/coalition_cashstorm`; proves repeated lightweight actors and mobile density reduction.

- [x] Follow the template; assert three stagger hits, one oversized-bundle final hit, maximum 12 desktop actors and reduced mobile count.
- [x] Commit and push `Add Mansour Abbas cashstorm finisher` (`d304298`); then record and push its hash.

---

### Task 14: Gadi Eisenkot — bazooka projectile

**Files:**
- Create: `assets/finishers/gadi_eisenkot/props/bazooka-*.png`
- Create: `assets/finishers/gadi_eisenkot/props/rocket-*.png`
- Create: `assets/finishers/gadi_eisenkot/effects/rocket-smoke-*.png`
- Create: `assets/finishers/gadi_eisenkot/effects/rocket-impact-*.png`
- Create: `assets/finishers/gadi_eisenkot/celebration/salute-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `gadi_eisenkot/bazooka_command`; proves projectile tracking, recoil and smoke cleanup.

- [x] Follow the template; assert one projectile, one final hit, smoke cleanup and grounded salute.
- [x] Commit and push `Add Eisenkot bazooka finisher` (`2a4f501`); then record and push its hash.

---

### Task 15: Yair Golan — M16 bursts and Kaplan celebration

**Files:**
- Create: `assets/finishers/yair_golan/props/m16-*.png`
- Create: `assets/finishers/yair_golan/effects/muzzle-flash-*.png`
- Create: `assets/finishers/yair_golan/actors/kaplan-crowd-*.png`
- Create: `assets/finishers/yair_golan/props/democracy-sign-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `yair_golan/m16_burst`; crowd actors remain background-only and signs use exact text `DEMOCRACY`.

- [x] Follow the template; assert two stagger bursts, one final burst, non-graphic effects, weapon-lowered celebration start and crowd depth behind Golan.
- [x] Verify readable democracy signs without covering the winner or result overlay; Hebrew sign art remains unmirrored on either side.
- [x] Commit and push `Add Yair Golan M16 finisher` (`b7a4009`); then record and push its hash.

---

### Task 16: Itamar Ben-Gvir — crocodile sequence

**Files:**
- Create: `assets/finishers/itamar_ben_gvir/actors/crocodile-*.png`
- Create: `assets/finishers/itamar_ben_gvir/props/enclosure-*.png`
- Create: `assets/finishers/itamar_ben_gvir/effects/crocodile-impact-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `itamar_ben_gvir/crocodile_release`; proves three ordered ground actors and celebration lineup.

- [x] Follow the template; assert three unique crocodile actors, two stagger hits, third final hit and all shadows remain on the floor.
- [x] Commit and push `Add Ben Gvir crocodile finisher` (`bcbe25a`); then record and push its hash.

---

### Task 17: Bezalel Smotrich — cattle herd

**Files:**
- Create: `assets/finishers/bezalel_smotrich/actors/cattle-*.png`
- Create: `assets/finishers/bezalel_smotrich/effects/herd-dust-*.png`
- Create: `assets/finishers/bezalel_smotrich/celebration/ranch-pose-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `bezalel_smotrich/cattle_charge`; proves two depth layers and mobile herd reduction.

- [x] Follow the template; assert central cattle final-hit ownership, rear-layer non-collision, capped actor count and tinted background silhouettes.
- [x] Commit and push `Add Smotrich cattle charge finisher` (`7c6291d`); then record and push its hash.

---

### Task 18: Aryeh Deri — campaign entourage and prayer

**Files:**
- Create: `assets/finishers/aryeh_deri/actors/campaign-operative-*.png`
- Create: `assets/finishers/aryeh_deri/props/campaign-sign-*.png`
- Create: `assets/finishers/aryeh_deri/celebration/prayer-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `aryeh_deri/campaign_entourage`; the celebration transitions from active effects to a quiet prayer tableau.

- [x] Follow the template; assert two foreground passes, one final sign impact, all crowd actors cleaned before prayer and no attack effect during celebration.
- [x] Commit and push `Add Deri campaign finisher` (`fec02b0`); then record and push its hash.

---

### Task 19: Joint List — miniature squad and knafeh celebration

**Files:**
- Create: `assets/finishers/joint_list/actors/chaos-squad-*.png`
- Create: `assets/finishers/joint_list/effects/comic-blast-*.png`
- Create: `assets/finishers/joint_list/props/knafeh-table-*.png`
- Create: `assets/finishers/joint_list/celebration/knafeh-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `joint_list/two_headed_chaos_squad`; supporting actors are fictional, masked and contain no ethnic or religious markings.

- [x] Follow the template; assert two stagger crossings, one final comic blast, squad cleanup before celebration, and both heads participate in eating/sharing knafeh.
- [x] Commit and push `Add Joint List chaos squad finisher` (`ea4102a`); then record and push its hash.

---

### Task 20: Donald Trump — B-2 flyover

**Files:**
- Create: `assets/finishers/trump/actors/b2-bomber-*.png`
- Create: `assets/finishers/trump/effects/target-marker-*.png`
- Create: `assets/finishers/trump/effects/b2-impact-*.png`
- Create: `assets/finishers/trump/celebration/victory-dance-*.png`
- Modify: `data/finishers.json`
- Test: `tests/test_finisher_roster.gd`

**Interfaces:** Produces `trump/b2_flyover`; proves overhead-pass camera, background aircraft and reduced mobile effects.

- [x] Follow the template; assert target lock, one non-graphic final blast, aircraft exit cleanup and distant celebration flyover.
- [x] Verify the plane remains recognizable at landscape-phone size and below the HUD safe area.
- [x] Commit and push `Add Trump B2 flyover finisher` (`69441ca`); then record and push its hash.

---

### Task 21: Complete roster release, performance and GitHub Pages verification

**Files:**
- Create: `tests/test_finisher_visual_budget.gd`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`
- Modify: `.github/workflows/deploy-pages.yml` only if the export needs an explicit validation step

**Interfaces:** Consumes all 13 implemented definitions and the existing Pages workflow. Produces a published release with no planned stubs.

- [x] **Step 1: Write the complete-roster and budget test**

Assert 13 implemented entries, no missing assets, no unsupported events, actor cap `<=12` at mobile density, one result marker per celebration, and cleanup count zero after every sequence.

- [x] **Step 2: Verify all roster items are complete**

- [x] **Step 3: Resolve only roster-wide validation or performance defects**

Do not redesign approved character sequences in this task.

- [x] **Step 4: Run fresh complete verification**

Run all `tests/test_*.gd` serially with unique logs, `python -m unittest`, `git diff --check`, and `tools/validate_finisher_assets.py`.

- [x] **Step 5: Capture every finisher and celebration**

Produce 26 desktop captures and 26 landscape-phone captures under ignored `output/finisher-review/release/`. Review clipping, grounding, required text, effect density and result handoff, then confirm none are staged.

- [x] **Step 6: Push release documentation**

Mark every checklist item complete with delivery records, update README controls and AGENTS status, commit `Complete finisher and celebration roster`, and push.

- [x] **Step 7: Verify GitHub Pages**

Wait for the workflow to succeed. Verify `/`, `index.wasm`, `index.pck`, `index.manifest.json` and `index.service.worker.js` return HTTP `200`. Open the published game at `844×390`, enter a fight and run one finisher with no browser errors.

## Standard verification commands

Focused Godot test on Windows:

```powershell
$godot = Join-Path (Get-Location) 'tools\godot-portable\Godot_v4.7.2-stable_win64.exe'
$proc = Start-Process -FilePath $godot -ArgumentList @('--headless','--path','.', '--log-file','.godot\focused.log','--script','res://tests/test_finisher_rules.gd') -WindowStyle Hidden -Wait -PassThru
if ($proc.ExitCode -ne 0) { Get-Content '.godot\focused.log'; exit $proc.ExitCode }
```

Full Godot suite:

```powershell
$godot = Join-Path (Get-Location) 'tools\godot-portable\Godot_v4.7.2-stable_win64.exe'
$failed = @()
Get-ChildItem tests -Filter 'test_*.gd' | Sort-Object Name | ForEach-Object {
  $log = Join-Path '.godot' ($_.BaseName + '-full.log')
  $proc = Start-Process -FilePath $godot -ArgumentList @('--headless','--path','.', '--log-file',$log,'--script',('res://tests/' + $_.Name)) -WindowStyle Hidden -Wait -PassThru
  if ($proc.ExitCode -ne 0) { $failed += $_.Name }
}
if ($failed.Count -gt 0) { throw ('Failed: ' + ($failed -join ', ')) }
```

Python and repository checks:

```powershell
python -m unittest
python tools/validate_finisher_assets.py
git diff --check
git status --short
```
