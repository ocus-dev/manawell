# 24 — One session save boundary

Status: tracked in work/architecture/README.md. Dependencies: 23.
Review coverage: Findings 1 and 5 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: controller save/purchase/reward/assignment paths; SaveStore; production.gd. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Extract a small session persistence coordinator with injected store and clock. Make one envelope builder own account, UTC watermark, and optional snapshot. Route purchases, assignments, rewards, offline settlement, retry and checkpoints through it; remove the purchase path that writes timestamp zero. Use distinctly named monotonic and UTC fields. Settle old-rate income before rate-changing commands. Inject test persistence explicitly before startup; do not globally disable it merely because Godot is headless.

## Acceptance checks

Purchase with an eligible guard then immediately reload: only true elapsed income is credited. All save call sites use the same envelope. Fake monotonic and UTC clocks deliberately differ by orders of magnitude and still calculate correct income. Fixture startup exercises persistence without writing the player profile.

## Stop boundary

Keep current save cadence for the next card. No scheduler, HUD, content, or broad account redesign. Introduce a coordinator, not a second giant controller.

## Completion note

Completed. Added `SessionPersistence` with injected store, monotonic/UTC clocks, `build_envelope()`, and one `save()` boundary. `SaveStore.save_envelope()` now writes the explicit `production_utc_timestamp` field while reading the legacy name. Controller purchases, assignments, rewards, offline settlement, retry, and checkpoints route through the coordinator; headless mode no longer disables persistence, and existing fixtures configure it before startup. Added `session_persistence_test.gd` covering guarded purchase then reload, clocks separated by orders of magnitude, and isolated startup persistence. All 22 discovered tests pass through `run_tests.ps1`; diagnostics report no errors. Remaining limitation: save cadence is unchanged and remains intentionally bounded by the next assignment.

