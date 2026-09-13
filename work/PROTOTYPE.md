# Compact prototype specification

## Goal

Prove that defending a mana extractor, deciding when to cash out, and reinvesting the proceeds is enjoyable. Then prove that leaving a hero to operate an old well makes progression feel rewarding. This brief is sufficient context for routine assignments; `design/Concept.md` remains the broader design proposal.

## Scope

Windows desktop prototype in Godot 4/GDScript. The active project is a native 2D side view with a fixed 1280x720 logical canvas, one horizontal ground lane, a central harvester, and procedural industrial visuals. Store the active Godot project under `prototype/`. The original 3D runtime is frozen at `archive/prototype-3d/`, and the accepted experiment is frozen at `experiments/side-view-defense/`; neither is an active dependency.

Milestone A: one hero, one well, three enemies, four authored surge tiers followed by escalating repeats, extraction and loss, two abilities, three upgrades, a clear HUD, and instant-versus-delayed sealing settings.

Milestone B: two wells using the same arena, two guaranteed heroes, one guard per well, deterministic passive income, capped offline settlement, persistent progress, exact enough encounter recovery to prevent rerolling, and two machine loadouts.

Excluded from this prototype: route stages, bosses, full acts, random recruitment, prestige, regional currencies, public chat, co-op, leaderboards, server security, cloud saves, final art production, and engine comparisons. These are product-scope exclusions, not unresolved conversion work.

## Play

Move with WASD. Primary weapon auto-targets the nearest living enemy within range. Space uses a short evasive dash; Q triggers a radial defensive pulse. E or a HUD button starts extraction or requests harvesting. Escape pauses solo combat. Purchases and assignments are available only outside an encounter.

An extraction has hero health and machine integrity. Either reaching zero loses the current tank only. Completing sealing banks the locked payout once. Failed attempts have no cost beyond the tank and time spent. Retry restores temporary state but preserves account progress.

Health, damage, cooldowns, and extraction timers use simulation time. A pause stops them. Passive income uses real elapsed time under the accounting contract and is not sped up by pause, frame rate, or time scale.

## Initial tunable values

These values make cards concrete; they are not balance claims. Keep them together in `data/balance.gd` or an equally simple data resource rather than scattering literals.

| Parameter | Starting value |
|---|---|
| Arena | 28 × 28 units, flat floor, closed boundaries |
| Hero | 100 health; movement 6 units/sec |
| Machine | 150 integrity |
| Well 1 / well 2 base extraction | 2 / 4 raw mana/sec |
| Sealing duration | 2 seconds; developer setting also permits 0 |
| Surge duration | 20 simulation seconds |
| Multipliers for 0 / 1 / 2 / 3 / 4 completed surges | 1 / 1.25 / 1.5 / 2 / 2.5 |
| Beyond surge 4 | Each completed surge adds 0.5 to multiplier; spawn interval falls 10% per tier down to 0.4 sec; enemy damage rises 15% of base per tier |
| Live enemy limit | 60; skip excess spawn attempts without a queued burst |
| Weapon | 10 damage, 0.6 sec interval, range 12, projectile speed 18 |
| Dash | 0.2 sec at speed 15; 4 sec cooldown; invulnerable during dash |
| Pulse | 15 damage in radius 4; 8 sec cooldown; simple flash/ring |
| Upgrade: damage | Cost 40, one purchase, +5 damage |
| Upgrade: pump | Cost 60, one purchase, +25% output, no extra pressure |
| Upgrade: spread | Cost 100, one purchase, three projectiles at -12/0/+12 degrees |
| Commission well | Successful extraction after at least one completed surge |
| Passive baseline | 20% of that well's effective base output; no active surge multiplier |
| Second hero guard bonus | +25% passive output; other base stats remain equal initially |
| Offline cap | 86,400 seconds per uninterrupted absence |

Surge 1 spawns basic pursuers every 3 seconds; surge 2 every 2.5 seconds with every fourth spawn a breaker; surge 3 every 2 seconds cycling pursuer, pursuer, breaker, ranged; surge 4 every 1.5 seconds with the same mix. Well 2 multiplies spawn intervals by 0.8 and enemy damage by 1.25. These factors compose with later-tier escalation.

Pursuer: 20 health, speed 2.5, targets hero, deals 8 damage at most once/sec in range 1.2. Breaker: 50 health, speed 1.5, targets machine, 12 damage at most once/sec in range 1.8. Ranged: 25 health, speed 2, targets hero, stops within 8 units, telegraphs for 0.6 sec before firing a projectile toward the hero's then-current position; 8 damage, projectile speed 8, 2 sec attack cycle. Projectiles expire after 3 seconds or on first collision.

## Visual minimum

Dark neutral floor; chunky red hero; yellow machine with a cyan tank indicator. Distinguish enemies by silhouette as well as color. Use clear ground-level attack telegraphs. HUD text explains tank versus bank, upcoming surge, sealing danger, and failure cause. No shaders or cinematic camera work are required.

## Practical completion rule

Each card implements one bounded capability and its focused checks. Runtime defects block that card; unvalidated taste or balance is recorded as a playtest question. Keep provisional numbers editable so later playtesting does not require architecture changes.

