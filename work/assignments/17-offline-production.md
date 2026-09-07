# 17 — Offline production settlement

Dependencies: 16. Status is tracked in ../README.md.

## Read first

SaveStore, production helpers and online settlement path. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Credit capped absence exactly once on startup.

## Implement

Apply the saved-rate offline calculation with UTC watermark and 24-hour cap. Commit updated bank and watermark together before showing a return summary. Zero elapsed and backward clocks grant zero. Preserve the later watermark on backward time. Ensure startup does not also credit the offline interval through online timing. Surface failed persistence without re-awarding through repeated UI actions.

## Acceptance checks

Fake-clock integration checks: 1 hour, more than 24 hours, repeated load at same time, backward clock, no guards, two guards, and save failure/retry. Confirm fractional amounts survive reload. Manual restart summary agrees with the model.

## Stop boundary

No server clock, anti-cheat claims, real waiting tests, or changes to active encounter recovery.

## Completion note

Implemented startup offline settlement in `prototype/scripts/game/encounter_controller.gd` using the saved UTC production watermark, the 24-hour cap, and `ProductionAccounting.offline_settlement`. Updated `SaveStore` schema 4 handling to preserve the watermark, kept fractional bank values through reload, and added a visible NETWORK retry action for failed persistence. Offline credit is committed with the new watermark before the return summary is shown; pending intervals are blocked from live settlement until retry succeeds.

Added `prototype/tests/offline_production_test.gd` covering one-hour recovery, the 24-hour cap, repeated-load idempotence, backward clocks, no guards, two-guard rate math, and save failure/retry. Run `& $godot_console --headless --path '.\prototype' --script 'res://tests/offline_production_test.gd'`; it exited 0. Manual verification: assign a guard, restart after elapsed time, compare the NETWORK summary to the rate, restart again at the same timestamp, and exercise **Retry offline settlement** after a temporary save failure. Server time, anti-cheat, and active encounter recovery remain out of scope.

