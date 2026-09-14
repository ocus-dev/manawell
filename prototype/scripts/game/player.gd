class_name SideViewHero
extends Node2D

const BalanceData = preload("res://data/balance.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const LEFT_BOUND: float = ArenaLayoutScript.LEFT_BOUND
const RIGHT_BOUND: float = ArenaLayoutScript.RIGHT_BOUND
const FEET_OFFSET: float = ArenaLayoutScript.HERO_FEET_OFFSET
const GROUND_SUPPORT_Y: float = ArenaLayoutScript.FLOOR_TOP_Y - ArenaLayoutScript.HERO_FEET_OFFSET

var last_facing: int = 1
var visual: Node
var vertical_velocity: float = 0.0
var grounded: bool = true
var jump_buffer_remaining: float = 0.0
var coyote_remaining: float = 0.0
var support_id: String = ArenaLayoutScript.FLOOR_ID
var ignored_support_id := ""
var drop_through_remaining: float = 0.0

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "HeroVisual"
	visual.z_index = 1
	add_child(visual)
	visual.configure("hero")
	visual.set_facing(last_facing)

func simulate_tick(delta: float, signed_input: float, jump_pressed: bool = false, jump_held: bool = true, drop_requested: bool = false) -> void:
	simulate_motion(delta, signed_input, 0, false, jump_pressed, jump_held, drop_requested)

func simulate_motion(delta: float, signed_input: float, dash_direction: int, dash_active: bool, jump_pressed: bool = false, jump_held: bool = true, drop_requested: bool = false) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var horizontal_input := clampf(signed_input, -1.0, 1.0)
	if not is_zero_approx(horizontal_input):
		last_facing = 1 if horizontal_input > 0.0 else -1
	var horizontal_speed := BalanceData.DASH_SPEED * 32.0 if dash_active else BalanceData.HERO_HORIZONTAL_SPEED
	var horizontal_direction := horizontal_input
	if dash_active:
		horizontal_direction = -1.0 if dash_direction < 0 else 1.0
		last_facing = -1 if dash_direction < 0 else 1
	position.x = clampf(position.x + horizontal_direction * horizontal_speed * delta, LEFT_BOUND, RIGHT_BOUND)
	drop_through_remaining = maxf(0.0, drop_through_remaining - delta)
	if ignored_support_id != "" and position.y > ArenaLayoutScript.hero_support_y(ignored_support_id) + ArenaLayoutScript.DROP_THROUGH_CLEARANCE:
		ignored_support_id = ""
	if grounded and support_id != ArenaLayoutScript.FLOOR_ID and not ArenaLayoutScript.overlaps_hero(ArenaLayoutScript.support_by_id(support_id), position.x):
		grounded = false
		support_id = ""
		vertical_velocity = 0.0
	if drop_requested and grounded and support_id != ArenaLayoutScript.FLOOR_ID:
		ignored_support_id = support_id
		drop_through_remaining = ArenaLayoutScript.DROP_THROUGH_DURATION
		grounded = false
		support_id = ""
		vertical_velocity = 1.0
	if jump_pressed:
		jump_buffer_remaining = BalanceData.HERO_JUMP_BUFFER_TIME
	else:
		jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	if grounded:
		coyote_remaining = BalanceData.HERO_COYOTE_TIME
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)
	if jump_buffer_remaining > 0.0 and (grounded or coyote_remaining > 0.0) and not drop_requested:
		vertical_velocity = BalanceData.HERO_JUMP_VELOCITY
		grounded = false
		coyote_remaining = 0.0
		jump_buffer_remaining = 0.0
	if not jump_held and vertical_velocity < BalanceData.HERO_JUMP_RELEASE_VELOCITY:
		vertical_velocity = BalanceData.HERO_JUMP_RELEASE_VELOCITY
	if not grounded:
		var previous_y := position.y
		vertical_velocity = minf(vertical_velocity + BalanceData.HERO_GRAVITY * delta, BalanceData.HERO_TERMINAL_VELOCITY)
		position.y += vertical_velocity * delta
		var landing := ArenaLayoutScript.support_for_landing(previous_y, position.y, position.x, ignored_support_id)
		if not landing.is_empty():
			var landing_id := str(landing["id"])
			position.y = ArenaLayoutScript.hero_support_y(landing_id)
			vertical_velocity = 0.0
			grounded = true
			support_id = landing_id
			coyote_remaining = BalanceData.HERO_COYOTE_TIME
	if visual != null:
		visual.set_locomotion(not is_zero_approx(horizontal_direction) and grounded)
		visual.set_facing(last_facing)
	queue_redraw()

func simulate_dash_tick(delta: float, direction: int) -> void:
	simulate_motion(delta, 0.0, direction, true)

static func normalized_horizontal_input(left_strength: float, right_strength: float) -> float:
	return clampf(right_strength - left_strength, -1.0, 1.0)

func capture_snapshot_state() -> Dictionary:
	return {"last_facing": last_facing, "vertical_velocity": vertical_velocity, "grounded": grounded, "support_id": support_id, "ignored_support_id": ignored_support_id, "drop_through_remaining": drop_through_remaining, "jump_buffer_remaining": jump_buffer_remaining, "coyote_remaining": coyote_remaining}

func reset_motion() -> void:
	vertical_velocity = 0.0
	grounded = true
	support_id = ArenaLayoutScript.FLOOR_ID
	ignored_support_id = ""
	drop_through_remaining = 0.0
	jump_buffer_remaining = 0.0
	coyote_remaining = BalanceData.HERO_COYOTE_TIME
	position.y = GROUND_SUPPORT_Y

func restore_snapshot_state(state: Dictionary) -> void:
	last_facing = -1 if int(state.get("last_facing", 1)) < 0 else 1
	vertical_velocity = float(state.get("vertical_velocity", 0.0))
	grounded = bool(state.get("grounded", true))
	support_id = str(state.get("support_id", ArenaLayoutScript.FLOOR_ID))
	ignored_support_id = str(state.get("ignored_support_id", ""))
	drop_through_remaining = maxf(0.0, float(state.get("drop_through_remaining", 0.0)))
	jump_buffer_remaining = maxf(0.0, float(state.get("jump_buffer_remaining", 0.0)))
	coyote_remaining = maxf(0.0, float(state.get("coyote_remaining", 0.0)))
	if visual != null:
		visual.set_facing(last_facing)
