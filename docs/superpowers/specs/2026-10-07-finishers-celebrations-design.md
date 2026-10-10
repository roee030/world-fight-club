# Finish attacks and celebrations — system design

**Date:** 2026-10-07  
**Status:** Design approved with character direction corrections; implementation has not started.  
**Source material:** The supplied fighting-game tutorial transcript, `docs/finisher-celebration-plan.md`, the current Godot combat implementation, and the user-approved character list in this document.

**Implementation plan:** `docs/superpowers/plans/2026-10-07-finishers-celebrations-implementation.md`

## Purpose

Add a reliable, data-driven Finish Attack and post-match Celebration system to all 13 playable fighters. Each sequence must feel specific to its fighter while using one shared runtime, one validation path and one testing contract. Finishers must extend the real combat state machine rather than play as detached videos or bypass health, collision and round resolution.

This document is the durable source of truth for future agents. Read it together with `README.md`, `AGENTS.md`, `docs/character-pipeline.md` and the implementation plan created from this design.

## Lessons carried forward from the tutorial

The supplied tutorial recommends a staged production loop:

1. Build coherent character and prop assets from stable reference art.
2. Inspect animation frames, grounding and bounds in a Character Gym.
3. Activate attack bounds only during authored active frames.
4. Tune timing and framing in a playground before match integration.
5. Keep gameplay values in data that the game and debug tools load together.
6. Add special presentation such as portrait lightboxes only after the mechanic is correct.

Finishers follow that sequence. Visual spectacle never replaces deterministic hit timing, damage, pause support or validation.

## Player contract

A Finish Attack can be activated when the attacker has 100 Special Energy, can act and the match is in `FIGHTING` with no pause or result overlay. Match point, defender health, grounding and facing are not activation requirements.

Input behavior:

- Below 100 energy, a normal Special tap continues to use the existing special attack.
- At 100 energy, one press of keyboard Special or the phone `FINISH` button starts the Finish Attack and spends the meter once.
- Distance is sampled on activation. Inside `activation_range` the authored hits apply; outside it the opening misses, no damage is applied and ordinary combat resumes.
- The HUD distinguishes an in-range ready state from `TOO FAR — ATTACK WILL MISS`.

Failure behavior:

- Once the cinematic starts, meter is spent immediately.
- If an authored finisher opening misses, the cinematic ends, both fighters unlock and ordinary combat resumes.
- A successful finisher can emit one defeat event and one match transition only.

## Match state machine

The match owns an explicit state instead of combining booleans:

`ROUND_INTRO → FIGHTING → FINISHER_PROMPT → FINISHER_CINEMATIC → KO_HOLD → CELEBRATION → RESULT`

Additional rules:

- `PAUSED` is an overlay that freezes the current state, timelines, tweens, AI, timer, sound cues and particles.
- `FINISHER_PROMPT` does not freeze normal combat; it represents an eligible hold in progress.
- `FINISHER_CINEMATIC` locks ordinary fighter input and AI.
- The round timer freezes from confirmed activation through `RESULT`.
- `KO_HOLD` preserves the authored defeated pose and prevents automatic get-up.
- `CELEBRATION` starts only after the final hit and waits for an authored result marker.
- `RESULT` remains the existing victory or defeat presentation entry point.

## Runtime architecture

### `FinisherCatalog`

Loads and validates `data/finishers.json`. It exposes immutable definitions by fighter ID and rejects missing assets, unknown event types, invalid times, out-of-range hit events and roster gaps during tests.

### `FinisherDirector`

A dedicated node owned by the match scene. It:

- evaluates eligibility;
- tracks hold confirmation;
- enters and exits cinematic states;
- positions the fighters at deterministic stage-safe marks;
- runs timeline events;
- applies authored hit events;
- controls camera presets and portrait lightboxes;
- starts celebration timelines;
- hands control back to the match result flow.

It does not contain fighter-specific `if` branches. It executes the catalog definition.

### `FinisherActor`

A lightweight sprite and prop actor used for guests, projectiles, crowds, vehicles and animals. It supports:

- transparent texture or sprite-frame animation;
- normalized screen/world position;
- scale, facing and depth layer;
- enter, hold and exit motion;
- optional ground contact;
- automatic cleanup when the sequence ends.

### Existing fighter integration

`fighter.gd` keeps ordinary movement and combat. It gains a cinematic lock API and explicit methods for authored damage/reaction. It must not learn the individual story of any finisher.

