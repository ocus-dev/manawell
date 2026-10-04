extends HBoxContainer

## Dev Encyclopedia > Level spawns: pick a level (the tutorial area included),
## choose which encyclopedia creatures spawn there and how often, save it to
## the game data, or Preview it live.

const LevelSpawnsScript = preload("res://scripts/model/level_spawns.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const GameFlowScript = preload("res://scripts/model/game_flow.gd")
const CreatureRegistryScript = preload("res://scripts/model/creature_registry.gd")

const MAIN_SCENE := "res://scenes/main.tscn"
## Width of the label column, so every slider lines up.
const LABEL_WIDTH := 250.0
const MODE_LABELS := {
	LevelSpawnsScript.MODE_DEFAULT: "Game default",
	LevelSpawnsScript.MODE_CUSTOM: "Custom",
	LevelSpawnsScript.MODE_NONE: "No monsters",
}

## The encyclopedia (for its colours, button styles and monster portraits).
var book: Node
var selected_level := LevelSpawnsScript.TUTORIAL_ID
var level_buttons: Dictionary = {}
var level_group := ButtonGroup.new()
var mode_buttons: Dictionary = {}
var mode_group := ButtonGroup.new()
var level_title: Label
var level_meta: Label
var custom_box: VBoxContainer
var mode_note: Label
var summary_label: Label
var setting_rows: Dictionary = {}
var mix_rows: Dictionary = {}
var status_label: Label
var progress_box: VBoxContainer
var progress_summary: Label
var boss_picker: OptionButton
var boss_rows: Array[Control] = []
## Creature rows: built-ins, then Creature Lab creatures (rebuilt when the
## encyclopedia's monsters change).
var mix_list: VBoxContainer
var mix_filter: LineEdit
var _row_ids: Array = []
var _syncing := false

func _init(encyclopedia: Node) -> void:
	book = encyclopedia
	name = "LevelSpawnsPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	add_child(_build_level_list())
	add_child(_build_editor())

# ---------- editing ----------

func select_level(level_id: String) -> void:
	selected_level = level_id
	if level_buttons.has(level_id):
		level_buttons[level_id].button_pressed = true
	refresh()

func set_mode(mode: String) -> void:
	LevelSpawnsScript.set_mode(selected_level, mode)
	_after_change()

func set_setting(key: String, value: float) -> void:
	if _syncing:
		return
	LevelSpawnsScript.set_value(selected_level, key, value)
	_after_change()

func set_weight(monster_id: String, value: float) -> void:
	if _syncing:
		return
	LevelSpawnsScript.set_weight(selected_level, monster_id, value)
	_after_change()

func set_boss_monster(monster_id: String) -> void:
	if _syncing:
		return
	LevelSpawnsScript.set_boss_monster(selected_level, monster_id)
	_after_change()

func reset_level() -> void:
	LevelSpawnsScript.reset_level(selected_level)
	_after_change()
	_set_status("%s is back to its default." % LevelSpawnsScript.level_name(selected_level))

func save() -> Dictionary:
	var result: Dictionary = LevelSpawnsScript.save_to_disk()
	_set_status(str(result.message))
	_refresh_level_list()
	return result

## Opens the selected level in the game with these settings. Nothing is saved
## to the player's profile; pausing offers "Back to spawn editor".
func preview() -> void:
	GameFlowScript.preview_level_id = selected_level
	GameFlowScript.preview_profile = LevelSpawnsScript.profile(selected_level)
	var controller: Node = book.get("controller")
	if controller != null and is_instance_valid(controller) and controller.has_method("_save_account") and bool(controller.get("persistence_enabled")):
		# Leaving a real run: checkpoint it so PLAY resumes it afterwards.
		var phase: int = int(controller.run_state.phase)
		controller._save_account(controller._capture_snapshot() if phase == 1 or phase == 2 else {})
	book.call("close")
	get_tree().change_scene_to_file(MAIN_SCENE)

func _after_change() -> void:
	# Edits apply straight away to a run of this level that's open behind the book.
	var controller: Node = book.get("controller")
	if controller != null and is_instance_valid(controller) and controller.has_method("current_level_id") and controller.current_level_id() == selected_level:
		controller.load_spawn_profile()
	refresh()
	_set_status("Applied. " + ("Not saved yet." if LevelSpawnsScript.has_unsaved_changes() else "Matches saved game data."))

# ---------- view ----------

func refresh() -> void:
	_sync_monster_rows()
	_syncing = true
	var profile := LevelSpawnsScript.profile(selected_level)
	var entry := _level_entry(selected_level)
	level_title.text = str(entry.get("name", selected_level))
	level_title.tooltip_text = "%s · %s" % [str(entry.get("type", "")), selected_level]
	level_meta.text = "%s  ·  %s" % [str(entry.get("type", "")).to_upper(), selected_level]
	var mode := str(profile.mode)
	if mode_buttons.has(mode):
		mode_buttons[mode].button_pressed = true
	custom_box.visible = mode == LevelSpawnsScript.MODE_CUSTOM
	mode_note.visible = mode != LevelSpawnsScript.MODE_CUSTOM
	mode_note.text = "The game's built-in spawning: %s first, then %s and %s join as surges build, getting faster from surge 4." % [MonsterStatsScript.monster("pursuer").name, MonsterStatsScript.monster("breaker").name, MonsterStatsScript.monster("ranged").name] + " Pick Custom to set this level's own rate and creatures (Creature Lab creatures only spawn in Custom levels, or as the boss)." if mode == LevelSpawnsScript.MODE_DEFAULT else "Nothing spawns on this level. Pick Custom to add creatures."
	for key in setting_rows:
		setting_rows[key].slider.value = float(profile[key])
		setting_rows[key].spin.value = float(profile[key])
	var shares := LevelSpawnsScript.shares(profile)
	for monster_id in mix_rows:
		var weight := float(profile.mix.get(monster_id, 0.0))
		mix_rows[monster_id].slider.value = weight
		mix_rows[monster_id].share.text = "%d%%" % roundi(float(shares.get(monster_id, 0.0)) * 100.0)
	summary_label.text = LevelSpawnsScript.describe(profile)
	summary_label.visible = mode == LevelSpawnsScript.MODE_CUSTOM
	var gated := int(profile.progress_surge) > 0
	for row in boss_rows:
		row.visible = gated
	var boss := LevelSpawnsScript.boss_monster(profile)
	for index in boss_picker.item_count:
		if str(boss_picker.get_item_metadata(index)) == boss:
			boss_picker.select(index)
	progress_summary.text = LevelSpawnsScript.describe_progress(profile)
	_refresh_level_list()
	_syncing = false

func _refresh_level_list() -> void:
	for level_id in level_buttons:
		var profile := LevelSpawnsScript.profile(level_id)
		var tag: Label = level_buttons[level_id].get_node("Row/Mode")
		var gate := int(profile.get("progress_surge", 0))
		tag.text = str(MODE_LABELS.get(str(profile.mode), "")) + ("  ·  boss at surge %d" % gate if gate > 0 else "  ·  no boss") + ("  •" if LevelSpawnsScript.is_modified(level_id) else "")

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _level_entry(level_id: String) -> Dictionary:
	for entry in LevelSpawnsScript.levels():
		if entry.id == level_id:
			return entry
	return {"id": level_id, "name": level_id, "type": ""}

# ---------- build ----------

func _build_level_list() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 0)
	panel.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 0, 0, 14, [0, 0, 1, 0]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "LEVELS"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", book.MUTED)
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for entry in LevelSpawnsScript.levels():
		var button := Button.new()
		button.name = "Level_" + str(entry.id)
		button.toggle_mode = true
		button.button_group = level_group
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_stylebox_override("normal", book._box(book.PLATE_2, book.EDGE, 1, 4, 0))
		button.add_theme_stylebox_override("pressed", book._box(Color("3a2f1c"), book.AMBER, 2, 4, 0))
		button.add_theme_stylebox_override("hover", book._box(Color("2f363d"), book.AMBER_DEEP, 1, 4, 0))
		var row := VBoxContainer.new()
		row.name = "Row"
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_top = 6
		row.offset_right = -10
		row.offset_bottom = -6
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var title := Label.new()
		title.text = str(entry.name)
		title.add_theme_font_size_override("font_size", 16)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		var mode := Label.new()
		mode.name = "Mode"
		mode.add_theme_font_size_override("font_size", 12)
		mode.add_theme_color_override("font_color", book.MUTED)
		mode.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mode)
		var level_id := str(entry.id)
		button.pressed.connect(func() -> void: select_level(level_id))
		level_buttons[level_id] = button
		list.add_child(button)
	level_buttons[selected_level].button_pressed = true
	return panel

