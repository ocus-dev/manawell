# Monster loot and hero builds

This queue supersedes the unimplemented E01–E06 equipment plan in `work/inventory`. The existing inventory/drop foundation is implemented and should be extended, not rebuilt. This document creates assignments only; no tasks have been dispatched and no gameplay values changed.

## Direction

Grinding monsters produces low-probability, individually rolled equipment. Multiple copies of the same base can coexist with different rarities and modifiers. Rarity controls modifier count; item level controls eligible modifier strength. Higher rarity offers more possibilities, not an automatic upgrade for every build.

The first milestone is one complete loop: kill → roll → collect automatically → retain → inspect → equip → observe changed hero stats → resume safely. Physical pickups, crafting and legendary powers come later.

## Responsibility split

Lead design/review work stays with the primary assistant: stat meanings, stacking, loot economy, exploit analysis, hero identity, encounter tuning and release review. Luna implements bounded contracts and supplies measured evidence. Luna should not invent balance rules to close gaps.

| Card | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| D01 | Primary assistant | Initial system decisions in [design contract](DESIGN.md) | Current-code review | DONE — provisional tuning |
| [L01](L01-definitions.md) | Luna | Instance and affix definitions; validation | D01 | DONE — schema and focused validators |
| [D02](D02-review.md) | Primary assistant | Exact affix tables, stat routing, snapshot/transaction specification | L01 | DONE — implementation contracts approved |
| [L02](L02-persistence.md) | Luna | Inventory instances, per-hero kit and save migration | D02 | DONE — instance persistence and v5 snapshot codec |
| [L03](L03-stat-resolver.md) | Luna | Pure resolved hero stats and equipment preview | L02 | DONE — pure resolver, slot comparison and focused acceptance test |
| [L04](L04-runtime-stats.md) | Luna | Damage, defense, movement, regeneration and active mining integration | L03 | DONE — frozen runtime builds, approved routing and resume fields |
| [L05](L05-loot-rolls.md) | Luna | Deterministic drop and affix generator | D02; sequence after L04 | DONE - pure `loot-v1` generator, focused checks and reproducible 100,000-kill evidence in [L05 evidence](L05-evidence.md) |
| [D03](DESIGN-REVIEWS.md#d03-loot-and-build-balance) | Primary assistant | Review simulations and approve first playable loot tuning | L04, L05 | TODO |
| [L06](L06-kill-rewards.md) | Luna | Kill rewards, persistence and resume safety | D03 | IN PROGRESS — core transaction path and focused checks implemented |
| [L07](L07-inventory-experience.md) | Luna | Instance inventory, equip comparisons and compact drop feedback | L06 | IN PROGRESS — inventory and character-sheet slice implemented |
| [L08](L08-acceptance.md) | Luna | Integration, performance and playtest evidence | L07 | PARTIAL — seeded acceptance harness and regression evidence recorded; encounter timeout, timing metrics and captures remain open |
| [D04](DESIGN-REVIEWS.md#d04-playable-review-and-next-design) | Primary assistant + user playtest | Tune feel; design hero identities, spells and weapon families | L08 | TODO |
| [L09](L09-hero-loadouts.md) | Luna | Approved hero identities, weapon/spell choices and later affixes | D04 | TODO — separate expansion |

Proceed in table order. D02/D03/D04 are concrete design work, not requests for another permission round. Return their evidence to the primary assistant rather than asking Luna to guess. Keep shared account/controller/UI changes sequential. Do not spawn agents or create tasks automatically.

## First milestone scope

- Shared stash; per-hero weapon, chassis and utility-module slots. A module belongs to that hero's expedition kit and may improve active well harvesting. Each instance can be equipped by only one hero.
- Common, Magic, Rare and Epic items; authored base definitions and restricted affix pools. Duplicate bases are valid.
- Repeatable monster drops. No guaranteed campaign item grants or automatic first-clear backfill after cutover. Already owned items receive deterministic legacy instances once.
- Automatic collection at the kill; secured items survive later failure/abandonment. Mana retains its existing extraction risk. Clearly tell the player this distinction.
- Equipment effects apply only to the active hero/run. Assigned guards and offline production remain unchanged.
- Attack, defense, maximum health, movement, vision, regeneration, active mining, enemy-family advantage, elemental resistance and drop chance have explicit contracts. Only affixes with a working gameplay consumer may enter live drop pools.
- A maximum of 100 stored instances in this prototype, with no loss of an equipped or locked item. At capacity, skip the item roll, preserve the random sequence for the next eligible kill, and show a throttled 'Inventory full' notice. L07 supplies explicit discard controls; there is no auto-salvage currency.

Spells and weapon families are build choices in L09, not generic numeric stats. Legendary/unique effects require authored mechanics and a later balance review. Do not implement procedural affix text as executable behavior.

## Prompt for Luna now

> Implement only work/loot/L02-persistence.md. Read work/loot/README.md, work/loot/D02-review.md, work/loot/approved-tables.md and work/loot/persistence-contract.md first. L01 is complete and reviewed; extend its schema to the approved production contract. Implement instance ownership, per-hero kit legality, save migration and coherent snapshot/retry support. Keep current gameplay runnable through the transitional first-clear adapter; do not enable monster loot or equipment combat effects yet. Do not implement later cards, change balance, spawn agents or create tasks. Run the card's checks, record actual results and changed files, update its status and stop. L03 follows L02.

Use Luna in task settings. For subsequent cards replace the path and check dependencies. Record incomplete checks honestly; a test fixture is not an implemented gameplay feature.

## L01 handoff

Implemented in [item_definitions.gd](../../prototype/scripts/model/item_definitions.gd) with focused coverage in [item_definitions_test.gd](../../prototype/tests/item_definitions_test.gd). The contract keeps catalog IDs (`base.*`) separate from opaque instance IDs (`inst-*`), stores authored `implicit_modifiers` separately from rolled `explicit_modifiers`, and maps Common/Magic/Rare/Epic to 0/1/2/3 explicit records. Modifier records use typed `stat` and `operation` fields (`flat` or `increased`) plus a unique family. Validation receives the affix table as an argument; the test's clearly marked table is not production balance data.

Example instance shape:

```gdscript
{
	"schema_version": 1,
	"instance_id": "inst-rivet-rare-001",
	"base_id": "base.rivet_cannon",
	"rarity": "rare",
	"item_level": 2,
	"implicit_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "base_damage", "value": 2}],
	"explicit_modifiers": [{"affix_id": "affix.damage", "tier": 1, "value": 3}, {"affix_id": "affix.speed", "tier": 2, "value": 0.15}],
}
```

D02 must author production base definitions, implicit values, affix ranges, tier eligibility, weights, family assignments, stat routing and caps. It should also decide the stable opaque-ID format, whether instance implicits remain copied into the save payload or are reconstructed from the base, and how future catalog changes are versioned. L01 adds no randomness, acquisition, migration, equip behavior or live balance values.

## L02 handoff

Implemented production `loot-v1` tables and metadata validation in [item_definitions.gd](../../prototype/scripts/model/item_definitions.gd). [AccountState](../../prototype/scripts/model/account_state.gd) now owns sorted instance payloads, per-hero kit references, lock/inspect/discard commands, 100-item capacity, deterministic legacy conversion and the transitional fixed-grant adapter. Legacy base ownership remains only as a compatibility projection for the current collection UI; instances are authoritative.

Save envelopes are version 6 and snapshots are version 5 with neutral resolved values and disabled loot state. [SessionPersistence](../../prototype/scripts/model/session_persistence.gd) retries a deep-copied account/campaign/snapshot envelope, never a live account reference. The existing inventory view exposes instance counts and IDs while retaining its current controls. Monster loot, combat stat effects, equipment UI redesign and runtime snapshot capture of non-neutral values remain disabled for L06/L07/L04.

Checks: `item_definitions_test.gd`, `loot_persistence_test.gd`, `snapshot_codec_test.gd`, `account_saves_test.gd`, and `inventory_drops_test.gd` passed. The account test emitted only its intentional malformed-JSON recovery diagnostics.

## L04 handoff

Implemented runtime consumers in [encounter_controller.gd](../../prototype/scripts/game/encounter_controller.gd), [player.gd](../../prototype/scripts/game/player.gd), and [projectile.gd](../../prototype/scripts/game/projectile.gd). Hero damage uses one physical mitigation boundary, outgoing gun/pulse family bonuses apply once, fan volleys preserve resolved per-projectile damage, movement uses resolved speed, active mining keeps its resolved cadence, and positive damage starts the three-second simulation-time regeneration delay. Paused, dead, and terminal states do not regenerate. Frozen resolved stats, equipment IDs, weapon runtime, harvest runtime, and regen delay are captured and restored.

Monster loot and equipment UI redesign remain disabled for later milestones. The legacy `damage_1`, `pump_1`, and `spread_1` account path remains a single compatibility adapter; migrated research ranks are not applied twice. The progression fixture now expects the approved three-shot fan value of 9.75 damage per projectile.

Checks: `loot_runtime_stats_test.gd`, `snapshot_codec_test.gd`, `research_resolver_test.gd`, `progression_2d_test.gd`, and `height_aware_combat_test.gd` passed. `git diff --check` passed with existing CRLF normalization warnings only.

## L05 handoff

Implemented [LootGenerator](../../prototype/scripts/model/loot_generator.gd) as a pure `RefCounted` generator. It validates the approved `loot-v1` catalog and input, consumes only its explicit LCG state, rolls occurrence, rarity, base, eligible affix families and inclusive tier values in stable order, and validates the complete instance before returning it. Ineligible kills and inventory-capacity skips preserve the supplied state. No account mutation, global randomness or kill hook was added.

Checks: `loot_generator_test.gd` passed with deterministic replay, resume, no-roll paths, rarity boundaries, schema validation and 1,000 generated-roll bounds. `loot_generator_simulation_test.gd` passed with fixed-seed 100,000-kill ordinary and boss runs. Measurements and D03 build-combination inputs are recorded in [L05 evidence](L05-evidence.md). D03 must review the measured distributions before L06 enables live kill rewards.

## L06 handoff

The live kill path now defers enemy retirement, sorts queued deaths deterministically, rolls `loot-v1` from stable run/enemy identity, and records exact item instances on the account before later terminal outcomes. Retired enemy intervals and acquired loot IDs are validated in snapshots; duplicate death notifications and repeated collection are rejected without a second reward. Fixed campaign item grants and load-time first-clear reconciliation are removed from the active path, while the explicit legacy reconciliation helper remains available for migration tooling.

Checks: `loot_generator_test.gd`, `loot_persistence_test.gd`, `loot_runtime_stats_test.gd`, `loot_kill_rewards_test.gd`, and `inventory_drops_test.gd` passed. Editor diagnostics report no errors in the touched scripts. The broader L06 acceptance matrix still needs runtime coverage for projectile/pulse/simultaneous damage, boss terminal ordering, save failure and restart cases, suspend/resume, full inventory, summons/cleanup, and repeat campaign runs before L06 can be marked complete.

## L07 handoff

The inventory page now keeps controls alive across HUD refreshes, exposes each opaque item instance separately, supports scrolling within the 100-item limit, filters by slot, sorts by recent/name/item level, and shows rarity, level, equipped hero, lock/New state, and authored implicit/rolled modifiers. Hero selection exposes weapon, chassis, and harvester slots with equip and unequip commands. Selected items provide resolver-backed stat previews, lock toggles, and named discard confirmation; active-run command guards remain enforced by the controller. Capacity is shown before expeditions, and the existing retained-item-after-failure copy remains visible.

Checks: `inventory_ui_test.gd` passed with real mouse selection across refresh; `inventory_l07_test.gd` passed duplicate-base instance selection, retained button identity, filters/sort, equip, locked discard rejection, named discard, and the full 100-item state. `loot_persistence_test.gd`, `loot_kill_rewards_test.gd`, and `loot_runtime_stats_test.gd` also passed; editor diagnostics report no errors in touched files.

Remaining L07 acceptance work: keyboard-focus traversal, 1280x720 and 1920x1080 screenshot review, visible rarity color/icon fallback review, compact drop-toast aggregation, result-list navigation to Inventory, and explicit conditional/capped source breakdown presentation. Keep L07 open until those checks are recorded.
