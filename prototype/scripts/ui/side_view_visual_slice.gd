extends Node2D

const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const EnvironmentScript = preload("res://scripts/game/side_view_environment_visual.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const BASELINE_Y := 540.0
const COMPARISON_BASELINE_Y := 680.0

var role_ids := ["hero", "harvester", "pursuer", "breaker", "ranged"]
var role_visuals: Array[Node] = []
var comparison_left: Node
var comparison_right: Node
var selected_role := "hero"
var selected_scale := 1.0
var show_debug := false
var role_picker: OptionButton
var scale_slider: HSlider
var debug_toggle: CheckButton
var resolution_picker: OptionButton

func _ready() -> void:
	var environment_visual := EnvironmentScript.new()
	environment_visual.name = "EnvironmentVisual"
	environment_visual.use_prepared_layers = true
	add_child(environment_visual)
	_build_previews()
	_build_controls()
	queue_redraw()

func _build_previews() -> void:
	for index in role_ids.size():
		var visual: Node = VisualScript.new()
		visual.name = "%sPreview" % role_ids[index].capitalize()
		visual.position = Vector2(128.0 + index * 256.0, BASELINE_Y - 40.0)
		visual.z_index = 1
		add_child(visual)
		visual.configure(role_ids[index])
		visual.set_facing(1)
		role_visuals.append(visual)
	comparison_left = VisualScript.new()
	comparison_left.name = "ComparisonLeft"
	comparison_left.position = Vector2(980.0, COMPARISON_BASELINE_Y - 40.0)
	comparison_left.z_index = 1
	add_child(comparison_left)
	comparison_right = VisualScript.new()
	comparison_right.name = "ComparisonRight"
	comparison_right.position = Vector2(1120.0, COMPARISON_BASELINE_Y - 40.0)
	comparison_right.z_index = 1
	add_child(comparison_right)
	_update_comparison()

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PreviewControls"
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(32.0, 22.0)
	title.text = "SIDE-VIEW VISUAL SLICE // COMPARISON"
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)
	var role_label := Label.new()
	role_label.position = Vector2(32.0, 68.0)
	role_label.text = "COMPARE ROLE"
	layer.add_child(role_label)
	role_picker = OptionButton.new()
	role_picker.position = Vector2(32.0, 90.0)
	role_picker.size = Vector2(150.0, 32.0)
	for role_id in role_ids:
		role_picker.add_item(role_id.capitalize())
	role_picker.item_selected.connect(_on_role_selected)
	layer.add_child(role_picker)
	var scale_label := Label.new()
	scale_label.position = Vector2(210.0, 68.0)
	scale_label.text = "VISUAL SCALE"
	layer.add_child(scale_label)
	scale_slider = HSlider.new()
	scale_slider.position = Vector2(210.0, 94.0)
	scale_slider.size = Vector2(190.0, 24.0)
	scale_slider.min_value = 0.5
	scale_slider.max_value = 1.5
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.value_changed.connect(_on_scale_changed)
	layer.add_child(scale_slider)
	debug_toggle = CheckButton.new()
	debug_toggle.position = Vector2(430.0, 88.0)
	debug_toggle.text = "ANCHORS / FOOTPRINTS"
	debug_toggle.toggled.connect(_on_debug_toggled)
	layer.add_child(debug_toggle)
	resolution_picker = OptionButton.new()
	resolution_picker.position = Vector2(1040.0, 88.0)
	resolution_picker.size = Vector2(190.0, 32.0)
	resolution_picker.add_item("1280 x 720")
	resolution_picker.add_item("1920 x 1080")
	resolution_picker.item_selected.connect(_on_resolution_selected)
	layer.add_child(resolution_picker)

func _on_role_selected(index: int) -> void:
	selected_role = role_ids[index]
	_update_comparison()
	queue_redraw()

func _on_scale_changed(value: float) -> void:
	selected_scale = value
	_update_comparison()
	queue_redraw()

func _on_debug_toggled(enabled: bool) -> void:
	show_debug = enabled
	queue_redraw()

func _on_resolution_selected(index: int) -> void:
	var size := Vector2i(1280, 720) if index == 0 else Vector2i(1920, 1080)
	DisplayServer.window_set_size(size)

func get_platform_rects() -> Array[Dictionary]:
	return ArenaLayoutScript.platform_supports()

func _update_comparison() -> void:
	if comparison_left == null or comparison_right == null:
		return
	comparison_left.configure(selected_role)
	comparison_left.set_facing(-1)
	comparison_left.set_scale_multiplier(selected_scale)
	comparison_right.configure(selected_role)
	comparison_right.set_facing(1)
	comparison_right.set_scale_multiplier(selected_scale)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for support in ArenaLayoutScript.platform_supports():
		var rect: Rect2 = support["rect"]
		draw_rect(Rect2(rect.position + Vector2(0.0, 5.0), Vector2(rect.size.x, 22.0)), Color("17282d"), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color("c38a43"), true)
		draw_line(rect.position + Vector2(0.0, 7.0), rect.position + Vector2(rect.size.x, 7.0), Color("5f7778"), 2.0)
		if show_debug:
			draw_rect(rect, Color(0.2, 0.8, 0.75, 0.35), false, 2.0)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(4.0, -6.0), str(support["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ed9df"))
	draw_string(ThemeDB.fallback_font, Vector2(32.0, 150.0), "INITIAL GAMEPLAY HEIGHTS // SHARED BASELINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7d9a9f"))
	draw_line(Vector2(32.0, BASELINE_Y), Vector2(1248.0, BASELINE_Y), Color("d2a14c"), 2.0)
	draw_line(Vector2(32.0, COMPARISON_BASELINE_Y), Vector2(1248.0, COMPARISON_BASELINE_Y), Color("d2a14c"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(820.0, COMPARISON_BASELINE_Y + 28.0), "%s // LEFT / RIGHT FACING" % selected_role.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9db3b5"))
	for index in role_ids.size():
		var x := 128.0 + index * 256.0
		draw_string(ThemeDB.fallback_font, Vector2(x - 40.0, BASELINE_Y + 30.0), role_ids[index].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color("d7e4e6"))
	if show_debug:
		for visual in role_visuals:
			var hero_collider := Rect2(visual.position + Vector2(-ArenaLayoutScript.HERO_HALF_WIDTH, -ArenaLayoutScript.HERO_FEET_OFFSET), Vector2(ArenaLayoutScript.HERO_HALF_WIDTH * 2.0, ArenaLayoutScript.HERO_FEET_OFFSET))
			draw_rect(hero_collider, Color(0.95, 0.45, 0.2, 0.32), false, 1.0)
		for visual in role_visuals + [comparison_left, comparison_right]:
			if visual == null:
				continue
			var anchor: Vector2 = visual.position + visual.ground_anchor_local()
			draw_circle(anchor, 5.0, Color("ffb347"))
			draw_line(anchor - Vector2(14.0, 0.0), anchor + Vector2(14.0, 0.0), Color("ffb347"), 1.0)
			draw_line(anchor - Vector2(0.0, 14.0), anchor + Vector2(0.0, 14.0), Color("ffb347"), 1.0)
			draw_rect(Rect2(anchor.x - 18.0, anchor.y - 40.0, 36.0, 40.0), Color(0.9, 0.4, 0.2, 0.35), false, 1.0)