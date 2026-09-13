extends PanelContainer

var hero_bar: ProgressBar
var machine_bar: ProgressBar
var hero_value: Label
var machine_value: Label

func _ready() -> void:
	if hero_bar == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if hero_bar == null:
		_build()
	var hero_health: float = float(view_data.get("hero_health", 0.0))
	var hero_max: float = float(view_data.get("hero_max_health", 100.0))
	var machine_health: float = float(view_data.get("harvester_integrity", 0.0))
	var machine_max: float = float(view_data.get("harvester_max_integrity", 150.0))
	hero_bar.max_value = hero_max
	hero_bar.value = hero_health
	machine_bar.max_value = machine_max
	machine_bar.value = machine_health
	hero_value.text = "%d / %d" % [roundi(hero_health), roundi(hero_max)]
	machine_value.text = "%d / %d" % [roundi(machine_health), roundi(machine_max)]

func _build() -> void:
	custom_minimum_size = Vector2(250, 56)
	add_theme_stylebox_override("panel", _compact_panel())
	var content := VBoxContainer.new()
	content.name = "SurvivalContent"
	content.add_theme_constant_override("separation", 2)
	add_child(content)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 4)
	var hero_label := _label("Hero", 14)
	hero_label.name = "Hero"
	hero_label.custom_minimum_size = Vector2(42, 20)
	hero_row.add_child(hero_label)
	hero_bar = _bar()
	hero_row.add_child(hero_bar)
	hero_value = _label("0 / 0", 12)
	hero_value.custom_minimum_size = Vector2(64, 20)
	hero_row.add_child(hero_value)
	content.add_child(hero_row)
	var machine_row := HBoxContainer.new()
	machine_row.add_theme_constant_override("separation", 4)
	var machine_label := _label("Harvester", 14)
	machine_label.name = "Harvester"
	machine_label.custom_minimum_size = Vector2(66, 20)
	machine_row.add_child(machine_label)
	machine_bar = _bar()
	machine_row.add_child(machine_bar)
	machine_value = _label("0 / 0", 12)
	machine_value.custom_minimum_size = Vector2(64, 20)
	machine_row.add_child(machine_value)
	content.add_child(machine_row)

func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(140, 7)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	return bar

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

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label