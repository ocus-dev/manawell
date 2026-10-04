extends PanelContainer

const SalvageScript = preload("res://scripts/model/salvage.gd")
const MULTI_COLOR := Color("4fd1c5")

signal item_inspected(id: String)
signal equip_requested(hero_id: String, slot: String, instance_id: String)
signal unequip_requested(hero_id: String, slot: String)
signal lock_toggled(instance_id: String, locked: bool)
signal salvage_requested(instance_ids: Array)

var state: Dictionary = {}
var selected_id := ""
var selected_hero_id := ""
var category := "all"
var sort_mode := "recent"
var query := ""
var buttons := {}
var filters := {}
var grid: GridContainer
var summary: Label
var search: LineEdit
var sort_select: OptionButton
var equipment_pane
var detail_pane
var empty_label: Label
var grid_scroll: ScrollContainer
var _records: Array[Dictionary] = []
## Multi-select: instance ids picked for salvage.
var selection: Dictionary = {}
var select_mode := false
var select_toggle: Button
var quick_select: OptionButton
var selection_bar: HBoxContainer
var selection_label: Label
var salvage_button: Button
var clear_button: Button
var result_label: Label
var help_label: Label
var salvage_dialog: ConfirmationDialog
var salvage_dialog_text: Label
var valuable_check: CheckBox
var _pending_salvage: Array[String] = []
var _anchor_id := ""
var _visible_order: Array[String] = []
var _signature := ""

