extends SceneTree

## Home (the main city): a walkable area with the hero and nothing else. The
## map's Home button opens it from the menus (never mid-run); Esc goes back.

const ArenaLayout = preload("res://data/arena_layout.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")
const BalanceData = preload("res://data/balance.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	GameFlow.home_hero_id = "hero_1"
	var home: Node2D = load("res://scenes/home_area.tscn").instantiate()
	home.persistence_enabled = false
	root.add_child(home)
	await process_frame
	assert(home.backdrop_texture != null, "home backdrop loads")
	assert(home.command_center_texture != null, "command center loads")
	# One continuous backdrop: a slow far-sky layer and a ground strip that
	# covers the whole base with no gaps.
	assert(home.has_continuous_backdrop(), "sky and ground layers load")
	assert(home.sky_layer != null and home.sky_layer.z_index < 0, "sky draws behind")
	var parallax: float = home.sky_parallax()
	assert(parallax > 0.0 and parallax < 0.5, "sky scrolls slower than the ground")
	var far_left: float = home.world_width() - 1280.0
	assert(is_equal_approx(home.sky_offset_for(0.0), 0.0), "sky starts at the start")
	assert(home.sky_offset_for(far_left) + home.sky_size().x >= home.world_width() - 0.5, "sky still covers the view at the far end")
	assert(home.sky_size().y >= 300.0, "sky reaches down behind the treeline")
	var pieces: Array = home.ground_rects()
	assert(pieces.size() >= 2)
	assert(is_equal_approx(pieces[0].position.x, 0.0))
	for i in range(1, pieces.size()):
		assert(is_equal_approx(pieces[i].position.x, pieces[i - 1].end.x), "ground pieces join edge to edge")
	assert(pieces[pieces.size() - 1].end.x >= home.world_width(), "ground reaches the end of the base")
	for piece in pieces:
		assert(absf(piece.end.y - 720.0) < 1.0, "ground sits on the bottom of the view")
		assert(piece.position.y < home.COMMAND_CENTER_BASE_Y - 100.0, "ground's treeline is above the building base line")
	var center_rect: Rect2 = home.command_center_rect()
	assert(is_equal_approx(center_rect.get_center().x, 640.0), "command center is centred")
	assert(is_equal_approx(center_rect.end.y, home.COMMAND_CENTER_BASE_Y), "stands on its base line")
	assert(center_rect.end.y < home.hero.position.y, "behind the hero's walkway")
	# One building in each copied section after the command center.
	var used_sections := {}
	for index in home.BUILDINGS.size():
		assert(home.building_textures[index] != null, "building art loads: %s" % home.BUILDINGS[index]["id"])
		var rect: Rect2 = home.building_rect(index)
		var section: int = int(home.BUILDINGS[index]["section"])
		assert(section >= 1 and section < home.SECTION_COUNT, "building sits in a copied section")
		assert(not used_sections.has(section), "one building per section")
		used_sections[section] = true
		assert(is_equal_approx(rect.get_center().x, home.section_rect(section).get_center().x), "centred in its section")
		assert(is_equal_approx(rect.end.y, home.COMMAND_CENTER_BASE_Y), "same base line as the command center")
		assert(rect.position.y >= 0.0, "fits on screen")
		assert(rect.position.x >= home.section_rect(section).position.x and rect.end.x <= home.section_rect(section).end.x, "stays inside its section")
	assert(home.hero != null and home.hero.grounded, "hero stands on the floor")
	assert(is_equal_approx(home.hero.position.y, ArenaLayout.FLOOR_TOP_Y - ArenaLayout.HERO_FEET_OFFSET))
	# Nothing to fight: no drill, enemies or projectiles in the scene.
	for child in home.get_children():
		assert(not str(child.name).to_lower().contains("harvester"), "no drill")
		assert(not ("dead" in child), "no monsters")
	# Run right, then left, and stay inside the area.
	var start_x: float = home.hero.position.x
	home.move_right_held = true
	for i in 30:
		home.step(1.0 / 60.0)
	assert(home.hero.position.x > start_x, "runs right")
	assert(is_equal_approx(home.hero.position.x - start_x, 30.0 / 60.0 * BalanceData.HERO_HORIZONTAL_SPEED * home.HOME_WALK_SPEED_MULTIPLIER), "walks at double speed in Home")
	assert(is_equal_approx(home.HOME_WALK_SPEED_MULTIPLIER, 2.0))
	assert(home.hero.last_facing == 1)
	home.move_right_held = false
	home.move_left_held = true
	for i in 600:
		home.step(1.0 / 60.0)
	assert(is_equal_approx(home.hero.position.x, ArenaLayout.LEFT_BOUND), "stops at the left edge")
	assert(home.hero.last_facing == -1)
	home.move_left_held = false
	# The base is wider than the screen: run right through every section to
	# the far end, with the camera following and staying inside the base.
	assert(home.camera != null and home.camera.is_current(), "home camera is active")
	assert(is_equal_approx(home.world_width(), home.SECTION_WIDTH * home.SECTION_COUNT))
	assert(home.SECTION_COUNT >= 6, "original section plus 5 copies")
	assert(is_equal_approx(home.section_rect(home.SECTION_COUNT - 1).end.x, home.world_width()), "sections tile edge to edge")
	home.move_right_held = true
	var passed_first_screen := false
	for i in 6000:
		home.step(1.0 / 60.0)
		if home.hero.position.x > 1280.0:
			passed_first_screen = true
	home.move_right_held = false
	assert(passed_first_screen, "walks past the first screen")
	assert(is_equal_approx(home.hero.position.x, home.world_width() - home.EDGE_MARGIN), "stops at the far right edge")
	assert(is_equal_approx(home.camera.position.x, home.hero.position.x), "camera follows the hero")
	assert(home.camera.limit_right == int(home.world_width()) and home.camera.limit_left == 0, "camera stays inside the base")
	assert(home.hero.grounded, "still on the floor at the far end")
	# Jump and land again.
	home.pending_jump = true
	home.jump_held = true
	home.step(1.0 / 60.0)
	assert(not home.hero.grounded, "jumps")
	home.jump_held = false
	for i in 240:
		home.step(1.0 / 60.0)
	assert(home.hero.grounded, "lands on the floor")
	home.queue_free()
	await process_frame

	# Home only opens from the menus, not during a run.
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	assert(controller.encounter_hud.operations.campaign_map.home_button != null, "map card has Home")
	controller.request_start_or_harvest()
	assert(not controller.enter_home(), "no Home mid-run")
	controller.queue_free()
	await process_frame
	print("PASS home area: backdrop, hero walks the wide base with a follow camera and jumps inside the bounds, nothing to fight, menus-only entry")
	quit(0)
