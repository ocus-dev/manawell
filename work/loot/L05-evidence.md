# L05 evidence - deterministic loot rolls

Implementation: [loot_generator.gd](../../prototype/scripts/model/loot_generator.gd)
Focused checks: [loot_generator_test.gd](../../prototype/tests/loot_generator_test.gd)
Simulation: [loot_generator_simulation_test.gd](../../prototype/tests/loot_generator_simulation_test.gd)

The generator uses `loot-v1`, an explicit 32-bit LCG state, and no global RNG. Ineligible kills and full inventory return without consuming state. The generator only returns a result and never mutates `AccountState`.

Command:

```powershell
& '.\\Godot_v4.8-dev4_win64.exe\\Godot_v4.8-dev4_win64_console.exe' --headless --path '.\\prototype' --script 'res://tests/loot_generator_simulation_test.gd'
```

Simulation: 100,000 eligible level-3 kills per scenario.

| Scenario | Seed | Threshold | Drops | Common | Magic | Rare | Epic | Final state |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Ordinary, bonus 0.00 | 324508639 | 200 | 1,995 | 1,186 | 606 | 182 | 21 | 2668582311 |
| Boss, bonus 0.50 | 610839777 | 3,000 | 30,044 | 18,074 | 8,903 | 2,777 | 290 | 3877957679 |

Base counts were ordinary: `chassis.bulwark` 209, `chassis.jump_servos` 238, `chassis.runner` 242, `core.accelerator` 205, `core.cycler` 203, `core.heavy_breech` 235, `module.bracing` 214, `module.fast_cycle` 227, `module.high_volume` 222. Boss counts: `chassis.bulwark` 3328, `chassis.jump_servos` 3250, `chassis.runner` 3332, `core.accelerator` 3378, `core.cycler` 3330, `core.heavy_breech` 3321, `module.bracing` 3397, `module.fast_cycle` 3300, `module.high_volume` 3408.

## D03 build-combination inputs

The simulation emits one deterministic generated instance for each available `slot/rarity` combination. D03 can enumerate combinations from these exact fields without invoking gameplay or account mutation. The simulation output contains the complete `build_inputs` map; representative entries are:

```json
{
  "weapon/common": {"base_id": "core.cycler", "rarity": "common", "item_level": 3, "explicit_modifiers": []},
  "weapon/magic": {"base_id": "core.accelerator", "rarity": "magic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.hunter", "tier": 3, "value": 0.16}]},
  "weapon/rare": {"base_id": "core.cycler", "rarity": "rare", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.force", "tier": 3, "value": 0.12}, {"affix_id": "affix.hunter", "tier": 3, "value": 0.18}]},
  "weapon/epic": {"base_id": "core.cycler", "rarity": "epic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.fortune", "tier": 3, "value": 0.12}, {"affix_id": "affix.force", "tier": 3, "value": 0.10}, {"affix_id": "affix.tempo", "tier": 3, "value": 0.12}]},
  "hero/common": {"base_id": "chassis.runner", "rarity": "common", "item_level": 3, "explicit_modifiers": []},
  "hero/magic": {"base_id": "chassis.runner", "rarity": "magic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.mobility", "tier": 3, "value": 0.07}]},
  "hero/rare": {"base_id": "chassis.jump_servos", "rarity": "rare", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.mobility", "tier": 3, "value": 0.08}, {"affix_id": "affix.recovery", "tier": 3, "value": 0.30}]},
  "hero/epic": {"base_id": "chassis.bulwark", "rarity": "epic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.plating", "tier": 3, "value": 13}, {"affix_id": "affix.recovery", "tier": 3, "value": 0.35}, {"affix_id": "affix.vitality", "tier": 3, "value": 14}]},
  "harvester/common": {"base_id": "module.bracing", "rarity": "common", "item_level": 3, "explicit_modifiers": []},
  "harvester/magic": {"base_id": "module.high_volume", "rarity": "magic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.vitality", "tier": 3, "value": 14}]},
  "harvester/rare": {"base_id": "module.high_volume", "rarity": "rare", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.extraction", "tier": 3, "value": 0.10}, {"affix_id": "affix.vitality", "tier": 3, "value": 14}]},
  "harvester/epic": {"base_id": "module.bracing", "rarity": "epic", "item_level": 3, "explicit_modifiers": [{"affix_id": "affix.vitality", "tier": 3, "value": 13}, {"affix_id": "affix.fortune", "tier": 3, "value": 0.11}, {"affix_id": "affix.plating", "tier": 3, "value": 14}]}
}
```

These are measured inputs, not a balance conclusion. No kill hook or live reward transaction is included in L05.