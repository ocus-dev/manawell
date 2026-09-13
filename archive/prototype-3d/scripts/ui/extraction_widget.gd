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
		helper_label.text = "Keep defending; payout is locked."
	elif extracting:
		action_button.text = "Harvest [E]"
		action_button.disabled = bool(view_data.get("paused", false))
		helper_label.text = "Defend for %.1fs to bank it" % float(view_data.get("sealing_duration", 0.0))
	else:
		action_button.text = "Harvest unavailable"
		action_button.disabled = true
		helper_label.text = "Start an extraction to build a payout."

func _on_harvest_pressed() -> void:
	if not action_button.disabled:
		harvest_requested.emit()

func _build() -> void:
	custom_minimum_size = Vector2(300, 126)
	var content := VBoxContainer.new()
	content.name = "ExtractionContent"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	var heading := _label("EXTRACTION", 14)
	content.add_child(heading)
	payout_label = _label("At risk: 0 mana", 22)
	payout_label.name = "AtRisk"
	content.add_child(payout_label)
	action_button = Button.new()
	action_button.name = "Harvest"
	action_button.custom_minimum_size = Vector2(0, 44)
	action_button.text = "Harvest [E]"
	action_button.pressed.connect(_on_harvest_pressed)
	content.add_child(action_button)
	helper_label = _label("Defend to bank it", 14)
	helper_label.name = "Helper"
	content.add_child(helper_label)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label