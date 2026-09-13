class_name HeroPicker
extends PanelContainer

const Portraits = preload("res://scripts/ui/hero_portraits.gd")

signal hero_selected(hero_id: String, mode: String, well_id: String)
signal guard_recall_requested(well_id: String)
signal cancelled

var mode: String = "guard"
var well_id: String = ""
var opener: Control
var hero_data: Array[Dictionary] = []
var current_guard_id: String = ""
var active_hero_id: String = ""
var title_label: Label
var reason_label: Label
var rows: VBoxContainer
var empty_label: Label
var cancel_button: Button
var action_buttons: Dictionary = {}
var pending_selection_id: String = ""
var pending_recall: bool = false

func _ready() -> void:
	visible = false
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_center_in_viewport()

func open_guard(well_data: Dictionary, heroes: Array[Dictionary], focus_opener: Control = null) -> void:
	mode = "guard"
	well_id = str(well_data.get("id", ""))
	current_guard_id = str(well_data.get("guard", {}).get("id", ""))
	active_hero_id = _active_id(heroes)
	opener = focus_opener
	title_label.text = "Assign a guard to %s" % str(well_data.get("label", well_id))
	reason_label.text = "Choose a reserve hero. Guard changes are explicit and do not transfer automatically."
	_render_rows(heroes)
	_show_and_focus()

func open_expedition(heroes: Array[Dictionary], selected_hero_id: String, focus_opener: Control = null) -> void:
	mode = "expedition"
	well_id = ""
	current_guard_id = ""
	active_hero_id = selected_hero_id
	opener = focus_opener
	title_label.text = "Choose your expedition hero"
	reason_label.text = "Guarded heroes stay at their assigned well until explicitly recalled."
	_render_rows(heroes)
	_show_and_focus()

func close_picker() -> void:
	_close_picker(true)

func _close_picker(was_cancelled: bool) -> void:
	visible = false
	var focus_target := opener
	opener = null
	if is_instance_valid(focus_target):
		focus_target.grab_focus()
	if was_cancelled:
		cancelled.emit()

func select_hero(hero_id: String) -> void:
	var button: Button = action_buttons.get(hero_id)
	if button == null or button.disabled:
		return
	button.disabled = true
	pending_selection_id = hero_id if mode == "guard" else ""
	hero_selected.emit(hero_id, mode, well_id)

func recall_current_guard() -> void:
	if mode != "guard" or current_guard_id.is_empty():
		return
	var button: Button = action_buttons.get(current_guard_id)
	if button != null and button.disabled:
		return
	if button != null:
		button.disabled = true
	pending_recall = true
	guard_recall_requested.emit(well_id)

func refresh_guard_state(well_data: Dictionary, heroes: Array[Dictionary], feedback: String = "", pending_save: bool = false) -> void:
	if mode != "guard" or str(well_data.get("id", "")) != well_id:
		return
	var next_guard_id := str(well_data.get("guard", {}).get("id", ""))
	var guard_changed := next_guard_id != current_guard_id
	var assignment_succeeded := not pending_selection_id.is_empty() and next_guard_id == pending_selection_id
	var recall_succeeded := pending_recall and next_guard_id.is_empty()
	current_guard_id = next_guard_id
	if assignment_succeeded or recall_succeeded:
		pending_selection_id = ""
		pending_recall = false
		_render_rows(heroes)
		if assignment_succeeded:
			_close_picker(false)
		return
	if not pending_selection_id.is_empty() or pending_recall:
		var message := feedback if not feedback.is_empty() else "The guard change was not applied."
		if pending_save:
			message += " Applied in memory; save is pending."
		reason_label.text = message
		_render_rows(heroes)
	elif guard_changed or hero_data != heroes:
		# Keep hovered/pressed controls alive across ordinary frame refreshes.
		_render_rows(heroes)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_picker()
	elif event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused != cancel_button and not focused.disabled:
			focused.emit_signal("pressed")

func _build() -> void:
	custom_minimum_size = Vector2(480, 0)
	var content := VBoxContainer.new()
	content.name = "PickerContent"
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	title_label = Label.new()
	title_label.name = "PickerTitle"
	title_label.add_theme_font_size_override("font_size", 20)
	content.add_child(title_label)
	reason_label = Label.new()
	reason_label.name = "PickerReason"
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_font_size_override("font_size", 14)
	content.add_child(reason_label)
	rows = VBoxContainer.new()
	rows.name = "HeroRows"
	rows.add_theme_constant_override("separation", 8)
	content.add_child(rows)
	empty_label = Label.new()
	empty_label.name = "EmptyState"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", 14)
	content.add_child(empty_label)
	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 40)
	cancel_button.pressed.connect(close_picker)
	content.add_child(cancel_button)

