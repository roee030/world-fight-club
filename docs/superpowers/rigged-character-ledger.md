# SDD ledger — plan: docs/superpowers/plans/2026-10-06-rigged-character-replacement.md

Setup: workspace is not a Git repository, so work proceeds in place and task completion is recorded here instead of commits.
Pre-flight: Task 1 produces asset-manifest.json; Task 2 consumes it — interface matches.
Pre-flight: Task 2 produces RiggedFighterVisual.build() and a skeleton; Tasks 3 and 4 consume them — interface matches.
Pre-flight: Task 3 produces FighterAccessories.attach(); Task 5 consumes the same accessory pipeline — interface matches.
Pre-flight: Task 4 produces the stable motion adapter; Tasks 5 and 6 consume completed animated fighters — interface matches.
Task 1: Ruling: use Universal Base Characters as the single character family and create project-owned 3D clothing — its skeleton exactly matches all 65 UAL bone names, while a second older modular rig would add retargeting risk; cost if wrong: clothing starts stylized and may need later mesh-art refinement.
Task 1: Complete — CC0 license, selected source files, manifest, audit tool, and exact 65-bone UAL compatibility verified.
Task 2: Complete — four data-driven rigged bodies build with validated bones, unique materials, ground shadows and no portrait sprites; focused test exited 0.
Task 3: Complete — Bennet reference body has a bone-driven navy/cyan suit, shoes and 3D Head-bone kippa; identity and assembler tests exited 0.
Task 4: Complete — UAL1/UAL2 libraries bind to the assembled skeleton without displaying their mannequin; motion and gameplay integration tests exited 0.
Task 5: Complete — Avigdor, Bibi and Yair have distinct bone-driven outfits, hair and accessories with no portrait billboards; roster identity test exited 0.
Task 6: Complete for automated verification — all seven focused Godot tests, editor import, main-scene smoke run and mobile/web render-budget test exited 0. Interactive screenshots remain a user-visible editor check because the sandbox renderer is headless.
Visual correction after user screenshot: removed all rigid capsule/box clothing from animated limb bones because their local axes produced detached floating parts. Replaced them with one continuous skinned body outfit material and compatible skinned hair meshes from the supplied pack; kept only small head-bone accessories.
Second visual correction: the material-only outfit left the base model visibly undressed. Added generated skinned outfit and shoe meshes filtered from the base body's weighted geometry, so clothes share every deformation with the body. Reversed the complete assembly facing mapping after the user's screenshot showed both fighters looking away from each other.