`main.gd` owns the match state, HUD prompt, pause overlay and result handoff. `character_debug.gd` gains a Finishers tab that uses the same catalog and director.

## Data contract

Each roster entry in `data/finishers.json` has this shape:

```json
{
  "fighter_id": "bennet",
  "finisher_id": "startup_exit",
  "meter_cost": 100,
  "trigger_health_ratio": 0.15,
  "hold_seconds": 0.55,
  "activation_range": 1.75,
  "duration": 3.2,
  "camera_preset": "close_side",
  "events": [
    {"at": 0.0, "type": "portrait_lightbox"},
    {"at": 0.35, "type": "spawn_prop", "asset": "laptop"},
    {"at": 1.15, "type": "launch_prop", "target": "defender"},
    {"at": 1.48, "type": "hit", "damage": 999, "reaction": "finish_fall"},
    {"at": 1.48, "type": "camera_impact", "strength": 0.55},
    {"at": 2.25, "type": "celebration_start"}
  ],
  "celebration_id": "exit_success"
}
```

Allowed event types are deliberately limited:

- `portrait_lightbox`
- `fighter_clip`
- `spawn_actor`
- `spawn_prop`
- `move_actor`
- `launch_prop`
- `caption`
- `sound`
- `camera_preset`
- `camera_impact`
- `screen_flash`
- `hit`
- `defender_reaction`
- `celebration_start`
- `result_marker`
- `cleanup`

Every `hit` event has a unique event ID. The director records consumed IDs so a frame hitch or pause/resume cannot apply the same damage twice.

## Asset contract

Assets live under `assets/finishers/<fighter_id>/`:

- `actors/` — guest characters and crowds;
- `props/` — laptop, clock, oil barrel, flag, money and weapons;
- `effects/` — smoke, impact, muzzle flash and explosion frames;
- `celebration/` — fighter-specific celebration frames;
- `preview.png` — Sprite Lab preview used for review.

All actors and props use transparent PNG/WebP frames with a consistent painted fighting-game style. Photographs are reference material only and never appear pasted into the arena. Sarah and Yair Netanyahu use the supplied image only as facial reference for original caricature assets.

Technical requirements:

- Keep important action inside the 16:9 safe frame.
- Grounded actors include an authored foot baseline.
- Projectiles and aircraft may leave the safe frame only through intentional entrance or exit motion.
- Effects use atlases where possible and are freed at sequence completion.
- A finisher may use at most 12 simultaneously visible supporting actors on mobile.
- Web builds target a stable 60 FPS on a modern phone; effects have a reduced mobile density setting.
- No full-screen pre-rendered video is used. The system composes sprites, props, camera and effects at runtime.

## Camera and presentation

Shared camera presets:

- `close_side` — attacker and defender, waist-up impact framing.
- `wide_stage` — crowds, cattle, crocodiles and aircraft.
- `projectile_track` — follows a thrown or fired prop.
- `overhead_pass` — B-2 flyover.
- `victory_low` — grounded hero celebration.

Every sequence begins with one portrait lightbox. Camera shake is limited to authored impact events and capped for mobile. Captions such as `48 HOURS`, `DEMOCRACY` and `EXIT SUCCESS` are part of the data and use the game's UI typography.

## Approved fighter sequences

The exact runtime IDs are fixed and must be used in the catalog:

| Fighter | `fighter_id` | `finisher_id` |
|---|---|---|
| Bennet | `bennet` | `startup_exit` |
| Bibi | `bibi` | `family_business` |
| Yair Lapid | `yair_lapid` | `prime_time_rush` |
| Benny Gantz | `benny_gantz` | `independence_flag` |
| Avigdor Lieberman | `avigdor` | `oil_barrel_48` |
| Mansour Abbas | `mansour_abbas` | `coalition_cashstorm` |
| Gadi Eisenkot | `gadi_eisenkot` | `bazooka_command` |
| Yair Golan | `yair_golan` | `m16_burst` |
| Itamar Ben-Gvir | `itamar_ben_gvir` | `crocodile_release` |
| Bezalel Smotrich | `bezalel_smotrich` | `cattle_charge` |
| Aryeh Deri | `aryeh_deri` | `campaign_entourage` |
| Joint List | `joint_list` | `two_headed_chaos_squad` |
| Donald Trump | `trump` | `b2_flyover` |

