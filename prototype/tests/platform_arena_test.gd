extends SceneTree

const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const HeroScript = preload("res://scripts/game/player.gd")

func _init() -> void:
	_test_authored_layout()
	_test_one_way_landing_and_ascent()
	_test_walk_off_and_drop_through()
	_test_runtime_and_preview_geometry()
	print("P05 platform arena checks passed")
	quit(0)

func _test_authored_layout() -> void:
	assert(ArenaLayoutScript.FLOOR_TOP_Y == 540.0)
	assert(ArenaLayoutScript.LEFT_BOUND == 96.0)
	assert(ArenaLayoutScript.RIGHT_BOUND == 1184.0)
	var supports := ArenaLayoutScript.platform_supports()
	assert(supports.size() == 2)
	assert(supports[0]["id"] == "platform_left")
	assert(supports[1]["id"] == "platform_right")
	assert(supports[0]["rect"] == Rect2(260.0, 430.0, 210.0, 16.0))
	assert(supports[1]["rect"] == Rect2(810.0, 430.0, 210.0, 16.0))

func _test_one_way_landing_and_ascent() -> void:
	var hero: Node = HeroScript.new()
	hero.position = Vector2(320.0, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID))
	hero.simulate_tick(1.0 / 60.0, 0.0, true, true)
	var rose_through_platform := false
	for _step in range(60):
		if hero.position.y < ArenaLayoutScript.hero_support_y("platform_left"):
			rose_through_platform = true
		hero.simulate_tick(1.0 / 60.0, 0.0, false, true)
	assert(rose_through_platform)
	assert(hero.grounded)
	assert(hero.support_id == "platform_left")
	assert(is_equal_approx(hero.position.y, ArenaLayoutScript.hero_support_y("platform_left")))
	hero.free()

func _test_walk_off_and_drop_through() -> void:
	var hero: Node = HeroScript.new()
	hero.position = Vector2(450.0, ArenaLayoutScript.hero_support_y("platform_left"))
	hero.grounded = true
	hero.support_id = "platform_left"
	hero.simulate_tick(0.2, 1.0, false, true)
	assert(not hero.grounded)
	assert(hero.support_id == "")
	hero.position = Vector2(320.0, ArenaLayoutScript.hero_support_y("platform_left"))
	hero.grounded = true
	hero.support_id = "platform_left"
	hero.vertical_velocity = 0.0
	hero.simulate_tick(1.0 / 60.0, 0.0, true, true, true)
	assert(not hero.grounded)
	assert(hero.ignored_support_id == "platform_left")
	hero.simulate_tick(0.5, 0.0, false, true)
	assert(hero.grounded)
	assert(hero.support_id == ArenaLayoutScript.FLOOR_ID)
	assert(is_equal_approx(hero.position.y, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID)))
	hero.free()

func _test_runtime_and_preview_geometry() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	await process_frame
	assert(controller.environment_visual.get_platform_rects() == ArenaLayoutScript.platform_supports())
	var preview: Node = load("res://scenes/previews/side_view_visual_slice.tscn").instantiate()
	get_root().add_child(preview)
	await process_frame
	assert(preview.get_platform_rects() == ArenaLayoutScript.platform_supports())
	controller.queue_free()
	preview.queue_free()
