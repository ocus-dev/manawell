# Telos prototype 2D

Active Godot project for the Windows desktop side-view prototype. The fixed 1280x720 logical canvas uses a single horizontal ground lane, a central harvester, procedural industrial presentation, continuing surge pressure, and the full two-well progression, loadout, production, and recovery loop. The accepted experiment at `../experiments/side-view-defense/` is frozen historical evidence; the original 3D runtime is independently preserved at `../archive/prototype-3d/`. Neither is an active dependency.

## Verified toolchain

- Godot: `4.8.dev4.official.b56a91878`
- Editor: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe`
- Console runner: `C:\Users\TTOCS\Documents\ChatGPT\Telos Game\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe`
- Active project: `prototype/`, using the isolated 2D profile `user://telos_side_view_defense_experiment`.

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

For the static-art comparison scene, open the project in the editor and run `scenes/previews/side_view_visual_slice.tscn`. The five trial sprites are in `assets/side-view/`; their source/cutout provenance, alpha bounds, visible heights, and ground anchors are recorded in `assets/side-view/side-view-assets.json`. Native screenshot evidence and the owner review checklist are in `../work/playtests/static-sprite-slice.md`.

The game uses keyboard controls: `WASD` moves, `E` starts extraction or harvests, `Space` dashes, `Q` uses the defensive pulse, and `Escape` pauses or resumes. The HUD exposes the same actions plus preparation, assignment, upgrade, network, retry, abandon, and save-reset controls. Purchases, guard assignments, well selection, and loadout selection are available outside active combat only.

The active project has no runtime resource loads from the archive or experiment. Its accepted scope is the existing 2D prototype with retained procedural visuals, not a new platformer, final art release, or campaign expansion.
The focused behavior checks are `movement_test.gd`, `run_state_test.gd`, `encounter_test.gd`, `surge_2d_test.gd`, `weapons_abilities_2d_test.gd`, `progression_2d_test.gd`, `persistence_2d_test.gd`, `presentation_2d_test.gd`, and the remaining model/UI tests discovered by the runner. Legacy 3D fixture names are not active paths; their disposition is recorded in `work/2d/test-matrix.md`.

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
