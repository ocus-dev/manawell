# L01 — Item and modifier definitions
Owner: Luna. Depends on D01. Ready to begin.

Read DESIGN.md, the existing item_catalog.gd, account_state.gd, inventory_panel.gd and work/inventory/IMPLEMENTATION.md.

Create isolated definitions and validators for base items, rarity, item levels, instances, typed modifier operations, modifier families and slot eligibility. Separate catalog IDs from instance IDs. Keep current live acquisition and UI unchanged; introduce no duplicate runtime inventory owner.

Represent Common/Magic/Rare/Epic with 0/1/2/3 explicit modifiers. Support authored implicits separately. Include fixtures of two instances sharing one base but carrying different rolls. Unknown IDs, duplicate instance IDs, nonfinite values, invalid rarity/level and repeated modifier families must fail validation. Integer-valued stats must reject fractional values.

Use clearly marked test-only affix tables to exercise schema validation; the primary assistant authors production ranges in D02. No live randomness, migration, equip actions or balance choices.

Acceptance: focused positive/negative validator tests, stable serialization fixture, current inventory and research tests still pass. Handoff includes schema examples and questions for D02. Update README status and stop.
