# Combo System Plan (proposal — awaiting owner decisions)

> Status: **implemented 2026-10-09** (see Delivery record). Read `AGENTS.md` first. The owner's decisions are recorded in section 6; they override the recommendations above where they differ (combo into SP is **out of scope**).

## 1. What exists today (`scripts/fighter.gd`)

| Piece | Current behaviour |
|---|---|
| Chains | A connected hit opens a **cancel window** (`cancel_from`..`cancel_to` in `MOVES`). An input buffered in that window (`INPUT_BUFFER_SECONDS = 0.34`) starts the next attack. |
| Routes | `light → light / heavy / special`, `heavy → heavy / special`. **KICK cannot chain** (neither into nor out of). |
| Length | `MAX_COMBO_HITS = 3`. |
| True combo | Yes. Light hitstun (0.34 s + hit-stop) outlasts the next jab's startup inside the window, so a connected chain cannot be escaped. |
| Block | A blocked hit ends the combo (`_clear_combo()`). |
| UI | `combo_label` shows `N HIT COMBO` at 2+ hits (player only). |
| Missing | Named sequences, a kick in combos, **damage scaling**, a combo breaker, a move list, combo feedback in the new console style, CPU combo variety, analytics. |

## 2. How fighting games do it (and what fits a phone satire fighter)

| Model | Examples | Feel | Fit for us |
|---|---|---|---|
| **Target / string combos ("dial-a-combo")**: fixed button sequences with a named finale | Tekken strings, Mortal Kombat kombos, Injustice | Easy to learn, readable, rewarding | **Best fit.** Works with 3 buttons on touch; names add satire. |
| **Chain combos**: light→medium→heavy, any order upward | Darkstalkers, Marvel vs Capcom, Skullgirls | Fast and forgiving | Good as the *universal* backbone (we mostly have this). |
| **Links**: frame-perfect timing between moves | Street Fighter | Hard, competitive | Wrong for touch. |
| **Cancels into specials/supers** | SF, Guilty Gear | Spectacular | Yes: "combo into SP" as the big payoff. |
| **Juggles / launchers** | Tekken, Smash | Needs air states and many frames | Not with the 12-frame sprite contract; maybe later. |
| **Tap combos / auto-combos** | Marvel Contest of Champions, MK Mobile | Very mobile-friendly | Fold into the strings (generous buffer). |

Every good system shares five rules, and we adopt all of them:
1. **Generous input buffer** on touch (keep 0.3–0.35 s).
2. **Damage scaling** per hit, so long combos are not instant kills. This answers the "I die in a few hits" feedback.
3. **A limit plus an escape**: a short maximum length and a *combo breaker* for the defender.
4. **Clear feedback**: hit counter, hit-stop, distinct final-hit effect, combo name and total damage.
5. **Learnable**: a move list in the pause menu and one tutorial step.

## 3. Recommended design

### 3.1 Universal strings (every fighter, in `data/combos.json`)

| Name | Input (touch / keyboard) | Hits | Finale effect |
|---|---|---|---|
| ONE-TWO | JAB, JAB | 2 | — |
| QUICK CROSS | JAB, JAB, CROSS | 3 | Strong knockback |
| POWER LINE | JAB, CROSS, KICK | 3 | Knockdown (short) |
| HEAVY HANDS | CROSS, CROSS | 2 | Guard crush (+ blockstun) |
| SWEEP STRING | JAB, KICK | 2 | Knockback + pushes to range |

### 3.2 Signature string (one per fighter, satirical name)
A 4-hit string ending in a unique finale (VFX + stagger + bonus energy). It reuses existing clips plus effects (no new sprite frames needed), for example:
- Bibi — **"PROTECTION DETAIL"** (J, J, C, K)
- Bennet — **"PIVOT ROUND"** (J, C, J, K)
- Lapid — **"PRIME-TIME COMBO"** (J, J, J, C)

…all 13 names live in data, so the owner can rename them.

