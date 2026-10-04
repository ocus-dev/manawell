extends PanelContainer

var surge_label: Label
var multiplier_label: Label
var threat_label: Label
var pressure_bar: ProgressBar
var boss_label: Label
var level_label: Label

func _ready() -> void:
	if surge_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if surge_label == null:
		_build()
	var paused: bool = bool(view_data.get("paused", false))
	var next_surge: float = float(view_data.get("next_surge_seconds", 0.0))
	var at_limit: bool = bool(view_data.get("at_surge_limit", false))
	var limit: int = int(view_data.get("surge_limit", 0))
	if at_limit:
		surge_label.text = "Holding at surge limit%s" % (" · paused" if paused else "")
	else:
		surge_label.text = "Next surge: %.1fs%s" % [next_surge, " · paused" if paused else ""]
	var surge_tier: int = int(view_data.get("completed_surges", 0))
	var tier_text := "SURGE %d / %d" % [surge_tier, limit] if limit > 0 else "SURGE %d" % surge_tier
	multiplier_label.text = "%s  ·  x%.2f" % [tier_text, float(view_data.get("multiplier", 1.0))]
	var surge_duration: float = 20.0
	pressure_bar.max_value = surge_duration
	pressure_bar.value = surge_duration if paused or at_limit else surge_duration - next_surge
	threat_label.text = str(view_data.get("threat_label", "Surge pressure"))
	var level_name := str(view_data.get("level_name", ""))
	level_label.text = level_name
	level_label.visible = not level_name.is_empty()
	var boss_text := str(view_data.get("boss_label", ""))
	boss_label.text = boss_text
	boss_label.visible = not boss_text.is_empty()

func _build() -> void:
	custom_minimum_size = Vector2(250, 52)
	add_theme_stylebox_override("panel", _compact_panel())
	var content := VBoxContainer.new()
	content.name = "PressureContent"
	content.add_theme_constant_override("separation", 2)
	add_child(content)
	level_label = _label("", 13)
	level_label.name = "LevelName"
	level_label.add_theme_color_override("font_color", Color("9ba4ac"))
	level_label.visible = false
	content.add_child(level_label)
	multiplier_label = _label("SURGE 0  ·  x1.00", 14)
	multiplier_label.name = "Multiplier"
	content.add_child(multiplier_label)
	surge_label = _label("Next surge: 0.0s", 14)
	surge_label.name = "NextSurge"
	content.add_child(surge_label)
	pressure_bar = ProgressBar.new()
	pressure_bar.name = "PressureProgress"
	pressure_bar.custom_minimum_size = Vector2(220, 8)
	pressure_bar.show_percentage = false
	_style_surge_bar(pressure_bar)
	content.add_child(pressure_bar)
	boss_label = _label("", 13)
	boss_label.name = "BossProgress"
	boss_label.add_theme_color_override("font_color", Color("f0a836"))
	boss_label.visible = false
	content.add_child(boss_label)
	threat_label = _label("Surge pressure", 12)
	threat_label.name = "ThreatSignal"
	threat_label.visible = false
	content.add_child(threat_label)

## Surge bar: electric blue fill with lightning wrapped around the filled part.
func _style_surge_bar(bar: ProgressBar) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("1e8bff")
	fill.border_color = Color("8fd8ff")
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(2)
	fill.shadow_color = Color(0.2, 0.6, 1.0, 0.55)
	fill.shadow_size = 4
	bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0c1a2b")
	track.border_color = Color("1f3a5a")
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	var electricity := preload("res://scripts/ui/electric_bar_overlay.gd").new()
	electricity.name = "Electricity"
	bar.add_child(electricity)

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