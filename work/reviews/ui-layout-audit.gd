extends SceneTree

func _init() -> void:
	call_deferred("audit")

func audit() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		var preview = load("res://scenes/ui/operations_preview.tscn").instantiate()
		preview.include_notice_placeholder = false
		root.add_child(preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for frame in range(8):
			await process_frame
		print("RESOLUTION ", resolution, " root=", preview.size)
		inspect_controls(preview, Rect2(Vector2.ZERO, Vector2(resolution)))
		var original_button = preview.expedition_panel.loadout_buttons.get("standard")
		preview.refresh(preview.view_state)
		print("REFRESH retains standard button: ", original_button == preview.expedition_panel.loadout_buttons.get("standard"))
		preview.queue_free()
		await process_frame
	quit(0)

func inspect_controls(node: Node, screen: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		if node is Button or node.name in ["OperationsWorkspace", "WellsRegion", "ResearchRegion", "ExpeditionRegion"]:
			var bounds: Rect2 = node.get_global_rect()
			print(node.name, " rect=", bounds, " min=", node.get_combined_minimum_size(), " fits=", screen.encloses(bounds))
	for child in node.get_children():
		inspect_controls(child, screen)
