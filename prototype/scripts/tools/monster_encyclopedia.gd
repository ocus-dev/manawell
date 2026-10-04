extends CanvasLayer

## Dev Encyclopedia (was Monster Encyclopedia): developer tool for tuning
## monster stats, weapon stats (Weapons tab) and level spawns in-game.
##
## Open with F9 during an encounter (debug builds) or from the title screen.
## Edits apply immediately to MonsterStats and to monsters already in the
## arena. "Save to game data" writes res://data/monster_stats.json.

const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const BalanceData = preload("res://data/balance.gd")
const LevelSpawnsPageScript = preload("res://scripts/tools/level_spawns_page.gd")
const WeaponsPageScript = preload("res://scripts/tools/weapon_encyclopedia_page.gd")

const TOGGLE_KEY := KEY_F9
const AMBER := Color("f0a836")
const AMBER_DEEP := Color("b9761c")
const INK := Color("ece6da")
const MUTED := Color("9ba4ac")
const PLATE := Color("20252a")
const PLATE_2 := Color("2a3036")
const EDGE := Color("434c55")
## Distance from the enemy spawn point to the harvester, in world units.
const ARENA_CROSSING_UNITS := (1240.0 - 160.0) / 32.0

signal closed

## The encounter controller, or null when opened outside a run (title screen).
var controller: Node

var selected_id := "pursuer"
var preview_animation := "idle"
var preview_time := 0.0
var was_paused := false

var root: Control
var count_label: Label
var search: LineEdit
var tile_list: VBoxContainer
var tile_group := ButtonGroup.new()
var tiles: Dictionary = {}
var portrait: TextureRect
var name_label: Label
var meta_label: Label
var desc_label: Label
var anim_buttons: Dictionary = {}
var stats_box: VBoxContainer
var derived_box: HBoxContainer
var status_label: Label
var rows: Dictionary = {}
var text_dialog: AcceptDialog
var text_dialog_label: Label
var text_dialog_area: TextEdit
var text_dialog_error: Label
var text_dialog_mode := ""
var reset_all_dialog: ConfirmationDialog
## Tabs: "monsters" (stats), "weapons" (weapon logbook and stats) and
## "spawns" (which creatures each level spawns).
const TABS := [["monsters", "Monsters"], ["weapons", "Weapons"], ["spawns", "Levels"]]
var tab := "monsters"
var tab_buttons: Dictionary = {}
var monster_body: Control
var monster_footer: Control
var spawns_page: Control
var weapons_page: Control

func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root.hide()

func is_open() -> bool:
	return root != null and root.visible

func open() -> void:
	if is_open():
		return
	if controller != null:
		was_paused = controller.run_state.paused
		controller.set_experiment_paused(true)
		for field in ["move_left_held", "move_right_held", "move_down_held", "jump_held", "pending_jump", "pending_dash", "pending_pulse", "pending_harvest", "pending_pause"]:
			controller.set(field, false)
	_render_tiles()
	_render_entry()
	_set_status(_idle_status())
	root.show()
	if tab == "spawns":
		spawns_page.refresh()
	elif tab == "weapons":
		weapons_page.refresh()
	else:
		search.grab_focus()

## Switches between the monster stats, the weapon logbook and the level spawn editor.
func show_tab(tab_id: String) -> void:
	tab = tab_id
	for key in tab_buttons:
		tab_buttons[key].set_pressed_no_signal(key == tab_id)
	monster_body.visible = tab_id == "monsters"
	monster_footer.visible = tab_id == "monsters"
	spawns_page.visible = tab_id == "spawns"
	weapons_page.visible = tab_id == "weapons"
	count_label.visible = tab_id == "monsters"
	if tab_id == "spawns":
		spawns_page.refresh()
	elif tab_id == "weapons":
		weapons_page.refresh()

## Opens straight onto the weapon logbook (optionally at one weapon).
func open_weapons(weapon_id: String = "") -> void:
	open()
	show_tab("weapons")
	if not weapon_id.is_empty():
		weapons_page.select_weapon(weapon_id)

## Opens straight onto the spawn editor for `level_id` (e.g. after a preview).
func open_spawn_editor(level_id: String) -> void:
	open()
	show_tab("spawns")
	spawns_page.select_level(level_id)

