class_name OperationsPreview
extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const WellCardScript = preload("res://scripts/ui/well_card.gd")
const HeroPickerScript = preload("res://scripts/ui/hero_picker.gd")
const ExpeditionPanelScript = preload("res://scripts/ui/expedition_panel.gd")
const ResourceStripScript = preload("res://scripts/ui/resource_strip.gd")
const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")
const ResponsiveWorkspaceScript = preload("res://scripts/ui/responsive_workspace.gd")
const ResponsiveContentScript = preload("res://scripts/ui/responsive_content.gd")
const ResponsiveViewportScript = preload("res://scripts/ui/responsive_viewport.gd")

@export var fixture_id: String = "one_well_commissioned"
var include_notice_placeholder: bool = true

var body: BoxContainer
var operations_scroll: ScrollContainer
var left_column: VBoxContainer
var right_column: VBoxContainer
var view_state: Dictionary = {}
var hero_picker
var expedition_panel
var resource_strip
var research_panel
var viewport_settings_button: Button

signal destination_requested(well_id: String)
signal guard_picker_requested(well_id: String)
signal hero_selected(hero_id: String, mode: String, well_id: String)
signal guard_recall_requested(well_id: String)
signal loadout_requested(loadout_id: String)
signal start_requested
signal purchase_requested(upgrade_id: String)
signal settings_requested(opener: Control)

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	_build()
	_update_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and body != null:
		_update_responsive_layout()

func _build() -> void:
	name = "OperationsPreview"
	view_state = UiPreviewFixturesScript.make(fixture_id).view_state
	var margin := ResponsiveViewportScript.new()
	margin.name = "OuterMargin"
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 0.0
	margin.offset_left = 0.0
	margin.offset_top = 0.0
	margin.offset_right = 0.0
	margin.offset_bottom = 0.0
	var scroll := ScrollContainer.new()
	operations_scroll = scroll
	scroll.name = "OperationsScroll"
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 0.0
	scroll.anchor_bottom = 0.0
	scroll.offset_left = 0.0
	scroll.offset_top = 0.0
	scroll.offset_right = 0.0
	scroll.offset_bottom = 0.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	scroll.add_child(margin)
	var content := ResponsiveContentScript.new()
	content.name = "OperationsContent"
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	resource_strip = ResourceStripScript.new()
	resource_strip.name = "ResourceStrip"
	resource_strip.settings_requested.connect(func(opener: Control): settings_requested.emit(opener))
	resource_strip.configure(view_state.operations.research)
	content.add_child(resource_strip)
	var overflow_settings := resource_strip.get_node("ResourceStripContent/SettingsButton") as Button
	overflow_settings.visible = false
	viewport_settings_button = Button.new()
	viewport_settings_button.name = "ViewportSettingsButton"
	viewport_settings_button.text = "Settings"
	viewport_settings_button.custom_minimum_size = Vector2(110, 40)
	viewport_settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	viewport_settings_button.position = Vector2(-134, 12)
	viewport_settings_button.pressed.connect(func(): settings_requested.emit(viewport_settings_button))
	add_child(viewport_settings_button)
	body = ResponsiveWorkspaceScript.new()
	body.name = "OperationsWorkspace"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	left_column = VBoxContainer.new()
	left_column.name = "WellsResearchRegion"
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 3.0
	right_column = VBoxContainer.new()
	right_column.name = "ExpeditionLaunchRegion"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 2.0
	body.add_child(left_column)
	body.add_child(right_column)
	left_column.add_child(_wells_region())
	research_panel = _research_region()
	left_column.add_child(research_panel)
	expedition_panel = ExpeditionPanelScript.new()
	expedition_panel.name = "ExpeditionRegion"
	expedition_panel.loadout_requested.connect(func(loadout_id: String): loadout_requested.emit(loadout_id))
	expedition_panel.change_hero_requested.connect(_on_change_hero_requested)
	expedition_panel.start_requested.connect(func(): start_requested.emit())
	right_column.add_child(expedition_panel)
	expedition_panel.configure(view_state.operations.expedition)
	if include_notice_placeholder:
		content.add_child(_placeholder_panel("NoticeRegion", "NOTICES", "Save and recovery notices remain separate from the primary instruction."))
	hero_picker = HeroPickerScript.new()
	hero_picker.name = "HeroPicker"
	hero_picker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hero_picker.offset_left = -240
	hero_picker.offset_top = -220
	hero_picker.offset_right = 240
	hero_picker.offset_bottom = 220
	hero_picker.hero_selected.connect(func(hero_id: String, mode: String, well_id: String): hero_selected.emit(hero_id, mode, well_id))
	hero_picker.guard_recall_requested.connect(func(well_id: String): guard_recall_requested.emit(well_id))
	add_child(hero_picker)

