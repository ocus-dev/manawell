# Architecture follow-up

Date: 2026-09-05

This report maps the seven findings in `architecture-review.md` to the current implementation and evidence. It does not claim that passing tests replaces manual runtime review.

## Findings

### 1. Save transaction, cadence, and clocks

Changed paths: `prototype/scripts/model/session_persistence.gd`, `prototype/scripts/model/save_store.gd`, `prototype/scripts/game/encounter_controller.gd`.

`SessionPersistence` is the single envelope/save boundary. It separates injected monotonic and UTC clocks, keeps fractional production in memory, checkpoints at five seconds, and retains failed dirty state for `retry_pending_save()`.

Evidence: `session_persistence_test.gd`, `checkpoint_retry_test.gd`, `offline_production_test.gd`, `network_production_test.gd`, and the full runner suite passed. Remaining limitation: an uncommitted crash can roll back to the last successful checkpoint.

### 2. Protected save recovery

Changed paths: `prototype/scripts/model/save_store.gd`, `prototype/tests/account_saves_test.gd`.

`SaveStore` exposes `fresh`, `loaded`, `recovered`, `unsupported`, and `corrupt` outcomes, checks backups, preserves rejected live bytes at `.recovery`, validates before replacement, and blocks writes when recovery is unsafe.

Evidence: `account_saves_test.gd` covers missing-live backup recovery, corrupt and unsupported sources, repeated writes, temporary/rename failures, and protected startup. It passed through the runner. Remaining limitation: local filesystem failure injection is representative, not a guarantee against every OS interruption mode.

### 3. Simulation ownership and order

Changed paths: `prototype/scripts/game/encounter_controller.gd`, `player.gd`, `melee_enemy.gd`, `ranged_enemy.gd`, `auto_weapon.gd`.

The controller owns one 60 Hz fixed-step scheduler; actor `simulate_tick()` methods no longer self-schedule. The tested order is input, movement/abilities, combat, damage, extraction/sealing, and terminal resolution.

Evidence: `single_scheduler_test.gd` and `recovery_equivalence_test.gd` cover seal-boundary damage, pause, dash ordering, and render-refresh invariance. Both passed in the full 31-test run. Remaining limitation: this is not deterministic networking or replay infrastructure.

### 4. Snapshot completeness and identity

Changed paths: `run_snapshot.gd`, `session_persistence.gd`, `encounter_controller.gd`, actor/projectile scripts, `account_state.gd`.

Components own capture/restore records. The snapshot includes upgraded weapon state, cooldowns, scaled enemies, abilities, all live projectiles, spawn state, and world-space positions. IDs use persisted monotonic allocation; malformed or incomplete state is rejected without discarding banked progress.

Evidence: `component_snapshot_test.gd`, `snapshot_validation_identity_test.gd`, `suspend_resume_test.gd`, and `recovery_equivalence_test.gd` passed. Remaining limitation: renderer-only transient effects are intentionally not persisted.

### 5. Test exit reliability and runtime-path coverage

Changed paths: `prototype/run_tests.ps1`, `prototype/tests/test_check.gd`, `prototype/tests/fixtures/`, and the architecture-specific tests.

The runner fails on nonzero exits, assertion/script diagnostics, and timeouts, while allowing only the expected malformed-JSON diagnostic. Fixture tests prove failure and timeout detection. The fresh journey uses production commands for progression, guarding, saving, restoring, resuming, and completion.

Evidence: the complete command below passed all 31 discovered tests. The isolated main-scene smoke command exited 0. Remaining limitation: headless coverage does not prove human control, visual readability, collision feel, or window-focus behavior.

### 6. HUD ownership and selection

Changed paths: `prototype/scripts/ui/encounter_hud.gd`, `prototype/scripts/game/encounter_controller.gd`, `prototype/tests/encounter_hud_test.gd`, `prototype/tests/domain_commands_test.gd`.

`EncounterHUD` receives read-only view state and emits semantic IDs. Controller commands enforce legality and persistence. Structural lists avoid unnecessary rebuilds and preserve selected IDs.

Evidence: `encounter_hud_test.gd` covers 120 refresh cycles and exact signal payloads; `domain_commands_test.gd` calls commands without widgets. Both passed. Manual dropdown/open-popup inspection remains pending.

### 7. Definitions, duplicate credit, IDs, and stale docs

Changed paths: `content_catalog.gd`, `account_state.gd`, `encounter_controller.gd`, `run_identity_credit_test.gd`, `prototype/README.md`, and `work/CONTRACTS.md`.

`ContentCatalog` owns definitions and authored surge data. `complete_run()` is the single completion command; `run_sequence` and `committed_run_id` replace unbounded new-save deduplication metadata, with guarded legacy migration. Final documentation now describes the current system rather than card-history status.

Evidence: `content_catalog_test.gd` and `run_identity_credit_test.gd` passed; the README stale-history scan passed; `git diff --check` passed. Remaining limitation: runtime content remains the authored two-well/two-hero catalog; external content loading is out of scope.

## Exact verification

From the repository root:

```powershell
$godot_console = 'C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& .\prototype\run_tests.ps1 -GodotPath $godot_console
```

Result: all 31 discovered tests passed with exit code 0. The runner captured the expected malformed-JSON diagnostic only for `account_saves_test.gd`.

Isolated application smoke check:

```powershell
$profile = Join-Path $env:TEMP 'telos-architecture-smoke-profile'
$env:GODOT_CONFIG_DIR = Join-Path $profile 'config'
$env:GODOT_DATA_DIR = Join-Path $profile 'data'
$env:GODOT_CACHE_DIR = Join-Path $profile 'cache'
& $godot_console --headless --path '.\prototype' --quit-after 5
```

Result: `SMOKE_EXIT=0`; no player save was written. Manual visual, input, collision, focus, export, stable-release, and balance checks remain pending. No gameplay systems or balance values were changed for this documentation pass.
