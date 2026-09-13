extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const SurvivalWidgetScript = preload("res://scripts/ui/survival_widget.gd")
const PressureWidgetScript = preload("res://scripts/ui/pressure_widget.gd")
const ExtractionWidgetScript = preload("res://scripts/ui/extraction_widget.gd")
const AbilityBarScript = preload("res://scripts/ui/ability_bar.gd")

signal pause_requested
signal harvest_requested
signal ability_requested(ability_id: String)

var survival_widget
var pressure_widget
var extraction_widget
var ability_bar
var pause_button: Button
var view_state: Dictionary = {}

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	_build()

func configure(next_view_state: Dictionary) -> void:
	view_state = next_view_state.duplicate(true)
	if survival_widget == null:
		_build()
	var combat: Dictionary = view_state.get("combat", {})
	survival_widget.configure(combat)
	pressure_widget.configure(combat)
	extraction_widget.configure(combat)
	ability_bar.configure(combat)
	pause_button.disabled = not bool(combat.get("active", false))
	pause_button.text = "Resume" if bool(combat.get("paused", false)) else "Pause"

func _build() -> void:
	if survival_widget != null:
		return
	survival_widget = SurvivalWidgetScript.new()
	survival_widget.name = "SurvivalWidget"
	survival_widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	survival_widget.position = Vector2(24, 8)
	add_child(survival_widget)
	pressure_widget = PressureWidgetScript.new()
	pressure_widget.name = "PressureWidget"
	pressure_widget.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pressure_widget.position = Vector2(-140, 6)
	add_child(pressure_widget)
	var wallet := PanelContainer.new()
	wallet.name = "CombatWallet"
	wallet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wallet.position = Vector2(-112, 8)
	wallet.custom_minimum_size = Vector2(96, 40)
	var wallet_panel := StyleBoxFlat.new()
	wallet_panel.bg_color = Color("#171c22e6")
	wallet_panel.border_color = Color("#3e4852")
	wallet_panel.set_border_width_all(1)
	wallet_panel.set_corner_radius_all(3)
	wallet_panel.content_margin_left = 3
	wallet_panel.content_margin_right = 3
	wallet_panel.content_margin_top = 2
	wallet_panel.content_margin_bottom = 2
	wallet.add_theme_stylebox_override("panel", wallet_panel)
	var wallet_row := HBoxContainer.new()
	wallet_row.name = "WalletContent"
	wallet_row.add_theme_constant_override("separation", 10)
	wallet.add_child(wallet_row)
	pause_button = Button.new()
	pause_button.name = "Pause"
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(96, 36)
	pause_button.pressed.connect(pause_requested.emit)
	wallet_row.add_child(pause_button)
	add_child(wallet)
	ability_bar = AbilityBarScript.new()
	ability_bar.name = "AbilityBar"
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_bar.position = Vector2(24, -60)
	ability_bar.ability_requested.connect(func(ability_id: String): ability_requested.emit(ability_id))
	add_child(ability_bar)
	extraction_widget = ExtractionWidgetScript.new()
	extraction_widget.name = "ExtractionWidget"
	extraction_widget.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	extraction_widget.position = Vector2(-150, -64)
	extraction_widget.harvest_requested.connect(harvest_requested.emit)
	add_child(extraction_widget)
