# Level format v1 proposal

## Manifest and identity

`campaign/index.json`: `{"schema_version":1,"act_files":["acts/act_01.json"]}`.

An act file contains `schema_version`, `id`, `display_name`, `layout_revision`, `level_files` (ordered paths relative to `data/`), and `completion_requires` (level IDs). An optional `next_act_id` identifies the following act. Ordering controls display, not unlocking. Each level owns its own `requires_completed` list. Validate all references and cycles across the campaign. Do not infer references from filename numbers.

`schema_version` describes the file structure; `content_revision` identifies a designer revision. Stable `id` persists in saves. Compute a canonical content hash on normalized resolved data, since designers may forget to bump a revision. Whitespace/key-order changes should not change that hash. Freeze gameplay-relevant resolved data at run start.

## Example: monster stage with a kill quota

This is an illustrative **future tuning example**, not a replacement for current Cinder Crossing values. Shared IDs such as `foundry_physical_v1` are proposed catalog IDs that LD01/LD02 must define or map explicitly.

```json
{
  "schema_version": 1,
  "content_revision": 1,
  "id": "act_01_node_04",
  "act_id": "act_01",
  "display_name": "Cinder Crossing",
  "type": "monster",
  "designer_notes": "Mixed threats. Tune for 45–60 seconds on first arrival.",
  "map": {"position": [0.37, 0.30]},
  "requires_completed": ["act_01_node_03"],
  "environment_id": "foundry",
  "encounter": {
    "mode": "kill_quota",
    "available_monsters": ["pursuer", "breaker", "ranged"],
    "scaling": {
      "hp_multiplier": 2.0,
      "damage_multiplier": 1.1,
      "move_speed_multiplier": 1.0,
      "attack_interval_multiplier": 1.0
    },
    "monster_overrides": {"breaker": {"hp_multiplier": 1.25}},
    "spawning": {
      "interval_seconds": 2.0,
      "max_alive": 8,
      "pool": [
        {"monster_id": "pursuer", "weight": 60},
        {"monster_id": "breaker", "weight": 25},
        {"monster_id": "ranged", "weight": 15}
      ]
    }
  },
  "completion": {
    "objective": "kill_count",
    "required_kills": 24,
    "count_monsters": ["pursuer", "breaker", "ranged"],
    "progress_scope": "run"
  },
  "rewards": {
    "mana_on_success": 5,
    "loot": {
      "table_id": "foundry_physical_v1",
      "item_level": 2,
      "ordinary_drop_chance": 0.02,
      "boss_drop_chance": 0.25
    },
    "guaranteed_items": [
      {
        "reward_id": "act_01_node_04.first_clear.cycler",
        "trigger": "first_clear",
        "base_id": "core.cycler",
        "item_level": 2,
        "rarity": "common",
        "quantity": 1
      }
    ]
  },
  "tuning_targets": {"first_clear_seconds": [45, 60]}
}
```

## Modes and fields

| Section | Fields and meaning |
|---|---|
| Identity | Required schema version, revision, stable level/act IDs, display name and type (`monster`, `well`, `boss`). |
| Map/access | Normalized position; prerequisite IDs; environment catalog reference. Conditions define access; completing a node makes qualifying successors available but does not auto-launch them. |
| Available monsters | Explicit allowlist. A spawn table or wave may reference only an allowed archetype. An allowed monster is not automatically spawned. |
| Scaling | Positive finite multipliers. Effective HP = archetype HP × level HP multiplier × per-monster HP multiplier. Same rule for damage, movement and interval. Interval 0.8 means attacks 20% sooner, not +20% attack rate. Defaults are 1, resolved visibly. |
| Monster overrides | Multipliers only in v1, plus a `role` entry when needed to identify the unique named boss. Do not override arbitrary scripts or invent per-level AI. Shared boss archetypes own base attack patterns. |
| Spawning | Tagged union: finite authored waves, weighted kill-quota spawner, or extraction schedule reference. Do not silently combine these modes. |
| Completion | Tagged objective tied to mode. Runtime state tracks unique credited deaths separately from loot RNG. |
| Rewards | Success mana, loot table and item-level override, explicit first-clear items. Every probability is a fraction in [0,1], weights are positive finite relative weights, item levels are integers supported by the generator (currently 1–3). |
| Tuning targets | Optional first-clear duration range. Documentation/preview only, never a forced timer or automatic difficulty adjustment. |

### Finite waves (migration default)

Use `encounter.mode: "waves"`; replace `spawning` with:

```json
{"waves": [
  {"monsters": [{"monster_id":"pursuer","count":2}], "delay_before_seconds":0},
  {"monsters": [{"monster_id":"breaker","count":1}], "delay_before_seconds":0}
]}
```

That object is the value of `encounter.spawning`. Completion is `{"objective":"clear_waves"}`. Spawn the next wave only after the preceding wave is cleared and its optional delay elapses. Preserve existing waves/counts during migration. Validate positive integer counts, capacity feasibility, and a nonempty population. Never leave a wave permanently blocked by a smaller alive cap; reject such authored combinations in v1.

### Kill quotas

The sample defines a weighted spawner and `required_kills`. Progress is **per run** in v1: a fresh attempt starts at zero; suspend/resume restores the current counter. No account-wide farming gate is introduced. The alive-cap skip does not queue a later burst. Seed spawn selection and save its state.

