# World Fight: Election Edition

משחק קרבות סאטירי מקורי, אופליין, שנבנה ב־Godot 4 כמשחק 2.5D עם לוחמים מצוירים מבוססי ספרייטים.

This repository is the source of truth for the game. New contributors and agents should read this file and [`AGENTS.md`](AGENTS.md) before changing code or art.

## Current game

- 13 playable fighters: Bennet, Avigdor Lieberman, Bibi, Yair Golan, Aryeh Deri, Yair Lapid, Mansour Abbas, Benny Gantz, Itamar Ben-Gvir, Bezalel Smotrich, Gadi Eisenkot, Donald Trump and Joint List.
- Single Fight with one player choice and a random CPU rival, revealed by a quick roster shuffle on CONFIRM FIGHT.
- Four-fight campaign, best-of-three rounds, health, hit stun, guard, combos and a charged special meter.
- Six stages, including the Knesset exterior, Knesset chamber, Kaplan Junction and three studio arenas.
- Keyboard and touch controls.
- Fighter Sprite Lab for inspecting every animation outside a match.
- CC0 audio: menu, fight and low-health music, hit/guard/movement/UI effects and a round announcer (`ROUND ONE`, `ROUND TWO`, `FINAL ROUND`, `FIGHT`, `YOU WIN`, `YOU LOSE`). Sources are listed in `assets/audio/README.md`.

The thin gold bar under each health bar in the combat HUD is **Special Energy** (labelled `SPECIAL ENERGY` with a percentage). Clean hits charge the attacker, blocked hits charge it a little, and the defender gains comeback energy from damage taken. At 55% the keyboard special move unlocks; at 100% the `SP` finisher unlocks and its button lights up with an electric aura.

## Controls

| Action | Keyboard |
|---|---|
| Move | `A` / `D` or arrow keys |
| Jump | `W` or Up |
| Guard | `S` / `H` |
| Crouch | `C` |
| Jab (`JAB`): fast, short-range combo starter | `J` / `1` |
| Cross (`CROSS`): slower, longer-range high-damage hit | `K` / `2` |
| Kick (`KICK`) | `U` / `4` |
| Special move (costs 55% energy) / `SP` finisher at 100% | `L` / `3` |
| Pause / back | `Esc` |

Phone controls follow the HUD reference: a joystick on the left (push up to jump, down to crouch) and a right-hand cluster of `JAB`, `CROSS`, `KICK`, `SP` and `GUARD`. Every button acts exactly once per tap, on press; its hit area is exactly the drawn diamond or circle, and each finger is tracked separately, so you can attack while holding the joystick. `KICK` needs no energy; the 55% special move is keyboard-only (`L` below 100%).

`SETTINGS` is available from both the main menu and pause menu. Master, Music, SFX and Voice volumes are saved between sessions, with Mute All and Reset to Defaults controls. Returning from settings opened during a fight keeps the match paused. The announcer calls Round 1, Round 2, Final Round, Fight, You Win and You Lose; licensed audio provenance and required attribution are recorded in [`assets/audio/README.md`](assets/audio/README.md).

Finisher controls: fill Special Energy to 100%, then press `L` / `3` once or tap `SP` on touch screens. No prior round win or rival-health threshold is required. The authored sequence always starts and spends the full meter; it damages the rival only when the fighters were inside the configured activation range at the instant of the press. An out-of-range attempt plays as an opening miss, deals no damage and resumes combat. **A finisher is a heavy blow, not an automatic win:** in a match it deals 30% of the rival's max HP. If the rival survives, it falls, gets up and the round continues. If the blow empties the bar, it is a normal round KO; the match ends (and the celebration plays) only when that KO wins the best-of-three. All 13 fighters have an authored Finish Attack and post-match celebration. At the end of a full match, the winner celebrates unobstructed for at least three real-time seconds at 40% authored speed; only then does the compact `YOU WIN` / `YOU LOSE` card appear. `REMATCH` / `TRY AGAIN` replays the same rival; `NEW OPPONENT` draws a different random rival. `WIN CELEBRATION` in Finisher Lab previews the same slower sequence directly.

