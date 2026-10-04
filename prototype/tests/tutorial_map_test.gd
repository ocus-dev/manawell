extends SceneTree

## Sector B is the tutorial and nothing else: the campaign's Sector B slot opens
## the tutorial, it comes first, clearing it unlocks Scrap Approach, and PLAY
## lands first-time players on it.

const LevelSpawns = preload("res://scripts/model/level_spawns.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")
const CampaignCatalog = preload("res://scripts/model/campaign_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	return controller

func _run() -> void:
	LevelSpawns.reload()
	var catalog = CampaignCatalog.new()
	var first: String = catalog.node_ids("act_01")[0]
	assert(first == LevelSpawns.TUTORIAL_NODE_ID, "the tutorial comes first")
	assert(str(catalog.get_node("act_01", first).display_name).contains("Sector B"))
	for entry in LevelSpawns.levels():
		assert(entry.id != LevelSpawns.TUTORIAL_NODE_ID, "the Sector B slot isn't a second level")
	assert(LevelSpawns.profile(LevelSpawns.TUTORIAL_NODE_ID) == LevelSpawns.profile(LevelSpawns.TUTORIAL_ID), "one set of settings")

	# Fresh profile: Start (or E) and the map's Sector B both open the tutorial.
	var c := _controller()
	await process_frame
	assert(c.campaign_state.node_status("act_01", "act_01_node_01", c.campaign_state_catalog()).status == "locked", "Scrap Approach waits for the tutorial")
	c.request_start_or_harvest()
	assert(c.tutorial_mode and c.current_level_id() == LevelSpawns.TUTORIAL_ID, "Start opens the tutorial")
	assert(c.campaign_state.active_node_id == LevelSpawns.TUTORIAL_NODE_ID)
	assert(c.environment_visual.backdrop_id == c.environment_visual.GENERIC_BACKDROP_ID, "Sector B art")
	c.run_state.abandon()
	c.return_to_operations()
	assert(c.activate_campaign_node("act_01", LevelSpawns.TUTORIAL_NODE_ID))
	assert(c.tutorial_mode, "the map's Sector B opens the tutorial")
	# Beat the boss: Sector B cleared, Scrap Approach unlocked.
	LevelSpawns.set_value(LevelSpawns.TUTORIAL_ID, "progress_surge", 1.0)
	c._begin_zone()
	assert(c.assignment_notice.contains("Scrap Approach"), c.assignment_notice)
	c.run_state.hero_health = 1.0e9
	while c.run_state.completed_surges < 1:
		c.run_state.advance(1.0)
	c.simulate_step(1.0 / 60.0)
	c.boss_enemy.take_damage(c.boss_enemy.health)
	c.simulate_step(1.0 / 60.0)
	assert(c.tutorial_done())
	assert(c.campaign_state.node_status("act_01", "act_01_node_01", c.campaign_state_catalog()).status != "locked", "Scrap Approach unlocked")
	# Retry stays on the tutorial.
	c.run_state.abandon()
	c.retry()
	assert(c.tutorial_mode and c.current_level_id() == LevelSpawns.TUTORIAL_ID)
	c.queue_free()
	await process_frame

	# PLAY with a profile that hasn't beaten the tutorial: tutorial map.
	GameFlow.play_requested = true
	c = _controller()
	await process_frame
	await process_frame
	assert(c.tutorial_mode, "first-time PLAY lands on the tutorial")
	c.queue_free()
	await process_frame
	LevelSpawns.reload()
	print("PASS tutorial map: Sector B is only the tutorial, first in order, unlocks Scrap Approach, PLAY lands there")
	quit(0)
