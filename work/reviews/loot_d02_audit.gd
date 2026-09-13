extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var resolver = preload("res://scripts/model/research_resolver.gd")
    var stats = resolver.resolve_weapon({"weapon.damage": 1, "weapon.shots": 1}, "weapon.fan")
    controller.weapon_damage = stats.damage
    controller.weapon_projectile_count = stats.projectile_count
    controller.spawn_friendly_volley(100.0, 200.0)
    print("AUDIT fan: resolver=", stats.damage, " spawned=", controller.projectiles.back().damage)
    var definitions = preload("res://scripts/model/item_definitions.gd")
    var fixture = preload("res://tests/item_definitions_test.gd")
    var decoded = JSON.parse_string(definitions.serialize_instance(fixture.COMMON_INSTANCE))
    print("AUDIT JSON round-trip valid=", definitions.validate_instance(decoded, fixture.TEST_CATALOG, fixture.TEST_AFFIXES))
    print("AUDIT empty catalog invalid affix=", definitions.validate_catalog({}, {"broken": {}}))
    controller.queue_free()
    await process_frame
    quit(0)
