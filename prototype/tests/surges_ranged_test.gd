extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RangedEnemyScript = preload("res://scripts/game/ranged_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_authored_tiers()
	_test_pause_and_cap()
	_test_ranged_windup_hit_and_miss()
	quit(0)

func _real_scene() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(scene)
	return scene

func _test_authored_tiers() -> void:
	var controller: Node = _real_scene()
	controller.request_start_or_harvest()
	controller.tick(3.0)
	assert(controller.enemies.size() == 1)
	assert(controller.enemies[0].get("enemy_kind") == EnemyScript.EnemyKind.PURSUER)
	controller.run_state.completed_surges = 1
	controller.tick(2.5)
	assert(controller.enemies.size() == 2)
	assert(controller.enemies[1].get("enemy_kind") == EnemyScript.EnemyKind.PURSUER)
	controller.run_state.completed_surges = 2
	controller.spawn_index = 2
	controller.spawn_timer = 2.0
	controller.tick(0.0)
	assert(controller.enemies.back().get("enemy_kind") == EnemyScript.EnemyKind.BREAKER)
	controller.spawn_index = 3
	controller.spawn_timer = 2.0
	controller.tick(0.0)
	assert(controller.enemies.back() is RangedEnemyScript)
	controller.run_state.completed_surges = 4
	var tier_four_interval: float = controller._spawn_interval()
	controller.run_state.completed_surges = 5
	assert(controller._spawn_interval() < tier_four_interval)
	controller.free()

func _test_pause_and_cap() -> void:
	var controller: Node = _real_scene()
	controller.request_start_or_harvest()
	controller.run_state.set_paused(true)
	controller.tick(20.0)
	assert(controller.enemies.is_empty())
	controller.run_state.set_paused(false)
	controller.run_state.completed_surges = 4
	controller.spawn_timer = 1000.0
	controller.enemies.resize(BalanceData.LIVE_ENEMY_LIMIT)
	for index in range(BalanceData.LIVE_ENEMY_LIMIT):
		controller.enemies[index] = Node3D.new()
	controller.tick(0.0)
	assert(controller.enemies.size() == BalanceData.LIVE_ENEMY_LIMIT)
	for enemy in controller.enemies:
		enemy.free()
	controller.free()

func _test_ranged_windup_hit_and_miss() -> void:
	var state: RefCounted = RunStateScript.new()
	assert(state.start("ranged-test"))
	var hero := Node3D.new()
	hero.position = Vector3.ZERO
	var ranged = RangedEnemyScript.new()
	ranged.setup(state, hero)
	ranged.position = Vector3(7.0, 0.0, 0.0)
	ranged.simulate_tick(0.5)
	assert(ranged.windup_remaining > 0.0)
	assert(ranged.attack_count == 0)
	ranged.simulate_tick(0.6)
	assert(ranged.attack_count == 1)
	hero.position = Vector3(0.0, 0.0, 7.0)
	var projectile = ranged.projectile
	projectile.simulate_tick(0.8)
	assert(is_equal_approx(state.hero_health, BalanceData.HERO_HEALTH))
	ranged.free()
	hero.free()

	var hit_state: RefCounted = RunStateScript.new()
	assert(hit_state.start("ranged-hit"))
	var hit_hero := Node3D.new()
	hit_hero.position = Vector3.ZERO
	var hit_ranged = RangedEnemyScript.new()
	hit_ranged.setup(hit_state, hit_hero)
	hit_ranged.position = Vector3(7.0, 0.0, 0.0)
	hit_ranged.simulate_tick(0.1)
	hit_ranged.simulate_tick(0.6)
	assert(hit_ranged.attack_count == 1)
	hit_ranged.projectile.simulate_tick(1.0)
	assert(is_equal_approx(hit_state.hero_health, BalanceData.HERO_HEALTH - BalanceData.RANGED_DAMAGE))
	hit_ranged.free()
	hit_hero.free()
