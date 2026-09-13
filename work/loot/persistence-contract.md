# D02 — Instance saves and loot transactions

Approved for L02–L06 implementation; this is a specification, not a claim that these changes already exist. Extend existing AccountState, SessionPersistence, SaveStore and RunSnapshot. No parallel save file or second authoritative inventory.

## Version and validation contract

L02 bumps outer save version 5 → 6 and snapshot version 4 → 5, config `prototype-loot-v1`. Continue supporting prior account migrations. Keep item schema version exactly 1; generation version is separately `loot-v1`. Future unknown outer/item/generation versions must use existing unsupported/recovery behavior, never silently coerce.

Account fields: `item_instances` (array of at most 100), `hero_kits` (known hero ID → dictionary with weapon/hero/harvester keys, empty string for unequipped), `inventory_migration_version` = 1, `last_loot_result` = `{run_id, item_ids}` for the most recent terminal run. Maintain existing run-ID allocation/terminal money idempotency. Instance lookup can be a runtime dictionary keyed by ID, serialized as a sorted array. Instance IDs must be unique across the account. Equipment references must be owned and slot-correct; no instance may be referenced by two kits.

Each instance stores all L01 fields plus `generation_version`, `provenance` `{kind, run_id, enemy_id, node_id}`, `inspected` boolean, `locked` boolean. Kind is `monster`, `legacy` or transitional `campaign`; empty run/node IDs and enemy ID 0 allowed only for legacy/transitional provenance. Monster enemy IDs are positive integral numbers. The serialized canonical form must preserve ALL these fields, not discard them as L01's serializer currently would. `last_loot_result` references may outlive discarded items: prune discarded IDs, never regenerate missing rewards.

IDs are `loot:<run_id>:<enemy_id>` for monster items and `legacy:<old_base_id>` for converted/transitional items. Treat them as opaque keys in UI/model, not strings to parse for stats. At most one item per enemy. No clock-derived or random identity; uniqueness derives from existing persisted run IDs and monotonic enemy IDs.

Validate tables once at startup independently of whether any bases exist. Validate item rarity count, bounds/step of each tier roll, level 1–3, eligible stat/operation/slot/family, generation version, exact implicit values and metadata types. Match floats with step-aware tolerance (1e-8), not an arbitrary broad epsilon. Reject nonfinite, fractional integral fields and unknown IDs. JSON integral-valued floats are legitimate integers after validation; bool/string are not. Normalize schema/tier/level/enemy IDs explicitly to int. Integer flat HP/vision modifiers require integral rolls; percent modifiers do not.

Copied implicits are authoritative saved rolls, validated against immutable `loot-v1` definitions. If balance later changes values, retain a versioned validation table and migrate explicitly; never reinterpret an old item on load against edited unversioned defaults. Production affix range/step validation and metadata preservation are L02 additions, not covered by L01's initial table schema.

## Legacy transition

If migration marker is absent, validate old ownership first. Convert each owned base to one Common level-1 instance with approved base implicit, no explicits, generation loot-v1, deterministic legacy ID, inspected = not old New, locked=false. Preserve known heroes, bank, research, campaign, production timestamps and all other noninventory progression. Start kits empty; no auto-equip. Set migration marker even for an empty collection. Remove old ownership/New/reward fields from new saves; expose only a temporary compatibility view if existing UI needs it.

Between L02 and L06, the old first-clear entry point may call an adapter that inserts the same `legacy:<base_id>` at most once, with campaign provenance. Its reconciliation must use that same identity. L06 removes BOTH new campaign grants and load-time first-clear backfill. Migration itself remains permanently available for older saves. A migrated/discarded item must not return on subsequent loads after cutover.

Old snapshot versions are intentionally not migrated. Reject only the old suspended encounter, clear campaign active node/act and transient run assignment, retain completed flags and account progress, and show: 'The suspended expedition was reset for the equipment update. Your banked progress and items were kept.' Save this reset coherently. Do not grant a pending old terminal reward from an incompatible snapshot. Unknown/corrupt account data still follows existing recovery rules; snapshot rejection is not permission to overwrite an unsupported account.

L02 must create the full snapshot-v5 codec shape with neutral/default resolved stats for the current game, even before L04 runtime effects. Reserve disabled loot state until L06. This prevents a second incompatible snapshot bump during this queue. Do not enable monster rolls early.

## Frozen run snapshot

Encode, validate and restore all current data plus: resolved hero/weapon/harvest stats, equipped instance IDs, selected weapon mode, remaining regen delay, campaign identity/config/wave/boss timer, director state, actual weapon interval/count/pierce/speed, harvest cadence/accumulator and specialization, hero resolved max HP, monster family/eligibility, and loot state below. Keep actor/component and projectile hit/pierce state complete. Restore these frozen values; do not rerun research/equipment resolution on resume.

Audit existing codec: controller capture currently includes campaign/director dictionaries that RunSnapshot.encode does not emit; its weapon interval and hero max HP use Balance constants. Fix this contract gap in L02's codec and L04's runtime capture/restore. Tests must assert real serialized round-trips, not just raw `_capture_snapshot()` content. Do not silently default missing mandatory v5 fields.

