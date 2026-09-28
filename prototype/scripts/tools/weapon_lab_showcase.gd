extends HBoxContainer

## Section 2's live previews, drawn by the game's own hero code:
##   Attack   the hero attacking with the weapon, on a loop
##   Holding  a still of the hero holding it (idle). Drag the weapon to move
##            it in the hand; the mouse wheel turns it, Shift+wheel resizes it.
## show_weapon() takes the lab's current values; nothing is published.

signal hand_offset_dragged(offset: Vector2, finished: bool)
signal placement_nudged(key: String, amount: float)

const HeroScript = preload("res://scripts/game/player.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

const MIN_STAGE := Vector2(200, 230)
const BACKDROP := Color("0f1215")
const FLOOR := Color("434c55")
const MUTED := Color("9ba4ac")
const GRIP := Color("f0a836")
## The hero stands centred on the world origin with its feet at FEET_Y; the
## camera looks a little right, where the weapon is. ZOOM_PER_PIXEL keeps the
## hero the same share of the stage whatever size the stage is.
const FEET_Y := 40.0
const CAMERA_FOCUS := Vector2(22, -10)
const ZOOM_PER_PIXEL := 1.4 / 220.0
const HOLD_SETTLE_FRAMES := 4

var attack_view: SubViewport
var hold_view: SubViewport
var attack_hero: Node2D
var hold_hero: Node2D
var attack_camera: Camera2D
var hold_camera: Camera2D
var hold_container: SubViewportContainer
var grip_marker: Node2D
var attack_note: Label
var hold_note: Label
var loop_period := 1.0
var loop_clock := 0.0
var attacks_played := 0
var dragging := false
var _drag_delta := Vector2.ZERO
var _hold_frames := 0
var _has_weapon := false
var _hovering := false
var walk_check: CheckBox
var hold_zoom := 1.0
var hold_zoom_label: Label
const HOLD_ZOOM_MAX := 8.0
var walking := false

func _init() -> void:
	add_theme_constant_override("separation", 10)
	var attack := _stage("Attack loop", "AttackStage")
	attack_view = attack.view
	attack_hero = attack.hero
	attack_camera = attack.camera
	attack_note = attack.note
	var hold := _stage("Holding (idle)", "HoldStage")
	hold_view = hold.view
	hold_hero = hold.hero
	hold_camera = hold.camera
	hold_note = hold.note
	hold_container = hold.container
	hold_container.mouse_filter = Control.MOUSE_FILTER_STOP
	hold_container.mouse_default_cursor_shape = Control.CURSOR_MOVE
	hold_container.tooltip_text = "Drag the weapon to put it in the hand.\nMouse wheel: turn it.  Shift + wheel: make it bigger or smaller."
	hold_container.gui_input.connect(_on_hold_input)
	# Zoom buttons in the Holding preview's top-right corner.
	var zoom_row := HBoxContainer.new()
	zoom_row.name = "HoldZoom"
	zoom_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	zoom_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zoom_row.add_theme_constant_override("separation", 2)
	(hold.frame as Control).add_child(zoom_row)
	hold_zoom_label = Label.new()
	hold_zoom_label.text = "1x"
	hold_zoom_label.add_theme_font_size_override("font_size", 11)
	hold_zoom_label.add_theme_color_override("font_color", MUTED)
	hold_zoom_label.add_theme_color_override("font_outline_color", BACKDROP)
	hold_zoom_label.add_theme_constant_override("outline_size", 3)
	hold_zoom_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zoom_row.add_child(hold_zoom_label)
	for pair in [["-", 1.0 / 1.5, "Zoom out"], ["+", 1.5, "Zoom in on the hand"]]:
		var button := Button.new()
		button.name = "HoldZoomOut" if pair[0] == "-" else "HoldZoomIn"
		button.text = str(pair[0])
		button.tooltip_text = str(pair[2]) + " (double-click the preview to go back to 1x)."
		button.custom_minimum_size = Vector2(26, 24)
		button.focus_mode = Control.FOCUS_NONE
		var factor := float(pair[1])
		button.pressed.connect(func() -> void: set_hold_zoom(hold_zoom * factor))
		zoom_row.add_child(button)
	walk_check = CheckBox.new()
	walk_check.name = "WalkCheck"
	walk_check.text = "Walk"
	walk_check.tooltip_text = "Play the hero's walk in the Holding preview, to check the weapon while walking."
	walk_check.add_theme_font_size_override("font_size", 12)
	walk_check.toggled.connect(set_walking)
	(hold.box as Control).add_child(walk_check)
	hold_container.mouse_entered.connect(func() -> void:
		_hovering = true
		_rerender_hold())
	hold_container.mouse_exited.connect(func() -> void:
		_hovering = false
		_rerender_hold())
	grip_marker = Node2D.new()
	grip_marker.name = "GripMarker"
	grip_marker.z_index = 50
	grip_marker.draw.connect(_draw_grip_marker)
	hold_view.get_node("World").add_child(grip_marker)
	for container in [attack.container, hold_container]:
		(container as Control).resized.connect(_fit_cameras)

## weapon: {texture, pivot, swing, effects, clip, hand_fit, hit_seconds,
## interval, loop_period}. texture null shows the empty-handed hero.
func show_weapon(weapon: Dictionary) -> void:
	var texture: Texture2D = weapon.get("texture")
	_has_weapon = texture != null
	var interval := maxf(0.05, float(weapon.get("interval", 1.0)))
	var hit := float(weapon.get("hit_seconds", 0.0))
	for hero in [attack_hero, hold_hero]:
		if not hero.is_inside_tree():
			continue
		hero.configure_held_weapon_swing(weapon.get("swing", {}))
		if texture == null:
			hero.clear_held_weapon()
		else:
			var pivot: Dictionary = weapon.get("pivot", {})
			var grip: Array = pivot.get("grip", [0.5, 0.75])
			var offset: Array = pivot.get("hand_offset", [0.0, 0.0])
			hero.configure_held_weapon(texture, Vector2(float(grip[0]), float(grip[1])), str(pivot.get("facing", "right")), float(pivot.get("world_scale", 1.0)), float(pivot.get("rotation_degrees", 0.0)), Vector2(float(offset[0]), float(offset[1])))
	for hero in [attack_hero, hold_hero]:
		if hero.is_inside_tree() and hero.visual != null:
			hero.visual.set_locomotion(walking and hero == hold_hero)
	if attack_hero.is_inside_tree():
		attack_hero.configure_attack_clip(weapon.get("clip", {}), hit, interval, weapon.get("hand_fit", {}))
	loop_period = maxf(0.4, float(weapon.get("loop_period", interval)))
	loop_clock = loop_period
	attack_note.text = "Attack loop" + ("" if _has_weapon else " (no art yet)")
	hold_note.text = ("Holding (idle): drag to place, wheel to turn, Shift+wheel to resize" if _has_weapon else "Holding (idle): empty hand")
	_rerender_hold()

## Walk in place in the Holding preview (the still keeps drawing while on).
func set_walking(on: bool) -> void:
	walking = on
	if hold_hero.is_inside_tree() and hold_hero.visual != null:
		hold_hero.visual.set_locomotion(on)
	hold_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else hold_view.render_target_update_mode
	if not on:
		_rerender_hold()

## Picks up newly installed hero art (idle, walk, attack).
func reload_heroes() -> void:
	for hero in [attack_hero, hold_hero]:
		if hero.is_inside_tree() and hero.visual != null:
			hero.configure_hero(hero.hero_id)
			hero.visual.set_facing(hero.last_facing)
	_rerender_hold()

## The still is drawn for a few frames after a change, then frozen.
func _rerender_hold() -> void:
	if hold_view == null:
		return
	_hold_frames = HOLD_SETTLE_FRAMES
	hold_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if grip_marker != null:
		grip_marker.queue_redraw()

func _fit_cameras() -> void:
	for pair in [[attack_view, attack_camera], [hold_view, hold_camera]]:
		var view: SubViewport = pair[0]
		var camera: Camera2D = pair[1]
		if view != null and camera != null:
			var zoom := maxf(0.5, float(view.size.y) * ZOOM_PER_PIXEL)
			if camera == hold_camera:
				zoom *= hold_zoom
				# Zoomed in, look at the hand (the weapon socket) instead of the whole hero.
				var hand: Vector2 = hold_hero.weapon_socket.position if hold_hero != null and hold_hero.weapon_socket != null else CAMERA_FOCUS
				camera.position = CAMERA_FOCUS.lerp(hand, clampf(hold_zoom - 1.0, 0.0, 1.0))
			camera.zoom = Vector2(zoom, zoom)
	if hold_zoom_label != null:
		hold_zoom_label.text = "%sx" % (str(int(hold_zoom)) if is_equal_approx(hold_zoom, roundf(hold_zoom)) else "%.1f" % hold_zoom)
	_rerender_hold()

## Zoom of the Holding preview (1 = whole hero), centred on the hand.
func set_hold_zoom(zoom: float) -> void:
	hold_zoom = clampf(zoom, 1.0, HOLD_ZOOM_MAX)
	_fit_cameras()

func _process(delta: float) -> void:
	if _hold_frames > 0 and not dragging and not walking:
		_hold_frames -= 1
		if _hold_frames == 0:
			hold_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree() or attack_hero.visual == null:
		return
	loop_clock += delta
	if loop_clock >= loop_period:
		loop_clock = fmod(loop_clock, loop_period)
		attack_hero.visual.play_attack()
		attacks_played += 1

# ---------- dragging in the Holding stage ----------

## A point in the Holding stage (container pixels) in the stage's world.
func stage_to_world(point: Vector2) -> Vector2:
	var shrink := float(maxi(1, hold_container.stretch_shrink))
	return hold_view.get_canvas_transform().affine_inverse() * (point / shrink)

func _on_hold_input(event: InputEvent) -> void:
	if not _has_weapon or hold_hero.held_weapon == null or hold_hero.held_weapon.texture == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and button.double_click:
				set_hold_zoom(1.0)
				hold_container.accept_event()
				return
			if button.pressed:
				begin_drag(button.position)
			elif dragging:
				end_drag()
			hold_container.accept_event()
		elif button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var direction := 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if button.shift_pressed:
				placement_nudged.emit("world_scale", 0.05 * direction)
			else:
				placement_nudged.emit("rotation_degrees", (1.0 if button.ctrl_pressed else 3.0) * -direction)
			hold_container.accept_event()
	elif event is InputEventMouseMotion and dragging:
		drag_to((event as InputEventMouseMotion).position)
		hold_container.accept_event()

## Starts moving the weapon; the part you grabbed stays under the mouse.
func begin_drag(point: Vector2) -> void:
	var socket: Node2D = hold_hero.weapon_socket
	dragging = true
	_drag_delta = socket.to_local(stage_to_world(point)) - hold_hero.held_weapon.position
	hold_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func drag_to(point: Vector2) -> void:
	var socket: Node2D = hold_hero.weapon_socket
	var desired := socket.to_local(stage_to_world(point)) - _drag_delta
	var offset: Vector2 = desired - hold_hero.held_weapon_base_position()
	if hold_hero.last_facing < 0:
		offset.x *= -1.0
	offset = Vector2(clampf(roundf(offset.x), -256.0, 256.0), clampf(roundf(offset.y), -256.0, 256.0))
	hold_hero.held_weapon_hand_offset = offset
	hold_hero._update_held_weapon_transform()
	grip_marker.queue_redraw()
	hand_offset_dragged.emit(offset, false)

func end_drag() -> void:
	dragging = false
	hand_offset_dragged.emit(hold_hero.held_weapon_hand_offset, true)
	_rerender_hold()

func _draw_grip_marker() -> void:
	if not _has_weapon or not (_hovering or dragging) or hold_hero.held_weapon == null or hold_hero.held_weapon.texture == null:
		return
	var point: Vector2 = hold_hero.held_weapon_grip_world_position()
	var zoom := hold_camera.zoom.x if hold_camera != null else 1.0
	var radius := 5.0 / zoom
	grip_marker.draw_arc(point, radius, 0.0, TAU, 24, GRIP, 1.5 / zoom, true)
	grip_marker.draw_line(point - Vector2(radius * 1.8, 0), point + Vector2(radius * 1.8, 0), GRIP, 1.0 / zoom)
	grip_marker.draw_line(point - Vector2(0, radius * 1.8), point + Vector2(0, radius * 1.8), GRIP, 1.0 / zoom)

# ---------- building ----------

func _stage(caption: String, node_name: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKDROP
	style.border_color = FLOOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(frame)
	var container := SubViewportContainer.new()
	container.name = node_name
	container.stretch = true
	container.custom_minimum_size = MIN_STAGE
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	var view := SubViewport.new()
	view.transparent_bg = false
	view.handle_input_locally = false
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	container.add_child(view)
	var world := Node2D.new()
	world.name = "World"
	view.add_child(world)
	var backdrop := Polygon2D.new()
	backdrop.color = BACKDROP
	backdrop.z_index = -20
	backdrop.polygon = PackedVector2Array([Vector2(-600, -600), Vector2(600, -600), Vector2(600, 600), Vector2(-600, 600)])
	world.add_child(backdrop)
	var floor_line := Line2D.new()
	floor_line.points = PackedVector2Array([Vector2(-400, FEET_Y), Vector2(400, FEET_Y)])
	floor_line.width = 1.0
	floor_line.default_color = FLOOR
	floor_line.z_index = -10
	world.add_child(floor_line)
	var hero: Node2D = HeroScript.new()
	hero.name = "Hero"
	world.add_child(hero)
	var camera := Camera2D.new()
	camera.position = CAMERA_FOCUS
	camera.zoom = Vector2(1.4, 1.4)
	world.add_child(camera)
	var note := Label.new()
	note.text = caption
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(MIN_STAGE.x, 0)
	box.add_child(note)
	return {"view": view, "hero": hero, "note": note, "camera": camera, "container": container, "box": box, "frame": frame}
