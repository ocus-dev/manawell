class_name OperationsPreview
extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const WellCardScript = preload("res://scripts/ui/well_card.gd")
const HeroPickerScript = preload("res://scripts/ui/hero_picker.gd")
const ExpeditionPanelScript = preload("res://scripts/ui/expedition_panel.gd")
const ResourceStripScript = preload("res://scripts/ui/resource_strip.gd")
const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")
const CampaignMapScript = preload("res://scripts/ui/campaign_map.gd")

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
var inventory_panel
signal inventory_item_inspected(id: String)
signal inventory_equip_requested(hero_id: String, slot: String, instance_id: String)
signal inventory_unequip_requested(hero_id: String, slot: String)
signal inventory_lock_toggled(instance_id: String, locked: bool)
signal inventory_discard_requested(instance_id: String, confirmed_name: String)
var viewport_settings_button: Button
var navigation_bar: HBoxContainer
var navigation_buttons: Dictionary = {}
var crew_panel: PanelContainer
var active_page := "operations"
var campaign_map
var well_popup
var destination_picker: OptionButton
var fitted_pages: Dictionary = {}

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

signal destination_requested(well_id: String)
signal guard_picker_requested(well_id: String)
signal hero_selected(hero_id: String, mode: String, well_id: String)
signal guard_recall_requested(well_id: String)
signal loadout_requested(loadout_id: String)
signal start_requested
signal purchase_requested(upgrade_id: String)
signal research_purchase_requested(research_id: String, expected_rank: int, expected_cost: int)
signal research_equipment_requested(choice_id: String)
signal settings_requested(opener: Control)
signal campaign_node_selected(act_id: String, node_id: String)
signal campaign_node_activate(act_id: String, node_id: String)

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
	_add_navigation_button("map", "MAP")
	_add_navigation_button("research", "RESEARCH")
	_add_navigation_button("inventory", "INVENTORY")
	_add_navigation_button("crew", "CREW")
	resource_strip = ResourceStripScript.new()
	resource_strip.name = "ResourceStrip"
	resource_strip.settings_requested.connect(func(opener: Control): settings_requested.emit(opener))
	var operations_state: Dictionary = view_state.get("operations", {})
	resource_strip.configure(operations_state.get("research", {}))
	content.add_child(resource_strip)
	viewport_settings_button = resource_strip.get_node("ResourceStripContent/SettingsButton") as Button
	body = BoxContainer.new()
	body.name = "OperationsWorkspace"
	body.custom_minimum_size.x = 0.0
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	campaign_map = CampaignMapScript.new()
	campaign_map.name = "CampaignMap"
	campaign_map.custom_minimum_size = Vector2(0, 620)
	campaign_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_map.node_selected.connect(func(act_id: String, node_id: String):
		campaign_node_selected.emit(act_id, node_id)
		for node in view_state.get("campaign", {}).get("nodes", []):
			if node.id == node_id and node.type == "well":
				_manage_map_well(str(node.well_id)))
	campaign_map.node_activate.connect(func(act_id: String, node_id: String): campaign_node_activate.emit(act_id, node_id))
	content.add_child(campaign_map)
	content.move_child(body, content.get_child_count() - 1)
	campaign_map.manage_well_requested.connect(_manage_map_well)
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
	left_column.hide()
	destination_picker = OptionButton.new()
	destination_picker.item_selected.connect(func(index: int): destination_requested.emit(str(destination_picker.get_item_metadata(index))))
	right_column.add_child(destination_picker)
	research_panel = _research_region()
	research_panel.visible = false
	content.add_child(research_panel)
	inventory_panel = preload("res://scripts/ui/inventory_panel.gd").new()
	inventory_panel.name = "InventoryRegion"
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_panel.visible = false
	inventory_panel.item_inspected.connect(func(id: String): inventory_item_inspected.emit(id))
	inventory_panel.equip_requested.connect(func(hero_id: String, slot: String, instance_id: String): inventory_equip_requested.emit(hero_id, slot, instance_id))
	inventory_panel.unequip_requested.connect(func(hero_id: String, slot: String): inventory_unequip_requested.emit(hero_id, slot))
	inventory_panel.lock_toggled.connect(func(instance_id: String, locked: bool): inventory_lock_toggled.emit(instance_id, locked))
	inventory_panel.discard_requested.connect(func(instance_id: String, confirmed_name: String): inventory_discard_requested.emit(instance_id, confirmed_name))
	content.add_child(inventory_panel)
	expedition_panel = ExpeditionPanelScript.new()
	expedition_panel.name = "ExpeditionRegion"
	expedition_panel.loadout_requested.connect(func(loadout_id: String): loadout_requested.emit(loadout_id))
	expedition_panel.change_hero_requested.connect(_on_change_hero_requested)
	expedition_panel.start_requested.connect(func(): start_requested.emit())
	right_column.add_child(expedition_panel)
	expedition_panel.configure(operations_state.get("expedition", {}))
	_refresh_destinations(operations_state)
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
	well_popup = preload("res://scripts/ui/well_popup.gd").new()
	well_popup.hero_selected.connect(func(id: String, well_id: String): hero_selected.emit(id, "guard", well_id))
	well_popup.guard_recall_requested.connect(func(id: String): guard_recall_requested.emit(id))
	add_child(well_popup)
	for entry in [["operations", body], ["map", campaign_map], ["research", research_panel]]:
		var fit = preload("res://scripts/ui/fitted_page.gd").new()
		fit.name = str(entry[0]).capitalize() + "PageFit"
		fit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(fit)
		fit.configure(entry[1])
		fitted_pages[entry[0]] = fit
	_show_page("operations")