### 3.3 Combo into SP
If Special Energy is 100%, pressing **SP during the cancel window of a combo's final hit** launches the finisher with a **+10% damage bonus** (40% instead of 30%) and the caption "COMBO FINISH!". This is the big payoff, and it ties combos to the existing finisher system.

### 3.4 Damage scaling
Per hit in a combo: 100% → 85% → 70% → 60% → 55% (floor). The finale ignores half of the scaling, so it still feels strong. Tune with `test_combat_fairness.gd`.

### 3.5 Combo breaker (defender escape)
While being hit (hitstun), the defender presses **GUARD + direction away**, or a dedicated touch gesture: GUARD double-tap. This costs **35% Special Energy**: a push-back burst, a short invulnerability, and "BREAK!" feedback. It is limited to once per combo. The CPU uses it by level (level 1 rarely, the boss often). This directly addresses "the CPU drains my HP".

### 3.6 Feedback and UI
- A counter at the side of the screen in the console style: "3 HITS", then tier words at 3/5/7 (GOOD → GREAT → MASSIVE) with the electric callout animation.
- On completing a named string: the string name + total damage ("POWER LINE · 18 DMG").
- Escalating hit-stop and camera shake on the finale; a distinct spark colour per tier.
- **MOVE LIST** in the pause menu: universal strings + the fighter's signature, drawn with the same button icons as the touch pad.
- The tutorial gains one optional step: "Do your first combo: JAB, JAB, CROSS".

### 3.7 CPU
`cpu_brain.gd` picks strings by weighted choice (level gates the length: L1 2-hit, L2 3-hit, L3–4 signature + combo-into-SP). It confirms on hit only: it stops if the first hit is blocked, and sometimes uses the breaker. Variety keeps it unpredictable (entropy test stays green).

### 3.8 Analytics
`combo/<string-name>`, `combo/max-<n>-hits`, `combo/into-sp`, `combo/break`.

## 4. Engineering plan

| Phase | Work | Tests |
|---|---|---|
| 1 Core | `data/combos.json` (strings, scaling, finale effects); a `ComboTracker` in `fighter.gd` that records the connected sequence and matches it to the strings; add `kick` to the chain routes; damage scaling; `MAX_COMBO_HITS` → 4 (signature). | `test_combo_strings.gd`: every string connects as a true combo from neutral at the closest range; scaling numbers; a block stops a string; KICK chains. |
| 2 Feedback | Combo counter and tier callouts, string name + damage, finale effects, MOVE LIST screen. | UI test (nodes, texts); Playwright screenshots at 780×360. |
| 3 SP and breaker | Combo → SP cancel with bonus; the breaker (energy cost, once per combo, invulnerability). | Integration test: SP cancel only in the final hit's window at 100%; the breaker ends a CPU combo and costs 35%. |
| 4 CPU and balance | Brain string selection by level; breaker usage; update the fairness thresholds (round length ≥ 22 s, win ratio 0.40–0.82). | `test_combat_fairness.gd`, plus a new CPU-combo entropy assertion. |
| 5 Onboarding and analytics | Tutorial combo step; events. | `test_tutorial.gd`, `test_analytics_paths.gd`. |

Estimated size: phases 1–3 are the core, roughly a day of focused agent work with tests; phases 4–5 are smaller.

## 5. Decisions needed from the owner
1. Scope: universal strings only, or universal **+ one signature string per fighter** (recommended)?
2. Combo breaker: yes (recommended: 35% energy, once per combo) or no?
3. Combo into SP with a +10% finisher bonus: yes (recommended) or no?
4. Signature string names: should the agent propose all 13 satirical names for approval, or will the owner supply them?

## 6. Owner decisions (2026-10-09)

| Question | Decision |
|---|---|
| Scope | **Universal strings + one signature string per fighter.** |
| Combo breaker | **Yes**: 35% Special Energy, once per combo (GUARD double-tap during hitstun; keyboard: `S` double-tap). |
| Combo into SP | **No.** SP stays separate. Drop section 3.3 and the `combo/into-sp` event. |
| Signature names | **The agent proposes; the owner approves or edits** (`data/combos.json`). |

