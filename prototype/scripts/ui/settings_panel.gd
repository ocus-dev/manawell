extends PanelContainer

signal retry_save_requested
signal retry_settlement_requested
signal clear_requested
signal developer_toggle_requested
signal closed

var developer_section: VBoxContainer
var confirmation: PanelContainer

func _ready() -> void:
	if developer_section == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if developer_section == null:
		_build()
	developer_section.visible = bool(view_data.get("developer_mode", false))
	get_node("SettingsContent/RetrySave").disabled = not bool(view_data.get("pending_save", false))
	get_node("SettingsContent/RetrySettlement").disabled = float(view_data.get("offline_pending_total", 0.0)) <= 0.0
	_hide_confirmation()

func request_clear() -> void:
	confirmation.visible = true
	confirmation.custom_minimum_size = Vector2(0, 136)
	confirmation.move_to_front()
	confirmation.get_node("ClearConfirmationContent/CancelClear").grab_focus()

func _on_confirm_clear() -> void:
	confirmation.visible = false
	clear_requested.emit()

func _on_cancel_clear() -> void:
	_hide_confirmation()

func _hide_confirmation() -> void:
	if confirmation != null:
		confirmation.visible = false

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if confirmation.visible:
			_hide_confirmation()
		else:
			closed.emit()
	elif event.keycode == KEY_E or event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()

func _build() -> void:
	custom_minimum_size = Vector2(360, 260)
	focus_mode = Control.FOCUS_ALL
	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var retry_save := Button.new()
	retry_save.name = "RetrySave"
	retry_save.text = "Retry save"
	retry_save.custom_minimum_size = Vector2(0, 40)
	retry_save.pressed.connect(retry_save_requested.emit)
	content.add_child(retry_save)
	var retry_settlement := Button.new()
	retry_settlement.name = "RetrySettlement"
	retry_settlement.text = "Retry offline settlement"
	retry_settlement.custom_minimum_size = Vector2(0, 40)
	retry_settlement.pressed.connect(retry_settlement_requested.emit)
	content.add_child(retry_settlement)
	var danger_heading := Label.new()
	danger_heading.text = "DANGER AREA"
	danger_heading.add_theme_font_size_override("font_size", 14)
	content.add_child(danger_heading)
	var clear_button := Button.new()
	clear_button.name = "ClearSavedProgress"
	clear_button.text = "Clear saved progress"
	clear_button.custom_minimum_size = Vector2(0, 40)
	clear_button.pressed.connect(request_clear)
	content.add_child(clear_button)
	developer_section = VBoxContainer.new()
	developer_section.name = "DeveloperControls"
	var developer_heading := Label.new()
	developer_heading.text = "DEVELOPER"
	developer_section.add_child(developer_heading)
	var developer_toggle := Button.new()
	developer_toggle.name = "SealingToggle"
	developer_toggle.text = "Toggle sealing duration"
	developer_toggle.pressed.connect(developer_toggle_requested.emit)
	developer_section.add_child(developer_toggle)
	content.add_child(developer_section)
	var close_button := Button.new()
	close_button.name = "CloseSettings"
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(closed.emit)
	content.add_child(close_button)
	confirmation = PanelContainer.new()
	confirmation.name = "ClearConfirmation"
	confirmation.custom_minimum_size = Vector2(0, 136)
	confirmation.visible = false
	content.add_child(confirmation)
	var confirmation_content := VBoxContainer.new()
	confirmation_content.name = "ClearConfirmationContent"
	confirmation.add_child(confirmation_content)
	var warning := Label.new()
	warning.text = "Clear saved progress? This restores the fresh Well 1 and Hero 1 account."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_content.add_child(warning)
	var confirm := Button.new()
	confirm.name = "ConfirmClear"
	confirm.text = "Confirm clear"
	confirm.custom_minimum_size = Vector2(0, 40)
	confirm.pressed.connect(_on_confirm_clear)
	confirmation_content.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "CancelClear"
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(_on_cancel_clear)
	confirmation_content.add_child(cancel)