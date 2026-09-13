extends PanelContainer

signal hero_selected(id: String)
signal item_selected(instance_id: String)
signal unequip_requested(hero_id: String, slot: String)

const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const Icons = preload("res://scripts/ui/item_icons.gd")
const Portraits = preload("res://scripts/ui/hero_portraits.gd")
const SLOT_NAMES := {"weapon": "WEAPON", "hero": "CHASSIS", "harvester": "UTILITY"}
var hero_select: OptionButton
var slot_buttons: Dictionary = {}
var remove_buttons: Dictionary = {}
var stat_values: Dictionary = {}
var portrait: Label
var mode_label: Label
var _hero_id := ""
var _kit: Dictionary = {}
var _hero_options: Array = []

func _label(value: String, font_size: int = 13) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18252d") if active else Color("111b22")
	style.border_color = Color("dab26d") if active else Color("364b57")
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	return style

func _ready() -> void:
	custom_minimum_size.x = 240
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	content.add_child(_label("EQUIPMENT", 16))
	hero_select = OptionButton.new()
	hero_select.custom_minimum_size.y = 30
	hero_select.item_selected.connect(_select_hero)
	content.add_child(hero_select)
	portrait = _label("HERO", 20)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.custom_minimum_size.y = 64
	content.add_child(portrait)
	for slot in SLOT_NAMES:
		var row := HBoxContainer.new()
		content.add_child(row)
		var button := Button.new()
		button.name = "Slot_" + slot
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_inspect_slot.bind(slot))
		row.add_child(button)
		slot_buttons[slot] = button
		var remove := Button.new()
		remove.text = "−"
		remove.custom_minimum_size.x = 28
		remove.tooltip_text = "Unequip " + str(SLOT_NAMES[slot]).to_lower()
		remove.pressed.connect(func(): unequip_requested.emit(_hero_id, slot))
		row.add_child(remove)
		remove_buttons[slot] = remove
	content.add_child(HSeparator.new())
	content.add_child(_label("EFFECTIVE STATS", 13))
	mode_label = _label("", 11)
	mode_label.modulate = Color("9ab0bc")
	content.add_child(mode_label)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("v_separation", 2)
	content.add_child(stats)
	for key in {"attack_damage": "Attack / projectile", "attacks_per_second": "Attacks / second", "max_health": "Health", "armor": "Armor", "move_speed": "Move speed", "mining_bonus": "Mining bonus", "drop_bonus": "Drop bonus"}:
		var names := {"attack_damage": "Attack / projectile", "attacks_per_second": "Attacks / second", "max_health": "Health", "armor": "Armor", "move_speed": "Move speed", "mining_bonus": "Mining bonus", "drop_bonus": "Drop bonus"}
		var caption := _label(names[key], 11)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(caption)
		var value := _label("—", 11)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.add_child(value)
		stat_values[key] = value

func _select_hero(index: int) -> void:
	if index >= 0 and index < hero_select.item_count:
		hero_selected.emit(str(hero_select.get_item_metadata(index)))

func _inspect_slot(slot: String) -> void:
	var id := str(_kit.get(slot, ""))
	if not id.is_empty():
		item_selected.emit(id)

func refresh(state: Dictionary, records: Array, hero_id: String, selected_record: Dictionary) -> void:
	_hero_id = hero_id
	if hero_select == null:
		return
	var heroes: Array = state.get("heroes", [])
	var options: Array = []
	var hero: Dictionary = {}
	for entry in heroes:
		options.append([str(entry.get("id", "")), str(entry.get("label", "Hero"))])
		if str(entry.get("id", "")) == hero_id:
			hero = entry
	if options != _hero_options:
		_hero_options = options.duplicate(true)
		hero_select.clear()
		for option in options:
			hero_select.add_item(option[1])
			hero_select.set_item_metadata(hero_select.item_count - 1, option[0])
	for index in range(hero_select.item_count):
		if str(hero_select.get_item_metadata(index)) == hero_id:
			hero_select.select(index)
	portrait.text = str(hero.get("label", "No hero"))
	Portraits.apply(portrait, hero_id)
	_kit = hero.get("kit", {})
	for slot in SLOT_NAMES:
		var id := str(_kit.get(slot, ""))
		var record: Dictionary = {}
		for candidate in records:
			if str(candidate.get("instance_id", "")) == id:
				record = candidate
		var button: Button = slot_buttons[slot]
		button.text = "%s\n%s" % [SLOT_NAMES[slot], str(record.get("label", "Empty slot"))]
		button.icon = Icons.texture(str(record.get("base_id", "")))
		button.tooltip_text = "%s: %s" % [SLOT_NAMES[slot], str(record.get("label", "Empty — select a compatible item to equip"))]
		button.disabled = id.is_empty()
		var compatible: bool = not selected_record.is_empty() and str(selected_record.get("category", "")) == str(slot)
		button.add_theme_stylebox_override("normal", _style(compatible))
		button.add_theme_stylebox_override("disabled", _style(compatible))
		remove_buttons[slot].disabled = id.is_empty() or not bool(state.get("mutation_allowed", true))
	var resolver_input: Dictionary = state.get("hero_resolver", {}).duplicate(true)
	resolver_input["hero_kit"] = _kit
	var resolved := Resolver.compare_slot(resolver_input, "weapon", str(_kit.get("weapon", "")))
	var values: Dictionary = resolved.get("stats", {})
	for key in stat_values:
		var value := float(values.get(key, 0.0))
		stat_values[key].text = "+%.0f%%" % (value * 100.0) if key in ["mining_bonus", "drop_bonus"] else "%.1f" % value
	mode_label.text = "%s · %d projectile%s" % [str(values.get("weapon_mode_id", "weapon.standard")).trim_prefix("weapon.").capitalize(), int(values.get("weapon_projectile_count", 1)), "s" if int(values.get("weapon_projectile_count", 1)) != 1 else ""]
