extends HBoxContainer

## Dev Encyclopedia > Weapons: a logbook of every weapon in the game (picture,
## type, behaviour, rarity, numbers) where the numbers can be tuned. Edits
## reach a running encounter at once; "Save to game data" publishes each edited
## weapon as its next revision (WeaponStatEdits / WeaponPublisher).

const WeaponStatEditsScript = preload("res://scripts/model/weapon_stat_edits.gd")
const WeaponTypesScript = preload("res://scripts/model/weapon_types.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const BalanceData = preload("res://data/balance.gd")
const LootOddsScript = preload("res://scripts/model/loot_odds.gd")
const CreatureDropsScript = preload("res://scripts/model/creature_drops.gd")
const LevelSpawnsScript = preload("res://scripts/model/level_spawns.gd")
const LootDropVisualScript = preload("res://scripts/game/loot_drop_visual.gd")
const ItemIconsScript = preload("res://scripts/ui/item_icons.gd")

## The in-game drop orb, drawn by the same code the game uses.
class OrbPreview extends Control:
	var tint := Color.WHITE
	var texture: Texture2D
	func _draw() -> void:
		LootDropVisualScript.draw_orb(self, tint, texture, "weapon", false, size / 2.0)

const TILE_SIZE := Vector2(104, 122)
const GRID_COLUMNS := 3
const LABEL_WIDTH := 230.0
## Same colours as the inventory.
const RARITY_COLORS := {"common": Color("bdc6cf"), "magic": Color("71bfff"), "rare": Color("e6c46c"), "epic": Color("c292ed")}

## The encyclopedia (colours, button styles, monster sprites, controller).
var book: Node
var model: RefCounted
var selected_id := ""

var search: LineEdit
var grid: GridContainer
var empty_label: Label
var count_label: Label
var tiles: Dictionary = {}
var tile_group := ButtonGroup.new()
var picture: TextureRect
var name_label: Label
var meta_label: Label
var desc_label: Label
var derived_box: HBoxContainer
var cap_label: Label
var matchup_box: HBoxContainer
var behavior_picker: OptionButton
var stats_box: VBoxContainer
var rows: Dictionary = {}
var status_label: Label
var save_button: Button
var entry_column: Control
var nothing_label: Label
var drop_check: CheckBox
var drop_rows: Dictionary = {}
var drop_odds_box: HBoxContainer
var drop_levels_grid: GridContainer
var drop_note: Label
## creature key -> {"card", "spin", "wait", "name"}
var creature_cards: Dictionary = {}
var creature_box: HBoxContainer
var orb_preview: Control
var orb_caption: Label
var drop_now_button: Button
var _syncing := false
var _textures: Dictionary = {}

func _init(encyclopedia: Node, edits: RefCounted = null) -> void:
	book = encyclopedia
	model = edits if edits != null else WeaponStatEditsScript.new()
	name = "WeaponsPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	add_child(_build_logbook())
	add_child(_build_entry())

## Re-reads the published weapons (the Weapon Lab may have added some).
func refresh() -> void:
	model.reload()
	_textures.clear()
	_rebuild_tiles()
	if not model.has_weapon(selected_id):
		var ids: Array = model.ids()
		selected_id = ids[0] if not ids.is_empty() else ""
	_render_entry()
	_set_status(_idle_status())

# ---------- editing ----------

func select_weapon(weapon_id: String) -> void:
	if not model.has_weapon(weapon_id):
		return
	selected_id = weapon_id
	_sync_tile_selection()
	_render_entry()

func set_stat(key: String, value: float) -> void:
	if _syncing or selected_id.is_empty():
		return
	model.set_stat(selected_id, key, value)
	_after_change(selected_id)

func set_behavior(behavior_id: String) -> void:
	if _syncing or selected_id.is_empty():
		return
	model.set_behavior(selected_id, behavior_id)
	_after_change(selected_id)

func revert_selected() -> void:
	if selected_id.is_empty():
		return
	model.revert(selected_id)
	_after_change(selected_id)
	_set_status("%s is back to its saved numbers." % model.label(selected_id))

func revert_all() -> void:
	var edited: Array = model.modified_ids()
	model.revert_all()
	for weapon_id in edited:
		_apply_live(weapon_id)
	_render_entry()
	_refresh_marks()
	_set_status("Every weapon is back to its saved numbers.")

func save() -> Dictionary:
	var edited: Array = model.modified_ids()
	if edited.is_empty():
		_set_status("Nothing to save. Every weapon matches the game data.")
		return {"ok": true, "saved": [], "errors": {}}
	var result: Dictionary = model.save()
	_textures.clear()
	_rebuild_tiles()
	_render_entry()
	if result.ok:
		var names: Array = []
		for weapon_id in result.saved:
			names.append("%s (revision %d)" % [model.label(weapon_id), model.revision_number(weapon_id)])
		_set_status("Saved: %s." % ", ".join(names))
	else:
		var problems: Array = []
		for weapon_id in result.errors:
			problems.append("%s: %s" % [model.label(weapon_id), result.errors[weapon_id]])
		_set_status("Not saved. " + "; ".join(problems))
	return result

func _after_change(weapon_id: String) -> void:
	_apply_live(weapon_id)
	_refresh_rows()
	_render_derived()
	_refresh_marks()
	_set_status("Applied live. " + ("Not saved yet." if model.is_modified(weapon_id) else "Matches saved game data."))

## Pushes the numbers (and drop settings) into a running encounter, if there is one.
func _apply_live(weapon_id: String) -> void:
	var controller: Variant = book.get("controller")
	if controller == null or not is_instance_valid(controller):
		return
	if controller.has_method("apply_weapon_stats"):
		controller.apply_weapon_stats(weapon_id, model.revision_patch(weapon_id))
	if controller.has_method("apply_loot_overrides"):
		controller.apply_loot_overrides(model.loot_overrides())

## Drop settings: "enabled", "weight", "min_item_level", "max_item_level".
func set_drop(key: String, value: Variant) -> void:
	if _syncing or selected_id.is_empty():
		return
	model.set_drop(selected_id, key, value)
	_after_change(selected_id)

func _idle_status() -> String:
	if model.ids().is_empty():
		return "No weapons in the game yet. Make one in the Weapon Lab."
	if not model.modified_ids().is_empty():
		return "You have unsaved weapon edits."
	return "Edits apply to the game immediately. Save to make them permanent."

# ---------- build ----------

func _build_logbook() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(GRID_COLUMNS * TILE_SIZE.x + (GRID_COLUMNS - 1) * 8 + 44, 0)
	panel.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 0, 0, 14, [0, 0, 1, 0]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	var heading := Label.new()
	heading.text = "LOGBOOK"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", book.MUTED)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	count_label = Label.new()
	count_label.name = "Count"
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", book.MUTED)
	heading_row.add_child(count_label)
	search = LineEdit.new()
	search.placeholder_text = "Find a weapon"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: _filter_tiles())
	column.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	holder.add_child(grid)
	empty_label = Label.new()
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_color_override("font_color", book.MUTED)
	empty_label.hide()
	holder.add_child(empty_label)
	return panel

