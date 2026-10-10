# World Fight Club — "100x" plan: from amateur prototype to a pro 3D fighter

## Context

The owner judged the current game amateur: the combo engine "doesn't really work", animation is 12 still frames per fighter, and there is no real fighting-game depth. The goal is a game that can win the internet: smooth, animation-rich, action-packed fighting in the league of Tekken 8 / Street Fighter 6 / Dragon Ball FighterZ, phone-first, online (rollback) + offline, with a **personal fighter made from each player's selfie**.

Owner decisions (2026-10-11):
- **Realistic 3D** look (Tekken/SF6 direction), side-view 2.5D fighting plane.
- **Pivot from 2D sprites to rigged 3D characters** on one shared humanoid skeleton and one shared animation library, so every fighter (including user avatars) gets hundreds of moves automatically.
- **Free tools only** for now.
- **Two control modes** like SF6: Easy (one-button specials, assisted auto-combos) and Pro (motion inputs, manual combos).

Repo: `D:\fight-app` → `github.com/roee030/world-fight-club` (public, Pages deploys `main`).

## Research summary (what the best games actually do)

| Game | What makes it feel great | What we take |
|---|---|---|
| Street Fighter 6 | Frame-data precision; **Drive gauge** (one renewable meter for Parry, Rush, Impact, Reversal, Overdrive; empty = Burnout penalty); **Modern controls** (one-button specials, assist button turns mashing into real combos) | Drive-style single meter; Easy/Pro control modes; hit-stop + counter/punish-counter callouts |
| Tekken 8 | 3D realism, 10-hit strings, juggles from launchers, wall splats/floor breaks; **Heat** (once-per-round 10 s power-up favouring aggression, readable momentum) | Strings + launcher→juggle→wall-splat combo route; once-per-round "Heat" comeback state |
| Dragon Ball FighterZ | 3D models animated **frame-by-frame like anime (limited animation)**, no auto in-betweens; huge camera-cut supers; universal **auto-combo**, **super dash**, **vanish** (teleport behind) | Hand-stepped "on twos/threes" animation sampling for impact; cinematic super camera; universal super-dash + vanish as signature mechanics |

Key insight: in all three, **simulation and animation are separate**. The game runs a deterministic 60 Hz sim with frame data (startup/active/recovery, hitboxes per frame); the animation is sampled at the sim frame. That is what makes them both smooth and fair, and what makes rollback netcode possible.

