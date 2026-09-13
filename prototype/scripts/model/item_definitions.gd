class_name ItemDefinitions
extends RefCounted

const RARITIES := {
    "common": 0,
    "magic": 1,
    "rare": 2,
    "epic": 3,
}
const RARITY_MODIFIER_COUNTS := {
    "common": 0,
    "magic": 1,
    "rare": 2,
    "epic": 3,
}
const SLOTS := ["weapon", "hero", "harvester"]
const OPERATIONS := ["flat", "increased"]
const INTEGER_STATS := ["max_health", "vision_radius"]
const STAT_NAMES := [
    "attack_damage",
    "attacks_per_second",
    "armor",
    "max_health",
    "move_speed",
    "vision_radius",
    "health_regen",
    "mining_bonus",
    "drop_bonus",
    "projectile_speed",
    "damage_vs.swarm",
    "damage_vs.armored",
    "damage_vs.guardian",
    "resistance.fire",
    "resistance.shock",
    "resistance.toxin",
]
const GENERATION_VERSION := "loot-v1"
const PRODUCTION_BASES := {
    "core.heavy_breech": {"id": "core.heavy_breech", "label": "Heavy Breech", "slot": "weapon", "implicits": [{"stat": "attack_damage", "operation": "flat", "family": "implicit.core.heavy_breech.attack_damage", "value": 2}]},
    "core.cycler": {"id": "core.cycler", "label": "Cycle Driver", "slot": "weapon", "implicits": [{"stat": "attacks_per_second", "operation": "increased", "family": "implicit.core.cycler.attacks_per_second", "value": 0.08}]},
    "core.accelerator": {"id": "core.accelerator", "label": "Long Accelerator", "slot": "weapon", "implicits": [{"stat": "projectile_speed", "operation": "increased", "family": "implicit.core.accelerator.projectile_speed", "value": 0.12}]},
    "chassis.bulwark": {"id": "chassis.bulwark", "label": "Bulwark Plating", "slot": "hero", "implicits": [{"stat": "armor", "operation": "flat", "family": "implicit.chassis.bulwark.armor", "value": 12}]},
    "chassis.runner": {"id": "chassis.runner", "label": "Runner Frame", "slot": "hero", "implicits": [{"stat": "move_speed", "operation": "increased", "family": "implicit.chassis.runner.move_speed", "value": 0.06}]},
    "chassis.jump_servos": {"id": "chassis.jump_servos", "label": "Jump Servos", "slot": "hero", "implicits": [{"stat": "max_health", "operation": "flat", "family": "implicit.chassis.jump_servos.max_health", "value": 10}]},
    "module.high_volume": {"id": "module.high_volume", "label": "High-volume Cylinder", "slot": "harvester", "implicits": [{"stat": "mining_bonus", "operation": "flat", "family": "implicit.module.high_volume.mining_bonus", "value": 0.08}]},
    "module.fast_cycle": {"id": "module.fast_cycle", "label": "Fast-cycle Rotor", "slot": "harvester", "implicits": [{"stat": "health_regen", "operation": "flat", "family": "implicit.module.fast_cycle.health_regen", "value": 0.2}]},
    "module.bracing": {"id": "module.bracing", "label": "Anchor Bracing", "slot": "harvester", "implicits": [{"stat": "armor", "operation": "flat", "family": "implicit.module.bracing.armor", "value": 8}]},
}
const PRODUCTION_AFFIXES := {
    "affix.payload": {"id": "affix.payload", "stat": "attack_damage", "operation": "flat", "family": "payload", "eligible_slots": ["weapon"], "weight": 100, "tiers": {1: {"min": 1, "max": 2, "step": 1}, 2: {"min": 2, "max": 3, "step": 1}, 3: {"min": 3, "max": 4, "step": 1}}},
    "affix.force": {"id": "affix.force", "stat": "attack_damage", "operation": "increased", "family": "force", "eligible_slots": ["weapon"], "weight": 100, "tiers": {1: {"min": 0.03, "max": 0.05, "step": 0.01}, 2: {"min": 0.06, "max": 0.08, "step": 0.01}, 3: {"min": 0.09, "max": 0.12, "step": 0.01}}},
    "affix.tempo": {"id": "affix.tempo", "stat": "attacks_per_second", "operation": "increased", "family": "tempo", "eligible_slots": ["weapon"], "weight": 100, "tiers": {1: {"min": 0.03, "max": 0.05, "step": 0.01}, 2: {"min": 0.06, "max": 0.08, "step": 0.01}, 3: {"min": 0.09, "max": 0.12, "step": 0.01}}},
    "affix.plating": {"id": "affix.plating", "stat": "armor", "operation": "flat", "family": "plating", "eligible_slots": ["hero", "harvester"], "weight": 100, "tiers": {1: {"min": 4, "max": 6, "step": 1}, 2: {"min": 7, "max": 10, "step": 1}, 3: {"min": 11, "max": 15, "step": 1}}},
    "affix.vitality": {"id": "affix.vitality", "stat": "max_health", "operation": "flat", "family": "vitality", "eligible_slots": ["hero", "harvester"], "weight": 100, "tiers": {1: {"min": 5, "max": 8, "step": 1}, 2: {"min": 9, "max": 12, "step": 1}, 3: {"min": 13, "max": 18, "step": 1}}},
    "affix.mobility": {"id": "affix.mobility", "stat": "move_speed", "operation": "increased", "family": "mobility", "eligible_slots": ["hero"], "weight": 100, "tiers": {1: {"min": 0.02, "max": 0.03, "step": 0.01}, 2: {"min": 0.04, "max": 0.05, "step": 0.01}, 3: {"min": 0.06, "max": 0.08, "step": 0.01}}},
    "affix.recovery": {"id": "affix.recovery", "stat": "health_regen", "operation": "flat", "family": "recovery", "eligible_slots": ["hero", "harvester"], "weight": 100, "tiers": {1: {"min": 0.1, "max": 0.15, "step": 0.05}, 2: {"min": 0.2, "max": 0.25, "step": 0.05}, 3: {"min": 0.3, "max": 0.4, "step": 0.05}}},
    "affix.extraction": {"id": "affix.extraction", "stat": "mining_bonus", "operation": "flat", "family": "extraction", "eligible_slots": ["harvester"], "weight": 100, "tiers": {1: {"min": 0.03, "max": 0.05, "step": 0.01}, 2: {"min": 0.06, "max": 0.08, "step": 0.01}, 3: {"min": 0.09, "max": 0.12, "step": 0.01}}},
    "affix.fortune": {"id": "affix.fortune", "stat": "drop_bonus", "operation": "flat", "family": "fortune", "eligible_slots": ["weapon", "hero", "harvester"], "weight": 100, "tiers": {1: {"min": 0.03, "max": 0.05, "step": 0.01}, 2: {"min": 0.06, "max": 0.08, "step": 0.01}, 3: {"min": 0.09, "max": 0.12, "step": 0.01}}},
    "affix.hunter": {"id": "affix.hunter", "stat": "damage_vs.swarm", "operation": "flat", "family": "hunter", "eligible_slots": ["weapon"], "weight": 100, "tiers": {1: {"min": 0.05, "max": 0.08, "step": 0.01}, 2: {"min": 0.09, "max": 0.12, "step": 0.01}, 3: {"min": 0.13, "max": 0.18, "step": 0.01}}},
    "affix.breaker": {"id": "affix.breaker", "stat": "damage_vs.armored", "operation": "flat", "family": "breaker", "eligible_slots": ["weapon"], "weight": 100, "tiers": {1: {"min": 0.05, "max": 0.08, "step": 0.01}, 2: {"min": 0.09, "max": 0.12, "step": 0.01}, 3: {"min": 0.13, "max": 0.18, "step": 0.01}}},
}

