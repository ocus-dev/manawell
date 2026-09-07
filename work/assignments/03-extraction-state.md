# 03 — Extraction state and payout

Dependencies: 01. Status is tracked in ../README.md.

## Read first

Shared contracts; balance section of compact spec; test runner. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Implement the scene-independent extraction state machine.

## Implement

Create run_state.gd and balance data. Implement phases, damage targets, tank accrual, completed surge multipliers, payout locking, sealing, failure, abandon, and reset. Expose a terminal result with run ID; no persistent bank yet. Keep death-before-completion ordering explicit in the caller contract. Support both 0 and 2 second sealing.

## Acceptance checks

Headless checks: no accrual in READY or pause; exact surge boundary; harvest freezes payout; sealing completes once; lethal damage prevents credit; repeated harvest ignored; abandon loses tank; reset clears temporary state; invalid/negative/nonfinite inputs cannot corrupt state.

## Stop boundary

No scene wiring, UI, spawning, purchases, or save files.

## Completion note

Done. Added `prototype/data/balance.gd`, `prototype/scripts/model/run_state.gd`, and `prototype/tests/run_state_test.gd`. The model implements temporary run phases, surge multipliers, tank accrual, payout locking, 0/2 second sealing, damage failure, abandon, reset, terminal results, and invalid-input guards without scene or save wiring. The focused state test exited `0`; the existing bootstrap, arena movement, and main-scene checks should remain the regression commands. Public API: `start`, `advance`, `request_harvest`, `apply_damage`, `abandon`, `reset`, `get_terminal_result`; callers apply damage before `advance` for death-before-seal ordering. No persistent bank, UI, spawning, or scene integration was added.

