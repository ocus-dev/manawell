extends Control

## Crackling electricity wrapped around a bar: two jagged strands spiral along
## the bar (crossing over and under it) and flicker a few times a second, with
## a soft glow. Sits on top of the bar (full rect) and ignores the mouse.
## Only the filled part of the bar is wrapped when `follow_fill` is set.

@export var bolt_color := Color(0.70, 0.92, 1.0, 0.95)
@export var glow_color := Color(0.25, 0.65, 1.0, 0.30)
@export var strands := 2
@export var turns_per_100px := 1.6
@export var overhang := 4.0
@export var jitter := 2.2
@export var flicker_seconds := 0.07
@export var follow_fill := true

var bar: Range
var _time := 0.0
var _flicker := 0.0
var _seed := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bar == null and get_parent() is Range:
		bar = get_parent() as Range

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_flicker += delta
	if _flicker >= flicker_seconds:
		_flicker = 0.0
		_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	queue_redraw()

func _draw() -> void:
	var width := size.x
	if follow_fill and bar != null and bar.max_value > bar.min_value:
		width *= clampf((bar.value - bar.min_value) / (bar.max_value - bar.min_value), 0.0, 1.0)
	if width < 6.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var mid := size.y * 0.5
	var amplitude := size.y * 0.5 + overhang
	var step := 4.0
	for strand in strands:
		var phase := TAU * float(strand) / float(maxi(1, strands)) + _time * 7.0
		var points := PackedVector2Array()
		var x := 0.0
		while x <= width:
			var wave := sin(phase + x / 100.0 * turns_per_100px * TAU)
			var y := mid + wave * amplitude + rng.randf_range(-jitter, jitter)
			points.append(Vector2(x, y))
			x += step
		if points.size() < 2:
			continue
		draw_polyline(points, glow_color, 5.0, true)
		draw_polyline(points, bolt_color, 1.3, true)
	# A few bright sparks along the strands.
	for spark in 3:
		var sx := rng.randf_range(0.0, width)
		var sy := mid + rng.randf_range(-amplitude, amplitude)
		draw_circle(Vector2(sx, sy), rng.randf_range(1.0, 2.2), Color(0.9, 0.98, 1.0, 0.9))
