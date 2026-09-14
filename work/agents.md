# Agent working agreement

Read this file before starting any assignment in this project. It governs implementation, handoff and integration work. Historical assignment notes are context, not authority to restore older behavior. Explicit current user instructions take precedence.

This lowercase file is a shared work agreement, not an automatically discovered root `AGENTS.md`. Every agent task prompt must explicitly require reading `work/agents.md`.

## Before writing

1. Identify the assignment, dependencies, current user requirements and latest predecessor handoff. Do not infer the current queue from an old “next task” note.
2. Record the repository path, branch, base commit SHA and working-tree status. Confirm that the intended files belong to this checkout.
3. Work in an isolated Git worktree and task branch based on an explicit integrated commit supplied by the coordinator. Do not independently choose an old baseline. Branch names use `codex/` unless the user specifies otherwise.
4. Declare the exact writable files/directories, interfaces being changed, acceptance checks and behaviors that must remain intact.
5. Inspect the current implementation before editing. An assignment saying “migrate” or “refactor” does not authorize rebuilding a feature from an older implementation.

If a necessary file contains another task's uncommitted changes, stop editing that file and report the conflict. Continue independent authorized work. Do not clean the checkout to make it convenient.

## Ownership and parallel work

- The integration checkout and integration branch have one writer: the designated integrator.
- Implementation agents own separate worktrees and explicit paths. Parallel work requires disjoint file ownership and agreed interfaces.
- If two tasks require the same shared file, serialize those edits or have agents deliver proposed patches to its owner. Worktrees prevent overwrites; they do not make conflicting designs compatible.
- Treat the encounter controller, app startup, save/snapshot code, shared catalogs, project settings and runtime asset manifest as shared interfaces. Changes require explicit ownership in the assignment.
- Do not spawn additional agents unless the user or coordinator explicitly authorizes delegation.

## Git rules

- Make focused edits to current files. Never replace a shared file with a historical copy to resolve a conflict or recover one feature. Reconcile the intended changes against current behavior.
- Do not use `git add -A` or broad staging. Stage only the task's explicit paths, then inspect the staged diff and file list.
- Implementation agents may commit only their own task changes in their isolated worktree. They do not merge, push or write to the integration branch.
- Do not use restore, checkout-file, reset, clean, stash/pop or force operations as incidental cleanup. Recovery requires an explicit recovery task, a preserved copy of the affected state and a reviewed recovery scope.
- Never discard untracked files or generated asset metadata merely because they are unfamiliar.
- Before committing, inspect the entire diff, including deletions and changed assets. Explain any removed behavior; an unexplained large deletion is a blocker.
- Do not amend someone else's commit or rewrite shared history.
- The integrator alone applies task commits, resolves conflicts semantically, runs the integration gate and publishes when authorized.

## Implementation boundaries

- Keep gameplay configuration in one authoritative source. Floor height, platform offsets, bounds, spawn zones, drill placement/scale and actor starts must agree. Derive values instead of copying numeric constants into another script.
- Load and validate content outside frame/render paths. Reuse a validated catalog; perform explicit development reloads when content changes. Freeze the required definition for an active run.
- Keep spawn scheduling, combat, rewards, persistence, UI and presentation responsibilities distinct. Introduce adapters incrementally; do not rewrite the entire controller as part of a narrow feature.
- Presentation should consume defined state/events for shots, spawns, deaths, phases and pause. Do not silently depend on experiment-only controller fields.
- Keep the production entrypoint separate from direct-scene test and experiment launches. A main-scene test does not verify the title flow.
- Keep approved runtime art traceable to its source and intended asset path. Do not promote an unreviewed candidate or overwrite approved art during unrelated work.
- Preserve save data during normal development. Tests use disposable accounts and disable persistence unless persistence itself is being tested against isolated storage.
- Do not retune balance, remove features, change expected tests or bypass validation to make a migration pass. An intentional behavior change must be required by the task and documented.

These boundaries are the target architecture. Where the current code has not reached them, use a narrow adapter and report the remaining coupling rather than starting an unsolicited rewrite.

## Current approved behavior to preserve

Until explicitly changed by the user:

