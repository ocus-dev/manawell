extends PanelContainer

const HeroStatResolver = preload("res://scripts/model/hero_stat_resolver.gd")

signal item_inspected(id: String)
signal equip_requested(hero_id: String, slot: String, instance_id: String)
signal unequip_requested(hero_id: String, slot: String)
signal lock_toggled(instance_id: String, locked: bool)
signal discard_requested(instance_id: String, confirmed_name: String)

var state: Dictionary = {}
var selected_id := ""
var selected_hero_id := ""
var category := "all"
var sort_mode := "recent"
var buttons := {}
var filters := {}
var grid: GridContainer
var summary: Label
var item_title: Label
var detail: Label
var hero_select: OptionButton
var sort_select: OptionButton
var slots_box: VBoxContainer
var stats: Label
var preview: Label
var actions: HBoxContainer
var discard_dialog: ConfirmationDialog
var discard_name: LineEdit

func text(value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	content.add_child(text("INVENTORY", 22))
	summary = text("")
	content.add_child(summary)
	var controls := HBoxContainer.new()
	content.add_child(controls)
	for key in ["all", "weapon", "hero", "harvester"]:
		var button := Button.new()
		button.text = key.capitalize()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_filter.bind(key))
		filters[key] = button
		controls.add_child(button)
	sort_select = OptionButton.new()
	sort_select.add_item("Recent")
	sort_select.add_item("Name")
	sort_select.add_item("Item level")
	sort_select.item_selected.connect(func(index: int): sort_mode = ["recent", "name", "level"][index]; refresh(state))
	controls.add_child(sort_select)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 230
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	content.add_child(scroll)
	content.add_child(HSeparator.new())
	var hero_row := HBoxContainer.new()
	hero_row.add_child(text("Hero", 15))
	hero_select = OptionButton.new()
	hero_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_select.item_selected.connect(_hero_selected)
	hero_row.add_child(hero_select)
	content.add_child(hero_row)
	slots_box = VBoxContainer.new()
	content.add_child(slots_box)
	item_title = text("Select an item", 18)
	detail = text("Select an item to inspect its actual rolls.")
	content.add_child(item_title)
	content.add_child(detail)
	stats = text("")
	content.add_child(stats)
	preview = text("")
	content.add_child(preview)
	actions = HBoxContainer.new()
	content.add_child(actions)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Discard item"
	discard_dialog.ok_button_text = "Discard"
	discard_name = LineEdit.new()
	discard_name.placeholder_text = "Type the item name to confirm"
	discard_dialog.add_child(discard_name)
	discard_dialog.confirmed.connect(_confirm_discard)
	add_child(discard_dialog)
	resized.connect(_layout)
	_layout()
	refresh(state)

func _layout() -> void:
	if grid != null:
		grid.columns = 3 if size.x >= 650 else 2 if size.x >= 420 else 1

func _filter(value: String) -> void:
	category = value
	selected_id = ""
	refresh(state)

func _hero_selected(index: int) -> void:
	if index >= 0 and index < hero_select.item_count:
		selected_hero_id = str(hero_select.get_item_metadata(index))
		refresh(state)

func _inspect(id: String) -> void:
	selected_id = id
	refresh(state)
	item_inspected.emit(id)

func _instance_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item in state.get("items", []):
		for instance in item.get("instances", []):
			var record: Dictionary = instance.duplicate(true)
			record.merge({"label": item.get("label", record.get("base_id", "")), "glyph": item.get("glyph", "?"), "category": item.get("category", "all"), "description": item.get("description", "")})
			for hero in state.get("heroes", []):
				for slot in ["weapon", "hero", "harvester"]:
					if str(hero.get("kit", {}).get(slot, "")) == str(record.get("instance_id", "")):
						record["equipped_by"] = "%s · %s" % [hero.get("label", hero.get("id", "")), slot]
			records.append(record)
	return records