func close() -> void:
	if not is_open():
		return
	root.hide()
	text_dialog.hide()
	reset_all_dialog.hide()
	if controller != null:
		_resume_controller()
	closed.emit()

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func _resume_controller() -> void:
	# Escape/F9 are still "just pressed" this frame; wait so the controller's
	# own pause polling doesn't pick them up after we unpause.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if controller == null or not is_instance_valid(controller) or is_open():
		return
	controller.pending_pause = false
	controller.set_experiment_paused(was_paused)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and is_open() and not text_dialog.visible and not reset_all_dialog.visible:
		close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_open():
		return
	preview_time += delta
	_update_portrait()

# ---------- editing ----------

func set_stat(monster_id: String, key: String, value: float) -> void:
	MonsterStatsScript.set_stat(monster_id, key, value)
	_after_change()

func select_monster(monster_id: String) -> void:
	if MonsterStatsScript.monster(monster_id).is_empty():
		return
	selected_id = monster_id
	preview_time = 0.0
	_sync_tile_selection()
	_render_entry()

func reset_selected() -> void:
	MonsterStatsScript.reset_monster(selected_id)
	_render_entry()
	_after_change()
	_set_status("%s reset to defaults. %s" % [MonsterStatsScript.monster(selected_id)["name"], _unsaved_hint()])

func reset_all() -> void:
	MonsterStatsScript.reset_all()
	_render_entry()
	_after_change()
	_set_status("All monsters reset to defaults. " + _unsaved_hint())

func save() -> Dictionary:
	var result: Dictionary = MonsterStatsScript.save_to_disk()
	if result["ok"]:
		_set_status("Saved to %s." % result["path"])
	else:
		_set_status(result["message"])
	_refresh_marks()
	return result

func _after_change() -> void:
	if controller != null and controller.has_method("apply_monster_stats"):
		controller.apply_monster_stats()
	_refresh_rows()
	_render_derived()
	_refresh_marks()
	_set_status("Applied live. " + _unsaved_hint())

func _unsaved_hint() -> String:
	if MonsterStatsScript.has_unsaved_changes():
		return "Not saved yet."
	return "Matches saved game data."

func _idle_status() -> String:
	if MonsterStatsScript.has_unsaved_changes():
		return "You have unsaved edits from this session."
	return "Edits apply to the game immediately. F9 or Esc to close."

# ---------- build ----------

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.047, 0.055, 0.063, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var book := PanelContainer.new()
	book.name = "Book"
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.offset_left = 40
	book.offset_top = 32
	book.offset_right = -40
	book.offset_bottom = -32
	book.add_theme_stylebox_override("panel", _box(PLATE, EDGE, 1, 6, 0))
	root.add_child(book)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	book.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	body.add_child(_build_index())
	body.add_child(_build_entry())
	monster_body = body
	monster_footer = _build_footer()
	column.add_child(monster_footer)
	spawns_page = LevelSpawnsPageScript.new(self)
	spawns_page.hide()
	column.add_child(spawns_page)
	weapons_page = WeaponsPageScript.new(self)
	weapons_page.hide()
	column.add_child(weapons_page)
	_build_dialogs()

func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 14, [0, 0, 0, 1]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var title := Label.new()
	title.text = "DEV ENCYCLOPEDIA"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", AMBER)
	row.add_child(title)
	var tag := Label.new()
	tag.text = "DEV TOOL"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	for tab_entry in TABS:
		var tab_id: String = tab_entry[0]
		var tab_button := _button(tab_entry[1])
		tab_button.name = "Tab_" + tab_id
		tab_button.toggle_mode = true
		tab_button.add_theme_stylebox_override("pressed", _button_box(AMBER_DEEP, AMBER))
		tab_button.pressed.connect(show_tab.bind(tab_id))
		tab_buttons[tab_id] = tab_button
		row.add_child(tab_button)
	tab_buttons["monsters"].button_pressed = true
	count_label = Label.new()
	count_label.add_theme_color_override("font_color", MUTED)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count_label)
	var close_button := _button("Close  (F9)")
	close_button.name = "Close"
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return bar

