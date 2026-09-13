class_name AbilitySlot
extends Button

const ActionLabelsScript = preload("res://scripts/ui/action_labels.gd")

var ability_id: String = ""
var action_id: String = ""
var ability_name: String = ""
var description: String = ""
var cooldown_remaining: float = 0.0
var cooldown_duration: float = 1.0
var cooldown_label: Label
var key_badge: Label

func setup(next_ability_id: String, next_action_id: String, next_name: String, next_description: String) -> void:
	ability_id = next_ability_id
	action_id = next_action_id
	ability_name = next_name
	description = next_description
	tooltip_text = ActionLabelsScript.tooltip(action_id, ability_name, description)
	if key_badge != null:
		key_badge.text = ActionLabelsScript.key_label(action_id)

func configure(remaining: float, duration: float, paused: bool) -> void:
	cooldown_remaining = maxf(0.0, remaining)
	cooldown_duration = maxf(0.01, duration)
	disabled = paused or cooldown_remaining > 0.0
	cooldown_label.visible = cooldown_remaining > 0.0
	cooldown_label.text = "%.1f" % cooldown_remaining if cooldown_remaining > 0.0 else ""
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	focus_mode = Control.FOCUS_ALL
	text = ""
	key_badge = Label.new()
	key_badge.name = "KeyBadge"
	key_badge.text = ActionLabelsScript.key_label(action_id) if not action_id.is_empty() else "?"
	key_badge.add_theme_font_size_override("font_size", 10)
	key_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_badge.position = Vector2(2, 2)
	key_badge.custom_minimum_size = Vector2(40, 15)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#202831e6")
	badge_style.border_color = Color("#6d7b85")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(2)
	badge_style.content_margin_left = 2
	badge_style.content_margin_right = 2
	key_badge.add_theme_stylebox_override("normal", badge_style)
	key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_badge)
	cooldown_label = Label.new()
	cooldown_label.name = "Cooldown"
	cooldown_label.add_theme_font_size_override("font_size", 12)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cooldown_label.position = Vector2(20, 25)
	cooldown_label.custom_minimum_size = Vector2(20, 16)
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.visible = false
	add_child(cooldown_label)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.56)
	var color := Color("#8ed9df") if not disabled else Color("#7b818a")
	if ability_id == "dash":
		draw_line(center + Vector2(-9, 0), center + Vector2(2, 0), color, 3.0, true)
		draw_line(center + Vector2(-1, -7), center + Vector2(8, 0), color, 3.0, true)
		draw_line(center + Vector2(-1, 7), center + Vector2(8, 0), color, 3.0, true)
	else:
		draw_arc(center, 10.0, -0.9, 2.0, 20, color, 2.5, true)
		draw_arc(center, 5.0, 2.2, 5.2, 20, color, 2.0, true)
	if cooldown_remaining > 0.0:
		var progress := clampf(cooldown_remaining / cooldown_duration, 0.0, 1.0)
		draw_circle(center, 13.0, Color(0.04, 0.06, 0.08, 0.42 * progress))
		draw_arc(center, 15.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color("#d8b34b"), 2.0, true)
