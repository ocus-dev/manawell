extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(controller)
	await process_frame
	var settings: Control = controller.encounter_hud.settings_panel
	var selector: OptionButton = settings.get_node("SettingsContent/Resolution")
	var ui_scale: HSlider = settings.get_node("SettingsContent/UIScaleRow/UIScale")
	assert(selector.item_count == 4)
	assert(selector.get_item_text(0) == "1024 x 576")
	assert(is_equal_approx(ui_scale.value, 1.0))
	controller.set_ui_scale(0.7)
	assert(is_equal_approx(controller.ui_scale, 0.7))
	assert(is_equal_approx(controller.encounter_hud.scale.x, 0.7))
	selector.select(0)
	selector.emit_signal("item_selected", 0)
	assert(controller.LOGICAL_SIZE == Vector2(1280.0, 720.0))
	controller.queue_free()
	print("Resolution setting checks passed")
	quit(0)
