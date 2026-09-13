# 57 — Full acceptance and documentation

Status: BLOCKED, tracked in work/2d/README.md. Dependency: 56.

## Read

Queue and handoffs 49–56; test matrix; current README/contracts/concept presentation section; pending UI visual acceptance and baseline failures.

## Implement

Verify the final approved side-view implementation, including sustained combat beyond the experiment's last wave, current-position projectile dodging, Triple shot, left/right recovery, and both well/loadout modifiers. Link the original experiment report as historical evidence and record the user's 2026-09-07 direction approval without inventing missing visual test results. Identify `experiments/side-view-defense/` as frozen history and `archive/prototype-3d/` as the original runtime; neither is an active dependency. Remove stale top-down/current-experiment instructions from project indexes and docs. Final scope is the existing full prototype in side view with retained procedural visuals, not a new platformer or final art release.

Run the complete active test suite with the existing strengthened runner. Resolve conversion regressions within this queue's scope. Reconcile every test matrix row: ported/passing, explicitly obsolete 3D-only with rationale and archived location, or unresolved with evidence. No silently deferred tests at completion. Remove temporary deferred copies once their coverage is ported and archive preservation is verified.

Perform an isolated-profile runtime walkthrough: preparation → extraction → dash/pulse/ranged combat → harvest → payout → purchase → guard assignment → second-well/loadout run → pause/save/close/reopen/resume → failure/retry. Inspect the two target resolutions and complete the applicable UI checks inherited from card 48. If visual tooling is unavailable, record the exact unverified checks and leave final acceptance BLOCKED; other implemented cards retain their actual status.

Update `prototype/README.md`, `work/CONTRACTS.md`, and the active presentation section of `design/Concept.md` to describe the resulting 2D project. Preserve historical assignments and original design history. Add `work/reviews/2d-transition-acceptance.md` with actual commands, results, screenshots where available, baseline versus new failures, archive location/launch instructions, and remaining limitations. Scan active resource references and launch scripts for stale 3D/archive dependencies. Verify the frozen archive manifest, accounting only for explicitly recorded archive metadata/config changes from 49.

## Acceptance

- One clear active 2D project and one self-contained frozen 3D archive; no active resource loads from the archive.
- Complete suite passes, or unresolved failures are honestly reported and final acceptance remains incomplete.
- Full gameplay and fresh 2D recovery journey verified; visual acceptance backed by runtime observation.
- Documentation agrees with tested behavior, profile location, and spatial scale. No claims of final art or human fun validation.

## Stop

No new feature backlog, publishing, engine upgrade, or automatic task dispatch.

## Completion note

BLOCKED 2026-09-07. Reconciled the active 2D documentation, test matrix, archive references, and stale conversion wording. The active runner passes all 22 discovered tests; 1280x720 and 1920x1080 headless boots pass without script/resource diagnostics. The temporary deferred copies were removed after their 30 legacy 3D-only fixtures were classified with archived paths and current 2D replacements. The archive manifests retain the same 222 paths and differ only in the intentional `project.godot` identity metadata. Native Godot screenshots and the requested interactive isolated-profile walkthrough are unavailable in this environment, so visual acceptance and the full preparation-to-retry journey remain unverified. Final acceptance must remain blocked until those checks are performed.
