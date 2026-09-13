extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const PreviewScript = preload("res://scripts/ui/operations_preview.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var preview: Control = load("res://scenes/ui/operations_preview.tscn").instantiate()
	preview.include_notice_placeholder = false
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _settle()
	assert(TestCheckScript.check(preview.theme != null, "preview uses the canonical theme"))
	assert(TestCheckScript.check(preview.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion") != null, "wells region exists"))
	assert(TestCheckScript.check(preview.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/ExpeditionLaunchRegion/ExpeditionRegion/ExpeditionPanelContent/StartExtraction") != null, "launch control exists"))
	assert(TestCheckScript.check(preview.body.vertical == false, "target width uses two columns"))
	assert(_essential_controls_fit(preview, Vector2(1280, 720)))
	root.size = Vector2i(1920, 1080)
	await _settle()
	assert(TestCheckScript.check(preview.body.vertical == false, "large target width uses two columns"))
	assert(_essential_controls_fit(preview, Vector2(1920, 1080)))
	root.size = Vector2i(1280, 720)
	await _settle()
	var standard_button: Button = preview.expedition_panel.loadout_buttons.get("standard")
	standard_button.grab_focus()
	await process_frame
	var had_focus := preview.get_viewport().gui_get_focus_owner() == standard_button
	preview.refresh(preview.view_state)
	await process_frame
	assert(TestCheckScript.check(preview.expedition_panel.loadout_buttons.get("standard") == standard_button, "identical refresh preserves loadout button identity"))
	if had_focus:
		assert(TestCheckScript.check(preview.get_viewport().gui_get_focus_owner() == standard_button, "identical refresh preserves loadout focus"))
	root.size = Vector2i(800, 720)
	await _settle()
	assert(TestCheckScript.check(preview.body.vertical == true, "narrow width stacks operations columns"))
	assert(TestCheckScript.check(preview.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder").columns == 1, "narrow width reflows well cards"))
	assert(TestCheckScript.check(preview.get_node("OperationsScroll").vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "narrow operations content is vertically scrollable"))
	assert(TestCheckScript.check(preview.get_node("OperationsScroll").get_h_scroll_bar().visible == false, "narrow operations content has no horizontal scrollbar"))
	assert(preview is PreviewScript)
	print("operations_preview: theme=canonical bounds=verified identity=verified responsive=1280x720+1920x1080+800x720")
	quit(0)

func _settle() -> void:
	for frame in range(8):
		await process_frame

func _essential_controls_fit(preview: Control, resolution: Vector2) -> bool:
	var screen := Rect2(Vector2.ZERO, resolution)
	for path in [
		"ViewportSettingsButton",
		"OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion",
		"OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/ExpeditionLaunchRegion/ExpeditionRegion/ExpeditionPanelContent/StartExtraction",
	]:
		var control := preview.get_node(path) as Control
		var rect := control.get_global_rect()
		if rect.position.x < screen.position.x or rect.end.x > screen.end.x:
			return false
	return true