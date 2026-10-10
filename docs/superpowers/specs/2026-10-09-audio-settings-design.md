# Audio Direction and Settings Design

**Date:** 2026-10-09
**Status:** Approved in conversation; awaiting review of this written specification

## Goal

Give World Fight a distinctive but restrained audio identity that supports the existing satirical console-fighter presentation without becoming loud, repetitive, or fatiguing. The feature covers menu and fight music, ordinary combat and UI effects, English match announcements, and persistent volume controls available from both the main menu and the paused fight.

This work must preserve the existing visual language, pause contract, finisher timing and 1280x720 expandable canvas layout.

## Creative Direction

The chosen direction is **restrained electronic arcade**: low, controlled bass; modern synthesizer textures; concise percussion; and a subtle election-night broadcast character. It should feel like a polished fighting game rather than a news simulation, while retaining enough broadcast tension to fit the political satire.

The mix must leave space for impacts and announcements. Music is the quietest foreground category by default. No track or effect should rely on constant high-frequency noise, excessive limiting, or large loudness jumps to create excitement.

### Music states

- **Main menu:** a calm, slightly mysterious loop, approximately 60-90 seconds before repetition.
- **Fighter and arena selection:** the menu identity continues with a slightly clearer pulse; transitions must be smooth rather than restarting the musical phrase on every screen.
- **Fight:** a restrained cinematic-electronic loop with more momentum but no intrusive lead melody.
- **Low health:** an optional additive tension layer or mix change, not a sudden replacement track. It must not trigger repeatedly near the threshold.
- **Result:** fight music resolves or fades cleanly before the result sting and announcer line.

Music changes use short crossfades. Opening a settings screen or pausing a fight does not restart the current track.

## Announcer

The announcer is authoritative, clear, and controlled rather than shouted. The lines are:

- `ROUND ONE`
- `ROUND TWO`
- `FINAL ROUND`
- `FIGHT!`
- `YOU WIN`
- `YOU LOSE`

The game is best-of-three, so round three is always announced as `FINAL ROUND`; it is never announced as `ROUND THREE`.

Round flow is:

1. Show the existing round callout and play its matching announcement.
2. Keep both fighters locked in their opening stances.
3. Briefly reduce music under the voice.
4. Show the existing `FIGHT!` callout and play `FIGHT!`.
5. Enable control only at the established fight-live point.

The result line must describe the local player's result. It plays only after the unobstructed victory celebration and when the existing result UI appears: `YOU WIN` for a player victory and `YOU LOSE` for a player loss.

## Sound Effects

The first pass provides separate, short sounds for:

- menu focus/press and back;
- jab, cross, and kick contact;
- guarded contact;
- whiff;
- jump/landing;
- Special Energy ready;
- special activation and finisher presentation;
- victory and loss stings.

Impacts should communicate attack weight without becoming explosive. Repeated light attacks require small pitch or sample variation to avoid mechanical repetition. Existing finisher WAV events remain data-driven and are routed through the shared SFX bus; their authored timing and ownership do not change.

Audio assets must be original or carry a compatible, documented licence. Voice assets must not imitate a real identifiable person. Imported source assets belong under `assets/audio/` with clear subdirectories for `music`, `sfx`, and `voice`.

## Runtime Architecture

Introduce a focused audio service rather than extending the current single procedural player in `scripts/main.gd`. The service owns:

- music playback and crossfades;
- one-shot SFX playback with enough concurrent players for overlapping hits;
- announcer playback;
- temporary music ducking while voice plays;
- bus volume and mute state;
- loading and saving settings.

Godot audio buses are:

- `Master`
- `Music`
- `SFX`
- `Voice`

Music, ordinary effects, announcer clips, and data-driven finisher sounds must be assigned to the appropriate bus. Existing `_play_sound(...)` callers migrate to named cues on the service so gameplay code requests intent instead of managing streams.

The service exposes small semantic operations such as setting the music state, playing a named effect, announcing a round, announcing the result, and changing a volume category. It must tolerate a missing optional audio asset without blocking match flow: emit a clear warning, skip that cue, and continue.

