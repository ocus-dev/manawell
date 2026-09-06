extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const MeleeEnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RangedEnemyScript = preload("res://scripts/game/ranged_enemy.gd")
const RangedProjectileScript = preload("res://scripts/game/ranged_projectile.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_lethal_melee_beats_seal_completion()
	_test_hostile_projectile_beats_seal_completion()
	_test_dash_expiry_is_before_movement()
	_test_pause_freezes_combat()
	_test_render_refresh_count_does_not_change_simulation()
	quit(0)

func _controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.request_start_or_harvest()
	return controller

func _test_lethal_melee_beats_seal_completion() -> void:
	var controller: Node = _controller()
	controller.run_state.request_harvest()
	controller.run_state.sealing_remaining = ControllerScript.FIXED_STEP
	controller.run_state.machine_integrity = 1.0
	var enemy := MeleeEnemyScript.new()
	enemy.setup(MeleeEnemyScript.EnemyKind.BREAKER, controller.run_state, controller.get_node("Machine"))
	enemy.position = controller.get_node("Machine").position
	controller.add_child(enemy)
	controller.enemies.append(enemy)
	controller.tick(ControllerScript.FIXED_STEP)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	assert(controller.run_state.terminal_reason == "machine_destroyed")
	controller.free()

func _test_hostile_projectile_beats_seal_completion() -> void:
	var controller: Node = _controller()
	controller.run_state.request_harvest()
	controller.run_state.sealing_remaining = ControllerScript.FIXED_STEP
	controller.run_state.hero_health = 1.0
	var enemy := RangedEnemyScript.new()
	enemy.setup(controller.run_state, controller.get_node("Hero"))
	controller.add_child(enemy)
	var projectile := RangedProjectileScript.new()
	projectile.run_state = controller.run_state
	projectile.target = controller.get_node("Hero")
	projectile.position = controller.get_node("Hero").position
	projectile.damage = 5.0
	projectile.lifetime_remaining = 1.0
	enemy.add_child(projectile)
	enemy.projectile = projectile
	controller.enemies.append(enemy)
	controller.tick(ControllerScript.FIXED_STEP)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	assert(controller.run_state.terminal_reason == "hero_destroyed")
	controller.free()

func _test_dash_expiry_is_before_movement() -> void:
	var controller: Node = _controller()
	var hero: Node3D = controller.get_node("Hero")
	hero.try_dash(Vector3.RIGHT)
	hero.dash_remaining = ControllerScript.FIXED_STEP
	controller.tick(ControllerScript.FIXED_STEP)
	assert(not hero.is_dash_active())
	controller.free()

func _test_pause_freezes_combat() -> void:
	var controller: Node = _controller()
	controller._spawn_next_enemy()
	var enemy: Node = controller.enemies[0]
	enemy.cooldown_remaining = 1.0
	controller.run_state.set_paused(true)
	var elapsed: float = controller.run_state.simulation_elapsed
	controller.tick(1.0)
	assert(is_equal_approx(controller.run_state.simulation_elapsed, elapsed))
	assert(is_equal_approx(enemy.cooldown_remaining, 1.0))
	controller.free()

func _test_render_refresh_count_does_not_change_simulation() -> void:
	var one_refresh: Node = _controller()
	var many_refreshes: Node = _controller()
	one_refresh.tick(1.0)
	for index in range(10):
		many_refreshes.tick(0.1)
	assert(is_equal_approx(one_refresh.run_state.simulation_elapsed, many_refreshes.run_state.simulation_elapsed))
	assert(one_refresh.spawn_index == many_refreshes.spawn_index)
	assert(one_refresh.enemies.size() == many_refreshes.enemies.size())
	one_refresh.free()
	many_refreshes.free()
