# Initial design contract — D01

These are original design proposals for this game, not a reproduction of another game's formulas. Structural decisions below guide implementation. Numbers are provisional until D02/D03; no balance simulation or human playtest has yet validated them.

## Item identity and progression

Separate base definition (weapon/chassis/module), item instance (unique ID and rolls), and equipped references. An instance stores schema version, instance ID, base ID, rarity, item level, implicit rolls, explicit affix records `{affix_id, tier, value}`, provenance and inspected/locked state. Rolled values persist: loading must not reroll from today's catalog or seed. Record generation version for debugging. Catalog changes need an explicit migration policy.

Use opaque instance IDs; identity is not the base ID. Kill rewards use the stable identity `(run_id, enemy_id)` to prevent duplicate processing. Generation must not consume the AI/spawn random stream. Rarity and numeric roll quality are separate, and only valid affixes for the base/slot may roll. No repeated modifier family on one item. Hero-compatible equipment has no level requirement in the first slice.

Proposed rarity distribution, conditional on an item dropping:

| Rarity | Chance | Random affixes |
|---|---:|---:|
| Common | 60% | 0; still has its base implicit |
| Magic | 30% | 1 |
| Rare | 9% | 2 |
| Epic | 1% | 3 |

Rarity does not multiply all stats again. Affix tier eligibility comes from authored encounter item level (initially Act 1 bands 1–3), never unbounded surge count. A low-level Epic can lose to a well-rolled Rare. D02 authors exact per-base implicits, tier ranges, weights and families; Luna does not improvise these.

Proposed ordinary-monster drop chance: 2%. A named act boss gets a 25% chance on each eligible defeat, not a guaranteed reward. No elite bonus until an actual elite classification exists. Boss summons, training targets and scripted cleanup are ineligible. Normal expedition enemies may drop on every replay. No pity system in the first slice.

At 20 eligible ordinary kills/minute, 2% implies 0.4 items/minute, or one item per 2.5 minutes on average. This is arithmetic, not observed kill speed. A four-minute run at that rate still has approximately a 20% chance of no drop. D03 must measure actual kills/minute before accepting the rate. Epic is intentionally aspirational, but its rarity must be reconsidered against real session length.

Drop chance = `min(0.30, base_chance * (1 + clamp(sum_drop_bonus, 0, 0.50)))`. A +20% modifier changes 2% to 2.4%, not 22%. It affects item occurrence only, not rarity, affix rolls, mana or campaign progression. Drop bonuses consume normal affix slots, creating an opportunity cost; measure whether they become mandatory farming gear.

## Hero stat meanings

| User concept | Canonical meaning and unit | First-slice interaction |
|---|---|---|
| Attack | `attack_damage`, damage per projectile before enemy mitigation | Weapon attacks only; spell damage is distinct |
| Attack rate | `attacks_per_second` | Sole attack-speed field; do not create a duplicate 'attack speed' multiplier |
| Defense | `armor`, nonnegative rating | Physical damage reduction `armor / (armor + 100)`, capped at 60% |
| Health | `max_health`, HP | Add explicitly because defensive item comparison requires it |
| Move speed | `move_speed`, world pixels/sec | Horizontal locomotion; no implicit change to jump, gravity or dash |
| Vision radius | `vision_radius`, world pixels | Auto-target acquisition radius; not camera zoom or projectile reach |
| Resistance | `resistance.fire/shock/toxin`, fractions | Applies only to the matching elemental component; cap each at 50%, floor 0 for this slice |
| Health regen | `health_regen`, HP/sec | Starts after 3 seconds without positive HP damage; stops on death, pause or terminal state |
| Mining rate | `mining_bonus`, fraction | Active hero's well cycle amount only; no offline or guard output and no cycle-cadence double application |
| Monster advantage | `damage_vs.<family>`, fraction | Applies once to outgoing attack/spell damage against one authored family, capped at +30% |
| Spells | Ability IDs plus resolved ability parameters | Active ability selection and cooldown/damage in L09; not an inventory number |
| Weapons | Base/family ID plus weapon parameters | Equipment selects a weapon profile; weapon behavior expansion is L09 |
| Drop rate | `drop_bonus`, fraction | Item occurrence formula above; frozen when the expedition starts |

