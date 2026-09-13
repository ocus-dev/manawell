# 50 — Promote the approved side-view arena

Status: tracked in work/2d/README.md. Dependency: 49.

## Read

Queue and 49 handoff; experiment README, `scripts/main.gd`, `scripts/hero.gd`, enemy/projectile scripts, scene, and focused tests; active model/UI dependencies and test matrix. Refer to archived source as needed.

## Implement

After verifying the archive, replace the active 3D scene and combat scripts with the promoted side-view experiment. Remove active 3D-only scenes, models, materials, imports, and actor implementations whose complete originals are archived. Keep shared model/UI files and their actual dependencies. Remove dangling preloads and obsolete global classes; do not leave broken scripts for the editor to discover. Stage affected integration tests outside active discovery in `work/2d/deferred-tests/`, with exact paths and owning cards in the matrix. Preserve their originals in the archive.

Promote the experiment's existing scene, procedural artwork, horizontal hero, and working combat code into the active project's conventional paths. Preserve its current playable loop while later cards replace the temporary controller/UI/model wiring; do not reduce it to a blank movement shell. Use the actual script-driven horizontal movement/bounds already present rather than imposing CharacterBody2D physics. Reconcile the copied experiment RunState and balance files with the canonical active model/data paths, recording any differences. Add no second RunState class or balance owner. Retain the experiment's 32 px/unit factor and logical layout as specified in the queue. Use a fresh 2D application/user-data identity; persistence is disabled until 55. Update README and launch links to identify prototype/ as the active side-view build and the experiment as frozen reference.

## Acceptance

- Active project imports and boots without 3D assets or archive references.
- Hero moves horizontally, cancels opposite input, clamps at lane bounds, faces/dashes correctly, and crosses the machine/enemies without body blocking; no vertical movement.
- Bootstrap and applicable model/UI tests pass; deferred coverage is explicitly enumerated, not reported as passing.
- Archive manifest remains unchanged. No runtime `Node3D`, `CharacterBody3D`, camera orbit, or 3D actor scripts remain in active combat.

## Stop

Preserve promoted experiment combat; do not implement the later integration and repair cards here. Do not discard model/UI tests just because integration fixtures need conversion.

## Completion note

Completed 2026-09-07.

- Promoted the accepted side-view experiment into active `prototype/` paths: `scenes/main.tscn`, `scripts/game/encounter_controller.gd`, `player.gd`, `melee_enemy.gd`, `projectile.gd`, and `data/schedule.gd`. Canonical active `scripts/model/run_state.gd` and `data/balance.gd` remain the single model/data owners; promoted scripts were rebound to them.
- Active `prototype/project.godot` is now the side-view build with fresh `user://telos_side_view_defense_experiment` identity. The fixed 1280x720 scene, 32 px/unit scale, horizontal movement, bounds, facing, dash, nonblocking machine crossing, procedural combat, and current playable loop are preserved.
- Removed archived 3D-only active actors, scene, and asset trees. Staged 35 affected legacy test scripts and their UID sidecars at `work/2d/deferred-tests/`; exact paths, reasons, and owners are recorded in `work/2d/test-matrix.md`. The archive retains their originals.

Actual checks:

- Active runner: 10 applicable tests passed (`bootstrap`, model/data, UI view, and promoted movement coverage). The runner discovers only those 10 active scripts; 35 legacy scripts are deferred and not reported as passing.
- Active import: `Godot_v4.8-dev4_win64_console.exe --headless --editor --path prototype --quit` exited 0 with zero script/dependency diagnostics.
- Active headless boot: `--headless --path prototype --quit-after 2` exited 0.
- Archive manifest: 222 files, 0 differences from the frozen archive manifest. The side-view experiment manifest also remains unchanged.
- Authored active-file scan found no `Node3D`, `CharacterBody3D`, `MeshInstance3D`, `Camera3D`, archived asset preload, or deleted 3D actor preload.

Deferred tests are not reported as passing; persistence, semantic UI/controller integration, snapshots, and further 2D interface repair belong to cards 51-55. Native visual/input/focus checks remain pending for cards 56-57. No later card was implemented.