func _sort_records(records: Array[Dictionary]) -> void:
	if sort_mode == "name":
		records.sort_custom(func(left: Dictionary, right: Dictionary): return str(left.get("label", "")) < str(right.get("label", "")))
	elif sort_mode == "level":
		records.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("item_level", 0)) > int(right.get("item_level", 0)))
	else:
		records.sort_custom(func(left: Dictionary, right: Dictionary): return str(left.get("instance_id", "")) > str(right.get("instance_id", "")))

func _make_item_button(record: Dictionary) -> Button:
	var id := str(record.get("instance_id", ""))
	var selected_key := str(record.get("base_id", "")) if id.begins_with("legacy:") else id
	var button := Button.new()
	button.name = "Item_" + id.replace(".", "_").replace(":", "_")
	button.custom_minimum_size = Vector2(180, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = preload("res://scripts/ui/item_icons.gd").texture(str(record.get("base_id", "")))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 48)
	button.toggle_mode = true
	button.pressed.connect(_inspect.bind(selected_key))
	grid.add_child(button)
	buttons[id] = button
	var base_id := str(record.get("base_id", ""))
	if not base_id.is_empty() and not buttons.has(base_id):
		buttons[base_id] = button
	return button

func refresh(value: Dictionary) -> void:
	state = value.duplicate(true)
	if summary == null:
		return
	if selected_hero_id.is_empty():
		selected_hero_id = str(state.get("selected_hero_id", ""))
	summary.text = "%d / %d stored  ·  %d new  ·  %s" % [int(state.get("stored_count", 0)), int(state.get("capacity", 100)), int(state.get("new_count", 0)), "Inventory full" if int(state.get("stored_count", 0)) >= int(state.get("capacity", 100)) else "Collected items are kept after failed extraction"]
	for index in range(hero_select.item_count):
		pass
	hero_select.clear()
	for hero in state.get("heroes", []):
		hero_select.add_item(str(hero.get("label", hero.get("id", "Hero"))))
		hero_select.set_item_metadata(hero_select.item_count - 1, str(hero.get("id", "")))
	for index in range(hero_select.item_count):
		if str(hero_select.get_item_metadata(index)) == selected_hero_id:
			hero_select.select(index)
	for key in filters:
		filters[key].set_pressed_no_signal(key == category)
	var records := _instance_records()
	_sort_records(records)
	var visible_ids := {}
	for record in records:
		var id := str(record.get("instance_id", ""))
		visible_ids[id] = true
		var button: Button = buttons.get(id)
		if button == null:
			button = _make_item_button(record)
		button.visible = category == "all" or record.get("category", "") == category
		button.set_pressed_no_signal(selected_id == id)
		var rarity := str(record.get("rarity", "common")).capitalize()
		var state_label := "EQUIPPED · %s" % str(record.get("equipped_by", "")) if not str(record.get("equipped_by", "")).is_empty() else "LOCKED" if bool(record.get("locked", false)) else "NEW" if not bool(record.get("inspected", true)) else "Ready"
		var item_label := str(record.get("label", "Item"))
		if button.icon == null:
			item_label = "[%s] %s" % [str(record.get("glyph", "?")), item_label]
		button.text = "%s\n%s · Lv %d\n%s" % [item_label, rarity, int(record.get("item_level", 1)), state_label]
		button.tooltip_text = str(record.get("description", ""))
	for id in buttons:
		if id.contains(":") and not visible_ids.has(id):
			buttons[id].visible = false
	_render_details(records)

