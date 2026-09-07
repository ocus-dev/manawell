# S01 — Isolated project and side-view movement

Read the queue, `prototype/project.godot`, `prototype/data/balance.gd`, `prototype/scripts/model/run_state.gd`, `prototype/scripts/game/player.gd`, and the current runner only as needed. No predecessor.

## Implement

Create `experiments/side-view-defense/` with a project.godot, main scene, scripts, tests, README, and local ignore rules for generated caches/logs. Give it a unique application/user-data identity even though saving is disabled. Use the installed Godot version. Add `experiments/README.md` explaining launch paths and which project is the preserved baseline.

Create the fixed logical canvas, floor, machine placeholder/service walkway, bounded horizontal hero movement, facing indicator, and visible controls legend. Wire normalized signed horizontal input; simultaneous left/right cancels. Set up one fixed-step owner and a named spatial conversion constant. Minimal movement in the shell is allowed before S02 adds encounter phase gating. Copy the pure model/balance dependencies required for S02, documenting provenance; no 3D actor/controller preloads.

Add a focused local test runner or adapt the existing runner into this project with correct project-relative paths, timeouts, and failure diagnostics. Record a content inventory/hash of prototype source files before/after the experiment work, excluding generated caches/logs, to establish no source modifications.

## Acceptance

- Experiment imports and boots independently; no 3D or external project resource dependencies.
- Horizontal movement speed, canceling input, bounds, and default/last facing behave as specified.
- Uniform scaling preserves the full arena at 1280×720 and 1920×1080; visual inspection can remain explicitly pending until S03.
- Focused tests pass, source baseline is unchanged, and README has exact editor/run/test commands.

Stop before combat, artwork production, or touching `prototype/`.

## Completion note

Completed 2026-09-06.

- Created the standalone project at `experiments/side-view-defense/` with a unique `user://telos_side_view_defense_experiment` identity and no `res://` references outside the experiment.
- Copied the pure `Balance` constants and `RunState` model locally. The 3D player script was read for behavior only and was not copied. Provenance hashes and the exact inventory command are recorded in `experiments/side-view-defense/README.md`.
- Added the 1280x720 fixed-camera procedural arena, central harvester placeholder/service walkway, bounded horizontal movement, facing indicator, and visible Start/Harvest, Retry, and Pause/Resume controls. The named spatial conversion is `SPATIAL_PIXELS_PER_UNIT = 32.0`.
- Added `tests/movement_test.gd` and `run_tests.ps1` with project-relative paths, captured diagnostics, and a 30-second timeout.

Actual checks:

- `Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe --headless --path experiments/side-view-defense --editor --quit`: passed project import and script registration.
- `Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe --headless --path experiments/side-view-defense --quit-after 1`: passed main-scene headless boot.
- `experiments/side-view-defense/run_tests.ps1 -GodotPath Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe`: passed `movement_test.gd`; Godot reported only headless CanvasItem/ObjectDB leak warnings on test exit.
- Prototype source inventory: 101 files, aggregate SHA-256 `cb9302330a55a5a4b740c305a3cb04e057048d1e9cac2e10d2ec3e1f11384f1a` both before and after this work.

Visual inspection at 1280x720 and 1920x1080 was not performed in this headless pass and remains pending for S03. Combat, enemy roles, extraction lifecycle, and playtest conclusions were not implemented or claimed. S02 is the next task after this prerequisite.