func _build_tile(weapon_id: String) -> Button:
	var color: Color = RARITY_COLORS.get(model.rarity(weapon_id), RARITY_COLORS.common)
	var tile := Button.new()
	tile.name = "Tile_" + weapon_id.validate_node_name()
	tile.toggle_mode = true
	tile.button_group = tile_group
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = model.label(weapon_id)
	tile.add_theme_stylebox_override("normal", book._box(Color("15181b"), color.darkened(0.45), 2, 4, 0))
	tile.add_theme_stylebox_override("hover", book._box(Color("20262b"), color, 2, 4, 0))
	tile.add_theme_stylebox_override("pressed", book._box(Color("2f2a20"), book.AMBER, 3, 4, 0))
	tile.add_theme_stylebox_override("hover_pressed", book._box(Color("3a3222"), book.AMBER, 3, 4, 0))
	tile.pressed.connect(select_weapon.bind(weapon_id))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_top = 8
	column.offset_right = -8
	column.offset_bottom = -6
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture_for(model.icon_path(weapon_id))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var title := Label.new()
	title.text = model.label(weapon_id)
	title.clip_text = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var mark := Panel.new()
	mark.name = "Edited"
	mark.tooltip_text = "Edited, not saved"
	mark.position = Vector2(TILE_SIZE.x - 18, 8)
	mark.size = Vector2(10, 10)
	mark.add_theme_stylebox_override("panel", book._box(book.AMBER, book.AMBER, 0, 5, 0))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.hide()
	tile.add_child(mark)
	return tile

