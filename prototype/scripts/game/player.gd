class_name SideViewHero
extends Node2D

const BalanceData = preload("res://data/balance.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const LEFT_BOUND: float = ArenaLayoutScript.LEFT_BOUND
const RIGHT_BOUND: float = ArenaLayoutScript.RIGHT_BOUND
const FEET_OFFSET: float = ArenaLayoutScript.HERO_FEET_OFFSET
const GROUND_SUPPORT_Y: float = ArenaLayoutScript.FLOOR_TOP_Y - ArenaLayoutScript.HERO_FEET_OFFSET
const WEAPON_SOCKET_LOCAL := Vector2(18.0, 21.0)
## Published weapon world sprites are prepared on a 256px reference canvas, but
## their aspect ratios vary widely. Gameplay maps the largest source dimension
## to this bounded size; authored world_scale remains a multiplier rather than a
## raw pixel scale.
const HELD_WEAPON_GAME_REFERENCE_MAX_DIMENSION: float = 96.0
const HELD_WEAPON_ATTACK_PRESENTATION_DURATION: float = 0.34

var last_facing: int = 1
var visual: Node
var hero_id := "hero_1"
var vertical_velocity: float = 0.0
var grounded: bool = true
var jump_buffer_remaining: float = 0.0
var coyote_remaining: float = 0.0
var support_id: String = ArenaLayoutScript.FLOOR_ID
var ignored_support_id := ""
var drop_through_remaining: float = 0.0
var weapon_socket: Node2D
var held_weapon: Sprite2D
var held_weapon_grip := Vector2(0.5, 0.75)
var held_weapon_scale := 1.0
var held_weapon_facing := "right"
var held_weapon_rotation_degrees := 0.0
## Optional authoring offset from the hero's weapon socket, in hero-local pixels.
## Legacy revisions omit it and retain the historical socket-locked placement.
var held_weapon_hand_offset := Vector2.ZERO
var held_weapon_attack_active := false
var held_weapon_attack_rotation_offset_degrees := 0.0
var held_weapon_attack_elapsed := 0.0

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "HeroVisual"
	visual.z_index = 1
	add_child(visual)
	configure_hero(hero_id)
	visual.set_facing(last_facing)
	visual.attack_started.connect(_start_held_weapon_attack_presentation)
	visual.attack_finished.connect(_finish_held_weapon_attack_presentation)
	weapon_socket = Node2D.new()
	weapon_socket.name = "WeaponSocket"
	weapon_socket.z_index = 2
	add_child(weapon_socket)
	held_weapon = Sprite2D.new()
	held_weapon.name = "HeldWeapon"
	held_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	held_weapon.visible = false
	weapon_socket.add_child(held_weapon)
	_update_held_weapon_transform()

func configure_hero(new_hero_id: String) -> bool:
	hero_id = new_hero_id if new_hero_id == "hero_2" else "hero_1"
	if visual == null:
		return false
	return visual.configure("hero_2" if hero_id == "hero_2" else "hero")

func configure_held_weapon(texture: Texture2D, grip: Vector2 = Vector2(0.5, 0.75), facing: String = "right", world_scale: float = 1.0, rotation_degrees: float = 0.0, hand_offset: Vector2 = Vector2.ZERO) -> void:
	held_weapon_grip = Vector2(clampf(grip.x, 0.0, 1.0), clampf(grip.y, 0.0, 1.0))
	held_weapon_facing = "left" if facing == "left" else "right"
	held_weapon_scale = world_scale if is_finite(world_scale) and world_scale > 0.0 else 1.0
	held_weapon_rotation_degrees = clampf(rotation_degrees, -180.0, 180.0) if is_finite(rotation_degrees) else 0.0
	held_weapon_hand_offset = Vector2(clampf(hand_offset.x, -256.0, 256.0), clampf(hand_offset.y, -256.0, 256.0)) if is_finite(hand_offset.x) and is_finite(hand_offset.y) else Vector2.ZERO
	held_weapon_attack_active = false
	held_weapon_attack_rotation_offset_degrees = 0.0
	held_weapon_attack_elapsed = 0.0
	held_weapon.texture = texture
	held_weapon.visible = texture != null
	_update_held_weapon_transform()

func _process(delta: float) -> void:
	if not held_weapon_attack_active or held_weapon == null or held_weapon.texture == null:
		return
	held_weapon_attack_elapsed = minf(HELD_WEAPON_ATTACK_PRESENTATION_DURATION, held_weapon_attack_elapsed + maxf(0.0, delta))
	held_weapon_attack_rotation_offset_degrees = _held_weapon_attack_pose_degrees(held_weapon_attack_elapsed / HELD_WEAPON_ATTACK_PRESENTATION_DURATION)
	_update_held_weapon_transform()

func _held_weapon_attack_pose_degrees(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	var swing := 0.0
	if t < 0.25:
		swing = lerpf(0.0, -25.0, t / 0.25)
	elif t < 0.6:
		swing = lerpf(-25.0, 75.0, (t - 0.25) / 0.35)
	else:
		swing = lerpf(75.0, 0.0, (t - 0.6) / 0.4)
	return swing * -float(last_facing)

func clear_held_weapon() -> void:
	held_weapon.texture = null
	held_weapon.visible = false

func _update_held_weapon_transform() -> void:
	if weapon_socket == null or held_weapon == null:
		return
	var hero_facing_sign := -1.0 if last_facing < 0 else 1.0
	var authored_facing_sign := -1.0 if held_weapon_facing == "left" else 1.0
	var art_facing_sign := hero_facing_sign * authored_facing_sign
	weapon_socket.position = Vector2(absf(WEAPON_SOCKET_LOCAL.x) * hero_facing_sign, WEAPON_SOCKET_LOCAL.y)
	var render_scale := _held_weapon_render_scale()
	held_weapon.scale = Vector2(render_scale * art_facing_sign, render_scale)
	var presentation_rotation_degrees := held_weapon_rotation_degrees + (held_weapon_attack_rotation_offset_degrees if held_weapon_attack_active else 0.0)
	held_weapon.rotation = deg_to_rad(presentation_rotation_degrees)
	if held_weapon.texture != null:
		var size := Vector2(held_weapon.texture.get_size())
		var pivot := Vector2((0.5 - held_weapon_grip.x) * size.x, (0.5 - held_weapon_grip.y) * size.y)
		var scaled_pivot := Vector2(pivot.x * render_scale * art_facing_sign, pivot.y * render_scale)
		# Rotate the center offset with the art so the authored grip remains
		# anchored to the socket at every angle.
		held_weapon.position = scaled_pivot.rotated(held_weapon.rotation) + held_weapon_hand_offset_local()

func held_weapon_base_position() -> Vector2:
	if held_weapon == null or held_weapon.texture == null:
		return Vector2.ZERO
	var size := Vector2(held_weapon.texture.get_size())
	var pivot := Vector2((0.5 - held_weapon_grip.x) * size.x, (0.5 - held_weapon_grip.y) * size.y)
	var render_scale := _held_weapon_render_scale()
	var hero_facing_sign := -1.0 if last_facing < 0 else 1.0
	var authored_facing_sign := -1.0 if held_weapon_facing == "left" else 1.0
	return Vector2(pivot.x * render_scale * hero_facing_sign * authored_facing_sign, pivot.y * render_scale).rotated(held_weapon.rotation)

func held_weapon_hand_offset_local() -> Vector2:
	var hero_facing_sign := -1.0 if last_facing < 0 else 1.0
	return Vector2(held_weapon_hand_offset.x * hero_facing_sign, held_weapon_hand_offset.y)

func _held_weapon_render_scale() -> float:
	if held_weapon == null or held_weapon.texture == null:
		return 0.0
	var source_size := Vector2(held_weapon.texture.get_size())
	var source_max_dimension := maxf(1.0, maxf(source_size.x, source_size.y))
	return held_weapon_scale * HELD_WEAPON_GAME_REFERENCE_MAX_DIMENSION / source_max_dimension

func held_weapon_grip_world_position() -> Vector2:
	if weapon_socket == null or held_weapon == null or held_weapon.texture == null:
		return weapon_socket.global_position if weapon_socket != null else global_position
	var render_scale := _held_weapon_render_scale()
	var hero_facing_sign := -1.0 if last_facing < 0 else 1.0
	var authored_facing_sign := -1.0 if held_weapon_facing == "left" else 1.0
	var art_facing_sign := hero_facing_sign * authored_facing_sign
	var size := Vector2(held_weapon.texture.get_size())
	var grip_local := Vector2((held_weapon_grip.x - 0.5) * size.x * render_scale * art_facing_sign, (held_weapon_grip.y - 0.5) * size.y * render_scale)
	return weapon_socket.to_global(held_weapon.position + grip_local.rotated(held_weapon.rotation))

func held_weapon_world_rect() -> Rect2:
	if weapon_socket == null or held_weapon == null or held_weapon.texture == null:
		return Rect2()
	var render_scale := _held_weapon_render_scale()
	var size := Vector2(held_weapon.texture.get_size()) * render_scale
	var local_center := held_weapon.position
	var corners := [
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
	]
	var first := weapon_socket.to_global(local_center + corners[0].rotated(held_weapon.rotation))
	var bounds := Rect2(first, Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(weapon_socket.to_global(local_center + corner.rotated(held_weapon.rotation)))
	return bounds

func hero_world_rect() -> Rect2:
	if visual == null:
		return Rect2(global_position + Vector2(-28.0, -80.0), Vector2(56.0, 80.0))
	for child in visual.get_children():
		if child is CanvasItem and child.visible and child.has_method("get_rect"):
			var child_node := child as Node2D
			var local_rect: Rect2 = child.call("get_rect")
			var first := child_node.to_global(local_rect.position)
			var bounds := Rect2(first, Vector2.ZERO)
			for corner in [local_rect.position + Vector2(local_rect.size.x, 0.0), local_rect.position + Vector2(0.0, local_rect.size.y), local_rect.end]:
				bounds = bounds.expand(child_node.to_global(corner))
			return bounds
	return Rect2(global_position + Vector2(-28.0, -80.0), Vector2(56.0, 80.0))

func _start_held_weapon_attack_presentation() -> void:
	if held_weapon == null or held_weapon.texture == null:
		return
	held_weapon_attack_active = true
	# Start partway into the wind-up so the presentation is visible on the
	# same frame as the baked attack clip's attack_started signal.
	held_weapon_attack_elapsed = 0.05
	# The pose changes over the baked clip while authored calibration remains
	# untouched.
	held_weapon_attack_rotation_offset_degrees = _held_weapon_attack_pose_degrees(held_weapon_attack_elapsed / HELD_WEAPON_ATTACK_PRESENTATION_DURATION)
	held_weapon.visible = true
	_update_held_weapon_transform()

func _finish_held_weapon_attack_presentation() -> void:
	held_weapon_attack_active = false
	held_weapon_attack_rotation_offset_degrees = 0.0
	held_weapon_attack_elapsed = 0.0
	_update_held_weapon_transform()
	if held_weapon != null:
		held_weapon.visible = held_weapon.texture != null

func interrupt_held_weapon_attack() -> void:
	_finish_held_weapon_attack_presentation()

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
		_update_held_weapon_transform()
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
	_update_held_weapon_transform()