### 1. Bibi — `family_business`

**Target duration:** 4.2 seconds.  
The arena darkens and Bibi poses at center-left. Sarah Netanyahu enters on a raised side spotlight and sings, producing two visible sound-wave impacts that stagger the defender without resolving the match. Yair Netanyahu enters as a theatrical comic-book villain and delivers the single final strike. The three characters remain inside the safe frame; guest art is a coherent caricature based on the supplied reference image.

**Celebration:** Bibi sits on a stylized royal throne. Sarah and Yair take positions on either side for a short family victory tableau. Result marker at approximately 2.0 seconds after the final hit.

### 2. Bennet — `startup_exit`

**Target duration:** 3.2 seconds.  
Bennet opens a glowing laptop showing scrolling code, closes it, spins and throws it like a disc. The laptop tracks the defender, displays an impact error flash and explodes into pixels. One final hit event resolves the match.

**Celebration:** Bennet catches a second laptop, opens it and the screen displays `EXIT SUCCESS`; pixel confetti rises behind him.

### 3. Gadi Eisenkot — `bazooka_command`

**Target duration:** 3.7 seconds.  
Eisenkot braces a stylized bazooka, aims, fires and absorbs the recoil. The projectile uses `projectile_track`; the explosion applies one final hit and leaves a short smoke column.

**Celebration:** Eisenkot lowers the bazooka, straightens his uniform and gives a grounded military salute.

### 4. Avigdor Lieberman — `oil_barrel_48`

**Target duration:** 3.5 seconds.  
Lieberman rolls and then throws a marked oil barrel toward the defender. A large clock appears above it at `48:00`, accelerates toward `00:00`, and the barrel explodes at zero. The timer is part of the finisher build-up; the oil barrel explosion is the final hit.

**Celebration:** Lieberman stands with folded arms while a large clock behind him remains fixed on `48:00`.

### 5. Itamar Ben-Gvir — `crocodile_release`

**Target duration:** 4.0 seconds.  
Ben-Gvir gestures forward and opens a stylized enclosure. Three cartoon crocodiles attack in a readable left-to-right sequence. The first two are stagger hits; the third is the final impact.

**Celebration:** The crocodiles line up beside him while he poses toward the camera.

### 6. Bezalel Smotrich — `cattle_charge`

**Target duration:** 4.1 seconds.  
Smotrich signals with a ranch-style whistle. A cattle herd crosses the wide-stage camera in two depth layers. Dust frames appear near the floor and the central animal carries the final hit event.

**Celebration:** Smotrich adopts a ranch pose while the herd settles as silhouettes in the background.

### 7. Mansour Abbas — `coalition_cashstorm`

**Target duration:** 3.6 seconds.  
Abbas throws bundles of dollar bills upward. They expand into a money storm with three controlled multi-hit events, followed by one oversized bundle as the final strike.

**Celebration:** A gentle rain of bills continues while Abbas calmly counts one bundle and faces the camera.

### 8. Aryeh Deri — `campaign_entourage`

**Target duration:** 4.0 seconds.  
Deri raises a campaign folder and summons a clearly authored group of caricatured Haredi campaign operatives with signs and binders. They cross the stage as a coordinated political entourage rather than an undifferentiated crowd. Two foreground passes stagger; the last sign impact finishes.

**Celebration:** The arena quiets, Deri puts away the folder, covers his head and prays to God in a respectful grounded pose. The celebration uses no attack effects.

### 9. Joint List — `two_headed_chaos_squad`

**Target duration:** 3.8 seconds.  
The two heads argue, point in opposite directions and accidentally summon a miniature masked comic sabotage squad. The squad is entirely fictional and carries no ethnic or religious markers. Their chaotic crossing produces two stagger hits and one final comic blast.

**Celebration:** The two-headed fighter sits at a small table and both heads happily eat knafeh, briefly competing for the final piece before sharing it.

### 10. Benny Gantz — `independence_flag`

**Target duration:** 3.4 seconds.  
Gantz unfurls a large Israeli Independence Day flag. The cloth arcs through the foreground, wraps the defender visually without hiding the safe frame, and the flagpole delivers the final grounded strike. Blue and white confetti follows the impact.

**Celebration:** Gantz plants the flag, stands tall beside it and salutes as Independence Day confetti falls.

### 11. Donald Trump — `b2_flyover`

