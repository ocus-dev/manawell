# 49 — Archive the 3D baseline

Status: tracked in work/2d/README.md. Dependency: current working project.

## Read

Queue rules; `prototype/project.godot`, `prototype/README.md`, `prototype/run_tests.ps1`, repository ignore files; current resource paths and launch scripts. Inspect actual working files, including uncommitted/untracked assets, rather than archiving only a Git commit.

## Implement

This card now starts the approved side-view conversion. Read `work/playtests/side-view-experiment.md` as evidence, but do not treat its 101-file source inventory as a complete asset archive. Inventory all runtime resources in the current 3D project. Also record the experiment's current source manifest and test results so its accepted baseline remains identifiable; leave the experiment unchanged. It is a reference project, not the new active path.

Create `archive/prototype-3d/` as a self-contained copy of the current Godot project. Preserve source, scenes, resources, imported source assets, UID sidecars, project configuration, tests, runner, and relevant documentation. Exclude regenerable `.godot/`, test logs, temporary outputs, and user saves. Resolve any resources outside the source project explicitly; record missing dependencies rather than assuming a copy is runnable. Do not duplicate the Godot executable, unrelated concept art, or the entire tools directory.

Add `archive/README.md` identifying the frozen 3D project, date, launch command using the installed executable, and the active `prototype/` destination. Record a source-file inventory/hash manifest and exclusions before modifying active files. Keep the archive's original resource-relative paths. Configure isolated user data for archive smoke testing so it cannot write the live profile. Add `work/2d/test-matrix.md` classifying existing tests as reusable model/UI, spatial conversion, integration conversion, or obsolete 3D-only, with the responsible card for each conversion. Run the baseline suite and record existing failures distinctly from future regressions.

## Acceptance

- Source/archive manifest comparison accounts for all included files; any intentional configuration difference is listed.
- Archive imports and boots with the installed engine under an isolated profile; capture errors and dependencies.
- Active project is unchanged by the archival operation. Archive is outside its import tree.
- Baseline test results and conversion ownership are recorded. Existing UI visual limitations are retained.

## Stop

No active 2D conversion, deletion of source assets, or unrelated repository cleanup. Do not mark the archive verified while required resources are missing.

## Completion note

Completed 2026-09-07.

- Archived the current 3D project at `archive/prototype-3d/` as 222 preserved source/runtime files, including scripts, scenes, GLB/PNG source assets, import sidecars, UID sidecars, project configuration, tests, runner, and documentation. The archive uses isolated user data `user://telos_prototype_3d_archive`.
- Recorded complete pre-archive and archive SHA-256 manifests in `archive/prototype-3d-source-manifest.sha256` and `archive/prototype-3d-archive-manifest.sha256`. All included paths/hashes match except `project.godot`, where only archive name, description, and user-data identity differ intentionally. The accepted experiment manifest is recorded at `archive/side-view-experiment-source-manifest.sha256`; the experiment was unchanged.
- Excluded `.godot/`, imported engine caches, editor state, shader caches, logs, temporary outputs, save-like files, the Godot executable, unrelated concept art, and the repository tools directory. Generated imported caches regenerated during archive smoke testing and are not part of the source archive manifest.
- Added `archive/README.md` with launch path, active destination, inventory/exclusions, dependency resolution, and baseline result. Added `work/2d/test-matrix.md` covering all 44 existing tests and assigning reusable model/UI, spatial, integration, and obsolete-3D-only conversion ownership.

Actual checks:

- Baseline command: `prototype/run_tests.ps1` with `work/reviews/logs/baseline-20260907`; 44 tests passed and `recovery_equivalence_test.gd` failed with its existing headless transform diagnostics and assertion at line 82. Runner exit code was 1; this is recorded as a baseline failure, not an archive regression.
- Archive import: `Godot_v4.8-dev4_win64_console.exe --headless --editor --path archive/prototype-3d --quit`: exit code 0.
- Archive boot: `Godot_v4.8-dev4_win64_console.exe --headless --path archive/prototype-3d --quit-after 2`: exit code 0. Godot emitted resource-leak diagnostics on exit; no missing source dependencies were reported.
- Active prototype manifest comparison after copying: 0 differences, 222 files, aggregate SHA-256 `1f763463dbe9bbb06e70c7f42b5364383fbab71ffca60f1cd3ff486d9bbe651f`.

Card 50 is the next conversion task. No active 2D conversion, source deletion, or cleanup was performed.
