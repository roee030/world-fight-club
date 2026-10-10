# Roster and Interface Polish Design

## Intent

Bring every fighter to the same recognizable 12-pose sprite standard, correct sprite grounding and scale, make the opponent random after a single player selection, and raise the menu, HUD and result presentation to the visual quality of the stage and newest fighters.

## Character contract

Every fighter has one transparent 4x3 sheet with the fixed pose order already used by the new roster. A manifest stores display scale, physical height and ground offset separately from the artwork. Full-body alpha bounds must remain inside each cell with padding. Existing Bennet, Avigdor, Bibi and Yair Golan are regenerated to this contract. Trump and Joint List are added; Joint List is one satirical two-headed fighter based on the supplied two-person reference, without demeaning ethnic caricature.

## Visual direction

- Bennet: recognizable likeness, Krav Maga uniform, humorous head tefillin based on the supplied reference.
- Avigdor: recognizable dark burgundy/charcoal counter fighter.
- Bibi: recognizable royal blue-and-gold king fighter.
- Yair Golan: recognizable olive field fighter.
- Trump: recognizable red/navy showman brawler.
- Joint List: one two-headed suit fighter with two distinct recognizable heads, dignified satirical presentation.

## Layout and flow

The main menu uses a full-width diagonal roster lineup behind a compact title/action panel. Character select chooses only the player's fighter; the opponent preview becomes a question mark and is drawn randomly from all other fighters when the arena is entered. The HUD uses layered frames, portraits, segmented health, clearer round markers and a centered timer medallion. The result screen uses a full-screen victory/defeat composition with winner portrait, accent lighting and clear rematch/menu actions.

## Quality gates

All frames validate for transparency, padding, dimensions and ground baseline. Tests cover per-fighter scale differences, opponent exclusion/randomness, hit interruption, health, menus, HUD and result visibility. Visual captures cover the lineup, selection, combat and both result states.
