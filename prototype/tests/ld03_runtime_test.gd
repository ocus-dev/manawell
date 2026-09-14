extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = _controller()
	_check(controller.start_campaign_node("act_01", "act_01_node_01"), "campaign node did not start")
	_check_neutral_profile(controller)
	_check_composed_profile(controller)
	_check_interval_semantics(controller)
	_check_wave_delay_and_allowlist(controller)
	_check_no_backlog_at_cap(controller)
	controller.queue_free()
	await process_frame
	await _test_boss()
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

func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (actual=%s expected=%s)" % [message, actual, expected])

func _check_neutral_profile(controller: Node) -> void:
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1, {"hp_multiplier": 1.0, "damage_multiplier": 1.0, "move_speed_multiplier": 1.0, "attack_interval_multiplier": 1.0})
	_check_close(enemy.max_health, BalanceData.PURSUER_HEALTH, "neutral HP changed")
	_check_close(enemy.attack_damage, BalanceData.PURSUER_DAMAGE, "neutral damage changed")
	_check_close(enemy.speed_pixels, BalanceData.PURSUER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT, "neutral movement changed")
	_check_close(controller.hero_max_health, BalanceData.HERO_HEALTH, "hero inherited enemy scaling")
	_check_close(controller.run_state.machine_max_integrity, 1.0, "machine inherited enemy scaling")
	enemy.dead = true
	controller._prune_enemies()

func _check_composed_profile(controller: Node) -> void:
	controller.campaign_config["scaling"] = {"hp_multiplier": 2.0, "damage_multiplier": 1.0, "move_speed_multiplier": 1.0, "attack_interval_multiplier": 1.0}
	controller.campaign_config["monster_overrides"] = {"pursuer": {"hp_multiplier": 1.5, "damage_multiplier": 1.25, "move_speed_multiplier": 0.5, "attack_interval_multiplier": 0.8}}
	var profile: Dictionary = controller._enemy_profile("pursuer", {"monster_id": "pursuer"})
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1, profile)
	_check_close(enemy.max_health, BalanceData.PURSUER_HEALTH * 3.0, "composed HP factor was not applied once")
	_check_close(enemy.attack_damage, BalanceData.PURSUER_DAMAGE * 1.25, "composed damage factor was not applied once")
	_check_close(enemy.speed_pixels, BalanceData.PURSUER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT * 0.5, "composed movement factor was not applied once")
	enemy.dead = true
	controller._prune_enemies()

func _check_interval_semantics(controller: Node) -> void:
	var profile := {"hp_multiplier": 1.0, "damage_multiplier": 1.0, "move_speed_multiplier": 1.0, "attack_interval_multiplier": 0.8}
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1, profile)
	_check_close(enemy.attack_interval, BalanceData.MELEE_ATTACK_INTERVAL * 0.8, "interval multiplier did not shorten attack interval")
	enemy.dead = true
	controller._prune_enemies()

func _check_wave_delay_and_allowlist(controller: Node) -> void:
	controller._clear_transients()
	controller.campaign_config = {"available_monsters": ["pursuer"], "scaling": {"hp_multiplier": 1.0, "damage_multiplier": 1.0, "move_speed_multiplier": 1.0, "attack_interval_multiplier": 1.0}, "monster_overrides": {}, "waves": [{"monsters": [{"monster_id": "breaker", "count": 1}], "delay_before_seconds": 0.0}, {"monsters": [{"monster_id": "pursuer", "count": 1}], "delay_before_seconds": 1.0}]}
	controller.campaign_wave_index = 0
	controller.campaign_wave_delay_remaining = 0.0
	controller._spawn_campaign_wave()
	_check(controller.campaign_wave_index == 0 and controller.enemies.is_empty(), "disallowed monster was spawned")
	controller.campaign_config["waves"] = [{"monsters": [{"monster_id": "pursuer", "count": 1}], "delay_before_seconds": 0.0}, {"monsters": [{"monster_id": "pursuer", "count": 1}], "delay_before_seconds": 1.0}]
	controller._spawn_campaign_wave()
	_check(controller.campaign_wave_index == 1, "first authored wave did not spawn")
	controller._clear_transients()
	controller._advance_campaign_objective(0.25)
	_check(controller.enemies.is_empty() and controller.campaign_wave_delay_remaining > 0.0, "wave delay was skipped")
	controller._advance_campaign_objective(1.0)
	_check(controller.enemies.size() == 1, "wave did not spawn after authored delay")

func _check_no_backlog_at_cap(controller: Node) -> void:
	controller._clear_transients()
	controller.campaign_config["waves"] = [{"monsters": [{"monster_id": "pursuer", "count": 1}], "delay_before_seconds": 0.0}]
	controller.campaign_config["available_monsters"] = ["pursuer"]
	controller.campaign_wave_index = 0
	for index in range(BalanceData.MAX_LIVE_ENEMIES):
		controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	controller._spawn_campaign_wave()
	_check(controller.campaign_wave_index == 0, "wave advanced while live cap was full")
	_check(controller.enemies.size() == BalanceData.MAX_LIVE_ENEMIES, "cap admitted a backlog spawn")

func _test_boss() -> void:
	var controller := _controller()
	for index in range(1, 9):
		controller.campaign_state.completed_nodes["act_01/act_01_node_%02d" % index] = true
	_check(controller.start_campaign_node("act_01", "act_01_node_09"), "boss node did not start")
	var boss: Node = controller.boss_enemy
	_check(boss != null, "boss did not spawn")
	_check(boss.spawn_id == "crown_guardian", "boss spawn identity was lost")
	_check(boss.spawn_role == "boss", "boss role was lost")
	_check_close(boss.max_health, 240.0, "boss health parity changed")
	_check_close(boss.attack_damage, 18.0, "boss damage parity changed")
	_check_close(boss.attack_interval, 3.0, "boss interval parity changed")
	_check_close(controller.hero_max_health, BalanceData.HERO_HEALTH, "boss scaling changed hero health")
	controller.queue_free()
	await process_frame
