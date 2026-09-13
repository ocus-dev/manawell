# 51 — Encounter lifecycle and existing interface

Status: tracked in work/2d/README.md. Dependency: 50.

## Read

Queue and predecessor; archived encounter controller; active RunState, AccountState, UI view state, encounter HUD, presentation router, and lifecycle/input tests.

## Implement

Replace the promoted experiment's standalone controller/UI wiring with the established production ownership, retaining its rendering and actor behavior. There must be one fixed-step owner and one HUD after this card. Remove the temporary session-only result owner: account completion owns payout. Move input-edge collection outside simulation substeps so E starts from READY and each press produces at most one command. Consolidate duplicate pause/started flags around RunState and the presenter. Do not blindly copy the experiment's `_physics_process` or `simulate_step` scheduling.

Adapt the controller's existing lifecycle, scheduler, command boundary, and HUD binding to the 2D shell. Restore start, extraction, harvest, sealing, success/failure, retry, abandon, pause, and results. Use the existing account completion command for exactly-once payout. Retain the fixed-step order and input queue; actors must not independently advance combat. Restore the current operations interface and semantic commands using existing owners; advanced progression integration is verified in 54. No copied economy rules in widgets.

Restore ordinary hero movement through the scheduler. Remove obsolete orbit/zoom settings and their handlers from active UI. Keep UI input consumption, focus handling, and modal blocking. Persistence remains explicitly disabled; do not call incomplete snapshot code or advertise durable saving during this milestone.

## Acceptance

- Start → accumulate → seal → success banks once; failure/abandon loses only the active tank.
- Pause freezes encounter time and movement; retry resets transient state.
- Damage wins a sealing-boundary tie using an injected damage fixture.
- UI clicks and modals do not trigger gameplay accidentally; E works from READY as well as EXTRACTING, and start/harvest keyboard/buttons reach the same commands. A multi-step frame consumes a pressed edge once. Window focus loss does not leave movement stuck.
- Restore the corresponding lifecycle, scheduler, and UI integration tests from the matrix.

## Stop

No enemy AI, polished artwork, or save migration.

## Completion note

Completed 2026-09-07.

- Replaced the experiment-only session presentation path with the active production `EncounterHUD` and `UiViewState` binding while retaining the promoted 2D renderer and actor behavior. The active controller now owns one fixed-step scheduler and one HUD.
- Added canonical `AccountState` ownership for run IDs and successful payout via `complete_run`, with duplicate terminal credit prevented by the account contract. Failure and abandon do not credit the active tank. Persistence remains disabled and no snapshot/save path is called.
- Added semantic controller commands for start/harvest, retry, return to operations, abandon, pause/resume, and HUD action endpoints. Input edges are collected in `_unhandled_input` and consumed once in `_apply_pending_commands`, so E starts from READY and a multi-step simulation cannot repeat a press.
- Consolidated live pause state around `RunState.paused`; retry clears enemies, projectiles, cooldowns, wave clock, queued input, and presentation state. The active HUD handles operations, pause confirmation, results, modal blocking, and click routing.
- Restored `encounter_test.gd`, `pause_results_test.gd`, and `runtime_click_routing_test.gd` from deferred discovery; exact remaining deferred paths and later owners remain in `work/2d/test-matrix.md`.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: all 13 active tests passed, including lifecycle/account credit, pause/results, runtime click routing, movement, model/data, UI view, and bootstrap coverage.
- Active headless boot with `--headless --path prototype --quit-after 2`: exit code 0 with no script diagnostics.
- Active authored-file scan: no `Node3D`, `CharacterBody3D`, `MeshInstance3D`, `Camera3D`, orbit/zoom handler, archived asset preload, or deleted 3D actor preload remains.
- Frozen archive manifest: 222 files, zero differences. The accepted side-view experiment remains unchanged.

Remaining deferred tests are not reported as passing. Persistence, progression, production integration, snapshot/recovery, and additional UI restoration belong to cards 52-55; native visual/input/focus checks remain for cards 56-57. No enemy AI or polished artwork was added in this card.
