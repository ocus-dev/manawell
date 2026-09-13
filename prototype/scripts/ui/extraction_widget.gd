extends PanelContainer

signal harvest_requested

var payout_label: Label
var action_button: Button
var helper_label: Label

func _ready() -> void:
	if payout_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if payout_label == null:
		_build()
	var phase: int = int(view_data.get("phase", 0))
	var sealing: bool = phase == 2
	var extracting: bool = phase == 1
	var payout: int = int(view_data.get("at_risk_payout", 0))
	payout_label.text = "At risk: %d mana" % payout
	if sealing:
		action_button.text = "Sealing... %.1fs" % float(view_data.get("sealing_remaining", 0.0))
		action_button.disabled = true
		helper_label.text = "Locked"
	elif extracting:
		action_button.text = "Harvest [E]"
		action_button.disabled = bool(view_data.get("paused", false))
		helper_label.text = ""
	else:
		action_button.text = "Harvest unavailable"
		action_button.disabled = true
		helper_label.text = ""

func _on_harvest_pressed() -> void:
	if not action_button.disabled:
		harvest_requested.emit()

func _build() -> void:
	custom_minimum_size = Vector2(300, 60)
	add_theme_stylebox_override("panel", _compact_panel())
	var content := HBoxContainer.new()
	content.name = "ExtractionContent"
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	payout_label = _label("At risk: 0 mana", 16)
	payout_label.name = "AtRisk"
	payout_label.custom_minimum_size = Vector2(104, 40)
	payout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(payout_label)
	action_button = Button.new()
	action_button.name = "Harvest"
	action_button.custom_minimum_size = Vector2(156, 40)
	action_button.text = "Harvest [E]"
	action_button.pressed.connect(_on_harvest_pressed)
	content.add_child(action_button)
	helper_label = _label("", 12)
	helper_label.name = "Helper"
	helper_label.visible = false
	content.add_child(helper_label)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _compact_panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171c22e6")
	panel.border_color = Color("#d8b34b")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 7
	panel.content_margin_right = 7
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	return panel