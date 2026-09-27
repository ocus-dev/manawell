extends VBoxContainer

## "Effects" section of the Weapon Lab: flipbooks attached to the weapon and
## when in the swing each one fires. Up to WeaponEffects.MAX_EFFECTS.

signal changed
## The lab should treat the next click on the world sprite as the anchor.
signal pick_anchor_requested

const WeaponEffects = preload("res://scripts/model/weapon_effects.gd")
const EffectArt = preload("res://scripts/tools/weapon_effect_art.gd")

const AMBER := Color("f0a836")
const MUTED := Color("9ba4ac")
const BAD := Color("f09a9a")

var effects: Array = []
var selected := -1
var weapon_id := ""
var picking_anchor := false
var preview_time := 0.0

var _loading := false
var _list: VBoxContainer
var _kind_picker: OptionButton
var _color_picker: ColorPickerButton
var _editor: GridContainer
var _fields: Dictionary = {}
var _thumb: Control
var _thumb_texture: Texture2D
var _status: Label
var _sheet_dialog: FileDialog
var _frames_dialog: FileDialog
var _pick_button: Button
var _remove_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build()
	_render()

func _process(delta: float) -> void:
	if _thumb != null and is_visible_in_tree():
		preview_time += delta
		_thumb.queue_redraw()

# ---------- data ----------

func set_effects(new_effects: Array, new_weapon_id: String = "") -> void:
	effects = []
	for effect in new_effects:
		if effect is Dictionary:
			effects.append(effect.duplicate(true))
	weapon_id = new_weapon_id
	selected = 0 if not effects.is_empty() else -1
	picking_anchor = false
	if is_inside_tree():
		_render()

func get_effects() -> Array:
	return effects.duplicate(true)

func selected_effect() -> Dictionary:
	return effects[selected] if selected >= 0 and selected < effects.size() else {}

func add_effect(effect: Dictionary) -> bool:
	if effect.is_empty():
		_set_status("Couldn't create that effect.", BAD)
		return false
	if effects.size() >= WeaponEffects.MAX_EFFECTS:
		_set_status("A weapon can have up to %d effects. Remove one first." % WeaponEffects.MAX_EFFECTS, BAD)
		return false
	effects.append(effect)
	selected = effects.size() - 1
	_render()
	changed.emit()
	_set_status("Added %s. It fires on \"%s\"." % [str(effect.get("label", "effect")), WeaponEffects.TRIGGER_LABELS.get(str(effect.get("trigger", "hit")), "")])
	return true

func generate(kind: String) -> bool:
	var color := _color_picker.color if _color_picker != null and _color_picker.has_meta("chosen") else Color(0, 0, 0, 0)
	return add_effect(EffectArt.generate_effect(kind, weapon_id, color))

func remove_selected() -> void:
	if selected < 0 or selected >= effects.size():
		return
	effects.remove_at(selected)
	selected = mini(selected, effects.size() - 1)
	_render()
	changed.emit()

func set_selected_anchor(anchor: Vector2) -> void:
	if selected < 0:
		return
	effects[selected]["anchor"] = [snappedf(clampf(anchor.x, 0.0, 1.0), 0.01), snappedf(clampf(anchor.y, 0.0, 1.0), 0.01)]
	picking_anchor = false
	_render_editor()
	changed.emit()
	_set_status("Anchor set.")

func import_sheet(path: String) -> bool:
	var frames := int(_fields["import_frames"].value) if _fields.has("import_frames") else 8
	return add_effect(EffectArt.import_sheet(path, weapon_id, frames, int(_fields["import_columns"].value) if _fields.has("import_columns") else 0))

func import_frames(paths: PackedStringArray) -> bool:
	return add_effect(EffectArt.import_frames(paths, weapon_id))

# ---------- UI ----------

