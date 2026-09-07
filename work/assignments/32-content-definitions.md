# 32 — Consolidate content definitions

Status: tracked in work/architecture/README.md. Dependencies: 31.
Review coverage: Finding 7 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: balance.gd; account validation; production; spawn rules; HUD summaries. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Add a small typed definition catalog for the existing two wells, two heroes, upgrades and authored surge rules. Make known-ID validation, production output, labels, roster lists and spawn lookup consume it. Keep values equal to the current implementation: this is not the balance pass. Derive descriptive UI values from definitions. Remove superseded duplicate constants/branches once migrated.

## Acceptance checks

Record baseline numeric definitions and verify migrated production/weapon/spawn/loadout values remain equal. A synthetic extra definition in a test is recognized by lookup/validation/UI data generation without adding runtime content. Unknown IDs fail safely. Existing two-well progression tests pass.

## Stop boundary

No new region, hero, currency, plugin loader, external content format or tuning. Note existing concept-versus-code differences rather than changing them.

## Completion note

Added `ContentCatalog` with injectable well, hero, upgrade, and authored surge definitions. Account validation accepts an optional catalog for controlled synthetic content; runtime production, active extraction, well summaries, hero selectors, spawn intervals, surge composition, and well damage factors now consume the default catalog. Existing values remain unchanged: well output 2/4, Well 2 spawn factor 0.8 and damage factor 1.25, upgrade costs 40/60/100, and authored tier rules. Added `content_catalog_test.gd` covering synthetic lookup, UI-data IDs, injected validation, and default unknown-ID rejection. The full 30-test suite passed with no diagnostics or diff-check errors. Remaining limitation: the two-well progression unlock rule remains intentionally authored to the current runtime content; external content loading is out of scope.

