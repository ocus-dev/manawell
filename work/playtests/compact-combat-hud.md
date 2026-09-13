# Compact Combat HUD Acceptance

P03 verifies the P01/P02 compact HUD in the real foundry runtime. The native fixture uses the controller, prepared environment, harvester, hero, pursuer, breaker, ranged enemy, warning ring, projectile, and persistent combat controls. It captures five states at both supported resolutions: all roles, low health, dash/pulse cooldowns, sealing, and pause.

## Evidence

Before P03: [P01 1280 capture](../reviews/combat-hud-1280.png) and [P01 1920 capture](../reviews/combat-hud-1920.png).

After P03: [all roles 1280](compact-combat-hud/all-roles-1280.png), [all roles 1920](compact-combat-hud/all-roles-1920.png), [low health 1280](compact-combat-hud/low-health-1280.png), [low health 1920](compact-combat-hud/low-health-1920.png), [cooldowns 1280](compact-combat-hud/cooldowns-1280.png), [cooldowns 1920](compact-combat-hud/cooldowns-1920.png), [sealing 1280](compact-combat-hud/sealing-1280.png), [sealing 1920](compact-combat-hud/sealing-1920.png), [pause 1280](compact-combat-hud/paused-1280.png), and [pause 1920](compact-combat-hud/paused-1920.png).

The inspected captures show distinct Hero and Harvester rows, readable surge tier/countdown/progress, fixed icon slots with Space/Q badges and cooldown rings, explicit at-risk mana, sealing seconds, and Pause/Resume. The world remains visible; no persistent widget enters the logical play area y=64...656.

## Measured bounds

Bounds are logical pixels and are identical at both physical targets because the project uses a 1280x720 canvas. The native fixture recorded:

| Widget | Position | Size | Band |
|---|---:|---:|---|
| SurvivalWidget | (24, 8) | 293x56 | top |
| PressureWidget | (500, 6) | 250x58 | top |
| CombatWallet / pause | (1168, 8) | 102x51 | top |
| AbilityBar | (24, 660) | 104x52 | bottom |
| ExtractionWidget | (490, 656) | 300x60 | bottom |

## Checks

`compact_combat_hud_acceptance_test.gd` passed natively with 5 scenarios x 2 resolutions and rectangle assertions. It also passes headless assertions, where image capture is intentionally unavailable. `combat_widgets_test.gd`, `weapons_abilities_2d_test.gd`, `presentation_2d_test.gd`, `operations_layout_test.gd`, `pause_results_test.gd`, and `ui_view_state_test.gd` passed. Editor diagnostics are clean and diff whitespace checks pass.

Remaining observation: keyboard feel and tooltip focus behavior are covered by existing command/metadata assertions but were not a human-input playtest. The known unrelated `progression_2d_test.gd` timeout remains from the earlier full-suite run. No gameplay, balance, platforming, settings, results, or operations redesign was performed.
