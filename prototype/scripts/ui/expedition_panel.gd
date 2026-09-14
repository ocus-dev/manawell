class_name ExpeditionPanel
extends PanelContainer

const Portraits = preload("res://scripts/ui/hero_portraits.gd")
var hero_initials: Label

signal change_hero_requested
signal loadout_requested(loadout_id: String)
signal start_requested

var view_data: Dictionary = {}
var hero_label: Label
var capability_label: Label
var destination_label: Label
var rate_label: Label
var threat_label: Label
var guard_warning_label: Label
var loadout_rows: VBoxContainer
var start_button: Button
var start_reason_label: Label
var loadout_buttons: Dictionary = {}

func _ready() -> void:
	if hero_label == null:
		_build()

func configure(next_data: Dictionary) -> void:
	view_data = next_data.duplicate(true)
	if hero_label == null:
		_build()
	hero_label.text = str(view_data.get("active_hero_label", "No hero selected"))
	Portraits.apply(hero_initials, str(view_data.get("active_hero_id", "")))
	capability_label.text = str(view_data.get("capability_summary", ""))
	destination_label.text = str(view_data.get("destination_label", ""))
	rate_label.text = "Base extraction: %.2f mana/sec" % float(view_data.get("base_extraction_rate", 0.0))
	threat_label.text = str(view_data.get("threat_summary", ""))
	guard_warning_label.text = str(view_data.get("guard_warning", ""))
	guard_warning_label.visible = not guard_warning_label.text.is_empty()
	_reconcile_loadouts(view_data.get("loadouts", []))
	start_button.disabled = not bool(view_data.get("start_available", false))
	start_button.tooltip_text = str(view_data.get("start_disabled_reason", ""))
	start_reason_label.text = "" if not start_button.disabled else str(view_data.get("start_disabled_reason", ""))
	start_reason_label.visible = start_button.disabled

func _reconcile_loadouts(loadouts: Array) -> void:
	var definitions_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for loadout in loadouts:
		var loadout_id: String = str(loadout.get("id", ""))
		if loadout_id.is_empty():
			continue
		definitions_by_id[loadout_id] = loadout
		ordered_ids.append(loadout_id)

	for child in loadout_rows.get_children():
		var child_id: String = str(child.get_meta("loadout_id", ""))
		if not definitions_by_id.has(child_id):
			loadout_rows.remove_child(child)
			child.queue_free()

	var refreshed_buttons: Dictionary = {}
	for index in ordered_ids.size():
		var loadout_id: String = ordered_ids[index]
		var button: Button = loadout_buttons.get(loadout_id)
		if button == null or not is_instance_valid(button):
			button = _create_loadout_button(loadout_id)
			loadout_rows.add_child(button)
		loadout_rows.move_child(button, index)
		_configure_loadout_button(button, definitions_by_id[loadout_id])
		refreshed_buttons[loadout_id] = button
	loadout_buttons = refreshed_buttons

