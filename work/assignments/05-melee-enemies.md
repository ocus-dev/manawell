# 05 — Melee enemies and damage

Dependencies: 04. Status is tracked in ../README.md.

## Read first

Encounter controller, player, run-state damage API. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Add pursuers and machine-targeting breakers.

## Implement

Create two primitive enemy types with the compact spec stats. Move directly across the flat arena using simple collision. Pursuers target hero; breakers target machine. Damage only in attack range and on cooldown, never every frame. Spawn a small fixed test set when extracting starts. Share one enemy damage/death API for the next card. Clean actors on retry.

## Acceptance checks

Observe each target preference. Contact damage matches cooldown and pauses correctly. Hero or machine death ends combat. Retry ten times without accumulating enemies or stale callbacks. Enemy damage method removes a dead actor once.

## Stop boundary

No pathfinding system, wave director, ranged attacks, or loot.

## Completion note

Done. Added `prototype/scripts/game/melee_enemy.gd` with pursuer/breaker stats, direct movement, target-specific contact damage, cooldown attacks, pause/terminal checks, and shared `take_damage`/`die` behavior. The encounter controller spawns two pursuers and one breaker on extraction start and synchronously clears them before retry. Added `prototype/tests/melee_enemy_test.gd`; it exited `0` for target preference, cooldown, pause, death idempotence, and ten retry cycles. Existing project tests and scene startup remain passing. No pathfinding, waves, ranged attacks, loot, or enemy weapon system was added. Next card can call `take_damage` to remove an enemy exactly once.

