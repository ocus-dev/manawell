# 56 — Readable 2D presentation

Status: tracked in work/2d/README.md. Dependency: 55.

## Read

Queue and predecessor; current 2D arena/HUD; relevant palette/readability sections of design/visual-style-bible.md and design/Interface.md; work/reviews/ui-implementation-gap.md and card 48's outstanding checks.

## Implement

Preserve and refine the accepted experiment's procedural side-view industrial composition rather than building a new overhead arena. Integrate its large animated harvester, walkway, gantries/stacks, entry warnings, and role silhouettes with the existing operations/combat UI. Update draw-state ownership to avoid two HUDs or duplicate animation clocks. Resolve reported experiment CanvasItem/ObjectDB leak warnings by inspecting fixture teardown and actual ownership; do not merely suppress diagnostics. Use scoped rendering separation only where it improves testable ownership.

Finish a coherent placeholder presentation using existing resources and procedural 2D drawing: distinguish hero, machine, pursuer, breaker, ranged threat, friendly shots, hostile shots, windup, dash, and pulse through shape as well as color. Keep the industrial palette, clear floor/boundaries, ground contact, and restrained effects. Avoid unnecessary environmental obstruction.

Fit the fixed arena into the combat play area with uniform scaling at 1280×720 and 1920×1080. Keep essential health, machine integrity, pressure, abilities, harvest, and warnings visible without scrolling or covering critical play space. Retain operations/results/settings layouts and repair conversion-related regressions. Remove leftover 3D terminology and camera controls. Write a compact `work/2d/art-handoff.md` specifying intended sprite scale, anchor/ground contact, viewing angle, draw ordering, and a bounded future asset list; do not generate assets in this card.

## Acceptance

- Capture actual runtime screenshots at both target sizes where tooling permits; inspect clipping, HUD overlap, actor distinction, and telegraph visibility.
- Verify modal/focus/input behavior in combat and operations. Headless checks alone do not establish visual acceptance.
- Effects remain legible with reduced motion/settings and do not change simulation hit sizes.
- At both resolutions the entire left/right lane and entry warnings remain visible, the hero crossing the machine reads clearly, and Triple shot trails convey three shots without suggesting jump/elevation mechanics.
- Record unavailable visual checks as pending for 57, not passed.

## Stop

No painted arena production, asset generation/downloads, 3D-to-sprite pipeline, or new UI redesign.

## Completion note

Completed 2026-09-07.

- Preserved and refined the accepted procedural side-view presentation in the active project: animated central harvester, machinery/extraction feedback, service walkway, gantries/stacks, clear ground lane, role-specific silhouettes, entry/windup warnings, projectile colors, dash/pulse feedback, and machine damage flash.
- Kept one presentation path: the production HUD is the single HUD under `EncounterLayer`/`CanvasLayer`; the combat arena remains controller-owned and fixed-camera. The pressure widget now derives next-spawn timing from the same director state rather than maintaining a second clock.
- Removed stale S03 labeling from the active build and added `work/2d/art-handoff.md` with intended sprite scale, ground contact, side-on view, draw ordering, and bounded future asset list. No assets were generated, downloaded, or added.
- Added `prototype/tests/presentation_2d_test.gd` covering HUD ownership, operations/combat visibility, next-spawn readout, and pause overlay behavior. No simulation hit sizes were changed by presentation work.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4.exe\\Godot_v4.8-dev4_win64_console.exe`: all 20 active tests passed, including `presentation_2d_test.gd`.
- Headless runtime boot passed at `1280x720` and `1920x1080` with exit code 0.
- Active authored-code scan found no runtime `Node3D`, `CharacterBody3D`, `MeshInstance3D`, `Camera3D`, orbit, or zoom controls. Regenerated editor cache text is not runtime code.
- `get_errors` reported no errors for the active project.

Native screenshots at both resolutions and interactive GUI focus/input/readability walkthroughs were unavailable in the current tooling environment and remain pending for card 57. Headless results are not presented as visual acceptance evidence. The archived 3D project and accepted experiment remain unchanged.