Special Energy carries over between the rounds of a match and resets when a new match starts.

The CPU uses an adaptive brain (`scripts/cpu_brain.gd`). During a match it learns which attack the player tends to throw after which (an order-1 Markov table), how often the player guards, and the player's preferred attack distance. It then chooses between spacing just outside the player's reach, pressure, baiting a whiff and defending, using a weighted random choice so it never settles into a readable pattern. It punishes missed attacks during their recovery, guards more often against habits it has learned, and never repeats the same attack three times in a row. The level sets its reaction time and guard skill. `tests/test_combat_fairness.gd` plays ten best-of-three matches between a scripted average player and the level-1 CPU and checks that the player wins between 40% and 82% of rounds, that rounds last at least 22 seconds, that Special Energy reaches 100% in most matches, that the CPU's attack choice has at least 1.2 bits of entropy, and that its guard rate against a repeated habit rises over time.

`SETTINGS` (main menu and pause) has three tabs. `GAME` picks the CPU difficulty, `AUDIO` holds the volume sliders, and `LEGAL` repeats the satire disclaimer in English; on the Web, `SHOW FULL DISCLAIMER` reopens the shell's Hebrew notice through `window.worldFightShowDisclaimer`. The difficulty presets live in `data/difficulty.json` and are saved to `user://game_settings.cfg`. Each preset sets the Quick Fight CPU level (`quick_level`) and shifts the campaign's 1-to-4 ramp (`campaign_offset`): EASY uses level 0 and ramps 0 to 3; NORMAL (the default) keeps the tuned level 1 and ramps 1 to 4; HARD uses level 2 and ramps 2 to 4; EXPERT puts every rival at level 4. `tests/test_settings_menu.gd` covers the tabs, presets, saving and the creator card.

## Run the project

1. Install Godot 4.7 or newer.
2. Import `project.godot` in Godot.
3. Run the main scene: `scenes/main.tscn`.

```powershell
godot --path .
```

The project disables Blender import in `project.godot`; gameplay uses the sprite pipeline and does not require Blender.

## Play on a phone