func _build_editor() -> Control:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	level_title = Label.new()
	level_title.add_theme_font_size_override("font_size", 26)
	level_title.add_theme_color_override("font_color", book.AMBER)
	column.add_child(level_title)
	level_meta = Label.new()
	level_meta.add_theme_font_size_override("font_size", 13)
	level_meta.add_theme_color_override("font_color", book.MUTED)
	# Kept for tests/tooltips; hidden so every row fits at 1280x720.
	level_meta.visible = false
	column.add_child(level_meta)

	# ---- Progression: the surge that brings the zone boss ----
	progress_box = VBoxContainer.new()
	progress_box.name = "Progression"
	progress_box.add_theme_constant_override("separation", 4)
	column.add_child(progress_box)
	progress_box.add_child(_section("PROGRESSION  (reach this surge, kill the boss, unlock the next level)"))
	progress_box.add_child(_setting_row("progress_surge"))
	var boss_row := HBoxContainer.new()
	boss_row.name = "BossCreature"
	boss_row.add_theme_constant_override("separation", 14)
	var boss_caption := Label.new()
	boss_caption.text = "Boss creature"
	boss_caption.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	boss_caption.add_theme_font_size_override("font_size", 16)
	boss_row.add_child(boss_caption)
	boss_picker = OptionButton.new()
	boss_picker.name = "BossPicker"
	boss_picker.custom_minimum_size = Vector2(260, 36)
	boss_picker.item_selected.connect(func(index: int) -> void: set_boss_monster(str(boss_picker.get_item_metadata(index))))
	boss_row.add_child(boss_picker)
	progress_box.add_child(boss_row)
	boss_rows.append(boss_row)
	for key in ["boss_health", "boss_damage", "boss_size"]:
		var row := _setting_row(key)
		progress_box.add_child(row)
		boss_rows.append(row)
	progress_summary = Label.new()
	progress_summary.name = "ProgressSummary"
	progress_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_summary.add_theme_font_size_override("font_size", 15)
	progress_summary.add_theme_color_override("font_color", book.AMBER)
	progress_box.add_child(progress_summary)
	column.add_child(_section("SPAWNS"))

	var modes := HBoxContainer.new()
	modes.name = "Modes"
	modes.add_theme_constant_override("separation", 8)
	column.add_child(modes)
	for mode in LevelSpawnsScript.MODES:
		var button: Button = book._button(str(MODE_LABELS[mode]))
		button.name = "Mode_" + str(mode)
		button.toggle_mode = true
		button.button_group = mode_group
		button.custom_minimum_size = Vector2(150, 40)
		button.add_theme_stylebox_override("pressed", book._button_box(book.AMBER_DEEP, book.AMBER))
		var mode_id := str(mode)
		button.pressed.connect(func() -> void: set_mode(mode_id))
		mode_buttons[mode] = button
		modes.add_child(button)

	summary_label = Label.new()
	summary_label.name = "Summary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 16)
	column.add_child(summary_label)

	mode_note = Label.new()
	mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_note.add_theme_color_override("font_color", book.MUTED)
	column.add_child(mode_note)

	custom_box = VBoxContainer.new()
	custom_box.name = "Custom"
	custom_box.add_theme_constant_override("separation", 4)
	column.add_child(custom_box)
	custom_box.add_child(_section("SPAWN RATE"))
	for key in LevelSpawnsScript.SETTING_ORDER:
		custom_box.add_child(_setting_row(str(key)))
	custom_box.add_child(_section("CREATURES  (every encyclopedia monster by family and stage; weights, shown as a share of spawns)"))
	mix_filter = LineEdit.new()
	mix_filter.name = "CreatureFilter"
	mix_filter.placeholder_text = "Find a creature (name, family, role)"
	mix_filter.clear_button_enabled = true
	mix_filter.text_changed.connect(func(_text: String) -> void: _filter_mix_rows())
	custom_box.add_child(mix_filter)
	mix_list = VBoxContainer.new()
	mix_list.name = "CreatureRows"
	mix_list.add_theme_constant_override("separation", 4)
	custom_box.add_child(mix_list)
	_sync_monster_rows()

	outer.add_child(_build_footer())
	return outer

