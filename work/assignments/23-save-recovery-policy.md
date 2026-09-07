# 23 — Save recovery and protected writes

Status: tracked in work/architecture/README.md. Dependencies: 22.
Review coverage: Finding 2 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: prototype/scripts/model/save_store.gd; account_saves_test.gd; controller startup. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Return an explicit load outcome: fresh, loaded, recovered, unsupported, or corrupt, with write eligibility. Try a valid backup when live is absent. Preserve rejected live bytes in a separate recovery file before any replacement; never rotate an invalid live over a good backup. Refuse automatic writes for unsupported versions and unrecoverable corruption. Adapt startup minimally to honor this result. Add a narrow injected file-operation seam for failure tests; keep it local to SaveStore.

## Acceptance checks

Test absent live/valid backup; interruption at each rename step; corrupt live/good backup followed by two writes; unsupported live through startup and attempted writes; all missing means fresh. Verify preserved bytes and account value, not merely file existence. Failed temp writes and replacements leave a recoverable committed account.

## Stop boundary

Do not add new save UI flows or solve transaction orchestration here. Existing explicit reset can remain the deliberate route to a fresh account. Keep recovery diagnostics visible.

## Completion note

Completed. Hardened `prototype/scripts/model/save_store.gd` with `LoadOutcome`, `get_load_result()`, `writes_allowed`, rejected-live preservation at `.recovery`, missing-live backup recovery, protected replacement, and injected `set_file_operations()` callbacks. Startup, offline settlement, checkpoint, and retry writes now honor the policy; explicit reset clears recovery material and re-enables writes. Expanded `account_saves_test.gd` for fresh/recovered/unsupported outcomes, source-byte preservation across two writes, missing-live backup, injected temp/rename failures, and unsupported startup. The focused recovery test and all 21 tests pass through `run_tests.ps1`. Remaining limitation: recovery is surfaced through existing notices; migration of older valid schemas remains outside this card.