func _render_details(records: Array[Dictionary]) -> void:
	_render_slots()
	for child in actions.get_children():
		child.queue_free()
	if selected_id.is_empty():
		item_title.text = "Select an item"
		detail.text = "Select an item to inspect its actual rolls."
		return
	for record in records:
		if str(record.get("instance_id", "")) != selected_id and str(record.get("base_id", "")) != selected_id:
			continue
		item_title.text = "%s · %s · Lv %d" % [str(record.get("label", "Item")), str(record.get("rarity", "common")).capitalize(), int(record.get("item_level", 1))]
		var base_id := str(record.get("base_id", ""))
		var slot := "weapon" if base_id.begins_with("core.") else "hero" if base_id.begins_with("chassis.") else "harvester"
		var equip := Button.new()
		equip.text = "Equip to %s" % selected_hero_id
		equip.pressed.connect(equip_requested.emit.bind(selected_hero_id, slot, selected_id))
		actions.add_child(equip)
		var lock := CheckButton.new()
		lock.text = "Locked"
		lock.button_pressed = bool(record.get("locked", false))
		lock.toggled.connect(func(value: bool): lock_toggled.emit(selected_id, value))
		actions.add_child(lock)
		var discard := Button.new()
		discard.text = "Discard"
		discard.pressed.connect(request_discard)
		discard.disabled = not str(record.get("equipped_by", "")).is_empty() or bool(record.get("locked", false))
		actions.add_child(discard)
		var rolls: Array[String] = []
		for modifier in record.get("implicit_modifiers", []):
			rolls.append("Implicit: %s %s" % [str(modifier.get("stat", "")), str(modifier.get("value", ""))])
		for modifier in record.get("explicit_modifiers", []):
			rolls.append("Roll: %s %s" % [str(modifier.get("affix_id", "")), str(modifier.get("value", ""))])
		detail.text = "%s\n%s\n%s" % [str(record.get("description", "")), "\n".join(rolls), "Equipped by %s" % str(record.get("equipped_by", "")) if not str(record.get("equipped_by", "")).is_empty() else "Unequipped"]
		_render_preview(record)
		return

func _render_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()
	var hero: Dictionary = {}
	for candidate in state.get("heroes", []):
		if str(candidate.get("id", "")) == selected_hero_id:
			hero = candidate
	var kit: Dictionary = hero.get("kit", {})
	for slot in ["weapon", "hero", "harvester"]:
		var row := HBoxContainer.new()
		var label := text("%s: %s" % [slot.capitalize(), str(kit.get(slot, "Empty")) if not str(kit.get(slot, "")).is_empty() else "Empty"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var unequip := Button.new()
		unequip.text = "Unequip"
		unequip.disabled = str(kit.get(slot, "")).is_empty()
		unequip.pressed.connect(unequip_requested.emit.bind(selected_hero_id, slot))
		row.add_child(unequip)
		slots_box.add_child(row)

func _render_preview(record: Dictionary) -> void:
	var instance_id := str(record.get("instance_id", ""))
	var equipped_slot := ""
	var base_id := str(record.get("base_id", ""))
	if base_id.begins_with("core."):
		equipped_slot = "weapon"
	elif base_id.begins_with("chassis."):
		equipped_slot = "hero"
	elif base_id.begins_with("module."):
		equipped_slot = "harvester"
	if equipped_slot.is_empty():
		preview.text = ""
		return
	var hero: Dictionary = {}
	for candidate in state.get("heroes", []):
		if str(candidate.get("id", "")) == selected_hero_id:
			hero = candidate
	var input: Dictionary = state.get("hero_resolver", {}).duplicate(true)
	input["hero_kit"] = hero.get("kit", {})
	input["weapon_mode_id"] = "weapon.standard"
	var result := HeroStatResolver.compare_slot(input, equipped_slot, instance_id)
	var values: Array[String] = []
	for stat in ["attack_damage", "max_health", "move_speed", "armor", "mining_bonus"]:
		values.append("%s: %s" % [stat, str(result.stats.get(stat, ""))])
	preview.text = "Preview (%s)\n%s" % [equipped_slot, " · ".join(values)]

func request_discard() -> void:
	if selected_id.is_empty():
		return
	discard_name.text = ""
	discard_dialog.dialog_text = "Type the exact item name to discard it. This cannot be undone."
	discard_dialog.popup_centered()

func _confirm_discard() -> void:
	discard_requested.emit(selected_id, discard_name.text)
