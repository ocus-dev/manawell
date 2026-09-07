class_name OperationsPreview
extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const WellCardScript = preload("res://scripts/ui/well_card.gd")
const HeroPickerScript = preload("res://scripts/ui/hero_picker.gd")
const ExpeditionPanelScript = preload("res://scripts/ui/expedition_panel.gd")
const ResourceStripScript = preload("res://scripts/ui/resource_strip.gd")
const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")

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
var navigation_bar: HBoxContainer
var navigation_buttons: Dictionary = {}
var crew_panel: PanelContainer
var active_page := "operations"

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

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
	theme.set_constant("separation", "VBoxContainer", 6)
	var panel_style := theme.get_stylebox("panel", "PanelContainer").duplicate()
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	_build()
	_update_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and body != null:
		_update_responsive_layout()

func _build() -> void:
	name = "OperationsPreview"
	view_state = UiPreviewFixturesScript.make(fixture_id).view_state
	var scroll := ScrollContainer.new()
	operations_scroll = scroll
	scroll.name = "OperationsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.name = "OuterMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 0)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "OperationsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	navigation_bar = HBoxContainer.new()
	navigation_bar.name = "NavigationBar"
	navigation_bar.add_theme_constant_override("separation", 4)
	content.add_child(navigation_bar)
	_add_navigation_button("operations", "OPERATIONS")
	_add_navigation_button("research", "RESEARCH")
	_add_navigation_button("crew", "CREW")
	resource_strip = ResourceStripScript.new()
	resource_strip.name = "ResourceStrip"
	resource_strip.settings_requested.connect(func(opener: Control): settings_requested.emit(opener))
	resource_strip.configure(view_state.operations.research)
	content.add_child(resource_strip)
	viewport_settings_button = resource_strip.get_node("ResourceStripContent/SettingsButton") as Button
	body = BoxContainer.new()
	body.name = "OperationsWorkspace"
	body.custom_minimum_size.x = 0.0
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	left_column = VBoxContainer.new()
	left_column.name = "WellsResearchRegion"
	left_column.custom_minimum_size.x = 0.0
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 3.0
	right_column = VBoxContainer.new()
	right_column.name = "ExpeditionLaunchRegion"
	right_column.custom_minimum_size.x = 0.0
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 2.0
	body.add_child(left_column)
	body.add_child(right_column)
	left_column.add_child(_wells_region())
	research_panel = _research_region()
	research_panel.visible = false
	content.add_child(research_panel)
	expedition_panel = ExpeditionPanelScript.new()
	expedition_panel.name = "ExpeditionRegion"
	expedition_panel.loadout_requested.connect(func(loadout_id: String): loadout_requested.emit(loadout_id))
	expedition_panel.change_hero_requested.connect(_on_change_hero_requested)
	expedition_panel.start_requested.connect(func(): start_requested.emit())
	right_column.add_child(expedition_panel)
	expedition_panel.configure(view_state.operations.expedition)
	if include_notice_placeholder:
		content.add_child(_placeholder_panel("NoticeRegion", "NOTICES", "Save and recovery notices remain separate from the primary instruction."))
	crew_panel = _crew_region()
	crew_panel.visible = false
	content.add_child(crew_panel)
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
	_show_page("operations")

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
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _add_navigation_button(page_id: String, label: String) -> void:
	var button := Button.new()
	button.name = "%sNavigationButton" % page_id.capitalize()
	button.text = label
	button.custom_minimum_size = Vector2(150, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.pressed.connect(_show_page.bind(page_id))
	navigation_bar.add_child(button)
	navigation_buttons[page_id] = button

func _show_page(page_id: String) -> void:
	active_page = page_id
	body.visible = page_id == "operations"
	research_panel.visible = page_id == "research"
	crew_panel.visible = page_id == "crew"
	for button_id in navigation_buttons:
		navigation_buttons[button_id].button_pressed = button_id == page_id
	_update_responsive_layout()

func _crew_region() -> PanelContainer:
	var panel := _panel("CrewRegion")
	var content := VBoxContainer.new()
	content.name = "CrewContent"
	content.add_child(_label("CREW", 16))
	var summary := _label("Assign expedition heroes and guards from the Operations page. This roster keeps role and availability visible as the crew system grows.", 14)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var roster := VBoxContainer.new()
	roster.name = "CrewRoster"
	roster.add_theme_constant_override("separation", 8)
	for hero_data in view_state.operations.heroes:
		var row := PanelContainer.new()
		row.name = "Crew_%s" % str(hero_data.get("id", ""))
		var row_content := HBoxContainer.new()
		row_content.add_theme_constant_override("separation", 16)
		var name_label := _label(str(hero_data.get("label", "Hero")), 16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_content.add_child(name_label)
		row_content.add_child(_label(str(hero_data.get("role_label", "Reserve")), 14))
		var reason := _label(str(hero_data.get("availability_reason", "Available to assign.")), 13)
		reason.custom_minimum_size.x = 300
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_content.add_child(reason)
		row.add_child(row_content)
		roster.add_child(row)
	content.add_child(roster)
	panel.add_child(content)
	return panel

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
	_refresh_crew(operations_state.get("heroes", []))
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

func _refresh_crew(heroes: Array) -> void:
	if crew_panel == null:
		return
	var roster: VBoxContainer = crew_panel.get_node("CrewContent/CrewRoster")
	for index in heroes.size():
		if index >= roster.get_child_count():
			break
		var row: PanelContainer = roster.get_child(index)
		var row_content: HBoxContainer = row.get_child(0)
		(row_content.get_child(1) as Label).text = str(heroes[index].get("role_label", "Reserve"))
		(row_content.get_child(2) as Label).text = str(heroes[index].get("availability_reason", "Available to assign."))

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
	# Breakpoints use logical viewport units, not physical window pixels.
	var compact_layout := size.x < 1000.0
	body.vertical = compact_layout
	var grid := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder")
	if grid != null:
		grid.columns = 1 if compact_layout else 2
	var cards := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/ResearchRegion/ResearchContent/UpgradeCards")
	if cards != null:
		cards.vertical = compact_layout
