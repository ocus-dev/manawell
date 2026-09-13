# V04 environment workflow evidence

Status: V04 complete. This card builds and exercises source workflows only; scenery is not imported into gameplay.

## Workflow pairs

Repository pairs live in `art/side-view/workflows/` and the native UI graphs are installed under the local ComfyUI `Telos_SideView` folder.

| Preset | Canvas | Output contract | Seed |
|---|---:|---|---:|
| `07_environment_backdrop` | 1536x864 | Opaque 16:9 fixed-camera side-on foundry backdrop | 9072107 |
| `08_environment_lane` | 1536x512 | Worn concrete/metal service-deck material source; not promised seamless | 9072108 |
| `09_environment_dressing` | 1024x1024 | One isolated low pipe/cable service prop on neutral opaque background | 9072109 |

The builder preserves existing 01–06 repository and installed UI pairs when they already exist. Structural checks discover pairs dynamically rather than relying on a six-workflow count.

## Bounded local runs

All three jobs completed serially on the local ComfyUI server with the existing Krea/Qwen/OVA baseline. No cloud service, model download, actor regeneration, or 3D stage was used.

- Backdrop: `art/side-view/environment/07-backdrop-01/result.png`, job `556db6b3-8ea7-465f-bd19-289c91b4fa7a`
- Lane: `art/side-view/environment/08-lane-01/result.png`, job `8a1ef949-dfa4-45d7-862d-06263919bbcf`
- Dressing: `art/side-view/environment/09-dressing-01/result.png`, job `47f81cc9-f828-4166-8313-f3035921a85d`

Each run directory retains `api.json`, `job.json`, `generate-history.json`, and the original `result.png`.

## Composition review

[All-role backdrop review](../../art/side-view/environment/reviews/07-backdrop-01-composite.png) overlays the existing hero, pursuer, harvester, breaker, and ranged sprites at their V03 visible heights. It marks logical ground `y=540`, entry zones `x=96` and `x=1184`, and includes a provisional translucent lane overlay. The backdrop remains the provisional candidate because it keeps the center machine area open, preserves both entry zones, and gives all actor silhouettes readable separation against the blue-grey industrial architecture.

The lower retaining wall and large pipework are strong foreground shapes near the lane. This is acceptable for V04 review but is a constraint for V05: keep the prepared deck quiet and omit edge dressing if it competes with actor feet, warnings, or the harvester. No candidate reroll was needed under the bounded review rule.

## Commands

```powershell
$python = 'D:\\Create\\comfy_ui\\ComfyUI_windows_portable\\python_embeded\\python.exe'
& $python tools/asset_pipeline/side_view.py --build
& $python tools/asset_pipeline/side_view.py --run 07_environment_backdrop --out art/side-view/environment/07-backdrop-01
& $python tools/asset_pipeline/side_view.py --run 08_environment_lane --out art/side-view/environment/08-lane-01
& $python tools/asset_pipeline/side_view.py --run 09_environment_dressing --out art/side-view/environment/09-dressing-01
& $python tools/asset_pipeline/review_environment.py --backdrop art/side-view/environment/07-backdrop-01/result.png --out art/side-view/environment/reviews/07-backdrop-01-composite.png
& $python tools/asset_pipeline/tests/test_side_view.py
```

Native UI graphs can be refreshed in ComfyUI from `art/side-view/workflows/07_environment_backdrop.json`, `08_environment_lane.json`, and `09_environment_dressing.json`.