func _build_entry() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	entry_column = column
	nothing_label = Label.new()
	nothing_label.text = "No weapons in the game yet. Make one in the Weapon Lab, then come back."
	nothing_label.add_theme_color_override("font_color", book.MUTED)
	nothing_label.hide()
	margin.add_child(nothing_label)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	column.add_child(head)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(300, 190)
	frame.add_theme_stylebox_override("panel", book._box(Color("101316"), book.EDGE, 1, 4, 14))
	head.add_child(frame)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(picture)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	head.add_child(info)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 30)
	info.add_child(name_label)
	meta_label = Label.new()
	meta_label.add_theme_color_override("font_color", book.AMBER)
	meta_label.add_theme_font_size_override("font_size", 14)
	info.add_child(meta_label)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color("c9c3b8"))
	desc_label.add_theme_font_size_override("font_size", 15)
	info.add_child(desc_label)
	var derived_panel := PanelContainer.new()
	derived_panel.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	derived_panel.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 1, 4, 12))
	info.add_child(derived_panel)
	var derived_column := VBoxContainer.new()
	derived_column.add_theme_constant_override("separation", 4)
	derived_panel.add_child(derived_column)
	derived_box = HBoxContainer.new()
	derived_box.add_theme_constant_override("separation", 26)
	derived_column.add_child(derived_box)
	cap_label = Label.new()
	cap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_label.add_theme_font_size_override("font_size", 12)
	cap_label.add_theme_color_override("font_color", book.AMBER)
	derived_column.add_child(cap_label)

	var matchup_heading := Label.new()
	matchup_heading.text = "AGAINST EACH MONSTER  (base weapon, no research)"
	matchup_heading.add_theme_font_size_override("font_size", 12)
	matchup_heading.add_theme_color_override("font_color", book.MUTED)
	column.add_child(matchup_heading)
	matchup_box = HBoxContainer.new()
	matchup_box.name = "Matchups"
	matchup_box.add_theme_constant_override("separation", 10)
	column.add_child(matchup_box)

	var behavior_row := HBoxContainer.new()
	behavior_row.add_theme_constant_override("separation", 14)
	column.add_child(behavior_row)
	var behavior_labels := VBoxContainer.new()
	behavior_labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	behavior_labels.add_theme_constant_override("separation", 0)
	behavior_row.add_child(behavior_labels)
	var behavior_title := Label.new()
	behavior_title.text = "Behaviour"
	behavior_title.add_theme_font_size_override("font_size", 16)
	behavior_labels.add_child(behavior_title)
	var behavior_hint := Label.new()
	behavior_hint.text = "Melee swings at a monster in reach; the others shoot."
	behavior_hint.clip_text = true
	behavior_hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	behavior_hint.add_theme_font_size_override("font_size", 12)
	behavior_hint.add_theme_color_override("font_color", book.MUTED)
	behavior_labels.add_child(behavior_hint)
	behavior_picker = OptionButton.new()
	behavior_picker.name = "Behavior"
	behavior_picker.custom_minimum_size = Vector2(180, 0)
	behavior_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for behavior in WeaponStatEditsScript.BEHAVIORS:
		behavior_picker.add_item(str(behavior[1]))
	behavior_picker.item_selected.connect(func(index: int) -> void: set_behavior(str(WeaponStatEditsScript.BEHAVIORS[index][0])))
	behavior_row.add_child(behavior_picker)

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	column.add_child(stats_box)
	for key in WeaponStatEditsScript.STAT_KEYS:
		stats_box.add_child(_build_stat_row(key))
	column.add_child(_build_drop_section())

	right.add_child(_build_footer())
	return right

func _build_stat_row(key: String) -> Control:
	var definition: Dictionary = WeaponStatEditsScript.STAT_DEFS[key]
	var row := HBoxContainer.new()
	row.name = "Stat_" + key
	row.add_theme_constant_override("separation", 14)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var label := Label.new()
	label.text = definition["label"]
	label.add_theme_font_size_override("font_size", 16)
	labels.add_child(label)
	var hint := Label.new()
	hint.text = definition["hint"]
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	hint.tooltip_text = definition["hint"]
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", book.MUTED)
	labels.add_child(hint)

	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 32)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var slider := HSlider.new()
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.min_value = definition["min"]
	slider.max_value = definition["slider_max"]
	slider.step = definition["step"]
	track.add_child(slider)
	var marker := ColorRect.new()
	marker.name = "SavedMarker"
	marker.color = Color(0.94, 0.66, 0.21, 0.55)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.anchor_top = 0.0
	marker.anchor_bottom = 1.0
	marker.offset_top = 4.0
	marker.offset_bottom = -4.0
	track.add_child(marker)

	var spin := SpinBox.new()
	spin.min_value = definition["min"]
	spin.max_value = definition["max"]
	spin.step = definition["step"]
	spin.custom_minimum_size = Vector2(118, 0)
	spin.select_all_on_focus = true
	if definition.get("percent", false):
		spin.suffix = "%"
	row.add_child(spin)

	var undo: Button = book._button("Saved", true)
	undo.custom_minimum_size = Vector2(92, 0)
	row.add_child(undo)

	slider.value_changed.connect(func(value: float) -> void: set_stat(key, value))
	spin.value_changed.connect(func(value: float) -> void: set_stat(key, value))
	undo.pressed.connect(func() -> void: set_stat(key, model.published_stat(selected_id, key)))
	rows[key] = {"row": row, "label": label, "slider": slider, "spin": spin, "undo": undo, "marker": marker}
	return row

