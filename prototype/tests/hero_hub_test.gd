extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/hero_hub.tscn")
	var scene: Control = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.selected_hero_id == scene.account.get_active_hero_id())
	assert(scene.roster_buttons.has("hero_1"))
	assert(scene.get_node("HeroStage/HeroArt").texture != null)
	assert(scene.get_node("RosterPanel/RosterMargin/RosterContent/Operations") is Button)
	if "--capture-layout" in OS.get_cmdline_user_args() and not OS.has_feature("headless"):
		root.size = Vector2i(1280, 720)
		for _frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../work/reviews/hero-hub-1280.png")
	scene.toggle_roster()
	assert(not scene.roster_expanded)
	assert(scene.get_node("CollapsedHandle").visible)
	scene.toggle_roster()
	assert(scene.roster_expanded)
	assert(not scene.get_node("CollapsedHandle").visible)
	scene.queue_free()
	print("PASS hero hub: active hero showcase, owned roster, selection entry, and collapsible rail")
	quit(0)