func _build_index() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 0)
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 0, 0, 14, [0, 0, 1, 0]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	search = LineEdit.new()
	search.placeholder_text = "Find a monster"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: _render_tiles())
	column.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	tile_list = VBoxContainer.new()
	tile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_list.add_theme_constant_override("separation", 8)
	scroll.add_child(tile_list)
	for entry in MonsterStatsScript.MONSTERS:
		var tile := _build_tile(entry)
		tiles[entry["id"]] = tile
		tile_list.add_child(tile)
	var empty := Label.new()
	empty.name = "Empty"
	empty.text = "No monsters match. Try a name or role."
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_theme_color_override("font_color", MUTED)
	empty.hide()
	tile_list.add_child(empty)
	return panel

func _build_tile(entry: Dictionary) -> Button:
	var id: String = entry["id"]
	var tile := Button.new()
	tile.name = "Tile_" + id
	tile.toggle_mode = true
	tile.button_group = tile_group
	tile.custom_minimum_size = Vector2(0, 76)
	tile.tooltip_text = entry["name"]
	tile.add_theme_stylebox_override("normal", _box(PLATE_2, EDGE, 1, 4, 0))
	tile.add_theme_stylebox_override("hover", _box(Color("343b42"), Color("6b747d"), 1, 4, 0))
	tile.add_theme_stylebox_override("pressed", _box(Color("2f2a20"), AMBER, 2, 4, 0))
	tile.add_theme_stylebox_override("hover_pressed", _box(Color("3a3222"), AMBER, 2, 4, 0))
	tile.pressed.connect(select_monster.bind(id))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = true
	icon.texture = sprite_texture(id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = entry["name"]
	title.add_theme_font_size_override("font_size", 17)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var role := Label.new()
	role.text = "%s · %s" % [entry["role"], entry["target"]]
	role.add_theme_font_size_override("font_size", 12)
	role.add_theme_color_override("font_color", MUTED)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(role)
	var mark := Panel.new()
	mark.name = "Edited"
	mark.tooltip_text = "Edited"
	mark.custom_minimum_size = Vector2(10, 10)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_stylebox_override("panel", _box(AMBER, AMBER, 0, 5, 0))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.hide()
	row.add_child(mark)
	return tile

func _build_entry() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	column.add_child(head)
	var portrait_column := VBoxContainer.new()
	portrait_column.add_theme_constant_override("separation", 6)
	head.add_child(portrait_column)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(190, 150)
	frame.add_theme_stylebox_override("panel", _box(Color("15181b"), EDGE, 1, 4, 8))
	portrait_column.add_child(frame)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = true
	frame.add_child(portrait)
	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 4)
	portrait_column.add_child(anim_row)
	var anim_group := ButtonGroup.new()
	for animation in ["idle", "walk", "attack"]:
		var anim_button := _button(animation.capitalize(), true)
		anim_button.toggle_mode = true
		anim_button.button_group = anim_group
		anim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		anim_button.button_pressed = animation == preview_animation
		anim_button.pressed.connect(_set_preview_animation.bind(animation))
		anim_buttons[animation] = anim_button
		anim_row.add_child(anim_button)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	head.add_child(info)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 30)
	info.add_child(name_label)
	meta_label = Label.new()
	meta_label.add_theme_color_override("font_color", AMBER)
	meta_label.add_theme_font_size_override("font_size", 14)
	info.add_child(meta_label)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color("c9c3b8"))
	desc_label.add_theme_font_size_override("font_size", 15)
	info.add_child(desc_label)
	var derived_panel := PanelContainer.new()
	derived_panel.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	derived_panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 1, 4, 12))
	info.add_child(derived_panel)
	derived_box = HBoxContainer.new()
	derived_box.add_theme_constant_override("separation", 26)
	derived_panel.add_child(derived_box)

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	column.add_child(stats_box)
	return scroll

func _build_footer() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 12, [0, 1, 0, 0]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_label)
	var reset_one := _button("Reset monster", true)
	reset_one.pressed.connect(reset_selected)
	row.add_child(reset_one)
	var reset_every := _button("Reset all", true)
	reset_every.pressed.connect(func() -> void: reset_all_dialog.popup_centered())
	row.add_child(reset_every)
	var import_button := _button("Import JSON")
	import_button.pressed.connect(_open_text_dialog.bind("import"))
	row.add_child(import_button)
	var export_button := _button("Export JSON")
	export_button.pressed.connect(_open_text_dialog.bind("export"))
	row.add_child(export_button)
	var save_button := _button("Save to game data")
	save_button.name = "Save"
	save_button.add_theme_stylebox_override("normal", _button_box(AMBER_DEEP, AMBER))
	save_button.add_theme_stylebox_override("hover", _button_box(AMBER, Color("f7bb58")))
	save_button.add_theme_color_override("font_color", Color("15181b"))
	save_button.add_theme_color_override("font_hover_color", Color("15181b"))
	save_button.pressed.connect(save)
	row.add_child(save_button)
	return bar

