# 13 — Commissioning and second well

Dependencies: 12. Status is tracked in ../README.md.

## Read first

Run result, saved account, balance definitions. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Unlock a second site through a successful first-site harvest.

## Implement

On successful extraction with at least one completed surge, commission the chosen well. First commissioning of well_1 unlocks well_2 and hero_2 as a roster record. Add a preparation selector with yield/danger summary and selected-well configuration. Reuse the arena. Second-well commissioning is independent. Save result credit and unlocks together.

## Acceptance checks

A failed run never commissions. A short early success does not commission. Qualifying success unlocks exactly once and survives restart. Well 2 extracts at twice base rate and uses its threat factors. Switching sites resets temporary state without losing bank.

## Stop boundary

No assignment UI, guard income, new map art, route stages, or distinct hero abilities.

## Completion note

Completed second-site commissioning. Extended `prototype/scripts/model/account_state.gd` and versioned saves with well unlocks, commissioned wells, and hero roster records. Added the atomic qualifying-success credit/commission path, with well 1 unlocking well 2 and hero 2 exactly once. Added the preparation selector and yield/threat summary in `prototype/scripts/game/encounter_controller.gd`; the selected well now configures run extraction, hero ID, and existing well 2 threat factors. Switching sites after a terminal run resets temporary state without changing bank.

Added `prototype/tests/two_wells_test.gd` covering failed and early successes, qualifying commissioning, idempotence, restart persistence, Well 2's 4 mana/sec output and threat factors, selector restrictions, and site switching. All existing tests, save/checkpoint tests, the two-well test, and main-scene startup exited 0. Assignment UI, guards/passive income, map art, route stages, and distinct hero abilities remain deferred.

