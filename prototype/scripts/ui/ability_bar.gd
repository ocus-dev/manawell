extends PanelContainer

const AbilitySlotScript = preload("res://scripts/ui/ability_slot.gd")

signal ability_requested(ability_id: String)

var dash_button: Button
var pulse_button: Button

func _ready() -> void:
	if dash_button == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if dash_button == null:
		_build()
	var abilities: Dictionary = view_data.get("abilities", {})
	var paused: bool = bool(view_data.get("paused", false))
	_apply_ability(dash_button, float(abilities.get("dash_cooldown_remaining", 0.0)), float(abilities.get("dash_cooldown", 1.0)), paused)
	_apply_ability(pulse_button, float(abilities.get("pulse_cooldown_remaining", 0.0)), float(abilities.get("pulse_cooldown", 1.0)), paused)

func _apply_ability(button, remaining: float, duration: float, paused: bool) -> void:
	button.configure(remaining, duration, paused)

func _build() -> void:
	custom_minimum_size = Vector2(104, 52)
	add_theme_stylebox_override("panel", _compact_panel())
	var row := HBoxContainer.new()
	row.name = "AbilityContent"
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	dash_button = _ability_button("dash", "dash", "Dash", "Burst forward and evade damage.")
	dash_button.name = "Dash"
	dash_button.pressed.connect(ability_requested.emit.bind("dash"))
	row.add_child(dash_button)
	pulse_button = _ability_button("pulse", "pulse", "Pulse", "Damage nearby enemies.")
	pulse_button.name = "Pulse"
	pulse_button.pressed.connect(ability_requested.emit.bind("pulse"))
	row.add_child(pulse_button)

func _ability_button(ability_id: String, action_id: String, ability_name: String, description: String) -> Button:
	var button: Button = AbilitySlotScript.new()
	button.setup(ability_id, action_id, ability_name, description)
	return button

func _compact_panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171c22e6")
	panel.border_color = Color("#3e4852")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 4
	panel.content_margin_right = 4
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	return panel