Only unique player-credited, nonsummoned deaths of `count_monsters` count. Despawns, scenery, duplicate callbacks, boss summons and other nodes do not. At the quota, stop spawning and succeed immediately; clean up remaining actors/projectiles without additional kills or loot. This defines completion clearly and avoids an invisible extra cleanup wave. Validate that at least one counted archetype has a positive spawn weight. If authored monsters are allowed but not counted, surface that distinction in the preview/HUD.

### Bosses

Use finite waves with a unique boss spawn entry tagged `role: "boss"` and `spawn_id: "crown_guardian"`. Define `completion: {"objective":"defeat_boss","boss_spawn_id":"crown_guardian"}`. The spawn entry may reuse a visual archetype, but its role must select the boss loot threshold and guardian family. Define a shared boss archetype for the current 240 HP / 18 damage / 3-second attack behavior instead of burying absolute boss values in controller code. Boss victory ends the encounter; summons never satisfy the objective or grant ordinary loot. A kill quota must not bypass a boss.

### Wells

Use `encounter.mode: "extraction"` and `spawning: {"schedule_id":"foundry_surges_v1"}`. Available-monster and scaling fields still apply. Add a top-level block:

```json
"well": {
  "id":"well_2",
  "base_mana_per_second":4.0,
  "spawn_interval_multiplier":0.8,
  "pressure_time_multiplier":1.0,
  "machine_integrity":150.0,
  "sealing_seconds":2.0,
  "payout_curve_id":"surge_payout_v1",
  "allowed_loadouts":["standard","overdrive","fortified"]
}
```

Completion is `{"objective":"extract","minimum_completed_surges":1}`. Reaching the surge count alone does not commission a well: the player must seal successfully. Preserve the current distinction between banking an early extraction and qualifying to complete/commission the campaign node. Use the same definition for campaign and Operations entry. A well ID maps to exactly one level in v1, preventing ambiguous Operations routing. Rewards mana is 0 for wells; extracted tank payout remains separate, avoiding duplicate payment.

The shared schedule/curve catalogs can initially be thin adapters over current values. New pressure curves or modifiers are a later balancing task, not required here. Research/loadout factors compose once with resolved level factors; never apply them again in the actor setup path.

## Guaranteed items and full inventory

`first_clear` is the only guarantee trigger in v1. Ordinary drops remain per-kill, using existing tables, rounding, caps, modifiers and generator semantics. A guaranteed item bypasses the drop-occurrence roll. `quantity` is a positive bounded integer; exact `base_id`, rarity and item level are supplied. Non-Common affixes use the existing generator with persisted deterministic results.

Each guarantee has a permanent globally unique `reward_id`, independent of filename order and content revision. Record level completion and reward entitlement atomically. If inventory is full, keep the actual generated item(s) in a bounded saved pending-reward queue; never silently lose the reward or force a retry for it. Save identity and rolled modifiers before delivery. Claim once when capacity is available; repeated clicks, retries, load, and replay cannot duplicate it. Treat quantity delivery item-by-item with stable child identities.

The existing nine first-clear item mappings must migrate to these IDs. Inspect current saved ownership/claim provenance before choosing the reconciliation rule; document how ambiguous older saves avoid duplicate rewards without deleting existing inventory. Do not infer a claim solely from currently owning an item, since the player may have discarded it. Level completion and any existing persistent reward receipt are the migration evidence. Retroactively introducing a new reward to previously cleared levels is an explicit future migration, not an incidental revision effect.

## Loading, validation and saves

- Load only manifest-listed files, with normalized paths restricted to the game's data directory. Never scan arbitrary file order. No code paths, shell commands or arbitrary resource loads in content fields.
- Validate strict types, finite/ranged numbers, unknown fields, IDs, references, graph cycles, monster eligibility, item levels and objective/mode compatibility. Reject typos instead of silently defaulting them. Error example: `act_01_node_04.json: encounter.scaling.hp_multiplier must be > 0`.
- Supply a CLI validation entry point and optional JSON Schema for editor hints. One validator defines runtime rules; do not create competing schema-only and runtime-only meanings.
- All-or-nothing catalog load: show a clear error and disable starting affected content; never silently launch a default encounter. Existing valid saves remain untouched.
- Preserve public catalog accessors via an adapter during migration. No exact-nine-node or exact-one-boss constraints. Validate actual requirements, not prototype counts.
- Freeze resolved encounter/objective/loot/guarantee conditions plus content hash at run start. Mid-run edits affect the next attempt, not the active or restored one. Save quota count, credited identities, wave/spawn clocks, spawn RNG, pending rewards and receipt identities through existing recovery machinery. Do not recompute loot item level from a node suffix on restore.
- Keep the legacy save path readable. If an old suspended run lacks frozen data, use its saved encounter settings plus the documented legacy mapping; if faithful reconstruction is impossible, return safely to preparation while preserving already banked progress and receipts, and explain the recovery. Never invent a successful result.
- No automatic XP fields in v1: XP is not implemented in the live game. Reserve a later schema revision when its behavior exists. Likewise defer affix customization, elemental/weather rules and arbitrary scripting until there is a concrete consumer.
