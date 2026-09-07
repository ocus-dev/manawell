# 06 — Automatic weapon

Dependencies: 05. Status is tracked in ../README.md.

## Read first

Player, enemy damage interface, encounter cleanup. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Let the hero automatically shoot nearby enemies.

## Implement

Acquire nearest living enemy within range. Use a visible projectile with speed, damage, collision ownership, and finite lifetime. Damage at most one enemy once per projectile; ignore hero and machine. Do not fire in READY, paused, or terminal phases. Keep shot angles extensible for the later spread upgrade.

## Acceptance checks

Kill both enemy types. Confirm no fire outside range, no double hits, no targeting freed actors, and cleanup on retry. Compare attack cadence at different frame rates using elapsed-time logic. Test projectile hit-once behavior with a focused fixture.

## Stop boundary

No manual aiming, equipment inventory, or multiple weapons.

## Completion note

Done. Added `prototype/scripts/game/auto_weapon.gd` and `prototype/scripts/game/projectile.gd`, plus weapon balance constants and `prototype/tests/auto_weapon_test.gd`. The hero now acquires the nearest living enemy within range and fires visible swept projectiles on elapsed-time cadence; projectiles ignore non-enemies, hit at most once, expire, and are cleared on retry/terminal states. The focused test exited `0` for both enemy kills, range and phase gating, pause, freed targets, hit-once behavior, and different frame cadence. Existing project tests and scene startup remain the regression checks. No manual aiming, inventory, or multiple weapons were added.

