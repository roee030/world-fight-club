# Fighter Engine Flow Plan (proposal — awaiting owner decisions)

> Status: **proposal, 2026-10-09, not implemented.** Read `AGENTS.md` first. Goal: make strikes, walking and jumping feel fluid and responsive, like a console fighter, without new sprite art and without breaking the 12-frame contract, grounding, finisher or fairness rules. Relationship to `2026-10-09-combo-system-plan.md`: this plan is the **foundation** the combo system builds on (frame data, input history, hit reactions). Recommended order is in section 6.

## 1. Diagnosis (what makes the current engine feel stiff)

Each item points at the code that causes it. Numbers are measured from the current constants.

| # | Problem | Cause | Effect on feel |
|---|---|---|---|
| D1 | **The strike pose appears before the hit is real.** | `SpriteMotion.play_state` stretches a 4-frame clip (`[0,4,4,0]`, `[0,5,5,0]`, `[0,6,6,0]`) *uniformly* over the move duration, so the strike frame shows at 25% of the duration. Heavy: pose at 0.165 s, active at 0.235 s. Kick: 0.18 vs 0.25. Special: 0.21 vs 0.28. | Punches look like they connect ~4 frames before damage arrives: "ghost" hits, delayed feedback, the rival seems to absorb the first frames. |
| D2 | **Walking is sluggish to start and stop.** | `fighter.gd:302` — acceleration 13 m/s² to ~3.25 m/s (0.25 s to full speed), deceleration 18 (0.18 s slide). Walk clip has 2 frames at 8.5 fps. | Spacing feels like ice. Fighting games reach walk speed in 2–4 frames. |
| D3 | **Jump is floaty and repeats on its own.** | Jump input is level-triggered (`main.gd:346` passes a held key; `fighter.gd:320` jumps whenever grounded) so holding W/stick-up bunny-hops. Air control uses the ground acceleration (`fighter.gd:303` has no floor check). One gravity for rise and fall. Facing flips mid-air when crossing over (`fighter.gd:259` has no floor check). `jump_air` uses frame 6 (the kick frame) as its pose. | Jumps feel like floating, not a committed arc; crossing jumps flip the sprite in the air; the air pose reads as a kick that never hits. |
| D4 | **No air attacks.** | Attacks can start in the air (no floor check in `action_allowed`) but play the ground clip, and `_try_hit` rejects any vertical gap > 0.95 m except the special. | Pressing attack while jumping does a useless standing punch in the air. The "jump-in" is missing, which is the core of fighting-game flow. |
| D5 | **Bodies snap instead of pushing.** | `fighter.gd:349-358` teleports a fighter to exactly 1.05 m from the rival each frame they overlap. No attacker push-back on hit or block. | Walking into the rival jitters; lunges stop dead; on-hit spacing is random, so chains sometimes drift out of range. |
| D6 | **The input buffer leaks during hit-stop.** | `fighter.gd:239-241` decrements `buffer_time` *before* the hit-stop early return. | A chain pressed during the freeze is more likely to be dropped, exactly on heavy hits where the player expects it most. |
| D7 | **Twelve frames with no in-between motion.** | `_animate()` resets `scale`, `rotation` and `position.y` every frame; there is no procedural layer. | Movement looks like a slideshow: no anticipation, no impact squash, no landing weight, no hit recoil shake. |
| D8 | **Hit reactions are all alike.** | `receive_hit` uses one `hit` frame and a fixed knockback for everything except special. No block-stun table, no counter-hit. | A jab and a kick feel the same to receive; blocking has no readable advantage/disadvantage. |
| D9 | **Tuning is hard-coded in if-chains.** | Speed (`fighter.gd:291-297`), HP (`max_health`) and damage multipliers (`_try_hit`) are per-character `if` lines. | Every balance tweak is a code edit; roadmap item 3 is still open. |
| D10 | **Motion judders on high-refresh / Web screens.** | 60 Hz physics with no physics interpolation (Godot 4.7 supports it for 3D). | On 90–144 Hz displays fighters step instead of glide. |

## 2. Design principles

1. **Frame data is the single source of truth.** Every move is described in frames @60 Hz (startup / active / recovery, hit-stun, block-stun, push-back, hit-stop). The animation is *generated from* that data, never the other way round.
2. **Commit and readability.** Ground moves are instantly responsive; jumps and attacks are commitments with a readable arc and recovery.
3. **Juice without new art.** In-between motion comes from a procedural transform layer on a foot pivot, so feet stay on the floor and the 12-frame/geometry contracts are untouched.
4. **Everything measurable.** Each feel change has an automated metric from a deterministic simulation harness (section 4), plus a 1280×720 and phone-size screen inspection.
5. **Phone first.** No inputs that need frame precision. New techniques (dash) use gestures the touch pad already has (stick double-tap); action buttons still dispatch once, on press.

