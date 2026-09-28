class_name SideViewHero
extends Node2D

const BalanceData = preload("res://data/balance.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const WeaponSwingScript = preload("res://scripts/model/weapon_swing.gd")
const WeaponEffectsScript = preload("res://scripts/model/weapon_effects.gd")
const WeaponEffectScript = preload("res://scripts/game/weapon_effect.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")
const LEFT_BOUND: float = ArenaLayoutScript.LEFT_BOUND
const RIGHT_BOUND: float = ArenaLayoutScript.RIGHT_BOUND
const FEET_OFFSET: float = ArenaLayoutScript.HERO_FEET_OFFSET
const GROUND_SUPPORT_Y: float = ArenaLayoutScript.FLOOR_TOP_Y - ArenaLayoutScript.HERO_FEET_OFFSET
## The front fist of the idle hero (the weapon-free red mech art, 2026-09-28).
## Each weapon's Hand X/Y moves its grip from here.
const WEAPON_SOCKET_LOCAL := Vector2(19.0, -4.0)
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
## Per-weapon swing (WeaponSwing values). Empty means the original built-in swing.
var held_weapon_swing: Dictionary = {}
var held_weapon_attack_offset := Vector2.ZERO
## Flipbook effects (WeaponEffects entries) fired during the attack swing.
var held_weapon_effects: Array = []
var held_weapon_effect_textures: Array = []
## Seconds after the attack starts when melee damage lands (0 for ranged).
var held_weapon_hit_seconds := 0.0
## Where effects that don't follow the weapon are placed; defaults to our parent.
var effect_world_parent: Node
var effects_spawned := 0
var _effect_queue: Array = []
## Weapon attack clip (WeaponClip). Hero mode is played by the visual; weapon
## mode swaps the held weapon's picture for the clip's frames during attacks.
var held_weapon_clip: Dictionary = {}
var held_weapon_clip_texture: Texture2D
var held_weapon_clip_atlas: AtlasTexture
var held_weapon_clip_line: Dictionary = {}
var held_weapon_clip_elapsed := 0.0
var held_weapon_clip_since_start := INF
var held_weapon_clip_index := 0
var held_weapon_clip_combo_window := 1.0
var held_weapon_clip_playing := false
var held_weapon_clip_frame := -1
var _base_weapon_texture: Texture2D
## hero_weapon clips: how this weapon's picture sits in the hands.
var held_weapon_hand_fit: Dictionary = {}
var _weapon_tip := Vector2.ZERO
var _hand_placed := false
var _base_weapon_grip := Vector2(0.5, 0.75)

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "HeroVisual"
	visual.z_index = 1
	add_child(visual)
	configure_hero(hero_id)
	visual.set_facing(last_facing)
	visual.attack_started.connect(_start_held_weapon_attack_presentation)
	visual.attack_finished.connect(_on_attack_clip_finished)
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
	_stop_weapon_clip()
	held_weapon.texture = texture
	held_weapon.visible = texture != null
	_base_weapon_texture = texture
	_base_weapon_grip = held_weapon_grip
	_refresh_weapon_tip()
	_update_held_weapon_transform()

func _process(delta: float) -> void:
	_advance_attack_clips(delta)
	_advance_swing(delta)
	_place_weapon_in_hands()

func _advance_swing(delta: float) -> void:
	if not held_weapon_attack_active or held_weapon == null or held_weapon.texture == null:
		return
	var duration := held_weapon_swing_duration()
	held_weapon_attack_elapsed = minf(duration, held_weapon_attack_elapsed + maxf(0.0, delta))
	_apply_held_weapon_swing_pose(held_weapon_attack_elapsed / duration)
	_update_held_weapon_transform()
	_fire_due_effects()
	# A custom swing runs its own length, even past the end of the baked clip.
	if not held_weapon_swing.is_empty() and held_weapon_attack_elapsed >= duration:
		_finish_held_weapon_attack_presentation()

## Sets the weapon's swing (WeaponSwing values); {} restores the built-in swing.
## Sets the weapon's flipbook effects and when melee damage lands.
func configure_held_weapon_effects(effects: Array, hit_seconds: float = 0.0) -> void:
	held_weapon_effects.clear()
	held_weapon_effect_textures.clear()
	held_weapon_hit_seconds = maxf(0.0, hit_seconds)
	for effect in effects:
		if not effect is Dictionary:
			continue
		var normalized: Dictionary = WeaponEffectsScript.normalize(effect)
		var texture: Texture2D = WeaponEffectsScript.load_sheet(WeaponEffectsScript.sheet_path(effect))
		if texture == null:
			continue
		held_weapon_effects.append(normalized)
		held_weapon_effect_textures.append(texture)

func _queue_effects() -> void:
	_effect_queue.clear()
	var swing: Dictionary = held_weapon_swing if not held_weapon_swing.is_empty() else WeaponSwingScript.normalize(WeaponSwingScript.DEFAULT)
	for index in range(held_weapon_effects.size()):
		_effect_queue.append({"index": index, "time": WeaponEffectsScript.trigger_seconds(held_weapon_effects[index], swing, held_weapon_swing_duration(), held_weapon_hit_seconds)})

func _fire_due_effects() -> void:
	for entry in _effect_queue.duplicate():
		if float(entry.time) <= held_weapon_attack_elapsed + 0.0001:
			_effect_queue.erase(entry)
			spawn_weapon_effect(int(entry.index))

## Plays effect `index` now at its anchor on the held weapon.
func spawn_weapon_effect(index: int) -> Node2D:
	if index < 0 or index >= held_weapon_effects.size() or held_weapon == null or held_weapon.texture == null:
		return null
	var effect: Dictionary = held_weapon_effects[index]
	var node: Node2D = WeaponEffectScript.new()
	node.name = "WeaponEffect"
	var size := Vector2(held_weapon.texture.get_size())
	var anchor: Array = effect.anchor
	var anchor_local := Vector2((float(anchor[0]) - 0.5) * size.x, (float(anchor[1]) - 0.5) * size.y)
	var facing := -1.0 if last_facing < 0 else 1.0
	var offset: Array = effect.offset
	var world_offset := Vector2(float(offset[0]) * facing, float(offset[1]))
	var weapon_scale := held_weapon.scale
	if bool(effect.follow):
		var inverse := Vector2(1.0 / maxf(0.0001, absf(weapon_scale.x)), 1.0 / maxf(0.0001, absf(weapon_scale.y)))
		node.setup(effect, held_weapon_effect_textures[index], inverse)
		node.position = anchor_local + held_weapon.global_transform.basis_xform_inv(world_offset)
		node.rotation = deg_to_rad(float(effect.rotation)) if bool(effect.align) else -held_weapon.rotation
		node.z_index = 1
		held_weapon.add_child(node)
	else:
		node.setup(effect, held_weapon_effect_textures[index])
		var parent: Node = effect_world_parent if is_instance_valid(effect_world_parent) else get_parent()
		if parent == null:
			parent = self
		parent.add_child(node)
		node.global_position = held_weapon.to_global(anchor_local) + world_offset
		node.global_rotation = (held_weapon.global_rotation if bool(effect.align) else 0.0) + deg_to_rad(float(effect.rotation)) * facing
		node.scale = Vector2(facing, 1.0)
		node.z_index = 6
	effects_spawned += 1
	return node

# ---------- attack clip ----------

## Sets the weapon's attack clip ({} for none). `hit_seconds`: when the game
## deals damage (0 for ranged); `attack_interval`: time between attacks.
func configure_attack_clip(clip: Dictionary, hit_seconds: float = 0.0, attack_interval: float = 1.0, hand_fit: Dictionary = {}) -> void:
	held_weapon_hand_fit = WeaponClipScript.normalize_hand_fit(hand_fit)
	_refresh_weapon_tip()
	_stop_weapon_clip()
	held_weapon_clip = {}
	held_weapon_clip_texture = null
	var texture: Texture2D = WeaponClipScript.load_sheet(clip) if WeaponClipScript.is_set(clip) else null
	var normalized: Dictionary = WeaponClipScript.normalize(clip) if texture != null else {}
	var longest := 0.0
	if not normalized.is_empty():
		for index in range(WeaponClipScript.attack_ranges(normalized).size()):
			longest = maxf(longest, float(WeaponClipScript.timeline(normalized, index, hit_seconds).length))
	var combo_window := maxf(attack_interval * 1.6, longest + 0.5)
	if visual != null:
		if not normalized.is_empty() and str(normalized.mode) != "weapon":
			visual.set_attack_clip(normalized, texture, hit_seconds, combo_window, WeaponClipScript.load_hand(clip) if str(normalized.mode) == "hero_weapon" else null)
		else:
			visual.clear_attack_clip()
	if not normalized.is_empty() and str(normalized.mode) == "weapon":
		held_weapon_clip = normalized
		held_weapon_clip_texture = texture
		held_weapon_clip_atlas = AtlasTexture.new()
		held_weapon_clip_atlas.atlas = texture
		held_weapon_clip_combo_window = combo_window
		held_weapon_clip_index = 0
		held_weapon_clip_since_start = INF
	held_weapon_clip_hit_seconds = maxf(0.0, hit_seconds)
	_update_weapon_visibility()

var held_weapon_clip_hit_seconds := 0.0

func has_attack_clip() -> bool:
	return not held_weapon_clip.is_empty() or (visual != null and visual.has_attack_clip())

func _start_weapon_clip() -> void:
	if held_weapon_clip.is_empty() or _base_weapon_texture == null:
		return
	if held_weapon_clip_since_start > held_weapon_clip_combo_window:
		held_weapon_clip_index = 0
	held_weapon_clip_line = WeaponClipScript.timeline(held_weapon_clip, held_weapon_clip_index, held_weapon_clip_hit_seconds)
	held_weapon_clip_index = (held_weapon_clip_index + 1) % WeaponClipScript.attack_ranges(held_weapon_clip).size()
	held_weapon_clip_elapsed = 0.0
	held_weapon_clip_since_start = 0.0
	held_weapon_clip_playing = true
	var cell: Array = held_weapon_clip.cell
	var anchor: Array = held_weapon_clip.anchor
	held_weapon_grip = Vector2(clampf(float(anchor[0]) / float(cell[0]), 0.0, 1.0), clampf(float(anchor[1]) / float(cell[1]), 0.0, 1.0))
	held_weapon.texture = held_weapon_clip_atlas
	_show_weapon_clip_frame(WeaponClipScript.frame_at(held_weapon_clip_line, 0.0))

func _show_weapon_clip_frame(frame: int) -> void:
	held_weapon_clip_frame = frame
	if frame >= 0:
		held_weapon_clip_atlas.region = WeaponClipScript.frame_rect(held_weapon_clip, frame)

func _stop_weapon_clip() -> void:
	if not held_weapon_clip_playing:
		return
	held_weapon_clip_playing = false
	held_weapon_clip_frame = -1
	held_weapon_grip = _base_weapon_grip
	if held_weapon != null:
		held_weapon.texture = _base_weapon_texture
	_update_held_weapon_transform()

func _advance_attack_clips(delta: float) -> void:
	held_weapon_clip_since_start += maxf(0.0, delta)
	if held_weapon_clip_playing:
		held_weapon_clip_elapsed += maxf(0.0, delta)
		var frame := WeaponClipScript.frame_at(held_weapon_clip_line, held_weapon_clip_elapsed)
		if frame < 0:
			_stop_weapon_clip()
		else:
			_show_weapon_clip_frame(frame)
			_update_held_weapon_transform()
	_update_weapon_visibility()

## A hero-mode clip draws the weapon itself, so the held weapon's picture is
## hidden while one plays (its effects still show).
func _refresh_weapon_tip() -> void:
	_weapon_tip = WeaponClipScript.resolve_tip(_base_weapon_texture.get_image(), _base_weapon_grip, held_weapon_hand_fit) if _base_weapon_texture != null else Vector2.ZERO

## hero_weapon clips: puts this weapon's own picture where the frame's hands
## are (drawn behind the body when the frame says so).
func _place_weapon_in_hands() -> void:
	if held_weapon == null or visual == null:
		return
	var placing: bool = visual.clip_places_weapon() and held_weapon.texture != null
	if not placing:
		if _hand_placed:
			_hand_placed = false
			weapon_socket.z_index = 2
			_update_held_weapon_transform()
		return
	var clip: Dictionary = visual.attack_clip
	var frame: int = visual.clip_frame
	var local := WeaponClipScript.hand_transform(clip, frame, Vector2(held_weapon.texture.get_size()), held_weapon_grip, _weapon_tip, held_weapon_hand_fit)
	held_weapon.global_transform = visual.clip_cell_to_global() * local
	held_weapon.visible = true
	weapon_socket.z_index = 0 if bool(clip.track[clampi(frame, 0, clip.track.size() - 1)].get("behind", false)) else 2
	_hand_placed = true

## Where this weapon's picture sits in the hands for `frame` (tests, previews).
func hand_placed_transform() -> Transform2D:
	return held_weapon.global_transform

func _update_weapon_visibility() -> void:
	if held_weapon == null:
		return
	var hidden: bool = visual != null and visual.clip_hides_weapon()
	held_weapon.self_modulate.a = 0.0 if hidden else 1.0

func configure_held_weapon_swing(swing: Dictionary) -> void:
	held_weapon_swing = WeaponSwingScript.normalize(swing) if not swing.is_empty() else {}

func held_weapon_swing_duration() -> float:
	if held_weapon_swing.is_empty():
		return HELD_WEAPON_ATTACK_PRESENTATION_DURATION
	return maxf(0.01, float(held_weapon_swing.get("duration", HELD_WEAPON_ATTACK_PRESENTATION_DURATION)))

func _apply_held_weapon_swing_pose(progress: float) -> void:
	if held_weapon_swing.is_empty():
		held_weapon_attack_rotation_offset_degrees = _held_weapon_attack_pose_degrees(progress)
		held_weapon_attack_offset = Vector2.ZERO
		return
	var pose: Dictionary = WeaponSwingScript.sample(held_weapon_swing, progress)
	held_weapon_attack_rotation_offset_degrees = float(pose.angle) * -float(last_facing)
	var offset: Vector2 = pose.offset
	held_weapon_attack_offset = Vector2(offset.x * (-1.0 if last_facing < 0 else 1.0), offset.y)

func _on_attack_clip_finished() -> void:
	# The built-in swing follows the baked clip; custom swings end on their own.
	if held_weapon_swing.is_empty():
		_finish_held_weapon_attack_presentation()

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
	_stop_weapon_clip()
	_base_weapon_texture = null
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
		held_weapon.position = scaled_pivot.rotated(held_weapon.rotation) + held_weapon_hand_offset_local() + (held_weapon_attack_offset if held_weapon_attack_active else Vector2.ZERO)

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
	var clip_factor := float(held_weapon_clip.get("scale", 1.0)) if held_weapon_clip_playing else 1.0
	return held_weapon_scale * HELD_WEAPON_GAME_REFERENCE_MAX_DIMENSION / source_max_dimension * clip_factor

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
	_start_weapon_clip()
	_update_weapon_visibility()
	held_weapon_attack_active = true
	# Start partway into the wind-up so the presentation is visible on the
	# same frame as the baked attack clip's attack_started signal.
	held_weapon_attack_elapsed = 0.05
	# The pose changes over the baked clip while authored calibration remains
	# untouched.
	if not held_weapon_swing.is_empty():
		held_weapon_attack_elapsed = 0.0
	_apply_held_weapon_swing_pose(held_weapon_attack_elapsed / held_weapon_swing_duration())
	held_weapon.visible = true
	_queue_effects()
	_update_held_weapon_transform()
	_place_weapon_in_hands()
	_fire_due_effects()

func _finish_held_weapon_attack_presentation() -> void:
	held_weapon_attack_active = false
	held_weapon_attack_rotation_offset_degrees = 0.0
	held_weapon_attack_elapsed = 0.0
	held_weapon_attack_offset = Vector2.ZERO
	_update_held_weapon_transform()
	if held_weapon != null:
		held_weapon.visible = held_weapon.texture != null

func interrupt_held_weapon_attack() -> void:
	_finish_held_weapon_attack_presentation()
	_stop_weapon_clip()
	if visual != null and visual.has_attack_clip():
		visual.stop_attack_clip(false)
	_update_weapon_visibility()

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
