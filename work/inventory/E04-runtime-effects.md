# E04 — Equip builds through the shared resolver

Depends on E02, research mechanics R03/R04 and idle shared files. Feed kit modifiers into the shared research resolver, then capture final stats and item IDs at run start. No per-frame account reads and no mid-run equipment changes. Snapshot codec must validate and restore resolved HP/integrity, movement/jump, weapon and harvest fields; avoid recomputing a suspended run under a different kit/catalog.

Apply weapon cores to player projectiles only; keep acquisition range and maximum travel distance independent of speed. All 1/3/5 Fan projectiles receive the correct per-projectile factor once; Lance retains its hit-count/rate rules. Hero HP initializes to resolved maximum on a new run, not as an extra heal action. Bulwark/Runner affect ordinary horizontal movement only. Jump Servos change takeoff-speed magnitude while preserving release, collision, buffer and coyote rules; avoid changing level geometry to require the upgrade.

Harvester modules act only on real active well encounters. Bracing changes machine max integrity and output; pump modules compose with researched cycle stats and specialization once. No guard/passive/offline rate changes from any equipment. Monster/boss encounters ignore the harvester slot. Existing well policies remain functional.

Acceptance: no-item baseline, every modifier/tradeoff, combinations at max research, snapshot round-trip, no hostile-projectile effects, unchanged passive income, no double-application and minimum/maximum stat bounds. Check platforming recovery/bounds with both movement and jump equipment. Completion note: pending.
