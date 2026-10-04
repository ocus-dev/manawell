extends SceneTree

## Zone progression: reach the level's progress surge, a boss spawns, killing
## it clears the level (next unlocks); farming runs pay out but don't unlock;
## a surge limit below the boss surge means pure farming; a mid-fight save
## restores the boss.

const LevelSpawns = preload("res://scripts/model/level_spawns.gd")
const RunState = preload("res://scripts/model/run_state.gd")
const MonsterStats = preload("res://scripts/model/monster_stats.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const LIVE := "user://zone_progression_test.json"

func _init() -> void:
	call_deferred("_run")

func _controller(persist: bool = false) -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = persist
	if persist:
		controller.save_store = SaveStoreScript.new(LIVE)
	root.add_child(controller)
	return controller

## Advances the run clock to `surges` surges without fighting.
func _reach_surge(controller: Node, surges: int) -> void:
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	while controller.run_state.completed_surges < surges:
		controller.run_state.advance(1.0)
	controller.simulate_step(1.0 / 60.0)

func _run() -> void:
	_cleanup()
	LevelSpawns.reload()
	LevelSpawns.set_value("act_01_node_01", "progress_surge", 2.0)
	LevelSpawns.set_mode("act_01_node_01", LevelSpawns.MODE_NONE)
	LevelSpawns.set_boss_monster("act_01_node_01", "pursuer")

	# 1. Reach surge 2: the boss spawns; kill it: level cleared, next unlocked.
	var c := _controller()
	await process_frame
	c.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	assert(c.start_campaign_node("act_01", "act_01_node_01"))
	assert(c.boss_state == "waiting")
	assert(c.assignment_notice.contains("surge 2"), "the goal is announced: %s" % c.assignment_notice)
	assert(c.boss_label() == "Boss at surge 2")
	_reach_surge(c, 1)
	assert(c.boss_state == "waiting" and c.boss_enemy == null)
	_reach_surge(c, 2)
	assert(c.boss_state == "active" and c.boss_enemy != null and c.boss_enemy.is_boss)
	assert(MonsterStats.id_for_kind(c.boss_enemy.enemy_kind) == "pursuer")
	assert(is_equal_approx(c.boss_enemy.max_health, MonsterStats.get_stat("pursuer", "health") * 8.0), "boss health scaled")
	assert(c.boss_label() == "BOSS FIGHT")
	c.boss_enemy.take_damage(c.boss_enemy.health)
	c.simulate_step(1.0 / 60.0)
	assert(c.boss_state == "defeated")
	assert(c.campaign_state.is_cleared("act_01", "act_01_node_01"), "boss kill clears the level")
	assert(c.campaign_state.node_status("act_01", "act_01_node_03", c.campaign_state_catalog()).status != "locked", "next level unlocked")
	assert(c.assignment_notice.begins_with("Zone cleared"))
	# Keep farming, then harvest: success.
	c.request_harvest()
	c.tick(3.0)
	assert(c.run_state.phase == RunState.Phase.SUCCESS)
	c.queue_free()
	await process_frame

	# 2. Farming run (boss never reached): harvest pays out, nothing unlocks.
	LevelSpawns.set_value("act_01_node_03", "progress_surge", 40.0)
	c = _controller()
	await process_frame
	c.campaign_state.completed_nodes["act_01/act_01_node_02"] = true
	c.campaign_state.completed_nodes["act_01/act_01_node_01"] = true
	assert(c.start_campaign_node("act_01", "act_01_node_03"))
	_reach_surge(c, 1)
	var bank_before: float = c.account_state.bank
	c.request_harvest()
	c.tick(3.0)
	assert(c.run_state.phase == RunState.Phase.SUCCESS)
	assert(c.account_state.bank > bank_before, "farming still pays the harvest")
	assert(not c.campaign_state.is_cleared("act_01", "act_01_node_03"), "no boss, no clear")
	c.queue_free()
	await process_frame

	# 3. Surge limit below the boss surge: pure farming, the boss never comes.
	c = _controller()
	await process_frame
	c.account_state.set_surge_limit("well_1", 1)
	c.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	assert(c.start_campaign_node("act_01", "act_01_node_01"))
	_reach_surge(c, 1)
	for i in 30:
		c.run_state.advance(1.0)
	c.simulate_step(1.0 / 60.0)
	assert(c.run_state.completed_surges == 1 and c.boss_state == "waiting" and c.boss_enemy == null)
	assert(c.boss_label().contains("farming"))
	c.queue_free()
	await process_frame

	# 4. Tutorial boss clears the tutorial.
	LevelSpawns.set_value(LevelSpawns.TUTORIAL_ID, "progress_surge", 1.0)
	c = _controller()
	await process_frame
	assert(c.start_tutorial())
	_reach_surge(c, 1)
	assert(c.boss_state == "active")
	c.boss_enemy.take_damage(c.boss_enemy.health)
	c.simulate_step(1.0 / 60.0)
	assert(c.campaign_state.tutorial_cleared)
	c.queue_free()
	await process_frame

	# 4b. A run started with Start extraction (not the map) clears its own level.
	c = _controller()
	await process_frame
	assert(c.start_run())
	var level_id: String = c.current_level_id()
	LevelSpawns.set_value(level_id, "progress_surge", 1.0)
	c._begin_zone()
	var expected_next: String = str(c.campaign_state.next_node("act_01", level_id, c.campaign_state_catalog()).get("display_name", ""))
	assert(expected_next.is_empty() or c.assignment_notice.contains(expected_next), "names the right next level: %s" % c.assignment_notice)
	_reach_surge(c, 1)
	c.boss_enemy.take_damage(c.boss_enemy.health)
	c.simulate_step(1.0 / 60.0)
	assert(c.campaign_state.is_cleared("act_01", level_id), "well run clears %s" % level_id)
	c.queue_free()
	await process_frame

	# 5. Saved mid-boss-fight: the boss comes back as the boss, same health.
	c = _controller(true)
	await process_frame
	c.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	assert(c.start_campaign_node("act_01", "act_01_node_01"))
	_reach_surge(c, 2)
	c.boss_enemy.take_damage(c.boss_enemy.max_health * 0.25)
	var boss_health: float = c.boss_enemy.health
	assert(c._save_account(c._capture_snapshot()))
	c.queue_free()
	await process_frame
	var resumed := _controller(true)
	await process_frame
	assert(resumed.boss_state == "active" and resumed.boss_enemy != null and resumed.boss_enemy.is_boss, "boss restored")
	assert(is_equal_approx(resumed.boss_enemy.health, boss_health), "boss health kept (%s vs %s)" % [resumed.boss_enemy.health, boss_health])
	resumed.queue_free()
	await process_frame
	_cleanup()
	LevelSpawns.reload()
	print("PASS zone progression: boss at surge, clear + unlock, farming payout, limit below gate, tutorial, save mid-fight")
	quit(0)

func _cleanup() -> void:
	for path in [LIVE, LIVE + ".tmp", LIVE + ".bak", LIVE + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
