# Pro fighting engine: depth, online, 2v2, mobile app

> **SUPERSEDED as the plan on 2026-10-11** by `2026-10-11-pro-3d-fighter-master-plan.md` + `../specs/2026-10-11-3d-fighter-architecture.md` (3D pivot). This file remains the running PROGRESS LOG (table below); append new rows here.

> **HANDOFF - read this first (updated as work lands; newest entry at the bottom of "Progress log").**
> Location: `D:ight-app` (its own git repo, forked 2026-10-10 from `D:\election world fight`; NEVER push to the old repo; do not push at all unless the owner asks).
> This file is the MASTER plan. The detailed engine spec is `2026-10-09-fighter-engine-flow-plan.md` (phases 0-7 there = Phases 1-4 here) and combos are `2026-10-09-combo-system-plan.md` (done). The owner's open decisions in the flow plan section 8 were answered by "build the pro engine": **adopt every recommended default** (dash yes, air attacks yes, counter-hit yes, engine before more combos, back-walk 0.8x).
> Working rules: follow `AGENTS.md`; headless test traps are in the memory file `godot-headless-test-gotchas` (preload scripts instead of relying on `class_name`; wrap runs in `timeout`).
> Run one test: `"D:/election world fight/tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_fighter_feel.gd`. Full suite: loop over `tests/test_*.gd` with `timeout 90` each, plus `python -m unittest discover -s tests -p 'test_*.py'`.
> Test harness for engine work: `tests/helpers/fight_sim.gd` (deterministic 60 Hz two-fighter stepper; preload it, `await sim.start(self, root, ...)`, `sim.step(axis, jump, block, crouch, attack)`).
> Characters/art are OUT OF SCOPE for this effort: the owner generates new character art elsewhere later; everything here must be data-driven.

## Progress log

| Date | Done | Evidence | Next |
|---|---|---|---|
| 2026-10-10 | Plan written. `data/fighter_tuning.json` + `scripts/fighter_tuning.gd` (HP, walk speed, damage mults moved out of if-chains, 1:1 values). Movement feel: walk accel 48/decel 70, back-walk 0.8x, committed jump arc (v 6.4, rise g 20, fall g 27, air drift 15%), edge-triggered jump (no bunny-hop), no mid-air facing flip, input buffer no longer ticks during hit-stop. Harness `tests/helpers/fight_sim.gd`. | `tests/test_fighter_tuning.gd`, `tests/test_fighter_feel.gd` pass | (superseded by 3D plan) Next: Phase 0 golden replays; derived `state` enum (flow plan 3.1); dash; air attacks; frame-data JSON for `MOVES`; blockstun/counter-hit; hit-stop tiers; CPU update + fairness bots. Then deterministic sim core (Phase 1 here). |
| 2026-10-11 | Owner chose realistic 3D, rigged pivot, free tools, Easy+Pro controls. Master plan + architecture spec written. Owner generated 12 pose images of himself; stored in `private/roee/frames` (git-ignored); local-only private fighter system (`scripts/private_roster.gd`, `tools/build_private_fighter.py`, `private/fighters.json`) lets `roee` play in the legacy game. | `tests/test_private_roster.gd` passes (with and without private fighters) | M0 spikes (sim perf, retarget, sampling, look), then M1 deterministic sim |
| 2026-10-11 (night, autonomous) | **New engine is playable** (menu: 3D ENGINE BETA, scene `scenes/battle/battle.tscn`). `sim/` deterministic integer sim: frame data from `data/movesets/universal.json` + rules `data/system/sim_rules.json`; hit/hurt boxes, hit-stop, hitstun/blockstun, high/mid/low/overhead, chains, launcher + jump cancel + air juggle, counter-hit, scaling, dash, push boxes/corner, KO/time; specials via motion parser (236/623/214/236236) and Easy SP+direction; projectile; invincible reversal; Super Art (3-bar gauge, super-freeze, damage floor); Drive gauge (parry/perfect parry, rush, armored impact, burnout); throws + tech; wall splat; normal->special/super/rush cancels. `present/`: 3D rigged views (UAL clips time-warped to the active frame + TwoBoneIK3D kicks/guard/blocks), stage backdrop, camera director, super cinematic, sparks, SFX, HUD (HP/Drive/Super/combo/callouts), touch stick + LP/HP/LK/HK/SP/DRIVE. `ai/cpu_pilot.gd` CPU (blocks, parries, anti-airs, combos, specials, supers). Local private fighter `roee` plays through `present/sprite_view.gd`. | `tests/test_sim_core.gd` (determinism, rollback resim, frame data, advantage, combos, lint, bench 22 us/frame), `tests/test_sim_systems.gd`, `tests/test_battle_scene.gd`, Python suite OK; visual captures checked locally | Next: Easy auto-combo, training mode (frame meter, hitbox overlay, dummy), FX polish (projectile glow/trail, hit sparks, KO slow-mo), character select (models), real character GLBs (Avaturn/MetaPerson) via `content/character_loader.gd` + retarget, mocap/Mixamo clips for kicks, rollback session (`net/`), retire legacy after owner review. Known: legacy finisher tests hang (pre-existing). |
| 2026-10-11 (night, continued) | Easy auto-combos (assisted 80%) + Easy/Pro toggle (Tab); hit feel (streak bursts, orb projectile, hit flash, super aura, zoom punch, KO slow-mo); **rollback netcode** `net/rollback_session.gd` + `net/loopback_transport.gd`; **online**: `server/relay.gd` (+Dockerfile, `docs/online-relay.md`), `net/ws_client.gd`, lobby `scenes/online/lobby.tscn` (menu ONLINE BETA); deterministic round flow in the sim (intro, wins, respawn, match over); **training mode** `present/training_overlay.gd` (menu TRAINING BETA; boxes, frame meter, advantage, dummy modes); **character pipeline** `content/` (bone conventions, runtime retarget of Mixamo/Avaturn/MetaPerson rigs, loader) + fighters as data `data/fighters/*.json`; select screen `scenes/battle/select.tscn`; **archetypes** `data/movesets/rushdown.json` (NOVA), `grappler.json` (TITAN, command grab) on top of universal (ATLAS); fight music, announcer, win/lose voice. | test_sim_core, test_sim_systems (incl. archetypes, command grab, round flow, Easy), test_rollback, test_online_relay, test_online_battle, test_character_loader, test_fighter_select, test_battle_scene; full suite 61/69 (8 = pre-existing legacy finisher hangs) | Owner: pick a relay host (docs/online-relay.md) and set relay_url; create real fighter GLBs (Avaturn/MetaPerson free export) -> add data/fighters/<id>.json; mocap/Mixamo clips for kicks/specials. Engineering next: HUD/menus to console polish, portraits rendered from models, more moves per archetype (multi-hit, projectiles for zoner), stage props/lighting, mobile layout pass, CPU per-archetype tactics, replays (inputs only), progression. |


