# Telos prototype

Godot project for the Windows desktop prototype. The current scene contains the arena, controllable hero, extraction encounter flow, surge director, melee and ranged threats, automatic weapon, and HUD.

## Verified toolchain

- Godot: `4.8.dev4.official.b56a91878`
- Editor: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe`
- Console runner: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe`

The executable directory is kept outside the project. This is a development build; use a stable Godot 4 release before shipping.

## Run the project

From the repository root in PowerShell:

```powershell
$godot = 'C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe'
& $godot --editor --path '.\prototype'
```

To run the main scene without opening the editor:

```powershell
& $godot --path '.\prototype'
```

The game uses keyboard controls: `WASD` moves, `E` starts extraction or harvests, `Space` dashes, `Q` uses the defensive pulse, and `Escape` pauses or resumes. The HUD exposes the same actions plus preparation, assignment, upgrade, network, retry, abandon, and save-reset controls. Purchases, guard assignments, well selection, and loadout selection are available outside active combat only.

The runtime save is `user://account_save.json`; its temporary and last-good files are `user://account_save.tmp` and `user://account_save.bak`. The **ACCOUNT > Clear saved progress** action removes all three and restores a fresh Well 1/Hero 1 account. Headless tests disable runtime persistence and use separate injected fixture paths, so they do not modify the real profile.

Run snapshots use schema v3. `Hero`, `AutoWeapon`, `MeleeEnemy`, `RangedEnemy`, `Projectile`, and `RangedProjectile` expose explicit `capture_snapshot_state()` and `restore_snapshot_state()` methods. The controller assembles actor and component records, restores known kinds through their owners, and stores projectile positions in world space (local position is used only for detached fixtures). Legacy snapshots missing v3 component or weapon state are rejected rather than silently upgraded into inexact recovery.

`recovery_equivalence_test.gd` drives uninterrupted and save/reload/resume encounters through the same fixed-step scheduler and compares combat state, stable IDs, in-flight projectiles, sealing, payout, and failed-checkpoint retention.

The encounter HUD lives in `scripts/ui/encounter_hud.gd`. It emits semantic ID commands and receives read-only view state; controller commands remain responsible for legality, production settlement, persistence, and account mutations.

Runtime content definitions are centralized in `scripts/model/content_catalog.gd`. The catalog supplies well output and modifiers, hero and upgrade IDs, and authored surge composition rules. Account validation can receive an injected catalog for tests; the runtime uses the default two-well/two-hero catalog.

Run identity is account-owned: `AccountState.allocate_run_id()` advances the persisted sequence, and `complete_run()` validates the active identity before applying payout and commissioning exactly once. Legacy generated IDs migrate into the sequence; unsafe arbitrary legacy IDs preserve banked progress and reject active snapshots with a recovery diagnostic. The focused coverage is in `tests/run_identity_credit_test.gd`.

## Run the headless bootstrap test

```powershell
$godot_console = 'C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& $godot_console --headless --path '.\prototype' --script 'res://tests/bootstrap_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Bootstrap test failed with exit code $LASTEXITCODE" }
```

The test must exit with code `0`. It checks the project name and main scene path without touching a player save.

## Run the test suite

From the repository root in PowerShell, provide the console executable explicitly:

```powershell
$godot_console = '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& .\prototype\run_tests.ps1 -GodotPath $godot_console
```

Use `-TestFilter name` to run one test or an isolated fixture. The runner captures a log per test, enforces a 30-second timeout, and rejects nonzero exits, parse errors, assertions, and `SCRIPT ERROR` diagnostics. The malformed-JSON diagnostic in `account_saves_test.gd` is the only allowed diagnostic. Failure and timeout fixtures live under `tests/fixtures/` and are excluded from ordinary discovery.

## Run the arena movement test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/arena_movement_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Arena movement test failed with exit code $LASTEXITCODE" }
```

This checks normalized diagonal movement, reserved input actions, and the arena collision node structure. Use the editor or the game window for manual control and readability checks.

## Run the extraction state test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/run_state_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Extraction state test failed with exit code $LASTEXITCODE" }
```

The scene-independent model is `res://scripts/model/run_state.gd`; tunable extraction values are in `res://data/balance.gd`. `RunState` exposes `start`, `advance`, `request_harvest`, `apply_damage`, `abandon`, `reset`, and `get_terminal_result`. The caller must apply combat damage before calling `advance` on each gameplay tick so lethal damage wins ties with sealing completion.

