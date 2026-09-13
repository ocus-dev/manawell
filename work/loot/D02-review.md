# D02 review and handoff

Completed September 9, 2026. L01 is accepted as the isolated definition foundation with the corrections below. Production roll validation and persistence integration remain assigned to L02; live monster drops remain gated by D03.

## Verified and repaired

- Luna's focused definitions test, both inventory tests and all five research tests passed before review fixes.
- A real JSON round-trip failed with `instance schema version is invalid`: Godot parses JSON numbers as floats. Integral schema/level/tier numbers now validate, unknown schema versions and fractional integral fields reject. Copied implicit comparisons now handle equivalent JSON numeric representations without accepting changed values.
- Affix validation was nested inside the base loop, so an empty catalog accepted an invalid affix table. Moved it outside the loop and added a regression.
- The existing fractional-health test changed the base but retained weapon implicits, so it failed before reaching integer validation. Added a valid chassis fixture and then mutated only its health roll. Fractional percentage increases are valid even on stats whose flat modifiers require integers.
- The focused test now includes actual serialized JSON parsing, exact supported schema and fractional-level rejection. These are schema fixes only; no live equipment or combat values changed.

## Confirmed integration issues assigned forward

Reproduction in `work/reviews/loot_d02_audit.gd` with an injected account and saving disabled: research damage rank 1, shots rank 1, fan mode resolves 9.75 damage, then spawned projectile receives 6.3375. L04 must remove the second attenuation, with approved no-equipment value 9.75 and fixture coverage.

Source audit: RunSnapshot.encode omits controller-provided campaign/director sections. Controller snapshot capture uses base constants for weapon interval/max HP. SessionPersistence retries combine a captured snapshot with a live account reference. The new contract specifies complete frozen stats/world data and immutable coherent pending envelopes; these changes belong to L02/L04/L06 as described there.

## Authoritative next inputs

- [Approved tables](approved-tables.md): nine base implicits, eleven affixes, exact bounds/steps/weights, rarity, encounter levels, stat formulas, family tags and twelve slot/rarity fixtures.
- [Persistence contract](persistence-contract.md): versions, metadata, migration, frozen run state, RNG, bounded retired-ID ranges, checkpoint cadence, terminal ordering and failed-save behavior.

Vision/resistance/spell/jump affixes remain disabled until they have useful implemented consumers. Initial numerical balance is approved for implementation and measurement, not claimed final. D03 owns simulations and loot-economy approval; D04 owns human playtesting and hero/weapon/spell expansion.

Luna may now start L02 only. Its first checks must expand ItemDefinitions to validate the production tables/metadata and then implement instance saves against the exact contract. Do not restart L01 or implement the obsolete E02 design.
