extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const TestCheckScript = preload("res://tests/test_check.gd")
const CAPTURE_DIR := "res://../work/playtests/compact-combat-hud"
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SCENARIOS := ["all-roles", "low-health", "cooldowns", "sealing", "paused"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		print("Compact HUD captures skipped: headless renderer has no viewport texture")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	for window_size in WINDOW_SIZES:
		root.size = window_size
		await process_frame
		for scenario in SCENARIOS:
			await _capture_scenario(scenario, window_size)
	print("compact_combat_hud: scenarios=5 resolutions=1280x720+1920x1080 bounds=verified native_captures=verified")
	quit(0)

func _capture_scenario(scenario: String, window_size: Vector2i) -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	assert(TestCheckScript.check(controller.start_run(), "fixture starts an extraction for " + scenario))
	await process_frame
	_configure_scenario(controller, scenario)
	root.size = window_size
	await _settle_frames()
	if scenario == "low-health":
		controller.run_state.hero_health = 8.0
		controller.run_state.machine_integrity = 22.0
		controller._update_hud()
	_assert_layout(controller, window_size, scenario)
	await _capture(controller, scenario, window_size)
	controller.queue_free()
	await process_frame

func _configure_scenario(controller: Node, scenario: String) -> void:
	var pursuer: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, -1)
	var breaker: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
	var ranged: Node = controller.spawn_enemy(EnemyScript.EnemyKind.RANGED, 1)
	pursuer.position.x = 270.0
	breaker.position.x = 880.0
	ranged.position.x = 1040.0
	ranged.warning_visible = true
	ranged.warning_remaining = BalanceData.RANGED_WINDUP
	controller.spawn_hostile_projectile(ranged.position.x, controller.hero.position.x, ranged.attack_damage, ranged)
	if scenario == "low-health":
		controller.run_state.hero_health = 12.0
		controller.run_state.machine_integrity = 34.0
	elif scenario == "cooldowns":
		assert(TestCheckScript.check(controller.try_dash(1), "dash enters cooldown"))
		controller.try_pulse()
		assert(TestCheckScript.check(controller.pulse_cooldown_remaining > 0.0, "pulse enters cooldown fixture"))
	elif scenario == "sealing":
		controller.tick(3.0)
		controller.request_harvest()
	elif scenario == "paused":
		controller.toggle_pause()
	controller._update_hud()

func _assert_layout(controller: Node, window_size: Vector2i, scenario: String) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(window_size))
	var hud: Control = controller.encounter_hud.combat
	var widgets := [hud.find_child("SurvivalWidget", true, false), hud.find_child("PressureWidget", true, false), hud.find_child("CombatWallet", true, false), hud.find_child("AbilityBar", true, false), hud.find_child("ExtractionWidget", true, false)]
	for widget in widgets:
		var bounds: Rect2 = widget.get_global_rect()
		print("hud_acceptance_bounds ", scenario, " ", widget.name, " ", bounds)
		assert(TestCheckScript.check(viewport_rect.encloses(bounds), scenario + " " + widget.name + " stays inside viewport"))
	var health_rect: Rect2 = widgets[0].get_global_rect()
	assert(TestCheckScript.check(health_rect.position.x <= 1.0 and health_rect.position.y <= 1.0, scenario + " health snaps to the top-left corner"))
	assert(TestCheckScript.check(widgets[1].get_global_rect().position.y >= health_rect.end.y - 1.0, scenario + " surge sits below health"))
	assert(TestCheckScript.check(widgets[2].get_global_rect().end.y <= 64.0, scenario + " pause stays in top band"))
	assert(TestCheckScript.check(widgets[3].get_global_rect().position.y >= 656.0, scenario + " skills stay in logical bottom band"))
	assert(TestCheckScript.check(widgets[4].get_global_rect().position.y >= widgets[1].get_global_rect().end.y - 1.0, scenario + " mana sits below surge"))

func _capture(controller: Node, scenario: String, window_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("%s/%s-%d.png" % [CAPTURE_DIR, scenario, window_size.x])
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(TestCheckScript.check(error == OK, "capture writes " + path))
	print("Captured ", path)

func _settle_frames() -> void:
	for _frame in range(10):
		await process_frame