static func validate_catalog(catalog: Dictionary, affix_table: Dictionary = {}) -> Dictionary:
    for base_id in catalog.keys():
        if not base_id is String or base_id.is_empty():
            return _failure("base item IDs must be non-empty strings")
        var base: Variant = catalog[base_id]
        if not base is Dictionary:
            return _failure("base item definitions must be objects")
        if base.get("id", "") != base_id:
            return _failure("base item ID does not match its catalog key")
        if not SLOTS.has(base.get("slot", "")):
            return _failure("base item slot is invalid")
        if not base.get("label", "") is String or str(base.get("label", "")).is_empty():
            return _failure("base item label is required")
        var implicits: Variant = base.get("implicits", [])
        if not implicits is Array:
            return _failure("base item implicits must be an array")
        var families := {}
        for modifier in implicits:
            var result := _validate_typed_modifier(modifier, families)
            if not result.valid:
                return result
    for affix_id in affix_table.keys():
        if not affix_id is String or affix_id.is_empty():
            return _failure("affix IDs must be non-empty strings")
        var affix: Variant = affix_table[affix_id]
        if not affix is Dictionary or affix.get("id", "") != affix_id:
            return _failure("affix ID does not match its table key")
        if not OPERATIONS.has(affix.get("operation", "")) or not STAT_NAMES.has(affix.get("stat", "")):
            return _failure("affix operation or stat is invalid")
        if not affix.get("family", "") is String or str(affix.get("family", "")).is_empty():
            return _failure("affix family is required")
        var eligible_slots: Variant = affix.get("eligible_slots", [])
        if not eligible_slots is Array or eligible_slots.is_empty():
            return _failure("affix eligible slots are required")
        for slot in eligible_slots:
            if not SLOTS.has(slot):
                return _failure("affix eligible slot is invalid")
        if affix.has("tiers"):
            if not affix.tiers is Dictionary:
                return _failure("affix tiers must be an object")
            for tier in [1, 2, 3]:
                if not affix.tiers.has(tier):
                    return _failure("affix tier table is incomplete")
                var range: Variant = affix.tiers[tier]
                if not range is Dictionary or not _valid_roll_range(range):
                    return _failure("affix tier range is invalid")
        elif not _valid_integer(affix.get("min_tier", 0)) or not _valid_integer(affix.get("max_tier", 0)) or int(affix["min_tier"]) < 1 or int(affix["max_tier"]) < int(affix["min_tier"]):
            return _failure("affix tier range is invalid")
    
    return _success()

