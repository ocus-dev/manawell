extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _instance(instance_id: String, base_id: String, explicit_modifiers: Array) -> Dictionary:
    return {"schema_version": 1, "instance_id": instance_id, "base_id": base_id, "rarity": "epic", "item_level": 1, "implicit_modifiers": Definitions.PRODUCTION_BASES[base_id].implicits.duplicate(true), "explicit_modifiers": explicit_modifiers.duplicate(true), "generation_version": "loot-v1", "provenance": {"kind": "test", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": true, "locked": false}

func _make_controller() -> Node:
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    get_root().add_child(controller)
    controller.account_state.item_instances = {
        "weapon": _instance("weapon", "core.heavy_breech", [{"affix_id": "affix.breaker", "tier": 1, "value": 0.10}]),
        "hero": _instance("hero", "chassis.bulwark", [{"affix_id": "affix.recovery", "tier": 1, "value": 0.20}]),
        "module": _instance("module", "module.high_volume", [{"affix_id": "affix.extraction", "tier": 1, "value": 0.03}]),
    }
    controller.account_state.hero_kits["hero_1"] = {"weapon": "weapon", "hero": "hero", "harvester": "module"}
    assert(controller.start_run())
    return controller

func _init() -> void:
    _test_frozen_build_and_incoming_mitigation()
    _test_regeneration_delay_pause_and_death()
    _test_family_damage_and_fan_projectile_damage()
    print("PASS L04 runtime stats: frozen builds, mitigation, family routing, fan damage, regen gates and snapshot fields")
    quit(0)

func _test_frozen_build_and_incoming_mitigation() -> void:
    var controller := _make_controller()
    assert(is_equal_approx(controller.hero_max_health, 100.0))
    assert(is_equal_approx(controller.resolved_stats.attack_damage, 12.0))
    assert(is_equal_approx(controller.resolved_stats.armor, 12.0))
    assert(is_equal_approx(controller.resolved_stats.health_regen, 0.20))
    var health_before: float = controller.run_state.hero_health
    assert(controller.apply_enemy_damage(0, 10.0))
    assert(is_equal_approx(controller.run_state.hero_health, health_before - 8.9285714286))
    var snapshot: Dictionary = controller._capture_snapshot()
    assert(snapshot.resolved_stats.attack_damage == controller.resolved_stats.attack_damage)
    assert(snapshot.equipped_instance_ids.weapon == "weapon")
    assert(snapshot.weapon_runtime.damage == controller.weapon_damage)
    assert(SnapshotScript.encode(snapshot).valid)
    controller.queue_free()

func _test_regeneration_delay_pause_and_death() -> void:
    var controller := _make_controller()
    controller.run_state.hero_health = 50.0
    controller.apply_enemy_damage(0, 10.0)
    var damaged_health: float = controller.run_state.hero_health
    controller.tick(2.0)
    assert(is_equal_approx(controller.run_state.hero_health, damaged_health))
    controller.tick(1.1)
    assert(controller.run_state.hero_health > damaged_health)
    var healing_health: float = controller.run_state.hero_health
    controller.set_experiment_paused(true)
    controller.tick(2.0)
    assert(is_equal_approx(controller.run_state.hero_health, healing_health))
    controller.set_experiment_paused(false)
    controller.run_state.hero_health = 0.0
    controller.tick(2.0)
    assert(is_equal_approx(controller.run_state.hero_health, 0.0))
    controller.queue_free()

func _test_family_damage_and_fan_projectile_damage() -> void:
    var controller := _make_controller()
    var breaker: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
    var breaker_health: float = breaker.health
    assert(controller.apply_hero_attack_damage(breaker, 10.0, "gun"))
    assert(is_equal_approx(breaker.health, breaker_health - 11.0))
    controller.queue_free()

    var fan_controller: Node = load("res://scenes/main.tscn").instantiate()
    fan_controller.persistence_enabled = false
    get_root().add_child(fan_controller)
    fan_controller.account_state.research_ranks = {"weapon.damage": 1, "weapon.shots": 1}
    fan_controller.account_state.equipped_weapon_mode_id = "weapon.fan"
    assert(fan_controller.start_run())
    assert(fan_controller.weapon_projectile_count == 3)
    fan_controller.spawn_friendly_volley(fan_controller.hero.position.x, fan_controller.hero.position.x + 100.0)
    assert(fan_controller.projectiles.size() == 3)
    for projectile in fan_controller.projectiles:
        assert(is_equal_approx(projectile.damage, 9.75))
    fan_controller.queue_free()
