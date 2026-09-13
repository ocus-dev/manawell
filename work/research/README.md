# Research trees — Luna implementation queue

Planning only; no implementation or task dispatch. The owner reports the campaign map is working. Inspect current code and handoffs before starting: the map queue still lists some encounter/acceptance work as pending, so do not infer completion or overwrite active controller changes.

## Design

Replace the three flat one-time upgrades with two compact trees: **Harvester Engineering** and **Weapons Engineering**. Research is permanent, account-wide and bought with existing banked mana outside active/suspended runs. No new currency, research timers, random affixes or per-hero duplicate purchases. The player chooses an unlocked specialization before an encounter; switching is free and does not refund research. Limited early mana creates investment choices, while specializations preserve choices after more nodes are unlocked.

Six core tracks cover the requested stats. Values below are initial tuning targets, not proven balance; use explicit rank arrays, additive bonuses within each track and documented multiplication between tracks. Tier costs and availability must be grounded in current campaign earnings in R01.

| Track / stable ID | Ranks | Effect at rank r | Prerequisite |
|---|---|---|---|
| Pump displacement / `harvest.amount` | 3 | +25% base mana per cycle per rank | None |
| Pump cadence / `harvest.cadence` | 3 | +15% cycles/sec per rank | None |
| Payload / `weapon.damage` | 3 | +5 damage per projectile per rank | None |
| Autoloader / `weapon.rate` | 3 | +15% attacks/sec per rank | None |
| Splitter / `weapon.shots` | 2 | Unlock 3-shot then 5-shot fan mode | Damage rank 1 |
| Accelerator / `weapon.velocity` | 3 | +25% projectile speed per rank | None |

Rank 2 follows rank 1 and rank 3 follows rank 2. The only campaign gate for this first slice is access to research itself through existing operations navigation; do not invent boss/material gates that can stall the current act. Costs alone can pace advanced ranks. Display currently unaffordable nodes and exact prerequisites.

### Harvester specializations

- **Standard:** no extra modifiers; always available.
- **Rapid Seal** (`harvest.rapid_seal`, one research rank): requires cadence 2, reduces sealing duration by 20%. Suits frequent safe extraction. Does not change surge timing.
- **Deep Draw** (`harvest.deep_draw`, one research rank): requires amount 2, adds ×1.25 extraction output but advances pressure ×1.15 during active well encounters. Suits longer, riskier holds. This tradeoff must be visible beside the projected rate.

Equip only one harvester specialization. Core amount/cadence ranks always apply. Cadence and amount are mathematically multiplicative throughput improvements; do not falsely describe them as inherently different strategies without their specialization effects. Use actual harvest cycles with fractional progress preserved when sealing; do not create a loss-at-seal timing exploit. A nominal 1-second base cycle preserves today's base mana/sec. Production accounting uses equivalent average throughput; no per-tick offline simulation. For this slice passive production receives core amount/cadence bonuses only, **neither specialization bonus**. This prevents Deep Draw's active danger from becoming free passive output.

### Weapon modes and visible behavior

- **Standard:** one projectile per attack, full damage, always selectable even after researching Splitter.
- **Fan:** rank 1 fires 3 visible projectiles at −12°, 0°, +12°; rank 2 fires 5 at −16°, −8°, 0°, +8°, +16°. Per-projectile damage is ×0.65 for 3 shots and ×0.50 for 5. All can hit one target if geometry allows: theoretical full-connect damage is 1.95× / 2.5× standard, not a hidden damage multiplier. Display both pellet damage and projectile count. Wide shots can miss; bosses may still favor fan at close range, which R07 must measure.
- **Lance** (`weapon.lance`, one research rank): requires damage 2 and velocity 2. One full-damage projectile pierces one additional distinct enemy, at ×0.85 attack rate. Rewards lining up targets and projectile reliability. Never damages one enemy twice with the same projectile.

Equip one mode: Standard, unlocked Fan, or unlocked Lance. Lance and Fan cannot stack. Projectile speed improves travel time/reliability; keep weapon range fixed so speed does not silently buy range. Attack-rate bonuses change firing interval, not movement or projectile velocity. Avoid critical chance, ricochet, homing, elemental status and infinite piercing in this first implementation.

### Formula contract

`cycle_interval = 1.0 / (1 + 0.15 * cadence_rank)` seconds.

`cycle_amount = well_base_output_per_second * 1.0 * (1 + 0.25 * amount_rank) * existing_loadout_output_multiplier * active_specialization_output_multiplier`.

`mean_output_per_second = cycle_amount / cycle_interval`. Apply existing surge payout multiplier once through the existing payout rules. Pressure multiplier is separate and composes once with existing loadout pressure rules.

`projectile_damage = (base_damage + 5 * damage_rank) * mode_damage_multiplier`.

`attack_interval = base_interval / ((1 + 0.15 * rate_rank) * mode_attack_rate_multiplier)`.

`projectile_speed = base_speed * (1 + 0.25 * velocity_rank)`.

Use current spatial unit conversion once. Define maximum projectile travel from the existing base speed/lifetime before adding upgrades; stop on that distance independent of upgraded speed, while target-acquisition range stays unchanged. Swept collision must still hit at maximum speed and with platforming elevation. Do not let enemy projectiles inherit player research.

## Queue and prompt

| Card | Work | Depends on | Status |
|---|---|---|---|
| [R01](R01-definition-balance.md) | Research definitions, costs and derived-stat contract | Current runtime audit | DONE |
| [R02](R02-state-purchases.md) | Ranks, prerequisites, purchases, equipment and saves | R01 | DONE |
| [R03](R03-harvester.md) | Harvest cycles, specializations and production parity | R02 | DONE |
| [R04](R04-weapons.md) | Rate, speed, real multishot and Lance | R02; shared controller idle after R03 | DONE |
| [R05](R05-tree-ui.md) | Compact tree UI with precise stat previews | R03, R04 | DONE |
| [R06](R06-research-preview.md) | Repeatable visual tuning scene | R05 | DONE |
| [R07](R07-acceptance.md) | Campaign balance and regression acceptance | R06 | DONE |

Select Luna and paste:

> Implement only work/research/R01-definition-balance.md. Read work/research/README.md, the card and relevant current source/handoffs. Coordinate any shared files with ongoing campaign or animation work. Do not implement later cards, create tasks or spawn agents. Run the card's checks, update its row and add a short completion note with real files/commands/results, then stop.

Replace the card path after its dependencies complete. Keep one card per task; states TODO / IN PROGRESS / DONE / BLOCKED. Do not alter other queues' status. Research uses current procedural/SVG icons or existing icon assets; no ComfyUI work is needed to prove these mechanics.

## Future options, deliberately deferred

After the first slice is tested: harvester integrity/repair for defensive builds; a brief shield after each completed pump cycle to further distinguish cadence; controlled knockback for crowd management; ability cooldown/area branches; well-specific specialization. Do not implement these now. Avoid pump-capacity upgrades until there is an actual tank-capacity mechanic.

Prototype legacy-save migration need not become a project of its own, but existing purchases should not silently vanish. Prefer mapping `damage_1` → damage rank 1, `pump_1` → amount rank 1, `spread_1` → shots rank 1 with Fan selected. Apply each effect only once. Document that the legacy full-damage spread is rebalanced. Preserve existing bank, well/campaign progress and corruption recovery; incompatible active snapshots follow an explicit existing reset/recovery path.
