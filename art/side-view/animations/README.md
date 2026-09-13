# Telos animation workflow

## Shared actor calibration (2026-09-08 correction)

Runtime animations now use one reference-pose scale and source-canvas ground anchor per actor, authored in `prototype/scripts/game/side_view_visual_config.gd`. Clip-specific `union_crop` translates that source pivot into each atlas cell. Do not scale clips independently by maximum motion bounds, and do not move each frame according to its alpha bounding box. Those bounds use left/top/right/bottom coordinates, not x/y/width/height. Facing and size changes must be recalculated from immutable values around the pivot.

For standalone Godot exports, `package --reference-height N` uses the same reviewed source-pixel reference height across every clip. Pair it with the same source `--anchor X Y` and intended `--height` for the actor. Current hero calibration is `--reference-height 416 --anchor 288 496 --height 80`. Use fresh output directories when changing package settings. Without this option the exporter still provides a clip-fitting preview scale; do not use that scale to assemble a multi-animation actor. The automatic `run` package remains a preview; repackage its masters with shared calibration for standalone final exports.

All clips in an actor family must originate from the same canvas/framing. Different source sizing requires explicit calibration or re-preparation. Current harvester uses its own larger-source calibration (557-pixel reference height and anchor 384,638); it must not inherit the hero's 576-canvas coordinates. Existing archived generation receipts and atlases remain unchanged.

The improved pipeline is **reference → H3 lossless masters → sampled transparent frames → review → Godot visual**. The existing `Asset animation` workflow and live game are preserved. Use the new `Telos_Animation` folder in ComfyUI (refresh the workflow list if necessary).

## ComfyUI presets

- `01_idle.json`: planted feet, subtle breathing and one claw flex, return to rest.
- `02_walk.json`: one in-place stride, clear weight transfer, no net travel.
- `03_attack.json`: one anticipation/strike/recovery, return to rest; export without looping.
- `04_frame_cutout.json`: single-frame transparent cutout for inspection. The runner repeats this stage over selected frames.

Editable native files and corresponding `.api.json` graphs live in `workflows/`. They retain the installed MiniMax H3 model, Qwen encoder, video/audio VAEs, `res_multistep` sampler, 15 steps and fixed seed. The new graphs connect both first and last references, use a padded 576×576 canvas, and save **every decoded image as PNG** alongside an MP4 preview. Audio stays in the preview only. Defaults produce 73 frames at 24 fps (about 3.04 seconds); H3 frame counts are rounded upward to its supported `17k + 5` length.

Both image selectors initially use the prepared breaker. Change **both** selectors when changing actors. First/last conditioning encourages a return pose; it does not guarantee a seamless loop. H3 prompts are currently creature-oriented; adapt anatomy/action wording for heroes or harvesters in `tools/animation_pipeline/workflows.py` before building their presets.

## Recommended end-to-end use

Run these commands from the repository root in PowerShell. ComfyUI must be running at the URL in `tools/asset_pipeline/config.json`; dependencies use its configured Python. Output directories must be inside this repository.

The breaker reference is already prepared. To generate and package a new idle:

```powershell
.\animation.ps1 run --reference art/side-view/animations/references/breaker/reference.png --motion idle --out art/side-view/animations/runs/breaker-idle-01
```

Replace `idle` with `walk` or `attack` and choose a new output folder. This submits a GPU generation job, downloads full-resolution PNG masters, samples at 12 fps, removes backgrounds, and exports a review package. `--to generate` stops after masters for early review. `--seconds`, `--seed`, and `--height` control duration, reproducibility and suggested in-game display height (112 by default). Same command/settings resume saved work; changed settings require a fresh folder. Interrupting polling does not cancel the GPU job. The pipeline won't silently resubmit an uncertain or failed job.

For another transparent sprite:

```powershell
.\animation.ps1 reference --image prototype/assets/side-view/breaker.png --out art/side-view/animations/references/breaker-v2
```

Review `reference.png` and `reference.json`: framing uses 70% width / 72% height with a bottom-center anchor at 86% canvas height. Check the actual planted feet. First/last references must share this exact scale, placement and canvas; do not independently crop a different last pose. `run --last PATH` accepts a separately prepared matching endpoint.

## Existing MP4 or ComfyUI PNG outputs

```powershell
.\animation.ps1 package --source art/side-view/animations/breaker_animation.mp4 --out art/side-view/animations/breaker-package-02 --fps 12 --anchor 288 550 --height 112 --motion idle --loop
```

The anchor above is for the **old full-size breaker video**, not the newly padded reference. New reference ground anchor is `288 495`.

`--source` also accepts a directory of zero-padded PNG masters with `--source-fps 24`. Use a directory containing only the frames from one take, in filename order. `--start` and `--end` select source frame indices, with end exclusive; trim duplicate endpoint holds or bad frames after reviewing motion. Sampling selects nearest frames without interpolation. Final frame duration preserves the selected source duration. MP4 fallback decodes all frames and rejects variable cadence; PNG masters avoid video compression damage.

## Review and correction

Inspect `preview.gif`, `contact-sheet.png`, `review.json` and individual `masks/NNNN/rgba.png`. Review feet, claws, anatomy, clipping, silhouette scale, edge flicker, the loop seam and timing **at actual game display size**. Alpha-area jumps and first/last difference generate heuristic warnings; a quiet report is not artistic approval. The original breaker take is a pipeline pilot, not a validated walk or attack.

Every selected frame uses one union crop, one scale and one ground anchor. There is no per-frame recentering, automatic motion removal, mask smoothing or crossfade that could hide a bad strike. If unwanted camera/root drift remains, supply `--shifts corrections.json`: an array of `[dx, dy]` pixel translations, one per selected frame. Choose these by review, preserving intentional body motion.

For manual mask cleanup, copy the selected RGBA images to a separate directory as `frame_0000.png`, `frame_0002.png`, etc., using **source indices**. Keep the full source canvas. Run `package` into a fresh folder with `--masks PATH`; this uses the corrected alpha instead of GPU segmentation and records their hashes. Do not edit archived masks/masters in place. Per-frame segmentation remains a fallback, so difficult clips may need this cleanup.

## Bring an approved result into Godot

Copy the complete generated `godot/` directory into a dedicated animation folder under game assets. It contains:

- `atlas.png`: full-resolution RGBA cells with consistent framing.
- `animation.tres`: SpriteFrames resource with sampled cadence, durations and loop setting.
- `visual.tscn`: AnimatedSprite2D child with a shared ground pivot and suggested scale.
- `manifest.json`: source indices, framing, timing and review metrics.

Instance `visual.tscn` beneath the actor's existing movement/collision node. Its origin is the ground anchor. Merge approved idle/walk/attack resources into the actor's animation controller as a separate implementation task. Game simulation continues to own movement, collision and damage timing; video frames do not define hitboxes or damage events. No game integration is performed by this pipeline.

## Maintenance and validation

Rebuild native/API presets with `animation.ps1 build --reference PATH`. Its reference-upload receipt preserves the initial source; for a new actor prefer editing both selectors or retaining a separate copy of the workflows. Tests: run `tools/animation_pipeline/test_pipeline.py` with the configured Python. No new custom nodes or model downloads are required for the currently installed stack.