## 3. Target design

### 3.1 Explicit fighter state machine
Replace the implicit combination of `busy / stun / knockdown_time / recovery_time / attack_kind / jump_phase` with one `state` and a single `_transition(to)` function:

`IDLE · WALK · DASH · BACKDASH · PREJUMP · AIR · LAND · ATTACK(startup|active|recovery) · AIR_ATTACK · BLOCK · BLOCKSTUN · HITSTUN · KNOCKDOWN · GETUP · KO · CINEMATIC`

- Migrate in two steps to keep risk low: (a) add a read-only `state` derived from the current timers and assert it in tests; (b) move logic into per-state `_tick_<state>()` functions. Keep the public fields (`attack_kind`, `attack_time`, `attack_confirmed`, `stun`, `knockdown_time`…) as compatible read-outs, because `cpu_brain.gd`, the finisher director, the tutorial and many tests read them.
- Pause, cinematic lock and `reset_round` become transitions, so cleanup lives in one place.

### 3.2 Input layer (`scripts/fighter_input.gd`)
- A per-frame `InputFrame` (axis, depth, jump *pressed*, block, crouch, attack pressed) stored in a 30-frame ring buffer.
- Jump becomes edge-triggered (press), fixing the bunny-hop (D3).
- Detects **double-tap forward / back** (≤ 0.22 s) for dash, and is reused by the combo plan's GUARD double-tap breaker and string matcher.
- Buffer timers do not advance during hit-stop (D6). Buffer stays 0.34 s.
- Facing-relative directions (`forward/back`) are resolved here, not in the brain.

### 3.3 Ground movement
| Value | Now | Target |
|---|---|---|
| Time to walk speed | 0.25 s | ≤ 0.07 s (accel ≈ 48 m/s²) |
| Stop slide | 0.18 s | ≤ 0.05 s (decel ≈ 70 m/s²) |
| Back-walk speed | = forward | 0.8 × forward (classic, readable retreat) |
| Dash forward | — | 0.20 s, ~1.3 m, cancellable into attack from frame 6 |
| Back-dash | — | 0.26 s, ~1.1 m, not cancellable, no invulnerability (no exploit) |
| Walk clip | 2 frames @ 8.5 fps | Same frames, speed scaled to actual velocity + procedural bob (3.6) |

- **Soft push-box** replaces the 1.05 m snap (D5): overlap is resolved by splitting the correction between both fighters (capped at 0.06 m per frame) and removing only the closing velocity. The corner rule stays: a cornered fighter does not move, the other one yields.
- **Push-back on hit/block**: the defender slides away; if the defender is in the corner, the attacker is pushed back instead. This keeps chains in range and stops infinite corner pressure.
- Facing turns only when grounded and not committed; it is locked while airborne and resolves on landing (fixes the mid-air flip).
- Per-fighter walk speed moves to data (3.7).

### 3.4 Jump
- **Prejump** 3 frames (`jump_start`), during which the direction is read: neutral, forward or back jump.
- **Committed arc**: horizontal velocity is fixed at takeoff (forward 3.4 m/s, back 3.0 m/s, neutral 0); air drift is limited to ±15% so the arc stays readable.
- **Two gravities**: rise 20 m/s², fall 27 m/s², apex ≈ 1.2 m, total air time ≈ 0.58 s (now 0.65 s, symmetric and floaty).
- **Landing**: 3 frames neutral landing; 6 frames after an air attack that whiffed (punishable, so jump-ins are not free).
- The current crossing logic (`jump_crossing`, lane offset) is kept: it already prevents landing inside the rival.
- `jump_air` pose changes from frame 6 (kick) to frame 3 (tuck), so frame 6 can mean "air kick" (D3/D4). The contract test for clip frames is updated accordingly.
- Shadow stays on the floor (unchanged rule) and grows lighter/smaller with height.

### 3.5 Strikes
**Frame-accurate clips (D1).** `FighterVisual` builds attack clips with *per-frame durations* (`SpriteFrames.add_frame(..., duration)`) generated from the move's frame data:

| Phase | Frame shown | Length |
|---|---|---|
| Anticipation | idle frame 0, with procedural lean-back | startup − 1 frame |
| Strike | 4 (jab), 5 (cross/hook), 6 (kick) | 1 frame before active → end of active |
| Hold | same strike frame | first ~40% of recovery |
| Recover | frame 0 | rest of recovery |

A test asserts that, for every fighter and every move, the strike frame first appears within ±1 frame of the active window start. Punch clips still never contain frame 6.