static func validate_instance(instance: Dictionary, catalog: Dictionary, affix_table: Dictionary) -> Dictionary:
    for field in ["schema_version", "instance_id", "base_id", "rarity", "item_level", "implicit_modifiers", "explicit_modifiers", "generation_version", "provenance", "inspected", "locked"]:
        if not instance.has(field):
            return _failure("instance is missing " + field)
    if not _valid_integer(instance.schema_version) or int(instance.schema_version) != 1:
        return _failure("instance schema version is invalid")
    if not instance.instance_id is String or instance.instance_id.is_empty():
        return _failure("instance ID must be a non-empty opaque string")
    if not instance.base_id is String or not catalog.has(instance.base_id):
        return _failure("instance base ID is unknown")
    if instance.instance_id == instance.base_id:
        return _failure("instance ID must be separate from base ID")
    if not instance.rarity is String or not RARITIES.has(instance.rarity):
        return _failure("instance rarity is invalid")
    if not _valid_integer(instance.item_level) or int(instance.item_level) < 1:
        return _failure("instance item level is invalid")
    if instance.generation_version != GENERATION_VERSION:
        return _failure("instance generation version is invalid")
    if not instance.inspected is bool or not instance.locked is bool:
        return _failure("instance metadata flags are invalid")
    var provenance_result := _validate_provenance(instance.provenance)
    if not provenance_result.valid:
        return provenance_result
    var base: Dictionary = catalog[instance.base_id]
    var implicit_modifiers: Variant = instance.implicit_modifiers
    if not implicit_modifiers is Array or not _same_implicits(implicit_modifiers, base.get("implicits", [])):
        return _failure("instance implicits must match the authored base implicits")
    var implicit_families := {}
    for modifier in implicit_modifiers:
        var implicit_result := _validate_typed_modifier(modifier, implicit_families)
        if not implicit_result.valid:
            return implicit_result
    var explicit_modifiers: Variant = instance.explicit_modifiers
    if not explicit_modifiers is Array:
        return _failure("instance explicit modifiers must be an array")
    if explicit_modifiers.size() != int(RARITY_MODIFIER_COUNTS[instance.rarity]):
        return _failure("explicit modifier count does not match rarity")
    var families := implicit_families.duplicate()
    for modifier in explicit_modifiers:
        if not modifier is Dictionary:
            return _failure("explicit modifiers must be objects")
        for field in ["affix_id", "tier", "value"]:
            if not modifier.has(field):
                return _failure("explicit modifier is missing " + field)
        var affix_id: Variant = modifier.affix_id
        if not affix_id is String or not affix_table.has(affix_id):
            return _failure("explicit modifier uses an unknown affix ID")
        var affix: Dictionary = affix_table[affix_id]
        if not affix.eligible_slots.has(base.slot):
            return _failure("affix is not eligible for the base slot")
        var tier_range: Dictionary = affix.tiers.get(int(modifier.tier), {}) if affix.has("tiers") else {"min": 0.0, "max": 0.0, "step": 0.0}
        if not _valid_integer(modifier.tier) or (affix.has("tiers") and tier_range.is_empty()) or (not affix.has("tiers") and (int(modifier.tier) < int(affix.min_tier) or int(modifier.tier) > int(affix.max_tier))) or int(modifier.tier) > int(instance.item_level):
            return _failure("explicit modifier tier is invalid for item level")
        var typed_modifier := {
            "stat": affix.stat,
            "operation": affix.operation,
            "family": affix.family,
            "value": modifier.value,
        }
        var modifier_result := _validate_typed_modifier(typed_modifier, families)
        if not modifier_result.valid:
            return modifier_result
        if affix.has("tiers") and not _value_in_range(float(modifier.value), tier_range):
            return _failure("explicit modifier value is outside its approved range")
    return _success()