**Target duration:** 4.5 seconds.  
Trump points upward. The camera widens and a stylized B-2 passes overhead in silhouette. Target markers converge on the defender, followed by a non-graphic cinematic blast and one final hit event.

**Celebration:** Trump performs a short victory dance while the B-2 makes a distant background pass.

### 12. Yair Lapid — `prime_time_rush`

**Target duration:** 3.2 seconds.  
Lapid enters a boxer stance and performs six rapid authored punches. The first five use low stagger damage with clear combo numbers; time slows before a final uppercut resolves the match.

**Celebration:** Lapid raises both boxing gloves under camera-flash effects and bounces once in a grounded winner stance.

### 13. Yair Golan — `m16_burst`

**Target duration:** 3.5 seconds.  
Golan takes a stable firing stance with a stylized M16. Two controlled muzzle-flash bursts cause stagger reactions; a final stronger impact resolves the match. Effects remain non-graphic and use clear hit timing rather than continuous damage.

**Celebration:** Golan lowers the weapon safely. A Kaplan protest crowd fills the background holding repeated `DEMOCRACY` signs while he raises a hand toward them. The crowd remains behind the fighter and inside the stage-safe region.

## Celebration rules

- Celebrations are separate timelines referenced by `celebration_id`.
- Every celebration begins from a grounded, collision-safe winner position.
- The loser stays in the authored finish pose and cannot recover.
- Background crowds never cover the winner's face, result title or action buttons.
- Celebration duration is 1.8–2.8 seconds before the result marker.
- The result overlay may fade in over the final held pose; it must not interrupt the defining celebration beat.
- A reduced-motion setting replaces repeated motion with a stable final tableau.

## Sprite Lab and review workflow

The Fighter Lab gains a `FINISHER` mode with:

- attacker and defender selector;
- eligible, hit, miss and pause/resume scenarios;
- timeline scrubber and current event ID;
- 0.25×, 0.5× and 1× playback;
- frame stepping;
- ground line and 16:9 safe-frame overlays;
- visibility toggles for collision, hurt, guard and attack bounds;
- mobile effect-density preview;
- validation output from `FinisherCatalog`.

No fighter is integrated into matches before its entire sequence is approved in the Lab.

## Testing contract

### Shared system tests

- Activation requires full meter and an actionable attacker, but not match point or critical defender health.
- A single press at full meter starts exactly one finisher on keyboard and touch.
- An out-of-range activation consumes meter, deals no damage and restores combat without moving the fighters together.
- Meter is spent once at confirmed activation.
- Ordinary input, AI and round timer freeze during the cinematic.
- Pause freezes and resumes at the same timeline time and event ID.
- Hit events fire only once and in time order.
- Missed openings resume combat without resolving the round.
- Successful finishers emit exactly one defeat and one result transition.
- Celebration starts after KO hold and reaches one result marker.
- Cleanup removes all temporary actors, props, sounds and effects.

### Per-fighter tests

- A catalog entry exists for every playable ID.
- Referenced assets exist and load.
- Timeline times are monotonic and within duration.
- The final hit occurs before `celebration_start`.
- The celebration contains one `result_marker`.
- All grounded actors have valid foot baselines.
- The 1280×720 safe-frame capture contains no cropped required actors.
- A landscape-phone capture loads the sequence at reduced density without errors.

## Incremental delivery and Git discipline

Implementation is delivered in small, reviewable pushes.

### Foundation pushes

1. Match state enum, eligibility tests and hold-input behavior.
2. Catalog schema, validator and placeholder assets.
3. Director timeline engine, pause support and cleanup tests.
4. Fighter Lab finisher controls and safe-frame preview.

### Fighter pushes

Each fighter receives its own commit and push. A fighter is complete only when all items are done:

- final transparent assets committed;
- catalog definition validated;
- Finish Attack plays in Fighter Lab;
- Finish Attack triggers through real match input;
- hit timing, KO and result transition tests pass;
- Celebration plays and remains grounded;
- 1280×720 screenshot reviewed;
- landscape-phone screenshot reviewed;
- checklist below updated with commit hash and notes;
- full Godot and Python suites pass;
- commit pushed to `main`.

Recommended implementation order minimizes risk:

1. Bennet — validates thrown-prop path.
2. Bibi — validates guest actors, sound waves and multi-character tableau.
3. Yair Lapid — validates rapid multi-hit timing.
4. Benny Gantz — validates large cloth/flag framing.
5. Avigdor Lieberman — validates timer plus explosive prop.
6. Mansour Abbas — validates particle-like money actors.
7. Gadi Eisenkot — validates projectile and smoke.
8. Yair Golan — validates burst events and background crowd celebration.
9. Itamar Ben-Gvir — validates multiple animal actors.
10. Bezalel Smotrich — validates a larger moving herd.
11. Aryeh Deri — validates foreground entourage and quiet celebration transition.
12. Joint List — validates miniature squad and two-character celebration props.
13. Donald Trump — validates aircraft, wide camera and mobile effect reduction.

## Progress checklist

Update this section in the same commit that completes each item.

### Shared foundation

- [x] Match state and eligibility — 2026-10-07: pure boundary rules and round-flow state tracking; 16 Godot tests passed.
- [x] Hold input and HUD prompt — Task 3: keyboard/touch hold, quick-tap release latch, 0.55 boundary and readable energy/finish prompt; desktop/phone captures inspected.
- [x] Catalog and validation — Task 2: 13 disabled entries and separate celebration objects, strict schema/resource/link validation, copy isolation and asset validator.
- [x] Timeline director — Tasks 4–5 complete: locks, authored hit deduplication, separate celebration and one result handoff.
- [x] Pause and cleanup — director/actor/audio pause and camera restoration; no temporary actors after result/cancel.
- [x] Fighter Lab support — Task 6: selectors, hit/miss/pause, replay scrub, frame step, speed/density settings, floor/safe frame and validation output.
- [x] Camera, lightbox, sound and result handoff — Task 7: perspective/orthographic camera presets, props/atlas regions, authored poses through existing fighter geometry, captions/clocks, bounded effects and capture tool.

### Fighters

- [x] Bennet — `startup_exit`: laptop launch, pixel impact, EXIT SUCCESS pose/confetti and original arcade audio; real MAX hold and both-side desktop/phone review completed.
- [x] Bibi — `family_business`: two Sarah sonic staggers, Yair final assist and family throne celebration; both-side desktop/phone review completed.
- [x] Yair Lapid — `prime_time_rush`: five crosses, final uppercut, combo count, short impact cues and gloves-up celebration; both-side desktop/phone review completed.
- [x] Benny Gantz — `independence_flag`: full flag strike, tall body and planted-flag salute; both-side desktop/phone review completed.
- [x] Avigdor Lieberman — `oil_barrel_48`: mirrored oil-barrel flight, accelerated 48:00 countdown, zero-time blast and fixed 48:00 victory clock; both-side desktop/phone review completed.
- [x] Mansour Abbas — `coalition_cashstorm`: three nonlethal cash showers, oversized-bundle final and counting-cash celebration; both-side desktop/phone review completed.
- [x] Gadi Eisenkot — `bazooka_command`: tracked rocket, single blast and grounded salute; desktop/phone review completed.
- [x] Yair Golan — `m16_burst`: two stagger bursts, one final burst and a background democracy crowd; both-side desktop/phone review completed.
- [x] Itamar Ben-Gvir — `crocodile_release`: three grounded crocodiles, two staggers, one final attack and a fully visible three-crocodile lineup; desktop/phone review completed.
- [x] Bezalel Smotrich — `cattle_charge`: two rear cattle, one central final bull, grounded dust and tinted settled-herd silhouettes; desktop/phone review completed.
- [x] Aryeh Deri — `campaign_entourage`: two campaign-operative staggers, one final sign pass and a quiet grounded prayer; desktop/phone review completed.
- [x] Joint List — `two_headed_chaos_squad`: fictional masked comic squad, two staggers, one final blast and a two-headed knafeh celebration; desktop/phone review completed.
- [x] Donald Trump — `b2_flyover`: visible overhead B-2 pass, one non-graphic final blast and a distant victory flyover; desktop/phone review completed.

## Definition of complete

## Delivery records