### Proposed signature strings (for approval; all reuse existing clips)

| Fighter | Name | Input | Finale |
|---|---|---|---|
| bibi | PROTECTION DETAIL | J, J, C, K | Knockdown + blue shield sparks |
| bennet | PIVOT ROUND | J, C, J, K | Knockback + pixel sparks |
| yair_lapid | PRIME-TIME COMBO | J, J, J, C | Stagger + camera-flash sparks |
| benny_gantz | CENTRE PUSH | C, J, C, K | Long knockback |
| avigdor | ULTIMATUM | C, C, J, K | Guard crush + red clock flash |
| mansour_abbas | KINGMAKER | J, C, C, K | Knockdown + gold coin sparks |
| gadi_eisenkot | CHIEF OF STAFF | J, J, C, C | Heavy stagger + smoke puff |
| yair_golan | LEFT FLANK | J, K, J, C | Knockback + cyan sparks |
| itamar_ben_gvir | NATIONAL SECURITY | C, J, J, K | Knockdown + orange sparks |
| bezalel_smotrich | BUDGET CUTS | J, C, K, K | Knockback + dust |
| aryeh_deri | COMEBACK TOUR | J, J, K, C | Stagger + purple sparks |
| joint_list | SPLIT VOTE | J, C, J, C | Double-hit finale (two sparks) |
| trump | THE DEAL | C, C, C, K | Knockdown + gold sparks |

Next step: implement phases 1–5 (without the SP cancel), starting with `data/combos.json` and `tests/test_combo_strings.gd`.

## 7. Delivery record (2026-10-09)

| Phase | Status | Evidence / notes |
|---|---|---|
| 1 Core | Done | The existing chain/cancel code was extended **in place**; no parallel system. `combo_data()` reads `data/combos.json`. Routes include KICK. A hit continues the combo while the rival is in hitstun or hit-stop (this fixes the counter resetting on a slightly late press). Scaling `[1.0, 0.9, 0.8, 0.7]` (softened from 0.85/0.7/0.6 after balancing). Finale relief 0.5. `MAX_COMBO_HITS = 4`. The obsolete chained-heavy clip swap was removed. `tests/test_combo_strings.gd` plays all 5 universal and 13 signature strings for real. |
| 2 Feedback | Done | `combo_label` gets its own `Callout` (`N HITS · GOOD!/GREAT!`, then `NAME · N DMG`). The duplicate "special" sound on every 3-hit combo was removed and moved to named strings. MOVE LIST panel in pause (`_refresh_move_list`). Playwright `?qa=fight` screenshots reviewed. |
| 3 Breaker | Done | `try_combo_breaker()`: double-tap GUARD in hitstun (`set_controls` rising edges), 35% energy, push-back, 0.45 s invulnerability. `combo_broken` signal → "COMBO BREAK!". Combo → SP: **not built** (owner decision). |
| 4 CPU and balance | Done | `cpu_brain.gd` plans a string after a confirmed first hit (level gate 3/3/4/4 hits; length² weighting; may cap with the special at ≥55% energy) and breaks player combos (0.35/0.9/1.6/2.4 per second). After rebasing onto main (which includes the arena-edge clamp, which made the CPU easier on its own: main alone measured 0.75): CPU damage factor `0.92 + 0.06 × level` and `DAMAGE_SCALE 0.6`. Final: player wins 0.65, round 23.3 s, entropy 1.83 bits, habit guard 0.50 → 0.76. Bug found and fixed: the plan aliased the shared data array, and `clear()` wiped combo sequences. |
| 5 Onboarding and analytics | Done | Tutorial step 7 "COMBO" (8 steps total); events `combo/<name>`, `combo/hits-N`, `combo/break-player|cpu`. |

**Parallel work note:** another session was editing `main.gd`/`fighter.gd` in the shared checkout at the same time. This work was moved to the `feat/combo-system` worktree and merged through git, so neither session committed the other's half-finished changes.
