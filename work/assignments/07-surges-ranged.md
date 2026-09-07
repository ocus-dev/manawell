# 07 — Surges and ranged enemy

Dependencies: 06. Status is tracked in ../README.md.

## Read first

Balance definitions, extraction completed-tier logic, spawn/cleanup code. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Replace fixed spawns with the authored surge sequence and add ranged threats.

## Implement

Implement deterministic spawn points/order, spawn timer, tier composition, late-tier escalation, well difficulty factors, and live enemy cap from the compact spec. Add ranged enemy windup and projectile behavior. Spawning continues during SEALING but rewards stay locked. Display upcoming threat label; pressure uses simulation time.

## Acceptance checks

Verify four tiers and one repeat tier using accelerated test time or a developer fixture. Pause freezes spawns, projectiles, and windups. Spawn cap skips excess attempts without a later burst. Ranged attacks telegraph and can miss a moving player. Tier rewards change only when a pressure interval completes.

## Stop boundary

No procedural encounters, additional enemy species, or campaign stages.

## Completion note

Implemented the simulation-time spawn director in `prototype/scripts/game/encounter_controller.gd`, authored balance constants in `prototype/data/balance.gd`, ranged threats and projectiles in `prototype/scripts/game/ranged_enemy.gd` and `prototype/scripts/game/ranged_projectile.gd`, sealing combat continuation, and the upcoming-threat HUD label. Melee damage accepts late-tier and well-two multipliers. Added `prototype/tests/surges_ranged_test.gd` and updated the legacy melee lifecycle fixture for timed spawning.

Checks run with `Godot_v4.8-dev4_win64_console.exe --headless`: bootstrap, arena movement, run state, encounter, melee, automatic weapon, surges/ranged, and main-scene startup all exited 0 with no reported errors. Remaining limitation: visuals are primitive prototype geometry; no procedural encounters or additional enemy species were added.

