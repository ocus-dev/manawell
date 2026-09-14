# Regression investigation and integration architecture — 2026-09-13

## Verified state
- Commit d4b9b77 (17:24, Updates, bug currently with elevation) reverses drill x=160 to x=240, removes 1.4 visual scale, reintroduces both-side spawning, and removes the windowed resolution fix. These are actual committed reversals.
- Arena floor remains 652 while encounter_controller uses 540. Spawn feet are therefore 112 pixels above the floor. Main scene hero starts at 612, so systems now disagree about the same arena.
- Current uncommitted encounter_controller rewrite removes approximately 500 lines net, including research/stat resolver, weapon runtime and loot integration, while adding level-definition/objective logic. This is not a narrow spawn-data adapter. Preserve it for reconciliation, not blanket restore/reset.
- Updated Act 1 image is NOT missing on disk: master.png SHA256 equals the approved map-improved.png (3a865a4423646e2849d1a328b49e9aec1ab57e68f2afb501947abafcd31a3f5e). campaign_map.gd reads that path. Investigate stale running process/export, alternate checkout, or changed overlay data before changing art.
- project.godot still starts title_screen.tscn. Title code waits for button input. Directly running main.tscn bypasses it. Actual launch path/process still needs verification.
- Main presentation regression test fails immediately at an assertion in the current tree. Do not interpret Godot exit code 0 after --quit-after as success. Existing run_tests.ps1 already scans assertion/parse errors; the missing piece is making its integrated use mandatory.
- Performance candidate: UiViewState._campaign_view constructs CampaignCatalog on HUD rebuild; its constructor now loads/validates files through LevelDataLoader. The controller also constructs catalogs. Cache validated content outside rendering. No rendered frame-time benchmark was performed, so this is not a quantified sole cause.

## Why this is possible
1. Parallel writers share a dirty checkout/index. Git has no per-agent ownership; a commit can include another task's staged files, and restores can erase work without a branch reflog entry.
2. encounter_controller owns startup, progression, combat, loot, snapshots, spawning, UI and visuals. A task touching one feature can replace unrelated behavior.
3. Floor, actor initial positions, spawn direction and presentation placement are duplicated rather than derived from a single runtime configuration.
4. Presentation subclasses depend on concrete mutable controller fields; removing a field can break unrelated effects.
5. Work indices contain several historical 'next queues'. Handoffs report local task success without a named integrated baseline.
6. Many tests instantiate main.tscn directly, so they cannot prove the project entry/title flow. Some asynchronous tests start work then quit from _init before all checks complete. Audit the runner/test lifecycle, not just test counts.
7. Previous integration checks here were also too narrow: passing the specific presentation/UI checks did not establish a complete release baseline. That verification gap should be closed explicitly.

## Immediate recovery plan
A. Pause writes to the integration checkout. Capture HEAD, branch, status, binary patch and untracked files in a dated backup. Keep today's level/weapon work.
B. Identify a baseline PER FEATURE using commit/blob evidence. Do not reset the entire repo to yesterday: newer title/data/weapon work would be lost.
C. Reconcile the controller once, under one integrator: retain approved geometry, one-sided spawns, drill scale, stats, loot and resolution behavior; merge level-data changes through a small adapter.
D. Verify the launched process uses this project, project entrypoint and current assets. Check map overlay data separately from image bytes.
E. Load and validate content once per content revision; inject the catalog into UI/run setup. UI changes should not reopen level files. Profile fixed representative combat before/after.
F. Run the mandatory integrated gate, then create a named baseline commit. No 'complete' status before that gate passes.

## Architecture to implement incrementally
- ArenaDefinition: one source for floor, platform offsets, boundaries, spawn zones and direction policy, drill anchor/scale, hero start and floor clearance. Runtime, scenery, shadows and fixtures derive from it.
- ContentRegistry: startup-loaded immutable validated campaign/weapon/enemy definitions, identified by revision/hash. Explicit development reload only. RunDefinition freezes the needed data for a run.
- SpawnDirector: consumes RunDefinition and ArenaDefinition, emits spawn requests; owns no loot/UI/persistence.
- CombatRuntime / RewardService / RunSnapshotCodec: separate authoritative state changes from drawing; preserve existing behavior with adapter tests before extracting another subsystem.
- Presentation component: subscribes to shot, spawn, death, phase and pause events. It must not require inheritance from a monolithic controller or experiment-only fields.
- AppFlow: sole production entrypoint owns title -> hub -> encounter. Test/experiment scenes are explicit alternate launches.
- AssetManifest: approved runtime asset IDs, paths, dimensions and optional hashes; make asset replacement reviewable instead of relying on a generic master.png name.

Do not rewrite these all at once. Start with ArenaDefinition and catalog lifetime because they address current failures directly, then extract the spawn-data adapter.

## Agent/Git contract
- One isolated worktree/branch per implementation task, created from an explicit integrated base SHA. The integration checkout is single-writer.
- Each assignment declares exact writable paths and public interfaces. Disjoint file ownership is required for parallel work; otherwise serialize or deliver a patch to the integrator.
- Agents commit only their own explicit path list in their own worktree. No git add -A, unrelated restores, whole-file copies from old commits, reset/clean/stash/pop or integration-branch writes as incidental cleanup.
- Existing unrelated changes are a stop-and-report condition for that path, not permission to clean them.
- Before completion, inspect the entire task diff for removed behavior and compare against the base SHA. Record deletions, changed contracts and tests actually completed.
- Integrator alone applies commits to the integration branch, reviews conflicts semantically, runs the cross-feature gate and publishes. Agents do not independently 'fix' shared files to get their local task green.
- Do not change expected regression values, skip tests or remove assertions merely because a migration breaks them. Intentional behavior changes require an explicit task requirement and review.

## Mandatory integration gate
- Launch via project.godot: title visible; user action reaches hub/game. Separate direct-scene test coverage.
- Floor at 652; hero/enemy feet meet support; drill x=160 and scale=1.4; all newly spawned enemies enter from the right; lane hidden.
- Approved map image and current node layout; well popup; Operations loadout; fitted pages; inventory/equip; research purchase; drops and debug drop rate.
- Single/volley attacks, pause/resume, extraction and monster/boss outcomes, restart and save/restore with disposable accounts.
- Fail on engine errors/assertions, timeouts AND missing test completion markers. Await asynchronous test bodies before success.
- Fixed visual captures at supported sizes and fixed-load frame-time measurements; initial performance budget set from measured approved baseline.
- Report base SHA, result SHA, exact command, exit status, completion marker, logs and screenshots. A test name without evidence is not acceptance.

## Reusable task prompt
Implement only [assignment] from integrated base [SHA] in [isolated worktree/branch]. Read the current runtime contract and this assignment's predecessor handoff. Writable files: [paths]. Shared interfaces: [contracts]. Preserve the integration gate behaviors unless this assignment explicitly changes one. Do not edit outside your ownership; report a required shared-file change for the integrator. Make focused edits to current files, never replace them with historical versions. Commit only your named files. Deliver commit SHA, complete diff summary including removed behavior, tests with completion evidence, and remaining blockers. Do not merge/push to the integration branch or mark integrated completion yourself.
