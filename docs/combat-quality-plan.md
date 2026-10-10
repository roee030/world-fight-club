# World Fight combat-quality work

The work follows the guide sequence: settle scale, floor contact, and spacing;
then make movement and combat states readable; then tune the CPU and add content.

## Completed in this pass

- Corrected the sprite foot anchor so fighter artwork sits on its ground shadow.
- Reduced movement speed, eased acceleration and stopping, and shortened the jump arc.
- Added depth sidesteps and lane-aware attack range. Fighters can pass across one
  another by jumping; grounded fighters still keep clear space.
- Made crouching visible and let it evade the high heavy strike.
- Added a knockdown and timed get-up after a clean special strike.
- Added takeoff, air, and landing animation states. The existing Bennet and
  Avigdor frames use these states with their available art; new fighters use
  six authored poses each.
- Changed CPU behavior to approach, engage, defend, retreat, and recover. It
  reads attack timing, guards during active threat windows, sometimes ducks a
  heavy strike, and has a brief attack cooldown.
- Added Bibi and Yair Golan to character select, single fights, campaign order,
  fighter stats, and combat sprites.

## Next work, in order

1. **Play-feel pass:** run repeated matches on desktop and phone; adjust movement,
   jump distance, lane separation, attack reach, hitstun, and CPU reaction delay.
2. **Frame-authored combat:** use the exact animation frames and per-move data to
   place fist/foot hitboxes and define startup, active, recovery, guard reaction,
   and knockback. Current attacks still use distance checks rather than authored
   limb hitboxes.
3. **Complete animation set:** add dedicated jump takeoff/air/landing, duck/block,
   hit-fall, grounded knockdown, and get-up drawings for every fighter. The
   current fall/get-up uses a procedural pose; the newly added fighters have six
   poses and reuse them across their clips.
4. **CPU tuning:** test each difficulty against different player habits, then
   tune reaction time, punish choices, defense, and spacing based on those games.
5. **Impact and character audio:** add the user-provided fighter sounds, then
   distinct guard, clean-hit, heavy-hit, and campaign-boss cues.
6. **Finishers:** design these after basic move timing and hit reactions are
   stable, as planned.

## This update

- Added a stage-pick screen after fighter selection. It includes the Knesset exterior and chamber, The Patriots studio, Friday studio, and Hatzinor studio. Supplied stage art is used in stage selection and as the fight backdrop.
- The main-cover roster and the fighter-select grid now both read the playable roster, so adding a fighter entry and its portrait adds it to both screens.
- Attacks keep the facing direction captured at startup through their active frames, and hit checks use that locked direction. This prevents a cross-up from turning a committed attack around mid-swing.
- Special knockdowns keep their floor capsule enabled. They face the attacker and fall away from the hit, then recover through a short get-up animation.
- A forward jump near an opponent now adds a measured depth-lane crossing and a higher arc. This makes the pass read as moving behind the opponent instead of occupying the same screen plane. Ordinary grounded separation and attack lanes remain active.

## 2026-10-06 quality pass

- Stage selection now uses a 16:9 prepared background that preserves the complete supplied image. If the source has a different aspect ratio, a softened version fills the margins while the original stays fully visible in the center. Fight arenas now display only that image and a hidden collision floor; generated pillars, wall, desk, crowd and floor meshes no longer cover it.
- Taking an unblocked hit now clears the victim's attack clip, lunge timer and lunge velocity as part of interrupting the move. The movement loop also allows lunge only while an attack is still active and the fighter is not stunned or knocked down. This prevents a canceled attack from carrying the victim forward.
- The basic combo is jab → cross → hook, with up to three confirmed hits. Press K again during the cancel window: after jab it plays cross, after cross it plays hook. The signature remains a separate meter move. Keyboard hints and the touch button now describe the cross/hook input.
- Attack keys now fire on the press edge instead of repeating while held. New attack requests are discarded during hit-stun, knockdown and get-up, and the hit pose is applied immediately. This closes the input-buffer route that could replay a held punch as soon as the victim recovered. Fighter spacing was increased so standing sprites do not overlap before a strike connects.
- Bibi and Yair's menu/select art is derived from their generated combat atlases, not from their supplied source photos. Side art and compact roster busts are separate assets, and rival art is mirrored to face the player side. Their original reference files remain available as art direction.
- Quaternius UAL1 and UAL2 free Standard GLBs and CC0 notices are in `assets/animations/quaternius/`. The visible combat bodies use the CC0 Universal Base Characters mesh and its exact matching 65-joint UAL skeleton. Walk, Punch_Jab, Punch_Cross, Melee_Hook, Hit_Chest, Hit_Knockback, LayToIdle and jump clips now animate that final skeleton directly. The UAL mannequin and photographic face attachments were removed. Project-owned 3D clothing, hair and accessories follow the body bones for all four fighters.
- `tools/prepare_visual_assets.py` can rebuild the wide stage backplates and Bibi/Yair hero and thumb art from the included source art.
