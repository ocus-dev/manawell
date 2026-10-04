extends PanelContainer

## In-game settings: window size and UI scale. Close with × or Esc.
## (Save problems are handled by the notice box, which has its own Retry.)

signal resolution_requested(width: int, height: int)
signal ui_scale_requested(scale: float)
signal closed

const RESOLUTIONS := [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var resolution_selector: OptionButton
var ui_scale_slider: HSlider
var ui_scale_value: Label
var close_button: Button

func _ready() -> void:
	if resolution_selector == null:
		_build()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.keycode == KEY_E or event.keycode == KEY_SPACE:
		# Don't let gameplay keys (harvest/jump) leak through while open.
		get_viewport().set_input_as_handled()

## Puts keyboard focus on the first setting (called when the panel opens).
func focus_first() -> void:
	if resolution_selector == null:
		_build()
	resolution_selector.grab_focus()

func set_ui_scale(value: float) -> void:
	if ui_scale_slider == null:
		return
	ui_scale_slider.set_value_no_signal(clampf(value, ui_scale_slider.min_value, ui_scale_slider.max_value))
	ui_scale_value.text = "%d%%" % roundi(ui_scale_slider.value * 100.0)

func _build() -> void:
	custom_minimum_size = Vector2(360, 0)
	focus_mode = Control.FOCUS_ALL
	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	content.add_child(header)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)
	close_button = Button.new()
	close_button.name = "CloseSettings"
	close_button.text = "×"
	close_button.tooltip_text = "Close (Esc)"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(closed.emit)
	header.add_child(close_button)

	content.add_child(_caption("WINDOW SIZE"))
	resolution_selector = OptionButton.new()
	resolution_selector.name = "Resolution"
	resolution_selector.custom_minimum_size = Vector2(0, 40)
	for resolution in RESOLUTIONS:
		resolution_selector.add_item("%d x %d" % [resolution.x, resolution.y])
		resolution_selector.set_item_metadata(resolution_selector.item_count - 1, resolution)
	resolution_selector.item_selected.connect(_on_resolution_selected)
	content.add_child(resolution_selector)

	content.add_child(_caption("UI SCALE"))
	var ui_scale_row := HBoxContainer.new()
	ui_scale_row.name = "UIScaleRow"
	content.add_child(ui_scale_row)
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
	ui_scale_value.text = "100%"
	ui_scale_row.add_child(ui_scale_value)

	_select_current_resolution()
	get_window().size_changed.connect(_select_current_resolution)
	visibility_changed.connect(_select_current_resolution)

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	return label

func _on_resolution_selected(index: int) -> void:
	var size: Vector2i = resolution_selector.get_item_metadata(index)
	resolution_requested.emit(size.x, size.y)

func _on_ui_scale_changed(value: float) -> void:
	ui_scale_value.text = "%d%%" % roundi(value * 100.0)
	ui_scale_requested.emit(value)

func _select_current_resolution() -> void:
	if resolution_selector == null:
		return
	var current := get_window().size
	var selected_index := RESOLUTIONS.find(current)
	resolution_selector.select(selected_index)
	if selected_index == -1:
		resolution_selector.text = "%d x %d (current)" % [current.x, current.y]