func _build_drop_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "Drops"
	section.add_theme_constant_override("separation", 8)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 14)
	section.add_child(heading_row)
	var heading := Label.new()
	heading.text = "LOOT DROPS"
	heading.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", book.MUTED)
	heading_row.add_child(heading)
	drop_check = CheckBox.new()
	drop_check.name = "DropEnabled"
	drop_check.text = "Drops from monsters"
	drop_check.tooltip_text = "Puts the weapon in the monster loot table (foundry_physical_v1)."
	drop_check.toggled.connect(func(on: bool) -> void: set_drop("enabled", on))
	heading_row.add_child(drop_check)

	# Weight: same row layout as the stats.
	var definition: Dictionary = WeaponStatEditsScript.DROP_DEFS.weight
	var row := HBoxContainer.new()
	row.name = "Drop_weight"
	row.add_theme_constant_override("separation", 14)
	section.add_child(row)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var label := Label.new()
	label.text = definition.label
	label.add_theme_font_size_override("font_size", 16)
	labels.add_child(label)
	var hint := Label.new()
	hint.text = definition.hint
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	hint.tooltip_text = definition.hint
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", book.MUTED)
	labels.add_child(hint)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 32)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var slider := HSlider.new()
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.min_value = definition.min
	slider.max_value = definition.slider_max
	slider.step = definition.step
	track.add_child(slider)
	var marker := ColorRect.new()
	marker.color = Color(0.94, 0.66, 0.21, 0.55)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.anchor_top = 0.0
	marker.anchor_bottom = 1.0
	marker.offset_top = 4.0
	marker.offset_bottom = -4.0
	track.add_child(marker)
	var spin := SpinBox.new()
	spin.min_value = definition.min
	spin.max_value = definition.max
	spin.step = definition.step
	spin.custom_minimum_size = Vector2(118, 0)
	spin.select_all_on_focus = true
	row.add_child(spin)
	var undo: Button = book._button("Saved", true)
	undo.custom_minimum_size = Vector2(92, 0)
	row.add_child(undo)
	slider.value_changed.connect(func(value: float) -> void: set_drop("weight", value))
	spin.value_changed.connect(func(value: float) -> void: set_drop("weight", value))
	undo.pressed.connect(func() -> void: set_drop("weight", model.published_drop(selected_id).weight))
	drop_rows["weight"] = {"label": label, "slider": slider, "spin": spin, "undo": undo, "marker": marker}

	# Item level range.
	var levels_row := HBoxContainer.new()
	levels_row.name = "Drop_levels"
	levels_row.add_theme_constant_override("separation", 14)
	section.add_child(levels_row)
	var levels_labels := VBoxContainer.new()
	levels_labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	levels_labels.add_theme_constant_override("separation", 0)
	levels_row.add_child(levels_labels)
	var levels_label := Label.new()
	levels_label.text = "Item levels"
	levels_label.add_theme_font_size_override("font_size", 16)
	levels_labels.add_child(levels_label)
	var levels_hint := Label.new()
	levels_hint.text = "Levels drop items of level 1-3; outside this range it can't drop."
	levels_hint.clip_text = true
	levels_hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	levels_hint.tooltip_text = levels_hint.text
	levels_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	levels_hint.add_theme_font_size_override("font_size", 12)
	levels_hint.add_theme_color_override("font_color", book.MUTED)
	levels_labels.add_child(levels_hint)
	drop_rows["levels_label"] = {"label": levels_label}
	for key in ["min_item_level", "max_item_level"]:
		var caption := Label.new()
		caption.text = "from" if key == "min_item_level" else "to"
		caption.add_theme_color_override("font_color", book.MUTED)
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		levels_row.add_child(caption)
		var level_spin := SpinBox.new()
		level_spin.name = "Drop_" + key
		level_spin.min_value = 1
		level_spin.max_value = 3
		level_spin.step = 1
		level_spin.custom_minimum_size = Vector2(90, 0)
		level_spin.value_changed.connect(func(value: float) -> void: set_drop(key, int(value)))
		levels_row.add_child(level_spin)
		drop_rows[key] = {"spin": level_spin}

	# What the drop looks like in a run: the same orb as every other item.
	var orb_row := HBoxContainer.new()
	orb_row.name = "DropOrb"
	orb_row.add_theme_constant_override("separation", 14)
	section.add_child(orb_row)
	var orb_labels := VBoxContainer.new()
	orb_labels.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	orb_labels.add_theme_constant_override("separation", 0)
	orb_row.add_child(orb_labels)
	var orb_title := Label.new()
	orb_title.text = "Drop orb"
	orb_title.add_theme_font_size_override("font_size", 16)
	orb_labels.add_child(orb_title)
	var orb_hint := Label.new()
	orb_hint.text = "What a monster drops in a run, same as every item."
	orb_hint.clip_text = true
	orb_hint.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	orb_hint.add_theme_font_size_override("font_size", 12)
	orb_hint.add_theme_color_override("font_color", book.MUTED)
	orb_labels.add_child(orb_hint)
	var orb_frame := PanelContainer.new()
	orb_frame.custom_minimum_size = Vector2(220, 92)
	orb_frame.add_theme_stylebox_override("panel", book._box(Color("101316"), book.EDGE, 1, 4, 4))
	orb_row.add_child(orb_frame)
	var orb_column := VBoxContainer.new()
	orb_column.add_theme_constant_override("separation", 0)
	orb_frame.add_child(orb_column)
	orb_caption = Label.new()
	orb_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_caption.add_theme_font_size_override("font_size", 13)
	orb_caption.add_theme_color_override("font_outline_color", Color("10161e"))
	orb_caption.add_theme_constant_override("outline_size", 4)
	orb_column.add_child(orb_caption)
	orb_preview = OrbPreview.new()
	orb_preview.name = "Orb"
	orb_preview.custom_minimum_size = Vector2(0, 60)
	orb_column.add_child(orb_preview)
	drop_now_button = book._button("Drop one now", true)
	drop_now_button.name = "DropNow"
	drop_now_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drop_now_button.pressed.connect(drop_now)
	orb_row.add_child(drop_now_button)

	# Drop chance per creature (PRD).
	var creature_heading := Label.new()
	creature_heading.text = "DROP CHANCE PER CREATURE  (smoothed: every miss raises the next roll)"
	creature_heading.add_theme_font_size_override("font_size", 12)
	creature_heading.add_theme_color_override("font_color", book.MUTED)
	section.add_child(creature_heading)
	creature_box = HBoxContainer.new()
	creature_box.name = "CreatureChances"
	creature_box.add_theme_constant_override("separation", 10)
	section.add_child(creature_box)
	for key in CreatureDropsScript.keys():
		creature_box.add_child(_build_creature_card(key))

	# The odds.
	var odds_panel := PanelContainer.new()
	odds_panel.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 1, 4, 12))
	section.add_child(odds_panel)
	var odds_column := VBoxContainer.new()
	odds_column.add_theme_constant_override("separation", 8)
	odds_panel.add_child(odds_column)
	drop_odds_box = HBoxContainer.new()
	drop_odds_box.name = "DropOdds"
	drop_odds_box.add_theme_constant_override("separation", 26)
	odds_column.add_child(drop_odds_box)
	drop_levels_grid = GridContainer.new()
	drop_levels_grid.name = "DropLevels"
	drop_levels_grid.columns = 5
	drop_levels_grid.add_theme_constant_override("h_separation", 18)
	drop_levels_grid.add_theme_constant_override("v_separation", 2)
	odds_column.add_child(drop_levels_grid)
	drop_note = Label.new()
	drop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drop_note.add_theme_font_size_override("font_size", 12)
	drop_note.add_theme_color_override("font_color", book.MUTED)
	odds_column.add_child(drop_note)
	return section

