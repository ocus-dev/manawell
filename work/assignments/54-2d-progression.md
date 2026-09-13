# 54 — Progression and production integration

Status: tracked in work/2d/README.md. Dependency: 53.

## Read

Queue and predecessor; AccountState, ContentCatalog, ProductionAccounting, Loadout, controller command methods, operations UI, and progression integration tests.

## Implement

Use the integrated side-view build. Preserve stable IDs/costs; expose spread_1 as Triple shot per the queue and verify its real combat effect. Differentiate the two existing sites through modest palette/machinery indicators using current procedural resources, and show the selected hero/loadout without inventing new statistics, new wells, or new assets. Remove any remaining experiment-only session payout or fixed machine maximum that bypasses the account/loadout models.

Complete and verify existing two-well/two-hero progression against the 2D encounter. Wire well selection, commissioning, hero selection, explicit guard assignment/recall, upgrades, and Standard/Overdrive/Fortified loadouts. Preserve existing command legality and catalog-derived values, including Fortified integrity of 225. Reuse online production accounting and injected clocks; do not implement a second calculation in UI. Restore simple 2D indicators for upgrade/loadout state where needed.

## Acceptance

- A fresh in-memory journey completes a run, buys an upgrade, commissions/chooses wells, assigns a reserve hero, and starts another encounter.
- Damage/spread/pump upgrades and loadouts affect the next encounter correctly without double spatial conversion.
- Only eligible guarded non-active wells produce; pause does not duplicate settlement; refresh does not mutate money.
- Illegal commands fail without account mutation; success credit remains exactly once.
- Restore corresponding progression/production/domain/UI integration tests. Persistence/offline reload checks belong to 55.

## Stop

No new progression systems or changes to costs/rewards/unlocks.

## Completion note

Completed 2026-09-07.

- Wired the active 2D controller to canonical `AccountState`, `ContentCatalog`, `HarvesterLoadout`, and `ProductionAccounting` owners. Well selection, loadout selection, hero selection, guard assignment/recall, upgrade purchase, run IDs, and online settlement now use existing command/model rules without duplicate economy calculations.
- Active encounter setup now applies catalog well output, pump and damage upgrades, Standard/Overdrive/Fortified modifiers, Well 2 threat factors, and Fortified machine integrity of 225. Triple shot remains the card 53 same-lane three-projectile adaptation.
- Online production settles through `ProductionAccounting.settle()` with an injected `production_time_override` available to tests; the active well is excluded and UI refresh is read-only with respect to account funds. No persistence or offline reload behavior was added.
- Added `prototype/tests/progression_2d_test.gd` covering a fresh in-memory harvest that commissions Well 1/unlocks Hero 2, upgrade effects, hero/guard flow, Well 2 selection, Fortified integrity, illegal active-run loadout changes, active-well production exclusion, and refresh purity.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe`: all 16 active tests passed, including `progression_2d_test.gd`, the 15 prior lifecycle/surge/weapons tests, and model/UI coverage.
- Direct `progression_2d_test.gd`: passed `2D progression checks passed` with exit code 0.
- Active project boot/import diagnostics: no new script or resource errors.
- Archive remains unchanged; persistence/offline reload checks remain deferred to card 55.

No new wells, statistics, assets, costs, rewards, or progression systems were added. Native visual and focus checks remain pending for later acceptance.
