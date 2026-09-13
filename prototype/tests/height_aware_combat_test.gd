extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_ground_projectile_and_aimed_hit()
	_test_melee_and_pulse_use_height()
	_test_locked_ranged_aim_and_machine_pressure()
	_test_friendly_2d_targeting_and_travel_order()
	print("P06 height-aware combat checks passed")
	quit(0)

func _make_controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	assert(controller.start_run())
	return controller

func _test_ground_projectile_and_aimed_hit() -> void:
	var controller := _make_controller()
	controller.hero.position = Vector2(320.0, 390.0)
	var health_before: float = controller.run_state.hero_health
	controller.spawn_hostile_projectile(800.0, 300.0, BalanceData.RANGED_DAMAGE, null, 482.0)
	controller.projectiles[0].simulate_tick(2.0)
	assert(is_equal_approx(controller.run_state.hero_health, health_before))
	controller.spawn_hostile_projectile(800.0, 300.0, BalanceData.RANGED_DAMAGE, null, CombatGeometryScript.body_center("hero", controller.hero.position).y)
	controller.projectiles[1].simulate_tick(2.0)
	assert(controller.run_state.hero_health < health_before)
	controller.queue_free()

func _test_melee_and_pulse_use_height() -> void:
	var controller := _make_controller()
	controller.hero.position = Vector2(320.0, 390.0)
	var pursuer: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	pursuer.position = Vector2(320.0, 500.0)
	var health_before: float = controller.run_state.hero_health
	pursuer.simulate_tick(1.0 / 60.0)
	assert(is_equal_approx(controller.run_state.hero_health, health_before))
	controller.hero.position = Vector2(320.0, 500.0)
	pursuer.simulate_tick(1.0 / 60.0)
	assert(controller.run_state.hero_health < health_before)
	controller.hero.position = Vector2(320.0, 390.0)
	pursuer.position = Vector2(440.0, 500.0)
	controller.pulse_cooldown_remaining = 0.0
	var pulse_before: float = pursuer.health
	assert(controller.try_pulse() == 0)
	assert(is_equal_approx(pursuer.health, pulse_before))
	pursuer.position = Vector2(440.0, 390.0)
	controller.pulse_cooldown_remaining = 0.0
	assert(controller.try_pulse() == 1)
	controller.queue_free()

func _test_locked_ranged_aim_and_machine_pressure() -> void:
	var controller := _make_controller()
	controller.hero.position = Vector2(320.0, 390.0)
	var ranged: Node = controller.spawn_enemy(EnemyScript.EnemyKind.RANGED, 1)
	ranged.position = Vector2(800.0, 500.0)
	ranged.windup_remaining = 0.1
	ranged.simulate_tick(0.1)
	assert(controller.projectiles.size() == 1)
	var locked_y: float = controller.projectiles[0].target_position.y
	assert(is_equal_approx(locked_y, CombatGeometryScript.body_center("hero", Vector2(320.0, 390.0)).y))
	controller.hero.position = Vector2(320.0, 500.0)
	assert(not is_equal_approx(controller.projectiles[0].target_position.y, CombatGeometryScript.body_center("hero", controller.hero.position).y))
	var breaker: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
	breaker.position = Vector2(controller.MACHINE_X, 500.0)
	var machine_before: float = controller.run_state.machine_integrity
	breaker.simulate_tick(1.0 / 60.0)
	assert(controller.run_state.machine_integrity < machine_before)
	controller.queue_free()

func _test_friendly_2d_targeting_and_travel_order() -> void:
	var controller := _make_controller()
	controller.hero.position = Vector2(320.0, 390.0)
	var far_ground: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	far_ground.position = Vector2(500.0, 500.0)
	var near_platform: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	near_platform.position = Vector2(530.0, 390.0)
	assert(controller.closest_live_enemy() == near_platform)
	controller.spawn_friendly_projectile(controller.hero.position.x, near_platform.position.x, near_platform)
	controller.projectiles[0].simulate_tick(1.0)
	assert(near_platform.health < near_platform.max_health)
	assert(is_equal_approx(far_ground.health, far_ground.max_health))
	controller.queue_free()
