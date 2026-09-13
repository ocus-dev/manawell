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
	foundry.queue_free()
	print("Cinematic foundry scene and support-aware shadow checks passed")
	quit(0)