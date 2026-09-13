extends PanelContainer

const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const Icons = preload("res://scripts/ui/item_icons.gd")
const STAT_LABELS := {"attack_damage": "Attack", "attacks_per_second": "Attacks / sec", "armor": "Armor", "max_health": "Health", "move_speed": "Move speed", "vision_radius": "Vision", "health_regen": "Health / sec", "mining_bonus": "Mining bonus", "drop_bonus": "Drop bonus", "projectile_speed": "Projectile speed", "damage_vs.swarm": "Damage vs swarm", "damage_vs.armored": "Damage vs armored", "damage_vs.guardian": "Damage vs guardian", "resistance.fire": "Fire resistance", "resistance.shock": "Shock resistance", "resistance.toxin": "Toxin resistance"}
const COLORS := {"common": Color("bdc6cf"), "magic": Color("71bfff"), "rare": Color("e6c46c"), "epic": Color("c292ed")}

signal equip_requested(hero_id: String, slot: String, instance_id: String)
signal lock_toggled(instance_id: String, locked: bool)
signal discard_requested(instance_id: String, confirmed_name: String)

var item_title: Label
var detail: Label
var preview: RichTextLabel
var icon: TextureRect
var metadata: Label
var status: Label
var equip_button: Button
var lock_button: CheckButton
var discard_button: Button
var discard_dialog: ConfirmationDialog
var discard_name: LineEdit
var _record: Dictionary = {}
var _hero_id := ""
var _slot := ""
var _pending_discard_id := ""
var _pending_discard_label := ""

func _label(value: String, font_size: int = 14) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	return result

func _ready() -> void:
	custom_minimum_size.x = 282
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111b22")
	panel_style.border_color = Color("364b57")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	column.add_child(_label("ITEM DETAILS", 13))
	var heading := HBoxContainer.new()
	column.add_child(heading)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(66, 66)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(icon)
	item_title = _label("Select an item", 19)
	item_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(item_title)
	metadata = _label("")
	column.add_child(metadata)
	column.add_child(HSeparator.new())
	detail = _label("Select an item in your inventory to see its rolls and compare equipment.")
	column.add_child(detail)
	column.add_child(HSeparator.new())
	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = false
	preview.custom_minimum_size.y = 112
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_theme_font_size_override("normal_font_size", 13)
	preview.add_theme_font_size_override("bold_font_size", 13)
	column.add_child(preview)
	status = _label("", 12)
	column.add_child(status)
	equip_button = Button.new()
	equip_button.text = "Equip"
	_compact_button(equip_button)
	equip_button.pressed.connect(_equip)
	column.add_child(equip_button)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	lock_button = CheckButton.new()
	lock_button.text = "Locked"
	lock_button.add_theme_font_size_override("font_size", 13)
	lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.toggled.connect(_lock)
	actions.add_child(lock_button)
	discard_button = Button.new()
	discard_button.text = "Discard"
	_compact_button(discard_button)
	discard_button.pressed.connect(request_discard)
	actions.add_child(discard_button)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Discard item"
	discard_dialog.ok_button_text = "Discard"
	discard_name = LineEdit.new()
	discard_name.placeholder_text = "Exact item name"
	discard_dialog.add_child(discard_name)
	discard_name.text_changed.connect(func(value: String): discard_dialog.get_ok_button().disabled = value != _pending_discard_label)
	discard_dialog.confirmed.connect(_confirm_discard)
	add_child(discard_dialog)
	refresh({}, [], "", {})

func _compact_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 13)
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := get_theme_stylebox(key, "Button").duplicate() as StyleBox
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(key, style)

