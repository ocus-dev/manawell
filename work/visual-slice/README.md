# Static sprite visual slice — Luna and owner handoff

V01–V06 are complete. The owner's review now authorizes [compact combat UI and platforming, P01–P08](../platforming/README.md). Continue there; the no-platforming stop boundaries below remain historical scope for the completed visual slice, not a prohibition on the new queue. Card 57's outstanding full acceptance remains open.

## Luna execution prompt

Select GPT-5.6 Luna in task settings, then paste:

> Implement only work/visual-slice/V04-environment-workflows.md. Read work/visual-slice/README.md, the assigned card, and its predecessor handoff, then only the named resources needed. Use the existing local ComfyUI/Krea setup and the environment brief. Preserve completed sprites, gameplay, collision sizes, saves, and archived projects. Complete the card's checks, update its status row and completion note with actual paths/results and limitations, then stop. Do not execute later cards, regenerate actor concepts, spawn agents, or create additional tasks.

Replace the card path with V05, then V06 after predecessor completion. Do not rerun V01–V03, the full conversion queue, or the experiment.

| Card | Deliverable | Dependency | Status |
|---|---|---|---|
| [V01 — Prepare sprites](V01-prepare-sprites.md) | Five RGBA assets and reproducible manifest | Selected files below | DONE |
| [V02 — Integrate visuals](V02-integrate-sprites.md) | Generated sprites in real encounters and a comparison scene | V01 | DONE |
| [V03 — Verify and hand off](V03-verify-handoff.md) | Runtime evidence and an owner playtest guide | V02 | DONE |
| [V04 — Environment workflows](V04-environment-workflows.md) | ComfyUI presets, candidate generation, composition review | V03 | DONE |
| [V05 — Prepare environment layers](V05-prepare-environment.md) | Aligned backdrop, lane, optional dressing and manifest | V04 | DONE |
| [V06 — Integrate environment](V06-integrate-environment.md) | Environment in gameplay/preview with rendered evidence | V05 | DONE |

## Selected first-pass sources

Treat these as authorized trial assets. No additional approval is required to prepare and integrate them. They are not final animation designs. Paths are relative to the repository root.

| Role / asset ID | Source PNG | Existing cutout | Initial visible height |
|---|---|---|---|
| hero | `art/side-view/pilots/hero-01/result.png` | `art/side-view/pilots/hero-cutout-01/result.png` | 80 logical px |
| harvester | `art/side-view/pilots/02_harvester/result.png` | Generate via 06_cutout | 190 logical px |
| pursuer | `art/side-view/pilots/03_enemy_pursuer-biological/result.png` | Generate via 06_cutout | 58 logical px |
| breaker | `art/side-view/pilots/04_enemy_breaker-biological/result.png` | Generate via 06_cutout | 112 logical px |
| ranged | `art/side-view/pilots/05_enemy_ranged-biological/result.png` | Generate via 06_cutout | 90 logical px |

Use the `-biological` enemies, not the earlier mechanical-looking trials. Hero 1 and Hero 2 may share this one hero sprite for the slice; the same harvester may serve both wells. Keep existing labels/selection identity truthful. These heights are starting values, adjustable centrally during visual review. Do not alter health, movement, attack ranges, collision footprints, or balance to match them in this queue.

## What the owner does

1. **Before Luna starts:** no manual asset export is required. The files above already exist. Optionally review them and tell Luna a replacement path if you prefer a different design; otherwise use this set.
2. **During V01:** leave the existing ComfyUI server available at `http://127.0.0.1:8188`. Luna can run the four missing cutouts sequentially using the documented CLI. Avoid queueing another GPU-heavy job during that pass. If a cutout loses a limb or antenna, inspect the reported image; minor mask/edge cleanup is allowed in derived copies. A replacement design is a separate choice, not an automatic regeneration loop.
3. **After V02/V03:** open the comparison scene with the command Luna records. Judge all five designs at the actual 1280×720 game scale before zooming into image detail. Check grounded feet/base, relative size, left/right facing, hero visibility when crossing the machine, and whether enemy roles remain distinct.
4. **Play a run:** move both ways, dash through the machine, use pulse, let ranged enemies fire, harvest, and retry. Look for warnings obscured by art, shots visually detached from weapons, hit flashes that hide silhouettes, or artwork suggesting hits that do not happen. Report those mismatches; do not infer that collision should automatically equal the full painted silhouette.
5. **Give concrete feedback:** for example, "hero 15% larger; harvester height good but too wide; breaker needs a truer side profile; ranged feet float; keep pursuer." Identify which designs/proportions are accepted and which need revision.

V01–V03 produced the playable actor slice. The environment extension below is now authorized; after V06 stop for owner review before producing animation or changing collision sizes.

V06 produced the complete first environment slice: the prepared Broken Foundry backdrop and service lane are driven by one shared runtime component in gameplay and preview. Native captures cover both supported resolutions, startup UI, hero/machine overlap, and mixed combat with ranged warning/projectile feedback. The owner review is now the next action.

