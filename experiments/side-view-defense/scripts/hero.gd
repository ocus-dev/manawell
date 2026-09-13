class_name SideViewHero
extends Node2D

const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const MOVEMENT_SPEED_UNITS: float = 6.0
const LEFT_BOUND: float = 96.0
const RIGHT_BOUND: float = 1184.0

var last_facing: int = 1

func simulate_tick(delta: float, signed_input: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var horizontal_input := clampf(signed_input, -1.0, 1.0)
	if not is_zero_approx(horizontal_input):
		last_facing = 1 if horizontal_input > 0.0 else -1
	position.x = clampf(position.x + horizontal_input * MOVEMENT_SPEED_UNITS * SPATIAL_PIXELS_PER_UNIT * delta, LEFT_BOUND, RIGHT_BOUND)
	queue_redraw()

static func normalized_horizontal_input(left_strength: float, right_strength: float) -> float:
	return clampf(right_strength - left_strength, -1.0, 1.0)

func _draw() -> void:
	var body_color := Color("d8e4e8")
	draw_circle(Vector2.ZERO, 19.0, Color("111b21"))
	draw_rect(Rect2(-13.0, -24.0, 26.0, 45.0), body_color, true)
	draw_circle(Vector2(0.0, -29.0), 12.0, Color("f2b84b"))
	draw_line(Vector2(10.0 * last_facing, -7.0), Vector2(38.0 * last_facing, -7.0), Color("66d9c4"), 5.0)
	draw_circle(Vector2(40.0 * last_facing, -7.0), 5.0, Color("66d9c4"))
