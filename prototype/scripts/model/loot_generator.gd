class_name LootGenerator
extends RefCounted

const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")

const GENERATION_VERSION: String = "loot-v1"
const RNG_MODULUS: int = 2147483647
const RNG_MULTIPLIER: int = 48271
const ORDINARY_OCCURRENCE: int = 200
const BOSS_OCCURRENCE: int = 2500
const MAX_OCCURRENCE: int = 3000
const RARITY_THRESHOLDS := [6000, 9000, 9900, 10000]
const RARITIES := ["common", "magic", "rare", "epic"]
const BASE_IDS := [
    "chassis.bulwark", "chassis.jump_servos", "chassis.runner",
    "core.accelerator", "core.cycler", "core.heavy_breech",
    "module.bracing", "module.fast_cycle", "module.high_volume",
]

static func generate(input: Dictionary, rng_state: int) -> Dictionary:
    var initial_state: int = _normalize_state(rng_state)
    var table_result: Dictionary = _validate_tables()
    if not table_result.valid:
        return {"valid": false, "error": table_result.error, "rng_state": initial_state}
    var input_result: Dictionary = _validate_input(input)
    if not input_result.valid:
        return {"valid": false, "error": input_result.error, "rng_state": initial_state}
    if not bool(input.get("eligible", true)):
        return _no_roll("ineligible", initial_state)
    if int(input.get("inventory_count", 0)) >= int(input.get("inventory_capacity", 100)):
        return _no_roll("capacity", initial_state)

    var state: int = initial_state
    var occurrence_draw: Array = _draw_bounded(state, 10000)
    state = int(occurrence_draw[0])
    var occurrence_roll: int = int(occurrence_draw[1])
    var occurrence_threshold: int = _occurrence_threshold(str(input.get("occurrence_kind", "ordinary")), float(input.get("drop_bonus", 0.0)))
    if OS.is_debug_build() and input.has("development_drop_percent"):
        occurrence_threshold = int(round(float(input.development_drop_percent) * 100.0))
    if occurrence_roll >= occurrence_threshold:
        return {"valid": true, "generated": false, "reason": "no_drop", "rng_state": state, "occurrence_roll": occurrence_roll, "occurrence_threshold": occurrence_threshold}

    var rarity_draw: Array = _draw_bounded(state, 10000)
    state = int(rarity_draw[0])
    var rarity_roll: int = int(rarity_draw[1])
    var rarity: String = _rarity_for_roll(rarity_roll)
    var base_draw: Array = _draw_bounded(state, BASE_IDS.size())
    state = int(base_draw[0])
    var base_index: int = int(base_draw[1])
    var base_id: String = BASE_IDS[base_index]
    var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES[base_id]
    var explicit_count: int = int(ItemDefinitionsScript.RARITY_MODIFIER_COUNTS[rarity])
    var eligible_affixes: Array[String] = _eligible_affix_ids(str(base.get("slot", "")), int(input.get("item_level", 1)))
    if eligible_affixes.size() < explicit_count:
        return {"valid": false, "error": "unsatisfiable affix pool for selected base and rarity", "rng_state": initial_state}

    var explicit_modifiers: Array[Dictionary] = []
    var remaining_affixes: Array[String] = eligible_affixes.duplicate()
    for index in range(explicit_count):
        var family_draw: Array = _draw_bounded(state, _weighted_total(remaining_affixes))
        state = int(family_draw[0])
        var family_index: int = int(family_draw[1])
        var affix_id: String = _weighted_affix_at(remaining_affixes, family_index)
        remaining_affixes.erase(affix_id)
        var affix: Dictionary = ItemDefinitionsScript.PRODUCTION_AFFIXES[affix_id]
        var tier: int = mini(3, int(input.get("item_level", 1)))
        var tier_range: Dictionary = affix.tiers[tier]
        var steps: int = int(round((float(tier_range.max) - float(tier_range.min)) / float(tier_range.step)))
        var value_draw: Array = _draw_bounded(state, steps + 1)
        state = int(value_draw[0])
        var roll_step: int = int(value_draw[1])
        var value: float = _stable_round(float(tier_range.min) + float(roll_step) * float(tier_range.step), float(tier_range.step))
        explicit_modifiers.append({"affix_id": affix_id, "tier": tier, "value": value})

    var instance_id: String = "loot:%s:%d" % [str(input.get("run_id", "")), int(input.get("enemy_id", 0))]
    var instance := {
        "schema_version": 1,
        "instance_id": instance_id,
        "base_id": base_id,
        "rarity": rarity,
        "item_level": int(input.get("item_level", 1)),
        "implicit_modifiers": base.get("implicits", []).duplicate(true),
        "explicit_modifiers": explicit_modifiers,
        "generation_version": GENERATION_VERSION,
        "provenance": {"kind": "monster", "run_id": str(input.get("run_id", "")), "enemy_id": int(input.get("enemy_id", 0)), "node_id": str(input.get("node_id", ""))},
        "inspected": false,
        "locked": false,
    }
    var validation: Dictionary = ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.PRODUCTION_BASES, ItemDefinitionsScript.PRODUCTION_AFFIXES)
    if not validation.valid:
        return {"valid": false, "error": validation.error, "rng_state": initial_state}
    return {"valid": true, "generated": true, "instance": instance, "rng_state": state, "occurrence_roll": occurrence_roll, "occurrence_threshold": occurrence_threshold, "rarity_roll": rarity_roll}

