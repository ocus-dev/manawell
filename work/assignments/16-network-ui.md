# 16 — Network UI and online production

Dependencies: 15. Status is tracked in ../README.md.

## Read first

Production public API, account mutation paths, preparation UI. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Wire central income into the running game.

## Implement

Add a small network panel showing each site's commissioning, guard, actual mana/min, and total rate. Credit through one production settlement path using monotonic elapsed time. Settle before every guard, research, and active-site mutation; save the updated account and timestamp consistently. Do not offer per-site collection clicks. Keep fractional bank internally.

## Acceptance checks

Guard one well while playing the other. Confirm only eligible sites earn, displayed rate matches observed accrual, pause earns normal real-time income, rapid panel toggling produces no extra money, and research changes do not retroactively increase earnings.

## Stop boundary

No offline catch-up, regional consolidation, auto-assignment, or charts.

## Completion note

Implemented online production in `prototype/scripts/game/encounter_controller.gd`, using `ProductionAccounting` for one settlement path and adding the collapsed NETWORK panel with per-site commissioning, guard, mana/min, and total-rate labels. Account bank is fractional; `SaveStore` schema 4 persists a monotonic production timestamp with the account. Settlement occurs before guard assignment/recall, pump research, active-site release, and each runtime tick. Added `prototype/tests/network_production_test.gd` for Hero 2 accrual and active-site exclusion; existing model, save, assignment, and startup checks still pass.

Verification: run `& $godot_console --headless --path '.\prototype' --script 'res://tests/network_production_test.gd'`. For the visible feature, unlock Hero 2, assign a guard, expand NETWORK, start an expedition at the other site, pause combat, and watch the bank/rates; collapse/reopen the panel to confirm no extra credit, then buy Pump and confirm only future accrual changes. Offline catch-up and charts remain deferred to card 17.

