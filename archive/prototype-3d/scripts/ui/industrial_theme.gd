class_name IndustrialTheme
extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("#f1eee4"))
	theme.set_color("font_color", "Button", Color("#f1eee4"))
	theme.set_color("font_hover_color", "Button", Color("#fff7d1"))
	theme.set_color("font_pressed_color", "Button", Color("#161a20"))
	theme.set_color("font_disabled_color", "Button", Color("#7b818a"))
	theme.set_color("font_color", "LineEdit", Color("#f1eee4"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("#8c939d"))
	theme.set_color("font_color", "OptionButton", Color("#f1eee4"))
	theme.set_color("font_disabled_color", "OptionButton", Color("#7b818a"))
	theme.set_color("font_color", "PanelContainer", Color("#f1eee4"))
	for type_name in ["Label", "Button", "LineEdit", "OptionButton", "PanelContainer"]:
		theme.set_font_size("font_size", type_name, 16)
	var surface := _box(Color("#171c22"), Color("#3e4852"), 1, 4)
	var surface_emphasis := _box(Color("#202831"), Color("#6d7b85"), 1, 4)
	var button := _box(Color("#26313a"), Color("#50606b"), 1, 3)
	var button_hover := _box(Color("#34434d"), Color("#8ed9df"), 1, 3)
	var button_pressed := _box(Color("#d8b34b"), Color("#f5dc79"), 1, 3)
	var button_disabled := _box(Color("#1b2026"), Color("#323942"), 1, 3)
	var focus := _box(Color(0, 0, 0, 0), Color("#8ed9df"), 2, 4)
	theme.set_stylebox("panel", "PanelContainer", surface)
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "OptionButton", button)
	theme.set_stylebox("hover", "OptionButton", button_hover)
	theme.set_stylebox("pressed", "OptionButton", button_pressed)
	theme.set_stylebox("disabled", "OptionButton", button_disabled)
	theme.set_stylebox("focus", "OptionButton", focus)
	theme.set_stylebox("normal", "LineEdit", surface_emphasis)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_constant("separation", "BoxContainer", 16)
	theme.set_constant("separation", "VBoxContainer", 16)
	theme.set_constant("separation", "HBoxContainer", 16)
	return theme

static func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style