func _label(value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var heading := HBoxContainer.new()
	var title := _label("EQUIPMENT & INVENTORY", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	heading.add_child(title)
	summary = _label("")
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(summary)
	content.add_child(heading)
	var workspace := HBoxContainer.new()
	workspace.name = "InventoryWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 10)
	content.add_child(workspace)
	equipment_pane = preload("res://scripts/ui/inventory_equipment_pane.gd").new()
	equipment_pane.custom_minimum_size.x = 240
	equipment_pane.hero_selected.connect(func(id: String): selected_hero_id = id; _refresh_panes())
	equipment_pane.item_selected.connect(_inspect)
	equipment_pane.unequip_requested.connect(func(hero_id: String, slot: String): unequip_requested.emit(hero_id, slot))
	workspace.add_child(equipment_pane)
	var stash := VBoxContainer.new()
	stash.name = "SharedInventory"
	stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash.add_theme_constant_override("separation", 8)
	workspace.add_child(stash)
	var toolbar := HBoxContainer.new()
	search = LineEdit.new()
	search.placeholder_text = "Search items"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value: String): query = value.strip_edges().to_lower(); _refresh_grid())
	toolbar.add_child(search)
	sort_select = OptionButton.new()
	for label in ["Recent", "Name", "Item level", "Rarity"]:
		sort_select.add_item(label)
	sort_select.item_selected.connect(func(index: int): sort_mode = ["recent", "name", "level", "rarity"][index]; _refresh_grid())
	toolbar.add_child(sort_select)
	select_toggle = Button.new()
	select_toggle.name = "SelectToggle"
	select_toggle.text = "Select"
	select_toggle.toggle_mode = true
	select_toggle.tooltip_text = "Pick several items to salvage. Ctrl+click toggles and Shift+click selects a range at any time."
	select_toggle.toggled.connect(set_select_mode)
	toolbar.add_child(select_toggle)
	stash.add_child(toolbar)
	var filter_row := HBoxContainer.new()
	for key in ["all", "weapon", "hero", "harvester"]:
		var button := Button.new()
		button.text = {"all": "All", "weapon": "Weapons", "hero": "Chassis", "harvester": "Utility"}[key]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_filter.bind(key))
		filters[key] = button
		filter_row.add_child(button)
	stash.add_child(filter_row)
	grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.custom_minimum_size.y = 160
	stash.add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid_scroll.add_child(grid)
	empty_label = _label("No items yet. Defeat monsters to find equipment.")
	stash.add_child(empty_label)
	selection_bar = HBoxContainer.new()
	selection_bar.name = "SelectionBar"
	selection_bar.add_theme_constant_override("separation", 6)
	quick_select = OptionButton.new()
	quick_select.name = "QuickSelect"
	quick_select.add_item("Quick select…")
	for label in ["All shown", "Commons", "Magic and below", "Rare and below"]:
		quick_select.add_item(label)
	quick_select.tooltip_text = "Adds shown items to the selection. Locked and equipped items are never picked."
	quick_select.item_selected.connect(_on_quick_select)
	selection_bar.add_child(quick_select)
	selection_label = _label("", 12)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	selection_label.clip_text = true
	selection_bar.add_child(selection_label)
	clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(clear_selection)
	selection_bar.add_child(clear_button)
	salvage_button = Button.new()
	salvage_button.name = "SalvageSelected"
	salvage_button.text = "Salvage"
	salvage_button.pressed.connect(request_salvage_selection)
	selection_bar.add_child(salvage_button)
	stash.add_child(selection_bar)
	result_label = _label("", 12)
	result_label.name = "SalvageResult"
	result_label.add_theme_color_override("font_color", Color("80d9b0"))
	result_label.visible = false
	stash.add_child(result_label)
	help_label = _label("Click to compare · Ctrl/Shift+click or Select to pick several · New: ●  Equipped: E  Locked: L", 12)
	stash.add_child(help_label)
	salvage_dialog = ConfirmationDialog.new()
	salvage_dialog.name = "SalvageDialog"
	salvage_dialog.title = "Salvage items"
	salvage_dialog.ok_button_text = "Salvage"
	var dialog_column := VBoxContainer.new()
	salvage_dialog_text = _label("")
	salvage_dialog_text.custom_minimum_size.x = 380
	dialog_column.add_child(salvage_dialog_text)
	valuable_check = CheckBox.new()
	valuable_check.text = "Yes, salvage rare and epic items too"
	valuable_check.toggled.connect(func(value: bool): salvage_dialog.get_ok_button().disabled = not value)
	dialog_column.add_child(valuable_check)
	salvage_dialog.add_child(dialog_column)
	salvage_dialog.confirmed.connect(_confirm_salvage)
	add_child(salvage_dialog)
	detail_pane = preload("res://scripts/ui/inventory_detail_pane.gd").new()
	detail_pane.custom_minimum_size.x = 282
	detail_pane.equip_requested.connect(func(hero_id: String, slot: String, id: String): equip_requested.emit(hero_id, slot, id))
	detail_pane.lock_toggled.connect(func(id: String, locked: bool): lock_toggled.emit(id, locked))
	detail_pane.salvage_requested.connect(func(id: String): request_salvage([id]))
	workspace.add_child(detail_pane)
	grid_scroll.resized.connect(_layout)
	refresh(state)

func _layout() -> void:
	if grid != null:
		grid.columns = maxi(1, int((grid_scroll.size.x - 16) / 78))

func _filter(value: String) -> void:
	category = value
	_refresh_grid()

func _inspect(id: String) -> void:
	selected_id = id
	_refresh_grid()
	_refresh_panes()
	var record := _selected_record()
	if not record.is_empty():
		item_inspected.emit(str(record.get("instance_id", id)))

func _instance_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item in state.get("items", []):
		for instance in item.get("instances", []):
			var record: Dictionary = instance.duplicate(true)
			record.merge({"label": item.get("label", record.get("base_id", "")), "glyph": item.get("glyph", "?"), "category": item.get("category", "all"), "description": item.get("description", "")})
			for hero in state.get("heroes", []):
				for slot in ["weapon", "hero", "harvester"]:
					if str(hero.get("kit", {}).get(slot, "")) == str(record.get("instance_id", "")):
						record["equipped_by"] = str(hero.get("label", hero.get("id", "")))
						record["equipped_hero_id"] = str(hero.get("id", ""))
						record["equipped_slot"] = slot
			records.append(record)
	return records

func _selected_record() -> Dictionary:
	if selected_id.is_empty():
		return {}
	for record in _records:
		if str(record.get("instance_id", "")) == selected_id or (str(record.get("instance_id", "")).begins_with("legacy:") and str(record.get("base_id", "")) == selected_id):
			return record
	return {}