func _research_region() -> Control:
	var panel = preload("res://scripts/ui/research_panel.gd").new()
	panel.name = "ResearchRegion"
	panel.purchase_requested.connect(func(id: String, rank: int, cost: int): research_purchase_requested.emit(id, rank, cost))
	panel.equipment_requested.connect(func(id: String): research_equipment_requested.emit(id))
	panel.refresh(view_state.get("operations", {}).get("research", {}))
	return panel

func _on_guard_picker_requested(well_id: String) -> void:
	guard_picker_requested.emit(well_id)
	for well_data in view_state.get("operations", {}).get("wells", []):
		if str(well_data.get("id", "")) == well_id:
			hero_picker.open_guard(well_data, view_state.get("operations", {}).get("heroes", []), get_viewport().gui_get_focus_owner())
			return

func _manage_map_well(well_id: String) -> void:
	for well in view_state.get("operations", {}).get("wells", []):
		if str(well.get("id", "")) == well_id:
			well_popup.configure(well, view_state.operations.get("heroes", []))
			well_popup.popup_centered(Vector2i(360, 190))
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
	var fitted := page_id == "inventory" or fitted_pages.has(page_id)
	operations_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if fitted else ScrollContainer.SCROLL_MODE_AUTO
	operations_scroll.scroll_vertical = 0
	var outer := operations_scroll.get_node("OuterMargin") as Control
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL if fitted else Control.SIZE_FILL
	for key in fitted_pages:
		fitted_pages[key].visible = key == page_id
	body.visible = page_id == "operations"
	if well_popup != null:
		well_popup.hide()
	campaign_map.visible = page_id == "map"
	research_panel.visible = page_id == "research"
	inventory_panel.visible = page_id == "inventory"
	crew_panel.visible = page_id == "crew"
	for button_id in navigation_buttons:
		navigation_buttons[button_id].button_pressed = button_id == page_id
	_update_responsive_layout()

func _crew_region() -> PanelContainer:
	var panel := _panel("CrewRegion")
	var content := VBoxContainer.new()
	content.name = "CrewContent"
	content.add_child(_label("CREW", 16))
	var summary := _label("Choose your expedition hero in Operations. Change well guards on the Map.", 14)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var roster := VBoxContainer.new()
	roster.name = "CrewRoster"
	roster.add_theme_constant_override("separation", 8)
	var operations_state: Dictionary = view_state.get("operations", {})
	for hero_data in operations_state.get("heroes", []):
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
	research_panel.refresh(research_state)
	var inventory_state: Dictionary = operations_state.get("inventory", {})
	inventory_panel.refresh(inventory_state)
	var new_count := int(inventory_state.get("new_count", 0))
	navigation_buttons["inventory"].text = "INVENTORY (%d)" % new_count if new_count > 0 else "INVENTORY"
	expedition_panel.configure(operations_state.get("expedition", {}))
	_refresh_destinations(operations_state)
	if campaign_map != null:
		campaign_map.refresh(view_state)
	_refresh_crew(operations_state.get("heroes", []))
	if well_popup.visible:
		for well in operations_state.get("wells", []):
			if str(well.get("id", "")) == well_popup.well_id:
				well_popup.configure(well, operations_state.get("heroes", []))
	if hero_picker.visible and hero_picker.mode == "guard":
		for well_data in operations_state.get("wells", []):
			if str(well_data.get("id", "")) == hero_picker.well_id:
				hero_picker.refresh_guard_state(well_data, operations_state.get("heroes", []), str(view_state.get("notices", {}).get("assignment", "")), bool(view_state.get("notices", {}).get("pending_save", false)))
				break

func _refresh_destinations(state: Dictionary) -> void:
	var wells: Array = state.get("wells", [])
	if destination_picker.item_count != wells.size():
		destination_picker.clear()
		for well in wells:
			destination_picker.add_item(str(well.get("label", well.id)))
			destination_picker.set_item_metadata(destination_picker.item_count - 1, str(well.id))
	for index in wells.size():
		destination_picker.set_item_disabled(index, not bool(wells[index].get("prepare_available", false)))
		if wells[index].get("selected", false):
			destination_picker.select(index)

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
	if campaign_map != null:
		campaign_map.custom_minimum_size.y = 720.0 if compact_layout else 620.0
	var grid := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder")
	if grid != null:
		grid.columns = 1 if compact_layout else 2
	var research_workspace := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/ResearchRegion/ResearchContent/ResearchWorkspace")
	if research_workspace != null:
		research_workspace.vertical = compact_layout