static func _validate_input(input: Dictionary) -> Dictionary:
    if input.has("development_drop_percent"):
        var override: Variant = input.development_drop_percent
        if not (override is int or override is float) or not is_finite(float(override)) or float(override) < 0.0 or float(override) > 100.0:
            return {"valid": false, "error": "development drop percent must be 0 through 100"}
    var item_level: Variant = input.get("item_level", 1)
    if not (item_level is int or item_level is float) or int(item_level) < 1 or int(item_level) > 3 or float(item_level) != floor(float(item_level)):
        return {"valid": false, "error": "item level must be an integer from 1 through 3"}
    var drop_bonus: float = float(input.get("drop_bonus", 0.0))
    if not is_finite(drop_bonus) or drop_bonus < 0.0 or drop_bonus > 0.50:
        return {"valid": false, "error": "drop bonus must be between 0 and 0.50"}
    var inventory_count: Variant = input.get("inventory_count", 0)
    var inventory_capacity: Variant = input.get("inventory_capacity", 100)
    if not (inventory_count is int or inventory_count is float) or not (inventory_capacity is int or inventory_capacity is float) or int(inventory_count) < 0 or int(inventory_capacity) < 0:
        return {"valid": false, "error": "inventory capacity values are invalid"}
    var occurrence_kind: String = str(input.get("occurrence_kind", "ordinary"))
    if not ["ordinary", "boss"].has(occurrence_kind):
        return {"valid": false, "error": "occurrence kind is invalid"}
        if str(input.get("run_id", "")).is_empty() or int(input.get("enemy_id", 0)) <= 0 or str(input.get("node_id", "")).is_empty():
            return {"valid": false, "error": "monster provenance is incomplete"}
    return {"valid": true}

static func _validate_tables() -> Dictionary:
    var definitions := ItemDefinitionsScript.new()
    var result: Dictionary = definitions.validate_catalog(ItemDefinitionsScript.PRODUCTION_BASES, ItemDefinitionsScript.PRODUCTION_AFFIXES)
    if not result.valid:
        return result
    for base_id in BASE_IDS:
        if not ItemDefinitionsScript.PRODUCTION_BASES.has(base_id):
            return {"valid": false, "error": "approved base table is incomplete"}
    for affix_id in ItemDefinitionsScript.PRODUCTION_AFFIXES.keys():
        if not ItemDefinitionsScript.PRODUCTION_AFFIXES[affix_id].has("tiers"):
            return {"valid": false, "error": "approved affix table has no tiers"}
    return {"valid": true}

static func _eligible_affix_ids(slot: String, item_level: int) -> Array[String]:
    var ids: Array[String] = []
    for affix_id in ItemDefinitionsScript.PRODUCTION_AFFIXES.keys():
        var affix: Dictionary = ItemDefinitionsScript.PRODUCTION_AFFIXES[affix_id]
        if affix.eligible_slots.has(slot) and item_level >= 1:
            ids.append(str(affix_id))
    ids.sort()
    return ids

static func _occurrence_threshold(kind: String, drop_bonus: float) -> int:
    var base_threshold: int = BOSS_OCCURRENCE if kind == "boss" else ORDINARY_OCCURRENCE
    return mini(MAX_OCCURRENCE, int(floor(float(base_threshold) * (1.0 + drop_bonus) + 0.5)))

static func _rarity_for_roll(roll: int) -> String:
    for index in RARITY_THRESHOLDS.size():
        if roll < int(RARITY_THRESHOLDS[index]):
            return RARITIES[index]
    return "epic"

static func _weighted_total(ids: Array[String]) -> int:
    var total := 0
    for affix_id in ids:
        total += int(ItemDefinitionsScript.PRODUCTION_AFFIXES[affix_id].get("weight", 0))
    return total

static func _weighted_affix_at(ids: Array[String], offset: int) -> String:
    var remaining := offset
    for affix_id in ids:
        remaining -= int(ItemDefinitionsScript.PRODUCTION_AFFIXES[affix_id].get("weight", 0))
        if remaining < 0:
            return affix_id
    return ids.back()

static func _draw_bounded(state: int, bound: int) -> Array:
    if bound <= 0:
        return [state, 0]
    var limit: int = (RNG_MODULUS - 1) / bound * bound
    var next_state: int = state
    var sample: int = 0
    while true:
        next_state = int((next_state * RNG_MULTIPLIER) % RNG_MODULUS)
        sample = next_state - 1
        if sample < limit:
            return [next_state, sample % bound]
    return [next_state, 0]

static func _normalize_state(state: int) -> int:
    var normalized: int = state % RNG_MODULUS
    return 1 if normalized <= 0 else normalized

static func _stable_round(value: float, step: float) -> float:
    var places := 0
    var scaled_step := step
    while places < 6 and not is_equal_approx(scaled_step, round(scaled_step)):
        scaled_step *= 10.0
        places += 1
    return snappedf(value, step)

static func _no_roll(reason: String, state: int) -> Dictionary:
    return {"valid": true, "generated": false, "reason": reason, "rng_state": state}
