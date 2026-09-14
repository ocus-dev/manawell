class_name OperationsPreview
extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const HeroPickerScript = preload("res://scripts/ui/hero_picker.gd")
const ExpeditionPanelScript = preload("res://scripts/ui/expedition_panel.gd")
const ResourceStripScript = preload("res://scripts/ui/resource_strip.gd")
const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")
const CampaignMapScript = preload("res://scripts/ui/campaign_map.gd")
const ENVIRONMENT_THUMBNAIL: Texture2D = preload("res://assets/side-view/environment/backdrop.png")
const MONSTER_PORTRAITS: Dictionary = {
	"pursuer": preload("res://assets/side-view/pursuer.png"),
	"breaker": preload("res://assets/side-view/breaker.png"),
	"ranged": preload("res://assets/side-view/ranged.png"),
}
const MONSTER_BRIEFINGS: Dictionary = {
	"pursuer": {"label": "Pursuer", "role": "CLOSE-QUARTERS THREAT", "flavor": "Fast-moving scavengers that close distance before the alarm can cycle. Keep them off the operator."},
	"breaker": {"label": "Breaker", "role": "HARVESTER THREAT", "flavor": "Heavy forms that ignore the hero to reach the machine. Stop them before integrity starts to slip."},
	"ranged": {"label": "Ranged", "role": "SUPPRESSION THREAT", "flavor": "Long-range hunters that turn open ground into a firing lane. Watch for the warning flash and keep moving."},
}

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
var destination_picker: OptionButton
var well_popup
var mission_briefing: PanelContainer
var environment_thumbnail: TextureRect
var objective_label: Label
var monster_name_label: Label
var monster_role_label: Label
var monster_flavor_label: Label
var monster_buttons: Dictionary = {}
var selected_monster_id := "pursuer"

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
	campaign_map.node_selected.connect(func(act_id: String, node_id: String): campaign_node_selected.emit(act_id, node_id))
	campaign_map.node_activate.connect(func(act_id: String, node_id: String): campaign_node_activate.emit(act_id, node_id))
	if campaign_map.has_signal("manage_well_requested"):
		campaign_map.manage_well_requested.connect(_manage_map_well)
	content.add_child(campaign_map)
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
	mission_briefing = _briefing_region()
	left_column.add_child(mission_briefing)
	research_panel = _research_region()
	research_panel.visible = false
	content.add_child(research_panel)
	inventory_panel = preload("res://scripts/ui/inventory_panel.gd").new()
	inventory_panel.name = "InventoryRegion"
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
	_update_briefing(operations_state.get("expedition", {}), view_state.get("campaign", {}))
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
	well_popup.hero_selected.connect(func(hero_id: String, well_id: String): hero_selected.emit(hero_id, "guard", well_id))
	well_popup.guard_recall_requested.connect(func(well_id: String): guard_recall_requested.emit(well_id))
	add_child(well_popup)
	_show_page("operations")

func _research_region() -> Control:
	var panel = preload("res://scripts/ui/research_panel.gd").new()
	panel.name = "ResearchRegion"
	panel.purchase_requested.connect(func(id: String, rank: int, cost: int): research_purchase_requested.emit(id, rank, cost))
	panel.equipment_requested.connect(func(id: String): research_equipment_requested.emit(id))
	panel.refresh(view_state.get("operations", {}).get("research", {}))
	return panel

func _briefing_region() -> PanelContainer:
	var panel := _panel("MissionBriefing")
	var content := VBoxContainer.new()
	content.name = "MissionBriefingContent"
	content.add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	var title := _label("MISSION BRIEFING", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("SECTOR B  /  LIVE INTEL", 11))
	content.add_child(header)
	environment_thumbnail = TextureRect.new()
	environment_thumbnail.name = "EnvironmentThumbnail"
	environment_thumbnail.texture = ENVIRONMENT_THUMBNAIL
	environment_thumbnail.custom_minimum_size = Vector2(0, 142)
	environment_thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	environment_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	environment_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	environment_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(environment_thumbnail)
	var location := _label("INTAKE WELL", 12)
	location.name = "EnvironmentName"
	content.add_child(location)
	var status := _label("FOUNDRY  ·  AVAILABLE", 10)
	status.name = "StageStatus"
	content.add_child(status)
	content.add_child(_label("OBJECTIVE", 12))
	objective_label = _label("Clear every hostile wave at Scrap Approach.", 15)
	objective_label.name = "Objective"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(objective_label)
	content.add_child(_label("KNOWN THREATS  ·  SELECT FOR FIELD NOTES", 12))
	var threat_row := HBoxContainer.new()
	threat_row.name = "MonsterPortraits"
	threat_row.add_theme_constant_override("separation", 6)
	for monster_id in ["pursuer", "breaker", "ranged"]:
		var button := _monster_button(monster_id)
		threat_row.add_child(button)
		monster_buttons[monster_id] = button
	content.add_child(threat_row)
	var dossier := PanelContainer.new()
	dossier.name = "MonsterDossier"
	var dossier_content := VBoxContainer.new()
	dossier_content.name = "MonsterDossierContent"
	monster_name_label = _label("", 14)
	monster_name_label.name = "MonsterName"
	dossier_content.add_child(monster_name_label)
	monster_role_label = _label("", 10)
	monster_role_label.name = "MonsterRole"
	dossier_content.add_child(monster_role_label)
	monster_flavor_label = _label("", 12)
	monster_flavor_label.name = "MonsterFlavor"
	monster_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dossier_content.add_child(monster_flavor_label)
	dossier.add_child(dossier_content)
	content.add_child(dossier)
	panel.add_child(content)
	_select_monster(selected_monster_id)
	return panel

