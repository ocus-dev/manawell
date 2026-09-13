# L06 — Monster drops and secure collection
Owner: Luna. Depends on D03 approval plus L02–L05.

Implement the reviewed transaction in the actual death path. Current melee_enemy.gd queues itself for deletion at zero HP; all projectile and pulse kills must converge on one death event before disposal. Cleanup/despawn must not grant rewards. Attribute eligible kills to the active expedition, using stable run/enemy identities.

Auto-collect exact generated instances. Record no-drop outcomes too. Wire RNG/processed identities/account instances/matching world state to the existing envelope and retry path exactly as specified in persistence-contract.md. Process a boss's kill reward before the terminal result commits. Failure or abandonment retains already secured loot. Cap feedback must not pause the game.

At this cutover remove new fixed campaign item grants and first-clear reconciliation. Do not delete already migrated items. Results report this expedition's recovered instances; reopening results never grants anything. Update old fixed-drop tests to assert their explicitly retired behavior, retaining migration tests.

Acceptance: projectile, pulse, simultaneous damage, boss, death replay, no-drop reload, save failure/retry, death-then-failure, abandon, suspend/resume, full inventory, summons, cleanup and repeat campaign runs. Verify one coherent snapshot prevents rerolls/duplication after restart. Record limitations honestly; stop.
