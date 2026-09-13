# World-map generation — M01/M02 delivery

**Update: the owner approved A — inland valley.** See [the implementation handoff](../../work/world-map/design-review.md) for exact asset/layout hashes. Luna should proceed with M04; the pre-approval delivery notes below remain historical evidence.

Three provisional **Broken Foundry** candidates are ready. Each has clean art and a separate nine-node overlay. Nothing is approved or integrated into the game. Stop here for design iteration; M03 and later work have not been executed.

| Candidate | Clean master | Route at 1280×720 | Design tradeoff |
|---|---|---|---|
| A — Inland valley | [Master](candidates/A_valley/master.png) | [Overlay](candidates/A_valley/overlay-1280.png) | Closest to the established ruined-valley theme; bridges and distant furnace give good scale. Route connectors still need final terrain-aware art direction. |
| B — Industrial coast | [Master](candidates/B_coast/master.png) | [Overlay](candidates/B_coast/overlay-1280.png) | Strong negative space and readable destination; may suit the later Drowned Works theme better than Act 1. |
| C — Excavation terraces | [Master](candidates/C_terraces/master.png) | [Overlay](candidates/C_terraces/overlay-1280.png) | Strong uphill destination and heavy industry; repeated circular pits can feel monotonous and terrain busier. |

The node sequence is 5 monster-only levels, 3 wells and a final boss. Shapes are preview semantics: circles = combat, squares = wells, diamond = boss. Markers have no live state. Their positions were adjusted per candidate after visual inspection; `layout.json` stores each revision and separate path polylines. Lines describe progression, not exact playable walking routes. No huge buttons are baked into the art.

## Installed workflows

In ComfyUI, refresh the workflow list and open **Telos_WorldMap**:

- `01_act_concept`: independent map generation, using editable WORLD, STYLE, GEOGRAPHY, COMPOSITION and THEME/exclusion blocks.
- `02_reference_revision`: actual image-to-image revision. LoadImage → ImageScale → VAEEncode → sampler latent input; denoise defaults to 0.55. The supplied reference is clean candidate A, not its overlay. This is latent image conditioning, not a semantic image-edit model or a guarantee of exact landmark preservation.

Each has a native `.json` and an API `.api.json` in `workflows/`. Native files were copied to the new ComfyUI folder without replacing other workflows. Both use the installed Krea2 turbo/Qwen baseline, 8 Euler/simple steps, CFG 1 and fixed seed. Concept dimensions are on EmptyLatentImage; revision dimensions are on ImageScale. Match the aspect ratio of the clean reference before revision. Lower denoise generally preserves more structure; compare actual results before relying on a setting.

SaveImage writes clean results beneath ComfyUI's `Telos/WorldMap/` output prefix. Never use a route overlay as a revision reference unless intentionally exploring baked UI artifacts. No model downloads, cloud services, custom-node installation or server restart were needed.

## Reproduce or extend

From repository-root PowerShell:

```powershell
$mapPython = (Get-Content tools/asset_pipeline/config.json -Raw | ConvertFrom-Json).python
& $mapPython tools/world_map/maps.py run --candidate A_valley --seed 9073101 --out art/world-map/candidates/A_valley
& $mapPython tools/world_map/maps.py prepare --out art/world-map/candidates/A_valley
```

Repeating a completed render verifies its source hash without submitting again. Incomplete renders retain their job ID and resume polling. Ctrl+C stops waiting, not the GPU job. Unknown submission outcomes are not blindly retried. A failed record requires inspecting history and choosing a fresh directory after fixing the cause. Do not run concurrent GPU generations.

For an owner-requested revision, choose a **new folder**:

```powershell
& $mapPython tools/world_map/maps.py run --candidate A_valley --seed 9073111 --reference art/world-map/candidates/A_valley/source.png --denoise 0.55 --out art/world-map/revisions/A-02
& $mapPython tools/world_map/maps.py prepare --out art/world-map/revisions/A-02
```

Edit `prompt-blocks.json` before the new run to describe the requested changes. Saved takes retain their API graph and prompt hash. Existing completed outputs must not be reused for changed prompts/settings. The runner keeps generation at 1536×864. `prepare` uniformly resamples to 2048×1152 using Lanczos without cropping/stretching; the larger file contains no newly generated detail.

For another act, copy the draft manifest into a new authored revision with new act/node/well/encounter IDs and theme, keep its exact 3/5/1 count, and create its own geography prompt block. The current CLI's named candidates are Act 1 examples; extend the candidate registry in `tools/world_map/maps.py` or use a copied native workflow with edited blocks. Do not silently overwrite the Act 1 authoring files. Prepare the new act's overlay using its own `layout.json`; `prepare` preserves an existing layout rather than replacing it with the default.

Workflow rebuild (preserves original generation takes, refreshes the two authored workflow files):

```powershell
& $mapPython tools/world_map/maps.py build --reference art/world-map/candidates/A_valley/source.png
```

Rebuilding repository workflows does not automatically update installed copies. Install only the two native files into `Telos_WorldMap` with required filesystem permissions. Source helpers are imported from the existing asset pipeline, not edited.

## Files and verification

- `brief.md`: art direction, scale/display contract, route and runtime audit.
- `act_01.draft.json`: validated nine-node draft, sequential prerequisites and boss gate.
- `prompt-blocks.json`: reusable editable generation blocks.
- `layout-sketch.png`: pre-generation deterministic route sketch.
- Each candidate: original `source.png`, `master.png`, `overlay.png`, `overlay-1280.png`, `layout.json`, `api.json`, `job.json`, Comfy history and `preparation.json` hashes/resampling provenance.
- `VALIDATION.md`: actual checks, generation receipts and remaining limitations.

Run `tools/world_map/test_maps.py` with the configured Python for the contract/reference-wiring regression tests. The graphs were checked against installed schemas and actual concept runs succeeded. The reference revision graph was structurally validated; a revision generation has **not** been run in this initial three-concept batch.
