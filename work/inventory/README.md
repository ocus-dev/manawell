# Items and inventory — Luna queue

> Superseded plan: the user has clarified that items should come from repeatable monster drops with rarity and individually rolled stats. Follow [Monster loot and hero builds](../loot/README.md) for new work. The E01–E06 cards below are historical; do not implement their unique-base ownership, fixed first-clear acquisition or shared-kit assumptions. Existing collection behavior remains live until the new queue's migration and cutover.

Collection and first-clear drops are implemented; equipment remains planned. See [implementation handoff](IMPLEMENTATION.md) before starting a card below. This follows the research-tree plan. **Research is permanent capability; equipment is a reversible build choice; inventory records owned items.** Do not turn research nodes into physical items or replace existing harvester loadout policies with inventory records.

## First playable scope

An account-wide collection with three equipment slots in one **active expedition kit**:

- Weapon core: affects the active hero's weapon.
- Hero chassis: affects the active hero's survival/mobility.
- Harvester module: affects the active machine in well encounters only.

The kit follows the selected active hero; it is not per-hero or per-well equipment. This deliberately avoids item ownership conflicts with assigned guards. Equipped items have **no passive/offline income or guard effects** in this slice. Existing well policies (Standard/Overdrive/Fortified), researched weapon modes and harvester specializations remain separate selectors and apply through one resolver. Clearly label all of these in the UI.

Use fixed authored items, one owned copy per definition. No random stat rolls, rarity tiers, durability, inventory capacity, weight, consumables, stack splitting, selling, salvage, crafting or world pickups yet. The modest collection is a filtered icon grid, not a spatial packing puzzle. Empty slots are valid and give no modifiers. Items are never consumed or lost on failure. Equip/unequip is free outside active/suspended runs.

### Initial nine-item collection

Provisional values: tune against the research baseline; each item trades a benefit for a cost. IDs below are stable. Research caps still apply to research ranks; equipment modifies resolved stats afterward with explicit safety bounds.

| Item ID / name | Slot | Benefit / cost |
|---|---|---|
| `core.heavy_breech` / Heavy Breech | Weapon | ×1.20 projectile damage, ×0.90 attacks/sec |
| `core.cycler` / Cycle Driver | Weapon | ×1.20 attacks/sec, ×0.90 projectile damage |
| `core.accelerator` / Long Accelerator | Weapon | ×1.35 projectile speed, ×0.90 attacks/sec; no extra range |
| `chassis.bulwark` / Bulwark Plating | Hero | ×1.25 maximum HP, ×0.90 horizontal move speed |
| `chassis.runner` / Runner Frame | Hero | ×1.15 horizontal move speed, ×0.90 maximum HP |
| `chassis.jump_servos` / Jump Servos | Hero | ×1.12 jump takeoff-speed magnitude, ×0.90 maximum HP |
| `module.high_volume` / High-volume Cylinder | Harvester | ×1.20 mana/cycle, ×0.90 cycles/sec |
| `module.fast_cycle` / Fast-cycle Rotor | Harvester | ×1.20 cycles/sec, ×0.90 mana/cycle |
| `module.bracing` / Anchor Bracing | Harvester | ×1.25 machine maximum integrity, ×0.90 active mean extraction output |

The two pump modules have equal theoretical throughput (1.08×), different cadence/feedback, and no hidden efficiency distinction; document this honestly. Research specializations provide the larger strategic distinction. Jump magnitude is applied to the negative takeoff velocity correctly; preserve buffer/coyote/release behavior and test platform boundaries. Neither movement item changes dash speed/cooldown unless explicitly authored later.

## Acquisition

Award one fixed item on each Act 1 node's **first successful completion**, using current stable campaign node IDs. Initial schedule:

1. Heavy Breech; 2. High-volume Cylinder; 3. Bulwark Plating; 4. Cycle Driver; 5. Fast-cycle Rotor; 6. Runner Frame; 7. Long Accelerator; 8. Anchor Bracing; 9. Jump Servos.

All are optional equipment; campaign traversal must work without the boss reward's jump bonus. Wells grant only when commissioning qualifies as a level clear. Failure, early non-qualifying extraction and repeated result delivery grant nothing. Replay gives existing encounter rewards but no additional copy or conversion payout. Grant items atomically with the existing validated completion commit, never when the results panel opens. Do not auto-equip rewards; show New until inspected.

For profiles that already completed nodes, reconcile missing deterministic first-clear items once from authoritative saved completion flags. With unique collection ownership this is idempotent and requires no replay. Do not trust art overlays or inferred well rates as evidence of completion. Add new inventory fields without discarding bank, research or campaign progress; validate corrupt data rather than silently repairing arbitrary unknown items.

## Implementation order

| Card | Deliverable | Depends on | Status |
|---|---|---|---|
| [E01](E01-item-contract.md) | Catalog, item/stat contract and acquisition schedule | Research R01 contract; current campaign audit | TODO |
| [E02](E02-ownership-save.md) | Collection, equipment legality and persistence | E01; research R02 save changes complete | TODO |
| [E03](E03-item-rewards.md) | First-clear grants and existing-profile reconciliation | E02; real campaign terminal routing available | TODO |
| [E04](E04-runtime-effects.md) | Equipment effects in shared resolved run stats | E02; research R03/R04 complete, shared files idle | TODO |
| [E05](E05-inventory-ui.md) | Compact collection, equip actions and comparisons | E03/E04; research R05 UI available | TODO |
| [E06](E06-acceptance.md) | Campaign, save, platforming and build verification | E05 | TODO |

E01 can author isolated definitions while research proceeds. Shared account/save/controller/UI edits must be serialized with active research/campaign/animation work. Inspect latest handoffs; do not mark other queues complete or create a second stat resolver because the first is still being built. No requirement to wait for polished item art: reuse the icon manifest/fallback contract from `work/ui-assets/README.md`.

## Luna prompt

> Implement only work/inventory/E01-item-contract.md. Read work/inventory/README.md, the assigned card and relevant current research/campaign contracts. Inventory is a new fixed-item collection and active expedition kit, not research ownership or a replacement for well policies. Keep to the card's scope and coordinate shared files with ongoing work. Run the acceptance checks, update this queue's status and a short completion note, then stop. Do not spawn agents, create tasks or implement later cards.

Use Luna in task settings; replace the card path as dependencies complete. Statuses TODO / IN PROGRESS / DONE / BLOCKED. These are repository instructions, not dispatched tasks.

## Later, after the collection is useful

Consider instance-based rare drops, crafting and materials, consumables, saved named kits or dedicated guard equipment. Each requires an explicit follow-up design. Do not add empty tabs, unused currencies or nonfunctional buttons for them now.