Loot state: `{enabled, generation_version, item_level, rng_state, retired_ranges, acquired_item_ids}`. Enabled is false until L06. `retired_ranges` is sorted, merged, nonoverlapping inclusive integer intervals covering every processed death or despawn for the current run. Record even ineligible and no-drop outcomes. This avoids an unbounded list of individual IDs during long wells: gaps are live actor IDs, so interval count is bounded by live actors + 1. Validate every retired ID below next_enemy_id, and no retired ID may be a live actor. Allocate enemy IDs strictly monotonically; never reuse them within a run.

On an incoming death event, check run active, enemy belongs to run and not retired, then mark it retired exactly once. Despawn/cleanup also retires but never rolls. Only genuine eligible combat deaths roll. Acquired item IDs lists only items from this run and is bounded by storage capacity; active-run discard/equip are disabled. On terminal resolution copy acquired IDs to last_loot_result, clear active snapshot and prune the run-only ledger/RNG after that coherent terminal state is saved. Never clear the ledger while retaining a resumable earlier world.

## RNG and roll order

Use a dedicated explicit Park–Miller integer stream: next state = `(state * 48271) % 2147483647`, initial state in 1…2147483646. Products fit signed 64-bit. Store the positive 31-bit integer directly in JSON (no 64-bit precision ambiguity). Initialize with the first 8 hexadecimal digits of SHA-256 of `loot-v1|<run_id>` modulo 2147483646, plus 1; initialize once before run-start save. This is reproducibility, not cryptographic anti-cheat.

Uniform bound n: generate x = next_state - 1; reject x >= floor(2147483646/n)*n, otherwise x % n. Do not use modulo alone or global RNG. All catalog iteration is ascending stable ID order. Draw occurrence first; on success draw rarity, base weight, then each affix family weight and its step roll in that order. Tier is fixed by item level, consuming no draw. Capacity skip/ineligible/duplicate consumes no draw. Generator returns state and the exact item or no-drop reason; it does not mutate account/world.

Persist the post-roll state, never reroll on save retry. A crash before the next successful checkpoint restores the earlier world and stream together; replaying its same deaths in the same order reproduces rolls. Choosing a different combat history may change rolls; this is not a server-authoritative anti-cheat design.

## Checkpoints and failed saves

Current SessionPersistence retains a copied snapshot but a live account reference. That can combine newer ownership with an older world on retry. L02 must replace this with an immutable pending envelope: copied account payload, campaign payload, timestamp and matching snapshot, all captured on the main thread at a coherent boundary. Refactor SaveStore to accept/validate payload values, or reconstruct an isolated AccountState from the copied payload. Never retain the live account object in a pending transaction.

L06 queues death events and processes them at the end of a simulation tick after all damage/projectile mutations, in ascending enemy ID order within that tick. Remove dead actors before capture. For the final boss/wave kill, process rewards before campaign terminal commitment. After all mutations, capture a complete consistent checkpoint. At most one synchronous save attempt per 250 ms of unpaused simulation while kills/loot state are dirty; ordinary frames do not write. This also checkpoints no-drop kills. Coalesce to the newest COMPLETE envelope, never mix sections from different revisions.

Force a coherent checkpoint on run start, pause/suspend, terminal result, return/abandon and normal application close. Before leaving operations, inventory modifications save coherently with empty active snapshot. Starting a run must not reuse a previously committed run ID. No loot save from inside a damage callback or HUD refresh.

If writing fails, retain the latest complete pending envelope and exact in-memory rolls. Show the existing unsaved-progress notice; do not block simulation every frame. Retry no more frequently than every 2 real seconds (or explicit user Retry). While unsaved mutations continue, replace pending only with a newer complete envelope. If running becomes terminal, pending terminal data supersedes old active data. A Retry must never combine an old world with current ownership. Timer writes are disabled for injected test sessions with persistence_enabled=false.

Items collected after the last successful save can be lost on abrupt termination; do not claim otherwise. The 250 ms checkpoint window is provisional pending L08 cost measurements. A failed save expands it until recovery. Runtime inventory still shows collected items and preserves them through ordinary failure/abandonment in memory.

## Capacity and commands

100 stored instances, equipped included. At capacity retire the death normally but skip RNG and item creation; throttle notice to once per 5 real seconds. No hidden overflow queue or deletion. Do not consume a drop roll then silently drop the result. Allow inspection/locking outside active/suspended runs; equip/unequip/discard require that same idle condition. Discard rejects equipped or locked items and requires the UI's named-item confirmation. Unknown IDs return an explicit failure without saving.

Tests: JSON disk round-trip, exact retry snapshots while simulation advances, failed boss terminal save, full storage, ineligible/dead/duplicate events, ordinary no-drop reload, retained loot after failure/abandon, old migration twice, discarded migrated items stay absent, per-hero ownership conflicts, resolved research/mode/cadence restored and retired-range boundedness over 100,000 deaths. Use isolated files and injected accounts; never the user's profile.