func _build_footer() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", book._box(book.PLATE_2, book.EDGE, 0, 0, 12, [0, 1, 0, 0]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.add_theme_color_override("font_color", book.MUTED)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.text = "Pick a level, set its creatures, then Preview it or save it to the game."
	row.add_child(status_label)
	var reset: Button = book._button("Reset level", true)
	reset.name = "ResetLevel"
	reset.pressed.connect(reset_level)
	row.add_child(reset)
	var preview_button: Button = book._button("Preview  ▶")
	preview_button.name = "Preview"
	preview_button.tooltip_text = "Play this level now with these settings. Nothing is saved to your profile."
	preview_button.pressed.connect(preview)
	row.add_child(preview_button)
	var save_button: Button = book._button("Save to game data")
	save_button.name = "Save"
	save_button.add_theme_stylebox_override("normal", book._button_box(book.AMBER_DEEP, book.AMBER))
	save_button.add_theme_stylebox_override("hover", book._button_box(book.AMBER, Color("f7bb58")))
	save_button.add_theme_color_override("font_color", Color("15181b"))
	save_button.add_theme_color_override("font_hover_color", Color("15181b"))
	save_button.pressed.connect(save)
	row.add_child(save_button)
	return bar

func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", book.MUTED)
	return label

func _setting_row(key: String) -> Control:
	var definition: Dictionary = LevelSpawnsScript.SETTING_DEFS[key] if LevelSpawnsScript.SETTING_DEFS.has(key) else LevelSpawnsScript.PROGRESS_DEFS[key]
	var row := HBoxContainer.new()
	row.name = "Setting_" + key
	row.add_theme_constant_override("separation", 14)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var label := Label.new()
	label.text = str(definition.label)
	label.add_theme_font_size_override("font_size", 16)
	labels.add_child(label)
	var hint := Label.new()
	hint.text = str(definition.hint)
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	hint.tooltip_text = str(definition.hint)
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", book.MUTED)
	labels.add_child(hint)
	var slider := HSlider.new()
	slider.min_value = float(definition.min)
	slider.max_value = float(definition.max)
	slider.step = float(definition.step)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = float(definition.min)
	spin.max_value = float(definition.max)
	spin.step = float(definition.step)
	spin.custom_minimum_size = Vector2(118, 0)
	spin.select_all_on_focus = true
	row.add_child(spin)
	slider.value_changed.connect(func(value: float) -> void: set_setting(key, value))
	spin.value_changed.connect(func(value: float) -> void: set_setting(key, value))
	setting_rows[key] = {"slider": slider, "spin": spin}
	return row

