extends Node2D

const ArenaLayoutScript = preload("res://data/arena_layout.gd")

@export var opacity: float = 0.28
@export var width: float = 42.0
@export var height: float = 9.0
@export var falloff: float = 180.0

var target: Node2D
var support_y: float = ArenaLayoutScript.FLOOR_TOP_Y
var airborne := false
var base_width: float
var enabled := true

func _ready() -> void:
	z_index = 1

func track(next_target: Node2D) -> void:
	target = next_target
	base_width = width

func _process(_delta: float) -> void:
	if not enabled or not is_instance_valid(target) or target.is_queued_for_deletion() or _target_is_dead():
		visible = false
		return
	var feet_y := target.global_position.y + 40.0
	support_y = _resolve_support_y(feet_y, target.global_position.x)
	if not is_finite(support_y):
		visible = false
		return
	var distance := maxf(0.0, support_y - feet_y)
	var distance_ratio := clampf(distance / falloff, 0.0, 1.0)
	var scale_ratio := lerpf(1.0, 0.58, distance_ratio)
	position = Vector2(target.global_position.x, support_y + 2.0)
	width = maxf(12.0, base_width * scale_ratio)
	modulate.a = opacity * lerpf(1.0, 0.45, distance_ratio)
	visible = true
	queue_redraw()

func _resolve_support_y(feet_y: float, actor_x: float) -> float:
	var best_y := INF
	var grounded_support_id := ""
	if target != null and "grounded" in target and bool(target.get("grounded")) and "support_id" in target:
		grounded_support_id = str(target.get("support_id"))
	if grounded_support_id != "":
		return ArenaLayoutScript.support_top(grounded_support_id)
	for support in ArenaLayoutScript.platform_supports():
		var rect: Rect2 = support["rect"]
		if actor_x >= rect.position.x and actor_x <= rect.end.x and rect.position.y >= feet_y and rect.position.y < best_y:
			best_y = rect.position.y
	if is_finite(best_y):
		return best_y
	if feet_y <= ArenaLayoutScript.FLOOR_TOP_Y:
		return ArenaLayoutScript.FLOOR_TOP_Y
	return INF

func _target_is_dead() -> bool:
	return target != null and "dead" in target and bool(target.get("dead"))

func _draw() -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(Vector2(cos(angle) * width, sin(angle) * height))
	draw_colored_polygon(points, Color(0.01, 0.02, 0.025, 1.0))