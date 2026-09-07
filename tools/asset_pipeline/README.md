# Local asset pipeline

For the active **2D side-view game**, use the new [hero, harvester, enemy, and cutout workflows](../../art/side-view/README.md). The mesh pipeline below remains available for the preserved 3D work; it is not required for sprites.

Run this from the Telos Game repository in PowerShell. It uses your installed ComfyUI, existing Krea concept workflow, TRELLIS.2, Blender and Godot. **Routine generation does not call Codex, an image API or a paid cloud service.** Once models are cached, generation runs on your GPU. Initial model/dependency downloads require internet access.

## First use

```powershell
.\assets.ps1 doctor
```

If ComfyUI is closed:

```powershell
.\assets.ps1 serve
```

Leave that terminal open and use another for generation. You can instead start your usual ComfyUI launcher. The pipeline never shuts down your running server. Its built-in launcher loads only TRELLIS2 and GeometryPack custom nodes; use your normal launcher for unrelated workflows. Only run one GPU-heavy pipeline at a time, including across multiple ComfyUI servers.

Copy `config.example.json` to `config.json` on each workstation, then set its executable paths, local server URLs, and ComfyUI output directory. `config.json` is machine-specific and intentionally ignored by Git. Concept and mesh stages default to the same server on port 8188. If you use a separate TRELLIS server, set `mesh_url` and ensure `comfy_output` matches **that** server. `serve` supports a single shared server; separate servers must be started manually. Each new run snapshots the config.

## Recommended workflow: two visual reviews

### 1. Create and review a concept

```powershell
.\assets.ps1 new coolant-pump --prompt "A compact industrial coolant pump with two chunky pipes and one cyan status light" --height 1.5 --triangles 12000 --seed 42 --to concept
```

The command prints a run ID such as `coolant-pump-20260906-120000-ab12cd`. Substitute **your printed ID** for `RUN_ID` below.

Open `art/generated/RUN_ID/concept.png`. The existing art style is retained; the composition is adapted to one isolated object with a neutral background. Accept a clear silhouette with the entire object visible. If it is wrong, create another run with a revised prompt or seed. No existing output is overwritten.

### 2. Generate and prepare the mesh

```powershell
.\assets.ps1 run RUN_ID --to prepare
```

This skips the completed concept, removes the background, generates a textured mesh, then runs Blender in background mode. Blender welds coincident vertices before reducing polygons, sets height and a bottom-center origin, corrects facing, preserves textures, and saves a GLB, editable Blend and review image.

Inspect `preview.png`, `prepared.blend` or `prepared.glb`, especially the rear, holes, thin parts, material seams and silhouette. `asset-report.json` records triangle counts, dimensions and textures. The default `--yaw 180` matches our tested TRELLIS-to-Godot orientation, but AI outputs can vary. Use another run with a different yaw if needed. The preparer assumes imported Z-up Blender geometry and scales by its vertical extent.

### 3. Import the accepted asset

```powershell
.\assets.ps1 run RUN_ID --to import
```

The pipeline creates and validates:

```text
prototype/assets/generated/RUN_ID/
  model.glb
  asset.tscn
```

Drag `asset.tscn` from Godot's FileSystem dock into your level. It is a visual-only scene: add a simple StaticBody3D and box/capsule collision if this object should block movement. For scenery outside the arena, collision usually isn't needed. Keep any edited scene as a separate game scene, or preserve it in place: the pipeline refuses to overwrite edited import outputs.

**Import means a usable Godot asset, not automatic placement or gameplay behavior.** No generated run edits `main.tscn`, player scripts, stats, save files or your open Blender scene. A fresh background Blender process is used, and imported source cameras/lights are excluded from the game GLB.

## One-command generation

Once you trust a prompt/style, skip the pauses:

```powershell
.\assets.ps1 new scrap-crate --prompt "One battered industrial steel storage crate with broad ochre panels and heavy dark corner braces" --height 1 --triangles 6000 --seed 123 --to import
```

This runs all four stages without further input. You should still inspect the result before using it in gameplay. It is not a guarantee of usable topology or artistic quality.

## Start from existing work

Use a concept you created yourself in ComfyUI (PNG):

```powershell
.\assets.ps1 new red-mecha --image concept_art/07_mecha_meshy_source_00002_.png --kind hero --height 1.8 --triangles 22000 --seed 42 --to prepare
```

Skip both AI stages with an existing or manually corrected static GLB:

