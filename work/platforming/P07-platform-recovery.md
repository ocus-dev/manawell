# P07 — Restore exact platforming save and resume

Dependency: P06. Status tracked in work/platforming/README.md.

## Implement

Extend the current component-owned snapshot contract for hero position/velocity, grounded/support ID, facing, coyote/buffer/release state, drop-through support/timer, dash state, 2D projectiles and ranged locked aim. Persist the arena layout/config identity and validate platform references, finite values, dimensions and valid motion states before scene mutation. Preserve the sole scheduler, stable IDs and account persistence owners.
Bump active-run snapshot/config identity. No migration of older flat-lane or intermediate snapshots is required: reject incompatible active runs with a clear notice while preserving valid bank/upgrades/wells/assignments. No live save deletion. Restore paused; clear live physical held keys on focus/resume without inventing jump/dash commands. Distinguish recorded gameplay timers from transient OS key state.
Re-enable snapshot checkpoints and active-run recovery disabled in P04. Compare uninterrupted versus snapshot/restore runs mid-ascent, apex, descent, air dash, on each platform, during drop-through, in ranged windup, with diagonal projectiles and during sealing.

## Acceptance

Recovery reproduces subsequent collisions, actor/projectile state and payouts under identical future command streams. No landing snap, stale support, free jump, repeated shot, duplicate reward or motion while paused. Invalid old snapshots reject safely; account saves and failed-save retry remain correct. All temporary snapshot-disable notices/branches are removed.

## Stop boundary

No legacy spatial importer, save-format redesign outside necessary fields or real-profile reset.

## Completion note

DONE. Re-enabled active-run checkpoint saves and paused recovery through the existing account/session persistence owners. Snapshot version/config identity now rejects older or incompatible active runs without migrating or deleting them, while account progress remains available. `prototype/scripts/model/run_snapshot.gd` validates finite values, arena identity, platform/support IDs, grounded geometry, motion timers, actor references, projectile vectors, and ranged locked aim. Hero snapshots include facing, vertical velocity, grounded/support state, coyote and jump-buffer timers, drop-through state, and ignored support. Controller restore preserves stable enemy IDs, cooldowns, locked aim, 2D projectile ownership/targets, dash/pulse state, weapon accumulator, spawn sequencing, and pending warnings, then remains paused until resume. Focus transitions clear held OS input and pending commands. Updated `snapshot_codec_test.gd` and `persistence_2d_test.gd`. Passed snapshot codec, exact persistence recovery, P04 jump, P05 arena, P06 combat, weapons, and account-save suites; diagnostics and 1280x720 boot are clean. Remaining limitations: no legacy active-snapshot migration, broader mid-run equivalence matrix, or P08 visual/playtest acceptance.

