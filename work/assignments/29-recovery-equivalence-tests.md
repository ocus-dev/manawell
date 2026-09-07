# 29 — Recovery equivalence checkpoint

Status: tracked in work/architecture/README.md. Dependencies: 28.
Review coverage: Findings 3–5 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: scheduler, session save boundary, component snapshots; suspend_resume tests. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Add a fixture that branches the same encounter into uninterrupted and save/reload/resume paths. Drive both through the real fixed-step scheduler with scripted commands and isolated stores. Cover scaled enemies, purchased spread/damage, in-flight friendly/hostile shots, partial cooldowns, sealing, and one-time payout. Fix only small defects exposed in this boundary; record a separate follow-up if repair becomes substantial.

## Acceptance checks

Compare health, tank, phase, reward, actor IDs and projectile state at matching simulation steps within stated numeric tolerances. Loading remains paused until resume. Reload after a committed success never re-awards. Persistence failures preserve the latest committed checkpoint. Run all existing and new tests through card 22's runner.

## Stop boundary

No manual fun conclusions, balance changes, or visual overhaul. Passing dictionary round-trips alone does not complete this card.

## Completion note

Implemented `recovery_equivalence_test.gd` using the real controller fixed-step `tick()` scheduler, isolated save stores, scripted sealing, and component-owned snapshots. The fixture branches identical upgraded encounters into uninterrupted and save/reload/resume paths, verifies loading remains paused, and compares phase, hero health, machine integrity, sealing time, actor IDs, projectile IDs/kinds/positions/lifetimes, and one-time bank payout. It also verifies a failed checkpoint leaves the last committed envelope intact while retaining the pending retry. Exact checks: `recovery_equivalence`, `snapshot_validation_identity`, `suspend_resume`, and `single_scheduler` passed; the complete runner suite passed with all 27 tests. No runtime repair was required beyond the assignment 28 compatibility path. Remaining limitation: equivalence assertions use scalar tolerances and do not cover renderer-only effects.

