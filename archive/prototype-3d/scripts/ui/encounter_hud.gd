class_name EncounterHUD
extends Control

const OperationsPreviewScript = preload("res://scripts/ui/operations_preview.gd")
const CombatPreviewScript = preload("res://scripts/ui/combat_preview.gd")
const PresentationRouterScript = preload("res://scripts/ui/presentation_router.gd")
const NoticeHostScript = preload("res://scripts/ui/notice_host.gd")
const SettingsPanelScript = preload("res://scripts/ui/settings_panel.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")

signal well_selected(well_id: String)
signal loadout_selected(loadout_id: String)
signal active_hero_selected(hero_id: String)
signal guard_assigned(hero_id: String, well_id: String)
signal guard_recalled(well_id: String)
signal upgrade_requested(upgrade_id: String)

var view_state: Dictionary = {}
var selected_well_id: String = "well_1"
var selected_loadout_id: String = "standard"
var selected_active_hero_id: String = "hero_1"
var selected_guard_id: String = ""
var controller: Node
var operations: Control
var combat: Control
var router: Control
var notice_host: Control
var settings_panel: Control
var settings_opener: Control

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	_build()

func build(owner: Node) -> void:
	controller = owner
	if not is_inside_tree():
		owner.add_child(self)
	if operations == null:
		_build()
	_configure_commands()
	set_view_state(view_state)

func set_view_state(next_state: Dictionary) -> void:
	view_state = next_state.duplicate(true)
	selected_well_id = str(view_state.get("selected_well_id", selected_well_id))
	selected_loadout_id = str(view_state.get("selected_loadout_id", selected_loadout_id))
	selected_active_hero_id = str(view_state.get("active_hero_id", selected_active_hero_id))
	selected_guard_id = str(view_state.get("guard_id", selected_guard_id))
	if operations == null:
		return
	var operations_state: Dictionary = view_state.get("operations", {})
	var combat_state: Dictionary = view_state.get("combat", {})
	if operations != null:
		operations.refresh(view_state)
	if combat != null:
		combat.configure(view_state)
	if notice_host != null:
		notice_host.configure(view_state.get("notices", {}))
	if settings_panel != null:
		settings_panel.configure(view_state.get("notices", {}))
	if router != null:
		router.configure(view_state)
	var active := bool(combat_state.get("active", false))
	operations.visible = not active
	combat.visible = active
	if int(combat_state.get("phase", 0)) >= 3:
		operations.visible = false
		combat.visible = false
	if operations_state.is_empty():
		operations.visible = false
	var terminal := int(combat_state.get("phase", 0)) >= 3
	if bool(combat_state.get("paused", false)) and router.mode != "pause":
		router.show_pause(combat_state)
	elif terminal and router.mode != "results":
		router.show_results(view_state.get("results", {}))
	elif not bool(combat_state.get("paused", false)) and not terminal and router.mode != "hidden":
		router.hide_overlays()

func choose_well(well_id: String) -> void:
	well_selected.emit(well_id)

func choose_loadout(loadout_id: String) -> void:
	loadout_selected.emit(loadout_id)

func choose_active_hero(hero_id: String) -> void:
	active_hero_selected.emit(hero_id)

func assign_guard(hero_id: String, well_id: String) -> void:
	guard_assigned.emit(hero_id, well_id)

func recall_guard(well_id: String) -> void:
	guard_recalled.emit(well_id)

func request_upgrade(upgrade_id: String) -> void:
	upgrade_requested.emit(upgrade_id)

func _build() -> void:
	if operations != null:
		return
	name = "EncounterHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	operations = OperationsPreviewScript.new()
	operations.name = "Operations"
	operations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	operations.include_notice_placeholder = false
	add_child(operations)
	combat = CombatPreviewScript.new()
	combat.name = "Combat"
	combat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(combat)
	router = PresentationRouterScript.new()
	router.name = "PresentationRouter"
	router.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(router)
	notice_host = NoticeHostScript.new()
	notice_host.name = "NoticeHost"
	notice_host.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	notice_host.position = Vector2(24, -150)
	notice_host.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(notice_host)
	settings_panel = SettingsPanelScript.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-180, -150)
	settings_panel.visible = false
	add_child(settings_panel)
	_configure_commands()

func _configure_commands() -> void:
	if controller == null or operations == null or router == null:
		return
	if not operations.destination_requested.is_connected(_on_destination_requested):
		operations.destination_requested.connect(_on_destination_requested)
		operations.guard_picker_requested.connect(_on_guard_picker_requested)
		operations.hero_selected.connect(_on_hero_selected)
		operations.guard_recall_requested.connect(_on_guard_recall_requested)
		operations.loadout_requested.connect(_on_loadout_requested)
		operations.start_requested.connect(_on_start_requested)
		operations.purchase_requested.connect(_on_purchase_requested)
		operations.settings_requested.connect(_show_settings)
		combat.pause_requested.connect(controller.toggle_pause)
		combat.harvest_requested.connect(controller.request_start_or_harvest)
		combat.ability_requested.connect(_on_ability_requested)
		router.resume_requested.connect(controller.toggle_pause)
		router.abandon_requested.connect(controller.abandon)
		router.return_requested.connect(controller.return_to_operations)
		router.retry_requested.connect(controller.retry)
		router.settings_requested.connect(_show_settings)
		notice_host.action_requested.connect(_on_notice_action)
		settings_panel.retry_save_requested.connect(controller.retry_pending_save)
		settings_panel.retry_settlement_requested.connect(controller.retry_offline_settlement)
		settings_panel.clear_requested.connect(_on_clear_requested)
		settings_panel.developer_toggle_requested.connect(controller._toggle_sealing_setting)
		settings_panel.closed.connect(_hide_settings)

func _on_destination_requested(well_id: String) -> void:
	well_selected.emit(well_id)

func _on_guard_picker_requested(_well_id: String) -> void:
	pass

func _on_hero_selected(hero_id: String, mode: String, well_id: String) -> void:
	if mode == "guard":
		guard_assigned.emit(hero_id, well_id)
	else:
		active_hero_selected.emit(hero_id)

func _on_guard_recall_requested(well_id: String) -> void:
	guard_recalled.emit(well_id)

func _on_loadout_requested(loadout_id: String) -> void:
	loadout_selected.emit(loadout_id)

func _on_start_requested() -> void:
	controller.request_start_or_harvest()

func _on_purchase_requested(upgrade_id: String) -> void:
	upgrade_requested.emit(upgrade_id)

func _on_ability_requested(ability_id: String) -> void:
	if ability_id == "dash":
		controller.pending_dash = true
	elif ability_id == "pulse":
		controller.pending_pulse = true

func _show_settings(opener: Control = null) -> void:
	settings_opener = opener if is_instance_valid(opener) else get_viewport().gui_get_focus_owner()
	settings_panel.visible = true
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.configure(view_state.get("notices", {}))
	settings_panel.get_node("SettingsContent/RetrySave").grab_focus()

func _hide_settings() -> void:
	settings_panel.visible = false
	if is_instance_valid(settings_opener):
		settings_opener.grab_focus()
	settings_opener = null

func _on_notice_action(action_id: String) -> void:
	if action_id == "retry_save":
		controller.retry_pending_save()
	elif action_id == "retry_settlement":
		controller.retry_offline_settlement()

func _on_clear_requested() -> void:
	controller.clear_saved_progress()
	if str(controller.save_store.last_error).is_empty():
		_hide_settings()
