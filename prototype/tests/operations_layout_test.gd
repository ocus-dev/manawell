extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var controller = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		for frame in range(20):
			await process_frame
		var operations = controller.encounter_hud.operations
		var viewport_rect := Rect2(Vector2.ZERO, operations.size)
		assert(operations.navigation_buttons.size() == 3, "Top navigation should expose three expandable pages")
		operations.navigation_buttons["research"].emit_signal("pressed")
		await process_frame
		assert(not operations.body.visible and operations.research_panel.visible, "Research navigation should isolate the research page")
		operations.navigation_buttons["crew"].emit_signal("pressed")
		await process_frame
		assert(not operations.research_panel.visible and operations.crew_panel.visible, "Crew navigation should isolate the crew page")
		operations.navigation_buttons["operations"].emit_signal("pressed")
		await process_frame
		assert(operations.body.visible and not operations.crew_panel.visible, "Operations navigation should restore the launch page")
		print("Operations size: ", operations.size)
		for widget in [operations.resource_strip, operations.left_column, operations.right_column, operations.expedition_panel.start_button, operations.viewport_settings_button]:
			print(widget.name, " ", widget.get_global_rect(), " minimum ", widget.get_combined_minimum_size())
			assert(viewport_rect.encloses(widget.get_global_rect()), "Startup control outside viewport: " + str(widget.name))
		assert(not operations.body.vertical, "Supported viewport must show expedition beside wells")
		assert(operations.operations_scroll.get_v_scroll_bar().max_value <= operations.size.y + 1.0, "Startup content should fit without scrolling")
		assert(not operations.viewport_settings_button.get_global_rect().intersects(operations.resource_strip.bank_label.get_global_rect()), "Settings overlaps wallet")
		for button in operations.expedition_panel.loadout_buttons.values():
			var summary = button.get_node("LoadoutContent/LoadoutSummary")
			assert(button.get_global_rect().encloses(summary.get_global_rect()), "Loadout description overflows button")
		if "--capture-layout" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../work/reviews/operations-layout-%d.png" % window_size.x)
	controller.queue_free()
	await process_frame
	print("Operations layout checks passed")
	quit(0)