func _build_dialogs() -> void:
	text_dialog = AcceptDialog.new()
	text_dialog.dialog_hide_on_ok = false
	text_dialog.min_size = Vector2i(620, 460)
	text_dialog.confirmed.connect(_on_text_dialog_ok)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	text_dialog.add_child(box)
	text_dialog_label = Label.new()
	text_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text_dialog_label)
	text_dialog_area = TextEdit.new()
	text_dialog_area.custom_minimum_size = Vector2(580, 320)
	text_dialog_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_dialog_area)
	text_dialog_error = Label.new()
	text_dialog_error.add_theme_color_override("font_color", Color("e2593a"))
	box.add_child(text_dialog_error)
	root.add_child(text_dialog)

	reset_all_dialog = ConfirmationDialog.new()
	reset_all_dialog.title = "Reset all monsters"
	reset_all_dialog.dialog_text = "Reset every monster to the defaults in data/balance.gd?\nSaved game data isn't changed until you save."
	reset_all_dialog.ok_button_text = "Reset all"
	reset_all_dialog.confirmed.connect(reset_all)
	root.add_child(reset_all_dialog)

# ---------- render ----------

func _render_tiles() -> void:
	var query := search.text.strip_edges().to_lower() if search != null else ""
	var shown := 0
	for entry in MonsterStatsScript.MONSTERS:
		var haystack := ("%s %s %s" % [entry["name"], entry["role"], entry["target"]]).to_lower()
		var matches := query.is_empty() or haystack.contains(query)
		tiles[entry["id"]].visible = matches
		if matches:
			shown += 1
	tile_list.get_node("Empty").visible = shown == 0
	_sync_tile_selection()
	_refresh_marks()

func _sync_tile_selection() -> void:
	for id in tiles.keys():
		tiles[id].set_pressed_no_signal(id == selected_id)

func _render_entry() -> void:
	var entry := MonsterStatsScript.monster(selected_id)
	name_label.text = entry["name"]
	meta_label.text = "%s · %s" % [str(entry["role"]).to_upper(), str(entry["target"]).to_upper()]
	desc_label.text = entry["desc"]
	var asset := VisualConfigScript.asset_for(selected_id)
	for animation in anim_buttons.keys():
		var frames: SpriteFrames = asset.get(animation + "_frames")
		anim_buttons[animation].disabled = frames == null
	if asset.get(preview_animation + "_frames") == null:
		preview_animation = "idle"
	anim_buttons[preview_animation].set_pressed_no_signal(true)
	_update_portrait()

	for child in stats_box.get_children():
		stats_box.remove_child(child)
		child.queue_free()
	rows.clear()
	for key in MonsterStatsScript.stat_keys(selected_id):
		var row := _build_stat_row(key)
		stats_box.add_child(row)
	_refresh_rows()
	_render_derived()

