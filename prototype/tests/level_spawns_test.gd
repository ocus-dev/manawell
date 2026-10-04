extends SceneTree

## Level spawn settings: defaults, math, the game using them, and preview.

const LevelSpawns = preload("res://scripts/model/level_spawns.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")
const MonsterStats = preload("res://scripts/model/monster_stats.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_model()
	await _test_tutorial_custom_spawns()
	await _test_campaign_level_none()
	await _test_preview()
	LevelSpawns.reload()
	print("PASS level spawns: defaults, rate/mix math, tutorial custom spawns, max alive, none mode, preview")
	quit(0)

func _test_model() -> void:
	LevelSpawns.reload()
	var levels := LevelSpawns.levels()
	assert(levels[0].id == LevelSpawns.TUTORIAL_ID, "tutorial is listed first")
	assert(levels.size() >= 2, "campaign levels are listed")
	assert(LevelSpawns.profile(LevelSpawns.TUTORIAL_ID).mode == LevelSpawns.MODE_NONE)
	assert(LevelSpawns.profile(str(levels[1].id)).mode == LevelSpawns.MODE_DEFAULT)
	var p := LevelSpawns.default_profile("x")
	p.interval = 4.0
	p.surge_speedup = 50.0
	p.min_interval = 0.6
	assert(is_equal_approx(LevelSpawns.interval_for(p, 0), 4.0))
	assert(is_equal_approx(LevelSpawns.interval_for(p, 1), 2.0))
	assert(is_equal_approx(LevelSpawns.interval_for(p, 10), 0.6), "never below the fastest spawn")
	p.mix = {"pursuer": 60.0, "breaker": 30.0, "ranged": 10.0}
	var counts := {"pursuer": 0, "breaker": 0, "ranged": 0}
	for i in 200:
		counts[LevelSpawns.pick(p, i)] += 1
	assert(absi(counts.pursuer - 120) <= 4 and absi(counts.breaker - 60) <= 4 and absi(counts.ranged - 20) <= 4, "mix is followed: %s" % counts)
	p.mix = {"pursuer": 0.0, "breaker": 0.0, "ranged": 0.0}
	assert(LevelSpawns.pick(p, 3) == "")
	# Setting back to defaults drops the entry (the file only keeps real changes).
	LevelSpawns.set_mode("act_01_node_02", LevelSpawns.MODE_CUSTOM)
	assert(LevelSpawns.is_modified("act_01_node_02") and LevelSpawns.has_unsaved_changes())
	LevelSpawns.set_mode("act_01_node_02", LevelSpawns.MODE_DEFAULT)
	assert(not LevelSpawns.is_modified("act_01_node_02"))

func _controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	return controller

func _test_tutorial_custom_spawns() -> void:
	LevelSpawns.reload()
	LevelSpawns.set_mode(LevelSpawns.TUTORIAL_ID, LevelSpawns.MODE_CUSTOM)
	LevelSpawns.set_value(LevelSpawns.TUTORIAL_ID, "interval", 1.0)
	LevelSpawns.set_value(LevelSpawns.TUTORIAL_ID, "max_alive", 3.0)
	LevelSpawns.set_weight(LevelSpawns.TUTORIAL_ID, "pursuer", 0.0)
	LevelSpawns.set_weight(LevelSpawns.TUTORIAL_ID, "breaker", 100.0)
	var controller := _controller()
	await process_frame
	assert(controller.start_tutorial())
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	var most := 0
	for second in 12:
		controller.simulate_step(1.0)
		controller._prune_enemies()
		most = maxi(most, controller.enemies.size())
		for enemy in controller.enemies:
			assert(MonsterStats.id_for_kind(enemy.enemy_kind) == "breaker", "only breakers in the mix")
	assert(most <= 3, "max alive respected (%d)" % most)
	assert(controller.spawn_index >= 10, "spawns every second")
	controller.queue_free()
	await process_frame
	LevelSpawns.reload()

func _test_campaign_level_none() -> void:
	LevelSpawns.reload()
	LevelSpawns.set_mode("act_01_node_01", LevelSpawns.MODE_NONE)
	var controller := _controller()
	await process_frame
	controller.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	assert(controller.start_campaign_node("act_01", "act_01_node_01"))
	assert(controller.current_level_id() == "act_01_node_01")
	controller.run_state.hero_health = 1.0e9
	controller.simulate_step(20.0)
	assert(controller.enemies.is_empty(), "none mode spawns nothing")
	controller.queue_free()
	await process_frame
	LevelSpawns.reload()

func _test_preview() -> void:
	var profile := LevelSpawns.default_profile("act_01_node_03")
	profile.mode = LevelSpawns.MODE_CUSTOM
	profile.interval = 0.5
	profile.mix = {"pursuer": 0.0, "breaker": 0.0, "ranged": 100.0}
	GameFlow.preview_level_id = "act_01_node_03"
	GameFlow.preview_profile = profile
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	assert(controller.preview_mode and not controller.persistence_enabled, "preview never saves")
	assert(controller.current_level_id() == "act_01_node_03", "preview opened the chosen level (locked levels too)")
	assert(controller.spawn_profile.interval == 0.5, "preview uses the editor's settings")
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	controller.simulate_step(3.0)
	assert(not controller.enemies.is_empty())
	for enemy in controller.enemies:
		assert(MonsterStats.id_for_kind(enemy.enemy_kind) == "ranged")
	assert(controller.assignment_notice.begins_with("PREVIEW"))
	controller.quit_to_title()
	assert(GameFlow.reopen_spawn_editor_level == "act_01_node_03")
	assert(GameFlow.preview_level_id.is_empty())
	await process_frame
	await process_frame
	GameFlow.reopen_spawn_editor_level = ""
