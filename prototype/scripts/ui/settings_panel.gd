extends PanelContainer

signal retry_save_requested
signal retry_settlement_requested
signal clear_requested
signal developer_toggle_requested
signal resolution_requested(width: int, height: int)
signal ui_scale_requested(scale: float)
signal closed

var developer_section: VBoxContainer
var confirmation_dialog: ConfirmationDialog
var resolution_selector: OptionButton
var ui_scale_slider: HSlider
var ui_scale_value: Label

func _ready() -> void:
	if developer_section == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if developer_section == null:
		_build()
	developer_section.visible = bool(view_data.get("developer_mode", false))
	get_node("SettingsContent/RetrySave").disabled = not bool(view_data.get("pending_save", false))
	get_node("SettingsContent/RetrySettlement").disabled = float(view_data.get("offline_pending_total", 0.0)) <= 0.0

func request_clear() -> void:
	confirmation_dialog.popup_centered()
	confirmation_dialog.get_ok_button().grab_focus()

func _on_confirm_clear() -> void:
	confirmation_dialog.hide()
	clear_requested.emit()

func _on_cancel_clear() -> void:
	confirmation_dialog.hide()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if confirmation_dialog.visible:
			confirmation_dialog.hide()
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
	var resolution_label := Label.new()
	resolution_label.text = "WINDOW SIZE"
	resolution_label.add_theme_font_size_override("font_size", 14)
	content.add_child(resolution_label)
	resolution_selector = OptionButton.new()
	resolution_selector.name = "Resolution"
	resolution_selector.custom_minimum_size = Vector2(0, 40)
	for resolution in [[1024, 576], [1280, 720], [1600, 900], [1920, 1080]]:
		resolution_selector.add_item("%d x %d" % [resolution[0], resolution[1]])
		resolution_selector.set_item_metadata(resolution_selector.item_count - 1, Vector2i(resolution[0], resolution[1]))
	resolution_selector.item_selected.connect(_on_resolution_selected)
	content.add_child(resolution_selector)
	var ui_scale_label := Label.new()
	ui_scale_label.text = "UI SCALE"
	ui_scale_label.add_theme_font_size_override("font_size", 14)
	content.add_child(ui_scale_label)
	var ui_scale_row := HBoxContainer.new()
	ui_scale_row.name = "UIScaleRow"
	ui_scale_slider = HSlider.new()
	ui_scale_slider.name = "UIScale"
	ui_scale_slider.min_value = 0.7
	ui_scale_slider.max_value = 1.0
	ui_scale_slider.step = 0.05
	ui_scale_slider.value = 1.0
	ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_scale_slider.custom_minimum_size = Vector2(0, 40)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	ui_scale_row.add_child(ui_scale_slider)
	ui_scale_value = Label.new()
	ui_scale_value.name = "UIScaleValue"
	ui_scale_value.custom_minimum_size = Vector2(60, 40)
	ui_scale_row.add_child(ui_scale_value)
	content.add_child(ui_scale_row)
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
	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.name = "ClearConfirmation"
	confirmation_dialog.title = "Clear saved progress"
	confirmation_dialog.dialog_text = "Clear saved progress? This restores the fresh Well 1 and Hero 1 account."
	confirmation_dialog.ok_button_text = "Confirm clear"
	confirmation_dialog.add_cancel_button("Cancel")
	confirmation_dialog.confirmed.connect(_on_confirm_clear)
	confirmation_dialog.canceled.connect(_on_cancel_clear)
	add_child(confirmation_dialog)
	_select_current_resolution()
	get_window().size_changed.connect(_select_current_resolution)
	visibility_changed.connect(_select_current_resolution)

func _on_resolution_selected(index: int) -> void:
	var size: Vector2i = resolution_selector.get_item_metadata(index)
	resolution_requested.emit(size.x, size.y)

func _on_ui_scale_changed(value: float) -> void:
	ui_scale_value.text = "%d%%" % roundi(value * 100.0)
	ui_scale_requested.emit(value)

func set_ui_scale(value: float) -> void:
	if ui_scale_slider == null:
		return
	ui_scale_slider.set_value_no_signal(clampf(value, ui_scale_slider.min_value, ui_scale_slider.max_value))
	ui_scale_value.text = "%d%%" % roundi(ui_scale_slider.value * 100.0)

func _select_current_resolution() -> void:
	if resolution_selector == null:
		return
	var current := get_window().size
	var selected_index := -1
	for index in resolution_selector.item_count:
		var size: Vector2i = resolution_selector.get_item_metadata(index)
		if size == current:
			selected_index = index
	resolution_selector.select(selected_index)
	if selected_index == -1:
		resolution_selector.text = "%d x %d (current)" % [current.x, current.y]
