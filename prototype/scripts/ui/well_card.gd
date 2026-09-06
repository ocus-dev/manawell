class_name WellCard
extends PanelContainer

const HeroSlotScript = preload("res://scripts/ui/hero_slot.gd")

signal destination_requested(well_id: String)
signal start_requested
signal guard_picker_requested(well_id: String)

var well_id: String = ""
var view_data: Dictionary = {}
var name_label: Label
var state_label: Label
var schematic_label: Label
var rate_label: Label
var activity_label: Label
var guard_slot
var prepare_button: Button

func _ready() -> void:
	if name_label == null:
		_build()

func configure(next_data: Dictionary) -> void:
	view_data = next_data.duplicate(true)
	well_id = str(view_data.get("id", ""))
	if name_label == null:
		_build()
	name_label.text = str(view_data.get("label", well_id))
	state_label.text = str(view_data.get("state_label", ""))
	schematic_label.text = "[ WELL / MACHINE ]"
	rate_label.text = _rate_text()
	activity_label.text = str(view_data.get("activity_label", ""))
	activity_label.visible = not activity_label.text.is_empty()
	guard_slot.visible = not bool(view_data.get("state_id", "") == "active")
	var guard_data: Dictionary = view_data.get("guard", {}).duplicate(true)
	guard_data["well_state_id"] = str(view_data.get("state_id", ""))
	guard_data["availability_reason"] = str(view_data.get("availability_reason", ""))
	guard_slot.configure(guard_data, well_id)
	prepare_button.disabled = not bool(view_data.get("prepare_available", false))
	var selected: bool = bool(view_data.get("selected", false))
	var can_start: bool = bool(view_data.get("start_available", false))
	prepare_button.text = "Start extraction" if selected and can_start else "Selected destination" if selected else "Prepare here"
	prepare_button.tooltip_text = str(view_data.get("availability_reason", ""))
	update_minimum_size()

func refresh(next_data: Dictionary) -> void:
	configure(next_data)

func request_prepare() -> void:
	if not prepare_button.disabled:
		if bool(view_data.get("selected", false)) and bool(view_data.get("start_available", false)):
			start_requested.emit()
		else:
			destination_requested.emit(well_id)

func request_guard_picker() -> void:
	if str(view_data.get("state_id", "")) == "commissioned":
		guard_picker_requested.emit(well_id)

func _build() -> void:
	var content := VBoxContainer.new()
	content.name = "WellCardContent"
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	name_label = Label.new()
	name_label.name = "WellName"
	name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(name_label)
	state_label = Label.new()
	state_label.name = "WellState"
	state_label.add_theme_font_size_override("font_size", 14)
	content.add_child(state_label)
	schematic_label = Label.new()
	schematic_label.name = "WellSchematic"
	schematic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	schematic_label.custom_minimum_size = Vector2(0, 40)
	content.add_child(schematic_label)
	rate_label = Label.new()
	rate_label.name = "PassiveRate"
	rate_label.add_theme_font_size_override("font_size", 14)
	content.add_child(rate_label)
	activity_label = Label.new()
	activity_label.name = "ActivityLabel"
	activity_label.add_theme_font_size_override("font_size", 14)
	content.add_child(activity_label)
	guard_slot = HeroSlotScript.new()
	guard_slot.name = "GuardSlot"
	guard_slot.guard_picker_requested.connect(_on_guard_slot_requested)
	content.add_child(guard_slot)
	prepare_button = Button.new()
	prepare_button.name = "PrepareButton"
	prepare_button.custom_minimum_size = Vector2(0, 40)
	prepare_button.pressed.connect(request_prepare)
	content.add_child(prepare_button)

func _rate_text() -> String:
	var rate: float = float(view_data.get("passive_rate_per_minute", 0.0))
	if str(view_data.get("state_id", "")) == "commissioned" and not bool(view_data.get("guard", {}).get("assigned", false)):
		return "0.00 mana/min · Add a guard"
	return "%.2f mana/min" % rate

func _on_guard_slot_requested(target_well_id: String) -> void:
	if str(view_data.get("state_id", "")) == "commissioned":
		guard_picker_requested.emit(target_well_id)