func _sort_records(records: Array[Dictionary]) -> void:
	records.sort_custom(func(left: Dictionary, right: Dictionary):
		if sort_mode == "name" and left.get("label", "") != right.get("label", ""):
			return str(left.get("label", "")) < str(right.get("label", ""))
		if sort_mode == "level" and left.get("item_level", 0) != right.get("item_level", 0):
			return int(left.get("item_level", 0)) > int(right.get("item_level", 0))
		if sort_mode == "rarity":
			var ranks := {"common": 0, "magic": 1, "rare": 2, "epic": 3}
			if ranks.get(left.get("rarity", ""), 0) != ranks.get(right.get("rarity", ""), 0):
				return ranks.get(left.get("rarity", ""), 0) > ranks.get(right.get("rarity", ""), 0)
		return str(left.get("instance_id", "")) > str(right.get("instance_id", "")))

func _make_item_button(record: Dictionary) -> Button:
	var id := str(record.get("instance_id", ""))
	var button := Button.new()
	button.name = "Item_" + id.replace(".", "_").replace(":", "_")
	button.custom_minimum_size = Vector2(72, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = preload("res://scripts/ui/item_icons.gd").texture(str(record.get("base_id", "")))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 56)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 11)
	button.toggle_mode = true
	var selected_key := str(record.get("base_id", "")) if id.begins_with("legacy:") else id
	button.pressed.connect(_on_item_pressed.bind(id, selected_key))
	grid.add_child(button)
	buttons[id] = button
	var base_id := str(record.get("base_id", ""))
	if not buttons.has(base_id):
		buttons[base_id] = button
	return button

func _refresh_grid() -> void:
	if grid == null:
		return
	for key in filters:
		filters[key].set_pressed_no_signal(key == category)
	var records := _records.duplicate()
	_sort_records(records)
	var live := {}
	var count := 0
	_visible_order.clear()
	for record in records:
		var id := str(record.get("instance_id", ""))
		live[id] = true
		var button: Button = buttons.get(id)
		if button == null:
			button = _make_item_button(record)
		grid.move_child(button, grid.get_child_count() - 1)
		button.visible = (category == "all" or record.get("category", "") == category) and (query.is_empty() or (str(record.get("label", "")) + " " + str(record.get("rarity", ""))).to_lower().contains(query))
		if button.visible:
			count += 1
			_visible_order.append(id)
		var picked := selection.has(id)
		button.set_pressed_no_signal(picked or str(_selected_record().get("instance_id", "")) == id)
		var markers := "✓ " if picked else ""
		if not bool(record.get("inspected", true)):
			markers += "● "
		if not str(record.get("equipped_by", "")).is_empty():
			markers += "E "
		if bool(record.get("locked", false)):
			markers += "L "
		button.text = "%sLv %d" % [markers, int(record.get("item_level", 1))]
		button.tooltip_text = "%s · %s · Level %d\n%s" % [record.get("label", "Item"), str(record.get("rarity", "common")).capitalize(), int(record.get("item_level", 1)), record.get("description", "")]
		var color: Color = {"common": Color("75848d"), "magic": Color("65aaff"), "rare": Color("e6c36a"), "epic": Color("c18cff")}.get(record.get("rarity", "common"), Color("75848d"))
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("1d3b3d") if picked else Color("243441") if style_name.contains("pressed") else Color("17232c")
			style.border_color = MULTI_COLOR if picked and style_name != "focus" else Color.WHITE if style_name == "focus" else color
			style.set_border_width_all(3 if picked else 2 if style_name != "normal" else 1)
			style.set_corner_radius_all(4)
			button.add_theme_stylebox_override(style_name, style)
	for child in grid.get_children():
		var found := false
		for id in live:
			if buttons.get(id) == child:
				found = true
				break
		if not found:
			child.visible = false
	empty_label.visible = count == 0
	empty_label.text = "No items yet. Defeat monsters to find equipment." if _records.is_empty() else "No items match these filters."
	_refresh_selection_bar()
	_layout()

