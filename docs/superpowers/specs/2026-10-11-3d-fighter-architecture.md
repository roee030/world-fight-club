# 3D fighter architecture spec (approved 2026-10-11)

Companion to `docs/superpowers/plans/2026-10-11-pro-3d-fighter-master-plan.md` (the WHY and milestones). This file is the HOW. Owner decisions: realistic 3D, rigged characters on one humanoid skeleton, free tools for now, Easy + Pro controls, online rollback later, optional 2v2.

## 0. Why the current code is replaced, not refactored

- `scripts/fighter.gd` is a `CharacterBody3D` with `move_and_slide`, float timers in seconds, time-based `MOVES`, a distance-check hit (`_try_hit`) and string-bonus combos (`data/combos.json`). Visual calls are mixed into combat. Not rollback-safe.
- `project.godot` uses `gl_compatibility` everywhere: the main constraint on realism.
- Animation is wall-clock driven (`quaternius_motion.gd` `play()` + speed stretch), so the strike pose and the active frame drift apart.
- The 2026-10-06 3D attempt (`rigged_fighter_visual.gd`, `fighter_clothing.gd`) built identity in code on a generic body. Never again: identity comes from a complete per-character model.

## 1. Layers (hard boundaries)

```
input/    devices -> raw bitmask per local player per tick
sim/      pure deterministic. RefCounted + PackedInt32Array/ints only. No Node, no float, no engine physics, no delta.
net/      rollback session around Sim.step(); transports
present/  reads snapshots + event stream; never writes sim
content/  JSON -> compiled int tables; GLB + bone map -> CharacterView
tools/    Frame Lab, box baker, content validator, replay runner, capture
```

Single entry point: `Sim.step(state: MatchState, inputs: PackedInt32Array) -> events`. Everything the next tick needs is in `state`. Replays, rollback and the CPU sit on this one function. Replays record post-CPU inputs, so the CPU is not part of the deterministic sim.

### Modules

