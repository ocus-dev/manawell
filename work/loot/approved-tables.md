# D02 — Approved implementation tables, revision loot-v1

Approved for L02–L05 implementation on September 9, 2026. These are concrete initial values, not final playtested balance. D03 remains the gate before live monster rewards. This document overrides provisional numeric examples in DESIGN.md where different.

## Base items

Keep existing base IDs from item_catalog.gd; `base.*` in L01 was a test fixture, not a required production prefix. All nine bases are available at every item level, with equal selection weight 1. Slots remain `weapon`, `hero`, `harvester` internally; display them as Weapon, Chassis, Utility. Empty slots are legal. Weapons currently modify the existing gun; new weapon behaviors belong to L09.

Implicits are fixed, copied into each instance, and validated against its generation-version catalog. Each implicit family is `implicit.<base_id>.<stat>`, distinct from explicit families. An implicit and an explicit bonus to the same stat may coexist.

| Base ID | Slot | Implicit modifier(s) |
|---|---|---|
| core.heavy_breech | weapon | attack_damage flat +2 |
| core.cycler | weapon | attacks_per_second increased +0.08 |
| core.accelerator | weapon | projectile_speed increased +0.12 |
| chassis.bulwark | hero | armor flat +12 |
| chassis.runner | hero | move_speed increased +0.06 |
| chassis.jump_servos | hero | max_health flat +10 |
| module.high_volume | harvester | mining_bonus flat +0.08 |
| module.fast_cycle | harvester | health_regen flat +0.20 |
| module.bracing | harvester | armor flat +8 |

Retain display names for legacy recognition but revise descriptions to explain actual bonuses. Jump Servos do not change jumping yet. Fast-cycle Rotor assists the hero's recovery; it does not change pump cadence. These are deliberately modest starter implicits, replacing the old unimplemented tradeoff proposals. No hidden negative modifiers.

## Affixes

Each row has ID `affix.<name>`, family equal to `<name>`, and weight 100. Select explicit families without replacement using their weights, excluding ineligible slots. No prefixes/suffixes split. Every eligible slot has at least three distinct families, including at item level 1; never compensate for a short pool by duplicating a family.

Only the highest unlocked tier is eligible: tier = item level, 1–3. Roll a uniform integer number of steps between the inclusive bounds, then multiply by step. Percentages are stored as fractions, never as whole percent numbers. Round only at roll generation to the stated step; comparisons use unrounded resolved values internally.

| Name | Stat / operation | Slots | Tier 1 bounds | Tier 2 bounds | Tier 3 bounds | Step |
|---|---|---|---|---|---|---|
| payload | attack_damage / flat | weapon | 1–2 | 2–3 | 3–4 | 1 |
| force | attack_damage / increased | weapon | .03–.05 | .06–.08 | .09–.12 | .01 |
| tempo | attacks_per_second / increased | weapon | .03–.05 | .06–.08 | .09–.12 | .01 |
| plating | armor / flat | hero, harvester | 4–6 | 7–10 | 11–15 | 1 |
| vitality | max_health / flat | hero, harvester | 5–8 | 9–12 | 13–18 | 1 |
| mobility | move_speed / increased | hero | .02–.03 | .04–.05 | .06–.08 | .01 |
| recovery | health_regen / flat | hero, harvester | .10–.15 | .20–.25 | .30–.40 | .05 |
| extraction | mining_bonus / flat | harvester | .03–.05 | .06–.08 | .09–.12 | .01 |
| fortune | drop_bonus / flat | weapon, hero, harvester | .03–.05 | .06–.08 | .09–.12 | .01 |
| hunter | damage_vs.swarm / flat | weapon | .05–.08 | .09–.12 | .13–.18 | .01 |
| breaker | damage_vs.armored / flat | weapon | .05–.08 | .09–.12 | .13–.18 | .01 |

`flat` on a fraction-valued stat means adding fraction points to that bonus, not adding raw damage. Add `projectile_speed`, `damage_vs.swarm`, `damage_vs.armored`, `damage_vs.guardian` to the recognized schema. No guardian affix is live yet. Restrict allowed operations per stat to those used above plus base implicits; unknown operations or stat/family pairs are invalid. Integer requirements apply to flat integer-valued modifiers, not to percentage increases of integer-valued stats.

Vision, elemental resistance, spell modifiers and jump modifiers are reserved, with no live affix rows or weights. All current damage is physical. Enabling elemental resistance requires a separately reviewed, communicated elemental threat; L04 must not silently reclassify existing hits. Vision remains at existing target acquisition range until L09 supplies a useful variation.

## Rarity and encounter tables

Occurrence uses integer thresholds out of 10,000: ordinary enemy 200, named act boss 2500. Apply frozen drop bonus, rounding the final threshold to nearest integer (half up), and cap at 3000. Bonus itself caps at .50. Example .20 bonus makes ordinary threshold 240. Ineligible kills and capacity skips consume no RNG.

Conditional rarity thresholds out of 10,000: Common [0,6000), Magic [6000,9000), Rare [9000,9900), Epic [9900,10000). Counts are 0/1/2/3. No further rarity stat multiplier.

Act 1 nodes 01–03 have item level 1; 04–06 level 2; 07–09 level 3. Surge count does not increase this. Ordinary enemies in boss encounters use the node level and ordinary occurrence chance; explicitly marked boss summons are ineligible. Only the named boss gets the boss threshold. Noncampaign test encounters grant no live loot.

