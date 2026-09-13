# Static sprite visual slice — V06 environment handoff

Status: complete first environment slice; owner review pending. This is not final sprite, animation, or collision approval.

## Selected assets

All five derived PNGs are in `prototype/assets/side-view/` and are mapped by `prototype/scripts/game/side_view_visual_config.gd`.

| Role | Derived PNG | Initial visible height | Ground anchor (source pixels) | Pose/readability note |
|---|---|---:|---:|---|
| Hero | `prototype/assets/side-view/hero.png` | 80 px | 296, 922 | Small silhouette; readable in the lineup and encounter |
| Harvester | `prototype/assets/side-view/harvester.png` | 190 px | 408, 697 | Large and wide; hero overlap remains visible |
| Pursuer | `prototype/assets/side-view/pursuer.png` | 58 px | 485, 541 | Low profile; distinct from the other enemies |
| Breaker | `prototype/assets/side-view/breaker.png` | 112 px | 443, 905 | Angled pose, not a strict side profile |
| Ranged | `prototype/assets/side-view/ranged.png` | 90 px | 399, 912 | Lifted leg; lowest planted foot is the anchor |

The manifest is `prototype/assets/side-view/side-view-assets.json`. Original images and archived projects were not modified. Collision, balance, save schema, and animation were not changed.

## Environment integration

The V05 selected Broken Foundry backdrop is used as the opaque 1280x720 rear layer. The prepared service lane is the opaque 1280x180 foreground layer positioned at `[0, 540]`, with its top edge exactly aligned to `GROUND_Y = 540`. Both layers are drawn by `SideViewEnvironmentVisual` and shared by gameplay and `side_view_visual_slice.tscn`; no preview-only transform or duplicate backdrop exists. The procedural scenery remains available only through the component's explicit `use_prepared_layers = false` fallback.

Native OpenGL runtime evidence from the active project:

- [Full comparison scene, 1280](static-sprite-slice/preview-lineup-1280.png)
- [Full comparison scene, 1920](static-sprite-slice/preview-lineup-1920.png)
- [Hero crossing machine, 1280](static-sprite-slice/encounter-hero-crossing-1280.png)
- [Hero crossing machine, 1920](static-sprite-slice/encounter-hero-crossing-1920.png)
- [Mixed combat and ranged warning, 1280](static-sprite-slice/encounter-all-roles-1280.png)
- [Mixed combat and ranged warning, 1920](static-sprite-slice/encounter-all-roles-1920.png)
- [Startup UI, 1280](static-sprite-slice/startup-operations-1280.png)
- [Startup UI, 1920](static-sprite-slice/startup-operations-1920.png)

Inspection: actors contact the service lane, both entry labels remain readable, the hero crosses the machine without changing simulation coordinates, and ranged health/warning/projectile feedback remains visible against the painted environment. HUD panels remain legible at both resolutions. Interactive input feel, persistence, and owner judgement of final scale remain manual checks; fixture screenshots do not prove those behaviors.

## Rendered actor evidence

These captures are native OpenGL captures from the active project, not headless screenshots. The original V03 evidence remains listed here for history:

- [Preview lineup, 1280](static-sprite-slice/preview-lineup-1280.png)
- [Preview lineup, 1920](static-sprite-slice/preview-lineup-1920.png)
- [Startup operations, 1280](static-sprite-slice/startup-operations-1280.png)
- [Startup operations, 1920](static-sprite-slice/startup-operations-1920.png)
- [Encounter, all roles, 1280](static-sprite-slice/encounter-all-roles-1280.png)
- [Encounter, all roles, 1920](static-sprite-slice/encounter-all-roles-1920.png)

Observed in the captures: all five silhouettes share the baseline, health bars remain above enemies, the hero and harvester overlap without hiding either role, and the ranged warning plus hostile projectile remain visible. The startup operations panel leaves a narrow art strip visible behind its translucent surface; this is recorded for review rather than changed in this slice.

## Checks and commands

V06-focused checks passed:

- `environment_visual_test.gd`: shared prepared resources, exact texture dimensions, fixed ground/machine coordinates, one environment per gameplay/preview owner, and no duplicate environment nodes.
- `static_sprite_capture_test.gd`: native OpenGL fixture rendered comparison, startup, hero-crossing, and mixed-combat states at both resolutions.

Historical V03 checks, retained for provenance:

- `persistence_2d_test.gd`: saved/resumed hero facing and breaker role/facing reconstruct correctly.
- `side_view_visual_test.gd`: role mapping, visual facing, unchanged actor transforms, scale, top, and anchor checks pass.
- `static_sprite_capture_test.gd` under `--headless`: exits cleanly with an explicit native-renderer skip.
- Existing targeted movement, weapons, surge, encounter, presentation, and UI checks passed during V03 validation.

Native capture command from the repository root:

```powershell
$godot = '.\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe'
& $godot --path '.\\prototype' --script 'res://tests/static_sprite_capture_test.gd'
```

Preview launch:

```powershell
& $godot --editor --path '.\\prototype'
```

Open `scenes/previews/side_view_visual_slice.tscn` and run the scene. The main game is `scenes/main.tscn`.

The complete active runner was rerun for V06 with persistence isolated: all 25 discovered tests passed. Fixtures do not use the user's live save.

V06 native capture command from the repository root:

```powershell
$godot = '.\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe'
& $godot --path '.\\prototype' --rendering-method gl_compatibility --script 'res://tests/static_sprite_capture_test.gd'
```

## Owner review

1. Open the comparison scene and judge all five designs at the actual 1280x720 game scale before zooming in.
2. Check grounded feet/base, relative size, left/right facing, and hero visibility while crossing the machine.
3. Play a run: move both ways, dash through the machine, use pulse, let ranged enemies fire, harvest, and retry.
4. Look for warnings obscured by art, shots detached from weapons, hit flashes hiding silhouettes, or painted poses implying hits that do not happen.
5. Give concrete feedback on accepted assets and revisions, using the table below.

| Asset | Size feedback | Pose feedback | Readability feedback | Requested revision |
|---|---|---|---|---|
| Hero | Review whether 80 px is large enough in motion | Side-facing silhouette is serviceable | Check visibility over machine overlap | Adjust scale only if it disappears during play |
| Harvester | Review width against hero and lane | Industrial silhouette reads | Check whether overlap obscures interaction cues | Consider narrower art only if it masks feedback |
| Pursuer | Review the 58 px low profile | Biological pose is distinct | Confirm it is readable during pressure | Keep or request a larger silhouette |
| Breaker | Review 112 px height | Angled pose is the known compromise | Confirm it reads as a separate role | Request a truer side profile if needed |
| Ranged | Review 90 px height | Raised leg is intentional | Confirm warning and muzzle remain legible | Request a planted-foot or muzzle revision if needed |

## Pending manual checks

Human input feel, both-way facing, dash, pulse timing, firing/muzzle alignment, damage feedback, sealing, pause/resume, retry, window focus, and final readability at native display scale remain pending owner review. Fixture captures prove repeatable presentation states, not interaction feel.

## Owner environment review

1. Judge the backdrop scale and service-lane width in the comparison and encounter captures at 1280x720 before reviewing 1920x1080.
2. Check whether lower pipework or retaining-wall forms compete with actor silhouettes, warnings, or projectile paths.
3. Play both wells and confirm labels remain truthful even though this first slice shares one environment.
4. Return concrete revision prompts for contrast, obstruction, floor contact, entry visibility, or HUD overlap before any second biome, weather, platform, or combat-tuning work.
