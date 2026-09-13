extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const InteractionProbeScript = preload("res://tests/interaction_probe.gd")

class ResetStore extends RefCounted:
	var clear_count: int = 0
	var writes_allowed: bool = true
	var last_error: String = ""
	var loaded_production_utc_timestamp: float = 0.0
	var loaded_snapshot: Dictionary = {}

	func clear_save() -> bool:
		clear_count += 1
		return true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	var reset_store := ResetStore.new()
	controller.save_store = reset_store
	controller.account_state.bank = 99.0
	controller.account_state.owned_upgrades["damage_1"] = true
	controller._update_hud()
	await _settle()

	var hud: Control = controller.encounter_hud
	var settings_button: Button = hud.operations.viewport_settings_button
	assert(InteractionProbeScript.assert_interactable(settings_button, "Settings button"))
	assert(InteractionProbeScript.hover_and_click(self, settings_button, "Settings button"))
	await _settle()
	assert(TestCheckScript.check(hud.settings_panel.visible, "pointer click opens Settings"))

	var clear_button: Button = hud.settings_panel.get_node("SettingsContent/ClearSavedProgress")
	assert(InteractionProbeScript.assert_interactable(clear_button, "Clear saved progress button"))
	assert(InteractionProbeScript.hover_and_click(self, clear_button, "Clear saved progress button"))
	await _settle()
	assert(TestCheckScript.check(hud.settings_panel.confirmation_dialog.visible, "pointer click opens clear confirmation"))
	var confirm_button: Button = hud.settings_panel.confirmation_dialog.get_ok_button()
	_activate(confirm_button)
	await _settle()
	assert(TestCheckScript.check(reset_store.clear_count == 1, "pointer confirm clears saved progress"))
	assert(TestCheckScript.check(controller.account_state.bank == 0.0, "pointer clear resets bank"))
	assert(TestCheckScript.check(not controller.account_state.has_upgrade("damage_1"), "pointer clear resets upgrades"))
	assert(TestCheckScript.check(not hud.settings_panel.visible, "successful pointer clear closes Settings"))
	assert(TestCheckScript.check(hud.operations.expedition_panel.view_data.get("destination_id", "") == "well_1", "pointer clear refreshes operations"))
	assert(TestCheckScript.check(hud.operations.expedition_panel.view_data.get("start_available", false), "fresh Well 1 remains startable after clear"))
	assert(TestCheckScript.check(hud.operations.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_1/WellCardContent/PrepareButton").text == "Start extraction", "fresh Well 1 exposes the bootstrap start action"))
	print("settings_interaction: pointer=open+confirm reset=verified")
	controller.queue_free()
	quit(0)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var window := control.get_window()
	var viewport := control.get_viewport()
	if window != get_root():
		point = control.position + control.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.window_id = window.get_window_id()
	press.position = point
	press.pressed = true
	viewport.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.window_id = window.get_window_id()
	release.position = point
	release.pressed = false
	viewport.push_input(release)

func _activate(control: Control) -> void:
	var window := control.get_window()
	var viewport := control.get_viewport()
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.window_id = window.get_window_id()
	press.pressed = true
	viewport.push_input(press)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.window_id = window.get_window_id()
	release.pressed = false
	viewport.push_input(release)

func _settle() -> void:
	for frame in range(4):
		await process_frame