func _create_loadout_button(loadout_id: String) -> Button:
	var button := Button.new()
	button.name = "Loadout_%s" % loadout_id
	button.set_meta("loadout_id", loadout_id)
	button.custom_minimum_size = Vector2(280, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.toggle_mode = true
	button.pressed.connect(loadout_requested.emit.bind(loadout_id))
	var content := VBoxContainer.new()
	content.name = "LoadoutContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_top = 4
	content.offset_right = -8
	content.offset_bottom = -4
	content.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "LoadoutLabel"
	label.add_theme_font_size_override("font_size", 13)
	content.add_child(label)
	var summary := Label.new()
	summary.name = "LoadoutSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 10)
	content.add_child(summary)
	button.add_child(content)
	return button

func _configure_loadout_button(button: Button, loadout: Dictionary) -> void:
	var selected: bool = bool(loadout.get("selected", false))
	var label: String = str(loadout.get("label", loadout.get("id", "")))
	button.text = ""
	button.button_pressed = selected
	var summary_text := str(loadout.get("summary", ""))
	var availability := str(loadout.get("availability_reason", ""))
	button.tooltip_text = summary_text if availability.is_empty() else "%s\n%s" % [summary_text, availability]
	button.disabled = not bool(loadout.get("available", false))
	var status_prefix := "Selected - " if selected else "Locked - " if button.disabled else ""
	button.get_node("LoadoutContent/LoadoutLabel").text = status_prefix + label
	button.get_node("LoadoutContent/LoadoutSummary").text = summary_text

func request_start() -> void:
	if not start_button.disabled:
		start_requested.emit()

func select_loadout(loadout_id: String) -> void:
	var button: Button = loadout_buttons.get(loadout_id)
	if button != null and not button.disabled:
		loadout_requested.emit(loadout_id)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		request_start()
	elif event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()

func _build() -> void:
	var content := VBoxContainer.new()
	content.name = "ExpeditionPanelContent"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	var heading := Label.new()
	heading.text = "EXPEDITION"
	heading.add_theme_font_size_override("font_size", 12)
	content.add_child(heading)
	var hero_row := HBoxContainer.new()
	hero_row.name = "ControlledHero"
	hero_initials = Label.new()
	hero_initials.text = "YOU"
	hero_initials.custom_minimum_size = Vector2(44, 38)
	hero_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_row.add_child(hero_initials)
	var hero_copy := VBoxContainer.new()
	hero_copy.name = "HeroCopy"
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_label = Label.new()
	hero_label.name = "HeroName"
	hero_label.add_theme_font_size_override("font_size", 16)
	hero_copy.add_child(hero_label)
	capability_label = Label.new()
	capability_label.name = "Capability"
	capability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capability_label.add_theme_font_size_override("font_size", 12)
	hero_copy.add_child(capability_label)
	hero_row.add_child(hero_copy)
	var change_hero := Button.new()
	change_hero.name = "ChangeHero"
	change_hero.text = "Change hero"
	change_hero.custom_minimum_size = Vector2(0, 32)
	change_hero.pressed.connect(change_hero_requested.emit)
	hero_row.add_child(change_hero)
	content.add_child(hero_row)
	var destination_heading := Label.new()
	destination_heading.text = "DESTINATION"
	destination_heading.add_theme_font_size_override("font_size", 12)
	content.add_child(destination_heading)
	destination_label = Label.new()
	destination_label.name = "Destination"
	destination_label.add_theme_font_size_override("font_size", 14)
	content.add_child(destination_label)
	rate_label = Label.new()
	rate_label.name = "BaseRate"
	rate_label.add_theme_font_size_override("font_size", 12)
	content.add_child(rate_label)
	threat_label = Label.new()
	threat_label.name = "ThreatSummary"
	threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	threat_label.add_theme_font_size_override("font_size", 12)
	content.add_child(threat_label)
	guard_warning_label = Label.new()
	guard_warning_label.name = "GuardWarning"
	guard_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guard_warning_label.add_theme_font_size_override("font_size", 12)
	content.add_child(guard_warning_label)
	var loadout_heading := Label.new()
	loadout_heading.text = "HARVESTER LOADOUT"
	loadout_heading.add_theme_font_size_override("font_size", 12)
	content.add_child(loadout_heading)
	loadout_rows = VBoxContainer.new()
	loadout_rows.name = "LoadoutChoices"
	loadout_rows.add_theme_constant_override("separation", 4)
	content.add_child(loadout_rows)
	start_button = Button.new()
	start_button.name = "StartExtraction"
	start_button.text = "Start extraction [E]"
	start_button.custom_minimum_size = Vector2(220, 34)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	start_button.pressed.connect(request_start)
	content.add_child(start_button)
	start_reason_label = Label.new()
	start_reason_label.name = "StartDisabledReason"
	start_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_reason_label.add_theme_font_size_override("font_size", 12)
	content.add_child(start_reason_label)
