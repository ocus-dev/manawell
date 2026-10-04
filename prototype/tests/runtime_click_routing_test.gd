extends SceneTree

const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.commissioned_wells = {"well_1": true}
	controller._update_hud()
	var hud: Control = controller.encounter_hud
	assert(hud.router.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	hud.operations.hero_picker.open_guard(hud.view_state["operations"]["wells"][0], hud.view_state["operations"]["heroes"])
	await process_frame
	var picker_rect: Rect2 = hud.operations.hero_picker.get_global_rect()
	var viewport_rect: Rect2 = controller.get_viewport().get_visible_rect()
	assert(picker_rect.position.x >= 0.0 and picker_rect.position.y >= 0.0)
	if viewport_rect.size.x >= picker_rect.size.x and viewport_rect.size.y >= picker_rect.size.y:
		assert(picker_rect.end.x <= viewport_rect.end.x and picker_rect.end.y <= viewport_rect.end.y)
	hud.operations.hero_picker.close_picker()
	# Found by name so layout changes to the Operations page don't break the test.
	var selected_destination: Button = hud.operations.find_child("StartExtraction", true, false)
	assert(selected_destination != null, "the expedition Start button is on the Operations page")
	assert(not selected_destination.disabled)
	selected_destination.emit_signal("pressed")
	assert(controller.run_state.phase == RunStateScript.Phase.EXTRACTING)
	hud.router.show_pause(hud.view_state.get("combat", {}))
	assert(hud.router.mouse_filter == Control.MOUSE_FILTER_STOP)
	hud.router.hide_overlays()
	assert(hud.router.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	print("runtime_click_routing: hidden-overlay-clicks=pass launch=pass modal-blocking=pass")
	controller.free()
	quit(0)
