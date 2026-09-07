extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_continuing_catalog_director()
	_test_modifiers_and_pause()
	_test_machine_target_and_cap()
	print("2D surge checks passed")
	quit(0)

func _make_controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	assert(controller.start_run())
	return controller

func _test_continuing_catalog_director() -> void:
	var controller := _make_controller()
	controller.run_state.hero_health = 100000.0
	controller.run_state.machine_integrity = 100000.0
	controller.simulate_step(90.0)
	assert(controller.spawn_index > 0)
	assert(controller.spawn_timer >= 0.0)
	assert(controller.side_sequence > 1)
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.PURSUER))
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.BREAKER))
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.RANGED))
	var first_warning: Dictionary = controller.pending_entry_warnings[0]
	assert(first_warning.has("side"))
	assert(first_warning.has("remaining"))
	var tier_four_interval: float = controller._spawn_interval()
	controller.run_state.completed_surges = 5
	assert(controller._spawn_interval() < tier_four_interval)
	controller.queue_free()

func _test_modifiers_and_pause() -> void:
	var controller := _make_controller()
	controller.run_state.selected_well_id = "well_2"
	controller.run_state.selected_module_id = "overdrive"
	controller.run_state.completed_surges = 2
	var modified_interval: float = controller._spawn_interval()
	controller.run_state.selected_well_id = "well_1"
	controller.run_state.selected_module_id = "standard"
	var base_interval: float = controller._spawn_interval()
	assert(modified_interval < base_interval)
	var elapsed: float = controller.run_state.simulation_elapsed
	var spawn_timer: float = controller.spawn_timer
	controller.toggle_pause()
	controller.simulate_step(4.0)
	assert(is_equal_approx(controller.run_state.simulation_elapsed, elapsed))
	assert(is_equal_approx(controller.spawn_timer, spawn_timer))
	controller.toggle_pause()
	controller.queue_free()

func _test_machine_target_and_cap() -> void:
	var controller := _make_controller()
	var breaker: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, -1)
	breaker.position.x = controller.MACHINE_X - breaker.attack_range_pixels
	var machine_health: float = controller.run_state.machine_integrity
	controller.simulate_step(1.0 / 60.0)
	assert(controller.run_state.machine_integrity < machine_health)
	controller.enemies.clear()
	for index in range(BalanceData.LIVE_ENEMY_LIMIT + 5):
		controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	assert(controller.enemies.size() == BalanceData.LIVE_ENEMY_LIMIT)
	controller.queue_free()