func _build_creature_card(key: String) -> Control:
	var card := PanelContainer.new()
	card.name = "Creature_" + key
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 1, 4, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.custom_minimum_size = Vector2(0, 64)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.flip_h = true
	sprite.texture = creature_texture(key)
	column.add_child(sprite)
	var name_text := Label.new()
	name_text.text = CreatureDropsScript.label(key)
	name_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_text.add_theme_font_size_override("font_size", 14)
	column.add_child(name_text)
	if key == CreatureDropsScript.BOSS_KEY:
		sprite.modulate = Color(1.0, 0.85, 0.6)
	var spin := SpinBox.new()
	spin.name = "Chance"
	spin.min_value = 0.0
	spin.max_value = 100.0
	spin.step = 0.1
	spin.suffix = "%"
	spin.select_all_on_focus = true
	spin.tooltip_text = "Chance per kill that this weapon drops from a %s. 0 = never." % CreatureDropsScript.label(key).to_lower()
	spin.value_changed.connect(func(value: float) -> void: set_drop("chance:" + key, value))
	column.add_child(spin)
	var wait := Label.new()
	wait.name = "Wait"
	wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait.add_theme_font_size_override("font_size", 11)
	wait.add_theme_color_override("font_color", book.MUTED)
	column.add_child(wait)
	creature_cards[key] = {"card": card, "spin": spin, "wait": wait, "name": name_text}
	return card

## Creature art for the drop cards: the monster's sprite; the zone boss uses
## the default boss creature's.
func creature_texture(key: String) -> Texture2D:
	if not book.has_method("sprite_texture"):
		return null
	return book.sprite_texture(LevelSpawnsScript.DEFAULT_BOSS_MONSTER if key == CreatureDropsScript.BOSS_KEY else key)

## Drops the selected weapon in front of the hero (only in a run).
func drop_now() -> String:
	var controller: Variant = book.get("controller")
	if controller == null or not is_instance_valid(controller) or not controller.has_method("drop_weapon_now"):
		_set_status("Start a run, then press F9 here to drop one in front of the hero.")
		return ""
	var message: String = controller.drop_weapon_now(selected_id)
	_set_status(message)
	return message

func _refresh_orb() -> void:
	var rarity: String = model.rarity(selected_id)
	var tint: Color = LootDropVisualScript.tint_for(rarity)
	orb_preview.tint = tint
	orb_preview.texture = ItemIconsScript.texture(selected_id)
	if orb_preview.texture == null:
		orb_preview.texture = texture_for(model.icon_path(selected_id))
	orb_preview.queue_redraw()
	orb_caption.text = "%s %s" % [rarity.capitalize(), model.label(selected_id)]
	orb_caption.add_theme_color_override("font_color", tint)
	var controller: Variant = book.get("controller")
	var in_run: bool = controller != null and is_instance_valid(controller) and controller.has_method("drop_weapon_now")
	drop_now_button.disabled = not in_run
	drop_now_button.tooltip_text = "Drops this weapon in front of the hero, the same way a monster drop does." if in_run else "Only in a run: start one and press F9."

