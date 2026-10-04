extends Control

## Life on the hero's health bar: bubbles drift up inside the filled part.
## (Flames along the top edge and embers are built in but off: show_flames.)
## Sits on top of the bar (full rect) and ignores the mouse. Everything follows
## the fill, so it shrinks as the hero takes damage.

@export var flame_colors := [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.12), Color(0.9, 0.15, 0.05)]
@export var flame_height := 7.0
@export var flame_spacing := 7.0
@export var bubbles_per_second := 6.0
@export var embers_per_second := 4.0
@export var show_flames := false

var bar: Range
var _time := 0.0
var _bubbles: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _bubble_timer := 0.0
var _ember_timer := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bar == null and get_parent() is Range:
		bar = get_parent() as Range
	_rng.seed = 11

func _fill_width() -> float:
	if bar == null or bar.max_value <= bar.min_value:
		return size.x
	return size.x * clampf((bar.value - bar.min_value) / (bar.max_value - bar.min_value), 0.0, 1.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var width := _fill_width()
	_bubble_timer -= delta
	if width > 4.0 and _bubble_timer <= 0.0:
		_bubble_timer = 1.0 / maxf(0.1, bubbles_per_second) * _rng.randf_range(0.5, 1.5)
		_bubbles.append({"x": _rng.randf_range(2.0, width - 2.0), "y": size.y - 1.0, "r": _rng.randf_range(0.8, 1.8), "speed": _rng.randf_range(4.0, 9.0), "wobble": _rng.randf_range(0.0, TAU)})
	_ember_timer -= delta
	if show_flames and width > 4.0 and _ember_timer <= 0.0:
		_ember_timer = 1.0 / maxf(0.1, embers_per_second) * _rng.randf_range(0.5, 1.5)
		_embers.append({"x": _rng.randf_range(0.0, width), "y": -2.0, "age": 0.0, "life": _rng.randf_range(0.5, 0.9), "drift": _rng.randf_range(-6.0, 6.0)})
	var bubbles: Array[Dictionary] = []
	for bubble in _bubbles:
		bubble.y -= float(bubble.speed) * delta
		if bubble.y > 1.0 and float(bubble.x) < width:
			bubbles.append(bubble)
	_bubbles = bubbles
	var embers: Array[Dictionary] = []
	for ember in _embers:
		ember.age += delta
		if ember.age < ember.life:
			embers.append(ember)
	_embers = embers
	queue_redraw()

func _draw() -> void:
	var width := _fill_width()
	if width < 3.0:
		return
	# Bubbles inside the fill (light, see-through, slight sideways wobble).
	for bubble in _bubbles:
		var at := Vector2(float(bubble.x) + sin(_time * 5.0 + float(bubble.wobble)) * 0.6, float(bubble.y))
		draw_circle(at, float(bubble.r), Color(1.0, 0.8, 0.75, 0.35))
		draw_circle(at + Vector2(-0.3, -0.3), float(bubble.r) * 0.4, Color(1, 1, 1, 0.6))
	if not show_flames:
		return
	# Flames along the top edge: overlapping tongues, each flickering on its own.
	var x := 0.0
	var index := 0
	while x < width:
		var flicker := 0.55 + 0.45 * sin(_time * (9.0 + float(index % 5)) + float(index) * 1.9)
		var height := flame_height * flicker
		var half := flame_spacing * 0.6
		for layer in flame_colors.size():
			var shrink := 1.0 - float(layer) * 0.28
			var color: Color = flame_colors[flame_colors.size() - 1 - layer]
			color.a = 0.55 + 0.15 * float(layer)
			var base_y := 1.0
			var tip := Vector2(x + sin(_time * 7.0 + float(index)) * 1.2, base_y - height * shrink)
			var points := PackedVector2Array([Vector2(x - half * shrink, base_y), tip, Vector2(x + half * shrink, base_y)])
			draw_colored_polygon(points, color)
		x += flame_spacing
		index += 1
	# Embers drifting up off the flames.
	for ember in _embers:
		var t: float = float(ember.age) / float(ember.life)
		var at := Vector2(float(ember.x) + float(ember.drift) * t, float(ember.y) - 10.0 * t)
		draw_circle(at, 1.0, Color(1.0, 0.75, 0.3, 1.0 - t))