## Goal

Same satirical idea, but feel like Brawlhalla / Street Fighter / Tekken: distinct characters,
real combos, addictive progression, online play, 2v2, shipped as a mobile app.

## Target decisions (from owner)

- Online play AND 2v2 are required. Final product is an app (Android first, iOS after).
- Touch-first controls stay: JAB, CROSS, KICK, SP, GUARD (plus direction). No motion inputs.

## Owner answers (2026-10-10)

- **1v1 is the core product.** 2v2 is an OPTIONAL extra mode (4 humans, or humans + CPU).
  The sim supports N fighters per side with a per-fighter input source (local, remote, CPU),
  but nothing in 1v1 may be compromised for 2v2. Top priority: smooth engine and addictive combos.
- **Final vision: every player gets a personal fighter** built from their own selfie plus
  preferences (look, strengths), used to fight everyone online and offline. See "Personal
  fighter" section below. This is a separate product/pipeline but the engine must be ready for it.
- Server: no preference, pick what is best (recommendation in chat: Nakama).
- Monetisation: undecided, keep out of scope.
- Platforms: Android and iOS in parallel. Stack decision: stay on Godot (see chat), no KMP/Unity rewrite.

## Assumptions to confirm before building (defaults chosen)

1. 2v2 optional mode, designed after 1v1 online is stable. Design spike (tag vs simultaneous,
   4-fighter camera, friendly fire off) before Phase 6.
2. Online = 1v1 ranked/casual first, 2v2 online after 1v1 is stable.
3. Netcode = **rollback** target, delay-based as first shippable step.
4. Engine stays Godot 4; export Android via Godot templates; iOS needs a Mac build step.

## Architecture truth that drives everything

Rollback netcode needs a **deterministic, serialisable simulation**. Today `fighter.gd` mixes
combat state with `CharacterBody3D` physics, floats and per-frame `delta`. That cannot be
rolled back or replayed reliably. So the first and most valuable work is a refactor that also
serves single-player quality (frame data, hit boxes, tests).