## Builds the creature rows and the boss list again when the encyclopedia's
## monsters changed (a creature added in the Creature Lab, say).
func _sync_monster_rows() -> void:
	if mix_list == null:
		return
	var ids: Array = MonsterStatsScript.monster_ids()
	if ids == _row_ids:
		return
	_row_ids = ids.duplicate()
	for child in mix_list.get_children():
		mix_list.remove_child(child)
		child.queue_free()
	mix_rows.clear()
	var family := "\u0000"
	for monster_id in ids:
		var entry := MonsterStatsScript.monster(monster_id)
		var this_family := str(entry.get("family", ""))
		if this_family.is_empty():
			this_family = "creatures"
		if this_family != family:
			family = this_family
			var heading := _section(CreatureRegistryScript.family_label(family).to_upper())
			heading.name = "Family_" + family
			heading.set_meta("family", family)
			mix_list.add_child(heading)
		mix_list.add_child(_mix_row(monster_id))
	mix_filter.visible = ids.size() > 4
	boss_picker.clear()
	for monster_id in ids:
		var entry := MonsterStatsScript.monster(monster_id)
		boss_picker.add_item(str(entry.get("name", monster_id)))
		boss_picker.set_item_metadata(boss_picker.item_count - 1, monster_id)
	_filter_mix_rows()

