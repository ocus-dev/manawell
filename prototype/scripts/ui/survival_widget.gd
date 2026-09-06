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
	custom_minimum_size = Vector2(250, 132)
	var content := VBoxContainer.new()
	content.name = "SurvivalContent"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	content.add_child(_label("SURVIVAL", 14))
	var hero_row := HBoxContainer.new()
	var hero_label := _label("Hero", 16)
	hero_label.name = "Hero"
	hero_label.custom_minimum_size = Vector2(72, 32)
	hero_row.add_child(hero_label)
	hero_bar = _bar()
	hero_row.add_child(hero_bar)
	hero_value = _label("0 / 0", 14)
	hero_value.custom_minimum_size = Vector2(72, 32)
	hero_row.add_child(hero_value)
	content.add_child(hero_row)
	var machine_row := HBoxContainer.new()
	var machine_label := _label("Harvester", 16)
	machine_label.name = "Harvester"
	machine_label.custom_minimum_size = Vector2(72, 32)
	machine_row.add_child(machine_label)
	machine_bar = _bar()
	machine_row.add_child(machine_bar)
	machine_value = _label("0 / 0", 14)
	machine_value.custom_minimum_size = Vector2(72, 32)
	machine_row.add_child(machine_value)
	content.add_child(machine_row)

func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(110, 32)
	bar.show_percentage = false
	return bar

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label