| Date | Delivery | Verification | Next step |
|---|---|---|---|
| 2026-10-07 | Implementation plan published; task 1 rules and match-state tracking implemented | Eligibility test observed failing before implementation, then passing; full Godot suite 16/16 | Catalog and roster stubs (task 2); no fighter finisher marked complete yet |
| 2026-10-07 | Task 2 catalog and roster scaffolding | Catalog/roster RED→GREEN; 10 Python tests passed; reviewer regressions reject unfinished celebrations and late portraits | Task 3 input; fighters remain disabled until final art and sequence review |
| 2026-10-07 | Task 2 pushed as `bb6f85e`; Task 3 Special hold input and HUD | Tap/hold and real host routing RED→GREEN; quick touch release regression; desktop/phone HUD review | Task 4 timeline; no delivered fighter sequences yet |
| 2026-10-07 | Task 3 pushed as `c62ba2e`; Task 4 deterministic timeline | RED→GREEN: timestamp order, frame hitches, pause, zero delta, deduplication and deep copies; 22 Godot tests passed with current foundation | Task 5 director and match handoff |
| 2026-10-07 | Task 4 pushed as `391e3aa`; Task 5 match director and fighter APIs | Fighter/director/match RED→GREEN; real match timer freeze, pause, single KO/result, camera restore and cleanup; fixture screen inspected | Task 6 Finisher Lab; fighter assets still pending |
| 2026-10-07 | Task 5 pushed as `7200190`; Task 7 shared presentation | Perspective camera and authored art RED→GREEN; original frames/camera restored; temporary system preview inspected | Task 6 Lab delivery and Bennet art review |
| 2026-10-07 | Task 7 pushed as `e6d154d`; Task 6 Finisher Lab | 25/25 Godot and 10/10 Python; planned/real/miss/scrub/pause tests; 1280×720 Lab inspected | Bennet vertical slice (Task 8) |
| 2026-10-07 | Task 6 pushed as `0516ef0`; Task 8 Bennet vertical slice | 26/26 Godot and 10/10 Python; real MAX hold, laptop timing, pause, single KO/result, miss and cleanup; ten desktop/phone captures reviewed including reversed side | Push delivery, record hash, integrate Bibi guest actors |
| 2026-10-07 | Bennet delivered in `8e3538d` | Verified before push; mirrored actor anchors included | Bibi `family_business` assets prepared; runtime integration and review pending |
| 2026-10-07 | Task 9 Bibi family business | 27/27 Godot and 10/10 Python; both sides at HP 1/10, nonlethal staggers, pause, one KO/result and cleanup; twelve desktop/phone captures inspected | Push delivery and record hash; Lapid rapid combo next |
| 2026-10-07 | Bibi delivered in `c35b8b7` | Reviewed assets, runtime and mobile framing before push | Lapid `prime_time_rush` |
| 2026-10-07 | Task 10 Lapid rapid boxing combo | 28/28 Godot and 10/10 Python; six unique hits, five nonlethal staggers, ordered captions, pause/miss/cleanup and both sides at HP 1/10; twelve final desktop/phone captures inspected | Push delivery and record hash; Gantz flag sequence next |
| 2026-10-07 | Lapid delivered in `1ce769a` | Reviewed rapid impacts and corrected pose scale before push | Gantz `independence_flag` |
| 2026-10-07 | Task 11 Gantz independence flag | 29/29 Godot and 10/10 Python; one KO, windup pause, height 1.96, grounding, miss/cleanup; eight desktop/phone strike/salute captures inspected on both sides | Push delivery and record hash; Lieberman oil barrel next |
| 2026-10-07 | Gantz delivered in `3a524af` | Complete flag, feet and mobile safe frame reviewed before push | Lieberman `oil_barrel_48` |
| 2026-10-08 | Task 12 Lieberman oil barrel plus complete Fight Lab roster | 30/30 Godot and 10/10 Python; clock/pause/miss/one KO, both directions, six reviewed flight/blast/victory captures; 13 visible FINISH buttons inspected at 1280×720 | Push delivery and record hash; Mansour cash storm next |
| 2026-10-08 | Lieberman and Fight Lab roster delivered in `91a1aa5` | Automated and visual evidence recorded before push | Mansour `coalition_cashstorm` |
| 2026-10-08 | Task 13 Mansour cash storm | 31/31 Godot and 10/10 Python; three low-health staggers, pause, both directions, one bundle KO/result and cleanup; six desktop/phone captures inspected | Push delivery and record hash; Eisenkot bazooka next |
| 2026-10-08 | Mansour delivered in `d304298` | Automated and visual evidence recorded before push | Eisenkot `bazooka_command` |
| 2026-10-08 | Task 14 Eisenkot bazooka | 32/32 Godot and 10/10 Python; single final hit, mobile actor limit, result/cleanup; rocket, blast and salute captures inspected | Push delivery and record hash; Yair Golan M16 next |
| 2026-10-08 | Eisenkot delivered in `2a4f501` | Automated and visual evidence recorded before push | Yair Golan `m16_burst` |
| 2026-10-08 | Task 15 Yair Golan M16 burst | 33/33 Godot and 10/10 Python; two staggers, one final burst, right-side sign orientation and result/cleanup; desktop/phone attack and celebration captures inspected | Push delivery and record hash; Ben-Gvir crocodiles next |
| 2026-10-08 | Yair Golan delivered in `b7a4009` | Automated, right-side text-orientation and visual evidence recorded before push | Ben-Gvir `crocodile_release` |
| 2026-10-08 | Task 16 Ben-Gvir crocodile release | 34/34 Godot and 10/10 Python; three grounded actors, two staggers, third final, result/cleanup and Fight Lab route; desktop/phone/right-side captures inspected and lineup occlusion corrected | Push delivery and record hash; Smotrich cattle next |
| 2026-10-08 | Ben-Gvir delivered in `bcbe25a` | Automated and visual evidence recorded before push | Deri `campaign_entourage` while Smotrich art halo is corrected |
| 2026-10-08 | Task 18 Deri campaign entourage | 35/35 Godot and 10/10 Python; two staggers, one final sign, cleanup before a nonviolent prayer celebration and Fight Lab route; corrected 33-pixel atlas crop reviewed on desktop/phone/right side | Push delivery and record hash; Smotrich art correction and remaining fighters next |
| 2026-10-08 | Deri delivered in `fec02b0` | Automated and visual evidence recorded before push | Repair Smotrich cattle art, then Joint List and Trump |
| 2026-10-08 | Task 17 Smotrich cattle charge | 36/36 Godot and 10/10 Python; central-bull-only final, background depth, grounded dust, actor cap, sprite tint and Fight Lab route; desktop/phone/right-side attack plus silhouette celebration inspected | Push delivery and record hash; Joint List and Trump next |
| 2026-10-08 | Smotrich delivered in `7c6291d` | Automated and visual evidence recorded before push | Joint List `two_headed_chaos_squad` and Trump `b2_flyover` |
| 2026-10-08 | Task 19 Joint List chaos squad | 37/37 Godot and 10/10 Python; two stagger crossings, one final non-graphic comic blast, cleanup before celebration and Fight Lab route; desktop/phone/right-side finale plus two-headed knafeh tableau inspected | Push delivery and record hash; Trump last |
| 2026-10-08 | Joint List delivered in `ea4102a` | Automated and visual evidence recorded before push | Trump `b2_flyover`, then final roster audit |
| 2026-10-08 | Task 20 Trump B-2 flyover | 38/38 Godot and 10/10 Python; one final blast, B-2 in finisher and celebration, cleanup and Fight Lab route; desktop/phone/right-side captures inspected and attack aircraft moved below the HUD safe area | Push delivery and record hash; complete-roster audit and Pages verification |
| 2026-10-08 | Trump delivered in `69441ca` | Automated and visual evidence recorded before push | Complete-roster audit and Pages verification |
| 2026-10-08 | Task 21 complete roster audit | 39/39 Godot and 10/10 Python; all 13 implemented, 13 Fight Lab buttons, mobile actor cap, result-marker contract and asset validation; 52/52 desktop/landscape-phone release captures reviewed in four contact sheets with no empty files, clipping or floating actors | Push release documentation and verify GitHub Pages deployment |
| 2026-10-08 | Complete roster released in `531c662` | Pages workflow `37744619202` succeeded; `/`, WASM, PCK, manifest and service worker returned HTTP 200; public 844×390 check loaded the main menu and all 13 Fight Lab buttons, then ran Bennet through `EXIT SUCCESS` with no browser errors | Finisher and celebration roster complete |
| 2026-10-08 | Live-versus Fight Lab and phone input repair, released in `321fc4b` | 40/40 Godot and 10/10 Python; 1280×720 live Lab inspected with grounded fighters, controls and bounds visible; Pages workflows `37751248944` and `37751848780` succeeded; public 390×844 portrait gate and 844×390 fight with joystick plus all five actions inspected | Complete |
| 2026-10-08 | One-press full-meter activation and round-facing reset | At 100% energy keyboard/touch starts the finisher immediately; range owns hit versus miss; every round resets player right/CPU left | Verification and deployment |

