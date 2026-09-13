class_name HeroStatResolver
extends RefCounted

const BalanceData = preload("res://data/balance.gd")
const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")
const ResearchResolverScript = preload("res://scripts/model/research_resolver.gd")

const CAPS := {
    "attack_damage": 1.50,
    "attacks_per_second": 1.30,
    "projectile_speed": 1.25,
    "max_health": 1.50,
    "move_speed": 1.20,
}
const BASELINE := {
    "max_health": BalanceData.HERO_HEALTH,
    "move_speed": BalanceData.HERO_HORIZONTAL_SPEED,
    "armor": 0.0,
    "health_regen": 0.0,
    "mining_bonus": 0.0,
    "drop_bonus": 0.0,
    "resistance.fire": 0.0,
    "resistance.shock": 0.0,
    "resistance.toxin": 0.0,
}

static func resolve(ranks: Dictionary, instances: Dictionary, hero_kit: Dictionary, base_output: float = BalanceData.WELL_1_BASE_OUTPUT, loadout_output_multiplier: float = 1.0, specialization_id: String = "", weapon_mode_id: String = "weapon.standard", hero_baseline: Dictionary = {}) -> Dictionary:
    var baseline := BASELINE.duplicate()
    for key in hero_baseline:
        if baseline.has(key):
            baseline[key] = float(hero_baseline[key])
    var standard_weapon: Dictionary = ResearchResolverScript.resolve_weapon(ranks, "weapon.standard")
    var selected_weapon: Dictionary = ResearchResolverScript.resolve_weapon(ranks, weapon_mode_id)
    var sources := _empty_sources()
    var totals := _equipment_totals(instances, hero_kit, sources)
    var stats := baseline.duplicate()
    stats["attack_damage"] = _capped_positive(float(standard_weapon.damage), totals["attack_damage_flat"], totals["attack_damage_increased"], CAPS.attack_damage)
    stats["attacks_per_second"] = _capped_positive(float(standard_weapon.attacks_per_second), totals["attacks_per_second_flat"], totals["attacks_per_second_increased"], CAPS.attacks_per_second)
    stats["projectile_speed"] = _capped_positive(float(standard_weapon.projectile_speed), totals["projectile_speed_flat"], totals["projectile_speed_increased"], CAPS.projectile_speed)
    stats["max_health"] = _capped_positive(float(baseline.max_health), totals["max_health_flat"], totals["max_health_increased"], CAPS.max_health)
    stats["move_speed"] = _capped_positive(float(baseline.move_speed), totals["move_speed_flat"], totals["move_speed_increased"], CAPS.move_speed)
    stats["armor"] = clampf(float(baseline.armor) + totals["armor_flat"] + totals["armor_increased"], 0.0, 150.0)
    stats["health_regen"] = clampf(float(baseline.health_regen) + totals["health_regen_flat"] + totals["health_regen_increased"], 0.0, 1.0)
    stats["mining_bonus"] = clampf(float(baseline.mining_bonus) + totals["mining_bonus_flat"] + totals["mining_bonus_increased"], 0.0, 0.25)
    stats["drop_bonus"] = clampf(float(baseline.drop_bonus) + totals["drop_bonus_flat"] + totals["drop_bonus_increased"], 0.0, 0.50)
    for resistance in ["fire", "shock", "toxin"]:
        var key: String = "resistance." + resistance
        stats[key] = clampf(float(baseline.get(key, 0.0)) + totals[key + "_flat"] + totals[key + "_increased"], 0.0, 0.50)
    stats["damage_vs"] = {}
    for family in totals.family_bonus:
        stats["damage_vs"][family] = clampf(float(totals.family_bonus[family]), 0.0, 0.30)
    var damage_ratio := _positive_ratio(float(selected_weapon.damage), float(standard_weapon.damage))
    var rate_ratio := _positive_ratio(float(selected_weapon.attacks_per_second), float(standard_weapon.attacks_per_second))
    stats["attack_damage"] *= damage_ratio
    stats["attacks_per_second"] *= rate_ratio
    stats["attack_damage"] = minf(stats["attack_damage"], float(standard_weapon.damage) * CAPS.attack_damage)
    stats["attacks_per_second"] = minf(stats["attacks_per_second"], float(standard_weapon.attacks_per_second) * CAPS.attacks_per_second)
    stats["projectile_speed"] = minf(stats["projectile_speed"], float(standard_weapon.projectile_speed) * CAPS.projectile_speed)
    stats["attack_interval"] = 1.0 / stats["attacks_per_second"] if stats["attacks_per_second"] > 0.0 else 0.0
    stats["weapon_projectile_count"] = int(selected_weapon.projectile_count)
    stats["weapon_pierce_count"] = int(selected_weapon.pierce_count)
    stats["weapon_mode_id"] = weapon_mode_id
    var harvest := ResearchResolverScript.resolve_harvest(base_output, ranks, loadout_output_multiplier, specialization_id)
    harvest["cycle_amount"] = float(harvest.cycle_amount) * (1.0 + float(stats.mining_bonus))
    harvest["mean_output_per_second"] = float(harvest.cycle_amount) / float(harvest.cycle_interval)
    return {"stats": stats, "harvest": harvest, "sources": sources, "research": {"standard_weapon": standard_weapon, "selected_weapon": selected_weapon}, "equipped_instance_ids": _kit_ids(hero_kit)}

