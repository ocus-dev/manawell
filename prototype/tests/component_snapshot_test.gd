extends SceneTree

const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const RangedEnemyScript = preload("res://scripts/game/ranged_enemy.gd")

func _init() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.owned_upgrades["damage_1"] = true
	controller.account_state.owned_upgrades["spread_1"] = true
	controller.request_start_or_harvest()
	var hero: Node3D = controller.get_node("Hero")
	hero.position = Vector3(3.0, 1.0, 7.0)
	controller._spawn_next_enemy()
	var target: Node3D = controller.enemies[0]
	target.position = Vector3(5.0, 0.8, 3.0)
	controller.auto_weapon.shot_accumulator = 0.25
	controller.auto_weapon._fire(target)
	var ranged := RangedEnemyScript.new()
	ranged.setup(controller.run_state, hero, 1.25)
	ranged.position = Vector3(-5.0, 0.8, 2.0)
	ranged.set_id_allocator(Callable(controller, "_allocate_snapshot_id").bind("projectile"))
	ranged.set_meta("snapshot_id", controller._allocate_snapshot_id("actor"))
	controller.add_child(ranged)
	controller.enemies.append(ranged)
	ranged._fire()
	ranged._fire()
	var payload: Dictionary = SnapshotScript.encode(controller._capture_snapshot())["payload"]
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	restored.persistence_enabled = false
	get_root().add_child(restored)
	restored.save_store.loaded_snapshot = payload
	restored._restore_saved_snapshot()
	assert(is_equal_approx(restored.auto_weapon.damage, controller.auto_weapon.damage))
	assert(restored.auto_weapon.spread_enabled)
	assert(is_equal_approx(restored.auto_weapon.shot_accumulator, 0.25))
	assert(restored.auto_weapon.projectiles.size() == 3)
	var restored_scaled: Node = restored.enemies.back()
	assert(is_equal_approx(restored_scaled.damage_multiplier, 1.25))
	assert(is_equal_approx(restored_scaled.capture_snapshot_state()["attack_damage"], ranged.capture_snapshot_state()["attack_damage"]))
	assert(restored_scaled.projectiles.size() == 2)
	assert(is_equal_approx(restored_scaled.position.x, -5.0))
	assert(is_equal_approx(restored_scaled.projectiles[0].position.x, payload["projectiles"][1]["position"][0]))
	controller.free()
	restored.free()
	quit(0)