```powershell
.\assets.ps1 new cleaned-mecha --glb art/mecha-trial/mecha_trellis2_512.glb --kind hero --height 1.8 --triangles 22000 --yaw 180 --to import
```

If you export a GLB that is already correctly oriented, use `--yaw 0`. `--kind hero` is a descriptive tag; it does not rig a character or attach it to the player. The preparer deliberately rejects armatures and active animation actions. Use Godot's normal importer for animated assets.

Other controls:

- `--finish "Red painted armor, charcoal joints, cyan visor"` changes finish/color guidance for new concepts.
- `--resolution 1024_cascade` requests higher TRELLIS detail. Start at 512; higher detail uses more memory and time.
- `--height` is the total height in metres, including protrusions such as antennas.
- `--triangles` is the preparation budget, 1,000–100,000. It does not make extra geometry when the source is already smaller.
- `--seed` is fixed across concept and mesh stages. Fixed seeds/settings improve repeatability, but different GPU/library versions may still change results.

## Experimental shape reference and geometry diagnostics

The pump study did **not** establish that clay Img2Img fixes holes. Treat it as an optional experiment, not a required production stage. Plain Img2Img can move parts; matching image dimensions does not prove matching silhouettes. It currently uses Krea VAE encoding and denoising, without edge/depth ControlNet constraints.

```powershell
.\assets.ps1 shape --image concept_art/my-concept.png --out art/shape-studies/my-asset --denoise 0.55
.\assets.ps1 new shape-test --image concept_art/my-concept.png --shape-image art/shape-studies/my-asset/clay.png --cleanup preserve-shell --audit-mesh --seed 42 --to prepare
```

Substitute your existing PNG. Review `clay.png` before the second command. Keep camera, framing, silhouette and component positions aligned with the original. `--prompt` can supply a complete transformation prompt. Repeat the same shape command to resume; use a new output directory for changed settings. The exact workflow and job history are saved beside the result.

`--shape-image` guides only geometry. The original `--image` still guides TRELLIS texture synthesis; this is regenerated appearance, not an exact pixel projection or a guaranteed restoration of the original design. Both conditioning branches share the original foreground mask/crop. A shifted silhouette can therefore be clipped or textured incorrectly.

Cleanup choices for **new** runs:

- `legacy` (unchanged default): existing remesh, inner-face removal and small-component filtering.
- `conservative`: diagnostic mode that disables remeshing, hole filling and component filtering. In this study it left severely fragmented surfaces; do not assume the name means better quality.
- `preserve-shell`: retains remeshing but disables inner-face removal and component filtering. It can retain interior/nonmanifold geometry and still needs inspection after simplification.

`--audit-mesh` also saves `before-cleanup.glb`, which can contain millions of triangles. `raw.glb` is after TRELLIS processing/texturing; `prepared.glb` is after Blender reduction. Diagnostic tools (run from the repo root):

```powershell
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/audit_mesh.py art/generated/RUN_ID
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/asset_pipeline/blender_review.py -- art/generated/RUN_ID
```

The audit requires the numpy/trimesh packages already installed in ComfyUI's Python. It welds UV/normal seam duplicates in normalized space before measuring boundaries. Boundary counts depend on tolerance; openings may be intentional, and zero boundaries does not establish a manifold mesh. The review renders opposite views in PBR and matte gray, plus a recomputed-normal comparison. It writes review PNGs without changing the saved Blend or GLB. View labels identify camera positions, not an inferred semantic front.

See [the pump study](../../art/shape-studies/pump-comparison.md) for results and exact run IDs.

## Resume, failures and provenance

```powershell
.\assets.ps1 status
.\assets.ps1 status RUN_ID
.\assets.ps1 run RUN_ID --to import
```

Every stage saves its exact API graph, prompt ID, history and output hashes in `art/generated/RUN_ID`. Completed stages are verified and skipped. Ctrl+C stops waiting, **not** ComfyUI generation; running the same command resumes polling. Timeout does the same. Use ComfyUI's queue controls to cancel an unwanted GPU job.

After a network interruption during submission, the runner searches ComfyUI queue/history using a unique job token. It will not silently submit again if the outcome is uncertain. If ComfyUI was restarted and lost both queue and history, inspect its output and start a new run, or use `--image`/`--glb` to continue from a saved artifact. A reported failed GPU job requires a new run after the underlying issue is fixed. This favors predictable costs over automatic rerolls.

