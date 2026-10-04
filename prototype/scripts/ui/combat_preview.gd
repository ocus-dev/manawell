extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const SurvivalWidgetScript = preload("res://scripts/ui/survival_widget.gd")
const CORNER_HUD_SCALE := 0.8
const PressureWidgetScript = preload("res://scripts/ui/pressure_widget.gd")
const ExtractionWidgetScript = preload("res://scripts/ui/extraction_widget.gd")
const AbilityBarScript = preload("res://scripts/ui/ability_bar.gd")
const DrillPanelScript = preload("res://scripts/ui/drill_panel.gd")

signal pause_requested
signal harvest_requested
signal ability_requested(ability_id: String)
## A left click on open screen (not on a widget), in viewport coordinates.
signal world_clicked(viewport_position: Vector2)
signal surge_limit_changed(limit: int)
signal drill_panel_closed

var survival_widget
var pressure_widget
var extraction_widget
var ability_bar
var pause_button: Button
const PAUSE_SCALE := 0.75
const ABILITY_BAR_SCALE := 0.8
var drill_panel
var view_state: Dictionary = {}

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	_build()

func configure(next_view_state: Dictionary) -> void:
	view_state = next_view_state
	configure_combat(view_state.get("combat", {}))

func configure_combat(combat: Dictionary) -> void:
	if survival_widget == null:
		_build()
	survival_widget.configure(combat)
	pressure_widget.configure(combat)
	extraction_widget.configure(combat)
	ability_bar.configure(combat)
	pause_button.disabled = not bool(combat.get("active", false))
	pause_button.text = "Resume" if bool(combat.get("paused", false)) else "Pause"
	_configure_drill_panel(combat.get("drill", {}))

func _configure_drill_panel(drill: Dictionary) -> void:
	var open := bool(drill.get("open", false))
	drill_panel.visible = open
	if not open:
		return
	drill_panel.configure(drill)
	drill_panel.reset_size()
	var anchor: Vector2 = drill.get("screen_anchor", Vector2.ZERO)
	var local := get_global_transform_with_canvas().affine_inverse() * anchor
	var panel_size: Vector2 = drill_panel.get_combined_minimum_size()
	local.y -= panel_size.y
	local.x = clampf(local.x, 8.0, maxf(8.0, size.x - panel_size.x - 8.0))
	local.y = clampf(local.y, 8.0, maxf(8.0, size.y - panel_size.y - 8.0))
	drill_panel.position = local

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		world_clicked.emit(get_global_transform_with_canvas() * event.position)

func _build() -> void:
	if survival_widget != null:
		return
	var corner: VBoxContainer
	# Health and surge stacked in the top-left corner, flush with the screen
	# edges: one panel with only its inner (bottom-right) corner rounded.
	corner = VBoxContainer.new()
	corner.name = "CornerHud"
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	corner.position = Vector2.ZERO
	# Drawn at 80% so it takes less of the view (text and box together).
	corner.scale = Vector2(CORNER_HUD_SCALE, CORNER_HUD_SCALE)
	corner.add_theme_constant_override("separation", 0)
	add_child(corner)
	survival_widget = SurvivalWidgetScript.new()
	survival_widget.name = "SurvivalWidget"
	corner.add_child(survival_widget)
	survival_widget.add_theme_stylebox_override("panel", _corner_panel(false))
	pressure_widget = PressureWidgetScript.new()
	pressure_widget.name = "PressureWidget"
	corner.add_child(pressure_widget)
	pressure_widget.add_theme_stylebox_override("panel", _corner_panel(false))
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
	# 75% size, shrinking toward its top-right corner so it stays in place.
	wallet.scale = Vector2(PAUSE_SCALE, PAUSE_SCALE)
	wallet.resized.connect(func() -> void: wallet.pivot_offset = Vector2(wallet.size.x, 0.0))
	wallet.pivot_offset = Vector2(wallet.size.x, 0.0)
	ability_bar = AbilityBarScript.new()
	ability_bar.name = "AbilityBar"
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_bar.position = Vector2(24, -60)
	ability_bar.ability_requested.connect(func(ability_id: String): ability_requested.emit(ability_id))
	add_child(ability_bar)
	# 80% size, shrinking toward its bottom-left corner so it stays in place.
	ability_bar.scale = Vector2(ABILITY_BAR_SCALE, ABILITY_BAR_SCALE)
	ability_bar.resized.connect(func() -> void: ability_bar.pivot_offset = Vector2(0.0, ability_bar.size.y))
	ability_bar.pivot_offset = Vector2(0.0, ability_bar.size.y)
	extraction_widget = ExtractionWidgetScript.new()
	extraction_widget.name = "ExtractionWidget"
	extraction_widget.harvest_requested.connect(harvest_requested.emit)
	# Mana at risk + Harvest, right below the surge stats in the corner HUD.
	corner.add_child(extraction_widget)
	extraction_widget.add_theme_stylebox_override("panel", _corner_panel(true))
	drill_panel = DrillPanelScript.new()
	drill_panel.surge_limit_changed.connect(surge_limit_changed.emit)
	drill_panel.close_requested.connect(drill_panel_closed.emit)
	add_child(drill_panel)

## The corner HUD's panels: no border or rounding on the screen-edge sides.
func _corner_panel(bottom: bool) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171c22e6")
	panel.border_color = Color("#3e4852")
	panel.border_width_right = 1
	panel.border_width_bottom = 1 if bottom else 0
	panel.corner_radius_bottom_right = 8 if bottom else 0
	panel.content_margin_left = 12
	panel.content_margin_right = 10
	panel.content_margin_top = 8 if not bottom else 2
	panel.content_margin_bottom = 8 if bottom else 4
	return panel
