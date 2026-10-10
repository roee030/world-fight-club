# Finisher Delivery, Combat Focus, and Tutorial Focus Design

**Status:** approved chat design, ready for implementation planning (2026-10-10)

## Goal

Make SP finishers immediately dependable in the Web build, keep the fight
space visually quiet except for useful combo-and-damage feedback, and make the
one-time first-fight tutorial unambiguous at both its start and completion.

## Context and confirmed diagnosis

The Web export currently excludes `assets/finishers/*` from `index.pck` and
downloads a separate `finishers.pck` at runtime via `scripts/web_pack_loader.gd`.
While that pack is unavailable, `main.gd` deliberately rejects SP activation
with `FINISHER STILL LOADING`.

The live build was checked on 2026-10-09: `finishers.pck` returned HTTP 200
with `Content-Encoding: gzip`, and the Godot console logged `loaded=true`.
The recent `accept_gzip = false` change repairs that particular gzip path, but
the two-pack architecture still makes a core combat action depend on a second
download. The product owner prefers one complete game package over that
startup-size optimization.

## Decision: ship finishers with the game

`index.pck` will contain all finisher assets. The separate Web preset, pack
download, runtime pack mount, readiness gate, retry behavior, and
`FINISHER STILL LOADING` feedback will be removed.

SP eligibility remains governed by existing combat rules only: 100% Special
Energy, an implemented finisher, active/actionable grounded fighters, valid
facing, and normal match state. Range remains owned by the authored opening
hit/miss sequence; it is not an input availability gate.

This deliberately increases first-load download size by roughly the former
finisher pack size. It prevents a first SP press from being unavailable because
of network timing and keeps native and Web behavior aligned.

## Decision: one compact combat-feedback lane

During live combat, the playfield must show only the player's current combo
and accrued damage feedback. The component presents one short line:

`<HITS> HITS  ·  <DAMAGE> DMG`

It occupies a centred, HUD-safe lane above the fighters (higher than its
current 232 px design-Y origin), uses the existing console callout treatment,
and expires with the current combo timer. A named combo uses the same lane and
still shows its total damage, rather than introducing another floating label.

The following centre-playfield instructional/status strings are removed:

- `GOOD!` and `GREAT!` combo suffixes;
- `SPECIAL ATTACK!`;
- SP availability and distance prompts (`SP READY`, `GET CLOSER`, `WAIT`,
  `NEEDS`, and `NOT AVAILABLE`);
- `COMBO BREAK!` and `CPU BREAKS FREE!`.

Round, fight, KO, and result announcements remain, because they communicate
round state rather than moment-to-moment instructions. The HUD's lit SP button
and the pause MOVE LIST remain the discoverable sources for SP guidance.

## Decision: tutorial spotlight states

The existing tutorial gets a purpose-built overlay layer that darkens the
whole fight except for a pulsing, gold-highlighted control target. It uses the
current `target_rect()` mapping, so the joystick, action buttons, and Special
Energy bar are all highlighted by the same source of truth.

Tutorial flow gains two explicit gates:

1. **Introduction:** `LEARN THE BASICS` explains that this is a short practice
   round, with `START TUTORIAL` and `SKIP` choices. The player never has to
   infer why the opponent is passive.
2. **Completion:** after the real SP sequence ends, `TRAINING COMPLETE` tells
   the player that the opponent is about to fight normally. `START FIGHT`
   begins a fresh competitive round; only then are the CPU, clock, scores, and
   meters restored.

Between those gates, the compact coach panel stays outside the fighter space
and the spotlight is the dominant instruction. The overlay itself must not
block the highlighted gameplay control; only its own buttons consume clicks.
The finisher step continues to advance from director signals, not per-frame
polling, because match-frame updates pause during a finisher.

## Difficulty answer and scope

No difficulty-system change is required in this batch. The game already has
EASY, NORMAL, HARD, and EXPERT settings persisted in user settings. They alter
CPU level, reaction timing, guard skill, whiff punishment, and combo-breaker
rate; campaign level ramps by ladder progress. Existing difficulty tests will
remain part of the regression suite.

## Files and boundaries

| Surface | Responsibility |
|---|---|
| `export_presets.cfg` | Put finishers back in the core Web export; remove the pack preset. |
| `.github/workflows/deploy-pages.yml` | Export only the single Web game package. |
| `scripts/main.gd` | Remove pack readiness from SP flow; consolidate combat feedback; place the combo lane; coordinate tutorial intro/completion handoff. |
| `scripts/web_pack_loader.gd` | Remove after all consumers are removed. |
| `scripts/ui/tutorial.gd` | Own spotlight rendering and explicit intro/completion tutorial states. |
| `tests/test_web_cache_policy.py` | Assert the single-package Web contract. |
| Godot finisher, mobile-control, tutorial, and presentation tests | Pin immediate SP availability, quiet combat feedback, combo position, and tutorial gates. |
| `README.md` and `AGENTS.md` | Describe the one-package delivery and final tutorial/control behavior. |

## Acceptance criteria

1. A fresh Web load has no runtime finisher-pack request, and all finisher
   resources are present in `index.pck`.
2. At 100% Special Energy, one keyboard or touch SP input starts its authored
   finisher immediately under otherwise-valid combat conditions.
3. Combat feedback contains one player combo/damage lane only; it is above the
   fighters and does not contain instructional prompts or quality adjectives.
4. The first tutorial starts with a dimmed spotlight introduction and finishes
   with an explicit completion gate before a live CPU round begins.
5. Tutorial SP completion remains signal-driven, and skip/out-of-range/replay
   behavior remains safe.
6. Focused Godot/Python tests, full suites, and 1280x720 plus landscape-phone
   visual inspection pass.

## Out of scope

- Rebalancing moves or CPU difficulty values.
- Changing finisher damage, range, authored sequences, celebrations, or their
  30% match-damage contract.
- New fighter art, fonts, or language localisation.
