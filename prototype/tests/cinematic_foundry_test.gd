extends SceneTree

const ArenaLayoutScript = preload("res://data/arena_layout.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var foundry: Node = load("res://scenes/experiments/cinematic_foundry.tscn").instantiate()
	root.add_child(foundry)
	await process_frame
	await process_frame
	assert(foundry.persistence_enabled == false)
	assert(foundry.environment_visual != null)
	assert(foundry.environment_visual.get_platform_rects() == ArenaLayoutScript.platform_supports())
	assert(foundry.shadow_nodes.size() >= 2)
	var hero_shadow = foundry.shadow_nodes[str(foundry.hero.get_instance_id())]
	assert(is_equal_approx(hero_shadow.position.y, ArenaLayoutScript.FLOOR_TOP_Y + 2.0))
	foundry.hero.position = Vector2(320.0, ArenaLayoutScript.hero_support_y("platform_left"))
	foundry.hero.grounded = true
	foundry.hero.support_id = "platform_left"
	foundry._refresh_shadows()
	await process_frame
	assert(is_equal_approx(hero_shadow.position.y, ArenaLayoutScript.support_top("platform_left") + 2.0))
	foundry.hero.grounded = false
	foundry.hero.support_id = "platform_left"
	foundry.hero.position = Vector2(320.0, 300.0)
	foundry._refresh_shadows()
	await process_frame
	assert(is_equal_approx(hero_shadow.position.y, ArenaLayoutScript.support_top("platform_left") + 2.0))
	foundry.hero.position = Vector2(700.0, 300.0)
	foundry._refresh_shadows()
	await process_frame
	assert(is_equal_approx(hero_shadow.position.y, ArenaLayoutScript.FLOOR_TOP_Y + 2.0))
	var machine_shadow = foundry.shadow_nodes[str(foundry.harvester_visual.get_instance_id())]
	assert(machine_shadow.width == 64.0)
	var enemy = foundry.spawn_enemy(0, 1)
	await process_frame
	assert(foundry.shadow_nodes.has(str(enemy.get_instance_id())))
	enemy.dead = true
	foundry._refresh_shadows()
	await process_frame
	assert(not foundry.shadow_nodes.has(str(enemy.get_instance_id())))
	foundry.shadows_enabled = false
	foundry._refresh_shadows()
	for i in range(4):
		await process_frame
	assert(not hero_shadow.visible)
	foundry._toggle_freeze()
	var sprite = foundry.harvester_visual.idle_sprite
	var frame: int = sprite.frame
	var progress: float = sprite.frame_progress
	for i in range(12):
		await process_frame
	assert(sprite.frame == frame and is_equal_approx(sprite.frame_progress, progress))
	foundry._toggle_freeze()
	assert(sprite.process_mode != Node.PROCESS_MODE_DISABLED)
	var position_before: Vector2 = foundry.hero.position
	foundry._toggle_presentation()
	assert(foundry.environment_visual.use_prepared_layers)
	assert(foundry.environment_visual.backdrop_texture == foundry.baseline_backdrop)
	assert(foundry.hero.position == position_before)
	assert(foundry.comparison_mode == foundry.ComparisonMode.BASELINE)
	assert(not foundry.activity_visual.visible)
	foundry = foundry.restart_experiment()
	assert(foundry.loot_rng_state == foundry.scene_seed)
	foundry.set_physics_process(false)
	for i in range(120):
		foundry._physics_process(1.0 / 60.0)
	var expected_position: Vector2 = foundry.hero.position
	var expected_seed: int = foundry.loot_rng_state
	var expected_index: int = foundry.spawn_index
	foundry = foundry.restart_experiment()
	foundry.set_physics_process(false)
	for i in range(120):
		foundry._physics_process(1.0 / 60.0)
	assert(foundry.hero.position == expected_position)
	assert(foundry.loot_rng_state == expected_seed)
	assert(foundry.spawn_index == expected_index)
	assert(foundry.activity_node_count() == 1)
	foundry.set_comparison_mode(foundry.ComparisonMode.FULL)
	var markers: Dictionary = foundry.activity_visual.marker_positions()
	assert(markers["contact"].y > 520.0 and markers["contact"].y < 545.0)
	assert(markers["exhaust"].y < markers["contact"].y - 80.0)
	assert(absf(markers["exhaust"].x - foundry.harvester_visual.position.x) < 90.0)
	assert(markers["lamp"].distance_to(foundry.harvester_visual.position) < 140.0)
	foundry.visual_config.solo("lamp_halos")
	foundry._refresh_activity()
	assert(foundry.activity_visual.light_count() == 0)
	foundry.visual_config.solo("drill_light")
	foundry._refresh_activity()
	assert(foundry.find_children("*", "Light2D", true, false).size() == 1)
	assert(foundry.activity_visual.light_count() == 1)
	foundry.visual_config.enable_all()
	foundry._refresh_activity()
	assert(foundry.activity_visual.light_count() == 1)
	var hud_layer: Node = foundry.get_node("EncounterLayer")
	assert(foundry.encounter_hud.light_mask == 0)
	assert(hud_layer.get_child(0).light_mask == 0)
	foundry.activity_visual.reset()
	foundry.weapon_projectile_count = 3
	foundry.spawn_friendly_volley(foundry.hero.position.x, 1100.0)
	assert(foundry.activity_visual.flash_count() == 1)
	foundry.spawn_friendly_projectile(foundry.hero.position.x, 1100.0)
	assert(foundry.activity_visual.flash_count() == 2)
	foundry.activity_visual.particles.append({"kind": "steam", "layer": "front", "position": markers["exhaust"], "velocity": Vector2(12.0, -20.0), "life": 1.0, "max_life": 1.0})
	foundry.set_experiment_paused(true)
	var paused_position: Vector2 = foundry.activity_visual.particles[0]["position"]
	for i in range(8):
		await process_frame
	assert(foundry.activity_visual.particles[0]["position"] == paused_position)
	foundry.set_experiment_paused(false)
	foundry.visual_config.steam_enabled = false
	foundry.cinematic_backdrop = foundry.baseline_backdrop
	foundry.cinematic_art_approved = false
	foundry = foundry.restart_experiment()
	assert(foundry.activity_node_count() == 1)
	assert(foundry.activity_visual.particle_count() == 0)
	assert(foundry.activity_visual.flash_count() == 0)
	assert(foundry.visual_config.steam_enabled == false)
	assert(foundry.cinematic_backdrop == foundry.baseline_backdrop)
	assert(foundry.environment_visual.backdrop_texture == foundry.baseline_backdrop)
	await process_frame
	assert(foundry.activity_node_count() == 1)
	foundry.queue_free()
	print("Cinematic foundry scene and support-aware shadow checks passed")
	quit(0)