## Environment flow — what the owner does

1. Keep local ComfyUI available for V04 generation. The default brief is **Broken Foundry**, matching the existing industrial art direction; no new setting choice is required to start.
2. Review V04's scene composite with the existing five sprites overlaid at their actual game sizes. Judge the setting's scale, horizon, value contrast and open lane—not just the standalone background painting. Optionally name a preferred candidate; otherwise Luna uses the documented clearest candidate as a provisional choice and continues when assigned V05.
3. If generating alternatives yourself, open the new environment presets in ComfyUI, edit the subject/finish blocks and seed, and return the generated file path to Luna. Keep a level side-view camera and exclude heroes, enemies, the harvester, text and UI. Do not bake those into the background.
4. After V06, launch the same comparison scene and a real encounter. Inspect the entire left/right lane, machine crossing, ranged warnings, dark enemy silhouettes against scenery, and both supported resolutions. Report specifics such as "back wall too close," "pipes hide right-entry warning," or "floor feels too narrow."
5. Approve or request changes to the setting/proportions before any platforming, camera movement, collision redesign, or second biome is proposed.

## Environment brief and layer contract

- One fixed-camera Broken Foundry arena: worn concrete service deck, muted ochre industrial housings, charcoal pipes, distant gantries and cooling stacks, blue-grey ambient light, restrained upper-left illumination. Reuse the painted OVA rendering language. Keep background contrast/detail below the actors and bright attack indicators.
- Logical composition remains 1280×720, ground y=540, machine x=640, hero lane x=96…1184. Scenery implies depth and scale without adding playable height. The skyline should not imply a new tilted/isometric floor plane.
- **Backdrop:** one opaque 16:9 plate containing distant sky, foundry architecture, and static rear infrastructure. This first pass can combine distant/midground structures; no unnecessary parallax separation.
- **Service lane:** a separate deterministic horizontal deck/foreground strip aligned exactly to y=540. Generate a texture/material source, then prepare the strip with controlled geometry and perspective. Do not rely on generation to put a floor edge at a precise pixel row.
- **Optional edge dressing:** up to two isolated cutouts (pipe housing, cable bundle, or low scrap cluster). Default placement stays outside x=96…1184 or below the gameplay lane. Omit these if they obscure actors or warnings; no tall foreground silhouettes over combat.
- Suggested source sizes: 1536×864 backdrop, 1536×512 lane material, 1024×1024 isolated dressing. These are generation canvases, not world dimensions. Record actual resize/crop transforms; preserve backdrop aspect ratio and use a documented crop/letterbox choice rather than stretching it.
- Draw order: backdrop/rear structures, lane, harvester, actors, small foreground dressing where safe, combat warnings/feedback, HUD. Keep a visible service walkway in front of the machine. No scrolling, parallax implementation, animated weather, new hazards, or environment collision in this slice.
- Environment source outputs live under `art/side-view/environment/`; prepared runtime files live under `prototype/assets/side-view/environment/`. One shared environment component must drive preview and gameplay. The existing procedural environment remains only an explicit debug fallback, never a second overlapping default scene.

## Shared implementation rules

- Active destination: `prototype/assets/side-view/`. Keep original generation outputs and both reference projects unchanged. No runtime dependency on `art/`, `experiments/`, or `archive/`.
- V01–V03 used existing ComfyUI `06_cutout` and local Python/Pillow for deterministic preparation. V04–V06 additionally authorize local environment generation with the installed Krea model and deterministic layer compositing. No actor regeneration, upscaling service, model install, mesh generation, or paid API.
- Preserve one common ground anchor. Crop by alpha bounds with a small transparent safety border; measure visible height, not the original square canvas. Record the crop origin and explicit foot/base anchor. The ranged creature's raised leg is not the ground anchor.
- Reuse the original high-resolution cutout; render smaller in Godot with suitable filtering. Do not repeatedly resample or destructively overwrite source images. Preserve aspect ratio.
- Sprite transforms are presentation only. Mirror a visual child for facing; never flip/scale the actor root, simulation coordinates, hitboxes, or health bar text. Separate visual recoil/motion from the ground anchor.
- Keep damage flashes, enemy health, ranged windup, entry warnings, dash/pulse, machine extraction/sealing, and harvest feedback visible. Remove only the procedural body drawings replaced by sprites. Keep the industrial environment and service walkway.
- The new sprite preview must share the same visual scenes/configuration as gameplay. No second combat implementation. No gameplay simulation or persistence in the preview by default.
- Test with persistence disabled or isolated fixtures. Never use the user's live save for verification. Preserve passing startup UI layout tests and record missing manual checks honestly.
- Status values: TODO, IN PROGRESS, DONE, BLOCKED. Completion notes should list changed files, actual checks and any remaining issue in roughly 150 words.
