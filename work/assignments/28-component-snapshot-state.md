# 28 — Component-owned snapshot state

Status: tracked in work/architecture/README.md. Dependencies: 27.
Review coverage: Finding 4 in work/reviews/architecture-review.md.

## Read first

Read work/architecture/README.md, then only the relevant section of the review, predecessor handoff, and these files: player/enemy/weapon/projectile scripts; snapshot assembler and restore code. Source paths are relative to the repository; use the actual names established by predecessors when files have moved.

## Implement

Give stateful components small explicit capture/restore methods or typed records. Move private-field knowledge out of controller reconstruction. Capture weapon damage/spread/timing, all friendly and hostile live projectiles, resolved enemy damage scaling, attack windups, movement/ability state and spawn state. Assemble records centrally and restore through a small factory by known kind. Choose one documented world/local coordinate convention and use it consistently for projectile spawn, update, and restore. Keep live projectiles registered until expiry instead of retaining only the latest hostile shot.

## Acceptance checks

Round-trip upgraded spread/damage and partial weapon cooldown; scaled enemies retain exact damage; friendly and multiple hostile projectiles retain positions/velocity/life. Test non-origin actor positions so coordinate mistakes cannot hide. Component records validate before mutating a live scene.

## Stop boundary

No new projectile targeting, collision design, or enemy behavior. Do not silently invent missing legacy state: use the policy from 27. Keep renderer-only transient effects optional.

## Completion note

Implemented component-owned v3 snapshot state in `encounter_controller.gd`, `run_snapshot.gd`, `player.gd`, `auto_weapon.gd`, `melee_enemy.gd`, `ranged_enemy.gd`, `projectile.gd`, and `ranged_projectile.gd`. Components expose `capture_snapshot_state()` and `restore_snapshot_state()`; the controller assembles known actor/projectile records and preserves world-space projectile positions, weapon timing, enemy scaling, and all live hostile shots. Incomplete legacy records fail validation instead of receiving invented component defaults. Added `component_snapshot_test.gd` covering upgraded spread/damage, partial cooldown, non-origin positions, scaled enemies, one friendly shot, and multiple hostile shots. Focused checks passed: `component_snapshot`, `snapshot_validation_identity`, `suspend_resume`, `harvester_loadouts`, and `single_scheduler`. The full suite passed after the final compatibility fix. Remaining limitation: renderer-only transient effects are intentionally not persisted.