func refresh(state: Dictionary, _records: Array, hero_id: String, selected_record: Dictionary) -> void:
	_record = selected_record.duplicate(true)
	_hero_id = hero_id
	if item_title == null:
		return
	var id := str(_record.get("instance_id", ""))
	if discard_dialog.visible and (id != _pending_discard_id or bool(_record.get("locked", false)) or not str(_record.get("equipped_hero_id", "")).is_empty() or not bool(state.get("mutation_allowed", true))):
		discard_dialog.hide()
	var has_item := not id.is_empty()
	icon.texture = Icons.texture(str(_record.get("base_id", ""))) if has_item else null
	item_title.text = str(_record.get("label", "Item")) if has_item else "Select an item"
	var rarity := str(_record.get("rarity", "common"))
	item_title.add_theme_color_override("font_color", COLORS.get(rarity, COLORS.common))
	_slot = str(Definitions.PRODUCTION_BASES.get(str(_record.get("base_id", "")), {}).get("slot", _record.get("category", "")))
	metadata.text = "%s · Level %d · %s" % [rarity.capitalize(), int(_record.get("item_level", 1)), {"weapon": "Weapon", "hero": "Chassis", "harvester": "Utility"}.get(_slot, "Item")] if has_item else ""
	var lines: Array[String] = []
	for modifier in _record.get("implicit_modifiers", []):
		lines.append(_roll(str(modifier.get("stat", "")), str(modifier.get("operation", "flat")), float(modifier.get("value", 0))) + "  (base)")
	for modifier in _record.get("explicit_modifiers", []):
		var affix: Dictionary = Definitions.PRODUCTION_AFFIXES.get(str(modifier.get("affix_id", "")), {})
		lines.append(_roll(str(affix.get("stat", "")), str(affix.get("operation", "flat")), float(modifier.get("value", 0))))
	detail.text = "\n".join(lines) if has_item else "Select an item to inspect its rolls and compare equipment."
	detail.tooltip_text = str(_record.get("description", ""))
	var hero: Dictionary = {}
	for candidate in state.get("heroes", []):
		if str(candidate.get("id", "")) == hero_id:
			hero = candidate
	var owner := str(_record.get("equipped_hero_id", ""))
	var equipped_here := owner == hero_id and not owner.is_empty()
	var allowed := bool(state.get("mutation_allowed", true))
	equip_button.disabled = not has_item or not allowed or hero.is_empty() or not owner.is_empty()
	equip_button.text = "Equipped" if equipped_here else "Equip to " + str(hero.get("label", "hero"))
	lock_button.disabled = not has_item or not allowed
	lock_button.set_pressed_no_signal(bool(_record.get("locked", false)))
	discard_button.disabled = not has_item or not allowed or not owner.is_empty() or bool(_record.get("locked", false))
	status.text = ""
	if has_item:
		if not allowed:
			status.text = "Equipment changes are unavailable during a run."
		elif not owner.is_empty() and not equipped_here:
			var owner_label := owner
			for candidate in state.get("heroes", []):
				if str(candidate.get("id", "")) == owner:
					owner_label = str(candidate.get("label", owner))
			status.text = "Equipped by %s. Unequip there first." % owner_label
		elif equipped_here:
			status.text = "Currently equipped. Use its slot to unequip."
		elif bool(_record.get("locked", false)):
			status.text = "Locked items cannot be discarded."
		else:
			status.text = "Replaced gear stays in your inventory."
	preview.text = _comparison(state, hero, id) if has_item and not hero.is_empty() else ""

func _comparison(state: Dictionary, hero: Dictionary, id: String) -> String:
	var input: Dictionary = state.get("hero_resolver", {}).duplicate(true)
	input["hero_kit"] = hero.get("kit", {}).duplicate(true)
	input["instances"] = input.get("instances", state.get("instances", {}))
	var current_id := str(input.hero_kit.get(_slot, ""))
	var before: Dictionary = Resolver.compare_slot(input, _slot, current_id).stats
	var after: Dictionary = Resolver.compare_slot(input, _slot, id).stats
	var lines: Array[String] = ["[b]EFFECTIVE STATS · CURRENT → EQUIPPED[/b]"]
	for stat in Definitions.STAT_NAMES:
		var a := _value(before, stat)
		var b := _value(after, stat)
		if is_equal_approx(a, b):
			continue
		var tint := "#80d9b0" if b > a else "#ef9696"
		lines.append("%s  %s → [color=%s]%s[/color]" % [STAT_LABELS.get(stat, stat), _number(a, _percent(stat)), tint, _number(b, _percent(stat))])
	if lines.size() == 1:
		lines.append("Already equipped." if current_id == id else "No effective stat change (caps included).")
	return "\n".join(lines)

static func _value(stats: Dictionary, stat: String) -> float:
	if stat.begins_with("damage_vs."):
		return float(stats.get("damage_vs", {}).get(stat.trim_prefix("damage_vs."), 0))
	return float(stats.get(stat, 0))

static func _percent(stat: String) -> bool:
	return stat in ["mining_bonus", "drop_bonus"] or stat.begins_with("damage_vs.") or stat.begins_with("resistance.")

static func _number(value: float, percent: bool = false) -> String:
	var result := "%.2f" % (value * 100.0 if percent else value)
	result = result.trim_suffix("0").trim_suffix("0").trim_suffix(".")
	return result + ("%" if percent else "")

static func _roll(stat: String, operation: String, value: float) -> String:
	return "+%s %s%s" % [_number(value, operation == "increased" or _percent(stat)), "increased " if operation == "increased" else "", STAT_LABELS.get(stat, stat)]

func _equip() -> void:
	if not equip_button.disabled:
		equip_requested.emit(_hero_id, _slot, str(_record.get("instance_id", "")))

func _lock(value: bool) -> void:
	if not lock_button.disabled:
		lock_toggled.emit(str(_record.get("instance_id", "")), value)

func request_discard() -> void:
	if discard_button.disabled:
		return
	_pending_discard_id = str(_record.get("instance_id", ""))
	_pending_discard_label = str(_record.get("label", ""))
	discard_name.text = ""
	discard_dialog.dialog_text = "Permanently discard %s?\nType its exact name below." % _pending_discard_label
	discard_dialog.get_ok_button().disabled = true
	discard_dialog.popup_centered(Vector2i(420, 160))
	discard_name.grab_focus()

func _confirm_discard() -> void:
	if not discard_button.disabled and _pending_discard_id == str(_record.get("instance_id", "")) and discard_name.text == _pending_discard_label:
		discard_requested.emit(_pending_discard_id, discard_name.text)