func _render_rows(heroes: Array[Dictionary]) -> void:
	for child in rows.get_children():
		child.queue_free()
	action_buttons.clear()
	hero_data = heroes.duplicate(true)
	for hero in hero_data:
		var hero_id: String = str(hero.get("id", ""))
		var row := PanelContainer.new()
		row.name = "HeroRow_%s" % hero_id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_content := HBoxContainer.new()
		row_content.name = "HeroRowContent"
		row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_content.add_theme_constant_override("separation", 12)
		row.add_child(row_content)
		var initials := Label.new()
		initials.name = "Initials"
		initials.text = _initials(str(hero.get("label", hero_id)))
		initials.custom_minimum_size = Vector2(48, 48)
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initials.add_theme_font_size_override("font_size", 18)
		row_content.add_child(initials)
		Portraits.apply(initials, hero_id)
		var copy := VBoxContainer.new()
		copy.name = "HeroCopy"
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = str(hero.get("label", hero_id))
		name_label.add_theme_font_size_override("font_size", 16)
		copy.add_child(name_label)
		var reason := Label.new()
		reason.name = "AvailabilityReason"
		reason.text = _reason_for(hero)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_font_size_override("font_size", 14)
		copy.add_child(reason)
		row_content.add_child(copy)
		var action := Button.new()
		action.name = "HeroAction"
		action.mouse_filter = Control.MOUSE_FILTER_STOP
		action.focus_mode = Control.FOCUS_ALL
		action.custom_minimum_size = Vector2(112, 40)
		action.text = _action_text(hero)
		action.disabled = not _is_available(hero)
		row_content.add_child(action)
		if mode == "guard" and hero_id == current_guard_id:
			action.text = "Recall"
			action.disabled = false
			action.pressed.connect(recall_current_guard)
		else:
			action.pressed.connect(select_hero.bind(hero_id))
		action_buttons[hero_id] = action
		rows.add_child(row)
	_render_empty_state()

func _reason_for(hero: Dictionary) -> String:
	var hero_id: String = str(hero.get("id", ""))
	if mode == "guard" and hero_id == current_guard_id:
		return "Assigned here"
	if mode == "expedition" and hero_id == active_hero_id:
		return "Current expedition hero"
	return str(hero.get("availability_reason", "Unavailable"))

func _action_text(hero: Dictionary) -> String:
	var hero_id: String = str(hero.get("id", ""))
	if mode == "guard" and hero_id == current_guard_id:
		return "Recall"
	if mode == "guard" and str(hero.get("role_id", "")) == "active":
		return "Active hero"
	if mode == "guard" and str(hero.get("role_id", "")) == "guard":
		return "Assigned elsewhere"
	if mode == "expedition" and hero_id == active_hero_id:
		return "Selected"
	return "Assign" if mode == "guard" else "Select"

func _is_available(hero: Dictionary) -> bool:
	var hero_id: String = str(hero.get("id", ""))
	if mode == "guard":
		return hero_id == current_guard_id or bool(hero.get("available_for_guard", false))
	return hero_id == active_hero_id or str(hero.get("role_id", "")) == "reserve"

func _render_empty_state() -> void:
	if mode != "guard":
		empty_label.text = ""
		return
	var has_reserve: bool = false
	for hero in hero_data:
		if bool(hero.get("available_for_guard", false)):
			has_reserve = true
			break
	empty_label.text = "" if has_reserve else "No reserve heroes available. Change your expedition hero or recall a guard first."

func _update_current_guard_row() -> void:
	for hero_id in action_buttons.keys():
		var action: Button = action_buttons[hero_id]
		if hero_id == current_guard_id:
			action.text = "Recall"
			action.disabled = false

func _show_and_focus() -> void:
	visible = true
	move_to_front()
	call_deferred("_center_in_viewport")
	cancel_button.grab_focus()

func _center_in_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2(maxf(16.0, (viewport_size.x - size.x) * 0.5), maxf(16.0, (viewport_size.y - size.y) * 0.5))

func _active_id(heroes: Array[Dictionary]) -> String:
	for hero in heroes:
		if str(hero.get("role_id", "")) == "active":
			return str(hero.get("id", ""))
	return ""

func _initials(label: String) -> String:
	var words: PackedStringArray = label.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return label.left(2).to_upper()
