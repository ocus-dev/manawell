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
	custom_minimum_size = Vector2(250, 30)
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
	_style_hero_bar(hero_bar)
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
	# The harvester's health isn't shown (the bar still updates, hidden).
	machine_row.visible = false

func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(140, 7)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	return bar

## Hero health: a multi-tone red fill (deep crimson -> red -> hot orange-red,
## with a lighter band across the top) on a dark track.
func _style_hero_bar(bar: ProgressBar) -> void:
	bar.custom_minimum_size.y = 9
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color("5c0a12"), Color("b3121f"), Color("e8312a"), Color("ff6a4a")])
	var horizontal := GradientTexture2D.new()
	horizontal.gradient = gradient
	horizontal.width = 128
	horizontal.height = 8
	var fill := StyleBoxTexture.new()
	fill.texture = horizontal
	bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("2a1012")
	track.border_color = Color("5a1a1e")
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	var shine := ColorRect.new()
	shine.name = "Shine"
	shine.color = Color(1.0, 0.75, 0.7, 0.22)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.anchor_right = 1.0
	shine.offset_top = 1.0
	shine.offset_bottom = 3.0
	bar.add_child(shine)
	var fx := preload("res://scripts/ui/hero_bar_fx.gd").new()
	fx.name = "HeroBarFx"
	bar.add_child(fx)
	bar.value_changed.connect(func(_v: float) -> void:
		shine.anchor_right = clampf((bar.value - bar.min_value) / maxf(0.001, bar.max_value - bar.min_value), 0.0, 1.0))

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