func _research_region() -> Control:
	var panel := _panel("ResearchRegion")
	var content := VBoxContainer.new()
	content.name = "ResearchContent"
	content.add_child(_label("RESEARCH", 14))
	var cards := BoxContainer.new()
	cards.name = "UpgradeCards"
	cards.vertical = false
	cards.add_theme_constant_override("separation", 12)
	for upgrade_data in view_state.operations.research.upgrades:
		var card = UpgradeCardScript.new()
		card.name = "UpgradeCard_%s" % str(upgrade_data.get("id", ""))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.purchase_requested.connect(func(upgrade_id: String): purchase_requested.emit(upgrade_id))
		cards.add_child(card)
		card.configure(upgrade_data)
	content.add_child(cards)
	panel.add_child(content)
	return panel

func _wells_region() -> Control:
	var panel := _panel("WellsRegion")
	var content := VBoxContainer.new()
	content.name = "WellsContent"
	content.add_child(_label("WELLS", 14))
	var grid := GridContainer.new()
	grid.name = "WellCardsPlaceholder"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for well_data in view_state.operations.wells:
		var card: PanelContainer = WellCardScript.new()
		card.name = "WellCard_%s" % str(well_data.get("id", ""))
		card.custom_minimum_size = Vector2(0, 0)
		card.destination_requested.connect(func(well_id: String): destination_requested.emit(well_id))
		card.start_requested.connect(func(): start_requested.emit())
		card.guard_picker_requested.connect(_on_guard_picker_requested)
		grid.add_child(card)
		card.configure(well_data)
	content.add_child(grid)
	panel.add_child(content)
	return panel

func _on_guard_picker_requested(well_id: String) -> void:
	guard_picker_requested.emit(well_id)
	for well_data in view_state.get("operations", {}).get("wells", []):
		if str(well_data.get("id", "")) == well_id:
			hero_picker.open_guard(well_data, view_state.get("operations", {}).get("heroes", []), get_viewport().gui_get_focus_owner())
			return

func _on_change_hero_requested() -> void:
	var operations_state: Dictionary = view_state.get("operations", {})
	hero_picker.open_expedition(operations_state.get("heroes", []), str(operations_state.get("expedition", {}).get("active_hero_id", "")), get_viewport().gui_get_focus_owner())

func refresh(next_view_state: Dictionary) -> void:
	view_state = next_view_state.duplicate(true)
	var operations_state: Dictionary = view_state.get("operations", {})
	var research_state: Dictionary = operations_state.get("research", {})
	resource_strip.configure(research_state)
	for card in research_panel.get_node("ResearchContent/UpgradeCards").get_children():
		for upgrade_data in research_state.get("upgrades", []):
			if str(upgrade_data.get("id", "")) == str(card.upgrade_id):
				card.configure(upgrade_data)
				break
	expedition_panel.configure(operations_state.get("expedition", {}))
	var grid: GridContainer = get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder")
	for card in grid.get_children():
		if card.has_method("refresh"):
			for well_data in operations_state.get("wells", []):
				if str(well_data.get("id", "")) == str(card.get("well_id")):
					card.refresh(well_data)
					break
	if hero_picker.visible and hero_picker.mode == "guard":
		for well_data in operations_state.get("wells", []):
			if str(well_data.get("id", "")) == hero_picker.well_id:
				hero_picker.refresh_guard_state(well_data, operations_state.get("heroes", []), str(view_state.get("notices", {}).get("assignment", "")), bool(view_state.get("notices", {}).get("pending_save", false)))
				break

func _placeholder_panel(panel_name: String, heading: String, copy: String) -> PanelContainer:
	var panel := _panel(panel_name)
	var content := VBoxContainer.new()
	content.add_child(_label(heading, 14))
	var detail := _label(copy, 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	panel.add_child(content)
	return panel

func _panel(panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _update_responsive_layout() -> void:
	if operations_scroll != null:
		operations_scroll.position = Vector2.ZERO
		operations_scroll.size = size
		var margin := operations_scroll.get_node("OuterMargin") as Control
		var content := margin.get_node("OperationsContent") as Control
		margin.position = Vector2.ZERO
		margin.size = operations_scroll.size
		content.position = Vector2(24.0, 24.0)
		content.size = Vector2(maxf(0.0, margin.size.x - 48.0), content.get_combined_minimum_size().y)
	body.vertical = size.x < 960.0
	body.queue_sort()
	call_deferred("_fit_resource_strip")
	var grid := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder")
	if grid != null:
		grid.columns = 1 if size.x < 960.0 else 2
	var cards := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/ResearchRegion/ResearchContent/UpgradeCards")
	if cards != null:
		cards.vertical = size.x < 960.0

func _fit_resource_strip() -> void:
	if resource_strip == null or operations_scroll == null:
		return
	var width := maxf(0.0, operations_scroll.size.x - 48.0)
	resource_strip.size.x = width
	var row := resource_strip.get_node("ResourceStripContent") as Control
	row.size.x = width
