# Luna stories: data-driven levels

All stories use GPT-5.6 Luna. Read FORMAT.md as the proposed contract. Each story must report checks actually run and write a concise handoff. Do not expand simulator work or retune current encounters as part of migration.

## LD01 — Level contract and validated catalog

**Story:** As a designer, I can edit one readable file per level and receive a precise error when a value or reference is invalid.

**Scope:** Build manifest/act/level loading, normalized immutable resolved definitions, JSON Schema/editor hints and a command-line validator. Adapt shared references to existing catalogs; add explicit shared archetype/profile IDs only where needed. Provide example fixtures for waves, quota, boss and well modes. Decide and document bounded collection/count limits and defaults. Own new loader/schema code; do not reroute gameplay yet.

**Acceptance:** Valid fixtures load; malformed JSON, unknown properties, wrong types, invalid probabilities, zero/negative scaling, unsupported item levels, duplicate IDs/reward IDs, bad references, unsafe paths, graph cycles and objective/mode mismatches fail with filename plus field path. Whitespace/key order leave canonical hashes unchanged; gameplay edits change them. Returned dictionaries cannot mutate the catalog. Headless validation exits nonzero on failure. Resolve any FORMAT.md ambiguities in the handoff before downstream work.

## LD02 — Migrate the existing campaign without changing balance

**Story:** As a player, my existing campaign and progress work identically after levels move into data files.

**Dependencies:** LD01.

**Scope:** Author the manifest, Act 1 and all nine level JSON files using current map positions, prerequisite IDs, waves, boss values, well factors, loot item levels and first-clear rewards. Route CampaignCatalog through the new loader with compatible accessors. Make ContentCatalog well lookup read the same resolved source. Replace exact-nine-node validation with graph/content validation. Keep old definitions only as a clearly labeled legacy migration source if needed.

**Acceptance:** Compare every migrated value against current runtime definitions, including current first-clear item ownership/instance behavior. Existing campaign saves retain completion and unlocks. A fixture with a different valid node count works. Operations and campaign resolve the same well. No level ordering/suffix calculation determines gameplay values. Existing campaign tests pass with intentional fixture updates documented. Do not enable example kill quotas or new stats yet.

## LD03 — Data-driven spawns and stage scaling

**Story:** As a designer, I can change enemy composition and toughness for one level without modifying combat code.

**Dependencies:** LD02.

**Scope:** Route finite waves and extraction schedules through resolved definitions. Apply level and per-monster HP/damage/movement/attack-interval multipliers exactly once. Support named boss spawn identity and its shared archetype. Respect allowed monsters and alive caps. Own encounter/spawn/actor setup integration; preserve existing attack patterns.

**Acceptance:** Unit/runtime checks cover neutral factors, a known 2× HP enemy, composed per-monster factors, interval semantics, boss stats, allowed-pool rejection, wave delays and no spawn backlog at cap. Hero and machine stats do not accidentally inherit enemy scaling. Current migration files preserve gameplay. A fixture edit changes only its selected level. Snapshot capture includes resolved actor values pending LD06 completion.

## LD04 — Kill-count and other completion objectives

**Story:** As a player, I can see the remaining kill requirement and unlock the next available level when I satisfy it.

**Dependencies:** LD03.

**Scope:** Implement typed objective state for clear-waves, kill-count, boss defeat and extraction. Add seeded weighted quota spawning. Count unique eligible deaths; quota completion stops spawning and finalizes success once. Keep progress per run. Preserve ordinary early-extraction banking separately from campaign commissioning. Own objective state/command logic; expose a small HUD view model for LD07.

**Acceptance:** At 23/24 eligible kills the node is unfinished; the 24th completes once and makes eligible successors available. Duplicate/decorative/despawn/summoned kills do not count. Retry starts at zero; suspend state can capture and restore the count/credited IDs. Remaining actors cleaned up on quota completion produce no extra rewards. Boss objective cannot be satisfied by ordinary kills. A failed seal cannot commission a well. Count/loot callback order cannot lose or duplicate the final kill's legitimate reward. Player is not forced into the successor automatically.

## LD05 — Level loot settings and reliable first-clear rewards

