extends PanelContainer

var surge_label: Label
var multiplier_label: Label
var threat_label: Label

func _ready() -> void:
	if surge_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if surge_label == null:
		_build()
	var paused: bool = bool(view_data.get("paused", false))
	var next_surge: float = float(view_data.get("next_surge_seconds", 0.0))
	surge_label.text = "Next surge: %.1fs%s" % [next_surge, " · paused" if paused else ""]
	multiplier_label.text = "Surges %d · pressure x%.2f" % [int(view_data.get("completed_surges", 0)), float(view_data.get("multiplier", 1.0))]
	threat_label.text = "Threat signal: %s" % str(view_data.get("threat_label", "Surge pressure"))

func _build() -> void:
	custom_minimum_size = Vector2(280, 110)
	var content := VBoxContainer.new()
	content.name = "PressureContent"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	content.add_child(_label("PRESSURE", 14))
	surge_label = _label("Next surge: 0.0s", 18)
	surge_label.name = "NextSurge"
	content.add_child(surge_label)
	multiplier_label = _label("Surges 0 · pressure x1.00", 16)
	multiplier_label.name = "Multiplier"
	content.add_child(multiplier_label)
	threat_label = _label("Threat signal: Surge pressure", 14)
	threat_label.name = "ThreatSignal"
	content.add_child(threat_label)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label