func _build() -> void:
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	add_child(add_row)
	_kind_picker = OptionButton.new()
	_kind_picker.name = "EffectKind"
	for kind in EffectArt.KIND_ORDER:
		_kind_picker.add_item(str(EffectArt.KINDS[kind]["label"]))
		_kind_picker.set_item_metadata(_kind_picker.item_count - 1, kind)
	add_row.add_child(_kind_picker)
	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(40, 0)
	_color_picker.color = EffectArt.KINDS["slash_arc"]["color"]
	_color_picker.tooltip_text = "Tint for generated effects"
	_color_picker.color_changed.connect(func(_c: Color) -> void: _color_picker.set_meta("chosen", true))
	add_row.add_child(_color_picker)
	var generate_button := _button("Generate")
	generate_button.name = "GenerateEffect"
	generate_button.tooltip_text = "Makes a built-in flipbook so you can try effects before you have art."
	generate_button.pressed.connect(func() -> void: generate(str(_kind_picker.get_item_metadata(maxi(0, _kind_picker.selected)))))
	add_row.add_child(generate_button)
	var sheet_button := _button("Import sprite sheet...")
	sheet_button.tooltip_text = "A single PNG with all frames. Set the frame count and columns below first."
	sheet_button.pressed.connect(func() -> void: _sheet_dialog.popup_centered_ratio(0.7))
	add_row.add_child(sheet_button)
	var frames_button := _button("Import frames...")
	frames_button.tooltip_text = "Pick several PNGs (one per frame, e.g. frames from a ComfyUI video). They're packed into one strip in file-name order."
	frames_button.pressed.connect(func() -> void: _frames_dialog.popup_centered_ratio(0.7))
	add_row.add_child(frames_button)
	var import_row := HBoxContainer.new()
	import_row.add_theme_constant_override("separation", 6)
	add_child(import_row)
	import_row.add_child(_caption("Sprite sheet layout for import:"))
	_fields["import_frames"] = _spin(1, 64, 1, 8)
	import_row.add_child(_caption("frames"))
	import_row.add_child(_fields["import_frames"])
	_fields["import_columns"] = _spin(0, 64, 1, 0)
	_fields["import_columns"].tooltip_text = "0 = one row"
	import_row.add_child(_caption("columns"))
	import_row.add_child(_fields["import_columns"])
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(190, 0)
	body.add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	left.add_child(_list)
	_thumb = Control.new()
	_thumb.name = "EffectThumb"
	_thumb.custom_minimum_size = Vector2(190, 150)
	_thumb.draw.connect(_draw_thumb)
	left.add_child(_thumb)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_editor = GridContainer.new()
	_editor.columns = 4
	_editor.add_theme_constant_override("h_separation", 8)
	_editor.add_theme_constant_override("v_separation", 4)
	right.add_child(_editor)
	_line_field("label", "Name", "What this effect is called in the lab.")
	_option_field("trigger", "Fires at", WeaponEffects.TRIGGERS, WeaponEffects.TRIGGER_LABELS, "The moment in the attack the flipbook starts. \"Hit\" follows the melee damage timing (40% of the attack interval); for ranged weapons it's when the shot fires.")
	_number_field("at", "Custom point", 0.0, 1.0, 0.01, "For \"Custom point in the swing\": 0 = start, 1 = end of the swing.")
	_number_field("fps", "Speed (fps)", 1.0, 60.0, 1.0, "Frames per second. frames / fps = how long it plays.")
	_number_field("frame_count", "Frames", 1, 64, 1, "How many frames are in the sheet.")
	_number_field("columns", "Columns", 1, 64, 1, "Frames per row in the sheet. Same as Frames for a single strip.")
	_number_field("size", "Size (px)", 4.0, 1024.0, 1.0, "On-screen size of the frame's longer side. The held weapon is about 96 px.")
	_number_field("rotation", "Rotation", -360.0, 360.0, 1.0, "Extra turn in degrees.")
	_number_field("anchor_x", "Anchor X", 0.0, 1.0, 0.01, "Where on the weapon image it plays (0 = left edge, 1 = right edge). Use Pick on sprite.")
	_number_field("anchor_y", "Anchor Y", 0.0, 1.0, 0.01, "0 = top edge, 1 = bottom edge of the weapon image.")
	_number_field("offset_x", "Offset X", -256.0, 256.0, 1.0, "Extra pixels along the hero's facing.")
	_number_field("offset_y", "Offset Y", -256.0, 256.0, 1.0, "Extra pixels down (negative is up).")
	_number_field("opacity", "Opacity", 0.0, 1.0, 0.05, "")
	_check_field("follow", "Rides on the weapon", "On: moves and turns with the weapon (trails, glows). Off: stays where it fired (impacts, sparks).")
	_check_field("align", "Turns with the weapon", "On: rotated to match the weapon when it fires. Off: always upright.")
	_check_field("additive", "Glow (add blend)", "Adds light, good for energy, fire and sparks. Off: normal painted look.")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	right.add_child(actions)
	_pick_button = _button("Pick anchor on sprite")
	_pick_button.tooltip_text = "Then click the world sprite in section 1 (ART)."
	_pick_button.pressed.connect(func() -> void:
		picking_anchor = true
		pick_anchor_requested.emit()
		_set_status("Click the world sprite in section 1 to place this effect."))
	actions.add_child(_pick_button)
	_remove_button = _button("Remove effect")
	_remove_button.add_theme_color_override("font_color", BAD)
	_remove_button.pressed.connect(remove_selected)
	actions.add_child(_remove_button)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_sheet_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Import an effect sprite sheet")
	_sheet_dialog.file_selected.connect(func(path: String) -> void: import_sheet(path))
	_frames_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILES, "Import effect frames")
	_frames_dialog.files_selected.connect(func(paths: PackedStringArray) -> void: import_frames(paths))

