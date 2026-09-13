# Shared implementation contracts

These are the tested interfaces and guarantees of the current prototype. Historical assignment notes remain in `work/assignments/`.

The active product is the native Godot 2D side-view prototype in `prototype/`: one fixed horizontal ground lane, a 1280x720 logical canvas, procedural industrial visuals, and no jumping, elevation, camera orbit, or scrolling. `experiments/side-view-defense/` is frozen historical evidence, and `archive/prototype-3d/` is the self-contained original runtime; neither is loaded by the active project.

## Ownership

- `RunState` owns extraction phases, pause state, timing, damage, sealing, and terminal results.
- `AccountState` owns bank, upgrades, unlocks, assignments, loadouts, run sequence, and `complete_run()`.
- `ContentCatalog` owns well, hero, upgrade, and authored surge definitions.
- `CampaignCatalog` owns authored act/node definitions; `CampaignState` owns mutable node completion, act unlocks, active node identity, terminal commit IDs, and derived node/well view state.
- `ProductionAccounting` calculates passive rates and settles elapsed income.
- `SessionPersistence` owns injected clocks, the UTC high-water mark, one save envelope, dirty state, and `retry_pending_save()`.
- `SaveStore` validates version 5 envelopes while reading older versions and protects live, temporary, backup, and recovery files.
- `EncounterController` owns the 60 Hz scheduler, scene orchestration, commands, and terminal integration.
- `EncounterHUD` renders read-only view state and emits semantic ID commands; it does not save or mutate models.
- `CampaignMap` renders read-only campaign view state, transforms normalized layout coordinates through the contained image rectangle, and emits `node_selected(act_id, node_id)` / `node_activate(act_id, node_id)` without deciding progression or mutating saves.
- Stateful actors and projectiles own `capture_snapshot_state()` and `restore_snapshot_state()`.

## Commands and IDs

Stable IDs are `well_1`, `well_2`, `hero_1`, `hero_2`, `damage_1`, `pump_1`, `spread_1`, `standard`, `overdrive`, and `fortified`. Controller commands accept IDs: `select_well_by_id`, `select_loadout_by_id`, `select_active_hero_by_id`, `assign_guard_by_id`, and `recall_guard_by_well_id`. They enforce phase, unlock, affordability, and assignment legality before mutation or persistence.

`RunState` phases are `READY`, `EXTRACTING`, `SEALING`, `SUCCESS`, and `FAILED`; pause is orthogonal. The fixed-step order is queued input, player movement/abilities, weapon and hostile actors/projectiles, damage, extraction/sealing advancement, then terminal resolution. Lethal damage wins a seal-boundary tie. `EncounterController.tick(delta)` delegates to this scheduler for tests.

`AccountState.complete_run(result, expected_run_id, well_id, completed_surges)` validates the active identity and applies payout/commissioning once. The persisted `run_sequence` and bounded `committed_run_id` provide idempotence for the single active run; unsafe legacy identities reject the active snapshot while preserving banked progress.

`CampaignState.start_node(act_id, node_id)` and `commit_terminal_result(result, account)` are the semantic campaign commands. Commits accept only successful results, require a commissioning surge for well nodes, delegate rewards to `AccountState.complete_run`, record each run ID once, complete the node, and unlock the next authored act after a boss. `node_status()` returns locked, available, or completed with a prerequisite-derived reason; completed nodes remain revisitable. `well_status()` derives commissioned, guarded, producing, active, and idle from account assignments and the active encounter. Hover, focus, and selection are transient view state and are not persisted.

The map view is exposed under `view_state["campaign"]` with authored nodes, prerequisite-derived statuses, route paths, and derived well indicators/rates. M05 activation is intentionally disabled until M06 supplies real encounter routing.

## Production and persistence

Only commissioned, guarded, non-active wells produce. The effective rate is well output × pump factor × guard factor × `0.20`; fractional income stays in memory until explicit transitions or the five-second checkpoint. Passive settlement uses an injected monotonic clock. Offline settlement uses the saved UTC watermark, clamps elapsed time to 24 hours, grants zero on backward time, and preserves the later watermark.

`SessionPersistence.build_envelope(snapshot)` writes account, `production_utc_timestamp`, and optional snapshot through `SaveStore.save_envelope()`. Failed writes retain the dirty account/snapshot for `retry_pending_save()` without replaying a purchase or reward. A crash may roll back to the latest committed checkpoint.

`SaveStore.get_load_result()` returns `fresh`, `loaded`, `recovered`, `unsupported`, or `corrupt` and exposes `writes_allowed`. It checks a valid backup when live is missing, preserves rejected live bytes at `.recovery`, validates before replacement, and blocks automatic writes for unsupported or unrecoverable data. `clear_save()` is the explicit reset path.

## Snapshots and verification

Snapshots validate types, known kinds, references, finite values, required hero/machine records, and unique IDs before scene mutation. Component records include actor/projectile state, weapon configuration and cooldown, attack windups, abilities, spawn state, and world-space projectile motion. IDs come from the persisted monotonic `spawner.next_id`; incomplete legacy component state is rejected rather than defaulted.

The PowerShell runner `prototype/run_tests.ps1` requires a Godot console path, supports `-TestFilter`, captures per-test logs, enforces a timeout, and fails on nonzero exits or failure diagnostics. Tests use isolated fixtures and never the real player profile. Headless tests cover model and integration behavior; manual runtime checks remain required for controls, collision, camera, focus, readability, and visual interaction.

