# Rigged Character Replacement Design

## Goal

Replace the generic Quaternius mannequins and floating face cards with four
complete, recognizable, clothed 3D fighters. The fighters must remain compatible
with the existing combat engine and its Quaternius walk, strike, hit, fall and
get-up animations. The solution must use free assets and remain suitable for web
and mobile exports.

## Success criteria

- No `CharacterFace` billboard or rectangular portrait appears in combat.
- Bennet, Avigdor Lieberman, Bibi and Yair Golan each have a full 3D body,
  clothing, head, hair and identifying accessories.
- Fighters are recognizable through silhouette, clothing, colors, hair, facial
  hair and accessories. Photographic faces are not pasted onto the models.
- `Walk`, `Punch_Jab`, `Punch_Cross`, `Melee_Hook`, `Hit_Chest`,
  `Hit_Knockback`, `LayToIdle` and jump animations visibly move the final models.
- Facing changes rotate the complete fighter, including clothing and accessories.
- One character configuration creates the same fighter in gameplay, previews and
  future character-select 3D presentation.
- The four fighters stay within a practical web/mobile rendering budget.

## Asset sources and cost

Use the free Standard editions of Quaternius assets under CC0:

- Universal Base Characters for humanoid heads, bodies and hairstyles compatible
  with the Universal Animation Library.
- Ultimate Modular Men for modular male clothing and body variants where its
  parts can be retargeted cleanly.
- Existing Universal Animation Library 1 and 2 files for motion.

Preserve the supplied license files beside imported assets. Do not use paid
Source/Pro files or an external paid character service.

## Architecture

### 1. Character model importer

Import the candidate GLB/glTF character files into
`assets/characters/rigged/source/`. Inspect each skeleton, mesh, material and
bone name before modifying combat code. Select one common humanoid skeleton and
record a deterministic bone map to the UAL rig.

The importer must establish:

- one `Skeleton3D` per fighter;
- skinned body and clothing meshes sharing that skeleton;
- consistent height, floor position and forward axis;
- local materials so recoloring one fighter never changes another;
- no root-motion displacement, because the existing physics controller owns
  movement.

If an old modular garment uses a different humanoid bone naming scheme, retarget
its skeleton through an explicit bone map. A garment that cannot deform cleanly
on the common skeleton is rejected instead of being attached as a floating rigid
mesh.

### 2. Character assembler

Create a data-driven `RiggedFighterVisual` that accepts a character id and builds
the correct body, clothing, materials and accessories. Character definitions
contain asset paths, scale, colors and accessory choices rather than combat
logic.

Initial visual definitions:

| Fighter | Body and clothing | Identity details |
| --- | --- | --- |
| Bennet | Athletic regular male, navy tailored jacket and trousers | Bald head, small dark kippa, clean face, cyan trim |
| Avigdor | Broad male, long charcoal coat or heavy dark jacket | Short gray hair, gray beard, burgundy accents |
| Bibi | Regular male, formal navy suit, white shirt and blue tie | Silver hair, clean face, gold trim |
| Yair Golan | Lean regular male, olive field jacket and cargo trousers | Short gray hair, gray stubble, dark sunglasses |

Small accessories such as kippa and sunglasses may be separate meshes attached to
the head bone. They must be shaped 3D objects, not camera-facing photographs.

### 3. Animation adapter

Keep `QuaterniusMotion` as the single mapping between combat states and animation
clips. Change it to animate the assembled character skeleton rather than loading
and displaying its own mannequin mesh.

The adapter continues to provide:

- cross-faded state changes;
- forward and backward walk playback;
- move-duration synchronization;
- hit-stop freeze and resume;
- left/right facing;
- UAL1 and UAL2 clip libraries on one character.

The combat controller must not know which meshes or clothing pieces a fighter
uses.

### 4. Migration

Build Bennet first as the reference character. Confirm his scale, facing,
clothing deformation and full animation set before duplicating the assembly for
the other fighters. Once all four definitions pass, remove the hidden sprite
fallback and the face-billboard code.

Menu and character-select cards remain the polished rendered artwork already in
the project. They identify the same costume and palette used by the 3D model.

## Data flow

1. `GameFighter.setup()` receives a character id.
2. `FighterVisual.build()` asks `RiggedFighterVisual` to assemble that id.
3. The assembler returns the visible model, common skeleton and shadow.
4. `QuaterniusMotion` binds its animation libraries to that skeleton.
5. The combat state machine requests semantic states such as `jab`, `hit` or
   `knockdown`.
6. The adapter selects and times the corresponding UAL clip.

## Failure handling

- Missing body, garment, skeleton or required bone fails character construction
  with a clear error naming the character and asset.
- Missing optional accessories produce a warning and keep the fighter playable.
- Missing mandatory animation clips fail the automated motion mapping test.
- The game must never fall back to a floating portrait.

## Verification

Automated checks:

- all four character definitions instantiate;
- each instance contains a skeleton and skinned mesh;
- no `CharacterFace` or combat `Sprite3D` exists;
- every required animation is available and reaches the final skeleton;
- attack timing remains synchronized with combat move duration;
- hit-stop freezes and resumes animation;
- facing rotates the full assembled character.

Visual checks at 1280×720 and a phone landscape viewport:

- both fighters stand on the floor without hovering;
- faces and accessories remain attached through walk, punches, fall and get-up;
- clothing does not visibly separate at shoulders, hips or knees;
- silhouettes remain readable against every arena;
- camera framing includes both fighters during movement and knockback.

## Scope boundary

This phase replaces combat models and preserves the existing fighting rules,
menus, arenas and campaign flow. Photorealistic face scanning, custom facial
animation and finishers are outside this phase. The target is a coherent stylized
3D likeness that moves correctly and can be improved without rebuilding the
combat engine.
