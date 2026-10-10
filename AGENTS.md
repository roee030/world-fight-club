# Agent onboarding (project: fight-app)

> **This is a NEW project, forked on 2026-10-10 from the satirical game in `D:\election world fight`. It is a separate git repo and is never pushed to that repo or its `main`. Do not push anywhere without the owner asking.**
> Vision: a pro 2.5D mobile fighting game (Brawlhalla / Street Fighter / Tekken feel): deep combos, distinct fighters, addictive progression, online (rollback) + offline, optional 2v2, and a **personal fighter built from each player's own selfie** (see `docs/character-art/`). Characters/art are produced outside the engine with AI image tools; the engine must stay data-driven.

Read, in this order: `docs/superpowers/plans/2026-10-11-pro-3d-fighter-master-plan.md` (ACTIVE master plan: research, design target, milestones M0-M10), `docs/superpowers/specs/2026-10-11-3d-fighter-architecture.md` (ACTIVE architecture: deterministic sim, move schema, meters, controls, verification), the progress log in `docs/superpowers/plans/2026-10-10-pro-fighting-engine-online-2v2-app.md` (handoff log; append to it), `docs/character-art/` (AI image prompts, personal-fighter flow, consent), then the rules below. Older plans/specs under `docs/superpowers/` describe the legacy satirical sprite game; reference only.

**2026-10-11 pivot (owner decision):** realistic rigged 3D characters on one humanoid skeleton with a shared animation library, a new deterministic fixed-point sim (`sim/`), Easy + Pro controls, rollback later. The 2D sprite pipeline, `fighter.gd` combat, `data/combos.json` and finishers are LEGACY: keep them working until the new battle scene becomes default (end of M4), but build new work in the new layers. Inherited rules below that mention the sprite pipeline, 12-frame contract, the single combo engine in `fighter.gd` or JAB/CROSS/KICK/SP/GUARD apply only to the legacy game.

**Personal likeness rule:** selfies and any art of real users live only in `private/` (git-ignored). Local test fighters are registered in `private/fighters.json` and built with `python tools/build_private_fighter.py <id>` (see `scripts/private_roster.gd`). Never commit or upload them. The owner's own test fighter is `roee`.

Local tooling: there is no portable Godot in this folder. Use the one in the sibling repo: `"D:/election world fight/tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/<name>.gd` (wrap in `timeout 90`). A copy of `.godot/` was brought over; if imports look stale run the same exe with `--headless --path . --import`.

Known pre-existing failures (identical on the untouched fork, NOT caused by the new engine work): `test_avigdor_finisher`, `test_bibi_finisher`, `test_finisher_director`, `test_finisher_lab`, `test_gantz_finisher`, `test_lapid_finisher`, `test_mansour_finisher`, `test_remaining_finishers` hang until timeout with "Assertion failed". Everything else in `tests/` passes. Investigate these separately; do not mask them.

The sections below are the inherited rules from the original game. Rules about the satirical roster, finishers, Web disclaimer and campaign apply only while those features still exist in this fork.

## Product goal

Build a polished satirical 2.5D fighting game in Godot 4. The quality target is a readable console fighting game: strong character identity, immediate hit feedback, clear UI hierarchy and no floating or cropped fighters.

## Non-negotiable implementation rules