Sources: [New Frame Plus on GGXrd/DBFZ animation](https://kotaku.com/breaking-down-the-animation-of-guilty-gear-and-dragonba-1836849279), [DBFZ 2.5D](https://cinemablend.com/games/1671520/why-dragon-balls-latest-game-has-2d-combat), [SF6 Drive system](https://dashfight.com/news/street-fighter-6-drive-system-explained-2880), [SF6 Modern controls](https://www.redbull.com/us-en/street-fighter-6-modern-vs-classic-controls), [Tekken 8 Heat](https://www.dexerto.com/tekken/tekken-8-heat-system-explained-2231285/), [Godot rollback addons](https://godotengine.org/asset-library/asset/2450), [Klotho deterministic C#](https://godotengine.org/asset-library/asset/5234), [Avatar platforms 2026 (RPM shut down)](https://avatarsdk.com/blog/2026/08/31/avatar-platforms-2026-whos-alive-whos-gone/), [Meshy auto-rig](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging).

## Game design target ("what the player feels")

**Universal system (every fighter):**
- Buttons: Light, Medium, Heavy, Special, + Guard/Parry. Directions: walk, dash/back-dash (double-tap), jump (neutral/forward/back), crouch.
- **Frame-data core**: every move has startup / active / recovery, hit-stun, block-stun, push-back, hit-stop, per-frame hitboxes and hurtboxes, cancel windows.
- **Combo grammar** (replaces the old `routes/strings` engine entirely):
  - Chains Light→Medium→Heavy (target combos), cancels Normal→Special→Super.
  - **Launcher → air juggle** with juggle-gravity scaling and a juggle-point limit; **wall splat / wall bounce**, **ground bounce**, OTG pickup once per combo.
  - Damage scaling per hit, minimum damage floor; counter-hit and **punish counter** with callouts.
  - Throws + throw tech; low/mid/high/overhead attacks; crouch/standing block.
- **Drive meter** (SF6-style, renewable): Parry (tap Guard), Drive Rush (dash cancel), Impact (armored strike), Reversal (escape pressure while blocking), Overdrive (EX specials). Empty → Burnout (slower, takes chip).
- **Super meter** (3 bars) for Super Arts with a **cinematic camera cut** (DBFZ-style), and one **Heat** state per round (Tekken-style comeback: power-up + unique chain).
- **Signature universal moves**: super dash (homing air dash), vanish (teleport behind, costs Drive).
- **Easy mode** (touch default): Special button + direction = special; tap Light repeatedly = auto-combo ending in a launcher/super; assisted combos deal ~80% damage. **Pro mode**: motion inputs (QCF, DP, charge), manual links, full damage. Same characters, both online.

**Per-fighter identity** (data, not code): archetype (rushdown, grappler, zoner, all-rounder, technical), stats (HP, walk speed, weight/juggle gravity, dash), 3-4 specials, 2 supers, a Heat move, unique strings. Personal avatars pick an archetype + spend a fixed stat budget (fair online).

**Feel/juice**: tiered hit-stop, camera shake + zoom punches, hit sparks per strength, slow-mo on round-winning hit, screen-space speed lines on super dash, dust/debris on wall splat and knockdown, crunchy layered SFX, announcer callouts ("COUNTER!", "PUNISH!", "WALL SPLAT!").

## Architecture (Godot 4.7, in `D:\fight-app`)

| Layer | New / reused | Responsibility |
|---|---|---|
| `sim/` deterministic core | **new** (replaces combat logic in `scripts/fighter.gd`) | Fixed 60 Hz tick, integer/fixed-point positions, explicit state machine, frame data, hit resolution, meters. No engine physics, no `delta`, seeded RNG. Snapshot save/load + state hash (rollback-ready from day one). |
| `data/moves/<archetype>.json`, `data/fighters/<id>.json` | **new** (extends `data/fighter_tuning.json`) | Move list with frame data, per-frame boxes, cancels, properties, animation clip + sampling; fighter stats + move set |
| `input/` | **new** | Device → per-tick input bitmask; 15-frame buffer; motion-input parser (Pro); Easy-mode macro layer; facing-relative directions |
| `presentation/fighter_view.gd` | **new**, reuses `scripts/rigged_fighter_visual.gd`, `scripts/humanoid_bone_map.gd` | Loads a character GLB, Godot humanoid retarget, samples the move's clip at the sim frame (`AnimationPlayer.seek`, no free-running time), stepped "on twos" option for impact frames, blends only in neutral |
| `presentation/director.gd` | **new**, reuses camera shake in `scripts/main.gd` | Hit-stop rendering, camera framing/zoom/cuts for supers, VFX + SFX triggers from sim events |
| CPU | rewrite of `scripts/cpu_brain.gd` on top of sim | Reads the same frame data: punishes, anti-airs, combos by level |
| Netcode (later) | addon or GDExtension | Rollback over the sim snapshot API; delay-based first |
| UI shell | reuse `scripts/main.gd` menus, HUD, touch pad, audio | Re-skinned; HUD gains Drive + Super bars, combo counter, callouts |

Retire: 12-frame sprite clips in `scripts/fighter_visual.gd` for combat (keep as fallback/Sprite Lab until 3D replaces it), old `routes/universal/signature` combo engine in `data/combos.json` + `fighter.gd` (`_try_hit`, `combo_data`), the satirical roster/finishers/campaign (moved to an optional legacy pack). `AGENTS.md` rule "use the existing sprite pipeline" is replaced by the 3D rules.

## Character pipeline (free tools)

1. **Identity model**: selfie → rigged realistic avatar via free tiers of **Avaturn** or **Avatar SDK MetaPerson** (GLB, humanoid rig, Mixamo-compatible). For designed fighters: AI image → 3D (Meshy/Tripo free tier) → auto-rig. Lesson from the failed 2026-10-06 attempt: identity must come from a real per-character model, never a generic base body with cut clothing.
2. **One skeleton**: import with Godot `BoneMap` + `SkeletonProfileHumanoid` so Mixamo, Quaternius UAL1/UAL2 (already in `assets/animations/quaternius`, CC0) and avatar rigs share one animation library.
3. **Animation library**: Mixamo martial-arts clips (free, usable in games) + UAL + **own moves recorded on a phone** with free AI mocap (FreeMoCap open-source; Rokoko Video / Plask free tiers) → cleaned in Blender (`tools/blender/`) → per-move clip with marked active frames.
4. **Budget** (phone + Web): ≤ 40k tris and one 2K texture set per fighter, ≤ 65-75 bones; LOD for 2v2.
5. The **12 Roee frames** (now in `assets/characters/sprite-sheets/new-roster/roee/`) become (a) an immediate 2D preview of the owner in the current game, (b) the look reference for the owner's 3D avatar. They are moved to `private/roee/` (git-ignored) before any commit.

## Milestones (each ends playable; vertical slice before breadth)

| # | Milestone | Done when |
|---|---|---|
| M0 | Housekeeping + instant gratification | Roee frames moved to `private/`; local-only 2D Roee test fighter playable on one stage (not pushed); `AGENTS.md`/master plan updated with the 3D pivot and this plan; old satirical content flagged as legacy |
| M1 | Deterministic sim core + frame data (still on current visuals) | `sim/` with state machine, move JSON, per-frame boxes, hit-stop, block-stun, counter-hit, throws; golden replay + same-input-same-hash tests; old `fighter.gd` combat behind an adapter |
| M2 | 3D vertical slice: 2 fighters, 1 stage | Owner avatar (Avaturn/MetaPerson free) + 1 designed fighter on the shared skeleton, retargeted Mixamo/UAL/mocap clips sampled by sim frame; walk, dash, jump, 3 normals each strength, 2 specials, block, hit, knockdown, get-up; realistic lighting on a 3D stage |
| M3 | Combo system v2 | Chains, cancels, launcher→juggle, wall splat/bounce, OTG, scaling, punish counter; training mode (frame data, hitbox view, input display, record/playback dummy) |
| M4 | Meters + signature mechanics | Drive (parry, rush, impact, reversal, burnout), Super Arts with cinematic camera, Heat, super dash, vanish |
| M5 | Controls | Easy + Pro modes on touch/keyboard/gamepad; tutorial rewritten for both |
| M6 | Juice pass | Hit sparks, tiered hit-stop/shake, slow-mo KO, SFX layering, announcer, stage reactions |
| M7 | CPU + balance | New brain on frame data; fairness matrix (CPU vs CPU per archetype pair, jump-only / turtle bots) |
| M8 | Roster + personal-fighter pipeline | 5 archetype templates; selfie → avatar → archetype + stat budget → playable; consent/safety flow from `docs/character-art/personal-fighter-flow.md` |
| M9 | Online | Delay-based → rollback on the sim snapshot API; matchmaking (Nakama), desync hash checks |
| M10 | Retention + app | Progression, daily challenges, replays (inputs only), Android/iOS export, store compliance; optional 2v2 |

## Verification

- Every milestone: headless deterministic tests via `tests/helpers/fight_sim.gd` (extended to the new sim): frame-data assertions per move, combo-route tests, replay hash equality, CPU fairness matrix; full suite with `timeout 90` per test (Godot exe at `D:\election world fight\tools\godot-portable\Godot_v4.7.2-stable_win64_console.exe`).
- Visual: Playwright/Godot captures at 1280×720 and phone size of the slice (walk, combo, launcher-juggle, wall splat, super cut-in); owner plays the Pages build before each milestone merges.
- Known pre-existing failing finisher tests stay documented, not masked.

## Risks

| Risk | Mitigation |
|---|---|
| Realistic 3D on Web/phone with `gl_compatibility` renderer (`project.godot:54`) | Baked lighting + light probes on stages, PBR-lite materials; native app builds use the Mobile renderer; strict tri/texture budget |
| Free avatar tiers (watermarks, limits, terms) | Prototype only on free tiers; abstract the avatar provider behind one import step; decide paid tier before public launch |
| Mixamo licence (use in games OK, no redistributing raw clips) and retarget quality | Bake clips into game resources, never ship raw FBX; own mocap for signature moves; retarget QA scene |
| Animation ↔ hitbox authoring effort | Hitboxes authored in data with a visual editor overlay in the training mode; boxes keyed to frames, not to bone positions |
| GDScript too slow for rollback resim with 4 fighters | Benchmark in M1; move the sim to GDExtension (C++/Rust) or C# if over budget |
| Scope | Vertical slice (M2) is the go/no-go gate before any breadth |