- Project startup displays the title screen before entering the hub/game.
- The logical arena is 1280×720; the floor is at y=652, with clearance above the hotbar. Actor feet, collisions, scenery and shadows agree on support height. The lane sprite is hidden.
- The drill is at x=160 and uses a 1.4 visual scale. New enemy arrivals come from the right only, including campaign waves.
- Act 1 uses the approved improved map, with the current campaign node layout. The approved image SHA256 is `3a865a4423646e2849d1a328b49e9aec1ab57e68f2afb501947abafcd31a3f5e` until a new image is selected.
- Operations owns destination, hero and loadout selection. Well nodes open a compact guard/income popup on the map.
- Operations, Map and Research fit without outer scrolling at supported resolutions. Inventory retains its equipment, item grid and details layout.
- Research and equipment affect gameplay; monster drops remain visible and collectible; the development drop-rate command works.
- Window-size selection works from windowed, maximized and fullscreen modes.
- Main-scene lighting, activity, shadows and single/volley flashes work, respect pause and clear appropriately between encounters. Experiment controls do not appear in normal play.

This list describes acceptance requirements, not a claim that the current checkout passes them. If the starting branch already violates one, record the failure and ask the integrator to reconcile it; do not silently normalize the regression. Update this list alongside an explicitly authorized behavior change.

## Verification and completion

### Implementation agent

- Run assignment-specific checks and the regression checks relevant to changed interfaces.
- Check actual output, not just process exit status. Godot can emit assertion/script errors and later exit zero after a forced quit.
- A timeout, missing completion marker, parse/script error or failed assertion is failure. An intentional negative test must identify its exact expected diagnostic; never ignore errors globally.
- Await asynchronous test bodies before printing success or quitting. A test that starts an async check and exits early is not evidence.
- Verify UI/art changes at actual gameplay size. Node counts and configuration flags do not prove an effect is visible or correctly placed.
- Report unavailable checks and pre-existing failures honestly. Do not claim integration acceptance from a focused unit test.

### Integrator

Before establishing a new integrated baseline, verify:

1. Project-entry title flow and transition into gameplay, using the intended checkout and launch command.
2. Arena alignment, drill size/position, right-only spawning, jumping/platform landing and hidden lane.
3. Approved map and node interactions, well popup, loadout selection, fitted pages, inventory and research.
4. Single/volley attacks, item drops, pause/resume, encounter outcomes, retry and isolated save/restore.
5. Resolution changes and representative visual captures at 1024×576, 1280×720 and 1920×1080.
6. Representative fixed-load performance against a measured approved baseline. Record renderer, resolution, hardware, warmup and measurement conditions; do not invent a performance threshold.

Use the project's test runner where applicable; it already checks diagnostic failures. Supplement it with entry-flow and visual/performance checks. Keep logs and require explicit completion evidence. Do not run the full gate repeatedly without new changes, but do run it on the final combined state.

## Handoff format

Record in the assignment's handoff:

- Assignment ID, base SHA, branch/worktree and result commit SHA.
- Changed files and resulting behavior, including removed behavior and changed interfaces.
- Checks actually run: commands, exit/result, completion markers and log/capture paths.
- Known failures, limitations, dependencies and required integration actions.
- Status: `READY FOR INTEGRATION` after task checks; only the integrator marks `INTEGRATED` after the combined gate passes. Historical `DONE` labels alone are not proof of integration.

Keep the handoff concise and specific. Do not edit other tasks' status or describe pending work as complete.

## Reusable implementation prompt

Implement only [assignment]. Read `work/agents.md` and the latest predecessor handoff first. Start from integrated base [SHA] in [worktree/branch]. Writable paths: [paths]. Shared interfaces: [contracts]. Preserve the approved behaviors unless this task explicitly changes them. Make focused edits to current files; report required changes outside ownership to the integrator. Run [acceptance/regression checks]. Commit only your explicit paths and deliver the handoff evidence. Do not merge or push to the integration branch. Stop at READY FOR INTEGRATION.

## Recovery procedure

Pause writes to affected shared paths. Preserve HEAD, status, tracked diffs and untracked files in a dated backup before recovery. Establish what changed using commits, reflogs, diffs and asset hashes. Recover feature by feature while retaining legitimate newer work. Verify the actual launched project before blaming an unchanged asset or entrypoint. Re-run the combined gate before recording a recovered baseline.
