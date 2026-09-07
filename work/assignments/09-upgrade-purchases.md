# 09 — Upgrade purchases

Dependencies: 08. Status is tracked in ../README.md.

## Read first

Account credit method, balance data, weapon and extraction configuration. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Make banked mana buy three visible improvements.

## Implement

Add damage_1, pump_1, and spread_1 with costs/effects from the compact spec. Purchase only outside runs; validate cost and ownership atomically. Show cost, effect, affordability, and owned state. Apply modifiers at next run start. Spread fires three distinct projectiles. Add a primitive machine addition for pump research.

## Acceptance checks

Focused tests reject insufficient funds and duplicate purchases; exact funds succeed once. Failed extraction does not erase upgrades. Observe damage, output, and three-shot spread effects in a fresh run. Retry retains account changes without stacking them again.

## Stop boundary

No repeatable levels, full tree, permanent disk save, or random shop.

## Completion note

Implemented atomic one-time `AccountState.purchase_upgrade` and `has_upgrade` APIs for `damage_1`, `pump_1`, and `spread_1`. Added outside-run HUD purchase controls with cost, effect, affordability, and owned state. Damage and spread apply to the automatic weapon at the next run start; pump output applies to the next run's extraction rate. Spread fires three distinct projectiles, and pump adds a primitive machine research visual. Retry preserves ownership without stacking effects.

Checks run with `Godot_v4.8-dev4_win64_console.exe --headless`: bootstrap, arena movement, run state, encounter, melee, automatic weapon, surges/ranged, player abilities, upgrade purchases, and main-scene startup all exited 0 with no reported errors. Remaining limitation: upgrades are in-memory only until the persistence card.

