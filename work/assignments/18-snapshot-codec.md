# 18 — Encounter snapshot codec

Dependencies: 17. Status is tracked in ../README.md.

## Read first

Run model, actor/projectile/ability/spawner state and save contract. Always read work/PROTOTYPE.md and work/CONTRACTS.md; inspect only relevant source after that.

## Outcome

Define and test a serializable active encounter snapshot.

## Implement

Add stable actor IDs and export/import data methods where needed. Capture all fields listed in the shared contract, including cooldowns, windups, projectiles, spawn position/index and config IDs. Prefer deterministic spawning. Implement payload validation and a codec without hooking application close/load yet. Save schema can contain an optional snapshot.

## Acceptance checks

Round-trip a synthetic encounter containing damaged actors, an in-flight projectile, active dash, a ranged windup, and partial sealing. Reject invalid target IDs, phases, nonfinite positions/timers, and incompatible config versions. No snapshot parsing can award mana.

## Stop boundary

No lifecycle orchestration or broad scene architecture rewrite. Leave application recovery to card 19.

## Completion note

Implemented `prototype/scripts/model/run_snapshot.gd` with versioned `RunSnapshot.encode`, `decode`, and validation APIs. The payload captures resumable run state, actor/projectile IDs and target references, damaged health, cooldowns, ranged windups, active dash data, projectile motion/lifetime, spawner position/index/timer, and config IDs. Validation rejects invalid phases, duplicate IDs, unknown references, nonfinite vectors/timers, and incompatible snapshot/config versions. No snapshot parsing can credit mana because the codec has no account or payout mutation path.

Added `prototype/tests/snapshot_codec_test.gd`, which round-trips a synthetic partial-sealing encounter containing damaged actors, an in-flight projectile, active dash, ranged windup, and deterministic spawner state, then rejects invalid targets, phases, positions, owners, and config versions. Run `& $godot_console --headless --path '.\prototype' --script 'res://tests/snapshot_codec_test.gd'`; it exited 0. Manual verification is deferred because this card intentionally has no save/load or application lifecycle wiring; card 19 should map live nodes to these stable IDs and restore into a paused encounter.

