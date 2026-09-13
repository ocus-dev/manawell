# Side-view defense experiment

This is the isolated S01 movement shell for the Telos side-view defense experiment. It is a separate Godot project and does not replace or modify the preserved 3D baseline at `../../prototype/`.

## Launch

From the repository root:

```powershell
& '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe' --path '.\experiments\side-view-defense'
```

Open `experiments/side-view-defense/project.godot` in the Godot editor, or run the main scene with the same command. The logical canvas is 1280x720 with keep-aspect uniform scaling. The scene uses procedural shapes only.

## Focused test

From the repository root:

```powershell
& '.\experiments\side-view-defense\run_tests.ps1' -GodotPath '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
```

The runner has a 30-second default timeout and writes only transient diagnostics under the ignored `logs/` directory. The focused test is `tests/movement_test.gd`.

## Implemented scope

The experiment provides a fixed camera, one ground level, a central harvester with a service walkway, bounded horizontal hero movement, a visible facing/weapon direction, and visible Start/Harvest, Retry, and Pause/Resume controls. A and D or the left/right arrows move; Space dashes, Q pulses, E starts or harvests, and Escape pauses. Equal simultaneous left/right input resolves to zero.

S02 adds READY -> EXTRACTING -> SEALING -> SUCCESS/FAILED, session-only tank/payout, hero and machine health, pressure surges, all three enemy roles, deterministic left/right waves, a 60-enemy cap, nearest-target auto-fire, swept single-hit projectiles, ranged windups, dash invulnerability, pulse damage, pause, and clean retry. No state is persisted.

`SPATIAL_PIXELS_PER_UNIT` is the named 32 px/unit conversion used by the local hero movement controller. The copied balance values and RunState are present for S02's local implementation; no 3D actor/controller or persistence stack was copied.

## Provenance and baseline integrity

Copied/adapted source provenance:

| Experiment file | Prototype source | Prototype SHA-256 |
|---|---|---|
| `data/balance.gd` | `prototype/data/balance.gd` | `feb9e15d8479a59420a4351b7910a28f920773159ba5d4ee3044f6f1a7ddfa5f` |
| `data/run_state.gd` | `prototype/scripts/model/run_state.gd` | `4cf81b06e1fdf9f2c79640d3018fcc5c5d5bfa47fa89696ea6c1739a76406730` |

`prototype/scripts/game/player.gd` was read for behavior only and was not copied because it is 3D-specific. Its recorded SHA-256 was `18760334f79419913bf415c58ef1053515bd54ed97e6b3d417de29586c6e60f3`.

The source inventory includes prototype `.gd`, `.tscn`, `.godot`, `.ps1`, `.md`, and `.json` files, excluding `.godot/` and `logs/` paths. It contained 101 files before S01 edits, with aggregate SHA-256 `cb9302330a55a5a4b740c305a3cb04e057048d1e9cac2e10d2ec3e1f11384f1a`. The same inventory after S01 is recorded below after verification.

To reproduce the inventory summary from the repository root:

```powershell
$root = (Resolve-Path '.\prototype').Path
$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in @('.gd','.tscn','.godot','.ps1','.md','.json') -and $_.FullName -notmatch '\\.godot\\|\\logs\\' } | Sort-Object FullName
$rows = foreach ($file in $files) { $relative = $file.FullName.Substring($root.Length + 1).Replace('\','/'); [pscustomobject]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() } }
$canonical = ($rows | ForEach-Object { "$($_.path)`t$($_.sha256)" }) -join "`n"
$aggregate = ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)) | ForEach-Object { $_.ToString('x2') }) -join ''
"count=$($rows.Count) aggregate_sha256=$aggregate"
```

## S02 schedule

The authored schedule is in `data/schedule.gd`: pursuers at 5s left and 10s right; a breaker at 18s left; a ranged threat at 26s right; a breaker at 36s right; a ranged threat at 46s left; mixed pursuer/breaker pressure at 58s; mixed ranged/pursuer pressure at 70s; and mixed breaker/ranged pressure at 82s. This introduces all roles within the first 90 seconds and then stops at twelve authored entries. The live-enemy cap is the copied `Balance.MAX_LIVE_ENEMIES` value of 60. No tuning changes were made to copied balance constants.

## Verification note

Automated checks pass for project import, headless main-scene boot, S01 movement behavior, S02 lifecycle and combat behavior, lethal sealing boundary, pause/retry cleanup, deterministic targeting, and swept projectiles. Visual inspection at 1280x720 and 1920x1080, interactive input focus behavior, and human playtest judgment remain pending until S03.
