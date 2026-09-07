# Telos side-view asset workflows

Nine editable ComfyUI workflows are installed under **Telos_SideView** in the local workflow sidebar. Refresh ComfyUI if the folder is not visible. Repository sources are in `workflows/`: open the plain `.json` files in ComfyUI; `.api.json` files are for scripted submission.

| Workflow | Purpose | Starting on-screen height at 1280×720 |
|---|---|---|
| 01_hero | Red industrial piloted mech, right-facing side profile | 80 px |
| 02_harvester | Ochre extraction machine, large stepped silhouette | 190 px |
| 03_enemy_pursuer | Low, lean organic runner | 58 px |
| 04_enemy_breaker | Heavy organic siege creature | 112 px |
| 05_enemy_ranged | Tall spitter with visible throat reservoir | 90 px |
| 06_cutout | Approved source image → foreground mask → transparent PNG | Original resolution |
| 07_environment_backdrop | Fixed-camera level side-on foundry background with quiet center and rear infrastructure | 1536x864 |
| 08_environment_lane | Worn concrete/metal service-deck material source; not promised seamless | 1536x512 |
| 09_environment_dressing | One isolated low pipe/cable service prop on neutral background for cutout | 1024x1024 |

These heights are visual starting points for comparison, not new collision sizes or gameplay balance. All generation presets use a 1024×1024 canvas and ask for complete silhouettes with generous margin. Actual subject bounds vary; scale the visible subject, not the full padded canvas. Anchor feet/base at bottom-center on the game's ground lane. Start with one idle still per role; animation sheets, separated moving parts, and final in-game import are subsequent work.

## Generate in ComfyUI

1. Open a preset. Edit **SUBJECT node 3** and **FINISH node 5** for variants. Keep RENDER and CAMERA/COMPOSITION consistent across the set. WORLD node 1 intentionally uses manufactured materials for friendly machines and biological materials for enemies; do not copy the steel/mechanism block into creature prompts.
2. Queue one image. Seed is fixed in node 16 for controlled comparisons; change it deliberately for another design. Outputs go to `ComfyUI/output/Telos/SideView/` with numbered filenames.
3. Review the full silhouette, strict side view, limb/weapon separation, and material language. A fixed seed does not guarantee identity across changed prompts. Independent generations are design variants, not consistent animation frames.
4. Open **06_cutout**, upload the approved PNG in LoadImage, change the SaveImage prefix to a useful asset name, and queue it. It uses the already-installed local TRELLIS BiRefNet background-removal node; no mesh is generated. The mask is inverted before JoinImageWithAlpha because that node expects transparency rather than foreground opacity.
5. Open **07_environment_backdrop**, **08_environment_lane**, or **09_environment_dressing** for the V04 layer sources. Edit SUBJECT node 3 and COMPOSITION node 4 only when changing the bounded layer brief; preserve the shared WORLD, RENDER, model, sampler, and seed conventions. Backdrop excludes actors/machine/UI, lane is a material source rather than a seamless tile, and dressing remains isolated on an opaque neutral background for 06_cutout.
5. Inspect alpha edges against light and dark backgrounds, especially antennae, legs, gaps, and gun barrels. The generation background is opaque grey; prompting alone does not create transparency. Cutouts retain original canvas dimensions and may need reviewed trimming/pivot adjustment before Godot import.

Shared model baseline: installed Krea 2 Turbo FP8, Qwen3VL Krea text encoder, Qwen image VAE, Euler/simple, 8 steps, CFG 1, batch 1. This reuses the existing OVA style workflow. No cloud image service, new model installation, or 3D stage is used.

## Repository runner

From the repository root in PowerShell:

```powershell
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --build
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --run 01_hero --out art/side-view/my-hero-01
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --run 06_cutout --image art/side-view/my-hero-01/result.png --out art/side-view/my-hero-cutout-01
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --run 07_environment_backdrop --out art/side-view/environment/07-backdrop-01
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --run 08_environment_lane --out art/side-view/environment/08-lane-01
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/side_view.py --run 09_environment_dressing --out art/side-view/environment/09-dressing-01
```

Create the V04 review composite without importing scenery into gameplay:

```powershell
& 'D:/Create/comfy_ui/ComfyUI_windows_portable/python_embeded/python.exe' tools/asset_pipeline/review_environment.py --backdrop art/side-view/environment/07-backdrop-01/result.png --out art/side-view/environment/reviews/07-backdrop-01-composite.png
```

`--build` validates installed nodes/model names and creates missing repository workflow pairs from the shared templates. Existing actor and cutout pairs are preserved; the V04 environment pairs are `07_environment_backdrop`, `08_environment_lane`, and `09_environment_dressing`. It does not overwrite installed sidebar copies. Preserve manual workflow edits under a new filename before rebuilding. Use one new output directory per design. Repeating a run command resumes its saved job rather than submitting another generation; completed runs are left alone. API graph, job ID and server history accompany each result. Stopping the runner does not cancel the GPU job. Do not run multiple heavy generation jobs simultaneously.

V04 evidence, original outputs, job metadata, and the provisional all-role backdrop review are recorded in `work/playtests/environment-workflows.md`. This work intentionally puts the visual slice ahead of combat tuning. No game scenes, mechanics, or saved profiles are changed by these workflows.