**Story:** As a designer, I set drop item level and guaranteed items per level; as a player, I receive my first-clear reward exactly once, even when inventory is full.

**Dependencies:** LD02; coordinate with LD04 kill-event boundary and LD06 save ownership.

**Scope:** Remove suffix-derived item levels and fixed positional first-clear reward arrays from live routing. Read explicit loot/guarantee definitions. Preserve existing roll caps, modifiers and loot eligibility. Add stable reward entitlements, deterministic item generation, saved pending delivery and claim commands. Reuse inventory generation and validation rather than introducing an alternate item format.

**Acceptance:** Moving/reordering a node does not change its drop level. Common/rare guarantees generate valid instances through supported rules; guaranteed grants do not depend on ordinary drop RNG. Full inventory creates a persistent pending reward; freeing a slot delivers once. Repeated completion, claim, retry and reload cannot duplicate grants. Partial quantity delivery recovers correctly. All nine migrated rewards match existing behavior; migration reconciliation uses provenance/completion evidence and preserves discarded-item history where available. Write exact migration decision rules for LD06. No new rewards are added during migration.

## LD06 — Definition snapshots and save compatibility

**Story:** As a player, I can resume a run after a content update without its enemies, objective or earned rewards changing underneath me.

**Dependencies:** LD04, LD05.

**Scope:** Integrate frozen normalized level conditions/hash into run snapshots and restoration. Persist spawner RNG, objective progress/credited IDs, claim receipts and generated pending items using existing atomic save/recovery boundaries. Upgrade old saves without resetting completed levels or rerolling rewards. Own persistence changes; coordinate any earlier temporary snapshot fields.

**Acceptance:** Begin a run, edit its level JSON, then resume: the active run uses frozen conditions and the next run uses the edit. Reload cannot reroll spawn selection/guaranteed affixes or duplicate a terminal reward. Old completed-node/item saves migrate; old suspended runs follow documented faithful reconstruction or safe preparation fallback. Corrupt/unsupported snapshots fail safely. Pending rewards survive save failure/retry. A content revision bump alone does not regrant first-clear rewards. Tests exercise crash/retry boundaries around success, entitlement creation and inventory delivery.

## LD07 — Level conditions UI and tuning preview

**Story:** As a player, I understand a level's objective and potential rewards before entering; as a designer, I can inspect its resolved tuning without reading code.

**Dependencies:** LD04, LD05, LD06.

**Scope:** Show objective, eligible enemy types, dropped item level, first-clear reward/claimed or pending state, and locked prerequisites on preparation/map views. Show quota progress in combat. Add a designer-only textual preview/validation command for resolved factors, base/effective monster values, composition, objective and rewards. Display first-clear time targets only in the designer preview. Provide one documented content reload action outside active runs; no continuous file watcher required.

**Acceptance:** UI reads the resolved definition and live objective state, not copied strings or suffix rules. Monster, boss and well views show appropriate conditions without technical schema fields. Claimed guarantees are not presented as repeatable drops. Pending rewards have a clear claim action/full-inventory explanation. Changing one JSON file and reloading updates preparation/preview without changing an active run. Keyboard/controller access and existing layout checks remain usable.

## LD08 — Full acceptance and tuning handoff

**Story:** As the project owner, I can tune level files confidently and begin a separate Act 1 pacing pass.

**Dependencies:** LD07.

**Scope:** Verify a fresh account, representative old saves and suspend/resume against the migrated nine-level campaign. Remove obsolete live fallback paths that could silently bypass JSON while retaining explicitly required legacy migration data. Document editing, validation, shared references, reward identity rules and restart/reload behavior. Produce a table of actual current per-level inputs and observations for the next tuning pass.

**Acceptance:** Relevant campaign, combat, loot, inventory and recovery tests pass; all shipped level files validate. Changing one fixture's HP, quota and loot item level demonstrably changes only that level. Adding a valid fixture level requires no new switch/case or suffix special case. No replay reward exploit or progress reset in tested migrations. Report current gameplay parity and any material differences honestly. Do not resume the simulator or silently apply the illustrative 24-kill/2× HP settings. Leave the next balancing work as an explicit handoff with real-playtest measurements to collect.