- (Legacy game) Use the existing sprite fighter pipeline. In all work: never use a photo billboard or a generic body with a pasted face; identity comes from a complete per-character model.
- Keep the 1280×720 reference layout usable with Godot canvas scaling.
- All fighters use the same 12-frame source contract and `FighterVisual` geometry system.
- Character height, pixel scale and floor correction are separate values. Adjust the correct value instead of compensating with arbitrary transforms.
- Shadows remain on the world floor during jumps.
- An attack counts only during its active window, within reach and in the correct facing direction.
- The gold HUD bar is Special Energy. UI text must identify it.
- A match finisher deals 30% of the rival's max HP; it ends a round only when that empties the bar and celebrates only when it wins the match. Phone controls are `JAB`, `CROSS`, `KICK` (no energy), `SP` (100%) and `GUARD`; every touch action dispatches once, on press. Finisher camera presets keep the fight framing (no zoom); the finisher opens with `scripts/ui/super_move_card.gd`.
- The window uses the `expand` stretch aspect: never assume the viewport is exactly 1280×720. Anchor HUD/touch elements to edges and centre 1280-wide screens.
- Keep `tests/test_combat_fairness.gd` green when tuning AI or damage. CPU behaviour lives in `scripts/cpu_brain.gd`; Special Energy carries over between rounds of one match.
- The UI must stay left-to-right on RTL locales (Hebrew users); never remove the forced LTR layout direction.
- The one-time first-fight tutorial lives in `scripts/ui/tutorial.gd` (`user://tutorial.cfg`). It never auto-starts in headless runs; `tests/test_tutorial.gd` drives it explicitly. Steps that happen during a finisher must use signals, because the host skips per-frame updates while a finisher plays.
- Combos: one engine in `fighter.gd` (`combo_data()`, `_try_hit`, `try_combo_breaker`) driven by `data/combos.json`; the CPU (`cpu_brain.gd`), HUD, MOVE LIST and tutorial consume it. Never add a parallel combo tracker. Never mutate arrays from `combo_data()` (copy them). Keep `tests/test_combo_strings.gd` green.
- Punch clips (`jab`, `cross`, `hook`) must never contain the kick frame (frame 6 of the 12-frame contract).
- Menus share the console style helpers in `main.gd` (`_screen_title`, `_split_background`, `_bottom_bar`, `_primary_button`, `_secondary_button`) and `scripts/ui/ornament.gd`. The bundled font lacks symbols such as ← ✓ ⛶; use plain text.
- Player selection chooses only the player fighter. Quick Fight chooses a different CPU rival randomly. Campaign: every other fighter, Bibi always last (`campaign_ladder_for`).
- The Web shell shows the legal disclaimer (`wf-disclaimer-v1`) before play; all finisher assets ship in the main Web package, so SP never waits for a second download. Owner settings (LinkedIn URL, GoatCounter code) live in `data/site_config.json`. Developer QA URLs: `?qa=finisher|win|loss|campaign`, `?diag=1`.
- Pause freezes combat, timers, AI, animations and round transitions.
- Do not commit `.godot`, exports, browser traces, temporary renders, portable tools or the raw `Universal Base Characters[Standard]` folder.

## Main files

- `scripts/main.gd`: screens, HUD, stage alignment and match flow.
- `scripts/fighter.gd`: combat rules and AI.
- `scripts/fighter_visual.gd`: art clips, height and grounding.
- `scripts/character_debug.gd`: Sprite Lab.
- `tools/slice_sprite_sheets.py`: connected-component frame extraction.
- `tools/build_portraits.py`: roster portrait derivation.

## Roster IDs

`bennet`, `avigdor`, `bibi`, `yair_golan`, `aryeh_deri`, `yair_lapid`, `mansour_abbas`, `benny_gantz`, `itamar_ben_gvir`, `bezalel_smotrich`, `gadi_eisenkot`, `trump`, `joint_list`.

When adding a fighter, update roster data, geometry, card, portrait, twelve sprite frames, tests and README together.

## Workflow

1. Reproduce a bug in the smallest headless test or Sprite Lab scenario.
2. Add the failing regression test.
3. Change the smallest production surface that fixes the root cause.
4. Run the focused test, then the full Godot and Python suites.
5. Open the relevant screen at 1280×720 and inspect clipping, grounding and readability.
6. Update docs if the asset contract, controls or state machine changed.

Never claim a visual or behavior fix without automated evidence and a screen inspection when visual output is involved.

## Current roadmap

All 13 finishers and celebrations are implemented. Their delivery record is tracked in `docs/superpowers/plans/2026-10-07-finishers-celebrations-implementation.md` and the approved spec. Catalog entries and celebrations are separate objects in `data/finishers.json`; new `implemented=false` entries must never activate. Preserve one `FINISH` button per fighter in Fight Lab and keep the complete-roster visual-budget test green. Run Python tests with `python -m unittest discover -s tests -p 'test_*.py'` (bare unittest discovers no tests).

1. Finish presentation polish across menu, selection, pause, HUD and result screens.
2. Tune hit range and feedback in the Sprite Lab/playground.
3. Move fighter timing, bounds and scale values into editable data files.
4. Polish the completed finisher roster without changing approved hit ownership, cleanup or celebration contracts.