func _build_stat_row(key: String) -> Control:
	var definition: Dictionary = MonsterStatsScript.STAT_DEFS[key]
	var default_value := MonsterStatsScript.default_value(selected_id, key)
	var row := HBoxContainer.new()
	row.name = "Stat_" + key
	row.add_theme_constant_override("separation", 14)

	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(230, 0)
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var label := Label.new()
	label.text = definition["label"]
	label.add_theme_font_size_override("font_size", 16)
	labels.add_child(label)
	var hint := Label.new()
	hint.text = definition["hint"]
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(230, 0)
	hint.tooltip_text = definition["hint"]
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	labels.add_child(hint)

	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 32)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var slider := HSlider.new()
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.min_value = definition["min"]
	slider.max_value = definition["max"]
	slider.step = definition["step"]
	track.add_child(slider)
	var ratio := inverse_lerp(float(definition["min"]), float(definition["max"]), default_value)
	var marker := ColorRect.new()
	marker.color = Color(0.94, 0.66, 0.21, 0.55)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.tooltip_text = "Default: %s" % _format(default_value, key)
	marker.anchor_left = ratio
	marker.anchor_right = ratio
	marker.anchor_top = 0.0
	marker.anchor_bottom = 1.0
	marker.offset_left = 8.0 - 16.0 * ratio - 1.0
	marker.offset_right = 8.0 - 16.0 * ratio + 1.0
	marker.offset_top = 4.0
	marker.offset_bottom = -4.0
	track.add_child(marker)

	var spin := SpinBox.new()
	spin.min_value = definition["min"]
	spin.max_value = definition["max"]
	spin.step = definition["step"]
	spin.custom_minimum_size = Vector2(118, 0)
	spin.select_all_on_focus = true
	row.add_child(spin)

	var undo := _button("Default", true)
	undo.custom_minimum_size = Vector2(92, 0)
	undo.tooltip_text = "Restore default (%s)" % _format(default_value, key)
	row.add_child(undo)

	slider.value_changed.connect(func(value: float) -> void: set_stat(selected_id, key, value))
	spin.value_changed.connect(func(value: float) -> void: set_stat(selected_id, key, value))
	undo.pressed.connect(func() -> void: set_stat(selected_id, key, default_value))
	rows[key] = {"row": row, "label": label, "slider": slider, "spin": spin, "undo": undo}
	return row

func _refresh_rows() -> void:
	for key in rows.keys():
		var parts: Dictionary = rows[key]
		var value := MonsterStatsScript.get_stat(selected_id, key)
		parts["slider"].set_value_no_signal(value)
		parts["spin"].set_value_no_signal(value)
		var changed := not is_equal_approx(value, MonsterStatsScript.default_value(selected_id, key))
		parts["label"].add_theme_color_override("font_color", AMBER if changed else INK)
		parts["undo"].disabled = not changed

func _render_derived() -> void:
	for child in derived_box.get_children():
		derived_box.remove_child(child)
		child.queue_free()
	var id := selected_id
	var damage := MonsterStatsScript.get_stat(id, "damage")
	var interval := MonsterStatsScript.get_stat(id, "attack_interval")
	var health := MonsterStatsScript.get_stat(id, "health")
	var speed := MonsterStatsScript.get_stat(id, "move_speed")
	var dps := damage / interval if interval > 0.0 else 0.0
	var weapon_damage := BalanceData.WEAPON_DAMAGE
	if controller != null and "weapon_damage" in controller:
		weapon_damage = maxf(0.01, float(controller.weapon_damage))
	_add_derived("Damage per second", "%.1f" % dps)
	if id == "breaker":
		_add_derived("Breaks harvester in", "%.1fs" % (BalanceData.MACHINE_INTEGRITY / dps) if dps > 0.0 else "never")
	else:
		_add_derived("Kills hero in", "%.1fs" % (BalanceData.HERO_HEALTH / dps) if dps > 0.0 else "never")
	_add_derived("Hits to kill", str(ceili(health / weapon_damage)))
	_add_derived("Crosses arena in", "%.1fs" % (ARENA_CROSSING_UNITS / speed) if speed > 0.0 else "never")

