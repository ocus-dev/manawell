class_name SideViewHero
extends Node2D

const BalanceData = preload("res://data/balance.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const MOVEMENT_SPEED_UNITS: float = 6.0
const LEFT_BOUND: float = 96.0
const RIGHT_BOUND: float = 1184.0

var last_facing: int = 1
var visual: Node

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "HeroVisual"
	visual.z_index = 1
	add_child(visual)
	visual.configure("hero")
	visual.set_facing(last_facing)

func simulate_tick(delta: float, signed_input: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var horizontal_input := clampf(signed_input, -1.0, 1.0)
	if not is_zero_approx(horizontal_input):
		last_facing = 1 if horizontal_input > 0.0 else -1
	position.x = clampf(position.x + horizontal_input * MOVEMENT_SPEED_UNITS * SPATIAL_PIXELS_PER_UNIT * delta, LEFT_BOUND, RIGHT_BOUND)
	if visual != null:
		visual.set_facing(last_facing)
	queue_redraw()

func simulate_dash_tick(delta: float, direction: int) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var dash_input := -1.0 if direction < 0 else 1.0
	last_facing = -1 if direction < 0 else 1
	position.x = clampf(position.x + dash_input * BalanceData.DASH_SPEED * SPATIAL_PIXELS_PER_UNIT * delta, LEFT_BOUND, RIGHT_BOUND)
	if visual != null:
		visual.set_facing(last_facing)
	queue_redraw()

static func normalized_horizontal_input(left_strength: float, right_strength: float) -> float:
	return clampf(right_strength - left_strength, -1.0, 1.0)

func capture_snapshot_state() -> Dictionary:
	return {"last_facing": last_facing}

func restore_snapshot_state(state: Dictionary) -> void:
	last_facing = -1 if int(state.get("last_facing", 1)) < 0 else 1
	if visual != null:
		visual.set_facing(last_facing)