func _refresh_drops() -> void:
	if not model.has_weapon(selected_id):
		return
	_refresh_orb()
	var current: Dictionary = model.drop(selected_id)
	var saved: Dictionary = model.published_drop(selected_id)
	drop_check.set_pressed_no_signal(bool(current.enabled))
	drop_check.add_theme_color_override("font_color", book.AMBER if bool(current.enabled) != bool(saved.enabled) else book.INK)
	var weight_parts: Dictionary = drop_rows.weight
	weight_parts.slider.set_value_no_signal(float(current.weight))
	weight_parts.spin.set_value_no_signal(float(current.weight))
	var weight_changed := absf(float(current.weight) - float(saved.weight)) > 0.0001
	weight_parts.label.add_theme_color_override("font_color", book.AMBER if weight_changed else book.INK)
	weight_parts.undo.disabled = not weight_changed
	weight_parts.undo.tooltip_text = "Back to the saved weight (%s)" % _trim(float(saved.weight))
	var ratio := clampf(inverse_lerp(float(WeaponStatEditsScript.DROP_DEFS.weight.min), float(WeaponStatEditsScript.DROP_DEFS.weight.slider_max), float(saved.weight)), 0.0, 1.0)
	weight_parts.marker.anchor_left = ratio
	weight_parts.marker.anchor_right = ratio
	weight_parts.marker.offset_left = 8.0 - 16.0 * ratio - 1.0
	weight_parts.marker.offset_right = 8.0 - 16.0 * ratio + 1.0
	for key in ["min_item_level", "max_item_level"]:
		drop_rows[key].spin.set_value_no_signal(int(current[key]))
	var levels_changed: bool = int(current.min_item_level) != int(saved.min_item_level) or int(current.max_item_level) != int(saved.max_item_level)
	drop_rows.levels_label.label.add_theme_color_override("font_color", book.AMBER if levels_changed else book.INK)
	for key in ["weight", "min_item_level", "max_item_level"]:
		if drop_rows[key].has("slider"):
			drop_rows[key].slider.editable = bool(current.enabled)
		drop_rows[key].spin.editable = bool(current.enabled)
	var per_creature: bool = model.is_per_creature(selected_id)
	drop_rows.weight.slider.editable = bool(current.enabled) and not per_creature
	drop_rows.weight.spin.editable = bool(current.enabled) and not per_creature
	for key in creature_cards:
		var parts: Dictionary = creature_cards[key]
		var chance := float(current.chances.get(key, 0.0))
		parts.spin.set_value_no_signal(chance)
		parts.spin.editable = bool(current.enabled)
		var changed := absf(chance - float(saved.chances.get(key, 0.0))) > 0.0001
		parts.name.add_theme_color_override("font_color", book.AMBER if changed else book.INK)
		if chance <= 0.0:
			parts.wait.text = "never"
		else:
			parts.wait.text = "about 1 in %s · sure by kill %d" % [_count(100.0 / chance), CreatureDropsScript.certain_by(chance / 100.0)]
		parts.card.modulate = Color(1, 1, 1, 1.0 if bool(current.enabled) else 0.5)
	_render_drop_odds()

func _render_drop_odds() -> void:
	for child in drop_odds_box.get_children() + drop_levels_grid.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var current: Dictionary = model.drop(selected_id)
	var table: Dictionary = model.drop_table()
	if not bool(current.enabled):
		drop_note.text = "Doesn't drop. Tick \"Drops from monsters\" to put it in the loot table."
		return
	if model.is_per_creature(selected_id):
		_render_creature_odds(current)
		return
	var level := int(current.min_item_level)
	var item_share := LootOddsScript.share(selected_id, table, level)
	var kill := LootOddsScript.per_kill(selected_id, table, level)
	_add_drop_chip("Share of item drops", _percent(item_share))
	_add_drop_chip("Chance per kill", _percent(kill))
	_add_drop_chip("Typical wait", "1 in %s kills" % _count(1.0 / kill) if kill > 0.0 else "never")
	_add_drop_chip("Boss-level kill", _percent(LootOddsScript.per_kill(selected_id, table, 3, "boss")))
	for caption in ["LEVEL", "ITEM LV", "KILLS / RUN", "CHANCE PER RUN", "HALF OF PLAYERS BY"]:
		var header := Label.new()
		header.text = caption
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", book.MUTED)
		drop_levels_grid.add_child(header)
	for entry in LootOddsScript.levels():
		var per_kill := LootOddsScript.per_kill(selected_id, table, int(entry.item_level), str(entry.kind))
		var per_run := LootOddsScript.at_least_once(per_kill, float(entry.kills))
		var runs := LootOddsScript.tries_for(per_run)
		var values := [str(entry.name), str(entry.item_level), "~%d" % int(entry.kills), _percent(per_run) if per_kill > 0.0 else "can't drop", ("run %s" % _count(ceilf(runs))) if per_kill > 0.0 else "-"]
		for index in range(values.size()):
			var cell := Label.new()
			cell.text = values[index]
			cell.add_theme_font_size_override("font_size", 13)
			if index == 3 and per_kill > 0.0:
				cell.add_theme_color_override("font_color", book.AMBER)
			drop_levels_grid.add_child(cell)
	drop_note.text = "A kill drops an item %s of the time (%s on boss levels); then the 9 gear items (weight 1.0 each) and every loot weapon share the roll by weight. Kills per run are estimated from each level's spawn settings up to its boss." % [_percent(LootOddsScript.item_chance()), _percent(LootOddsScript.item_chance("boss"))]