The server must be idle for a new job; the pipeline releases its cached models between stages to make room for the next model family. It never cancels someone else's queued job. A local OS lock prevents simultaneous commands on the same run and is released automatically if the process exits.

Do not edit a run's manifest or completed outputs in place. Use a new run from an edited PNG or exported GLB. Changed artifacts and edited imported scenes are rejected rather than silently reused/replaced. JSON writes are atomic. Mesh discovery uses a unique per-job ComfyUI output directory and requires exactly one GLB, never the newest file from a shared folder.

## What needs a person—and when Codex is useful

| Step | Routine owner | Approach |
|---|---|---|
| Prompt, size and budget | You | Use short object descriptions and saved commands; no coding required. |
| Concept approval | You | Inspect the PNG; change seed/prompt if silhouette or framing is wrong. |
| Background removal, geometry, PBR textures | Pipeline | Existing local ComfyUI nodes. |
| Simplification, scale, pivot, export | Pipeline | Repeatable Blender script, no open-scene edits. |
| Mesh review | You | Rotate it in Blender; inspect the hidden side and thin parts. |
| Scenery placement/simple collision | You | Drag the generated scene into Godot; add simple shapes if needed. |
| Rigging, articulation, broken geometry | Artist or focused Codex task | Separate mechanical parts, repair joints, rig and animate after the design is accepted. These are not reliably solved by generation. |
| New gameplay integration | One focused Codex task per asset category | Build one reusable enemy/player/interactive-prop scene, then swap its visual child for future assets. |
| Workflow/model changes | Occasional Codex maintenance | Update the two JSON adapters and rerun the tests after intentionally upgrading ComfyUI/custom nodes. |

No stage intrinsically requires my touch. The practical limit is asset quality and integration with new behavior, not running the pipeline. Avoid paying for repeated assistant-driven exports or per-asset code edits: use static props first, and make reusable game scenes for categories with common behavior. Portrait generation, animation, automatic LOD chains and level layout are outside this first pipeline.

## Dependencies and maintenance

- ComfyUI concept template: `templates/concept.json`, copied from our working Krea 2 Turbo API graph. Style is in nodes 1/2, subject 3, composition 4, finish 5, seed 16, output 18. Requires the existing Krea/Qwen models already installed here.
- TRELLIS adapter: `templates/mesh.json`, copied from the successful local mecha trial. Requires `PozzettiAndrea/ComfyUI-TRELLIS2`, its GeometryPack dependency and their model downloads. Resolution is node 68; seed nodes 82/83; mesh output 86; conditioning image 101.
- Tested dependency fix from the mecha trial: host and isolated worker both need compatible Trimesh serialization; here they use 5.1.0. The wrapper uses comfy-env 0.3.89 and isolated PyTorch 2.8/cu128 while the host uses PyTorch 2.13/cu130. Avoid upgrading these casually.
- CLI: Python 3.10+ and `requests` (`requirements.txt`). This machine uses ComfyUI's embedded Python. No Node.js, web server, cloud API key or extra paid model is needed.
- Blender: tested installed 5.2.1 LTS. Godot: project executable 4.8-dev4. `doctor` checks paths, node presence and the concept model selections; it does not install dependencies or prove all GPU operations will work.

The templates are API-format graphs. To adopt a changed ComfyUI workflow, export API JSON and update `graph_for()` node bindings as needed. Keep the known-good templates until an end-to-end trial succeeds.

Run inexpensive regression checks without generating images:

```powershell
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/tests/test_pipeline.py
```

The first version intentionally has no browser UI. A local UI can later call these same stage functions and display the saved PNGs/status without changing the generation logic.

## Verified example

`art/generated/pipeline-pump-20260906-211723-a4bb48` completed all stages with a newly generated local Krea concept and TRELLIS mesh. Blender reduced 99,594 triangles to 11,999 at a height of 1.5 metres, retaining two 2K texture maps. Godot confirmed the generated scene loads. Repeating `run ... --to import` verified and skipped all four completed stages. Twelve non-GPU regression tests pass, including uncertain submission recovery, completed-job resume, failed-job evidence, busy-server handling, artifact changes and unmanaged destination protection.

The sample scene is `prototype/assets/generated/pipeline-pump-20260906-211723-a4bb48/asset.tscn`; it has not been placed in the level. Its inferred rear and shiny PBR interpretation differ from the concept. This illustrates why a mesh review remains useful even when the pipeline runs successfully.
