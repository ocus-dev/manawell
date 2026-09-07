# 25 — Bounded checkpoints and failed-save retry

Status: tracked in work/architecture/README.md. Dependencies: 24.
Review coverage: Finding 1 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: session coordinator from 24; controller process/checkpoint/close handlers. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Accrue fractional production in memory. Save dirty state at a five-second real-time checkpoint cadence plus explicit transitions and orderly close, including idle guarded production. Centralize pending-save/error/retry handling: retain a dirty in-memory result on failure, retry without reapplying its reward/purchase, and checkpoint the latest coherent account/snapshot together. Keep a UTC high-water mark across backward-clock events. Ensure focus-loss saves do not introduce unrelated behavior changes.

## Acceptance checks

A spy store observes at most the configured periodic writes during hundreds of idle/render frames, excluding explicit transitions. Checkpoints also work when combat is paused. Fail a reward/purchase/offline save, retry, reload, and verify one credit/debit. Backward time followed by ordinary save preserves the watermark. Orderly close settles elapsed income before persisting.

## Stop boundary

No asynchronous I/O framework. Document that an uncommitted crash can roll back to the last successful checkpoint. Do not claim perfect durability on filesystem failure.

## Completion note

Completed. Extended `SessionPersistence` with dirty envelopes, pending snapshots, retry, and a UTC high-water mark. Production now accrues in memory; five-second checkpoints run during idle and paused ticks, while explicit transitions and orderly close persist the latest coherent account/snapshot. Failed offline credits and purchases remain applied in memory and retry without replay. Added `retry_pending_save()` and spy-backed `checkpoint_retry_test.gd`; strengthened offline reload coverage. Updated fixture startup to configure persistence before `ready`. The full 24-test suite passes through `run_tests.ps1`. Remaining limitation: an uncommitted crash can roll back to the last successful checkpoint; no asynchronous durability is claimed.