func _refresh_panes() -> void:
	var record := _selected_record()
	equipment_pane.refresh(state, _records, selected_hero_id, record)
	detail_pane.refresh(state, _records, selected_hero_id, record)

func refresh(value: Dictionary) -> void:
	state = value.duplicate(true)
	if summary == null:
		return
	var signature := JSON.stringify(state)
	if signature == _signature:
		return
	_signature = signature
	var heroes: Array = state.get("heroes", [])
	var valid_hero := false
	for hero in heroes:
		if str(hero.get("id", "")) == selected_hero_id:
			valid_hero = true
	if not valid_hero:
		selected_hero_id = str(state.get("selected_hero_id", ""))
		if selected_hero_id.is_empty() and not heroes.is_empty():
			selected_hero_id = str(heroes[0].get("id", ""))
	_records = _instance_records()
	if not selected_id.is_empty() and _selected_record().is_empty():
		selected_id = ""
	_prune_selection()
	summary.text = "%d / %d items · %d new · Scrap %d" % [int(state.get("stored_count", 0)), int(state.get("capacity", 500)), int(state.get("new_count", 0)), int(state.get("scrap", 0))]
	_refresh_grid()
	_refresh_panes()

func _record_for(instance_id: String) -> Dictionary:
	for record in _records:
		if str(record.get("instance_id", "")) == instance_id:
			return record
	return {}

func _mutation_allowed() -> bool:
	return bool(state.get("mutation_allowed", true))

## Why this item can't be picked for salvage ("" when it can).
func salvage_blocker(record: Dictionary) -> String:
	if record.is_empty():
		return "Unknown item."
	if not _mutation_allowed():
		return "Salvage is unavailable during a run."
	if bool(record.get("locked", false)):
		return "Locked items can't be salvaged."
	if not str(record.get("equipped_by", "")).is_empty():
		return "Equipped items can't be salvaged."
	return ""

func _on_item_pressed(instance_id: String, inspect_key: String) -> void:
	var ctrl := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	var shift := Input.is_key_pressed(KEY_SHIFT)
	if shift and not _anchor_id.is_empty():
		select_range(_anchor_id, instance_id)
	elif select_mode or ctrl:
		toggle_selected(instance_id)
	else:
		_anchor_id = instance_id
	_inspect(inspect_key)

## Add or remove one item from the multi-selection.
func toggle_selected(instance_id: String) -> bool:
	_anchor_id = instance_id
	if selection.has(instance_id):
		selection.erase(instance_id)
		_refresh_grid()
		return true
	var reason := salvage_blocker(_record_for(instance_id))
	if not reason.is_empty():
		_show_message(reason, false)
		_refresh_grid()
		return false
	selection[instance_id] = true
	_refresh_grid()
	return true

## Select every eligible shown item between two items (inclusive).
func select_range(from_id: String, to_id: String) -> void:
	var a := _visible_order.find(from_id)
	var b := _visible_order.find(to_id)
	if a < 0 or b < 0:
		toggle_selected(to_id)
		return
	for index in range(mini(a, b), maxi(a, b) + 1):
		var id := _visible_order[index]
		if salvage_blocker(_record_for(id)).is_empty():
			selection[id] = true
	_refresh_grid()

## Pick shown, salvageable items at or below a rarity ("" = any rarity).
func select_shown(max_rarity: String = "") -> int:
	var ranks := {"common": 0, "magic": 1, "rare": 2, "epic": 3}
	var added := 0
	for id in _visible_order:
		var record := _record_for(id)
		if not salvage_blocker(record).is_empty() or selection.has(id):
			continue
		if not max_rarity.is_empty() and int(ranks.get(str(record.get("rarity", "common")), 0)) > int(ranks.get(max_rarity, 0)):
			continue
		selection[id] = true
		added += 1
	_refresh_grid()
	return added

func _on_quick_select(index: int) -> void:
	quick_select.select(0)
	if index <= 0:
		return
	var added := select_shown(["", "", "common", "magic", "rare"][index])
	if added == 0:
		_show_message("Nothing new to select here.", false)