func _render() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	for index in range(effects.size()):
		var effect: Dictionary = effects[index]
		var row := Button.new()
		row.toggle_mode = true
		row.button_pressed = index == selected
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.text = "%s\n%s" % [str(effect.get("label", "Effect")), WeaponEffects.TRIGGER_LABELS.get(str(effect.get("trigger", "hit")), "")]
		row.clip_text = true
		row.add_theme_font_size_override("font_size", 13)
		var effect_index := index
		row.pressed.connect(func() -> void:
			selected = effect_index
			_render())
		_list.add_child(row)
	if effects.is_empty():
		_list.add_child(_caption("No effects yet. Generate one or import art."))
	_render_editor()

func _render_editor() -> void:
	var effect := selected_effect()
	_editor.visible = not effect.is_empty()
	_pick_button.visible = not effect.is_empty()
	_remove_button.visible = not effect.is_empty()
	_thumb_texture = WeaponEffects.load_sheet(WeaponEffects.sheet_path(effect)) if not effect.is_empty() else null
	preview_time = 0.0
	if effect.is_empty():
		return
	var values := WeaponEffects.normalize(effect)
	_loading = true
	_fields["label"].text = str(values.label)
	var trigger_index := WeaponEffects.TRIGGERS.find(str(values.trigger))
	_fields["trigger"].select(maxi(0, trigger_index))
	for key in ["at", "fps", "frame_count", "columns", "size", "rotation", "opacity"]:
		_fields[key].value = float(values[key])
	_fields["anchor_x"].value = float(values.anchor[0])
	_fields["anchor_y"].value = float(values.anchor[1])
	_fields["offset_x"].value = float(values.offset[0])
	_fields["offset_y"].value = float(values.offset[1])
	for key in ["follow", "align", "additive"]:
		_fields[key].button_pressed = bool(values[key])
	_fields["at"].editable = str(values.trigger) == "custom"
	_loading = false

