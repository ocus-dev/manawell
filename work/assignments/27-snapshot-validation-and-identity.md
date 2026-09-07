# 27 — Snapshot validation and stable IDs

Status: tracked in work/architecture/README.md. Dependencies: 26.
Review coverage: Finding 4 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: run_snapshot.gd; actor spawn/prune code; existing snapshot tests. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Validate external section/field types before defaulting or normalization. Validate known kinds/IDs, boolean fields, required hero/machine records and references. Allocate actor/projectile IDs at creation from a monotonic encounter counter; persist and restore the next counter. Never derive identity from array position. Introduce a version change only where the payload changes and an explicit policy for older snapshots.

## Acceptance checks

Wrong nested types return invalid results without SCRIPT ERROR. Kill/prune/spawn repeatedly and verify unique IDs before and after recovery. Invalid references and duplicate hero/machine records are rejected. Unsupported snapshots preserve banked account data and yield a clear diagnostic.

## Stop boundary

Do not implement missing weapon or enemy fields yet. Legacy snapshots whose IDs can be safely retained may migrate; otherwise discard only the active snapshot with an explanation, never the account.

## Completion note

Completed. `RunSnapshot` now emits version 2 payloads, validates nested types before normalization, known actor kinds, typed booleans/IDs, hero/machine uniqueness, projectile references, and `spawner.next_id`. Version-1 snapshots migrate only through the safe legacy path: existing IDs are retained and new `entity-N` IDs use a separate namespace; malformed or unsupported active snapshots are rejected without replacing banked account data. `EncounterController`, `AutoWeapon`, and `RangedEnemy` allocate actor/projectile IDs at creation, persist the counter, and restore it without reconstruction side effects. Added `snapshot_validation_identity_test.gd` for malformed sections, invalid references, duplicate records, prune/respawn uniqueness, and recovery. Updated the codec fixture for required records. Full 25-test suite passes; diagnostics and `git diff --check` pass. Remaining limitation: weapon-specific snapshot fields remain deferred to assignment 28.

