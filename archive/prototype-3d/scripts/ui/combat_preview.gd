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
var bank_label: Label
var passive_label: Label
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
	var operations: Dictionary = view_state.get("operations", {})
	bank_label.text = "Mana %0.2f" % float(operations.get("banked_mana", 0.0))
	passive_label.text = "%0.2f/min" % float(operations.get("passive_rate_per_minute", 0.0))
	pause_button.disabled = not bool(combat.get("active", false))
	pause_button.text = "Resume" if bool(combat.get("paused", false)) else "Pause"

func _build() -> void:
	if survival_widget != null:
		return
	survival_widget = SurvivalWidgetScript.new()
	survival_widget.name = "SurvivalWidget"
	survival_widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	survival_widget.position = Vector2(24, 24)
	add_child(survival_widget)
	pressure_widget = PressureWidgetScript.new()
	pressure_widget.name = "PressureWidget"
	pressure_widget.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pressure_widget.position = Vector2(-140, 24)
	add_child(pressure_widget)
	var wallet := PanelContainer.new()
	wallet.name = "CombatWallet"
	wallet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wallet.position = Vector2(-300, 24)
	wallet.custom_minimum_size = Vector2(276, 68)
	var wallet_row := HBoxContainer.new()
	wallet_row.name = "WalletContent"
	wallet_row.add_theme_constant_override("separation", 10)
	wallet.add_child(wallet_row)
	var wallet_values := VBoxContainer.new()
	wallet_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_label = Label.new()
	bank_label.name = "BankedMana"
	bank_label.text = "Mana 0.00"
	wallet_values.add_child(bank_label)
	passive_label = Label.new()
	passive_label.name = "PassiveRate"
	passive_label.text = "0.00/min"
	wallet_values.add_child(passive_label)
	wallet_row.add_child(wallet_values)
	pause_button = Button.new()
	pause_button.name = "Pause"
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(82, 44)
	pause_button.pressed.connect(pause_requested.emit)
	wallet_row.add_child(pause_button)
	add_child(wallet)
	ability_bar = AbilityBarScript.new()
	ability_bar.name = "AbilityBar"
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_bar.position = Vector2(24, -88)
	ability_bar.ability_requested.connect(func(ability_id: String): ability_requested.emit(ability_id))
	add_child(ability_bar)
	extraction_widget = ExtractionWidgetScript.new()
	extraction_widget.name = "ExtractionWidget"
	extraction_widget.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	extraction_widget.position = Vector2(-150, -150)
	extraction_widget.harvest_requested.connect(harvest_requested.emit)
	add_child(extraction_widget)