func _filter_mix_rows() -> void:
	if mix_list == null:
		return
	var query := mix_filter.text.strip_edges().to_lower() if mix_filter != null else ""
	var shown_families := {}
	for monster_id in mix_rows:
		var entry := MonsterStatsScript.monster(monster_id)
		var family := str(entry.get("family", "")) if not str(entry.get("family", "")).is_empty() else "creatures"
		var haystack := ("%s %s %s %s %s %s" % [monster_id, entry.get("name", ""), entry.get("role", ""), entry.get("target", ""), family, entry.get("legacy_name", "")]).to_lower()
		var shown := query.is_empty() or haystack.contains(query)
		mix_rows[monster_id].row.visible = shown
		if shown:
			shown_families[family] = true
	for child in mix_list.get_children():
		if child.has_meta("family"):
			child.visible = shown_families.has(str(child.get_meta("family")))

func _mix_row(monster_id: String) -> Control:
	var entry: Dictionary = MonsterStatsScript.monster(monster_id)
	var row := HBoxContainer.new()
	row.name = "Mix_" + monster_id
	row.add_theme_constant_override("separation", 14)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if book.has_method("sprite_texture"):
		portrait.texture = book.sprite_texture(monster_id)
	row.add_child(portrait)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(LABEL_WIDTH - 40 - 14, 0)
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var label := Label.new()
	label.text = str(entry.get("name", monster_id))
	label.add_theme_font_size_override("font_size", 16)
	labels.add_child(label)
	var role := Label.new()
	role.clip_text = true
	role.custom_minimum_size = Vector2(LABEL_WIDTH - 40 - 14, 0)
	role.text = "%s · %s" % [str(entry.get("role", "")), str(entry.get("target", ""))]
	if bool(entry.get("custom", false)):
		role.text = "%s · %s" % [str(CreatureRegistryScript.ARCHETYPES[MonsterStatsScript.archetype(monster_id)]["short"]), str(entry.get("target", ""))]
	elif entry.has("legacy_name"):
		role.text += " · the original %s" % str(entry["legacy_name"])
	role.tooltip_text = role.text
	role.mouse_filter = Control.MOUSE_FILTER_PASS
	role.add_theme_font_size_override("font_size", 12)
	role.add_theme_color_override("font_color", book.MUTED)
	labels.add_child(role)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = LevelSpawnsScript.WEIGHT_MAX
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var share := Label.new()
	share.custom_minimum_size = Vector2(118, 0)
	share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	share.add_theme_font_size_override("font_size", 18)
	share.add_theme_color_override("font_color", book.AMBER)
	row.add_child(share)
	slider.value_changed.connect(func(value: float) -> void: set_weight(monster_id, value))
	mix_rows[monster_id] = {"slider": slider, "share": share, "row": row}
	return row
