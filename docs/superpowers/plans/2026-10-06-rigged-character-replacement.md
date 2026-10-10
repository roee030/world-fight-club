# Rigged Character Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic UAL mannequins and floating face cards with four complete clothed 3D fighters animated by the existing Quaternius combat clips.

**Architecture:** Normalize free Quaternius character assets into one humanoid visual pipeline, describe each fighter with data, and assemble body, clothing, materials and 3D accessories around one `Skeleton3D`. `QuaterniusMotion` becomes an animation-only adapter that binds to the assembled skeleton; combat remains independent of mesh choice.

**Tech Stack:** Godot 4.7.2, GDScript, glTF/GLB, Quaternius Universal Base Characters, Quaternius Ultimate Modular Men, Quaternius UAL1/UAL2.

**Spec:** `docs/superpowers/specs/2026-10-06-rigged-character-replacement-design.md`

## Global Constraints

- Use only free Standard/CC0 assets; preserve license files beside the imports.
- No paid character service, Source pack or Pro pack.
- No photographic face billboard or combat `Sprite3D` fallback.
- The existing physics controller owns displacement; use no-root-motion clips.
- Support Godot WebGL 2 and phone landscape rendering.
- Build Bennet as the reference fighter before expanding the same pipeline to the other three fighters.

## Review Focus

- A missing required mesh or bone must fail with the character id and missing resource in the error.
- A missing optional accessory must warn and leave a playable fighter without creating a portrait fallback.
- Repeated creation of different fighters must not share mutable materials or recolor existing instances.
- Facing changes during attacks must rotate the complete assembly without reversing a committed strike.
- Hit-stop must pause and resume the final skeleton without desynchronizing the combat timer.

---

### Task 1: Acquire and audit the free character assets

**Files:**
- Create: `assets/characters/rigged/source/universal-base-characters/`
- Create: `assets/characters/rigged/source/ultimate-modular-men/`
- Create: `assets/characters/rigged/LICENSES.md`
- Create: `assets/characters/rigged/asset-manifest.json`
- Create: `tools/audit_character_assets.gd`
- Test: `tests/test_character_asset_manifest.gd`

**Interfaces:**
- Consumes: Free Standard asset archives and their CC0 notices.
- Produces: `asset-manifest.json` with exact model paths, skeleton path, mesh names, bone names, forward axis, height and license for every accepted source model.

- [ ] **Step 1: Write `test_character_asset_manifest.gd`** asserting both asset families have CC0 license entries, every listed scene exists, and every accepted fighter source lists a skeleton and at least one skinned mesh.
- [ ] **Step 2: Run the test** with Godot `--headless --path . --script res://tests/test_character_asset_manifest.gd`; expect failure because the manifest and assets do not exist.
- [ ] **Step 3: Download the free Standard archives**, preserve the originals under `downloads/`, extract only model, texture and license files into the source folders, and record source URLs plus archive hashes in `LICENSES.md`.
- [ ] **Step 4: Implement `audit_character_assets.gd`** to instantiate every candidate scene and print skeleton bone names, skin count, surface count, material names, AABB height and animation libraries.
- [ ] **Step 5: Run the audit** and choose one exact modern-clothing source model for each fighter. Accept direct UAL bone names when available; otherwise record the explicit humanoid bone-name map in the manifest.
- [ ] **Step 6: Complete `asset-manifest.json` and rerun the manifest test**; expect PASS.
- [ ] **Step 7: Commit** the imported free assets, licenses, manifest, audit tool and test. If the workspace is still not a Git repository, record the test command and result in `docs/superpowers/rigged-character-ledger.md` instead.

### Task 2: Build the data-driven rigged visual assembler

**Files:**
- Create: `scripts/character_visual_catalog.gd`
- Create: `scripts/rigged_fighter_visual.gd`
- Create: `scripts/humanoid_bone_map.gd`
- Test: `tests/test_rigged_fighter_visual.gd`

**Interfaces:**
- Consumes: `asset-manifest.json` from Task 1.
- Produces: `CharacterVisualCatalog.definition(id: String) -> Dictionary`; `RiggedFighterVisual.build(id: String) -> Dictionary` returning `root: Node3D`, `skeleton: Skeleton3D`, `meshes: Array[MeshInstance3D]`, `shadow: MeshInstance3D` and `warnings: Array[String]`.

- [ ] **Step 1: Write `test_rigged_fighter_visual.gd`** asserting all four ids instantiate, return one skeleton and at least one skinned mesh, contain no `CharacterFace`/`Sprite3D`, use unique material resources, and emit a character-specific error for a missing mandatory body.
- [ ] **Step 2: Run the test**; expect failure because the catalog and assembler do not exist.
- [ ] **Step 3: Implement `character_visual_catalog.gd`** with exact body/clothing/accessory paths, scale, floor offset, material palette and optional accessory flags for the four fighters.
- [ ] **Step 4: Implement `humanoid_bone_map.gd`** with `resolve(skeleton: Skeleton3D, manifest_entry: Dictionary) -> Dictionary` and validation for root, pelvis, spine, head, arms, hands, thighs, calves and feet.
- [ ] **Step 5: Implement `RiggedFighterVisual.build()`** to instantiate the accepted scene, duplicate all mutable materials, normalize height/axis, apply the catalog palette and return the stable interface.
- [ ] **Step 6: Rerun the focused test**; expect PASS for all four ids and the failure-path assertions.
- [ ] **Step 7: Commit or ledger** the assembler task and test result.

### Task 3: Finish Bennet as the reference model

