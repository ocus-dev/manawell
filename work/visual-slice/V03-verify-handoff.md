# V03 — Verify the playable visual slice and hand off for review

Read the queue and V01/V02 handoffs; existing startup-layout repair evidence, relevant tests, and current `prototype/README.md`.

## Implement

Run the complete active test suite once. Fix visual-integration regressions in scope; do not remove behavioral assertions to accommodate an art change. Check clean import with no missing textures or references outside the active project. Verify saved/resumed encounters reconstruct the same visual role/facing without serializing decorative animation state.

Capture actual rendered Godot viewport images at 1280×720 and 1920×1080: comparison lineup, an encounter containing all enemy roles, hero in front of the harvester, ranged warning/projectile, and startup operations. Reuse the existing Godot render-capture approach from `tests/operations_layout_test.gd` where helpful. Use isolated fixtures for repeatable states; screenshots must come from real visual components. Inspect leg grounding, masking edges, asset proportions, text overlap, health bars, warnings, and muzzle alignment. Do not claim native screenshots are unavailable without checking the existing working capture path.

Perform or clearly document pending interactive checks: move/facing both ways, dash, pulse, machine crossing, firing, damage, sealing, pause/resume, and retry. A fixture capture is not evidence of human input feel. Fix concrete layout/anchor/draw-order issues; keep subjective design decisions in the owner feedback list.

Write `work/playtests/static-sprite-slice.md` with selected assets and known pose limitations, final visual sizes/anchors, actual tests and screenshot links, short game/preview launch commands, the owner's five-step review from the queue, and a compact feedback table (asset, size, pose, readability, requested revision). Record this as a playable static-art trial, not final sprite/animation approval. Update the active README with preview instructions and the new art paths. Preserve card 57's historical status; reference new evidence without claiming unrelated checks complete.

## Acceptance

- One playable extraction encounter with all five assets and a reusable comparison scene.
- Automated regression results and actual rendered evidence recorded; any remaining interactive checks explicit.
- No modified original images, archived projects, collision values or economic rules.
- The owner can launch the result and give concrete size/pose/readability feedback without reconstructing task history.

Stop after delivery. Owner review determines the next art revisions and eventual animation/collision work. Do not start those automatically.

## Completion note

DONE. Added `work/playtests/static-sprite-slice.md` with the selected asset paths, manifest heights/anchors, owner review steps, feedback table, native screenshot links, commands, and explicit manual gaps. Added the isolated `prototype/tests/static_sprite_capture_test.gd` fixture and captured the preview lineup, startup operations, and all-role encounter at 1280x720 and 1920x1080 using the native OpenGL console runner. Snapshot restore now refreshes hero visual facing and the persistence fixture verifies restored breaker role/facing. The complete active runner passed all 24 discovered tests. Headless capture is intentionally skipped because the dummy renderer has no viewport image. No source images, archived projects, collision values, balance rules, or animation were changed.
