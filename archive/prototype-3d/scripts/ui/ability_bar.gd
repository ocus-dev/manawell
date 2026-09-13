extends PanelContainer

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
	_apply_ability(dash_button, "Dash [Space]", float(abilities.get("dash_cooldown_remaining", 0.0)), paused)
	_apply_ability(pulse_button, "Pulse [Q]", float(abilities.get("pulse_cooldown_remaining", 0.0)), paused)

func _apply_ability(button: Button, label: String, remaining: float, paused: bool) -> void:
	button.text = "%s: %.1fs" % [label, remaining] if remaining > 0.0 else "%s: ready" % label
	button.disabled = paused or remaining > 0.0

func _build() -> void:
	custom_minimum_size = Vector2(250, 64)
	var row := HBoxContainer.new()
	row.name = "AbilityContent"
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	dash_button = _ability_button("Dash [Space]")
	dash_button.name = "Dash"
	dash_button.pressed.connect(ability_requested.emit.bind("dash"))
	row.add_child(dash_button)
	pulse_button = _ability_button("Pulse [Q]")
	pulse_button.name = "Pulse"
	pulse_button.pressed.connect(ability_requested.emit.bind("pulse"))
	row.add_child(pulse_button)

func _ability_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button