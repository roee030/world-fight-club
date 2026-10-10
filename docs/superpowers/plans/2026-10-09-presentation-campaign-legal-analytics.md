# Presentation, Campaign, Legal Gate and Analytics Plan (handoff document)

> **For any agent picking this up:** read `AGENTS.md` first. This file is the single source of truth for this batch. Each task has a **Status** line; update it, and the "Delivery record" table at the end, whenever you finish or change something. Workflow per task: failing regression test, smallest production change, full Godot and Python suites, then a phone-sized screen inspection (Playwright with `locale: 'he-IL'`, 780×360 @3×, see "How to verify").

**Requested by the product owner on 2026-10-09** (phone play-test, screenshots in the chat). Goals:

1. Finisher intro card ("lightbox") looks bad: a small boxed portrait plus a raw `MANSOUR_ABBAS` caption. Replace it with a full-screen "super move" card (fighter art, fighter name, finisher name, electric styling). Reference: AI concept with "FINAL JUDGMENT" lightning title.
2. Remove the zoom-in / zoom-out "jump" around the finisher card.
3. All on-screen announcements (ROUND 1, FIGHT!, ROUND LOST, feedback) are plain text. Make them styled banners in the new console style with an electric entrance animation.
4. The `MAX` touch button actually performs a kick (the 55% special uses the kick clip). Rename it and make it usable without an energy requirement.
5. The end-of-match screen (translucent winner card art over a blurred arena plus an old-style text card) must follow the supplied YOU WIN / YOU LOSE concepts, using the real arena and the real fighters, not a generic background.
6. Campaign: after each fight, show a progress ladder. The player must beat every other fighter, and **Bibi is always the last opponent**, even when the player picked Bibi (mirror match).
7. Remove `FIGHTER LAB` from the main menu.
8. Startup legal disclaimer (satire, no affiliation, no incitement, non-commercial, not legal advice). The player must tick a checkbox before playing.
9. A main-menu button that opens the creator's LinkedIn profile.
10. Analytics: who visits, how many, what they do.
11. This handoff document.

## Decisions (made autonomously, owner asleep)

