# 55 — Fresh 2D persistence and recovery

Status: tracked in work/2d/README.md. Dependency: 54.

## Read

Queue and predecessor; RunSnapshot, SaveStore, SessionPersistence, controller capture/restore boundaries, component methods, and persistence/recovery test matrix entries.

## Implement

Snapshot the integrated side-view state, including last-facing/dash direction, weapon cooldown/config, projectile velocity/lifetime/hit state, stable IDs, ranged windup/aim, and director timers/side sequence/pending warning entries. Keep a consistent Vector2 record for ground positions (constant lane y), separating decorative offsets from authoritative state. Do not persist redundant experiment pause/started flags. Restore through component owners and the single production scheduler. Compare recovery while moving left and right, mid-dash, during warning/windup, during Triple shot flight, and during sealing.

Enable persistence in the distinct 2D profile introduced in 50. Define a new snapshot/config identity with explicit two-component positions, velocities, directions, and required component state. Update validators, actor capture/restore, and fixtures together. No 3D-save importer or legacy spatial compatibility path is required. Remove obsolete 3D snapshot-specific conversion branches while retaining validation and current save failure protection.

Preserve account saves, offline production, checkpoints, retry-after-failure, stable run/actor IDs, paused restoration, and exactly-once credit through existing persistence owners. Do not wipe the former profile or weaken new-save correctness because old saves are disposable.

## Acceptance

- Fresh 2D save/relaunch loads account progress; active encounters restore paused with positions, cooldowns, windups, projectiles, and spawn state intact.
- Uninterrupted versus save/restore/resume runs agree on relevant combat/payout state under the common scheduler.
- Malformed/nonfinite/dimensionally invalid and old 3D snapshots are rejected before scene mutation.
- Failed save retry does not replay rewards/purchases/offline income; existing backup/recovery and clock protections hold.
- Restore all persistence and remaining deferred integration tests; use injected test stores only.

## Stop

No old save migration or deletion of real profiles.

## Completion note

Completed 2026-09-07.

- Enabled persistence in the distinct active 2D profile `user://telos_side_view_defense_experiment` using the existing `SaveStore` and `SessionPersistence` owners. Account mutations, exactly-once completion credit, periodic checkpoints, focus-loss, and orderly-close checkpoints use those owners; no old-save migration or real-profile reset was added.
- Added active 2D snapshot identity `prototype-2d-config-1` with two-component `[x, y]` positions and velocities. Snapshots include run state, hero facing, dash state, weapon accumulator/configuration, projectile travel/lifetime/hit state, actor IDs/cooldowns/windups, and director timers/index/side sequence/pending warnings.
- Added paused restore through the controller scheduler for hero, enemies, projectiles, cooldowns, windups, and director timing. Invalid snapshot data continues to be rejected before scene mutation by `RunSnapshot` validation.
- Restored `account_saves_test.gd`, `session_persistence_test.gd`, and `snapshot_codec_test.gd`; added `persistence_2d_test.gd`. Remaining 3D actor recovery-equivalence fixtures stay deferred and are not reported as passing.

Actual checks:

- `prototype/run_tests.ps1 -GodotPath .\\Godot_v4.8-dev4.exe\\Godot_v4.8-dev4_win64_console.exe`: all 18 active tests passed, including account saves, session persistence, 2D persistence round-trip, and 2D snapshot validation.
- Direct `persistence_2d_test.gd`: passed save, two-component schema encode/decode, paused restore, hero position, and facing checks.
- Active project import/boot and error scan: no errors found.
- Archive and accepted experiment remain unchanged; no legacy 3D save importer was added.

Remaining manual checks include GUI relaunch, focus loss, and recovery during mid-dash, ranged windup, Triple shot flight, and sealing. The deferred 3D recovery fixtures remain owned by later recovery work.