func _render_creature_odds(current: Dictionary) -> void:
	var chances: Dictionary = current.chances
	var best_key := ""
	for key in chances:
		if best_key.is_empty() or float(chances[key]) > float(chances[best_key]):
			best_key = key
	_add_drop_chip("Drop mode", "Per creature")
	_add_drop_chip("Best source", "%s, %s" % [CreatureDropsScript.label(best_key), _percent(float(chances[best_key]) / 100.0)])
	_add_drop_chip("Worst case", "kill %d of a %s" % [CreatureDropsScript.certain_by(float(chances[best_key]) / 100.0), CreatureDropsScript.label(best_key).to_lower()])
	for caption in ["LEVEL", "ITEM LV", "KILLS / RUN", "CHANCE PER RUN", "HALF OF PLAYERS BY"]:
		var header := Label.new()
		header.text = caption
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", book.MUTED)
		drop_levels_grid.add_child(header)
	for entry in LootOddsScript.levels():
		var in_range: bool = int(entry.item_level) >= int(current.min_item_level) and int(entry.item_level) <= int(current.max_item_level)
		var per_run := LootOddsScript.creature_per_run(chances, entry.creature_kills) if in_range else 0.0
		var runs := LootOddsScript.tries_for(per_run)
		var values := [str(entry.name), str(entry.item_level), "~%d" % int(entry.kills), _percent(per_run) if per_run > 0.0 else "can't drop", ("run %s" % _count(ceilf(runs))) if per_run > 0.0 else "-"]
		for index in range(values.size()):
			var cell := Label.new()
			cell.text = values[index]
			cell.add_theme_font_size_override("font_size", 13)
			if index == 3 and per_run > 0.0:
				cell.add_theme_color_override("font_color", book.AMBER)
			drop_levels_grid.add_child(cell)
	drop_note.text = "Each kill of a creature rolls this weapon's chance for it, smoothed like Dota 2's PRD: the first roll is lower, each miss raises the next, and it's certain by the kill shown on the card. Miss counts carry over between runs. This weapon has left the shared %s item roll." % _percent(LootOddsScript.item_chance())

