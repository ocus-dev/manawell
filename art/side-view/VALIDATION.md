# Workflow validation — 2026-09-07

- Built six native/API workflow pairs from the existing OVA Krea graph and installed them under `ComfyUI/user/default/workflows/Telos_SideView` on this workstation.
- Validated required node classes and configured model names against the running local ComfyUI server (0.31.0).
- `tools/asset_pipeline/tests/test_side_view.py` passed native/API link consistency, node types, prompt values, fixed seeds, and dimensions for all six pairs.
- Hero and harvester pilot generations completed; the hero background-removal pipeline completed end to end. PIL inspection confirmed RGBA output with alpha range 0–255 and corner alpha 0. No 3D mesh stage ran.
- Initial enemy pilots exposed manufactured armor leaking from the world prompt. The installed enemy presets now use an organic material block with the same OVA renderer. Initial robotic-looking variants remain under `pilots/03_enemy_pursuer`, `04_enemy_breaker`, and `05_enemy_ranged` as historical evidence, not current suggested designs. Revised runs use `-biological` directory suffixes.
- All three revised biological enemy presets completed successfully and were visually inspected. The ranged pilot has a distinct elevated snout and long-legged silhouette; its airborne-looking rear limb still needs pose review before use as an idle sprite.

Visual review: the hero, harvester, and revised pursuer/breaker are complete recognizable silhouettes with a coherent cel-painted treatment. The model does not reliably obey the requested 12% margin or strict side elevation (especially the breaker, which turns toward camera). These are pilot design stills, not approved final sprites or animation frames. Review camera consistency, simplify dark limb shadows, and normalize visible subject size before an in-game trial. Segmentation still needs per-asset edge review; only the hero cutout has been executed in this validation pass.

The workflow library uses local cached models and did not change the game's scene, collision sizes, or save data. Native graph files were structurally checked; browser-based interactive editing was not separately exercised.