**Frame data (initial proposal, @60 fps; tuned with the fairness test):**

| Move | Startup | Active | Recovery | Hit-stun | Block-stun | On block | Hit-stop | Notes |
|---|---|---|---|---|---|---|---|---|
| JAB (light) | 7 | 5 | 14 | 20 | 12 | −2 | 4 | chain starter |
| CROSS (heavy) | 13 | 6 | 20 | 28 | 16 | −4 | 6 | upward hitbox = **anti-air** |
| KICK | 15 | 7 | 22 | 30 | 16 | −6 | 7 | longest reach, low push-back on hit |
| SPECIAL (MAX) | 17 | 8 | 26 | knockdown | 20 | −6 | 9 | unchanged energy cost |
| AIR PUNCH | 6 | 8 | until landing | 22 | 14 | — | 4 | frame 4 |
| AIR KICK | 8 | 10 | until landing | 26 | 16 | — | 6 | frame 6, the classic jump-in |

**Hitboxes instead of a distance check.** Each move gets a simple box (forward range, vertical band, depth band) and each state a hurtbox (standing / crouching / airborne). Rules from `AGENTS.md` stay: only during active frames, within reach, in the facing direction. This replaces two special cases: crouching naturally ducks under CROSS (lower hurtbox), and air attacks hit standing rivals (vertical band) instead of the `> 0.95 m` rejection.

**Rock–paper–scissors that comes for free:** jump-in beats a slow ground poke, CROSS beats a jump-in (anti-air), GUARD beats the jump-in pressure, dash-in beats a whiffed kick.

**Hit reactions (D8).**
- Light hit: small recoil (hit frame + 0.08 m shake during hit-stop).
- Heavy/kick hit: stagger slide (longer push-back, stronger shake).
- Special: knockdown (existing).
- **Counter-hit**: a hit that lands during the rival's startup gets +50% hit-stun and a "COUNTER" callout. Rewards reading the opponent; easy to understand.
- **Block**: own `BLOCKSTUN` state with the table values, a block spark and small push-back; chip damage stays as today.

**Hit-stop** per strength (table), with the defender shaking and the attacker frozen; the camera shake already in `main.gd` keys off the move strength. Buffered inputs survive the freeze.

### 3.6 Procedural motion layer ("juice", D7)
`SpriteMotion` gains a `Pivot` node placed at the feet; procedural transforms are applied to the pivot, never to the sprite's geometry values, so height, pixel scale and floor correction stay separate (AGENTS rule).

| State | Effect (amplitudes small, all from data) |
|---|---|
| Walk | 2–3 cm vertical bob synced to the walk frames, slight forward lean |
| Dash | forward lean + horizontal stretch 1.06, dust puff at start |
| Prejump | squash 0.92 |
| Rise / fall | stretch 1.05 / 1.02 |
| Land | squash 0.90 for 3 frames + dust |
| Attack startup | lean back 3°; strike frame lean forward 5° |
| Hit-stop (defender) | horizontal shake ±0.04 m, white flash 1 frame |
| Hitstun | recoil rotation away from the attacker |
| Knockdown | existing; add dust on floor contact |

Test: the lowest opaque pixel of the sprite stays within 1 cm of the floor in every grounded state (extends the existing grounding tests).