## Run the encounter integration test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/encounter_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Encounter test failed with exit code $LASTEXITCODE" }
```

The encounter controller is `res://scripts/game/encounter_controller.gd`. In the running game, `E` or the HUD button starts/harvests, `Escape` pauses/resumes, and `Retry` or `Abandon run` controls terminal encounters. The two `DEV:` buttons apply damage directly to the hero or machine as a temporary stand-in for enemies; they are not enemy AI and are not a shipping control surface.

## Run the melee enemy test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/melee_enemy_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Melee enemy test failed with exit code $LASTEXITCODE" }
```

Melee enemies use `res://scripts/game/melee_enemy.gd` and expose `setup`, `simulate_tick`, `take_damage`, and `die`. The encounter director spawns authored tier compositions from simulation time, continues pressure during sealing, skips attempts at the 60-enemy cap, and applies late-tier and well-two damage escalation.

## Run the automatic weapon test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/auto_weapon_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Automatic weapon test failed with exit code $LASTEXITCODE" }
```

`res://scripts/game/auto_weapon.gd` acquires the nearest living enemy within 12 units and fires one 10-damage projectile every 0.6 seconds. Projectiles travel at 18 units/sec, live for 3 seconds, and can damage one enemy once. The controller clears them on retry and terminal states.

## Run the surges and ranged enemy test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/surges_ranged_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Surges and ranged enemy test failed with exit code $LASTEXITCODE" }
```

Ranged threats stop within 8 units, telegraph for 0.6 seconds, fire 8-damage projectiles at speed 8, and expire after 3 seconds or a hit. Their attack state and projectiles freeze while paused.

## Run the player abilities test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/player_abilities_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Player abilities test failed with exit code $LASTEXITCODE" }
```

The hero exposes `setup_abilities`, `try_dash`, `try_pulse`, `receive_damage`, `simulate_ability_tick`, and `reset_abilities`. Dash lasts 0.2 seconds at speed 15 with a 4-second cooldown and blocks hero damage only. Pulse deals 15 damage within radius 4 with an 8-second cooldown.

## Run the upgrade purchases test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/upgrade_purchases_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Upgrade purchases test failed with exit code $LASTEXITCODE" }
```

The account exposes `purchase_upgrade` and `has_upgrade`. `damage_1` costs 40 and adds 5 weapon damage, `pump_1` costs 60 and adds 25% extraction output, and `spread_1` costs 100 and fires three projectiles at -12, 0, and +12 degrees. Purchases are one-time, outside active runs, and apply at the next run start.

## Run the feedback and onboarding test

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/feedback_onboarding_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Feedback and onboarding test failed with exit code $LASTEXITCODE" }
```

The HUD explains movement, starting, tank risk, sealing danger, failure, and retry. Success is shown as banked mana; sealing explicitly remains unsafe until its timer reaches zero. Developer-only damage controls are hidden unless `EncounterController.developer_mode` is enabled. The exported `sealing_duration_setting` supports the authored 2-second seal or a 0-second developer test seal.

## Run the extraction checkpoint

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/extraction_checkpoint_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Extraction checkpoint failed with exit code $LASTEXITCODE" }
```

The checkpoint records fresh-run timing, delayed and instant sealing, pause during sealing, hero and machine failure, retry, and next-run upgrade effects. The evidence report is `work/playtests/extraction.md`.

## Persistent account saves

The runtime stores versioned account progress and an optional active encounter snapshot under `user://account_save.json`. `SessionPersistence` owns the injected store and monotonic/UTC clocks, builds one envelope, and routes controller saves through `SaveStore.save_envelope()`. `SaveStore` reports `fresh`, `loaded`, `recovered`, `unsupported`, or `corrupt` through `get_load_result()`, with write eligibility. Writes go through a temporary file and committed backup; a rejected live save is preserved at `user://account_save.json.recovery`, and unsupported or unrecoverable saves block automatic writes until explicit reset. Tests configure persistence before startup and use injected fixture paths, so they never touch the player save.

Fractional production remains in memory between explicit transitions and five-second checkpoints. Failed saves retain the dirty account and latest snapshot for retry without replaying rewards or purchases; an uncommitted crash can still roll back to the last successful checkpoint.

