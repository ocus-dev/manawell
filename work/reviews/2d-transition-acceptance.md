# 2D transition acceptance

Date: 2026-09-07
Status: BLOCKED for final visual acceptance

## Scope

The active project is `prototype/`, a native Godot 2D side-view prototype with a fixed 1280x720 logical canvas and a single horizontal ground lane. It retains procedural industrial visuals and the existing full prototype loop: preparation, extraction, combat, harvest, payout, purchases, guard assignment, second-well/loadout runs, pause/save/reopen recovery, failure, and retry. `experiments/side-view-defense/` is frozen historical evidence. `archive/prototype-3d/` is the self-contained original runtime and is not an active dependency.

The side-view direction was approved by the user on 2026-09-07. That approval records product direction only; it is not visual test evidence or a fun verdict.

## Commands and results

From the repository root:

```powershell
& .\prototype\run_tests.ps1 -GodotPath '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
```

Result: 22 of 22 active tests passed. The runner completed without timeout, parse error, assertion failure, or unexpected script diagnostic.

```powershell
$godot = '.\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64_console.exe'
& $godot --headless --path '.\prototype' --resolution 1280x720 --quit-after 2
& $godot --headless --path '.\prototype' --resolution 1920x1080 --quit-after 2
```

Result: both boots exited 0 with no script, parse, or missing-resource diagnostics.

The active test matrix is reconciled in `work/2d/test-matrix.md`. Thirty temporary legacy fixture copies were removed after classification as obsolete 3D-only tests; their originals remain in `archive/prototype-3d/tests/`.

## Baseline versus new failures

The archive handoff records the pre-conversion 3D run as 44 attempted tests with `recovery_equivalence_test` failing in its old 3D fixture and emitting headless transform/resource-leak diagnostics. This is preserved baseline evidence, not a regression in the active project. There are no new active-suite failures.

The archive manifest check found 222 paths in both manifests. All paths match except the intentional `project.godot` identity metadata for the archive. The archive launch command is:

```powershell
& $godot --path '.\archive\prototype-3d'
```

## Visual and runtime walkthrough status

No native Godot-window screenshot or interactive keyboard/pointer harness is available in this environment. Therefore these checks are explicitly unverified and no screenshot paths are claimed:

- operations, guard picker, extracting, sealing, result, and save-error visual states at 1280x720 and 1920x1080;
- no clipping, duplicate rows, overlap, lost focus, or stale guard/payout text;
- isolated-profile walkthrough from preparation through extraction, dash/pulse/ranged combat, harvest, payout, purchase, guard assignment, second-well/loadout run, pause/save/close/reopen/resume, failure, and retry;
- visual distinction of hero, machine, pursuer, breaker, ranged threat, friendly shots, hostile shots, windup, dash, pulse, and Triple shot trails.

Headless tests and resolution boots do not establish those visual or interactive checks. Final acceptance remains blocked until a desktop-capable walkthrough records them. No final-art or human-fun claim is made.

## Remaining limitations

The project uses Godot 4.8 development build `4.8.dev4.official.b56a91878`. Checkpoint recovery can roll back to the latest committed save, local wall-clock time is editable, and visual/manual acceptance is pending. No new feature backlog, publishing step, engine upgrade, or automatic dispatch was added.
