# Telos archive

## Frozen 3D baseline

`archive/prototype-3d/` is a source-level copy of the current Godot 3D project captured on 2026-09-07 before the approved side-view conversion. The active project destination is `prototype/`; this archive is reference-only and is outside the active project's import tree.

Launch the archive from the repository root with the installed console executable:

```powershell
$godot_console = '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& $godot_console --path '.\archive\prototype-3d'
```

The archive project uses `config/user_data_dir="user://telos_prototype_3d_archive"` so smoke tests and manual runs do not write the live profile. Its display name is `Telos Prototype 3D Baseline Archive`; these are the only intentional source differences from `prototype/project.godot`.

## Inventory and parity

The source inventory was captured before the copy and includes 222 files: 91 GDScript files, 91 UID sidecars, 5 scenes, 5 GLB source assets, 9 PNG source assets, 14 import sidecars, the project file, runner, README, `.gitignore`, and two pipeline-owner metadata files. The complete manifests are:

- `archive/prototype-3d-source-manifest.sha256`: pre-archive active source inventory and SHA-256 values.
- `archive/prototype-3d-archive-manifest.sha256`: copied archive inventory and SHA-256 values.
- `archive/side-view-experiment-source-manifest.sha256`: accepted S01-S03 experiment source inventory, recorded without changing the experiment.

The source/archive comparison found exactly one path difference, `project.godot`, with the intentional archive identity changes above. All other included paths and hashes match.

The current prototype inventory after copying remains 222 files with aggregate SHA-256 `1f763463dbe9bbb06e70c7f42b5364383fbab71ffca60f1cd3ff486d9bbe651f`, computed by the same canonical inventory command used for the pre-archive record. The archive copy contains the same 222 paths.

## Exclusions

Excluded from the archive copy:

- `prototype/.godot/`, including imported engine caches, editor state, shader caches, and generated imported scenes.
- `prototype/logs/` and test log output.
- Temporary files matching `*.tmp` and `*.log`.
- User-save names and save-like files matching `account_save`.
- Temporary/scratch directories named `temp` or `temporary`.

The Godot executable, unrelated `concept_art/`, and the repository `tools/` directory were not duplicated. No external runtime dependency was found: project scripts and scenes use `res://` references within the project, and the archive retains the referenced source assets and sidecars. Generated imported assets are intentionally regenerable by the installed engine; the source `.glb` and `.png` files plus `.import` metadata are preserved.

## Baseline test result

Command run before archive creation:

```powershell
$godot = '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& .\prototype\run_tests.ps1 -GodotPath $godot -LogDirectory '.\work\reviews\logs\baseline-20260907'
```

Result: 44 tests passed and `recovery_equivalence_test.gd` failed. This is recorded as a baseline failure, not an archive regression. Its log records expected headless 3D `!is_inside_tree()` transform diagnostics from `mecha_visual.gd` and an assertion in `_test_failed_checkpoint_keeps_last_committed_snapshot` at line 82, followed by resource-leak diagnostics. The baseline runner exited with code 1 because of that failure.

## Archive smoke result

The archive was copied before any active-project edits. Headless editor import/quit and headless main-scene boot both passed with exit code 0 using the installed Godot version. Import regenerated the excluded `.godot/imported` cache inside the archive, as expected; no source dependency was missing. The baseline suite result above remains the authoritative pre-copy test record.

The side-view experiment remains unchanged as a reference project. Its source manifest and accepted S01-S03 test results are recorded separately; it is not duplicated into this archive.