func clear_selection() -> void:
	selection.clear()
	_refresh_grid()

func set_select_mode(value: bool) -> void:
	select_mode = value
	if select_toggle != null:
		select_toggle.set_pressed_no_signal(value)
	if not value:
		selection.clear()
	_refresh_grid()

func selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _visible_order:
		if selection.has(id):
			ids.append(id)
	for id in selection:
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids

## Drop picks that vanished or became locked/equipped.
func _prune_selection() -> void:
	for id in selection.keys():
		if not salvage_blocker(_record_for(str(id))).is_empty():
			selection.erase(id)

func _refresh_selection_bar() -> void:
	if selection_bar == null:
		return
	var active := select_mode or not selection.is_empty()
	selection_bar.visible = active
	help_label.visible = not active
	var records: Array = []
	for id in selection:
		records.append(_record_for(str(id)))
	var total := SalvageScript.total_for(records)
	selection_label.text = "%d selected · %s" % [records.size(), SalvageScript.describe(total)] if not records.is_empty() else "Click items to select them"
	salvage_button.text = "Salvage (%d)" % records.size() if not records.is_empty() else "Salvage"
	salvage_button.disabled = records.is_empty() or not _mutation_allowed()
	clear_button.disabled = records.is_empty()

func request_salvage_selection() -> void:
	request_salvage(selected_ids())

## Ask to confirm salvaging these items. Blocked items are left out.
func request_salvage(instance_ids: Array) -> void:
	_pending_salvage.clear()
	var records: Array = []
	var skipped := 0
	var valuable := 0
	for value in instance_ids:
		var id := str(value)
		var record := _record_for(id)
		if not salvage_blocker(record).is_empty():
			skipped += 1
			continue
		_pending_salvage.append(id)
		records.append(record)
		if SalvageScript.is_valuable(record):
			valuable += 1
	if records.is_empty():
		_show_message("Nothing to salvage: locked and equipped items are kept.", false)
		return
	var total := SalvageScript.total_for(records)
	var subject := str(records[0].get("label", "this item")) if records.size() == 1 else "%d items" % records.size()
	var lines: Array[String] = ["Salvage %s for %s?" % [subject, SalvageScript.describe(total)], "Salvaged items are gone for good."]
	if skipped > 0:
		lines.append("%d locked or equipped item%s will be kept." % [skipped, "" if skipped == 1 else "s"])
	if valuable > 0:
		lines.append("Includes %d rare or epic item%s." % [valuable, "" if valuable == 1 else "s"])
	salvage_dialog_text.text = "\n".join(lines)
	valuable_check.visible = valuable > 0
	valuable_check.set_pressed_no_signal(false)
	salvage_dialog.get_ok_button().disabled = valuable > 0
	salvage_dialog.reset_size()
	salvage_dialog.popup_centered(Vector2i(420, 0))

func _confirm_salvage() -> void:
	if _pending_salvage.is_empty() or salvage_dialog.get_ok_button().disabled:
		return
	var ids: Array = _pending_salvage.duplicate()
	_pending_salvage.clear()
	salvage_requested.emit(ids)

## Called with the account's salvage result once the request is handled.
func show_salvage_result(result: Dictionary) -> void:
	var salvaged: Array = result.get("salvaged", [])
	for id in salvaged:
		selection.erase(str(id))
	if salvaged.is_empty():
		var skipped: Dictionary = result.get("skipped", {})
		_show_message(str(skipped.values()[0]) if not skipped.is_empty() else "Nothing was salvaged.", false)
	else:
		_show_message("Salvaged %d item%s · +%s" % [salvaged.size(), "" if salvaged.size() == 1 else "s", SalvageScript.describe(result)], true)
	_refresh_grid()

func _show_message(text: String, success: bool) -> void:
	if result_label == null:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color", Color("80d9b0") if success else Color("efb27a"))
	result_label.visible = not text.is_empty()

## Salvage the item shown in the detail pane (asks to confirm first).
func request_salvage_inspected() -> void:
	detail_pane.request_salvage()