static func compare_slot(result_input: Dictionary, slot: String, replacement_instance_id: String) -> Dictionary:
    var instances: Dictionary = result_input.get("instances", {}).duplicate(true)
    var kit: Dictionary = result_input.get("hero_kit", {}).duplicate(true)
    kit[slot] = replacement_instance_id
    return resolve(result_input.get("ranks", {}), instances, kit, float(result_input.get("base_output", BalanceData.WELL_1_BASE_OUTPUT)), float(result_input.get("loadout_output_multiplier", 1.0)), str(result_input.get("specialization_id", "")), str(result_input.get("weapon_mode_id", "weapon.standard")), result_input.get("hero_baseline", {}))

static func _equipment_totals(instances: Dictionary, kit: Dictionary, sources: Dictionary) -> Dictionary:
    var totals := {}
    for stat in ItemDefinitionsScript.STAT_NAMES:
        totals[stat + "_flat"] = 0.0
        totals[stat + "_increased"] = 0.0
    totals["family_bonus"] = {}
    for slot in ItemDefinitionsScript.SLOTS:
        var instance_id: String = str(kit.get(slot, ""))
        if instance_id.is_empty() or not instances.has(instance_id):
            continue
        var instance: Dictionary = instances[instance_id]
        for modifier in instance.get("implicit_modifiers", []):
            _add_modifier(totals, sources, slot, instance_id, str(modifier.stat), str(modifier.operation), float(modifier.value))
        for modifier in instance.get("explicit_modifiers", []):
            var affix: Dictionary = ItemDefinitionsScript.PRODUCTION_AFFIXES.get(str(modifier.get("affix_id", "")), {})
            if not affix.is_empty():
                _add_modifier(totals, sources, slot, instance_id, str(affix.stat), str(affix.operation), float(modifier.value))
    return totals

static func _add_modifier(totals: Dictionary, sources: Dictionary, slot: String, instance_id: String, stat: String, operation: String, value: float) -> void:
    var key := stat + "_" + operation
    if totals.has(key):
        totals[key] += value
    if stat.begins_with("damage_vs."):
        var family := stat.trim_prefix("damage_vs.")
        totals.family_bonus[family] = float(totals.family_bonus.get(family, 0.0)) + value
    if sources.has(stat):
        sources[stat].append({"slot": slot, "instance_id": instance_id, "operation": operation, "value": value})

static func _empty_sources() -> Dictionary:
    var sources := {}
    for stat in ItemDefinitionsScript.STAT_NAMES:
        sources[stat] = []
    return sources

static func _capped_positive(baseline: float, flat: float, increased: float, cap_factor: float) -> float:
    if baseline <= 0.0:
        return maxf(0.0, flat)
    return clampf((baseline + flat) * (1.0 + increased), baseline, baseline * cap_factor)

static func _positive_ratio(selected: float, standard: float) -> float:
    if standard <= 0.0 or not is_finite(standard) or not is_finite(selected):
        return 1.0
    return selected / standard

static func _kit_ids(kit: Dictionary) -> Dictionary:
    return {"weapon": str(kit.get("weapon", "")), "hero": str(kit.get("hero", "")), "harvester": str(kit.get("harvester", ""))}
