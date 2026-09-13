extends SceneTree

const RunStateScript = preload("res://data/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

func _init() -> void:
	_test_lifecycle_and_seal_boundary()
	_test_roles_schedule_and_targeting()
	_test_pause_and_retry_cleanup()
	_test_abilities_and_projectile_sweep()
	_test_dead_enemies_are_removed()
	print("S02 defense checks passed")
	quit(0)

func _make_controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	return controller

func _test_lifecycle_and_seal_boundary() -> void:
	var controller := _make_controller()
	assert(controller.run_state.phase == RunStateScript.Phase.READY)
	assert(controller.start_run())
	controller.simulate_step(1.0)
	assert(controller.run_state.phase == RunStateScript.Phase.EXTRACTING)
	assert(controller.request_harvest())
	assert(controller.run_state.phase == RunStateScript.Phase.SEALING)
	var payout: int = controller.run_state.locked_payout
	controller.run_state.apply_damage(RunStateScript.DamageTarget.MACHINE, BalanceData.MACHINE_INTEGRITY)
	controller.simulate_step(BalanceData.SEALING_DURATION)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	assert(controller.run_state.locked_payout == 0)
	assert(payout > 0)
	controller.queue_free()

func _test_roles_schedule_and_targeting() -> void:
	var controller := _make_controller()
	assert(controller.start_run())
	controller.simulate_step(27.0)
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.PURSUER))
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.BREAKER))
	assert(controller.spawned_kinds.has(EnemyScript.EnemyKind.RANGED))
	assert(controller.spawn_clock >= 27.0)
	var left: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, -1)
	var right: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	left.position.x = controller.hero.position.x - 100.0
	right.position.x = controller.hero.position.x + 100.0
	assert(controller.closest_live_enemy() == left)
	right.position.x = left.position.x
	assert(controller.closest_live_enemy() == left)
	controller.queue_free()

func _test_pause_and_retry_cleanup() -> void:
	var controller := _make_controller()
	assert(controller.start_run())
	controller.spawn_enemy(EnemyScript.EnemyKind.RANGED, 1)
	controller.spawn_hostile_projectile(900.0, controller.hero.position.x, 8.0)
	controller.set_experiment_paused(true)
	var elapsed: float = controller.run_state.simulation_elapsed
	controller.simulate_step(4.0)
	assert(is_equal_approx(controller.run_state.simulation_elapsed, elapsed))
	assert(controller.projectiles.size() == 1)
	controller.retry()
	assert(controller.run_state.phase == RunStateScript.Phase.READY)
	assert(controller.enemies.is_empty())
	assert(controller.projectiles.is_empty())
	assert(is_equal_approx(controller.spawn_clock, 0.0))
	controller.queue_free()

func _test_abilities_and_projectile_sweep() -> void:
	var controller := _make_controller()
	assert(controller.start_run())
	assert(controller.try_dash(0))
	var health: float = controller.run_state.hero_health
	controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, 20.0)
	assert(is_equal_approx(controller.run_state.hero_health, health))
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	enemy.position.x = controller.hero.position.x + 120.0
	assert(controller.try_pulse() == 1)
	assert(controller.try_pulse() == 0)
	controller.spawn_friendly_projectile(controller.hero.position.x, enemy.position.x)
	controller.simulate_step(1.0)
	assert(enemy.health < enemy.max_health)
	controller.queue_free()

func _test_dead_enemies_are_removed() -> void:
	var controller := _make_controller()
	assert(controller.start_run())
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	assert(enemy.take_damage(enemy.health))
	assert(enemy.dead)
	assert(enemy.is_queued_for_deletion())
	controller.simulate_step(1.0 / 60.0)
	assert(controller.enemies.is_empty())
	controller.queue_free()
