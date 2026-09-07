# 20 — Two harvester loadouts

Dependencies: 19. Status is tracked in ../README.md.

## Read first

Active configuration, balance data, UI and snapshot version handling. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Add one simple pre-run tradeoff between output and protection.

## Implement

Keep standard available; grant overdrive and fortified when well 2 is commissioned. One selection per well, free to switch outside combat. Overdrive: +25% active extraction and pressure time advances 25% faster. Fortified: +50 maximum machine integrity and unchanged output/pressure. Research composes once. Store selection in account and resolved modifiers in snapshot. Show explicitly that passive rates do not change.

## Acceptance checks

Model/integration checks compare standard/overdrive pressure boundaries and tank, fortified max integrity, modifier composition, and no mid-run switching. Save/reload a modified run with the same stats. UI shows tradeoffs and unlock requirements.

## Stop boundary

No module inventory, multi-slot tree, salvage mechanic, or passive rebalance.

## Completion note

Implemented in `prototype/scripts/model/loadout.gd`, `prototype/scripts/model/account_state.gd`, `prototype/scripts/model/run_state.gd`, `prototype/scripts/model/run_snapshot.gd`, and `prototype/scripts/game/encounter_controller.gd`. Added per-well Standard, Overdrive, and Fortified selection with Well 2 commissioning gates, atomic account persistence, active-run-only modifiers, dynamic Fortified machine capacity, and snapshot-resolved pressure/output/capacity values. Passive production remains unchanged and the PREPARATION UI states that explicitly.

Added `prototype/tests/harvester_loadouts_test.gd`. It verifies unlock gating, save/reload selection persistence, Overdrive tank and pressure boundaries, Fortified capacity and unchanged output, pump composition, no mid-run switching, and snapshot round-trip. Also reran all 20 prototype tests and main-scene startup; every command exited 0. The malformed JSON diagnostic from `account_saves_test.gd` is intentional recovery coverage.

Manual verification: commission Well 2, select each loadout in PREPARATION, compare Standard and Overdrive tank/surge timing, then start Fortified and confirm the machine maximum is 225 while output and pressure remain baseline. Confirm the selector disables during combat and NETWORK passive rates stay unchanged. Loadouts affect active runs only; inventory, multi-slot modules, salvage, and passive rebalance remain out of scope.