func _on_field_changed(key: String, value: Variant) -> void:
	if _loading or selected < 0:
		return
	var effect: Dictionary = effects[selected]
	match key:
		"anchor_x":
			effect["anchor"] = [float(value), float(WeaponEffects.normalize(effect).anchor[1])]
		"anchor_y":
			effect["anchor"] = [float(WeaponEffects.normalize(effect).anchor[0]), float(value)]
		"offset_x":
			effect["offset"] = [float(value), float(WeaponEffects.normalize(effect).offset[1])]
		"offset_y":
			effect["offset"] = [float(WeaponEffects.normalize(effect).offset[0]), float(value)]
		"frame_count", "columns":
			effect[key] = int(value)
		_:
			effect[key] = value
	if key == "trigger":
		_fields["at"].editable = str(value) == "custom"
		_render()
	elif key == "label":
		_render_list_labels()
	changed.emit()

func _render_list_labels() -> void:
	var index := 0
	for child in _list.get_children():
		if child is Button and index < effects.size():
			child.text = "%s\n%s" % [str(effects[index].get("label", "Effect")), WeaponEffects.TRIGGER_LABELS.get(str(effects[index].get("trigger", "hit")), "")]
			index += 1

func _draw_thumb() -> void:
	var rect := Rect2(Vector2.ZERO, _thumb.size)
	_thumb.draw_rect(rect, Color("0f1215"), true)
	var effect := selected_effect()
	if effect.is_empty() or _thumb_texture == null:
		return
	var values := WeaponEffects.normalize(effect)
	var length := WeaponEffects.play_length(values)
	var loop := length + 0.3
	var t := fmod(preview_time, loop)
	if t > length:
		return
	var frame := clampi(int(t * float(values.fps)), 0, int(values.frame_count) - 1)
	var cell := WeaponEffects.frame_rect(values, Vector2(_thumb_texture.get_size()), frame)
	var fit := minf((rect.size.x - 8.0) / cell.size.x, (rect.size.y - 8.0) / cell.size.y)
	var draw_size := cell.size * fit
	_thumb.draw_texture_rect_region(_thumb_texture, Rect2((rect.size - draw_size) * 0.5, draw_size), cell, Color(1, 1, 1, float(values.opacity)))
	_thumb.draw_string(ThemeDB.fallback_font, Vector2(6, rect.size.y - 6), "frame %d / %d" % [frame + 1, int(values.frame_count)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

func _set_status(text: String, color: Color = MUTED) -> void:
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", color)

# ---------- widgets ----------

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	return button

func _spin(minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(88, 0)
	return spin

func _labeled(caption: String, control: Control, tooltip: String) -> void:
	var label := _caption(caption)
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	control.tooltip_text = tooltip
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.add_child(label)
	_editor.add_child(control)
	_fields[control.get_meta("key")] = control

func _number_field(key: String, caption: String, minimum: float, maximum: float, step: float, tooltip: String) -> void:
	var spin := _spin(minimum, maximum, step, minimum)
	spin.set_meta("key", key)
	spin.value_changed.connect(func(value: float) -> void: _on_field_changed(key, value))
	_labeled(caption, spin, tooltip)

func _line_field(key: String, caption: String, tooltip: String) -> void:
	var line := LineEdit.new()
	line.set_meta("key", key)
	line.text_changed.connect(func(value: String) -> void: _on_field_changed(key, value))
	_labeled(caption, line, tooltip)

func _option_field(key: String, caption: String, values: Array, labels: Dictionary, tooltip: String) -> void:
	var option := OptionButton.new()
	option.set_meta("key", key)
	for value in values:
		option.add_item(str(labels.get(value, value)))
	option.item_selected.connect(func(index: int) -> void: _on_field_changed(key, values[index]))
	_labeled(caption, option, tooltip)

func _check_field(key: String, caption: String, tooltip: String) -> void:
	var box := CheckBox.new()
	box.text = caption
	box.set_meta("key", key)
	box.tooltip_text = tooltip
	box.add_theme_font_size_override("font_size", 13)
	box.toggled.connect(func(on: bool) -> void: _on_field_changed(key, on))
	_editor.add_child(box)
	_fields[key] = box

func _file_dialog(mode: int, title: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = title
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	add_child(dialog)
	return dialog
