extends PanelContainer

var surge_label: Label
var multiplier_label: Label
var threat_label: Label
var pressure_bar: ProgressBar

func _ready() -> void:
	if surge_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if surge_label == null:
		_build()
	var paused: bool = bool(view_data.get("paused", false))
	var next_surge: float = float(view_data.get("next_surge_seconds", 0.0))
	surge_label.text = "Next surge: %.1fs%s" % [next_surge, " · paused" if paused else ""]
	var surge_tier: int = int(view_data.get("completed_surges", 0))
	multiplier_label.text = "SURGE %d  ·  x%.2f" % [surge_tier, float(view_data.get("multiplier", 1.0))]
	var surge_duration: float = 20.0
	pressure_bar.max_value = surge_duration
	pressure_bar.value = surge_duration - next_surge if not paused else surge_duration
	threat_label.text = str(view_data.get("threat_label", "Surge pressure"))

func _build() -> void:
	custom_minimum_size = Vector2(250, 52)
	add_theme_stylebox_override("panel", _compact_panel())
	var content := VBoxContainer.new()
	content.name = "PressureContent"
	content.add_theme_constant_override("separation", 2)
	add_child(content)
	multiplier_label = _label("SURGE 0  ·  x1.00", 14)
	multiplier_label.name = "Multiplier"
	content.add_child(multiplier_label)
	surge_label = _label("Next surge: 0.0s", 14)
	surge_label.name = "NextSurge"
	content.add_child(surge_label)
	pressure_bar = ProgressBar.new()
	pressure_bar.name = "PressureProgress"
	pressure_bar.custom_minimum_size = Vector2(220, 6)
	pressure_bar.show_percentage = false
	content.add_child(pressure_bar)
	threat_label = _label("Surge pressure", 12)
	threat_label.name = "ThreatSignal"
	threat_label.visible = false
	content.add_child(threat_label)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _compact_panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171c22e6")
	panel.border_color = Color("#3e4852")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 7
	panel.content_margin_right = 7
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	return panel