class_name WeaponPlacementEditor
extends Control

signal save_requested(pivot: Dictionary)

var controller: Node
var hero: Node
var weapon_id := ""
var weapon_texture: Texture2D
var grip_x: SpinBox
var grip_y: SpinBox
var world_scale: SpinBox
var weapon_rotation: SpinBox
var hand_offset_x: SpinBox
var hand_offset_y: SpinBox
var facing: OptionButton
var feedback: Label
var status: Label
var panel: PanelContainer
var dragging := false
var drag_pointer_delta := Vector2.ZERO

func configure(new_controller: Node, new_weapon_id: String, revision: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	controller = new_controller
	hero = controller.get("hero")
	weapon_id = new_weapon_id
	var assets: Dictionary = revision.get("assets", {})
	weapon_texture = load(str(assets.get("world_sprite", ""))) as Texture2D
	var pivot: Dictionary = revision.get("pivot", {})
	_build_panel(pivot)
	_apply_preview()
	queue_redraw()

func _build_panel(pivot: Dictionary) -> void:
	panel = PanelContainer.new()
	panel.name = "PlacementPanel"
	panel.position = Vector2(918.0, 72.0)
	panel.size = Vector2(340.0, 570.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "WEAPON PLACEMENT"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s · live playtest preview" % weapon_id
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var instructions := Label.new()
	instructions.text = "Drag the weapon box relative to the hero. Grip stays unchanged; fine-tune all values below."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	grip_x = _spin(float(pivot.get("grip", [0.5, 0.75])[0]), 0.0, 1.0, 0.01)
	column.add_child(_field_row("Image grip X · 0–1", grip_x))
	grip_y = _spin(float(pivot.get("grip", [0.5, 0.75])[1]), 0.0, 1.0, 0.01)
	column.add_child(_field_row("Image grip Y · 0–1", grip_y))
	world_scale = _spin(float(pivot.get("world_scale", 1.0)), 0.1, 4.0, 0.05)
	column.add_child(_field_row("Scale", world_scale))
	weapon_rotation = _spin(float(pivot.get("rotation_degrees", 0.0)), -180.0, 180.0, 1.0)
	column.add_child(_field_row("Rotation · degrees", weapon_rotation))
	var hand_offset: Array = pivot.get("hand_offset", [0.0, 0.0])
	hand_offset_x = _spin(float(hand_offset[0]), -256.0, 256.0, 1.0)
	column.add_child(_field_row("Placement X · pixels", hand_offset_x))
	hand_offset_y = _spin(float(hand_offset[1]), -256.0, 256.0, 1.0)
	column.add_child(_field_row("Placement Y · pixels", hand_offset_y))
	facing = OptionButton.new()
	facing.name = "Facing"
	facing.add_item("right")
	facing.add_item("left")
	facing.select(1 if str(pivot.get("facing", "right")) == "left" else 0)
	facing.item_selected.connect(func(_index: int): _apply_preview())
	column.add_child(_field_row("Art faces", facing))
	feedback = Label.new()
	feedback.name = "PlacementFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 58
	column.add_child(feedback)
	status = Label.new()
	status.name = "PlacementStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var save := Button.new()
	save.name = "SavePlacement"
	save.text = "Save Placement"
	save.tooltip_text = "Publishes a new immutable weapon revision with these placement values."
	save.pressed.connect(func(): save_requested.emit(current_pivot()))
	column.add_child(save)
	for spin in [grip_x, grip_y, world_scale, weapon_rotation, hand_offset_x, hand_offset_y]:
		spin.value_changed.connect(func(_value: float): _apply_preview())

func _field_row(label_text: String, field: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 164.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.x = 130.0
	row.add_child(label)
	row.add_child(field)
	return row

func _spin(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = clampf(value, minimum, maximum)
	spin.custom_minimum_size.x = 130.0
	return spin

func set_placement(revision: Dictionary) -> void:
	var pivot: Dictionary = revision.get("pivot", {})
	var assets: Dictionary = revision.get("assets", {})
	weapon_texture = load(str(assets.get("world_sprite", ""))) as Texture2D
	grip_x.value = float(pivot.get("grip", [0.5, 0.75])[0])
	grip_y.value = float(pivot.get("grip", [0.5, 0.75])[1])
	world_scale.value = float(pivot.get("world_scale", 1.0))
	weapon_rotation.value = float(pivot.get("rotation_degrees", 0.0))
	var hand_offset: Array = pivot.get("hand_offset", [0.0, 0.0])
	hand_offset_x.value = clampf(float(hand_offset[0]), -256.0, 256.0)
	hand_offset_y.value = clampf(float(hand_offset[1]), -256.0, 256.0)
	facing.select(1 if str(pivot.get("facing", "right")) == "left" else 0)
	_apply_preview()

func current_pivot() -> Dictionary:
	return {"coordinate_space": "normalized", "origin": "top_left", "grip": [float(grip_x.value), float(grip_y.value)], "facing": facing.get_item_text(facing.selected), "world_scale": float(world_scale.value), "rotation_degrees": float(weapon_rotation.value), "hand_offset": [float(hand_offset_x.value), float(hand_offset_y.value)]}

func set_status(message: String, is_error: bool = false) -> void:
	status.text = message
	status.modulate = Color("f09a9a") if is_error else Color("75d5a5")

func _apply_preview() -> void:
	if hero == null or weapon_texture == null:
		return
	var pivot := current_pivot()
	hero.configure_held_weapon(weapon_texture, Vector2(float(pivot.grip[0]), float(pivot.grip[1])), str(pivot.facing), float(pivot.world_scale), float(pivot.rotation_degrees), Vector2(float(pivot.hand_offset[0]), float(pivot.hand_offset[1])))
	_update_feedback()
	queue_redraw()

func _update_feedback() -> void:
	if feedback == null or hero == null:
		return
	var socket: Node2D = hero.get("weapon_socket")
	var bounds: Rect2 = hero.held_weapon_world_rect()
	var grip: Vector2 = hero.held_weapon_grip_world_position()
	feedback.text = "Hand socket: (%.1f, %.1f)\nWeapon bounds: %.1f × %.1f px\nPlacement offset: %.1f px" % [socket.global_position.x, socket.global_position.y, bounds.size.x, bounds.size.y, grip.distance_to(socket.global_position)]

func _process(_delta: float) -> void:
	if hero != null:
		_update_feedback()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if panel != null and panel.get_global_rect().has_point(event.position):
			return
		if event.pressed:
			if hero != null and hero.held_weapon_world_rect().grow(4.0).has_point(event.position):
				dragging = true
				var socket: Node2D = hero.get("weapon_socket")
				drag_pointer_delta = socket.to_local(event.position) - hero.held_weapon.position
				set_status("Dragging weapon placement. Release to keep the new hero-relative offset.")
				get_viewport().set_input_as_handled()
			else:
				dragging = false
		else:
			dragging = false
		return
	if event is InputEventMouseMotion and dragging:
		_update_hand_offset_from_drag(event.position)
		get_viewport().set_input_as_handled()

func _update_hand_offset_from_drag(point: Vector2) -> void:
	if hero == null or not is_instance_valid(hero.held_weapon):
		return
	var socket: Node2D = hero.get("weapon_socket")
	var desired_position := socket.to_local(point) - drag_pointer_delta
	var offset: Vector2 = desired_position - hero.held_weapon_base_position()
	if int(hero.get("last_facing")) < 0:
		offset.x *= -1.0
	hand_offset_x.value = clampf(offset.x, -256.0, 256.0)
	hand_offset_y.value = clampf(offset.y, -256.0, 256.0)
	_apply_preview()

func set_hand_offset_from_world_point(point: Vector2) -> bool:
	if hero == null or weapon_texture == null or not is_instance_valid(hero.held_weapon):
		return false
	var socket: Node2D = hero.get("weapon_socket")
	var offset: Vector2 = socket.to_local(point) - hero.held_weapon_base_position()
	if int(hero.get("last_facing")) < 0:
		offset.x *= -1.0
	hand_offset_x.value = clampf(offset.x, -256.0, 256.0)
	hand_offset_y.value = clampf(offset.y, -256.0, 256.0)
	_apply_preview()
	return true

func set_grip_from_world_point(point: Vector2) -> bool:
	if hero == null or weapon_texture == null or not is_instance_valid(hero.held_weapon):
		return false
	if not hero.held_weapon_world_rect().grow(4.0).has_point(point):
		return false
	var texture_size := Vector2(weapon_texture.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var local_point: Vector2 = hero.held_weapon.to_local(point)
	var normalized := Vector2(local_point.x / texture_size.x + 0.5, local_point.y / texture_size.y + 0.5)
	grip_x.value = clampf(normalized.x, 0.0, 1.0)
	grip_y.value = clampf(normalized.y, 0.0, 1.0)
	_apply_preview()
	set_status("Grip snapped to the selected point. Save Placement when it looks right.")
	return true

func _draw() -> void:
	if hero == null:
		return
	var socket: Node2D = hero.get("weapon_socket")
	var point := socket.global_position
	var hero_bounds: Rect2 = hero.hero_world_rect()
	if hero_bounds.size.x > 0.0 and hero_bounds.size.y > 0.0:
		draw_rect(hero_bounds, Color("70b7e8", 0.7), false, 1.5)
	draw_circle(point, 8.0, Color("69d9d0"), false, 2.0)
	draw_line(point - Vector2(18.0, 0.0), point + Vector2(18.0, 0.0), Color("69d9d0"), 1.5)
	draw_line(point - Vector2(0.0, 18.0), point + Vector2(0.0, 18.0), Color("69d9d0"), 1.5)
	var bounds: Rect2 = hero.held_weapon_world_rect()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		draw_rect(bounds, Color("e9bd5f", 0.75), false, 1.5)
		draw_line(point, bounds.get_center(), Color("e9bd5f", 0.65), 1.0)
		draw_line(hero_bounds.get_center(), bounds.get_center(), Color("c995e8", 0.7), 1.0)