func _add_derived(caption: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var top := Label.new()
	top.text = caption
	top.add_theme_font_size_override("font_size", 12)
	top.add_theme_color_override("font_color", MUTED)
	box.add_child(top)
	var bottom := Label.new()
	bottom.text = value
	bottom.add_theme_font_size_override("font_size", 20)
	box.add_child(bottom)
	derived_box.add_child(box)

func _refresh_marks() -> void:
	for id in tiles.keys():
		tiles[id].find_child("Edited", true, false).visible = MonsterStatsScript.is_modified(id)
	var edited := MonsterStatsScript.modified_count()
	var total := MonsterStatsScript.MONSTERS.size()
	count_label.text = "%d monsters%s%s" % [total, ", %d edited" % edited if edited > 0 else "", "  ·  unsaved" if MonsterStatsScript.has_unsaved_changes() else ""]

func _set_status(text: String) -> void:
	status_label.text = text

# ---------- sprites ----------

## Static sprite cropped to its visible bounds, for list icons.
func sprite_texture(monster_id: String) -> Texture2D:
	var asset := VisualConfigScript.asset_for(monster_id)
	if asset.is_empty() or asset.get("texture") == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = asset["texture"]
	atlas.region = asset["visible_bounds"]
	return atlas

func _set_preview_animation(animation: String) -> void:
	preview_animation = animation
	preview_time = 0.0
	_update_portrait()

func _update_portrait() -> void:
	if portrait == null:
		return
	var asset := VisualConfigScript.asset_for(selected_id)
	var frames: SpriteFrames = asset.get(preview_animation + "_frames")
	var animation := StringName(preview_animation)
	if frames == null or not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		portrait.texture = sprite_texture(selected_id)
		return
	var count := frames.get_frame_count(animation)
	var fps := maxf(1.0, frames.get_animation_speed(animation))
	var index := int(preview_time * fps) % count
	portrait.texture = frames.get_frame_texture(animation, index)

# ---------- import / export ----------

func _open_text_dialog(mode: String) -> void:
	text_dialog_mode = mode
	text_dialog_error.text = ""
	if mode == "export":
		text_dialog.title = "Export monster stats"
		text_dialog_label.text = "Stats keyed by monster id. Same format as data/monster_stats.json."
		text_dialog_area.text = MonsterStatsScript.to_json()
		text_dialog_area.editable = false
		text_dialog.ok_button_text = "Copy to clipboard"
	else:
		text_dialog.title = "Import monster stats"
		text_dialog_label.text = "Paste JSON exported from this tool. Unknown monsters and stats are ignored; values are clamped to the slider ranges."
		text_dialog_area.text = ""
		text_dialog_area.editable = true
		text_dialog.ok_button_text = "Import"
	text_dialog.popup_centered()
	text_dialog_area.grab_focus()

func _on_text_dialog_ok() -> void:
	if text_dialog_mode == "export":
		DisplayServer.clipboard_set(text_dialog_area.text)
		text_dialog.ok_button_text = "Copied"
		return
	var message := import_json(text_dialog_area.text)
	if message.is_empty():
		text_dialog.hide()
	else:
		text_dialog_error.text = message

## Returns an empty string on success, or an error message.
func import_json(text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK:
		return "That isn't valid JSON (line %d: %s)." % [json.get_error_line() + 1, json.get_error_message()]
	if typeof(json.data) != TYPE_DICTIONARY:
		return "Expected a JSON object keyed by monster id."
	var applied := MonsterStatsScript.apply_map(json.data)
	if applied == 0:
		return "No known monster stats found in that JSON."
	_render_entry()
	_after_change()
	_set_status("Imported %d values. %s" % [applied, _unsaved_hint()])
	return ""

# ---------- helpers ----------

func _format(value: float, key: String) -> String:
	var step := float(MonsterStatsScript.STAT_DEFS[key]["step"])
	return str(int(value)) if is_equal_approx(step, roundf(step)) else ("%.2f" % value).rstrip("0").rstrip(".")

func _button(text: String, ghost: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	if ghost:
		button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0), EDGE))
	return button

func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _box(fill, border, 1, 3, 0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _theme() -> Theme:
	var theme: Theme = IndustrialThemeScript.create()
	theme.set_constant("separation", "BoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	var button := _button_box(Color("26313a"), Color("50606b"))
	theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate()
	hover.bg_color = Color("34434d")
	hover.border_color = AMBER
	theme.set_stylebox("hover", "Button", hover)
	var pressed := button.duplicate()
	pressed.bg_color = AMBER_DEEP
	pressed.border_color = AMBER
	theme.set_stylebox("pressed", "Button", pressed)
	var disabled := button.duplicate()
	disabled.bg_color = Color("1b2026")
	disabled.border_color = Color("323942")
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 2, 4, 0))
	var field := _box(Color("15181b"), EDGE, 1, 3, 0)
	field.content_margin_left = 10
	field.content_margin_right = 10
	field.content_margin_top = 6
	field.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), AMBER, 2, 3, 0))
	theme.set_color("font_color", "Label", INK)
	return theme

func _box(fill: Color, border: Color, border_width: int, radius: int, padding: float, borders: Array = []) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	if borders.size() == 4:
		style.border_width_left = int(borders[0]) * maxi(1, border_width)
		style.border_width_top = int(borders[1]) * maxi(1, border_width)
		style.border_width_right = int(borders[2]) * maxi(1, border_width)
		style.border_width_bottom = int(borders[3]) * maxi(1, border_width)
	else:
		style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
