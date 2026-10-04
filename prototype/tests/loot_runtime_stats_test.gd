extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const HeroStatResolverScript = preload("res://scripts/model/hero_stat_resolver.gd")

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
    _test_equipped_items_drive_weapon_stats()
    _test_spread_volley()
    print("PASS runtime stats: equipped items resolve weapon damage/interval, snapshot stays valid, spread volley")
    quit(0)

func _test_equipped_items_drive_weapon_stats() -> void:
    var controller := _make_controller()
    var kit: Dictionary = controller.account_state.hero_kits["hero_1"]
    var expected: Dictionary = HeroStatResolverScript.resolve(controller.account_state.research_ranks, controller.account_state.item_instances, kit, float(controller.content_catalog.get_well(controller.selected_well_id).get("base_output", BalanceData.WELL_1_BASE_OUTPUT)), 1.0, "", str(controller.account_state.equipped_weapon_mode_id)).stats
    assert(is_equal_approx(controller.weapon_damage, float(expected.attack_damage)))
    assert(is_equal_approx(controller.weapon_interval, maxf(0.01, float(expected.attack_interval))))
    # The epic weapon's affixes make it hit harder than the bare base damage.
    assert(controller.weapon_damage > BalanceData.WEAPON_DAMAGE)
    var health_before: float = controller.run_state.hero_health
    assert(controller.apply_enemy_damage(0, 10.0))
    assert(controller.run_state.hero_health < health_before)
    var snapshot: Dictionary = controller._capture_snapshot()
    assert(is_equal_approx(float(snapshot.weapon_state.damage), controller.weapon_damage))
    assert(SnapshotScript.encode(snapshot).valid)
    controller.queue_free()

func _test_spread_volley() -> void:
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    get_root().add_child(controller)
    controller.account_state.owned_upgrades["spread_1"] = true
    assert(controller.start_run())
    assert(controller.weapon_projectile_count >= 3)
    controller.spawn_friendly_volley(controller.hero.position.x, controller.hero.position.x + 100.0)
    assert(controller.projectiles.size() == controller.weapon_projectile_count)
    for projectile in controller.projectiles:
        assert(is_equal_approx(projectile.damage, controller.weapon_damage))
    controller.queue_free()
