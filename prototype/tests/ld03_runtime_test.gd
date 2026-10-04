extends SceneTree

## Enemy spawning at runtime: base monster stats, the live-enemy cap and the
## tutorial's no-spawn rule. (The old authored-wave / per-level scaling / boss
## director this file used to cover was removed from the game.)

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = _controller()
	_check(controller.start_run(), "run did not start")
	_check_base_stats(controller)
	_check_no_backlog_at_cap(controller)
	controller.queue_free()
	await process_frame
	await _check_tutorial_spawns_nothing()
	if failures == 0:
		print("PASS LD03 runtime checks")
		quit(0)
	else:
		push_error("LD03 runtime checks failed: %d" % failures)
		quit(1)

func _controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	return controller

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("LD03: " + message)

func _check_base_stats(controller: Node) -> void:
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	_check(enemy != null, "pursuer did not spawn")
	_check(enemy.max_health > 0.0 and is_equal_approx(enemy.health, enemy.max_health), "pursuer spawned without full health")
	_check(enemy.attack_damage > 0.0, "pursuer has no attack damage")
	_check(is_equal_approx(controller.run_state.hero_health, BalanceData.HERO_HEALTH), "spawning changed hero health")
	enemy.dead = true
	controller._prune_enemies()

func _check_no_backlog_at_cap(controller: Node) -> void:
	controller._clear_transients()
	for index in range(BalanceData.MAX_LIVE_ENEMIES):
		controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	_check(controller.enemies.size() == BalanceData.MAX_LIVE_ENEMIES, "cap not reached")
	_check(controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1) == null, "spawn_enemy went past the live cap")
	var index_before: int = controller.spawn_index
	controller._spawn_next_enemy()
	_check(controller.enemies.size() == BalanceData.MAX_LIVE_ENEMIES, "director spawned past the live cap")
	_check(controller.spawn_index == index_before + 1, "director queued a backlog at the cap")
	controller._clear_transients()

func _check_tutorial_spawns_nothing() -> void:
	var controller: Node = _controller()
	await process_frame
	_check(controller.start_tutorial(), "tutorial did not start")
	controller.tick(30.0)
	_check(controller.enemies.is_empty(), "tutorial spawned monsters")
	controller.queue_free()
	await process_frame
