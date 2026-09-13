# L02 — Instance ownership, hero kits and persistence
Owner: Luna. Depends on approved D02 contracts.

Read DESIGN.md, approved-tables.md and persistence-contract.md, then account_state.gd, save_store.gd, session_persistence.gd, run_snapshot.gd and current inventory tests.

D02 is complete; read D02-review.md. Add the approved production tables and expand ItemDefinitions with metadata preservation, generation-version validation, exact roll ranges/steps and family stats before accepting production instances. The reviewed L01 JSON fixes must remain covered. Implement snapshot-v5's full codec shape with neutral current-game resolved values until L04; monster loot state remains disabled until L06. Snapshot capture fields and retry behavior must follow the immutable-envelope contract, not a copied snapshot plus live account reference.

Replace unique-base ownership with authoritative instance storage; per-hero weapon/chassis/module references point to owned instances. Enforce matching slot, one hero per instance, valid hero IDs, and no equip changes during an active/suspended run. Do not silently steal another hero's equipment. Include lock, inspect and discard commands; discard rejects equipped or locked items.

Implement the D02 migration/version rules, including deterministic one-time conversion of legacy ownership and New flags. Preserve bank/research/campaign and existing recovery handling. Until L06, route remaining fixed grants through an explicit transitional adapter so the prototype stays runnable without maintaining two independent owners. Adapt current inventory views minimally to display instances; visual redesign belongs to L07.

Acceptance: duplicate bases survive round-trip, equipped identity persists, malformed/dangling references reject, repeat migration is idempotent, failed-save retry preserves exact instances, old account fixtures load, suspended-version policy works. Inventory is capped at 100 with visible command failure; never truncate a loaded account silently. Record changed paths and actual checks; stop.
