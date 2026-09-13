# L08 Acceptance Evidence

Status: partial acceptance. The seeded end-to-end harness passes, but the full evidence set is not complete because `encounter_test.gd` times out and live performance metrics have not been collected.

## Commands and results

All commands ran headless from the repository root with an isolated controller fixture (`persistence_enabled = false`); no user profile was overwritten.

- `res://tests/l08_acceptance_test.gd` — PASS. Covers a well success, ordinary enemy kill and automatic collection, inspection/equip, effective stat change, save-payload reload, boss collection, failed-run retention, retry, and paused snapshot capture.
- `res://tests/loot_generator_test.gd` — PASS. Determinism, resume state, no-roll paths, schema, rarity counts, and bounds.
- `res://tests/loot_generator_simulation_test.gd` — PASS. Fixed-seed 100,000-kill ordinary and boss runs.
- `res://tests/loot_persistence_test.gd` — PASS. Production tables, duplicate instances, kit legality, lock/discard, migration, and immutable retry.
- `res://tests/loot_kill_rewards_test.gd` — PASS. Exact collection, duplicate protection, deferred death, retired ledgers, and no fixed campaign grants.
- `res://tests/loot_runtime_stats_test.gd` — PASS. Runtime stat routing and snapshot fields.
- `res://tests/inventory_drops_test.gd` — PASS. Failure retention, duplicate commits, replay, inspect, validation, legacy reconciliation, disk persistence, and failed-save retry.
- `res://tests/inventory_ui_test.gd` — PASS. Real selection across refresh, filters, and persistent controls.
- `res://tests/inventory_l07_test.gd` — PASS. Duplicate instances, equip, lock/discard confirmation, and 100-item capacity.
- `res://tests/account_saves_test.gd` — exit 0.
- `res://tests/campaign_state_test.gd` — PASS (`Campaign state checks passed`).
- `res://tests/persistence_2d_test.gd` — PASS (`2D persistence checks passed`).
- `res://tests/snapshot_codec_test.gd` — exit 0.
- `res://tests/session_persistence_test.gd` — exit 0.
- `res://tests/run_identity_credit_test.gd` — exit 0.
- `res://tests/research_resolver_test.gd` — exit 0.
- `res://tests/research_purchases_test.gd` — exit 0.
- `res://tests/surge_2d_test.gd` — PASS (`2D surge checks passed`).
- `res://tests/platform_arena_test.gd` — PASS (`P05 platform arena checks passed`).
- `res://tests/encounter_test.gd` — unresolved: timed out during the regression batch and again during an individual 20-second run.
- `res://tests/production_test.gd` — exited without a reported PASS line; result needs a focused rerun before claiming coverage.

## Acceptance coverage

The existing focused regressions cover corrupt/invalid item validation, legacy profile migration, repeated death/result protection, failed persistence retry, no-drop and replay-safe state, full storage, two-hero kit legality, and unauthorized equip/discard rejection. These are regression-level checks, not a substitute for manual playtesting.

The L08 harness uses a seeded ordinary drop constrained to a weapon base so the stat-change assertion observes an authored combat effect. It reloads the complete saved item payload and compares the opaque instance record. The boss path verifies collection after the boss death queue is processed.

## Seeded balance evidence

`loot_generator_simulation_test.gd` uses 100,000 kills per scenario.

| Scenario | Seed | Threshold | Drops | Drop rate |
|---|---:|---:|---:|---:|
| Ordinary, no bonus | 324508639 | 200 | 1,994 | 1.994% |
| Boss, 50% bonus | 610839777 | 3,000 | 29,921 | 29.921% |

Ordinary rarity counts: common 1,232; magic 560; rare 170; epic 32.

Boss rarity counts: common 18,034; magic 8,814; rare 2,750; epic 323.

Ordinary slot counts: weapon 675; hero 660; harvester 659.

Boss slot counts: weapon 9,902; hero 9,995; harvester 10,024.

The run reports deterministic build-input examples and final RNG states. It does not currently report longest dry streak, streak percentiles, duplicate-base frequency, inventory growth over time, kills/minute, items/minute by live encounter timing, save/checkpoint cost, or frame-time impact at 0/50/100 items. Those remain required before D03 evidence can be considered complete.

## Captures and manual route

No screenshots were captured in this headless pass. The short manual route is: start an ordinary campaign node, kill an enemy, open Inventory, select the new item, inspect its modifiers, equip it to the active hero, confirm the stat preview changes, leave the node and reload; repeat once by taking lethal damage, then pause after retry and resume from the saved snapshot. Repeat the ordinary route at the well and act boss.

## Remaining defects and risks

- `encounter_test.gd` timeout blocks a clean full regression claim and should be diagnosed before L08 closes.
- `production_test.gd` needs a focused result check because it exited without a PASS line.
- Live kills/minute, timed item rates, dry-streak statistics, save/checkpoint timing, and frame-time comparisons are not measured.
- No 1280x720 or 1920x1080 screenshot review was performed in this pass.
- Automated checks do not establish final balance or fun. D03 assumptions should remain open until timed gameplay and build-comparison evidence exists.

L09 was not started.
