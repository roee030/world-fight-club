# 2.5D Fighter Roster Expansion Plan

## Goal

Replace combat character models with recognizable side-view 2D fighters while retaining the existing 3D stages, combat engine, health, AI, combos, campaign and mobile controls.

## Visual contract

Every fighter receives the same 12-pose sheet: idle, walk contact, walk passing, crouch, jab, cross, kick/signature, block, hit, knockdown, grounded and get-up. All poses face right, use the same baseline and scale, and have transparent backgrounds.

## Current roster

- Bennet — navy/cyan Krav Maga founder
- Avigdor Lieberman — charcoal/burgundy counter fighter
- Bibi — navy/gold statesman fighter
- Yair Golan — olive field fighter

## New roster

- Aryeh Deri — purple/gold fictional religious rogue
- Yair Lapid — cobalt/white boxer
- Mansour Abbas — emerald/cream heavyweight diplomat
- Benny Gantz — very tall steel-blue defensive commander
- Itamar Ben-Gvir — orange/black fictional warden with a small crocodile shoulder mascot
- Bezalel Smotrich — burnt-orange/gray fictional prisoner-costume fighter
- Gadi Eisenkot — short, stocky olive/red commander

The costumes and lore are fictional satire and are not factual claims about the people depicted.

## Implementation

1. Generate and preserve one transparent 12-pose sheet per new fighter.
2. Slice sheets into deterministic frame files and validate dimensions/alpha/baseline.
3. Restore the sprite-based `FighterVisual` pipeline and remove combat dependence on custom 3D character GLBs.
4. Add fighter data, palette, styles, stats and roster/menu assets.
5. Keep Model Lab as Sprite Lab for reviewing characters and animations outside combat.
6. Run focused tests for every fighter, every animation state, facing, hit interruption, health, rounds, menus and main-scene smoke.