| File | Responsibility |
|---|---|
| `sim/fx.gd` | Fixed point: 1 m = 10 000 units (int), velocity units/frame, gravity units/frame². Percent math `*n/100` floor. No trig. |
| `sim/layout.gd` | Named indices into each fighter's flat int array (pos, vel, facing, state_id, state_frame, hitstop, hitstun, juggle, meters, combo, flags). Snapshot = duplicate; hash = HashingContext over bytes. |
| `sim/match_state.gd` | frame, rng (xorshift32 in state), round timer, fighters[N] (N per side from day one for 2v2), projectile pool, data_version. |
| `sim/input_history.gd` | 64-frame ring per fighter in state; facing-relative numpad directions; SOCD cleaning; press/release edges. |
| `sim/command_parser.gd` | Motions 236, 214, 623, 41236, 22, 66/44, charge [4]6, 236236; chords (LP+LK throw). ~8-10 f per step leniency, priority order (623 over 236). Buffer 4 f normals, ~10 f cancels. |
| `sim/easy_mode.gd` | Inside the sim, per fighter `control_mode`. Easy buttons -> same canonical command ids before the state machine; auto-combo routes; assisted specials at 80% damage. |
| `sim/moveset_compiled.gd` | Immutable int tables compiled once from JSON; shared per archetype. |
| `sim/state_machine.gd` | Every state is a move record (idle, walk, crouch, prejump, air, land, dash, backdash, blockstun hi/lo, hitstun, launched, wall_splat, ground_bounce, kd soft/hard, getup, techroll, thrown, ko, cinematic). One transition function; cancels read move cancel windows. |
| `sim/motion.gd` | Velocity, dual gravity + juggle gravity scaling, push-boxes (split correction), walls/corner, push-back (attacker pushed when defender is cornered). |
| `sim/collision.gd` | Integer AABB in the x/y plane: hit, hurt, throw, proximity-guard, push. |
| `sim/hit_resolver.gd` | Simultaneous: collect all contacts from pre-hit state, then apply. Order: throw vs throw -> tech -> strike vs throw -> parry -> armor -> block -> hit; trades; counter / punish counter. |
| `sim/combo.gd` | Scaling, starter penalties, juggle points, gravity scaling, hit cap, wall-splat/ground-bounce/OTG once per combo, true-combo flag, super damage floors. |
| `sim/meter.gd` | Drive / Super / Surge. |
| `sim/sim.gd` | Fixed tick order (below), emits events. |
| `net/rollback_session.gd` | Small GGPO-style session: input queue, prediction, 10-frame snapshot ring, resim, time sync, hash exchange every 30 f. `net/sync_test.gd` rolls back every frame. Transports: local loopback (delay/jitter/loss) and WebRTC. Nakama for matchmaking later. |
| `present/battle_view.gd` | 60 Hz accumulator in `_process`, calls the sim, interpolates between snapshots for >60 Hz displays. |
| `present/character_view.gd` | Model + AnimationTree sampler, facing (rotate 180°, no mirroring), hit-stop shake, hit flash. |
| `present/anim_sampler.gd` | `(state_id, state_frame)` -> clip time through a piecewise-linear time warp from move data; AnimationTree in manual mode (TimeSeek A/B -> Blend2 crossfade -> Add2 additive flinch), `advance(0)`. After rollback just sample the corrected frame. |
| `present/camera_director.gd` | Side framing (midpoint, distance zoom); super camera tracks from data; sim is in `cinematic` state during supers. |
| `present/vfx_director.gd`, `audio_director.gd` | Event-driven, keyed by (frame, fighter, kind, move); dedupe on resim, retract vanished events. |
| `present/debug_overlay.gd` | Boxes, SF6-style frame meter, state name, input display. |
| `input/device_input.gd` | Keyboard, gamepad, touch -> bitmask. Reuse `scripts/virtual_stick.gd`, `scripts/touch_action_button.gd`. Easy and Pro touch layouts. |
| `content/character_loader.gd` | `data/fighters/<id>.json` -> GLB (res:// or user://) -> bone map to `SkeletonProfileHumanoid` -> retarget -> CharacterView. |
| `content/bone_conventions.gd` | From `scripts/humanoid_bone_map.gd`: name tables for UAL, Mixamo (`mixamorig:*`), Avaturn, MetaPerson. |
| `content/model_validator.gd` | One skinned skeleton, profile bones present, T/A rest pose, 1.60-2.00 m, ≤35k tris mobile / 60k desktop, ≤3 materials, 2K textures, clothing skinned in the model. |
| `content/anim_library_builder.gd` | From `quaternius_motion.gd` `bind()`: merge UAL1/UAL2/Mixamo/mocap clips into one shared AnimationLibrary. |
| `tools/frame_lab/` | Replaces Sprite Lab: frame step, scrub clip vs sim frames, edit warp keys and boxes, save JSON. |
| `tools/bake_move_boxes.gd` | Headless: play clips through the warp, record hand/foot/body bones per frame, propose hit/hurt boxes and displacement for designer approval. |

### Tick order (`sim/sim.gd`)
1. Inputs -> history -> Easy translation -> command parse. 2. Per-fighter hit-stop gate. 3. Transitions (buffer, cancels). 4. Advance state frames. 5. Velocity, gravity, position. 6. Push-boxes, walls. 7. Facing (grounded + neutral only). 8. Collect contacts. 9. Resolve + apply hits. 10. Meters, timers. 11. Round/KO. 12. Emit events.

## 2. Character pipeline

- Identity only from a complete per-character GLB (body, head, hair, clothes skinned), made outside the engine (Avaturn / MetaPerson / Meshy / Tripo, cleaned in Blender). The engine never adds clothing/props. Retire `fighter_clothing.gd`, `fighter_accessories.gd`, `character_visual_catalog.gd`.
- Bundled characters: GLB import Retarget -> BoneMap -> `SkeletonProfileHumanoid` + Rest Fixer. Animation libraries imported the same way, so every clip plays on every fighter.
- Runtime selfie avatars (user://): `GLTFDocument` load, rename bones via `bone_conventions.gd`, drive a hidden canonical puppet with the shared library, copy poses with `RetargetModifier3D` (verify availability in 4.7 in M0). Fallback: avatar server step outputs canonical naming + rest pose.
- Gameplay boxes belong to the move/archetype, scaled by integer `height_permille`; never read bone positions at runtime.

## 3. Meter design

- **Drive (6 stocks, regenerates):** Parry (hold, drains; perfect parry first 2 f), Rush (1 from parry, 3 from a normal cancel; in air / after launcher = super dash), Vanish (3; teleport behind/above, once per combo as extender), Impact (1; 2-hit armor; wall splat when blocked in corner), Reversal (2; guard cancel). Burnout at 0: no drive actions, chip on block, blocked Impact = stun.
- **Super (3 bars):** L1 fast reversal, L2 combo extender, L3 cinematic with damage floors.
- **Surge (Heat-like, once per round):** Drive+Super or a Surge-engager hit; 600 f or until a super; Drive regen x2, chip on block, one enhanced special, one Surge Smash; activation returns 1 Drive stock; longer below 30% HP.
- **Counter / punish:** counter-hit (startup) +2 f hitstun, x1.2 damage; punish counter (recovery) +4 f, x1.2, drains 0.5 Drive.
- **Throws:** 5 f startup, 10 f tech window; throw-invulnerable in hitstun, blockstun, wake-up frames 1-3 and prejump.

## 4. Controls

- **Pro:** LP, HP, LK, HK, Drive; Throw = LP+LK; Super = 236236 + any. Motion specials, manual chains and strings. Touch Pro uses stick sectors.
- **Easy (touch default):** Attack repeated = auto-combo (direction picks route); Special + direction = 4 specials; Super picks level from bars; Drive tap = parry, forward+Drive = rush, Drive+Attack = impact. Assisted 80% damage. Translation in `sim/easy_mode.gd`, so the opponent sees identical moves and frame data.

## 5. Reuse vs retire

Reuse: `main.gd` shell (menus, safe area, web bridge, audio), `scripts/hud/slant_bar.gd`, `scripts/ui/callout.gd`, `super_move_card.gd`, `result_fx.gd`, touch widgets; feel numbers in `data/fighter_tuning.json` (convert to fixed point); loader pattern of `scripts/fighter_tuning.gd`; ideas of `cpu_brain.gd` (habits, intents, reaction time) ported to read snapshots and output input bits; library loading of `quaternius_motion.gd`; `humanoid_bone_map.gd`. Combat glue in `main.gd` (`_physics_process`) moves to `scenes/battle/battle.tscn` + `present/battle_view.gd`.

Retire (freeze as legacy until the new battle scene is default at end of the vertical slice, then delete, updating AGENTS.md in the same commit): `fighter.gd` combat, `data/combos.json`, sprite pipeline (`fighter_visual.gd`, `sprite_motion.gd`, `tools/slice_sprite_sheets.py`), satire finishers (`data/finishers.json`, `scripts/finishers/`) and their tests.

## 6. Move data schema

Files: `data/movesets/universal.json`, `data/movesets/<archetype>.json`, `data/fighters/<id>.json`, `data/system/combo_rules.json`, `data/system/meter_rules.json`.

```json
{
  "schema": 1, "moveset": "rushdown", "inherits": "universal",
  "moves": {
    "5HP": {
      "type": "normal", "posture": "stand",
      "input": {"pro": "HP", "easy": null},
      "frames": {"startup": 10, "active": 3, "recovery": 18},
      "anim": {"clip": "Punch_Cross", "blend_in": 3, "warp": [[0, 0.00], [10, 0.21], [13, 0.30], [31, 0.72]]},
      "motion": [{"f": [1, 9], "vx": 120}],
      "hitboxes": [{"f": [10, 12], "box": [400, 1250, 900, 220], "group": 0}],
      "hurtboxes": [{"f": [1, 31], "box": [-250, 0, 500, 1800]}, {"f": [8, 20], "box": [250, 1200, 700, 250], "kind": "extended"}],
      "hit": {"damage": 800, "chip": 100, "level": "mid", "hitstop": 10, "hitstun": 21, "blockstun": 16, "pushback": [900, 1100],
              "on_air": {"juggle_cost": 1, "launch": {"vx": 150, "vy": 0}},
              "counter": {"hitstun_bonus": 2}, "punish": {"hitstun_bonus": 4, "launch": {"vx": 100, "vy": 900}},
              "properties": ["wall_splat"], "meter": {"super_on_hit": 300, "super_on_block": 150, "drive_on_hit": 250}},
      "cancels": [{"f": [10, 20], "on": ["hit", "block"], "into": ["special", "super", "drive_rush"]}],
      "invuln": [], "armor": [],
      "expected": {"on_hit": 3, "on_block": -2}, "tags": ["anti_air"]
    }
  },
  "strings": [{"name": "Rising Hammer", "seq": ["5LP", "5LP~HP", "5LP~HP~HK"]}],
  "auto_combo": {"ground": ["5LP", "5MP", "5HP", "236P"], "air": ["j.LP", "j.HP", "VANISH"]}
}
```

Boxes `[x_forward, y_up, w, h]` in units relative to root and facing; `f` ranges 1-based inclusive in sim frames; `warp` maps sim frame -> clip seconds (impact pose lands on the first active frame); `expected` exists only for tests. Fighter file: `{"id", "model", "bone_convention", "height_permille", "archetype", "stats": {...point-buy...}, "moveset_overrides", "palette", "voice"}`.

Combo rules: scaling `[100,100,80,70,60,50,40,30,20,10]` min 10%; light starter -10%; super floor 30/40/50%; juggle budget 6; gravity +4% per juggle hit; hit cap 20; wall splat / ground bounce / OTG once each per combo.

## 7. Milestones (detailed)

- **M0 spikes (go/no-go):** look (free realistic GLB, FPS under Compatibility/Mobile/Forward+), retarget (UAL + Mixamo clip via import BoneMap and runtime RetargetModifier3D), sim perf (GDScript fixed-point tick, 2 fighters, ~12 boxes, 8-frame resim, phone Web), sampling (AnimationTree manual + warp + crossfade). Gate: tick ≤ 0.25 ms on phone Web, else sim to GDExtension C++ before M1 grows.
- **M1 deterministic core + Frame Lab (mannequins):** walk, dash, backdash, jump, crouch, block, 4 normals, hitstop/hitstun/blockstun, push-boxes, corner; UAL mannequin through CharacterView; replay runner.
- **M2 real characters + anim sync:** loader, validator, shared library, two real GLBs, warp authoring, box baker, stand/crouch/air reactions.
- **M3 combo engine + Pro moveset:** parser, cancels, strings, 4 specials, launcher/juggle/wall splat/bounce/OTG, throws, counter/punish, scaling, combo counter, one L3 super with camera track, training mode.
- **M4 meters + Easy + CPU = vertical slice:** Drive/Super/Surge, easy_mode + touch layouts, CPU port, one stage, phone/Web/desktop builds. Gate: owner feel review; flip default; retire legacy.
- **M5 presentation polish**, **M6 online 1v1 rollback** (sync_test -> loopback -> WebRTC -> Nakama), **M7 breadth** (5 archetypes, selfie import, fairness matrix, 2v2).

## 8. Verification

- M1: same replay twice = equal hashes every frame; snapshot/restore at random frames = equal hash; golden replays in `tests/replays/*.json` (seed, inputs, checkpoint hashes, data_version; regenerate only with `--bless`); feel metrics ported from `tests/test_fighter_feel.gd`; push-box cap and corner.
- M2: validator for every fighter; anim-sync (impact key = first active frame; baked hand/foot inside hitbox); windowed capture replays with perceptual diff + human review at 1280×720 and 780×360.
- M3: per-move frame-data assertions vs `expected`; combo-route tests (true flag), listed non-combos fail; 100k-frame fuzz (no stuck state, hit cap, juggle budget, damage floor); parser tables.
- M4: Easy == Pro move ids with 80% scaling; meter rules; CPU fairness; Web smoke via Playwright.
- M5: draw-call/tri/texture budgets; FPS targets (≥60 desktop/Android, 30-60 Web).
- M6: sync_test (rollback 1-8 f every frame), loopback 0-200 ms with jitter and 5% loss, forced-desync report.
- Lint test: grep `sim/` for `float`, `Vector`, `Node`, `delta` -> fail.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Realism on phone/Web (Compatibility) | Per-platform renderer (Forward+ desktop, Mobile Android, Compatibility Web); 2 characters, baked-lightmap stage; custom skin shader (wrap, rim, AO, cheap SSS); compressed 2K textures; validator budgets. Measured in M0. |
| Licensing | Mixamo inside games OK, never raw files; check free-tier commercial terms; `assets/LICENSES.json` + test; prefer CC0 and own mocap. |
| Retarget quality | Humanoid profile + Rest Fixer; M0 spike; Blender cleanup; skinned clothing; turntable acceptance. |
| Authoring effort | Frame data per archetype moveset; baker proposals; Frame Lab; ship ~40 universal + ~15 archetype moves first. |
| GDScript rollback perf / Web | Flat int arrays, no per-tick allocation; benchmark gates; narrow Sim.step for a GDExtension port (needs dlink Web template); golden replays prove the port. C# excludes Web, so no Klotho. Write a small session rather than node-based rollback addons. |
| Float leaks | Lint test. |
| VFX/SFX after rollback | Event keys + dedupe/retraction. |
| Scope | Vertical slice M0-M4 is the only commitment before breadth. |