### 3.7 Data (`data/fighter_tuning.json`, roadmap item 3, D9)
- `moves`: the frame-data table above, hitboxes, push-back, hit-stop, clip mapping.
- `fighters.<id>`: HP, walk speed, back-walk factor, dash distance, jump velocities, damage multipliers (replacing the `if` chains, with today's values migrated 1:1 first).
- `motion`: procedural amplitudes.
- Loaded once by `scripts/fighter_tuning.gd` with schema validation (missing ids/moves fail a test). Sprite Lab reloads the file on a key press for live tuning.
- `MOVES` in `fighter.gd` stays as a read-only view so existing readers keep working.

### 3.8 CPU (`cpu_brain.gd`)
- Uses dash to close distance and back-dash to escape pressure (rate by level).
- Jump-ins by level (L1 rare, L4 mixes them in); anti-air with CROSS by reaction time (L1 seldom, L4 often), so the player is never forced to jump to win and cannot win only by jumping.
- Respects block advantage: does not attack straight after a blocked KICK at level ≥ 3 (uses the frame-advantage table to punish).
- `tests/test_combat_fairness.gd` stays green; add assertions that a "jump-only" scripted player and a "never-jump" scripted player both stay inside the win-ratio band.

### 3.9 Smooth rendering (D10)
Enable `physics/common/physics_interpolation` and call `reset_physics_interpolation()` on every teleport (round reset, cinematic lock, finisher anchors, corner yield). Verify finisher framing and Web build.

## 4. Verification harness (built first)

- `tests/helpers/fight_sim.gd`: builds two fighters on a floor without `main.gd`, steps exactly N physics frames with scripted `InputFrame`s, and records per-frame state, position, velocity, clip and frame. All new tests use it, so feel becomes numbers.
- **Feel metrics** (each one a test): frames to walk speed; stop distance; jump apex/air time; no re-jump while holding jump; no facing change in the air; strike frame vs active window for all 13 fighters × all moves; on-block advantage per move matches the table; buffered chain survives hit-stop; push-box never moves a fighter more than 0.06 m per frame; grounding of the pivot layer.
- **Sprite Lab overlay** (`character_debug.gd`): hitbox/hurtbox outlines, current state name, frame counter, active-frame flash, and a "step one frame" key. This is the tool for the hit-range tuning in roadmap item 2.
- Visual inspection after each phase: Playwright captures at 1280×720 and 780×360 of walk, dash, jump-in, anti-air, block, counter-hit and knockdown.

## 5. Phases

| Phase | Work | Key tests | Size |
|---|---|---|---|
| 0 Harness | `fight_sim.gd`, feel-metric tests written against today's behaviour (documenting D1–D6 as failing/expected-fail), Sprite Lab overlay | new `test_fighter_feel.gd` | S |
| 1 Data + state | `fighter_tuning.json` with current values (no behaviour change), `fighter_tuning.gd`, derived `state`, input layer with edge-triggered jump and hit-stop-safe buffer | all existing suites green + schema test | M |
| 2 Movement | fast walk, back-walk factor, dash/back-dash (keyboard double-tap, stick double-tap), soft push-box, push-back, grounded-only turn | walk/stop/dash metrics, push-box cap, corner rule | M |
| 3 Jump + air attacks | prejump, committed arc, dual gravity, landing recovery, `jump_air` → tuck, AIR PUNCH / AIR KICK, hitboxes/hurtboxes | jump metrics, air-hit tests, crouch-under-CROSS via hurtbox, clip contract | M |
| 4 Strikes | frame-data clips with per-frame durations, new frame-data table, block-stun, counter-hit, reaction tiers, hit-stop tiers | strike-frame alignment ×13, on-block advantage, counter-hit | M |
| 5 Juice | pivot transform layer, dust/flash VFX, camera shake tiers | grounding of pivot layer, visual captures | S–M |
| 6 CPU + balance | brain uses dash/jump-in/anti-air/punish; fairness thresholds incl. jump-only and never-jump bots | `test_combat_fairness.gd` | M |
| 7 Polish | physics interpolation, Web check, tutorial step for jump-in/anti-air (optional), README + `docs/character-pipeline.md` (clip contract change) | full Godot + Python suites, Web smoke | S |

Each phase follows the AGENTS workflow (failing test → smallest change → focused test → full suites → screen inspection) and lands as its own commit(s).

## 6. Order relative to the combo plan

Recommended: **phases 0–4 of this plan first, then the combo plan**, then phases 5–7. The combo system needs exactly what phases 1–4 produce (input history for strings and the GUARD double-tap breaker, frame data for true-combo checks, push-back so strings stay in range, block-stun for "a block stops a string"). Building combos on the current timing would mean tuning them twice.

## 7. Risks

| Risk | Mitigation |
|---|---|
| State-machine refactor breaks finishers, tutorial or CPU readers | Two-step migration with compatible read-outs; finisher/tutorial suites run after every phase |
| Faster walk + dash make the CPU easier to bully | Phase 6 is mandatory before release; fairness bots for jump-only/never-jump |
| `jump_air` frame change trips identity/clip tests | Update the contract and `docs/character-pipeline.md` in the same commit |
| Procedural layer makes fighters look like they float | Foot pivot + grounding test in every grounded state |
| Physics interpolation smears teleports | `reset_physics_interpolation()` on every teleport, covered by a test that checks interpolated position after reset |

## 8. Decisions needed from the owner

1. **Dash** (double-tap forward/back on keyboard and stick): yes (recommended) or no?
2. **Air attacks** (jump-in punch/kick) with CROSS as anti-air: yes (recommended) or no?
3. **Counter-hit** (+50% hit-stun, "COUNTER" callout): yes (recommended) or no?
4. **Order**: engine phases 0–4 before the combo plan (recommended), or combos first?
5. **Back-walk** slower than forward (0.8×): yes (recommended) or keep equal speeds?

GUARD stays a button (no "hold back to block"), because the phone control contract in `AGENTS.md` depends on it.