Mansour art uses a strict transparent 2×2 atlas: throw pose, single bundle, bill storm and counting pose. Mobile density remains below the shared 12-actor ceiling; the bill storm is one lightweight visual actor per wave rather than individual nodes for every note.

Fight Lab ruling: all 13 fighters remain visible in a compact two-row roster. Every `FINISH` button routes through the production catalog and director; an unfinished fighter reports `PLANNED` until its validated assets and timeline are delivered. This avoids a parallel preview implementation.

Lapid scale ruling: head-to-foot body height excludes raised gloves (uppercut 600 px, victory 606 px). All glove pixels remain visible in the atlas. Brief blue impact cues are reused from the existing pixel effect for the five crosses; final uppercut uses its camera impact and caption without a lingering floating effect. Celebration flashes are suppressed in reduced motion.

Bibi art uses two transparent painted atlases generated from the family reference and existing Bibi sprite. The photo is not included in game assets. Sarah's sonic attacks use visible musical waves and original electronic cues; recorded vocals are not part of this delivery. The family throne tableau is an authored cinematic pose grounded through the existing fighter geometry.

Lab guide note: cyan shows the actual collision capsule. Hurt/guard guides are explicitly labeled proxies because ordinary combat uses facing, distance and guard booleans rather than separate shape nodes.

