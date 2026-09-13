# V05 — Prepare aligned environment layers

Read the queue, V04 handoff and selected composition, existing sprite preparation utility/manifest, and the current scene's lane dimensions.

## Implement

Prepare the chosen backdrop, lane, and optional dressing into `prototype/assets/side-view/environment/` with a reproducible utility and manifest. Preserve the original generation outputs. Backdrop remains opaque; do not run a full environment painting through subject segmentation or try to infer hidden depth layers from it.

Build a straight service-deck strip whose top edge lands exactly on logical y=540 when placed in the scene. Use the lane material source through deterministic crop/compositing and simple authored trim/edge geometry; avoid arbitrary perspective warping that makes the floor appear climbable. Remove/cover a competing painted ground edge in the backdrop where needed using the lane layer, documenting the transform. No procedural changes to actor positions or collisions. A single non-tiling strip is sufficient at the fixed camera width.

Run isolated dressing through 06_cutout only if it improves the reviewed scene. Inspect alpha against light/dark backgrounds and preserve soft edges. Limit to two placements outside critical combat visibility; omit dressing rather than masking warnings. Save scene-level tint/contrast choices as reversible configuration, not repeated lossy image edits.

Manifest: source/output hashes and paths, original/prepared sizes, crop/resize transform, layer type, logical placement/bounds, draw order, filtering, alpha expectation, and rationale for any omitted prop. Include a prepared composition at 1280×720 with the actual actors and a debug baseline/entry-zone version for review.

## Acceptance

- All layers have explicit logical alignment and runtime-local paths; backdrop opacity and dressing alpha verified.
- Floor edge is at y=540, spans the visible lane, and has no unintended seam or second floating ground plane.
- Existing actor anchors and sprite sizes are unchanged. The central machine area and both entries remain readable.
- Preparation checks cover output dimensions, manifest references, and placement transforms; inspect the composed result visually.

Stop before game integration; no new environment generation except resuming V04's recorded jobs.

## Completion note

DONE. Added `tools/asset_pipeline/prepare_environment.py` and focused checks in `tools/asset_pipeline/tests/test_prepare_environment.py`. The selected V04 backdrop is prepared at 1280x720; the lane source is centrally cropped and resized to a 1280x180 opaque strip whose top edge is exactly logical y=540. A deterministic lane-material riser covers the backdrop's competing retaining-wall edge from y=414 to y=539 without perspective warping, then the lane begins at y=540. The optional dressing is intentionally omitted because the selected composition already has strong lower pipework and the prop would compete with actor feet and warnings; its source remains preserved and was not sent through 06_cutout. The manifest records hashes, transforms, bounds, draw order, filtering, alpha expectations, reversible tint/contrast settings, actor-height contract, reviews, and omission rationale. Prepared and debug 1280x720 reviews were inspected with all five unchanged actors and both entry zones. Evidence: `work/playtests/prepared-environment.md`. No gameplay integration or actor/collision changes were made.