| Topic | Decision | Why |
|---|---|---|
| Finisher card art | Use the existing `assets/characters/<id>-card.png` full-body art with code-drawn effects (speed lines, lightning, glow). Optional per-fighter art override: `assets/finishers/<id>/super-card.png` is used automatically if it exists. | New illustrated "armoured" hero art like the concept cannot be produced in code; see "Missing assets". |
| Finisher name | `display_name` field in `data/finishers.json` if present, else the humanised `finisher_id` (`coalition_cashstorm` → `COALITION CASHSTORM`). | No display names exist yet; the field lets the owner rename them without code. |
| Zoom jump | Finishers keep the fight framing (no FOV/position presets). Camera *shake* on impacts stays. | The stage backplate is attached to the camera, so any zoom also lifts fighters off the painted floor (same root cause as the celebration fix). |
| MAX button | Renamed `KICK`; a normal kick with no energy cost. The 55% special move stays on keyboard `L`/`3` below 100% energy. | Owner: "rename it and let the user press it independently". |
| Disclaimer | Rendered by the Web shell (HTML), not Godot: the bundled Godot font has no Hebrew glyphs, while the browser renders Hebrew and gives a native, accessible checkbox. Acceptance is stored in `localStorage` with a version (`wf-disclaimer-v1`). Bump the version to show it again after wording changes. | Hebrew text plus legal clarity. |
| LinkedIn | A `CONTACT THE CREATOR` menu button opens `linkedin_url` from `data/site_config.json`. **The URL is not filled in** (unknown). While it is empty, the button is hidden. | Never guess a personal URL. |
| Analytics | Privacy-friendly, cookie-free [GoatCounter](https://www.goatcounter.com/) (free for non-commercial use). The shell loads it only when `goatcounter_code` is set in `data/site_config.json`. Godot sends named events through `window.worldFightTrack(name, props)`. Without a code, events go to an in-page ring buffer, visible with `?diag=1`. | Needs an account the owner must create; no cookies, so no cookie banner is required. The disclaimer mentions anonymous statistics. |
| Campaign ladder | Opponent order: all other fighters in a fixed shuffled order (seeded per run), then Bibi. If the player is Bibi, Bibi still closes the ladder as a mirror "BOSS". CPU level ramps from 1 to 4 across the ladder. A loss retries the same opponent; progress is kept for the session. | Owner request. |

## Tasks

### T1 — Finisher super-move card
**Status:** see Delivery record.
- `scripts/ui/super_move_card.gd` (new): a full-screen CanvasLayer overlay with a dark vignette, radial speed lines, fighter art sliding in with a cyan glow, an electric two-line finisher title, the fighter name, and animated lightning arcs. About 1.1 s: in 0.15 s, hold, out 0.25 s. Pausable (follows the director's pause).
- `finisher_director.gd` `portrait_lightbox` event → `SuperMoveCard`. Remove the old 220 px boxed portrait.
- Tests: `test_finisher_match_integration.gd` / finisher lab tests keep passing; a new assertion checks that the card exists during the lightbox and is freed by cleanup.

### T2 — No zoom jump
- `_camera_preset()` keeps the fight transform and FOV for every preset (records only the mode).
- Test: the camera transform and FOV are unchanged through a whole finisher.

### T3 — Styled announcements
- `scripts/ui/callout.gd` (new): owns `message_label`; any text change triggers an animated banner (slanted plate, gold/cyan rim by style, scale punch-in, white flash, short lightning crackle). Styles come from the text: `FIGHT!` / KO = gold large; `ROUND n` = cyan; feedback (`NEEDS`, `NOT AVAILABLE`, `READY`) = small cyan. Finisher captions use the same component.
- Existing tests on `message_label.visible` / `.text` stay valid.

### T4 — KICK button
- `TOUCH_CONTROL_LAYOUT`: `max` → `kick` ("KICK", boot icon). Remove the energy gate and the MAX feedback. Update `test_mobile_control_contract.gd`, `AGENTS.md` and the README.

### T5 — Result screen
- Rebuild `_build_result()` per the concepts. The real arena stays visible (celebration pose, loser on the floor; no translucent card art and no blur). A left framed card: cyan frame for a win, red for a loss, with `FINAL RESULT`, a huge `YOU WIN` / `YOU LOSE`, `<NAME> WINS` / `OPPONENT WINS`, and `You won 2–0`. Bottom bar: gold `REMATCH`, outlined `NEW OPPONENT`, outlined `RETURN TO MENU`. Gold particles/confetti for a win; red cracks/sparks for a loss (code-drawn).
- Update `test_ui_presentation.gd` (`ResultWinnerArt` is removed, or hidden).

### T6 — Campaign ladder
- Data: `_campaign_ladder(player_id) -> Array` (others shuffled, Bibi last). State: `campaign_index`, `campaign_ladder`.
- Screen: `CampaignProgress` (console style). It shows the portraits in order with checkmarks for beaten rivals, the next rival highlighted, "FIGHT n / N" and a `NEXT FIGHT` button. It appears after each campaign win and after a loss ("RETRY"). Ladder complete → a champion screen, then the menu.
- Tests: `test_campaign_ladder.gd` (new). Bibi is last for every player choice; there are no duplicates; the player never fights themselves except Bibi→Bibi; the level ramps; a win advances; a loss retries.

### T7 — Menu
- Menu actions: `START FIGHT`, `CAMPAIGN`, `CONTACT THE CREATOR` (hidden when no URL). `FIGHTER LAB` is removed from the menu (the scene still exists for developers: open `scenes/character_debug.tscn`).

### T8 — Disclaimer gate (Web shell)
- `tools/patch_web_export.py`: `#worldFightDisclaimer` modal over everything, with Hebrew (primary) and English text, a checkbox, and an `ENTER THE GAME` button that is disabled until the box is checked. It sets `localStorage['wf-disclaimer-v1']`. While the modal is open, the game cannot be entered. Text: satire and parody only; no affiliation with or endorsement by any person or party; any resemblance is caricature; no call for or encouragement of violence of any kind; free and non-commercial; anonymous usage statistics; this notice is not legal advice.
- **The owner should still consult a lawyer** (defamation, right of publicity, incitement). Further risk reductions are listed under "Open items".

### T9 — Analytics
- `data/site_config.json`: `{"goatcounter_code": "", "linkedin_url": ""}`. The patcher injects the GoatCounter script only when the code is set.
- Godot → JS: `_track(name, props)` calls `window.worldFightTrack`. Events: `session_start`, `disclaimer_accepted` (shell), `menu_start_fight`, `menu_campaign`, `contact_click`, `fight_start` (player, rival, stage, mode), `round_end` (winner, reason), `match_end` (result, score), `finisher` (fighter, hit/miss), `campaign_progress` (index), `rematch`, `new_opponent`.
- GoatCounter dashboard: visits, unique visitors, countries, devices, and per-event counts (events are sent as `event:<name>` paths).

## Missing assets / owner actions

| Item | Needed for | How to provide |
|---|---|---|
| Illustrated "super move" art per fighter (like the FINAL JUDGMENT concept) | T1, optional | PNG with transparent background, about 1200×1400, at `assets/finishers/<fighter_id>/super-card.png`. Picked up automatically. |
| Finisher display names | T1, optional | Add `"display_name": "FINAL JUDGMENT"` to each finisher in `data/finishers.json`. |
| LinkedIn profile URL | T7 | Set `linkedin_url` in `data/site_config.json`. |
| GoatCounter account code | T9 | Sign up at goatcounter.com (free); set `goatcounter_code` (the subdomain, e.g. `worldfight`). |
| Legal review | T8 | Have a lawyer review the disclaimer and the use of real names and images. |

## Open items / ideas (not started)
- Optional parody names (e.g. letter swaps) behind a setting, to reduce legal exposure further.
- Hebrew in-game UI requires bundling a Hebrew-capable font (e.g. Noto Sans Hebrew, OFL licence) in `assets/fonts/`.
- Server-side analytics alternatives (Cloudflare Web Analytics) if the site moves off GitHub Pages.

## How to verify
- `python -m unittest discover -s tests -p 'test_*.py'`
- All Godot tests: `tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd` for every `tests/test_*.gd`.
- Local Web build: see the memory note / README. Export from a clean copy of the tracked files with `APPDATA` pointing at `tmp/godot-data`, run `python tools/patch_web_export.py`, serve `export/web`, then use Playwright (`isMobile`, `hasTouch`, `deviceScaleFactor: 3`, `locale: 'he-IL'`).

## Delivery record

| Task | Status | Evidence / notes |
|---|---|---|
| T1 Super-move card | Done | `scripts/ui/super_move_card.gd`; default art is the transparent cross-punch sprite (frame 5), flipped toward the title; roster cards were rejected because their opaque background looked pasted. Integration test asserts the card opens and is cleaned up; Playwright `?qa=finisher` screenshot reviewed. |
| T2 No zoom jump | Done | `_camera_preset` keeps the fight framing; the projectile pan was removed. `test_finisher_presentation.gd` and the integration test assert unchanged FOV and position. |
| T3 Styled announcements | Done | `scripts/ui/callout.gd` wraps `message_label` (and finisher captions); style is derived from the text. Existing message tests unchanged. |
| T4 KICK button | Done | `TOUCH_CONTROL_LAYOUT` `kick` with a boot icon; one tap = one kick without energy (`test_mobile_control_contract.gd`). |
| T5 Result screen | Done | Framed card with gradient shade, `ResultFx` confetti/cracks, console bottom bar. `test_ui_presentation.gd` updated; `?qa=win` / `?qa=loss` screenshots reviewed (QA shortcut shows 3–0 because the forced KO adds a round; normal play is unaffected). |
| T6 Campaign ladder | Done | `campaign_ladder_for`, `campaign_level_for`, `_build_campaign`, `_show_campaign_progress`; campaign skips arena select. Campaign fighter selection hides the random-rival panel, and unreached ladder rivals remain `?` until their fight. `test_campaign_ladder.gd` covers all 13 player picks, the ramp, reveal rules, advance, retry and completion. 1280x720 selection and ladder captures reviewed. |
| T7 Menu | Done | Fighter Lab removed; `ContactCreatorButton` is hidden until `linkedin_url` is set (UI test). |
| T8 Disclaimer | Done | Shell modal, checkbox-gated button, versioned `localStorage` and a compact layout under 440 px height; `tests/test_web_legal_analytics.py`; Playwright verified that the button is disabled until checked and that acceptance is stored. |
| T9 Analytics | Done (needs owner's GoatCounter code) | Shell `worldFightTrack` + optional GoatCounter; Godot `_track()` events; Python tests for sanitising and opt-in. |

### Follow-up (2026-10-09, owner input)

| Item | Status | Notes |
|---|---|---|
| Analytics live | Done | `goatcounter_code = "roeeangel"`. The dashboard is at https://roeeangel.goatcounter.com. Events appear as `event-<name>` paths. GoatCounter ignores localhost, so only the live site counts. |
| LinkedIn + creator photo | Done | `linkedin_url` set. A `CreatorCard` in the main menu shows `assets/ui/creator.png` (circular), `CREATED BY ROEE ANGEL`, and opens the profile. The separate CONTACT action was removed; the menu actions are START FIGHT and CAMPAIGN. |
| Legal wording | Done | Disclaimer v2 opens with the owner's exact sentence: "המשחק הוא סאטירה בלבד, כל קשר בין הדמויות למציאות הוא מקרי בהחלט, ואין בו שום קריאה או עידוד לאלימות בעולם האמיתי". Then: parody caricatures, no affiliation, free/non-commercial, anonymous statistics. The version bump re-shows it to everyone. A persistent satire line sits in the main menu. Not adopted: parody name changes (that changes the game's identity; owner decision). |
| Finisher names | Done | `display_name` set for all 13 finishers in `data/finishers.json`. |
| Illustrated finisher art | Done | 2026-10-09: generated and integrated one `assets/finishers/<id>/super-card.png` for every fighter from the approved brief and canonical character-card references. All 13 are transparent, left-facing, exact 1200x1400 PNGs with fighter-specific props and accent colours. The complete 13-card in-game contact sheet was reviewed at 1280x720; Mansour was also inspected at 780x360 and 568x320 with no title overlap or cropping. Godot imported every texture; 44/44 Godot tests and 24/24 Python tests passed. |

| Analytics v2 | Done | Readable per-dimension paths (`fight/<mode>/<fighter>`, `sp/<fighter>/<hit|miss>`, `sp-press/<ready|not-ready>`, `campaign/won-NN-of-M`, `campaign/complete/<fighter>`, `linkedin/click`, `playtime/NNmin`); an early-event queue (session starts were lost before count.js loaded). `analytics_path()` in `main.gd` is tested by `test_analytics_paths.gd`. Dashboard guide and custom-domain notes are in the README. |

| First-fight tutorial | Done | `scripts/ui/tutorial.gd`: 7 steps (move, JAB, CROSS, KICK, jump, GUARD, SP at 100%), pulsing pointer, coach panel, SKIP, frozen clock, passive CPU, fresh round afterwards, `user://tutorial.cfg`, pause *HOW TO PLAY*, funnel analytics. It opens only after the first selected fight reaches `FIGHTING`; the SP step hides the coach during the cinematic and completes from `sequence_finished`, so the fresh fight cannot start before the move ends. `tests/test_tutorial.gd`; full browser run via `?qa=tutorial` with keyboard. |
| Illustrated finisher art | Done (owner commit `84f155f`) | 13 `super-card.png` files; the package is now about 19.8 MB. |
| Kaplan Junction stage | Done | The supplied photo is preserved as a centre-cropped 1920×1080 arena, registered as the sixth stage, and shown in a balanced 3×2 arena grid. `tests/test_kaplan_stage.gd`; fight framing inspected at 1280×720 and 780×360. |

### Remaining owner actions
1. Legal review of the disclaimer wording, and a decision about parody names.

### Next ideas for a future agent
- A Hebrew-capable font, to localise the in-game UI.
- Per-campaign-stage intro cards and a champion celebration screen with confetti.
- Persist campaign progress across sessions (`user://campaign.json`).

### Follow-up (2026-10-10): Finisher delivery and tutorial focus

- **One Web game package:** finishers now ship in `index.pck`; the deferred
  `finishers.pck` download and SP loading gate were removed. A live Pages
  smoke test confirmed no `finishers.pck` network request.
- **Quiet combat feedback:** the raised centre lane now shows only
  `HITS · DMG`; quality labels, named-combo copy, breaker copy, and normal
  live-combat SP coaching no longer cover the fighters.
- **Tutorial clarity:** the first fight opens with `LEARN THE BASICS`, uses a
  dimmed Highlight Overlay around the active control, and ends at an explicit
  `TRAINING COMPLETE` / `START FIGHT` gate before CPU handoff. Pages captures
  were reviewed at desktop and 780×360 landscape-phone sizes.
- **Verification:** 33/33 Python tests passed; all 57 Godot test scripts
  passed under isolated `APPDATA` (the engine still emits its known Windows
  certificate/teardown warnings).