Execution order ruling: Task 7 presentation support is delivered before Task 6 because the Lab needs the same opening-miss switch and atlas rendering used by real sequences. No duplicate preview renderer is introduced.

Atlas contract: actor and fighter-pose events may include `region: [x,y,width,height]`. Fighter poses declare `figure_height_px` and `foot_baseline`; the existing `FighterVisual` height, pixel scale and floor correction calculate their placement. Source PNGs remain intact.

Anchored actor contract: `anchor: attacker|defender` positions are relative to that fighter; their X offsets and art facing mirror with the attacker. Motion events support the same anchor contract. This prevents props moving away from the opponent when the attacker stands on the right. Capture tool accepts `--side=right`.

Bennet art: `props/laptop-kit.png` contains closed/open laptop, pixel impact and confetti regions; `celebration/pose-kit.png` contains throwing and laptop victory poses. Atlas regions replace separate numbered effect files; the twelve ordinary fighter frames remain unchanged. Shared audio is original procedural PCM generated by `tools/build_finisher_audio.py`.

Pause input clarification: confirmation time freezes while paused. Releasing Special while paused cancels that pending confirmation on resume without firing Special; holding throughout preserves elapsed confirmation time.

Execution ruling: this managed worktree has a detached HEAD. Preserve it and publish using `git push origin HEAD:main` after integrating remote updates normally. No forced pushes.

The feature is complete when all 13 finishers and celebrations satisfy the data contract, pass shared and per-fighter tests, have reviewed desktop and phone captures, preserve ordinary Special behavior, pause correctly, resolve the match once and are deployed successfully through GitHub Pages.


## Amendment 2026-10-08: finisher damage share and best-of-three flow

Requested directly by the product owner after phone play-testing ("a finisher should be a strong blow, not kill the rival, and must not end the match while rounds remain").

- In a match, `main.gd` passes `damage_budget = 0.30 × rival max HP` and `celebrate_on_lethal = (player_rounds + 1 >= 2)` to `FinisherDirector.begin(...)`.
- Non-final authored hits keep their small authored damage (never lethal). The final hit deals the rest of the budget instead of `max(damage, health)`.
- If the rival survives, the director cleans up at `celebration_start` and emits `sequence_finished(false)`; the rival takes a grounded knockdown with a normal get-up and the round continues. No round is awarded.
- If the blow empties the bar before match point, the director emits `sequence_finished(true)`; the round is awarded once and the next round starts after the normal KO hold.
- Only a match-winning lethal finisher continues into the authored celebration and result card.
- Fight Lab previews pass no damage budget and keep the original always-lethal preview behaviour, so hit ownership, cleanup and celebration contracts are unchanged there.
- Phone button renamed `FINISH` → `SP` (round gold button with an electric aura at 100%); the 55% special move is the separate `MAX` button.
- Regression: `tests/test_finisher_match_integration.gd` covers miss, 30% survive, round-one lethal (next round), match-point lethal (celebration → result) and same-rival rematch.
