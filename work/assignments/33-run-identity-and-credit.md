# 33 — Bounded run identity and one completion command

Status: tracked in work/architecture/README.md. Dependencies: 32.
Review coverage: Finding 7 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: account_state credit methods; run start ID allocation; save migrations; snapshots. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Consolidate successful-run application into one command that validates the active run identity and atomically applies payout and commissioning. Replace the unbounded credited-ID collection with a persisted monotonic run sequence and a bounded committed marker suitable for one active run. Explicitly migrate existing saves: derive a safe next sequence from legacy generated IDs and active snapshot; reject stale/unknown completions instead of dropping deduplication protection. Keep migration code until old saves are supported.

## Acceptance checks

Thousands of sequential runs do not grow deduplication metadata. Repeated, stale, failed and mismatched results never award. Legacy saves with credited IDs and an active run migrate without replay; reload after completion remains idempotent. If legacy arbitrary IDs cannot safely map, preserve account and reject that active snapshot with a diagnostic.

## Stop boundary

No generalized event store or distributed transaction system. Never discard the old ID set before proving the migration preserves committed rewards.

## Completion note

Implemented in `account_state.gd`, `encounter_controller.gd`, `save_store.gd`, and `run_identity_credit_test.gd`. `AccountState.allocate_run_id()` owns persisted monotonic IDs; `complete_run()` is the single success command and requires the active run identity. New saves persist only `run_sequence` and `committed_run_id`; safely migrated `run-N` IDs are folded into the sequence, while arbitrary legacy IDs remain protected and invalidate unsafe active snapshots with a recovery diagnostic. Focused identity tests passed. The complete suite passed all 31 tests through `prototype/run_tests.ps1` with Godot 4.8.dev4. Existing legacy account round-trip behavior remains supported. No balance or gameplay rules changed.

