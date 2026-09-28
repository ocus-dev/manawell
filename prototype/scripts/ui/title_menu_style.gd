extends RefCounted

## Readability styles for the title menu. The game uses "plates": dark button
## plates with light text, amber + ▶ on the selected option, and the dev tools
## (debug builds) in a smaller group under a divider. "outline" and "band" were
## the other mockups.

const INK := Color("f3ead8")
const AMBER := Color("f5ab4f")
const SHADOW := Color(0.02, 0.025, 0.03, 0.95)

static func apply(title: Control, style: String) -> void:
	var menu: VBoxContainer = title.get_node("Menu")
	var buttons: Array = []
	for child in menu.get_children():
		if child is Button:
			buttons.append(child)
	match style:
		"outline":
			for button in buttons:
				button.add_theme_stylebox_override("disabled", _empty())
				_light_text(button, 7)
				button.add_theme_stylebox_override("normal", _empty())
				button.add_theme_stylebox_override("hover", _underline())
				button.add_theme_stylebox_override("focus", _underline())
				button.add_theme_stylebox_override("pressed", _underline())
		"band":
			for button in buttons:
				button.add_theme_stylebox_override("disabled", _empty())
			var band := _band(title)
			title.add_child(band)
			title.move_child(band, menu.get_index())
			for button in buttons:
				_light_text(button, 4)
				button.add_theme_stylebox_override("normal", _empty())
				button.add_theme_stylebox_override("hover", _bar(Color(AMBER, 0.16), Color(AMBER, 0.0), 0))
				button.add_theme_stylebox_override("focus", _bar(Color(AMBER, 0.16), Color(AMBER, 0.0), 0))
				button.add_theme_stylebox_override("pressed", _bar(Color(AMBER, 0.24), Color(AMBER, 0.0), 0))
		"plates":
			menu.add_theme_constant_override("separation", 6)
			var dev := false
			for button in buttons:
				var is_dev := ["DevEncyclopedia", "MonsterTestArena", "WeaponLab"].has(str(button.name))
				if is_dev and not dev:
					dev = true
					var divider := Label.new()
					divider.text = "—  DEV TOOLS  —"
					divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					divider.add_theme_font_size_override("font_size", 12)
					divider.add_theme_color_override("font_color", Color(INK, 0.75))
					divider.add_theme_color_override("font_outline_color", SHADOW)
					divider.add_theme_constant_override("outline_size", 4)
					menu.add_child(divider)
					menu.move_child(divider, button.get_index())
				_light_text(button, 3)
				if is_dev:
					button.custom_minimum_size = Vector2(250, 36)
					button.add_theme_font_size_override("font_size", 14)
					button.add_theme_color_override("font_color", Color("c9d2d8"))
				else:
					button.custom_minimum_size = Vector2(250, 46)
				button.add_theme_stylebox_override("normal", _bar(Color(0.05, 0.065, 0.08, 0.78), Color(AMBER, 0.45), 1))
				button.add_theme_stylebox_override("hover", _bar(Color(0.12, 0.09, 0.05, 0.9), AMBER, 2))
				button.add_theme_stylebox_override("focus", _bar(Color(0.12, 0.09, 0.05, 0.9), AMBER, 2))
				button.add_theme_stylebox_override("pressed", _bar(Color(0.2, 0.13, 0.05, 0.95), AMBER, 2))
				button.add_theme_stylebox_override("disabled", _bar(Color(0.05, 0.065, 0.08, 0.55), Color(AMBER, 0.2), 1))
	for button in buttons:
		_selected_marker(button)

## The settings panel in the same style: a dark plate behind it and light
## text on its controls (they were dark text on a dark panel).
static func style_settings(title: Control) -> void:
	var panel: PanelContainer = title.get_node_or_null("SettingsPanel")
	if panel == null:
		return
	var plate := _bar(Color(0.04, 0.05, 0.06, 0.9), Color(AMBER, 0.5), 1)
	plate.content_margin_left = 22
	plate.content_margin_right = 22
	plate.content_margin_top = 18
	plate.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", plate)
	var heading: Label = panel.get_node_or_null("Settings/Heading")
	if heading != null:
		heading.add_theme_color_override("font_color", INK)
		heading.add_theme_color_override("font_outline_color", SHADOW)
		heading.add_theme_constant_override("outline_size", 3)
	for button_name in ["Fullscreen", "Back"]:
		var button: Button = panel.get_node_or_null("Settings/" + button_name)
		if button == null:
			continue
		_light_text(button, 3)
		button.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
		button.add_theme_stylebox_override("normal", _bar(Color(0.08, 0.1, 0.12, 0.9), Color(AMBER, 0.45), 1))
		button.add_theme_stylebox_override("hover", _bar(Color(0.12, 0.09, 0.05, 0.95), AMBER, 2))
		button.add_theme_stylebox_override("focus", _bar(Color(0.12, 0.09, 0.05, 0.95), AMBER, 2))
		button.add_theme_stylebox_override("pressed", _bar(Color(0.2, 0.13, 0.05, 0.95), AMBER, 2))
		button.add_theme_stylebox_override("hover_pressed", _bar(Color(0.2, 0.13, 0.05, 0.95), AMBER, 2))
		button.add_theme_stylebox_override("disabled", _bar(Color(0.08, 0.1, 0.12, 0.6), Color(AMBER, 0.2), 1))
		for style in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			var box: StyleBox = button.get_theme_stylebox(style)
			box.content_margin_left = 12
			box.content_margin_right = 12

static func _light_text(button: Button, outline: int) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", AMBER)
	button.add_theme_color_override("font_focus_color", AMBER)
	button.add_theme_color_override("font_pressed_color", AMBER)
	button.add_theme_color_override("font_hover_pressed_color", AMBER)
	button.add_theme_color_override("font_disabled_color", Color(INK, 0.4))
	button.add_theme_color_override("font_outline_color", SHADOW)
	button.add_theme_constant_override("outline_size", outline)

## "▶ " in front of the hovered / focused option.
static func _selected_marker(button: Button) -> void:
	var plain := button.text
	var mark := func() -> void:
		button.text = ("▶  " + plain) if (button.has_focus() or button.is_hovered()) else plain
	button.focus_entered.connect(mark)
	button.focus_exited.connect(mark)
	button.mouse_entered.connect(mark)
	button.mouse_exited.connect(mark)

static func _empty() -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func _underline() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_bottom = 2
	style.border_color = AMBER
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func _bar(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

## A soft-edged dark panel behind the menu (below the logo).
static func _band(title: Control) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.5)
	style.shadow_color = Color(0.02, 0.03, 0.04, 0.5)
	style.shadow_size = 48
	style.set_corner_radius_all(48)
	var menu: Control = title.get_node("Menu")
	var rect := Panel.new()
	rect.name = "MenuBand"
	rect.add_theme_stylebox_override("panel", style)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fit := func() -> void:
		var box := menu.get_global_rect()
		rect.global_position = box.position - Vector2(60, 16)
		rect.size = box.size + Vector2(120, 32)
	menu.resized.connect(fit)
	menu.item_rect_changed.connect(fit)
	fit.call_deferred()
	return rect