Combat runs through one controller-owned 60 Hz scheduler. Each fixed step consumes queued input, updates player movement and abilities, advances the weapon and hostile actors/projectiles, applies damage, then advances sealing/extraction and resolves terminal state. Rendering and passive production remain outside that loop. Actor `simulate_tick()` methods no longer run from independent physics callbacks; `EncounterController.tick()` is a compatibility wrapper over the same fixed-step path for integration tests.

Active encounter snapshots use the current schema and validated component records. `RunSnapshot` rejects malformed sections, unknown kinds, invalid references, duplicate IDs, nonfinite values, and unsupported versions before scene mutation. Stateful components expose `capture_snapshot_state()` and `restore_snapshot_state()`; actor and projectile IDs come from the persisted monotonic `spawner.next_id`. Safe legacy IDs can migrate into a separate namespace; unsafe identity or incomplete component state rejects only the active snapshot and preserves banked progress. Restored encounters are paused until explicit resume.

The account owns commissioned wells, hero assignments, upgrades, per-well loadouts, and run identity. `ContentCatalog` supplies the known well, hero, upgrade, and surge definitions. `AccountState.complete_run()` is the single successful-run command: it validates the active run ID and applies payout and commissioning once. `select_well_by_id`, `select_loadout_by_id`, `select_active_hero_by_id`, `assign_guard_by_id`, and `recall_guard_by_well_id` are the controller's UI-independent command boundary. The HUD emits these semantic IDs and does not save or mutate account state.

Passive production uses commissioned, guarded, non-active wells and the injected monotonic/UTC clocks. Offline catch-up is capped at 24 hours, backward clocks grant zero while preserving the later watermark, and failed writes remain pending for retry. Loadouts affect active runs only: Overdrive changes active extraction and pressure timing, while Fortified raises machine integrity to 225 without changing output or pressure.

The collapsed **ACCOUNT** section can clear the live save, temporary file, backup, and recovery copy outside an active extraction or sealing phase. The **NETWORK** section shows guarded production and exposes offline-settlement retry. These controls are adapters over the command and persistence boundaries, not the enforcement layer.

Architecture verification is recorded in `work/reviews/architecture-follow-up.md`. The complete strengthened runner currently discovers 31 tests. A fresh fixture journey progresses, assigns a guard, accrues production, saves, restores paused, resumes, commissions the next well, and completes without touching the player profile.

```powershell
& $godot_console --headless --path '.\prototype' --script 'res://tests/account_saves_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Account save test failed with exit code $LASTEXITCODE" }
```

Verify the production model with:

```powershell
& $godot_console --headless --path '.\\prototype' --script 'res://tests/production_test.gd'
if ($LASTEXITCODE -ne 0) { throw "Production model test failed with exit code $LASTEXITCODE" }
```

Offline catch-up is capped at 24 hours and is not applied to active encounter recovery.

Verify online production manually by unlocking Hero 2, assigning a guard, expanding **NETWORK**, and starting an expedition at the other well. Confirm the guarded site's displayed rate and bank increase while the expedition site shows no passive rate. Pause combat for several seconds and confirm income continues; collapse and reopen **NETWORK** and confirm the bank does not jump. Buy **Pump +25% output** between checks and confirm only future accrual uses the higher rate.

Verify offline production by assigning Hero 2 as a guard, closing the game, advancing the saved test clock or waiting briefly, and restarting. Expand NETWORK and confirm the welcome-back amount matches the displayed rate and elapsed time. Restart again at the same timestamp and confirm no second credit. For a backward clock, confirm zero credit and a preserved watermark. To exercise recovery, make the save location unavailable, restart, restore it, and press **Retry offline settlement** once; confirm the summary clears without awarding twice.

Verify loadouts manually by commissioning Well 2, selecting each site in PREPARATION, and confirming Standard, Overdrive, and Fortified are available. Start an Overdrive run and compare its tank and next-surge timing with Standard; confirm the selector is disabled after starting. Start Fortified and confirm the machine bar maximum increases to 225 while output and pressure timing remain at baseline. Expand NETWORK before and during each run to confirm passive rates are unchanged.

Known limitations remain: checkpoint recovery can roll back to the latest committed save after a crash; local wall-clock time is user-editable; the project uses a Godot 4.8 development build; and manual visual, input, collision, window-focus, and readability checks have not been performed in this environment.
