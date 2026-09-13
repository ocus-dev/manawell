# R01 balance sheet

The prototype's measured Act 1 anchors are 3, 4, 5, 6, 7 mana for the early monster nodes and 12 mana for the boss; Well 1 produces 2 mana/sec before payout multipliers. The first purchase costs remain 40 damage, 60 displacement, and 100 splitter, preserving the current anchors while making a successful early encounter sufficient for one choice.

| ID | Rank costs | Rank effect |
|---|---:|---|
| `harvest.amount` | 60 / 120 / 240 | +25% cycle amount per rank |
| `harvest.cadence` | 50 / 110 / 220 | +15% cycles/sec per rank |
| `weapon.damage` | 40 / 90 / 180 | +5 damage/projectile per rank |
| `weapon.rate` | 50 / 110 / 220 | +15% attacks/sec per rank |
| `weapon.shots` | 100 / 180 | 3 then 5 fan projectiles |
| `weapon.velocity` | 45 / 100 / 200 | +25% projectile speed per rank |
| `harvest.rapid_seal` | 140 | -20% active sealing duration; requires cadence 2 |
| `harvest.deep_draw` | 160 | x1.25 active output and x1.15 pressure; requires amount 2 |
| `weapon.lance` | 180 | one additional distinct hit and x0.85 attack rate; requires damage 2 and velocity 2 |

Costs are integral, finite and positive. The total six-track spend is 2,220 mana; this is intentionally beyond Act 1 so specialization choice remains meaningful rather than automatic. Passive production uses only amount and cadence core ranks in later stages; specializations never affect passive output.

## Formula contract

`cycle_interval = 1 / (1 + 0.15 * cadence_rank)` and `cycle_amount = base_output * (1 + 0.25 * amount_rank) * loadout_multiplier * active_specialization_multiplier`.

`projectile_damage = (10 + 5 * damage_rank) * mode_multiplier`, `attack_interval = 0.6 / ((1 + 0.15 * rate_rank) * mode_rate_multiplier)`, and `projectile_speed = 18 * (1 + 0.25 * velocity_rank)`. Fan theoretical full-connect volley DPS is 1.95x at three shots and 2.5x at five shots before rate upgrades; actual damage depends on hits.

## Example equal-budget builds

At 100 mana, Payload 1 + Accelerator 1 costs 85 and gives 15 damage, 1 projectile, 22.5 units/sec. Amount 1 + Cadence 1 costs 110 and is just beyond that budget, making the first successful 100-mana threshold a deliberate choice rather than a guaranteed pair. At 280 mana, Fan 1 plus Payload 1 plus Rate 1 costs 190 and leaves 90; Amount 2 costs 180 and leaves 100. These examples are comparison anchors, not balance claims; R07 measures real encounters before any retuning.