Baseline hero values should reproduce current gameplay (currently 100 HP, 192 pixels/sec movement, weapon 10 damage and 0.6-second interval before research). Heroes initially share that baseline. D04 designs distinct identities after item effects are measurable; do not invent class passives now.

All current damage is treated as physical until D02 maps explicit sources. Armor does not also reduce elemental damage. For a mixed hit, mitigate each damage component separately and sum; clamp final damage nonnegative. No dodge, crit, penetration or resistance debuffs in this milestone. Resistance affixes stay out of live pools until a real, visually communicated elemental threat is implemented and tested. Likewise monster-family tags are separate from attack-role enums; D02 must author a tag for each existing monster.

Auto-targeting uses `min(vision_radius, weapon_target_range)` and retains existing geometry/facing rules. D02 must choose a baseline and ceiling that make vision useful without lowering existing targeting range; if no useful variation is possible, keep vision visible in the sheet but out of the initial affix pool. It never changes projectile lifetime. Jump bonuses from the old plan are deferred to L09 and platform reach review.

## Composition and safeguards

Build one run-stat resolver that consumes hero baseline, existing research results, equipped instances and explicit loadout policies. ResearchResolver remains the source of research calculations; do not clone or independently reapply it.

For ordinary scalable stats, resolve `(research-adjusted baseline + summed equipment flat values) * (1 + summed equipment increased fractions)`, then apply a separately named authored mode multiplier exactly once, then safety clamps. Mode multipliers already included by ResearchResolver must not be reapplied; D02 defines the adapter explicitly. Flat additions and percentages require separate typed modifier operations. Defense/regen/resistance/drop bonuses use their own units and formulas, not this generic rule blindly.

Proposed equipment-only bounds relative to the researched baseline: damage +50%, attack rate +30%, movement +20%, maximum health +50%, active mining +25%; regeneration at most 1 HP/sec for Act 1. These bound the added equipment contribution, not already earned research. D02 sets exact clamps for combined flat and percent bonuses. Caps must appear in comparisons so an item does not promise ineffective gains.

Worked stacking target: researched attack damage 20, equipment +2 flat and +10%/+5% increased gives 25.3 before any separately authored weapon-mode factor. Attack rate increases add together before conversion to interval. A physical 10-damage hit against armor 25 deals 8; a fire 10-damage hit against 20% fire resistance deals 8 irrespective of armor. Mining +10% changes a researched cycle amount of 5 to 5.5 with its cadence unchanged.

Freeze resolved stats, equipped references, loot modifiers and loot-table version for the run. Equipping is allowed only outside active or suspended expeditions. This avoids last-hit gear swapping and reload stat changes. Do not heal the hero by rebuilding max health every HUD frame. Guard assignment remains legal with equipment but receives no equipment benefit.

## Rewards, persistence and transition

Auto-collect on an eligible real death. Show a small drop cue, not a modal or physical pickup obstacle. Items secured before failure/abandonment remain owned; money retains the existing banking rules. Closing during combat must not let a restored enemy grant the same item twice or reroll a failed drop.

Persist loot random state, processed enemy-death identities (including no-drop outcomes), newly owned instances and matching encounter state atomically in the existing save envelope. D02 defines how this fits current save checkpoints and failure retry. If a save fails, keep the exact pending roll and snapshot; retry must not regenerate. Do not promise crash durability before a successful save. Resetting an intentionally old save is outside prototype anti-cheat scope.

Replace fixed campaign item acquisition at L06 cutover, including disabling the old missing-first-clear reward reconciliation. Convert each already owned fixed item once to a deterministic Common instance with authored legacy implicit values and preserve its New state. Keep bank/research/campaign data intact. Prototype suspended saves incompatible with the new schema may be discarded with a clear message while retaining account progression; D02 specifies the exact policy before L02 changes codecs.

No selling economy yet. L07 allows discard only for unequipped, unlocked instances with a confirmation identifying the item. At capacity, no hidden drop is generated or lost: inform the player to free space. The inventory limit and skip behavior must be visible before starting a run. No batch discard by rarity in the first slice.
