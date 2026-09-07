# Broken Foundry — environment v1

## Texture pilot — v2

The game now instances `broken_foundry_v2.glb`. `broken_foundry_v2.blend` preserves an editable texture pass; v1 remains available unchanged. ComfyUI generated two 1024×1024 surface images in `textures/`, with submitted graphs and seed/job metadata alongside them.

Scope: all 49 concrete floor slabs and exactly one left-front pump housing at Blender coordinates (-18, -7, 1.7). Other pumps and buildings retain v1 materials. The 50 meshes have explicit UVs and embedded color textures. Concrete uses .94 roughness, paint .78; no normal/height maps are inferred from color. Portable glTF base-color factors tune the images for the bright current game lighting without changing global lights or game rules.

The concrete image is mapped once per slab with varied rotations; existing slab joints bound its repeats. The pump uses box-projected UVs. These generated images are not certified seamless texture scans. The visible pilot was inspected in Blender and Godot; final edge-specific wear, richer roughness maps and larger texture-library rollout remain future passes.

Rebuild v2 with `apply_texture_pass.py` in Blender background mode after the two texture PNGs exist. It reads v1, creates v2, packs the images into the .blend/GLB, renders `textured-preview.png` and `pump-texture-detail.png`, and writes a pilot manifest. Godot inspection uses `verify_foundry.gd -- --texture-pilot`, produces `godot-textured-preview.png`, and checks 50 imported textured meshes plus retained collision. No player profile is loaded by that inspection.

First static environment art pass for Mana Well. Created September 6, 2026.

## Outputs

- `concept-v1.png`: ComfyUI concept generated with the existing Krea 2 Turbo OVA pipeline.
- `comfy-workflow.json`: editable ComfyUI workflow; drag into ComfyUI to inspect/reuse.
- `comfy-api.json`: exact submitted graph; seed 9062026, eight Euler/simple steps, CFG 1.
- `broken_foundry_v1.blend`: editable Blender source with individual named meshes and a review camera.
- `blender-preview.png`: actual Blender render of the modeled environment.
- `../../prototype/assets/environment/broken_foundry_v1.glb`: portable Godot-ready scenery, instanced by main.tscn.

The concept is a design reference. The mesh is a procedural interpretation built in Blender, not an automatic image-to-3D reconstruction. Flat portable materials establish the palette; painted wear, richer surface textures, animated machinery and atmosphere are future art passes. Static scenery does not need an armature. Pumps remain separate named objects for later animation work.

## Integration

Blender meters; XY ground exported through glTF to Godot Y-up. The 28m square is open. Tall buildings, pressure vessels and supply pipes sit outside its perimeter. Thin floor markings and mana seams are cosmetic. Existing FloorBody, boundary bodies, hero, machine, camera and combat rules are retained. The previous solid floor mesh is hidden to display the slab floor; existing boundary meshes remain visible.

The source `.blend` stays outside `prototype/` to avoid requiring Blender auto-import for players. Godot loads the exported GLB. Remove the FoundryScenery instance and re-enable Floor visibility to revert the art pass.

## Rebuild

Run `build_foundry.py` through Blender's background Python mode from the repository root. It creates a fresh isolated scene, writes the GLB/source/preview, and does not connect to or modify an already-open Blender window. Blender 5.2.1 was used. Open the saved `.blend` manually in Blender when ready to edit it.

`generate_concept.py` reuses the existing PNG-embedded workflow and submits a new generation to local ComfyUI at port 8188; it is not needed to rebuild the mesh. This run's concept is copied into the repo. ComfyUI also retains its original output under Telos/BrokenFoundry.

The v1 mesh deliberately favors simple geometry and readable combat space. It is not intended as final painted-OVA asset quality.

## Verification

Blender background build completed and its render was inspected. Godot imported the GLB and rendered the actual main-scene camera at 1280×720; see `godot-preview.png`. `verify_foundry.gd` checked 333 imported meshes, no added collision bodies, hidden legacy floor mesh and unchanged 28m floor collision. The verification scene disables gameplay scripts before entering the tree, so it does not load player progress. No full combat playtest was performed for this scenery-only pass.

The Blender source has individual editable objects. Future optimization can merge static meshes by material in the export while retaining the editable source. The current preview also shows that final material/lighting work is still needed to approach the painted concept's finish.