**Files:**
- Create: `scripts/fighter_accessories.gd`
- Modify: `scripts/character_visual_catalog.gd`
- Test: `tests/test_bennet_visual_identity.gd`

**Interfaces:**
- Consumes: `RiggedFighterVisual.build()` from Task 2.
- Produces: `FighterAccessories.attach(character_id: String, skeleton: Skeleton3D, definition: Dictionary) -> Array[Node3D]` and a complete Bennet definition.

- [ ] **Step 1: Write `test_bennet_visual_identity.gd`** asserting Bennet has navy body/clothing materials, cyan accent, a 3D `Kippa` attached to `Head`, no billboard, and floor-aligned bounds between 1.7m and 2.1m.
- [ ] **Step 2: Run the test**; expect failure because the accessories and final Bennet definition do not exist.
- [ ] **Step 3: Implement `fighter_accessories.gd`** using small mesh accessories attached through `BoneAttachment3D`; optional accessories warn through the assembler result.
- [ ] **Step 4: Complete Bennet’s definition** with the selected tailored outfit, bald/short-hair head choice, navy/cyan palette and kippa.
- [ ] **Step 5: Run the Bennet test and the Task 2 suite**; expect PASS.
- [ ] **Step 6: Commit or ledger** the reference-character task and test result.

### Task 4: Bind UAL animation libraries to the assembled skeleton

**Files:**
- Modify: `scripts/quaternius_motion.gd`
- Modify: `scripts/fighter_visual.gd`
- Modify: `scripts/fighter.gd`
- Test: `tests/test_fighter_visual_uses_quaternius.gd`
- Test: `tests/test_fighter_motion_integration.gd`

**Interfaces:**
- Consumes: `RiggedFighterVisual.build()` and its returned `skeleton`.
- Produces: `QuaterniusMotion.bind(target_skeleton: Skeleton3D, bone_map: Dictionary) -> void`; existing `play_state(state: String, restart := false, target_duration := 0.0) -> void` remains stable.

- [ ] **Step 1: Update the motion tests first** to require animation tracks on the returned character skeleton, full-assembly facing, hit-stop pause/resume and no mannequin mesh.
- [ ] **Step 2: Run both tests**; expect failure because `QuaterniusMotion` still creates and displays its own mannequin.
- [ ] **Step 3: Refactor `QuaterniusMotion`** to load animation libraries only, retarget/bind tracks through the bone map and animate the assembler’s skeleton.
- [ ] **Step 4: Refactor `FighterVisual.build()`** to return the assembled rig and remove hidden sprite construction, face regions and mannequin creation.
- [ ] **Step 5: Adjust `fighter.gd`** to address visual state through the motion/root interface instead of `_visual.sprite` transforms.
- [ ] **Step 6: Run both focused tests**; expect PASS for walk, jab, cross, hook, hit, knockdown, get-up, facing and hit-stop.
- [ ] **Step 7: Commit or ledger** the animation-binding task and test result.

### Task 5: Define Avigdor, Bibi and Yair Golan

**Files:**
- Modify: `scripts/character_visual_catalog.gd`
- Modify: `scripts/fighter_accessories.gd`
- Test: `tests/test_character_visual_identities.gd`

**Interfaces:**
- Consumes: the reference model and animation interface from Tasks 2–4.
- Produces: complete visual definitions for `avigdor`, `bibi` and `yair_golan`.

- [ ] **Step 1: Write `test_character_visual_identities.gd`** asserting the exact palette/accessory rules from the spec: Avigdor charcoal/burgundy with gray hair/beard, Bibi navy/blue/gold with silver hair, Yair olive with gray hair/stubble and 3D sunglasses.
- [ ] **Step 2: Run the test**; expect failure because the three complete definitions are absent.
- [ ] **Step 3: Add Avigdor’s definition and accessories**, run only his assertions, expect PASS.
- [ ] **Step 4: Add Bibi’s definition and accessories**, run only his assertions, expect PASS.
- [ ] **Step 5: Add Yair’s definition and accessories**, run only his assertions, expect PASS.
- [ ] **Step 6: Run the complete identity and assembler suites**; expect PASS with unique materials and no billboards.
- [ ] **Step 7: Commit or ledger** the roster expansion and test result.

### Task 6: Visual, performance and project verification

**Files:**
- Modify: `README.md`
- Modify: `docs/combat-quality-plan.md`
- Create: `tests/test_character_render_budget.gd`
- Create: `output/rigged-character-review/` screenshots

**Interfaces:**
- Consumes: all four final assembled fighters.
- Produces: verified desktop/mobile presentation, documented asset/license pipeline and review images.

- [ ] **Step 1: Write `test_character_render_budget.gd`** asserting each fighter stays under 50,000 visible triangles, eight material surfaces and four active skinned meshes in combat.
- [ ] **Step 2: Run the budget test**; expect failure for any unoptimized assembly.
- [ ] **Step 3: Reduce duplicate/hidden surfaces and materials** until the budget test passes without removing identity accessories.
- [ ] **Step 4: Capture 1280×720 and phone-landscape images** for idle, walk, jab, hook, hit, fall and get-up against at least two arenas; verify floor contact, attachment stability, facing and framing.
- [ ] **Step 5: Run all Godot script tests**, the headless editor import and a main-scene smoke run; expect zero project parse/runtime failures.
- [ ] **Step 6: Update README and combat documentation** with the final model pipeline, controls, CC0 sources and known stylistic limits.
- [ ] **Step 7: Commit or ledger** final verification commands, results and any remaining visual limitations.
