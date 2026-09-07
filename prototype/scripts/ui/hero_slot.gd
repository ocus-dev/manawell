class_name HeroSlot
extends PanelContainer

const Portraits = preload("res://scripts/ui/hero_portraits.gd")

signal guard_picker_requested(well_id: String)

var well_id: String = ""
var slot_data: Dictionary = {}
var initials_label: Label
var name_label: Label
var detail_label: Label
var action_button: Button

func _ready() -> void:
	if initials_label == null:
		_build()

func configure(next_data: Dictionary, next_well_id: String) -> void:
	slot_data = next_data.duplicate(true)
	well_id = next_well_id
	if initials_label == null:
		_build()
	var state_id: String = str(slot_data.get("well_state_id", "commissioned"))
	var assigned: bool = bool(slot_data.get("assigned", false))
	var assignable: bool = state_id == "commissioned"
	initials_label.visible = assignable
	Portraits.apply(initials_label, str(slot_data.get("id", "")) if assigned and assignable else "")
	var unavailable_reason: String = str(slot_data.get("availability_reason", ""))
	if state_id == "locked":
		initials_label.text = "LOCK"
		name_label.text = "Locked"
		detail_label.text = unavailable_reason
		action_button.text = "Locked"
		action_button.disabled = true
		action_button.tooltip_text = unavailable_reason
		return
	if state_id == "available":
		initials_label.text = "-"
		name_label.text = "Not commissioned"
		detail_label.text = unavailable_reason
		action_button.text = "Commission first"
		action_button.disabled = true
		action_button.tooltip_text = unavailable_reason
		return
	var label: String = str(slot_data.get("label", "Assign guard"))
	initials_label.text = _initials(label) if assigned else "+"
	name_label.text = label
	detail_label.text = str(slot_data.get("role_label", "Unstaffed"))
	if assigned:
		action_button.text = "Change guard"
		action_button.tooltip_text = "Open guard options for this well"
	else:
		action_button.text = "Assign guard"
		action_button.tooltip_text = "Assign a reserve hero to this well"
	action_button.disabled = not assignable
	update_minimum_size()

func request_guard_picker() -> void:
	if not slot_data.is_empty():
		guard_picker_requested.emit(well_id)

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := VBoxContainer.new()
	row.name = "HeroSlotContent"
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	initials_label = Label.new()
	initials_label.name = "HeroInitials"
	initials_label.custom_minimum_size = Vector2(0, 24)
	initials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials_label.add_theme_font_size_override("font_size", 20)
	row.add_child(initials_label)
	var copy := VBoxContainer.new()
	copy.name = "HeroCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label = Label.new()
	name_label.name = "HeroName"
	name_label.add_theme_font_size_override("font_size", 16)
	copy.add_child(name_label)
	detail_label = Label.new()
	detail_label.name = "HeroRole"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	copy.add_child(detail_label)
	row.add_child(copy)
	action_button = Button.new()
	action_button.name = "GuardAction"
	action_button.custom_minimum_size = Vector2(0, 40)
	action_button.pressed.connect(request_guard_picker)
	row.add_child(action_button)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_guard_picker()
		accept_event()

func _initials(label: String) -> String:
	var words: PackedStringArray = label.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return label.left(2).to_upper()