Every push to `main` exports the Godot Web build and deploys it to GitHub Pages at [israel-election-fight.online](https://israel-election-fight.online/) (the old `roee030.github.io/world-fight-election` address redirects there). Open it in a phone browser and rotate to landscape. While the engine downloads, a branded loading screen shows the percentage and megabytes, warns about slow connections and offers `RETRY` if the engine fails. The game fills the entire landscape screen: Godot uses the `expand` stretch aspect on a 1280×720 design canvas, so wider phones show more arena instead of black bars; the HUD panels and touch controls anchor to the screen edges, and menus stay centred. On Android phones a `TAP TO FIGHT` gate enters fullscreen and locks landscape; leaving fullscreen pauses the fight and shows the gate again. Browsers without the fullscreen API skip that gate. On iPhone/iPad, the rotate screen explains how to use **Share → Add to Home Screen**; because iPhone Safari has no fullscreen API, a landscape Safari tab also shows the same three Home Screen steps once per tab (`PLAY HERE` dismisses it, `?qa=ios-install` previews it on any browser); opening that installed Web app removes Safari's tabs and requests landscape through the Web manifest. A normal Safari tab cannot hide the browser chrome, and the site cannot override the device's Rotation Lock. Add `?diag=1` to the URL for an on-screen diagnostics panel (load stage, engine heartbeat, viewport, safe area, GPU and last console errors).

The UI is authored left-to-right and is forced to stay that way (`internationalization/rendering/root_node_layout_direction=1` plus `Window.LAYOUT_DIRECTION_LTR`). Without it Godot mirrors every screen on Hebrew phones and browsers, which pushed the menus off-screen and left only the background art visible.

Images are imported as lossy WebP by default (`[importer_defaults]` in `project.godot`), which cut the downloaded package from about 65 MB to about 15 MB. Textures decode to the same GPU format, so runtime performance is unchanged.

In portrait orientation the page now shows a dedicated illustrated rotate gate: the complete fighter roster surrounds a landscape-phone cue beneath the Knesset menorah, with a visible `FULL SCREEN` button. Rotating to landscape triggers a best-effort browser full-screen request, and the first landscape tap also retries it; mobile browsers that require a user gesture retain the button as the reliable fallback. In landscape, every Web fight exposes the movement joystick plus `JAB`, `CROSS`, `KICK`, `SP` and `GUARD`. Editor-only 3D sources, raw sprite sheets, reference images and tests are excluded from the Web package to reduce its initial download without removing runtime fighters, stages or finishers. The web export replaces the former PWA worker with a self-retiring cleanup worker that unregisters itself and clears old caches without reloading open tabs (a forced reload used to download the game twice).

## Project structure

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Screen flow, stages, HUD, rounds, pause and result presentation |
| `scripts/fighter.gd` | Movement, attacks, damage, AI, health, special meter and reaction states |
| `scripts/fighter_visual.gd` | Fighter height, grounding, sprite clips and shadow setup |
| `scripts/character_debug.gd` | Fighter Sprite Lab |
| `scripts/opponent_selector.gd` | Random rival selection |
| `scripts/audio/audio_manager.gd` | Music/SFX/Voice buses, saved volumes, music crossfades and cue playback |
| `assets/audio/` | Music, effects and announcer OGG files (CC0) |
| `assets/characters/*-card.png` | Canonical full character artwork |
| `assets/characters/portraits/` | Face-focused selection and HUD portraits |
| `assets/characters/sprites/` | Normalized transparent combat frames |
| `assets/stages/` | Full-frame stage backplates |
| `assets/ui/main-hero-video.ogv` | Looping, silent main-menu hero video (Godot-ready Theora) |
| `assets/ui/main-hero-*.png` | Title-art candidates; `main-hero-b.png` is the video fallback |
| `tools/slice_sprite_sheets.py` | Sprite extraction and normalization |
| `tools/build_portraits.py` | Rebuilds face-focused roster portraits |
| `tests/` | Headless Godot and Python regression tests |
| `docs/` | Art pipeline, combat plans and future design work |

## Character art contract

Every playable fighter must have:

1. A canonical `assets/characters/<id>-card.png` character illustration.
2. A generated `assets/characters/portraits/<id>.png` upper-body portrait.
3. Twelve normalized transparent frames in `assets/characters/sprites/<id>-0.png` through `<id>-11.png`.
4. Geometry metadata in `FighterVisual.FIGHTER_GEOMETRY`.
5. Entries in `FIGHTER_DATA` and `PLAYABLE_IDS`.

Do not paste a photo onto a generic 3D body. The game uses coherent, complete fighter artwork and sprite animation. See [`docs/character-pipeline.md`](docs/character-pipeline.md).

## Rebuild derived art

```powershell
python tools/build_portraits.py
python tools/slice_sprite_sheets.py
```

After rebuilding PNGs, let Godot finish importing before running visual tests.

## Tests

```powershell
python -m unittest tests.test_slice_sprite_sheets

Get-ChildItem tests/test_*.gd | ForEach-Object {
  godot --headless --path . --script ("res://tests/" + $_.Name)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Regression coverage checks roster completeness, random opponent selection, sprite geometry, real hit damage, reaction clips, grounded shadows, pause behavior and presentation structure.

## Current design direction

- Full-screen cinematic title art with a small floating text menu.
- Fighter selection shows all fighters at once with face-focused portraits.
- Angular fighting-game HUD with edge portraits, segmented cyan/red health, round markers, a central timer and a thin gold `SPECIAL ENERGY` meter. Phone controls use a large left joystick and a right-side diamond cluster matching the supplied console-fighter reference.
- The defeated fighter falls on the lethal hit and remains grounded. Results stay hidden while the winner celebrates unobstructed for at least three seconds at 40% speed, then reveal one compact result card.
- Per-stage visual alignment keeps feet on the visible floor.

On phones, `SP` launches a finisher with one tap whenever Special Energy is full. Distance determines hit or miss rather than whether the sequence starts. The Web loading screen disappears as soon as the real Godot menu reports ready.

The shared finisher and celebration system is complete for all 13 fighters: one MAX/Special press at 100% triggers the authored timeline, pause freezes the cinematic, and Fighter Lab previews hit, miss and celebration sequences. Fighter Lab shows the complete roster at once with a dedicated `FINISH` button for each fighter, plus hit/miss, pause, frame-step, mobile-density and reduced-motion controls. `LIVE VERSUS TEST` creates a production fighter and a selectable rival with full Special Energy; use the normal keyboard controls or the lab action buttons, then `F` or `FINISH NOW` to validate in-range hits and out-of-range misses. The authoritative delivery record is [`docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`](docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md).

## Asset and repository policy

- Keep source code, curated game assets, design documents and tests in Git.
- Keep Godot caches, local exports, portable Blender downloads, temporary renders and the raw third-party character pack out of Git.
- Third-party licenses retained under `assets/characters/rigged/source/` must remain with their corresponding assets.
- Review generated artwork for clean anatomy, readable silhouette, transparent edges and correct ground contact before integration.

## Status

The game is playable and under active visual and combat polish. The current priority is consistent character presentation, readable hit feedback, robust pause behavior, stage grounding and data-driven finishing moves.


## Presentation, campaign, legal and analytics (2026-10-09)

- **Finisher card:** every finisher opens with a full-screen super-move card: fighter pose, fighter name, and an electric, slanted finisher name (`display_name` in `data/finishers.json`, else the humanised `finisher_id`). Optional illustrated art: `assets/finishers/<id>/super-card.png`. The camera no longer zooms in or out around it.
- **Announcements:** ROUND / FIGHT! / feedback messages and finisher captions play as animated console-style banners (`scripts/ui/callout.gd`).
- **Results:** a framed YOU WIN / YOU LOSE card (cyan with confetti, or red with cracks) over the live arena, with REMATCH, NEW OPPONENT and RETURN TO MENU.
- **Campaign:** beat every other fighter in a shuffled ladder; Bibi is always the final boss (a mirror match if you picked Bibi). Difficulty ramps from level 1 to 4. A progress screen shows the ladder before every fight. A loss retries the same rival.
- **Menu:** START FIGHT, CAMPAIGN and CONTACT THE CREATOR. The contact button appears once `linkedin_url` is set in `data/site_config.json`. Fighter Lab is developer-only (`scenes/character_debug.tscn`).
- **Disclaimer:** the Web shell shows a Hebrew/English satire disclaimer. Play starts only after the checkbox is ticked; acceptance is stored per device (`wf-disclaimer-v1`). This text is not legal advice; have a lawyer review it.
- **Analytics:** anonymous, cookie-free GoatCounter (`goatcounter_code` in `data/site_config.json`); dashboard https://roeeangel.goatcounter.com. See "Analytics guide" below.
- **Combos:** chain JAB / CROSS / KICK while the rival is still reeling. Every fighter shares five named strings (ONE-TWO, QUICK CROSS, POWER LINE, HEAVY HANDS, SWEEP STRING) and has one 4-hit signature string (for example Bibi's PROTECTION DETAIL). Names, inputs, finales (knockback, knockdown, stagger), damage scaling and routes live in `data/combos.json`. Double-tap GUARD while being hit is a **combo breaker** (35% Special Energy). The pause menu shows a MOVE LIST whose inputs are chips coloured like the touch buttons. The CPU uses the same strings by level and can break your combos.
- **Sound indicator:** a SOUND / MUTED button with a speaker icon sits in the main menu (next to FULL SCREEN) and in the fight HUD (next to pause). Tapping it toggles mute and stays in sync with the Settings screen. Analytics: `sound/muted`, `sound/on`.
- **First-fight tutorial:** the tutorial stays closed on startup and character selection, then the first fight on a device opens an explicit `LEARN THE BASICS` gate before the one-time guide: move, JAB, CROSS, KICK, jump, GUARD, combo, then Special Energy fills to 100% and the glowing SP button launches a first finisher. A dimmed Highlight Overlay leaves only the required control bright; the CPU stands still and the clock is frozen. SKIP is always available. The final SP step waits for the complete finisher sequence, then shows `TRAINING COMPLETE`; `START FIGHT` begins the fresh real round. Completion is stored in `user://tutorial.cfg`; *HOW TO PLAY* in the pause menu replays it. Analytics: `tutorial/start`, `tutorial/step-<id>`, `tutorial/complete`, `tutorial/skip-at-<id>` (shows where players drop out).
- **QA URLs:** `?qa=fight`, `?qa=tutorial`, `?qa=finisher`, `?qa=win`, `?qa=loss`, `?qa=campaign` jump straight to those screens for screenshots.

## Analytics guide

GoatCounter is anonymous by design: it counts visits and events, with country, device, browser and time, but never identifies a person. Each game event has a readable path, so each dimension gets its own dashboard row. Type a prefix into **Filter paths** to group them:

| Filter | What it answers |
|---|---|
| `session/start` | Sessions per day (`touch` = phones/tablets, `desktop`) |
| `playtime/` | How long people play: `playtime/01min`, `03min`, `05min`, `10min`, `20min`, `30min`, `60min` count sessions that reached that much visible play time. |
| `fight/` | Which fighters players pick: `fight/quick/<fighter>`, `fight/campaign/<fighter>`. The rival and stage are in the row title. |
| `sp-press/` | SP button presses: `ready` (finisher available) vs `not-ready` (pressed too early) |
| `sp/` | Finishers performed per fighter, `hit` or `miss` |
| `result/` | Match results per mode (`win` / `loss`) |
| `campaign/` | `campaign/start/<fighter>`, then progress `campaign/won-03-of-12` (players who beat their 3rd rival), and `campaign/complete/<fighter>` |
| `linkedin/click` | Clicks on the creator card |
| `menu/` | Start Fight / Campaign / Rematch / New Opponent |
| `disclaimer/accepted` | Players who accepted the disclaimer |
| `combo/` | Named combos used (`combo/quick-cross`, `combo/kingmaker`), combo length (`combo/hits-3`), breakers (`combo/break-player`, `combo/break-cpu`) |
| `tutorial/` | Tutorial funnel: `start`, `step-<id>` per completed step, `complete`, `skip-at-<id>` |

**Moving to a custom domain:** the dashboard is tied to the site code (`roeeangel`), not to the domain, so all history stays and new data keeps arriving in the same dashboard. In GitHub go to *Settings → Pages → Custom domain*, add the domain, and point a DNS `CNAME` record to `roee030.github.io` (or `A` records for an apex domain). The only visible change: the page-view row switches from `/world-fight-election` to `/`; all event rows are unchanged. If GoatCounter's *Settings → Sites/allowed domains* is ever restricted, add the new domain there.

## Web loading

The Web build ships one complete `index.pck`: menu, fighters, stages, audio and every finisher. SP is ready as soon as its normal combat rules are met; it never waits for a second art download. Native and Web builds therefore use the same finisher resources.

## Search visibility (SEO)

The game is a WebGL canvas, which search engines cannot read, so `tools/patch_web_export.py` adds everything crawlers need around it: a Hebrew `<title>` and description (the shell pins the title because Godot renames the tab at start-up), canonical and hreflang links, Open Graph and Twitter cards, `VideoGame` JSON-LD, favicon and manifest icons, and a visually hidden `<main id="wf-seo">` summary plus `<noscript>` text. Static files live in `web/static/` and are copied into every export: `robots.txt`, `sitemap.xml` (the build date is stamped in), `CNAME`, `404.html`, the Hebrew guide `/about/` and the English guide `/en/`, the favicon set and `og-image.jpg`. Regenerate the icons and share image with `python tools/build_seo_assets.py`. The canonical domain is `site_url` in `data/site_config.json`; `tests/test_web_seo.py` guards all of it. The private dashboard path is never listed in `robots.txt` or the sitemap (the dashboard itself is `noindex`).

One-time owner steps: add the domain as a property in Google Search Console (DNS TXT record in Cloudflare), submit `https://israel-election-fight.online/sitemap.xml`, and optionally import it into Bing Webmaster Tools.