func _add_drop_chip(caption: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var top := Label.new()
	top.text = caption
	top.add_theme_font_size_override("font_size", 12)
	top.add_theme_color_override("font_color", book.MUTED)
	box.add_child(top)
	var bottom := Label.new()
	bottom.text = value
	bottom.add_theme_font_size_override("font_size", 20)
	box.add_child(bottom)
	drop_odds_box.add_child(box)

static func _percent(value: float) -> String:
	var percent := value * 100.0
	if percent >= 10.0:
		return "%d%%" % roundi(percent)
	if percent >= 1.0:
		return "%.1f%%" % percent
	return "%.2f%%" % percent

static func _count(value: float) -> String:
	if is_inf(value):
		return "never"
	return str(roundi(value)) if value < 10000.0 else "%dk" % roundi(value / 1000.0)

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
	row.add_child(status_label)
	var revert_one: Button = book._button("Revert weapon", true)
	revert_one.pressed.connect(revert_selected)
	row.add_child(revert_one)
	var revert_every: Button = book._button("Revert all", true)
	revert_every.pressed.connect(revert_all)
	row.add_child(revert_every)
	save_button = book._button("Save to game data")
	save_button.name = "SaveWeapons"
	save_button.tooltip_text = "Publishes each edited weapon as its next revision."
	save_button.add_theme_stylebox_override("normal", book._button_box(book.AMBER_DEEP, book.AMBER))
	save_button.add_theme_stylebox_override("hover", book._button_box(book.AMBER, Color("f7bb58")))
	save_button.add_theme_color_override("font_color", Color("15181b"))
	save_button.add_theme_color_override("font_hover_color", Color("15181b"))
	save_button.pressed.connect(save)
	row.add_child(save_button)
	return bar

# ---------- render ----------

func _rebuild_tiles() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	for weapon_id in model.ids():
		var tile := _build_tile(weapon_id)
		tiles[weapon_id] = tile
		grid.add_child(tile)
	_filter_tiles()

func _filter_tiles() -> void:
	var query := search.text.strip_edges().to_lower()
	var shown := 0
	for weapon_id in tiles:
		var revision: Dictionary = model.revision(weapon_id)
		var haystack := ("%s %s %s %s %s" % [model.label(weapon_id), weapon_id, revision.get("weapon_type", ""), WeaponStatEditsScript.behavior_label(model.behavior(weapon_id)), model.rarity(weapon_id)]).to_lower()
		var matches := query.is_empty() or haystack.contains(query)
		tiles[weapon_id].visible = matches
		if matches:
			shown += 1
	empty_label.visible = shown == 0
	empty_label.text = "No weapons match. Try a name, type or rarity." if not tiles.is_empty() else "No weapons in the game yet."
	_sync_tile_selection()
	_refresh_marks()

func _sync_tile_selection() -> void:
	for weapon_id in tiles:
		tiles[weapon_id].set_pressed_no_signal(weapon_id == selected_id)

func _render_entry() -> void:
	var has_selection: bool = model.has_weapon(selected_id)
	entry_column.visible = has_selection
	nothing_label.visible = not has_selection
	save_button.disabled = not has_selection
	if not has_selection:
		return
	name_label.text = model.label(selected_id)
	var description: String = model.description(selected_id)
	desc_label.text = description if not description.is_empty() and description != "No description yet." else "No description yet. Write one in the Weapon Lab."
	picture.texture = texture_for(model.world_sprite_path(selected_id))
	if picture.texture == null:
		picture.texture = texture_for(model.icon_path(selected_id))
	_refresh_rows()
	_render_derived()

func _refresh_rows() -> void:
	if not model.has_weapon(selected_id):
		return
	_syncing = true
	for key in rows:
		var parts: Dictionary = rows[key]
		var definition: Dictionary = WeaponStatEditsScript.STAT_DEFS[key]
		var value: float = model.get_stat(selected_id, key)
		var saved: float = model.published_stat(selected_id, key)
		parts.slider.set_value_no_signal(value)
		parts.spin.set_value_no_signal(value)
		var changed: bool = model.is_stat_modified(selected_id, key)
		parts.label.add_theme_color_override("font_color", book.AMBER if changed else book.INK)
		parts.undo.disabled = not changed
		parts.undo.tooltip_text = "Back to the saved value (%s)" % _format(saved, key)
		var ratio := clampf(inverse_lerp(float(definition["min"]), float(definition["slider_max"]), saved), 0.0, 1.0)
		var marker: ColorRect = parts.marker
		marker.anchor_left = ratio
		marker.anchor_right = ratio
		marker.offset_left = 8.0 - 16.0 * ratio - 1.0
		marker.offset_right = 8.0 - 16.0 * ratio + 1.0
		marker.tooltip_text = "Saved: %s" % _format(saved, key)
	var behavior_index := 0
	for index in range(WeaponStatEditsScript.BEHAVIORS.size()):
		if WeaponStatEditsScript.BEHAVIORS[index][0] == model.behavior(selected_id):
			behavior_index = index
	behavior_picker.select(behavior_index)
	_syncing = false
	_refresh_drops()

func _render_derived() -> void:
	for child in derived_box.get_children():
		derived_box.remove_child(child)
		child.queue_free()
	for child in matchup_box.get_children():
		matchup_box.remove_child(child)
		child.queue_free()
	if not model.has_weapon(selected_id):
		return
	var numbers: Dictionary = model.resolved(selected_id)
	var damage := float(numbers.attack_damage)
	var rate := float(numbers.attacks_per_second)
	_add_derived("Damage per hit", _trim(damage))
	_add_derived("Attacks / s", "%.2f" % rate)
	_add_derived("Damage per second", "%.1f" % float(numbers.dps))
	_add_derived("Time between attacks", "%.2fs" % float(numbers.attack_interval))
	var capped: Array = numbers.capped
	cap_label.text = "Capped: %s. Item bonuses top out at +50%% of base damage and +30%% attack speed." % ", ".join(capped) if not capped.is_empty() else ""
	cap_label.visible = not capped.is_empty()
	_render_meta()
	for monster_id in MonsterStatsScript.monster_ids():
		matchup_box.add_child(_matchup_card(monster_id, damage, rate))

func _render_meta() -> void:
	var type_id := str(model.revision(selected_id).get("weapon_type", ""))
	var type_text := WeaponTypesScript.label_of(type_id, WeaponTypesScript.game_library()) if not type_id.is_empty() else "No type"
	meta_label.text = "%s  ·  %s  ·  %s  ·  REVISION %d" % [type_text.to_upper(), WeaponStatEditsScript.behavior_label(model.behavior(selected_id)).to_upper(), model.rarity(selected_id).to_upper(), model.revision_number(selected_id)]

## Hits and time to kill one monster (its current Encyclopedia health).
func _matchup_card(monster_id: String, damage: float, rate: float) -> Control:
	var card := PanelContainer.new()
	card.name = "Matchup_" + monster_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", book._box(Color("1b2024"), book.EDGE, 1, 4, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = true
	if book.has_method("sprite_texture"):
		icon.texture = book.sprite_texture(monster_id)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var health := MonsterStatsScript.get_stat(monster_id, "health")
	var title := Label.new()
	title.text = "%s  ·  %s HP" % [str(MonsterStatsScript.monster(monster_id).get("name", monster_id)), _trim(health)]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", book.MUTED)
	text.add_child(title)
	var hits := ceili(health / damage) if damage > 0.0 else 0
	var seconds := float(hits - 1) / rate if rate > 0.0 and hits > 0 else 0.0
	var value := Label.new()
	value.name = "Value"
	value.text = "%d %s  ·  %.1fs" % [hits, "hit" if hits == 1 else "hits", seconds] if damage > 0.0 else "can't kill"
	value.add_theme_font_size_override("font_size", 18)
	text.add_child(value)
	return card

func _add_derived(caption: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var top := Label.new()
	top.text = caption
	top.add_theme_font_size_override("font_size", 12)
	top.add_theme_color_override("font_color", book.MUTED)
	box.add_child(top)
	var bottom := Label.new()
	bottom.text = value
	bottom.add_theme_font_size_override("font_size", 20)
	box.add_child(bottom)
	derived_box.add_child(box)

func _refresh_marks() -> void:
	for weapon_id in tiles:
		tiles[weapon_id].get_node("Edited").visible = model.is_modified(weapon_id)
	var edited: int = model.modified_ids().size()
	count_label.text = "%d weapons%s" % [tiles.size(), ", %d unsaved" % edited if edited > 0 else ""]

func _set_status(text: String) -> void:
	status_label.text = text

# ---------- helpers ----------

## Published art is imported by the editor; art published this session may not
## be yet, so fall back to reading the PNG.
func texture_for(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null and FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture

func _format(value: float, key: String) -> String:
	var definition: Dictionary = WeaponStatEditsScript.STAT_DEFS[key]
	return _trim(value) + ("%" if definition.get("percent", false) else "")

static func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % value).rstrip("0").rstrip(".")
