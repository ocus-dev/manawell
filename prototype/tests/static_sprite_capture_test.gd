extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const CAPTURE_DIR := "res://../work/playtests/static-sprite-slice"

var window_sizes := [Vector2i(1280, 720), Vector2i(1920, 1080)]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		print("Static sprite captures skipped: headless renderer has no viewport texture")
		quit(0)
		return
	await process_frame
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		print("Static sprite captures skipped: headless renderer has no viewport texture")
		quit(0)
		return
	if viewport_texture.get_image() == null:
		print("Static sprite captures skipped: headless renderer has no viewport texture")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	await _capture_preview()
	await _capture_startup()
	await _capture_encounter()
	print("Static sprite capture fixtures rendered")
	quit(0)

func _capture_preview() -> void:
	var preview: Node = load("res://scenes/previews/side_view_visual_slice.tscn").instantiate()
	root.add_child(preview)
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("preview-lineup", window_size)
	preview.queue_free()
	await process_frame

func _capture_startup() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("startup-operations", window_size)
	var operations = controller.encounter_hud.operations
	operations.navigation_buttons["research"].emit_signal("pressed")
	await _settle_frames()
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("startup-research", window_size)
	operations.navigation_buttons["crew"].emit_signal("pressed")
	await _settle_frames()
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("startup-crew", window_size)
	controller.queue_free()
	await process_frame

func _capture_encounter() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	assert(controller.start_run())
	await _settle_frames()
	controller.hero.position.x = controller.MACHINE_X
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("encounter-hero-crossing", window_size)
	var pursuer = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, -1)
	var breaker = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
	var ranged = controller.spawn_enemy(EnemyScript.EnemyKind.RANGED, 1)
	pursuer.position.x = 270.0
	breaker.position.x = 880.0
	ranged.position.x = 1040.0
	ranged.warning_visible = true
	ranged.warning_remaining = BalanceData.RANGED_WINDUP
	controller.spawn_hostile_projectile(ranged.position.x, controller.hero.position.x, ranged.attack_damage, ranged)
	for window_size in window_sizes:
		root.size = window_size
		await _settle_frames()
		_capture("encounter-all-roles", window_size)
	controller.queue_free()
	await process_frame

func _settle_frames() -> void:
	for _frame in range(20):
		await process_frame

func _capture(name: String, window_size: Vector2i) -> void:
	var relative_path := "%s/%s-%d.png" % [CAPTURE_DIR, name, window_size.x]
	var path := ProjectSettings.globalize_path(relative_path)
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "Could not save capture: %s (%s)" % [path, error])
	print("Captured ", path)