Target shape:

- `sim/` layer: fixed 60 Hz tick, integer or fixed-point positions, no engine physics, no
  randomness except a seeded RNG stored in state. Pure data in, pure data out.
- `FighterState` (explicit state machine enum) + `MatchState` snapshot: copyable dictionary,
  hashable (for desync detection).
- Presentation layer (`fighter_visual.gd`, camera, HUD, FX) reads snapshots and interpolates.
  It never mutates the sim.
- Input is an integer bitmask per fighter per tick (buffered inside the sim).

## Phases

### Phase 0: safety net (before any refactor)
- Golden replay tests: record input sequences, assert exact end state/HP for current engine.
- Keep `tests/test_combat_fairness.gd`, `test_combo_strings.gd`, `test_tutorial.gd` green.

### Phase 1: deterministic core + state machine
- Explicit state enum: IDLE, WALK, JUMP, CROUCH, BLOCK, ATTACK(startup/active/recovery),
  HITSTUN, BLOCKSTUN, KNOCKDOWN, GETUP, THROWN, FINISHER, TAGGING.
- Single legal-transition table replacing the repeated `action_allowed` conditions.
- Fixed tick loop; hit stop becomes a sim counter, not a time scale.
- Exit criteria: golden replays still pass; two runs of the same inputs hash identically.

### Phase 2: frame data and hit/hurt boxes as data
- Move `MOVES` out of `fighter.gd` into per-fighter `data/fighters/<id>.json` (with a shared
  default): startup, active, recovery, damage, hitstun, blockstun, hitstop, knockback, height
  (high/mid/low), launch, cancel windows, meter gain, box rects per active frame.
- Hit/hurt boxes are data rectangles (not Area3D/AnimationPlayer): deterministic and testable.
  Hurtbox changes by state (stand/crouch/air/knockdown).
- Sprite Lab draws the boxes for tuning.

### Phase 3: combat depth
- Attack heights + block types (stand block vs crouch block), throws and throw tech.
- Launchers and air juggle with damage scaling and a juggle-point limit (no infinite combos).
- Cancel rules (normal -> special) from data; combo counter/damage scaling; combo breaker kept.
- Counter hit, guard break / pushback, wall bounce optional.
- Per-fighter combos in `data/combos.json` (one engine, per the project rule).
- Training mode: frame data display, record/playback dummy, input display, box overlay.

### Phase 4: game feel (no art dependency)
- Hit stop tiers (light/heavy/counter/finisher), sprite shake on victim, hit flash, spark
  variants per strength, screen shake tiers, block spark, KO slow-down without zoom
  (finisher framing rule stays).
- Audio: layered hit sounds by strength, whiff sound, KO, UI sounds. Needs an audio pass.
- Animation system supports **variable frame counts per clip** and per-move timing while the
  base 12-frame contract keeps working, so new characters drop in later.

### Phase 5: character system (engine only, no new art)
- Archetype stat block per fighter: hp, walk speed, jump, weight, hurtbox size, meter gain,
  plus move-set overrides. Archetypes: rushdown, tank, zoner, counter, acrobat.
- Signature special per fighter defined in data (projectile, command grab, counter stance,
  air dash) using a small set of reusable move behaviours, so new characters are config.
- Fairness matrix test: every archetype pair simulated by CPU vs CPU within win-rate band.
- Character onboarding checklist for the future art: 12 frames, portrait, geometry, data file,
  tests, README.

### Phase 6: 2v2 tag
- Roster pick of 2 per side; active + reserve with partial recovery on bench.
- Tag swap (button, costs meter, invulnerable entry), assist call with cooldown.
- Match rules: round won when both on a side are KO or per shared HP pool (decide in design).
- HUD for two portraits per side; AI controls the partner; training and local first.
- Sim supports N fighters per side from the start of Phase 1 to avoid a rewrite.

### Phase 7: online
- 7a: transport and lobby. Pick a relay (WebRTC/ENet via Godot high-level API or Nakama/
  Colyseus). Matchmaking queue, private room codes, regions, reconnect.
- 7b: delay-based sync with input exchange and hash checks (shippable).
- 7c: rollback with snapshot ring buffer, input prediction, resim; target 7-8 frames max.
- 7d: ping display, sync-loss handling, rematch, ranked ladder (server side), anti-cheat basics
  (server only relays inputs; clients verify state hashes).