## Settings UI

`SETTINGS` is accessible from:

- the main menu; and
- the pause menu during a fight.

The settings screen uses the existing console presentation helpers in `main.gd`: `_screen_title`, `_split_background`, `_bottom_bar`, `_primary_button`, `_secondary_button`, and `scripts/ui/ornament.gd`. It uses the same typography, gold/cyan accents, panels, borders and button behavior as the other screens. It must not introduce a separate visual system.

All settings UI is forced left-to-right, including on Hebrew/RTL systems. It remains readable at 1280x720 and usable on short phone viewports under the existing `expand` stretch mode. Controls anchor to screen edges and remain centered on 1280-wide screens.

The controls are:

- `MASTER` slider, 0-100%;
- `MUSIC` slider, 0-100%;
- `SFX` slider, 0-100%;
- `VOICE` slider, 0-100%;
- `MUTE ALL` toggle;
- `RESET TO DEFAULTS`;
- `BACK`.

Each slider displays its numeric percentage. Changing SFX volume plays a restrained preview effect after throttling rapid drag updates. Changing Voice volume plays a short voice preview after throttling. Music changes are heard continuously through the active track. Master volume affects all categories.

`MUTE ALL` is non-destructive: it suppresses output without overwriting the four stored slider values. Unmuting restores those values. `RESET TO DEFAULTS` restores the approved balanced defaults, including the mute state.

Opening settings from a fight keeps the tree paused. The settings screen and its controls process while paused, but fighters, CPU, timers, animations, round transitions and finisher state remain frozen. `BACK` returns to the pause menu without resuming combat; only the existing resume action unpauses the fight.

## Persistence

Settings are stored in `user://audio_settings.cfg`. The file records a schema version, the four normalized volumes, and mute state. Loading clamps malformed numeric values into range and falls back per field instead of discarding all valid settings. A missing or unreadable file uses defaults without interrupting startup.

Changes are applied immediately and saved when a control is committed, on leaving the settings screen, and during orderly shutdown when necessary. The implementation avoids a disk write for every pointer-motion event while dragging.

## Integration Boundaries

- `scripts/main.gd` continues to own screen and match flow, but delegates playback and stored audio state.
- The existing styled `Callout` remains the visual owner for round, fight, and result announcements.
- `scripts/finishers/finisher_director.gd` preserves event timing but routes sound-event players to the SFX bus.
- The pause behavior remains authoritative in `_toggle_pause`; settings opened from pause cannot modify fight state.
- Tutorial behavior and signal-driven finisher steps remain unchanged.

README documentation will describe audio controls and settings access. If the asset-generation or licence contract gains a reusable workflow, the relevant asset documentation will be updated as well.

## Verification

Implementation follows the repository workflow: add failing focused tests, make the smallest production change, run focused tests, then run the complete Godot and Python suites.

Automated coverage must verify:

- round one, round two, and final-round cue selection;
- `FIGHT!` occurs at the established control-release boundary;
- win/loss cue selection follows the local player's result;
- all four categories apply independently through the correct buses;
- settings save and reload correctly;
- malformed values are clamped or defaulted safely;
- mute preserves slider values and unmute restores audible levels;
- resetting restores every default;
- settings opened from pause do not unpause combat or advance timers;
- finisher sound events use SFX and remain paused with the finisher;
- missing optional cues do not block match progression.

Visual inspection is required for the main-menu and pause-entry variants of the settings screen at 1280x720 and at a short phone viewport with `locale: 'he-IL'`. The review checks clipping, forced LTR layout, touch target usability, percentage readability and consistency with the current console components.

Audio review is required at both desktop and phone playback levels. It checks voice intelligibility, restrained loudness, smooth music transitions, impact differentiation, non-fatiguing repetition, pause behavior and the balance between Music, SFX and Voice.

## Out of Scope

- Per-fighter voice acting or impersonation.
- A unique full music track for every arena.
- Dynamic music driven by every combat action.
- Changes to combat damage, timing, hit ownership, finisher choreography or celebration contracts.
- A new visual design system for settings.
