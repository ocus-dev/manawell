extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_friendly_segment_and_interception()
	_test_hostile_current_position_and_facing()
	_test_dash_and_pulse()
	_test_triple_shot()
	print("2D weapons and abilities checks passed")
	quit(0)

func _make_controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	assert(controller.start_run())
	return controller

func _test_friendly_segment_and_interception() -> void:
	var controller := _make_controller()
	var near: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	var far: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
	near.position.x = 550.0
	far.position.x = 620.0
	controller.hero.position.x = 400.0
	controller.spawn_friendly_projectile(400.0, 700.0)
	controller.projectiles[0].simulate_tick(0.5)
	assert(near.health < near.max_health)
	assert(near.damage_feedback_amount == BalanceData.WEAPON_DAMAGE)
	assert(near.damage_feedback_remaining > 0.0)
	assert(is_equal_approx(far.health, far.max_health))
	var left_enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, -1)
	left_enemy.position.x = 300.0
	controller.spawn_friendly_projectile(500.0, 100.0)
	controller.projectiles[1].simulate_tick(0.8)
	assert(left_enemy.health < left_enemy.max_health)
	var feedback_time: float = left_enemy.damage_feedback_remaining
	left_enemy.simulate_tick(0.2)
	assert(left_enemy.damage_feedback_remaining < feedback_time)
	near.take_damage(near.health)
	controller.spawn_friendly_projectile(400.0, 700.0)
	controller.projectiles[2].simulate_tick(0.5)
	assert(is_equal_approx(near.health, 0.0))
	controller.queue_free()

func _test_hostile_current_position_and_facing() -> void:
	var controller := _make_controller()
	controller.hero.position.x = 200.0
	controller.spawn_hostile_projectile(800.0, 200.0, BalanceData.RANGED_DAMAGE)
	controller.hero.position.x = 100.0
	controller.projectiles[0].simulate_tick(0.5)
	assert(is_equal_approx(controller.run_state.hero_health, BalanceData.HERO_HEALTH))
	controller.spawn_hostile_projectile(800.0, 100.0, BalanceData.RANGED_DAMAGE)
	controller.hero.position.x = 650.0
	controller.projectiles[1].simulate_tick(0.7)
	assert(controller.run_state.hero_health < BalanceData.HERO_HEALTH)
	controller.hero.position.x = 650.0
	controller.hero.last_facing = -1
	controller.spawn_hostile_projectile(650.0, 650.0, BalanceData.RANGED_DAMAGE)
	assert(controller.projectiles[2].velocity.y < 0.0)
	controller.queue_free()

func _test_dash_and_pulse() -> void:
	var controller := _make_controller()
	controller.hero.last_facing = -1
	assert(controller.try_dash(0))
	var dash_start_x: float = controller.hero.position.x
	controller.simulate_step(0.1)
	assert(is_equal_approx(controller.hero.position.x, dash_start_x - BalanceData.DASH_SPEED * controller.SPATIAL_PIXELS_PER_UNIT * 0.1))
	var health: float = controller.run_state.hero_health
	assert(not controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, 20.0))
	assert(is_equal_approx(controller.run_state.hero_health, health))
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	enemy.position.x = controller.hero.position.x + BalanceData.PULSE_RADIUS * controller.SPATIAL_PIXELS_PER_UNIT
	assert(controller.try_pulse() == 1)
	assert(controller.try_pulse() == 0)
	controller.queue_free()

func _test_triple_shot() -> void:
	var controller := _make_controller()
	controller.account_state.owned_upgrades["spread_1"] = true
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	enemy.position.x = controller.hero.position.x + 200.0
	controller.simulate_step(BalanceData.WEAPON_INTERVAL)
	assert(controller.projectiles.size() == 3)
	for projectile in controller.projectiles:
		projectile.simulate_tick(1.0)
	assert(enemy.health == 0.0 or enemy.health == BalanceData.PURSUER_HEALTH - BalanceData.WEAPON_DAMAGE)
	controller.queue_free()