static func validate_instances(instances: Array, catalog: Dictionary, affix_table: Dictionary) -> Dictionary:
    var seen := {}
    for instance in instances:
        if not instance is Dictionary:
            return _failure("instances must be objects")
        var instance_id: Variant = instance.get("instance_id", "")
        if not instance_id is String or seen.has(instance_id):
            return _failure("instance IDs must be unique")
        seen[instance_id] = true
        var result := validate_instance(instance, catalog, affix_table)
        if not result.valid:
            return result
    return _success()

static func serialize_instance(instance: Dictionary) -> String:
    return JSON.stringify(_canonical_instance(instance))

static func _canonical_instance(instance: Dictionary) -> Dictionary:
    return {
        "schema_version": instance.get("schema_version", 1),
        "instance_id": instance.get("instance_id", ""),
        "base_id": instance.get("base_id", ""),
        "rarity": instance.get("rarity", ""),
        "item_level": instance.get("item_level", 0),
        "implicit_modifiers": instance.get("implicit_modifiers", []),
        "explicit_modifiers": instance.get("explicit_modifiers", []),
        "generation_version": instance.get("generation_version", GENERATION_VERSION),
        "provenance": instance.get("provenance", {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}),
        "inspected": instance.get("inspected", false),
        "locked": instance.get("locked", false),
    }

static func _validate_typed_modifier(modifier: Variant, families: Dictionary) -> Dictionary:
    if not modifier is Dictionary:
        return _failure("typed modifiers must be objects")
    if not STAT_NAMES.has(modifier.get("stat", "")) or not OPERATIONS.has(modifier.get("operation", "")):
        return _failure("typed modifier stat or operation is invalid")
    var family: Variant = modifier.get("family", "")
    if not family is String or family.is_empty():
        return _failure("typed modifier family is required")
    if families.has(family):
        return _failure("modifier families cannot repeat")
    var value: Variant = modifier.get("value", null)
    if not (value is int or value is float) or not is_finite(float(value)):
        return _failure("modifier values must be finite numbers")
    if modifier.operation == "flat" and modifier.stat in INTEGER_STATS and float(value) != floor(float(value)):
        return _failure("integer-valued stats cannot be fractional")
    families[family] = true
    return _success()

static func _validate_provenance(provenance: Variant) -> Dictionary:
    if not provenance is Dictionary:
        return _failure("instance provenance must be an object")
    if not ["monster", "legacy", "campaign"].has(provenance.get("kind", "")):
        return _failure("instance provenance kind is invalid")
    if not provenance.get("run_id", "") is String or not provenance.get("node_id", "") is String:
        return _failure("instance provenance identity is invalid")
    if not _valid_integer(provenance.get("enemy_id", 0)) or int(provenance.get("enemy_id", 0)) < 0:
        return _failure("instance provenance enemy ID is invalid")
    if provenance.kind == "monster" and (str(provenance.run_id).is_empty() or int(provenance.enemy_id) < 1):
        return _failure("monster provenance is incomplete")
    return _success()

static func _valid_roll_range(range: Dictionary) -> bool:
    for field in ["min", "max", "step"]:
        if not (range.get(field) is int or range.get(field) is float) or not is_finite(float(range[field])):
            return false
    return float(range.min) <= float(range.max) and float(range.step) > 0.0 and _value_in_range(float(range.max), range)

static func _value_in_range(value: float, range: Dictionary) -> bool:
    if value < float(range.min) - 1e-8 or value > float(range.max) + 1e-8:
        return false
    var steps := (value - float(range.min)) / float(range.step)
    return absf(steps - roundf(steps)) <= 1e-8

static func _same_implicits(actual: Array, expected: Array) -> bool:
    if actual.size() != expected.size():
        return false
    for i in range(actual.size()):
        if not actual[i] is Dictionary or actual[i].size() != expected[i].size():
            return false
        for key in expected[i]:
            if not actual[i].has(key):
                return false
            if key == "value":
                var value: Variant = actual[i][key]
                if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(expected[i][key]):
                    return false
            elif actual[i][key] != expected[i][key]:
                return false
    return true

static func _valid_integer(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func _success() -> Dictionary:
    return {"valid": true}

static func _failure(error: String) -> Dictionary:
    return {"valid": false, "error": error}
