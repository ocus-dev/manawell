# V04 — Build and exercise environment ComfyUI workflows

Read the queue's environment brief, V03 handoff, `art/side-view/README.md`, `tools/asset_pipeline/side_view.py`, shared concept/UI templates, and relevant palette/environment sections of the visual bible. Inspect the completed actor slice and existing foundry references. Earlier elevated 3D courtyard concepts are style references only, not the side-view camera target.

## Implement

Add reusable native UI and API workflow pairs for **07_environment_backdrop**, **08_environment_lane**, and **09_environment_dressing**. Reuse the installed Krea/Qwen/OVA baseline and editable world/render/subject/composition/finish prompt blocks. Preserve existing 01–06 workflows and tests; extending the builder must not reset customized installed presets. Save repository workflows under `art/side-view/workflows/`, and install only the new native graphs under ComfyUI's `Telos_SideView` folder when permissions allow. If installation is restricted, finish the repository files and provide the concrete install request rather than changing tools or bypassing permissions.

Backdrop: strict level side-on wide foundry setting, clear central machine area, low-contrast distance, no actors/machine/UI/lettering, no dramatic foreground occlusion. Lane: worn concrete/metal deck material with broad quiet surfaces, no painted fake holes or obstacles, no strong baked shadows; do not promise seamless tiling. Dressing: one fully visible isolated low industrial prop with ample margin, opaque neutral background for the existing cutout stage. Match material family, palette and lighting across all three.

Extend the existing resumable runner and structural workflow checks for new preset IDs and differing dimensions; remove any hard-coded six-workflow count rather than weakening checks. Record seeds, graphs, job IDs and original outputs. Run GPU jobs serially. Generate one image per new preset and, only if composition/readability fails, at most two additional backdrop candidates. Do not regenerate actors. Keep all outputs and record failures; no unbounded exploration.

Create a deterministic composition review overlaying the existing actual-size hero, harvester and enemies over each backdrop, marking y=540 and the entry zones. A provisional simple lane overlay is allowed for this review; the prepared lane is V05. Inspect the result for camera consistency and actor/background contrast. Select a provisional candidate with a short reason and document alternatives; owner feedback is optional, not a gate for completing this card.

## Acceptance

- Three new editable UI/API pairs with valid link/parameter mappings and installed node/model compatibility.
- Backdrop, lane-material and dressing generation runs complete or exact blockers are recorded. No cloud/model downloads.
- At least one reviewed 16:9 composition includes all existing actor roles at game scale and identifies a usable provisional backdrop.
- Update `art/side-view/README.md` with new workflow names, inputs/outputs and commands; preserve earlier validation as history.

Stop before importing scenery into gameplay.

## Completion note

DONE. Extended `tools/asset_pipeline/side_view.py` with reusable 07 backdrop, 08 lane, and 09 dressing API/UI pairs using the installed Krea/Qwen/OVA nodes. The builder now preserves existing 01–06 pairs and supports preset-specific dimensions; `test_side_view.py` discovers pairs dynamically and verifies all nine. Native 07–09 graphs were installed under ComfyUI `Telos_SideView`. Serial local runs completed with seeds 9072107–9072109 and recorded API graphs, job IDs, histories, and original outputs under `art/side-view/environment/`. Added `review_environment.py`, which composites the five existing actor sprites at game scale with y=540 and entry-zone guides. The backdrop candidate is provisionally selected because it keeps the central machine area and both entries readable; its strong lower retaining wall/pipework is documented as a V05 constraint. Evidence is in `work/playtests/environment-workflows.md`. No actors were regenerated and no gameplay/scenery import was performed.