- 7e: online 2v2.
- Web build constraints: WebRTC/WebSocket only (no raw UDP). Mobile app can use ENet/UDP.

### Phase 8: retention and meta
- Persistent progression in `user://` (later cloud account): XP, coins, unlocks, rank.
- Daily/weekly challenges, Survival/Arcade endless mode, per-character mastery, titles/banners.
- Unlockable palettes/accessories: engine supports recolor/overlay now; art arrives later.
- Result-screen share image, replays (free once sim is deterministic: store inputs only).
- Analytics events (keeps GoatCounter on web; app needs its own, with consent).

### Phase 9: mobile app
- Android export, touch layout safe areas and notch handling, haptics on hit, 60 fps budget,
  texture compression and APK size limit, pause/resume handling, offline mode.
- Store requirements: age rating, privacy policy, data safety form, in-app purchase policy.
- **Legal risk to resolve before store submission:** satire of real, named politicians in a
  commercial app. Store reviewers and defamation/personality-rights law differ per region.
  Existing web disclaimer is not enough for stores. Needs legal review before monetisation.
- iOS: needs Apple developer account and Mac build.

## Suggested order and why

0 -> 1 -> 2 -> 3 -> 4 (single-player already feels pro; everything shippable on web)
-> 5 (distinct styles; wait for art for the rest) -> 6 (2v2 local) -> 7 (online)
-> 8 -> 9. Phases 1-2 are the load-bearing ones: skip them and online/2v2 become rewrites.

## Risks

- Rollback is the highest-risk item; do not start before Phase 1 hashes are stable.
- Frame-rate independence: web/mobile devices vary; fixed tick with render interpolation.
- Balance debt grows with roster size; fairness matrix must gate every new fighter.
- Scope: this is a multi-month effort. Each phase must end with a playable, tested build.

## Open questions for the owner

1. Tag-team 2v2 (default) or simultaneous 2v2?
2. Server budget: self-hosted relay or a managed service (Nakama, Photon-like)?
3. Monetisation (ads, cosmetics, none)? It affects the legal review and store category.
4. Android first, confirmed? iOS timing?

## Personal fighter (final vision, design constraints for the engine)

Player takes a selfie, picks look preferences and strengths; the system builds a fighter used
online and offline. Engine implications, decided now so we do not rebuild later:

- **Cosmetics and power are separate.** The selfie/look only changes visuals. Power comes from a
  fixed **point-buy stat budget** (every custom fighter has the same total), plus an archetype
  template for the move set. This keeps online matches fair; the fairness matrix test runs over
  budget extremes, not just 13 hand-made characters.
- **A fighter is pure data** (stats + archetype id + art bundle id). The 12-frame sprite contract
  stays the interface for generated art. Art bundles download on demand and are cached offline.
- **Offline play** needs the fighter bundle stored locally and a local-only profile; online
  sync of the profile happens later.
- **Generation pipeline (server side, outside this repo):** selfie -> likeness-safe stylised
  character -> 12 frames + portrait -> automatic quality checks (height, grounding, no cropping)
  -> player preview and approval.
- **Safety and legal (blocking for launch):** selfie is biometric/personal data (GDPR, Israeli
  privacy law, BIPA-style laws); minors; verifying the face belongs to the uploader (liveness
  check) so people cannot generate fighters of others or of politicians; content moderation of
  generated art; deletion on request. This also lowers the defamation risk of the current
  real-politician roster; the app could ship personal fighters only and keep politicians as a
  separate web/satire pack.

## Stack recommendation

- **Client: stay on Godot 4.** It exports Android, iOS and Web from one project, and keeps all
  existing work (sprite pipeline, HUD, tests). Kotlin Multiplatform is not a game engine and
  gives nothing for a sprite fighting game; Unity would mean a full rewrite for no gain here.
  KMP is only worth considering later for a non-game companion app, not for this.
- **Simulation core:** spike to decide GDScript vs GDExtension (Rust/C++). Rollback resimulates
  several frames per tick; on mobile with up to 4 fighters GDScript may be too slow. A native
  core could also run on the server to validate results. Decide with a benchmark in Phase 1.
- **Backend:** Nakama (open source, Godot client, accounts, matchmaking, leaderboards,
  storage) self-hosted or managed; separate service for the avatar pipeline and asset storage.
- **Netcode:** UDP-like transport on mobile, WebRTC on web; relay server for NAT issues.