Monster family is independent of role and loot eligibility: pursuer/ranged = swarm, breaker = armored, named boss = guardian (overrides its reused visual/combat role). One family per enemy. Persist it with actor state. Summons may have a family for damage calculations while remaining loot-ineligible.

## Hero baseline and resolution

Both heroes: 100 HP, 192 pixels/sec horizontal movement, armor 0, regeneration 0, resistance channels 0, family bonuses 0, mining/drop bonus 0. Vision is `Balance.WEAPON_RANGE * SPATIAL_PIXELS_PER_UNIT`; weapon target range remains that value. Dash, jump, gravity, pulse cooldown and base pulse damage retain existing values.

Use ResearchResolver as the research source. Resolve standard weapon mode once to obtain unmodified research damage/rate/speed. Resolve selected mode once for its count/pierce/mode factors. Compute selected/standard ratios for damage and rate (finite positive baselines required). Equipment modifies the standard research values, caps them, then mode ratios apply ONCE. Volley spawning accepts final per-projectile damage and must not multiply by fan attenuation again. Do not reverse-engineer ranks in a second resolver.

For a positive baseline B, ordinary equipment result is `(B + sum_flat) * (1 + sum_increased)`, bounded from B through `B * cap_factor`. Sum implicits and explicits before capping. Damage cap 1.50; attacks/sec 1.30; projectile speed 1.25; HP 1.50; movement 1.20. All current equipment is nonnegative. HP stays float internally; round only the UI. Convert attack rate to interval after cap/mode factors.

Armor = clamp(sum armor, 0, 150), giving at most 60% physical mitigation via A/(A+100). Regen = clamp(sum, 0, 1) HP/sec. Resistance per channel = clamp(sum, 0, .50), reserved at zero. Family bonus per family = clamp(sum, 0, .30). Drop bonus = clamp(sum, 0, .50). Mining bonus = clamp(sum, 0, .25).

Harvest: call existing resolve_harvest with research, well policy and specialization exactly once; multiply its cycle_amount by `(1 + mining_bonus)`. Recompute mean from resulting amount/unchanged interval. No effects on pressure, seal duration, machine integrity, passive income or guards. Utility armor/regen/HP bonuses benefit the active hero in every encounter, including monster-only nodes; only extraction is well-specific.

Legacy research fallback, where still necessary, must enter the research baseline adapter exactly once. Do not apply old pump/damage account flags a second time after resolving equipment. Preserve already migrated research ranks.

## Damage, targeting and regeneration routing

Hero gun and pulse damage use a shared outgoing hit boundary with source ability, damage components and target family. Gun uses resolved per-projectile attack damage. Pulse keeps base 15 damage; attack_damage and attacks_per_second do not scale it. The matching family bonus multiplies outgoing gun/pulse damage once. Target mitigation follows; current monsters have zero armor/resistance. No family bonus applies to hero or machine damage.

Incoming hero damage from melee, hostile projectiles and boss direct hits passes through one mitigation function. Physical component × (1 - armor/(armor+100)); elemental component × (1 - matching resistance). Sum components. Machine damage preserves its existing behavior; never inherit hero armor. Do not introduce rounding per component. UI damage feedback must show applied damage.

Positive actual hero HP damage resets a simulation-time regeneration delay to 3 seconds. Regeneration uses only the portion of a frame after that delay expires, then caps at max HP. No healing from paused/offline time, death or terminal results. New runs start at resolved max HP; rebuilding HUD/preview does not heal. Save remaining regen delay and health. Auto-targeting uses existing geometry/facing and min(vision, weapon range), with existing stable tie-breaks.

## Worked acceptance fixtures

All rows use item level/tier 1; all instances have their base implicit above. Omitted modifiers are absent. These are valid concrete fixtures covering each slot and rarity:

| Slot/base | Common | Magic explicit(s) | Rare explicit(s) | Epic explicit(s) |
|---|---|---|---|---|
| weapon/core.heavy_breech | none | payload=1 | payload=1, tempo=.03 | payload=1, tempo=.03, fortune=.03 |
| hero/chassis.bulwark | none | vitality=5 | vitality=5, mobility=.02 | vitality=5, mobility=.02, recovery=.10 |
| harvester/module.high_volume | none | extraction=.03 | extraction=.03, recovery=.10 | extraction=.03, recovery=.10, fortune=.03 |

Three Epic fixtures equipped together, no research, standard gun: damage 13, attacks/sec 1.7166666667, HP 105, armor 12, movement 195.84, regen .20, mining .11, drop .06. A 10 physical hit deals 8.9285714286. Well base cycle amount 2 becomes 2.22. Ordinary drop threshold is 212. Common Heavy Breech alone gives 12 damage; no item gives the existing 10 baseline.

Research damage rank 1 + 3-shot fan, no equipment: 15 × .65 = 9.75 per projectile, not 6.3375. Same with Heavy Breech implicit: 17 × .65 = 11.05. Five-shot factor .50; Lance rate factor .85, pierce 1. Report theoretical all-hit volley damage separately from actual spread hits. The earlier generic stacking example with B=20, +2 flat and +15% gives 25.3 before selected mode; cap is 30.
