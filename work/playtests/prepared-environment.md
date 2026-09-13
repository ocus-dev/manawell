# V05 prepared environment evidence

Status: prepared static layers; gameplay integration intentionally not started.

## Runtime-local outputs

- [Prepared backdrop](../../prototype/assets/side-view/environment/backdrop.png): 1280x720 opaque plate.
- [Prepared lane](../../prototype/assets/side-view/environment/lane.png): 1280x180 opaque non-tiling strip placed at logical `[0, 540]`.
- [Environment manifest](../../prototype/assets/side-view/environment/environment-manifest.json): source/output hashes, transforms, bounds, draw order, filtering, alpha expectations, visual configuration, actor contract, and omission rationale.

The selected 1536x864 V04 backdrop is resized exactly to 1280x720. Its competing painted retaining-wall edge is covered from y=414 through y=539 with a deterministic crop of the selected lane material; the actual lane layer starts at y=540 and covers through the bottom. No perspective warp or inferred depth layer was used. The lane source is centrally cropped `[0,148,1536,364]` and resized to 1280x180, with a four-pixel authored top trim.

## Review images

- [Prepared composition](../../art/side-view/environment/reviews/v05-prepared-composition.png): actors at the unchanged V03 visible heights.
- [Debug baseline and entries](../../art/side-view/environment/reviews/v05-prepared-debug.png): y=540 line, x=96/x=1184 entry guides, labels, and dressing omission.

The five actors remain readable and the harvester area is open. The lower material is intentionally quiet; the V04 dressing prop was omitted because the backdrop already has strong pipework near the combat lane and the prop would compete with feet or warnings. The opaque V04 dressing source remains preserved and was not sent through 06_cutout.

## Checks

```powershell
$python = 'D:\\Create\\comfy_ui\\ComfyUI_windows_portable\\python_embeded\\python.exe'
& $python tools/asset_pipeline/prepare_environment.py --prepare
& $python tools/asset_pipeline/tests/test_prepare_environment.py
```

The focused checks verify output dimensions, manifest references and hashes, exact lane placement/top edge, opaque backdrop/lane alpha, omitted dressing, and 1280x720 review outputs. No game scene, actor transform, collision, save, or gameplay asset reference was changed.