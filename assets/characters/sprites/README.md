# Fighter animation frames

Each PNG is a transparent 320 × 420 frame used by AnimatedSprite3D clips inside the
3D arena. Frames come from the approved concepts and share a right-facing base pose.
The opponent sprite is mirrored at runtime to face its rival.

Frame order:

0. Idle guard
1. Guard / movement anticipation
2. Quick straight punch
3. Heavy hook
4. Front kick / special move
5. Hit reaction
6. High block
7. Recovery guard
8–11. Four-frame walk-forward loop
12–15. Four-frame walk-back loop
16–19. Progressive four-frame jab
20–23. Progressive four-frame heavy cross

The original two fighters use the 24-frame numbered sequence above. Bibi and
Yair Golan use six generated full-body poses sliced from 3×2 source atlases by
`tools/import_fighter_atlases.py`:

0. Neutral guard
1. Short step
2. Crouching guard
3. Lead-hand punch
4. Rear-hand counter
5. High kick

Their attack clips repeat/hold these authored key poses to match the same
startup, active, recovery, and cancel windows in `scripts/fighter.gd`. The art
is generated from the user-provided reference photos; the source atlases live in
`output/imagegen/` and are excluded from web exports.

Source sheets are in `output/imagegen/`; they are excluded from Web exports. This
keeps the game download small while retaining the original sheets for future edits.
