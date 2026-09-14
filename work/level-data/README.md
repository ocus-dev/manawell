# Data-driven levels — Luna implementation stories

Status: LD05 complete; LD06 is ready to begin. Campaign data is migrated, finite encounters consume resolved definitions, typed per-run objective state owns quota, boss, wave, and extraction completion, and authored first-clear rewards deliver deterministically with persistent pending claims. Simulator work remains paused.

## Recommendation

Use one strict JSON file per playable level, plus an explicit act manifest. Keep monster archetypes, item definitions and reusable extraction schedules in shared catalogs. Designers edit a level's local HP/damage factors, objectives, rewards and population without editing code. Shared catalogs define identity and behavior; levels define composition and tuning.

Proposed runtime layout:

```text
prototype/data/campaign/index.json
prototype/data/campaign/acts/act_01.json
prototype/data/levels/act_01_node_01.json
prototype/data/levels/act_01_node_02.json
... one file for each level ...
prototype/data/schemas/level.schema.json
```

The schema and concrete examples in [FORMAT.md](FORMAT.md) are the contract for these stories. Example settings are illustrative. First migrate current gameplay exactly, then use the format to tune it in a separate pass.

JSON is supported directly by Godot, easy to diff, and needs no parser dependency. Use `designer_notes` for comments. Avoid JSON inheritance and deep merge chains in v1. Resolve shared profile references and local multipliers explicitly, with a readable resolved preview.

## Queue

| Story | Deliverable | Dependencies |
|---|---|---|
| LD01 | JSON contract, loader, validation and diagnostics | DONE |
| LD02 | Migrate nine existing levels and campaign lookup | DONE |
| LD03 | Spawn composition and per-level combat scaling | DONE |
| LD04 | Kill quotas and typed completion objectives | DONE |
| LD05 | Data-driven loot and guaranteed reward delivery | DONE; LD02; coordinate save ownership with LD06 |
| LD06 | Frozen run definitions and save migration | LD04, LD05 |
| LD07 | Player-facing conditions and designer tuning preview | LD04, LD05, LD06 |
| LD08 | End-to-end acceptance and initial tuning handoff | LD07 |

Detailed acceptance criteria: [STORIES.md](STORIES.md). Execute sequentially by default; LD05 can be developed independently after LD02 only with explicit file ownership coordination. Each story should leave the game runnable. No task has been dispatched merely by writing these stories.

## Copyable Luna task prompt

> Implement only story LDxx from work/level-data/STORIES.md. Read work/level-data/FORMAT.md and the predecessor completion notes first. Preserve current gameplay during migration. Do not resume simulator work, introduce XP, or apply speculative balance values. Complete the story's acceptance checks. Record changed files, actual checks/results, migration decisions and remaining issues in work/level-data/handoffs/LDxx.md; update the queue status here. Stop before later stories.

## Existing sources to migrate

- `prototype/data/campaign_definitions.gd`: nine map nodes, IDs, prerequisites and positions.
- `prototype/data/campaign_encounters.gd`: waves, fixed mana rewards and boss stats.
- `prototype/scripts/model/content_catalog.gd` and `loadout.gd`: well output, pressure factors, schedules and loadouts.
- `prototype/scripts/model/item_catalog.gd`: existing first-clear reward for **every** Act 1 node; do not add duplicate replacements.
- `prototype/scripts/model/item_definitions.gd` and live loot code: generation rules and item-level bounds.
- `prototype/scripts/model/campaign_catalog.gd`: currently enforces exactly nine nodes and one boss; replace this structural restriction with graph validation.
- `prototype/scripts/game/encounter_controller.gd`: item level derived from node suffix and scattered encounter routing.

Preserve existing level IDs (`act_01_node_01` etc.), well IDs, inventory ownership, completed nodes and claimed rewards. The first release of this migration must not reset anyone's progress.
