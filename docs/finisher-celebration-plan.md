# Finishers and celebrations — design plan

> Superseded by the detailed approved system design at
> `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`.
> Keep implementation progress and per-fighter commit notes in that document.

Status: shared foundation implemented after the core combat tests passed. Per-fighter delivery and verification are tracked in the approved design linked above. This older document remains a design reference, not the current task ledger.

## Lessons from the supplied tutorial

The tutorial recommends a staged workflow: generate coherent animation sets, inspect them in a Character Gym, define collision, hurt, attack and guard bounds per frame, tune parameters in a playground, save those parameters as data, then integrate the core loop and presentation. Specials use a full meter, a charging animation, multi-hit timing and a portrait lightbox.

Finishers and celebrations should extend that architecture. They should not be one-off branches embedded in a fighter script.

## Player flow

1. A finisher becomes eligible only on a match-winning round when the rival is at critical health and the attacker has a full Special meter.
2. The HUD briefly changes `SPECIAL READY` to `FINISH READY`.
3. The player deliberately holds Special for a short confirmation window. A normal tap still performs the ordinary special.
4. Both fighters enter a locked cinematic state. Movement, AI and ordinary attacks stop.
5. The attacker plays authored startup, active and recovery clips. Damage is applied only by explicit active-frame hit events.
6. On connection, the camera and impact presentation play, the defeated fighter enters a dedicated finish reaction, and the round resolves once.
7. The winner returns to a grounded celebration pose while the result overlay enters. The loser remains in the authored final pose.
8. If the finisher misses, normal combat resumes and the meter is spent.

## State model

`ROUND_INTRO → FIGHTING → FINISHER_PROMPT → FINISHER_CINEMATIC → KO_HOLD → CELEBRATION → RESULT`

Pause is an overlay state that freezes whichever match state is active.

## Data contract

Each fighter should eventually load a data resource or JSON record:

```json
{
  "finisher_id": "example_finish",
  "meter_cost": 100,
  "trigger_health_ratio": 0.15,
  "range": 1.6,
  "startup_frames": [0, 1, 2],
  "active_frames": [3, 4],
  "recovery_frames": [5, 6],
  "hit_sequence": [8, 8, 20],
  "camera_preset": "close_side",
  "loser_reaction": "finish_fall",
  "celebration": "victory_a"
}
```

Timing, bounds and camera presets are data. Fighter code executes the shared contract.

## Sprite Lab additions

- Frame number and playback speed.
- Pause and single-frame stepping.
- Collision, hurt, guard and attack bounds toggles.
- Finisher eligibility, hit, miss and interrupted previews.
- Camera-safe frame overlay for 16:9.
- Celebration preview with the ground line visible.
- Save validated settings to the same data loaded by a match.

## Presentation rules

- Use the fighter's established art direction and silhouette.
- Keep every body grounded and inside the safe frame.
- Limit camera shake and flashes so impact remains readable.
- Portrait lightbox appears once at activation, not on every hit.
- Result UI waits for the celebration's authored hold marker.
- Every fighter gets a neutral victory celebration before character-specific finishers are expanded.

## Test plan

- Finisher cannot trigger before match point, above the health threshold or below full meter.
- A normal Special tap remains backward compatible.
- Damage happens only on active frames and only once per authored hit event.
- Missed finishers spend meter and resume combat without resolving the round.
- Successful finisher emits one defeat event and one result transition.
- Pause freezes the cinematic and resumes at the same frame.
- Celebration starts only after KO hold and keeps feet and shadow on the floor.
- Every fighter data record references existing clips and valid frame indices.

## Delivery phases

1. Match state machine and regression tests.
2. Data schema plus one placeholder finisher in Sprite Lab.
3. One complete vertical slice using Bennet versus Bibi.
4. Camera, sound, portrait lightbox and result handoff.
5. Shared celebration system for all fighters.
6. Fighter-specific finishers after timing and framing review.