func _monster_button(monster_id: String) -> Button:
	var button := Button.new()
	button.name = "Monster_%s" % monster_id
	button.custom_minimum_size = Vector2(72, 72)
	button.toggle_mode = true
	button.tooltip_text = str(MONSTER_BRIEFINGS[monster_id].get("label", monster_id))
	button.pressed.connect(_select_monster.bind(monster_id))
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = MONSTER_PORTRAITS[monster_id]
	button.add_child(portrait)
	return button

func _select_monster(monster_id: String) -> void:
	selected_monster_id = monster_id
	_update_monster_dossier(monster_id)
	for id in monster_buttons:
		monster_buttons[id].button_pressed = id == monster_id

func _update_monster_dossier(monster_id: String) -> void:
	if monster_name_label == null or not MONSTER_BRIEFINGS.has(monster_id):
		return
	var briefing: Dictionary = MONSTER_BRIEFINGS[monster_id]
	monster_name_label.text = str(briefing.get("label", monster_id)).to_upper()
	monster_role_label.text = str(briefing.get("role", "UNKNOWN THREAT"))
	monster_flavor_label.text = str(briefing.get("flavor", "No field notes available."))

func _update_briefing(expedition: Dictionary, campaign: Dictionary = {}) -> void:
	if objective_label == null:
		return
	var node: Dictionary = campaign.get("briefing_node", {})
	var level_data: Dictionary = node.get("level_data", {})
	var stage_name := str(node.get("display_name", expedition.get("destination_label", "Intake Well")))
	var objective_data: Dictionary = level_data.get("completion", {})
	match str(objective_data.get("objective", "")):
		"extract":
			objective_label.text = "Stabilize %s and survive %d complete surge." % [stage_name, maxi(1, int(objective_data.get("minimum_completed_surges", 1)))]
		"defeat_boss":
			objective_label.text = "Defeat the %s at %s." % [str(objective_data.get("boss_spawn_id", "boss")).replace("_", " ").capitalize(), stage_name]
		_:
			objective_label.text = "Clear every hostile wave at %s. Protect the operator while the route is secured." % stage_name
	var location := mission_briefing.get_node_or_null("MissionBriefingContent/EnvironmentName") as Label
	if location != null:
		location.text = stage_name.to_upper()
	var status_label := mission_briefing.get_node_or_null("MissionBriefingContent/StageStatus") as Label
	if status_label != null:
		var stage_status: Dictionary = campaign.get("statuses", {}).get(str(node.get("id", "")), {})
		status_label.text = "%s  ·  %s" % [str(level_data.get("environment_id", "foundry")).to_upper(), str(stage_status.get("status", "available")).to_upper()]
	var available_monsters: Array = level_data.get("encounter", {}).get("available_monsters", [])
	for monster_id in monster_buttons:
		monster_buttons[monster_id].visible = str(monster_id) in available_monsters
	var first_visible := ""
	for monster_id in monster_buttons:
		if monster_buttons[monster_id].visible:
			first_visible = monster_id
			break
	if not first_visible.is_empty():
		_select_monster(first_visible)
	else:
		monster_name_label.text = "NO THREAT PROFILE"
		monster_role_label.text = ""
		monster_flavor_label.text = "No field notes available for this encounter."

func _on_guard_picker_requested(well_id: String) -> void:
	guard_picker_requested.emit(well_id)
	for well_data in view_state.get("operations", {}).get("wells", []):
		if str(well_data.get("id", "")) == well_id:
			hero_picker.open_guard(well_data, view_state.get("operations", {}).get("heroes", []), get_viewport().gui_get_focus_owner())
			return

func _manage_map_well(well_id: String) -> void:
	for well in view_state.get("operations", {}).get("wells", []):
		if str(well.get("id", "")) == well_id:
			if well_popup == null:
				return
			well_popup.configure(well, view_state.get("operations", {}).get("heroes", []))
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
	body.visible = page_id == "operations"
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
	var summary := _label("Assign expedition heroes and guards from the Operations page. This roster keeps role and availability visible as the crew system grows.", 14)
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
	_update_briefing(operations_state.get("expedition", {}), view_state.get("campaign", {}))
	if campaign_map != null:
		campaign_map.refresh(view_state)
	_refresh_crew(operations_state.get("heroes", []))
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
	var research_workspace := get_node_or_null("OperationsScroll/OuterMargin/OperationsContent/ResearchRegion/ResearchContent/ResearchWorkspace")
	if research_workspace != null:
		research_workspace.vertical = compact_layout
