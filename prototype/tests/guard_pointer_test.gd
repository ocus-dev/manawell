extends SceneTree

var failures: int = 0
var selections: int = 0

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	for resolution in [Vector2i(620, 410), Vector2i(1280, 720)]:
		await check_picker(resolution)
	quit(1 if failures > 0 else 0)

func check_picker(resolution: Vector2i) -> void:
	root.size = resolution
	var controller = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	controller.account_state.commissioned_wells = {"well_1": true}
	controller.account_state.roster_heroes = {"hero_1": true, "hero_2": true}
	controller.account_state.hero_assignments = {"hero_1": {"role": "reserve", "well_id": ""}, "hero_2": {"role": "active", "well_id": ""}}
	controller.assignment_notice = "Hero 2 selected for active expeditions."
	controller._update_hud()
	var operations = controller.encounter_hud.operations
	operations._on_guard_picker_requested("well_1")
	for frame in range(5):
		await process_frame
	var picker = operations.hero_picker
	selections = 0
	picker.hero_selected.connect(func(_hero_id, _mode, _well_id): selections += 1)
	var button: Button = picker.action_buttons["hero_1"]
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	check(not button.disabled, "reserve hero Assign is enabled")
	check(root.gui_get_hovered_control() == button, "Assign receives actual mouse hover")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		if pressed:
			for frame in range(4):
				await process_frame
			check(is_instance_valid(button) and picker.action_buttons.get("hero_1") == button, "held button survives frame refreshes")
			check(root.gui_get_hovered_control() == picker.action_buttons.get("hero_1"), "hover survives frame refreshes")
	await process_frame
	check(controller.account_state.get_guard_for_well("well_1") == "hero_1", "multi-frame pointer click assigns the reserve hero")
	check(selections == 1, "pointer click dispatches once")
	check(not picker.visible, "successful assignment closes picker")
	check(controller.account_state.get_active_hero_id() == "hero_2", "expedition hero remains active")
	operations._on_guard_picker_requested("well_1")
	await process_frame
	check(picker.action_buttons["hero_1"].text == "Recall", "reopening reflects the changed guard state")
	picker.close_picker()
	controller.queue_free()
	await process_frame
	print("guard_pointer: ", resolution, " failures=", failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST CHECK FAILED: " + message)

