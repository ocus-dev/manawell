extends SceneTree

const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _instance(instance_id: String, base_id: String, rarity: String, implicits: Array, explicit_modifiers: Array) -> Dictionary:
    return {"schema_version": 1, "instance_id": instance_id, "base_id": base_id, "rarity": rarity, "item_level": 1, "implicit_modifiers": implicits.duplicate(true), "explicit_modifiers": explicit_modifiers.duplicate(true), "generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": true, "locked": false}

func _init() -> void:
    var breech_implicit: Array = Definitions.PRODUCTION_BASES["core.heavy_breech"].implicits
    var bulwark_implicit: Array = Definitions.PRODUCTION_BASES["chassis.bulwark"].implicits
    var volume_implicit: Array = Definitions.PRODUCTION_BASES["module.high_volume"].implicits
    var instances := {
        "weapon-a": _instance("weapon-a", "core.heavy_breech", "epic", breech_implicit, [{"affix_id": "affix.payload", "tier": 1, "value": 1}, {"affix_id": "affix.tempo", "tier": 1, "value": 0.03}, {"affix_id": "affix.fortune", "tier": 1, "value": 0.03}]),
        "weapon-b": _instance("weapon-b", "core.heavy_breech", "common", breech_implicit, []),
        "hero-a": _instance("hero-a", "chassis.bulwark", "epic", bulwark_implicit, [{"affix_id": "affix.vitality", "tier": 1, "value": 5}, {"affix_id": "affix.mobility", "tier": 1, "value": 0.02}, {"affix_id": "affix.recovery", "tier": 1, "value": 0.10}]),
        "module-a": _instance("module-a", "module.high_volume", "epic", volume_implicit, [{"affix_id": "affix.extraction", "tier": 1, "value": 0.03}, {"affix_id": "affix.recovery", "tier": 1, "value": 0.10}, {"affix_id": "affix.fortune", "tier": 1, "value": 0.03}]),
    }
    var empty := Resolver.resolve({}, instances, {})
    assert(is_equal_approx(empty.stats.attack_damage, 10.0))
    assert(is_equal_approx(empty.stats.attacks_per_second, 1.6666666667))
    assert(is_equal_approx(empty.stats.attack_interval, 0.6))
    assert(is_equal_approx(empty.stats.max_health, 100.0))
    assert(is_equal_approx(empty.harvest.cycle_amount, 2.0))

    var equipped_kit := {"weapon": "weapon-a", "hero": "hero-a", "harvester": "module-a"}
    var result := Resolver.resolve({}, instances, equipped_kit)
    assert(is_equal_approx(result.stats.attack_damage, 13.0))
    assert(is_equal_approx(result.stats.attacks_per_second, 1.7166666667))
    assert(is_equal_approx(result.stats.max_health, 105.0))
    assert(is_equal_approx(result.stats.armor, 12.0))
    assert(is_equal_approx(result.stats.move_speed, 195.84))
    assert(is_equal_approx(result.stats.health_regen, 0.20))
    assert(is_equal_approx(result.stats.mining_bonus, 0.11))
    assert(is_equal_approx(result.stats.drop_bonus, 0.06))
    assert(is_equal_approx(result.harvest.cycle_amount, 2.22))
    assert(is_equal_approx(result.harvest.mean_output_per_second, 2.22))
    assert(result.sources.attack_damage.size() == 2)

    var before := JSON.stringify(instances)
    var compared := Resolver.compare_slot({"ranks": {}, "instances": instances, "hero_kit": equipped_kit, "base_output": 2.0}, "weapon", "weapon-b")
    assert(is_equal_approx(compared.stats.attack_damage, 12.0))
    assert(is_equal_approx(result.stats.max_health, compared.stats.max_health + 0.0))
    assert(JSON.stringify(instances) == before)

    var reordered := {"module-a": instances["module-a"], "hero-a": instances["hero-a"], "weapon-a": instances["weapon-a"]}
    var reordered_result := Resolver.resolve({}, reordered, equipped_kit)
    assert(JSON.stringify(result.stats) == JSON.stringify(reordered_result.stats))

    var capped := Resolver.resolve({"weapon.damage": 3, "weapon.rate": 3, "weapon.velocity": 3}, instances, equipped_kit)
    assert(is_equal_approx(capped.stats.attack_damage, 28.0))
    assert(capped.stats.attacks_per_second <= capped.research.standard_weapon.attacks_per_second * 1.30 + 1e-8)
    assert(capped.stats.projectile_speed <= capped.research.standard_weapon.projectile_speed * 1.25 + 1e-8)
    assert(capped.stats.max_health <= 150.0)
    assert(capped.stats.move_speed <= 230.4)

    var fan := Resolver.resolve({"weapon.damage": 1, "weapon.shots": 1}, instances, {"weapon": "weapon-b"}, 2.0, 1.0, "", "weapon.fan")
    assert(is_equal_approx(fan.stats.attack_damage, 11.05))
    assert(fan.stats.weapon_projectile_count == 3)
    var deep_draw := Resolver.resolve({"harvest.amount": 1}, instances, {"harvester": "module-a"}, 2.0, 1.0, "harvest.deep_draw")
    assert(is_equal_approx(deep_draw.harvest.cycle_amount, 3.46875))
    print("PASS hero stat resolver: baselines, stacking, caps, modes, harvest, replacement, source breakdown and immutability")
    quit(0)
