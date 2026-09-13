# V01 — Prepare the five selected sprites

Read the queue, `art/side-view/README.md`, `art/side-view/VALIDATION.md`, and `tools/asset_pipeline/side_view.py`. Inspect the selected source images and hero cutout before processing. No predecessor.

## Implement

Reuse the hero cutout. Run the other four selected sources through the existing local `06_cutout` workflow one at a time, using new descriptive directories under `art/side-view/prepared/`. Use the runner's saved job IDs for resume; do not queue duplicate jobs after a timeout. If ComfyUI is unavailable, report the exact connection/tooling problem and do not silently switch services.

Create a small reproducible preparation utility under `tools/asset_pipeline/` that verifies RGBA, finds meaningful alpha bounds, trims transparent margins with a documented threshold and safety padding, and writes derived PNGs under `prototype/assets/side-view/`. Keep soft edge alpha in output: the threshold determines bounds, not a destructive binary mask. Refuse fully transparent/opaque failed cutouts and never silently overwrite edited outputs. Allow an explicit reviewed ground anchor override per asset.

Write an asset manifest alongside the prepared sprites with asset ID, source path/hash, cutout path/hash, derived PNG/hash, original dimensions, crop rectangle, visible bounds, ground anchor, right-facing convention, and initial visible height from the queue. Note the breaker's angled pose and ranged creature's lifted leg as known source characteristics. Do not attempt to "repair" their anatomy automatically.

Make a light/dark/checkerboard review sheet using deterministic compositing, including both native-resolution edge crops and all five assets at their proposed relative display sizes on a common baseline. This sheet is for review, not the in-game texture. Inspect masks for missing extremities, grey fringe, filled gaps, disconnected noise, and opaque background residue. Minor manual/deterministic edge cleanup may be saved as a separate derived step with provenance; stop and report serious segmentation failure rather than importing a damaged sprite.

## Acceptance

- Five nonempty transparent RGBA PNGs, with preserved proportions and complete meaningful silhouettes; no source overwritten.
- Manifest values reproduce preparation and reference existing files/hashes.
- Meaningful checks cover transparent/opaque failures, bounds/padding, and anchor transformation through cropping, using small synthetic fixtures.
- Review sheet inspected; any aesthetic limitations are documented, not mislabeled final art.

Stop before changing game actors or adding animation.

## Completion note

DONE. Added `tools/asset_pipeline/prepare_side_view.py` and focused synthetic coverage in `tools/asset_pipeline/tests/test_prepare_side_view.py`. The utility uses alpha threshold 8 and four-pixel transparent padding, preserves soft alpha, records the crop and transformed ground anchor, refuses fully transparent/opaque inputs, and refuses to overwrite derived files or manifests. The four required local `06_cutout` jobs completed serially: harvester `6c5ef11c-9876-4e15-bab2-e10f49d85c25`, pursuer `a6eb4b8e-0240-4dad-b8f2-e2dc96a6144f`, breaker `b13c35e8-cbf3-4a32-b3ba-87cb650f8313`, and ranged `5191258a-2607-496d-aeaf-ff1fa84299fb`. Five derived RGBA sprites are under `prototype/assets/side-view/`; `side-view-assets.json` contains hashes, dimensions, bounds, anchors, display heights, and source notes. `art/side-view/prepared/review-sheet.png` was inspected on light, dark, and checkerboard backgrounds. Checks passed: 3 focused tests, 19 asset-pipeline tests, side-view workflow integrity, alpha audit, and `git diff --check`. Limitations remain documented: the breaker is angled rather than strict side profile, and the ranged creature has a lifted leg. No game actors or animation were changed.
