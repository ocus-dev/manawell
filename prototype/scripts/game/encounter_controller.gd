extends Node2D

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const HeroScript = preload("res://scripts/game/player.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const EncounterHUDScript = preload("res://scripts/ui/encounter_hud.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const ProductionScript = preload("res://scripts/model/production.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const SessionPersistenceScript = preload("res://scripts/model/session_persistence.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const EnvironmentScript = preload("res://scripts/game/side_view_environment_visual.gd")
const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const FIXED_STEP: float = 1.0 / 60.0
const GROUND_Y: float = 652.0
const MACHINE_X: float = 160.0

@export var persistence_enabled: bool = true
@export var use_prepared_environment: bool = true

@onready var hero: Node2D = $Hero

var status_text := "READY - jump motion milestone"
var pause_button: Button
var run_state: RefCounted = RunStateScript.new()
var enemies: Array[Node] = []
var projectiles: Array[Node] = []
var spawned_kinds: Array[int] = []
var next_enemy_id: int = 1
var spawner_rng_state: int = 1
var objective_progress: int = 0
var objective_required: int = 0
var objective_credited_ids: Array[String] = []
var claim_receipts: Array[String] = []
var frozen_level_definition: Dictionary = {}
var frozen_level_content_hash: String = ""
var weapon_clock: float = 0.0
var dash_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var pulse_cooldown_remaining: float = 0.0
var spawn_timer: float = 0.0
var spawn_index: int = 0
var side_sequence: int = 0
var pending_entry_warnings: Array[Dictionary] = []
var content_catalog: RefCounted = ContentCatalogScript.new()
var presentation_time: float = 0.0
var machine_flash_remaining: float = 0.0
var pulse_feedback_remaining: float = 0.0
var harvest_feedback_elapsed: float = 0.0
var harvest_feedback_amount: float = 0.0
var harvest_feedback_remaining: float = 0.0
var last_machine_integrity: float = BalanceData.MACHINE_INTEGRITY
var account_state: RefCounted = AccountStateScript.new()
var campaign_state: RefCounted = CampaignStateScript.new()
var encounter_hud: Control
var pending_dash := false
var pending_jump := false
var pending_pulse := false
var pending_harvest := false
var pending_pause := false
var jump_held := false
var move_left_held := false
var move_right_held := false
var move_down_held := false
var credited_run_id := ""
var selected_well_id: String = "well_1"
var selected_loadout_id: String = LoadoutScript.STANDARD
var production: RefCounted = ProductionScript.new()
var production_time_override: float = -1.0
var last_production_time: float = 0.0
var weapon_damage: float = BalanceData.WEAPON_DAMAGE
var weapon_projectile_count: int = 1
var checkpoint_elapsed: float = 0.0
var save_store: RefCounted = SaveStoreScript.new()
var session_persistence: RefCounted
var production_utc_timestamp: float = 0.0
var assignment_notice: String = ""
var ui_scale: float = 1.0
var harvester_visual: Node
var environment_visual: Node

func _ready() -> void:
	environment_visual = EnvironmentScript.new()
	environment_visual.name = "EnvironmentVisual"
	environment_visual.use_prepared_layers = use_prepared_environment
	add_child(environment_visual)
	harvester_visual = VisualScript.new()
	harvester_visual.name = "HarvesterVisual"
	harvester_visual.position = Vector2(MACHINE_X, GROUND_Y - 40.0)
	harvester_visual.z_index = 1
	add_child(harvester_visual)
	harvester_visual.configure("harvester")
	harvester_visual.set_scale_multiplier(1.4)
	if hero != null:
		hero.z_index = 2
	_ensure_session_persistence()
	if persistence_enabled:
		account_state = session_persistence.load_account()
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "EncounterLayer"
	add_child(hud_layer)
	encounter_hud = EncounterHUDScript.new()
	hud_layer.add_child(encounter_hud)
	encounter_hud.build(self)
	set_ui_scale(ui_scale)
	encounter_hud.well_selected.connect(select_well_by_id)
	encounter_hud.loadout_selected.connect(select_loadout_by_id)
	encounter_hud.active_hero_selected.connect(select_active_hero_by_id)
	encounter_hud.guard_assigned.connect(assign_guard_by_id)
	encounter_hud.guard_recalled.connect(recall_guard_by_well_id)
	encounter_hud.upgrade_requested.connect(purchase_upgrade)
	encounter_hud.campaign_node_selected.connect(select_campaign_node)
	encounter_hud.campaign_node_activate.connect(activate_campaign_node)
	_update_hud()
	_restore_saved_snapshot()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pending_dash = false
		pending_jump = false
		pending_pulse = false
		pending_harvest = false
		jump_held = false
		move_left_held = false
		move_right_held = false
		move_down_held = false
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		pending_dash = false
		pending_jump = false
		pending_pulse = false
		pending_harvest = false
		jump_held = false
		move_left_held = false
		move_right_held = false
		move_down_held = false
	if not persistence_enabled:
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_account(_capture_snapshot() if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else {})
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause_game"):
		pending_pause = true
	if run_state.paused:
		return
	simulate_step(FIXED_STEP)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("move_left"):
		move_left_held = event.is_pressed()
	elif event.is_action("move_right"):
		move_right_held = event.is_pressed()
	elif event.is_action("move_down"):
		move_down_held = event.is_pressed()
	elif event.is_action("jump"):
		jump_held = event.is_pressed()
		if event.is_pressed() and not event.is_echo():
			pending_jump = true
	elif not event.is_pressed() or event.is_echo():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("dash"):
		pending_dash = true
	elif event.is_action_pressed("pulse"):
		pending_pulse = true
	elif event.is_action_pressed("harvest"):
		pending_harvest = true
	elif event.is_action_pressed("pause_game"):
		pending_pause = true
	get_viewport().set_input_as_handled()

func simulate_step(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or run_state.paused:
		return
	var remaining := delta
	while remaining > 0.0:
		var step := minf(FIXED_STEP, remaining)
		_simulation_step(step)
		remaining -= step

func tick(delta: float) -> void:
	simulate_step(delta)
	_update_hud()

func _simulation_step(delta: float) -> void:
	_apply_pending_commands()
	if run_state.paused:
		return
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		return
	if hero == null:
		hero = get_node_or_null("Hero") as Node2D
	if hero == null:
		return
	var left_strength := 1.0 if move_left_held else 0.0
	var right_strength := 1.0 if move_right_held else 0.0
	var signed_input: float = clampf(right_strength - left_strength, -1.0, 1.0)
	var jump_pressed := pending_jump
	pending_jump = false
	var drop_requested := jump_pressed and move_down_held
	if dash_remaining > 0.0:
		hero.simulate_motion(delta, signed_input, dash_direction, true, jump_pressed, jump_held, drop_requested)
		dash_remaining = maxf(0.0, dash_remaining - delta)
	else:
		hero.simulate_motion(delta, signed_input, 0, false, jump_pressed, jump_held, drop_requested)
	if not is_zero_approx(signed_input):
		last_input_direction = 1 if signed_input > 0.0 else -1
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	pulse_cooldown_remaining = maxf(0.0, pulse_cooldown_remaining - delta)
	_advance_spawning(delta)
	_simulate_enemies(delta)
	_simulate_projectiles(delta)
	_simulate_weapon(delta)
	var tank_before_advance: float = run_state.tank_base
	run_state.advance(delta)
	if run_state.phase == RunStateScript.Phase.EXTRACTING:
		var harvested_delta: float = maxf(0.0, run_state.tank_base - tank_before_advance)
		harvest_feedback_elapsed += delta
		if harvest_feedback_elapsed >= 1.0:
			harvest_feedback_amount = harvested_delta + run_state.extraction_rate * (harvest_feedback_elapsed - delta)
			harvest_feedback_remaining = 0.85
			harvest_feedback_elapsed = fmod(harvest_feedback_elapsed, 1.0)
	else:
		harvest_feedback_elapsed = 0.0
	harvest_feedback_remaining = maxf(0.0, harvest_feedback_remaining - delta)
	_credit_if_complete()
	if run_state.machine_integrity < last_machine_integrity:
		machine_flash_remaining = 0.16
	last_machine_integrity = run_state.machine_integrity
	machine_flash_remaining = maxf(0.0, machine_flash_remaining - delta)
	pulse_feedback_remaining = maxf(0.0, pulse_feedback_remaining - delta)
	queue_redraw()

func _apply_pending_commands() -> void:
	if pending_pause:
		pending_pause = false
		toggle_pause()
	if pending_dash:
		pending_dash = false
		try_dash(0)
	if pending_pulse:
		pending_pulse = false
		try_pulse()
	if pending_harvest:
		pending_harvest = false
		request_start_or_harvest()

var dash_direction: int = 1
var last_input_direction: int = 0

func start_run() -> bool:
	if run_state.phase != RunStateScript.Phase.READY:
		return false
	if not content_catalog.has_well(selected_well_id) or not account_state.is_well_unlocked(selected_well_id):
		return false
	var hero_id: String = account_state.get_active_hero_id()
	if hero_id.is_empty():
		return false
	var modifiers: Dictionary = LoadoutScript.modifiers(selected_loadout_id)
	var well_data: Dictionary = content_catalog.get_well(selected_well_id)
	var extraction_rate: float = float(well_data.get("base_output", BalanceData.WELL_1_BASE_OUTPUT)) * float(modifiers["extraction_multiplier"])
	if account_state.has_upgrade("pump_1"):
		extraction_rate *= BalanceData.PUMP_OUTPUT_MULTIPLIER
	weapon_damage = BalanceData.WEAPON_DAMAGE + (BalanceData.DAMAGE_UPGRADE_BONUS if account_state.has_upgrade("damage_1") else 0.0)
	var run_id: String = account_state.allocate_run_id()
	var machine_max: float = BalanceData.MACHINE_INTEGRITY * float(modifiers["machine_integrity_multiplier"])
	if not run_state.start(run_id, selected_well_id, hero_id, selected_loadout_id, extraction_rate, BalanceData.SEALING_DURATION, BalanceData.HERO_HEALTH, machine_max, float(modifiers["pressure_time_scale"])):
		return false
	_freeze_level_definition(well_data)
	spawner_rng_state = 1
	objective_progress = 0
	objective_required = 0
	objective_credited_ids.clear()
	claim_receipts.clear()
	if hero == null:
		hero = get_node_or_null("Hero") as Node2D
	status_text = "EXTRACTING - protect the harvester"
	account_state.release_guard_for_start(selected_well_id)
	production.reset_cursor(_current_production_time())
	_save_account()
	_update_hud()
	return true

func request_harvest() -> bool:
	var harvested: bool = run_state.request_harvest()
	if harvested:
		status_text = "SEALING - payout locked: %d" % run_state.locked_payout
	_update_hud()
	return harvested

func request_start_or_harvest() -> void:
	if run_state.phase == RunStateScript.Phase.READY:
		var catalog: RefCounted = campaign_state_catalog()
		var stage: Dictionary = campaign_state.furthest_progression_node(catalog)
		if not stage.is_empty():
			var act_id: String = campaign_state.active_act_id if not campaign_state.active_act_id.is_empty() else catalog.first_act_id()
			start_campaign_node(act_id, str(stage.get("id", "")))
	elif run_state.phase == RunStateScript.Phase.EXTRACTING:
		request_harvest()

func campaign_state_catalog() -> RefCounted:
	return CampaignCatalogScript.new()

func start_campaign_node(act_id: String, node_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY or not campaign_state.start_node(act_id, node_id, campaign_state_catalog()):
		return false
	var node: Dictionary = campaign_state_catalog().get_node(act_id, node_id)
	var well_id: String = str(node.get("well_id", selected_well_id))
	if node.is_empty() or not content_catalog.has_well(well_id) or not account_state.is_well_unlocked(well_id):
		campaign_state.clear_active_node()
		return false
	selected_well_id = well_id
	selected_loadout_id = account_state.get_loadout_for_well(well_id)
	if not start_run():
		campaign_state.clear_active_node()
		return false
	frozen_level_definition = node.get("level_data", {}).duplicate(true)
	frozen_level_content_hash = SnapshotScript.content_hash_for(frozen_level_definition)
	_apply_level_backdrop()
	return true

func select_campaign_node(act_id: String, node_id: String) -> bool:
	return campaign_state.node_status(act_id, node_id, campaign_state_catalog())["status"] != CampaignStateScript.STATUS_LOCKED

func activate_campaign_node(act_id: String, node_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY:
		assignment_notice = "Resolve the current encounter before starting another level."
		_update_hud()
		return false
	return start_campaign_node(act_id, node_id)

func select_well_by_id(well_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY and run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return false
	if well_id != "well_1" and well_id != "well_2":
		return false
	if not account_state.is_well_unlocked(well_id):
		return false
	selected_well_id = well_id
	selected_loadout_id = account_state.get_loadout_for_well(well_id)
	_update_hud()
	return true

func select_loadout_by_id(loadout_id: String) -> bool:
	var first_expedition: bool = content_catalog.has_well(selected_well_id) and account_state.is_well_unlocked(selected_well_id) and not account_state.is_well_commissioned(selected_well_id)
	var selected: bool = account_state.select_loadout(selected_well_id, loadout_id)
	if first_expedition and loadout_id == LoadoutScript.STANDARD:
		selected = true
	if run_state.phase != RunStateScript.Phase.READY or not selected:
		return false
	selected_loadout_id = loadout_id
	_update_hud()
	return true

func select_active_hero_by_id(hero_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY or not account_state.has_hero(hero_id):
		return false
	var changed: bool = account_state.select_active_hero(hero_id)
	if changed:
		_save_account()
	_update_hud()
	return changed

func assign_guard_by_id(hero_id: String, well_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	var assigned: bool = account_state.assign_guard(hero_id, well_id)
	if assigned:
		_save_account()
	_update_hud()
	return assigned

func recall_guard_by_well_id(well_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	var recalled: bool = account_state.recall_guard(well_id)
	if recalled:
		_save_account()
	_update_hud()
	return recalled

func purchase_upgrade(upgrade_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	var purchased: bool = account_state.purchase_upgrade(upgrade_id)
	if purchased:
		_save_account()
	_update_hud()
	return purchased

func retry_pending_save() -> bool:
	_ensure_session_persistence()
	return session_persistence.retry_pending_save()

func retry_offline_settlement() -> bool:
	return retry_pending_save()

func clear_saved_progress() -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	_ensure_session_persistence()
	var cleared: bool = save_store.clear_save()
	if cleared:
		account_state = AccountStateScript.new()
		session_persistence.account = account_state
		session_persistence.reset_after_clear()
	return cleared

func _settle_offline_production(now_timestamp: float) -> bool:
	_ensure_session_persistence()
	if not save_store.writes_allowed:
		return false
	var rates: Dictionary = ProductionScript.calculate_rates(account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades)
	var result: Dictionary = ProductionScript.offline_settlement(now_timestamp, save_store.loaded_production_utc_timestamp, rates)
	account_state.bank += float(result.get("total", 0.0))
	return session_persistence.save()

func _toggle_sealing_setting() -> void:
	pass

func set_resolution(width: int, height: int) -> void:
	if width <= 0 or height <= 0:
		return
	DisplayServer.window_set_size(Vector2i(width, height))

func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.7, 1.0)
	if encounter_hud != null:
		encounter_hud.pivot_offset = Vector2(640.0, 360.0)
		encounter_hud.scale = Vector2.ONE * ui_scale

func toggle_pause() -> void:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		set_experiment_paused(not run_state.paused)

func return_to_operations() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return
	_clear_transients()
	run_state.reset()
	credited_run_id = ""
	_update_hud()

func abandon() -> void:
	if run_state.abandon():
		_clear_transients()
		_update_hud()

func _clear_transients() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	enemies.clear()
	projectiles.clear()

func _credit_if_complete() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS or credited_run_id == run_state.run_id:
		return
	var result: Dictionary = run_state.get_terminal_result()
	var completed: bool = campaign_state.commit_terminal_result(result, account_state, campaign_state_catalog()) if not campaign_state.active_node_id.is_empty() else account_state.complete_run(result, run_state.run_id, run_state.selected_well_id, run_state.completed_surges)
	if completed:
		credited_run_id = run_state.run_id
		_save_account()

func _current_production_time() -> float:
	if production_time_override >= 0.0:
		return production_time_override
	if session_persistence != null:
		return session_persistence.now_monotonic()
	return Time.get_ticks_msec() / 1000.0

func _settle_production() -> void:
	var timestamp: float = _current_production_time()
	if not is_finite(timestamp):
		return
	var active_well: String = run_state.selected_well_id if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else ""
	var settlement: Dictionary = production.settle(timestamp, account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, active_well)
	account_state.bank += float(settlement.get("total", 0.0))
	last_production_time = timestamp

func configure_persistence(new_store: RefCounted, new_monotonic_clock: Callable = Callable(), new_utc_clock: Callable = Callable()) -> void:
	save_store = new_store
	session_persistence = SessionPersistenceScript.new(save_store, account_state, new_monotonic_clock, new_utc_clock, campaign_state)

func _ensure_session_persistence() -> void:
	if session_persistence == null or session_persistence.store != save_store:
		session_persistence = SessionPersistenceScript.new(save_store, account_state, Callable(), Callable(), campaign_state)

func _load_account() -> void:
	_ensure_session_persistence()
	account_state = session_persistence.load_account()
	selected_loadout_id = account_state.get_loadout_for_well(selected_well_id)

func _save_account(snapshot: Dictionary = {}) -> bool:
	if not persistence_enabled:
		return true
	_ensure_session_persistence()
	return session_persistence.save(snapshot)

func _capture_snapshot() -> Dictionary:
	var actors: Array = [
		{"id": "hero", "kind": "hero", "position": [hero.position.x, hero.position.y], "health": run_state.hero_health, "max_health": BalanceData.HERO_HEALTH, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": hero.capture_snapshot_state()},
		{"id": "machine", "kind": "machine", "position": [MACHINE_X, GROUND_Y], "health": run_state.machine_integrity, "max_health": run_state.machine_max_integrity, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}},
	]
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			actors.append({"id": "enemy-%d" % enemy.enemy_id, "kind": "ranged" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "breaker" if enemy.enemy_kind == EnemyScript.EnemyKind.BREAKER else "pursuer", "position": [enemy.position.x, enemy.position.y], "health": enemy.health, "max_health": enemy.max_health, "cooldown_remaining": enemy.cooldown_remaining, "windup_remaining": enemy.windup_remaining, "target_id": "hero" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED or enemy.enemy_kind == EnemyScript.EnemyKind.PURSUER else "", "dead": false, "component_state": enemy.capture_snapshot_state()})
	var projectile_states: Array = []
	for index in projectiles.size():
		var projectile: Node = projectiles[index]
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			var owner_id: String = "hero"
			var target_id: String = "hero"
			if projectile.hostile:
				owner_id = "enemy-%d" % projectile.source_enemy_id if projectile.source_enemy_id > 0 else "hero"
			if not projectile.hostile:
				var target: Node = closest_live_enemy_between(projectile.position, projectile.position + projectile.velocity)
				target_id = "enemy-%d" % target.enemy_id if target != null else "hero"
			projectile_states.append({"id": "projectile-%d" % index, "kind": "hostile" if projectile.hostile else "friendly", "owner_id": owner_id, "target_id": target_id, "position": [projectile.position.x, projectile.position.y], "velocity": [projectile.velocity.x, projectile.velocity.y], "damage": projectile.damage, "lifetime_remaining": projectile.lifetime_remaining, "hit_target": projectile.hit_target})
	return {"run_state": {"run_id": run_state.run_id, "well_id": run_state.selected_well_id, "hero_id": run_state.selected_hero_id, "module_id": run_state.selected_module_id, "phase": run_state.phase, "paused": true, "simulation_elapsed": run_state.simulation_elapsed, "tank_base": run_state.tank_base, "extraction_rate": run_state.extraction_rate, "pressure_time_scale": run_state.pressure_time_scale, "completed_surges": run_state.completed_surges, "multiplier": run_state.multiplier, "locked_payout": run_state.locked_payout, "sealing_remaining": run_state.sealing_remaining, "sealing_duration": run_state.sealing_duration, "hero_health": run_state.hero_health, "machine_integrity": run_state.machine_integrity, "machine_max_integrity": run_state.machine_max_integrity, "terminal_reason": run_state.terminal_reason}, "actors": actors, "projectiles": projectile_states, "player_abilities": {"dash_cooldown_remaining": dash_cooldown_remaining, "pulse_cooldown_remaining": pulse_cooldown_remaining, "dash_remaining": dash_remaining, "dash_direction": [float(dash_direction), 0.0], "dash_active": dash_remaining > 0.0, "ability_flash_remaining": 0.0}, "weapon_state": {"damage": weapon_damage, "spread_enabled": account_state.has_upgrade("spread_1"), "attack_interval": BalanceData.WEAPON_INTERVAL, "shot_accumulator": weapon_clock}, "spawner": {"spawn_timer": spawn_timer, "spawn_index": spawn_index, "spawn_position": [40.0, GROUND_Y], "config_id": "%s-%s" % [selected_well_id, selected_loadout_id], "next_id": next_enemy_id, "rng_state": spawner_rng_state}, "arena_config_id": ArenaLayoutScript.CONFIG_ID, "director": get_director_state(), "level_definition": frozen_level_definition.duplicate(true), "level_content_hash": frozen_level_content_hash, "campaign": {"act_id": campaign_state.active_act_id, "node_id": campaign_state.active_node_id, "config_id": "%s-%s" % [selected_well_id, selected_loadout_id], "wave_index": spawn_index, "boss_timer": 0.0}, "objective": {"objective_id": "", "progress": objective_progress, "required": objective_required, "credited_ids": objective_credited_ids.duplicate()}, "reward_state": {"claim_receipts": claim_receipts.duplicate(), "pending_items": account_state.pending_rewards.duplicate(true)}}

func _restore_saved_snapshot() -> void:
	if not persistence_enabled:
		return
	if save_store.loaded_snapshot.is_empty():
		if not save_store.recovery_message.is_empty():
			assignment_notice = save_store.recovery_message
		return
	if hero == null:
		hero = get_node_or_null("Hero") as Node2D
	if hero == null:
		return
	var decoded: Dictionary = SnapshotScript.decode(save_store.loaded_snapshot)
	if not decoded.get("valid", false):
		assignment_notice = "Active encounter snapshot was rejected; banked progress was preserved."
		return
	var snapshot: Dictionary = decoded["snapshot"]
	var state: Dictionary = snapshot["run_state"]
	selected_well_id = str(state["well_id"])
	selected_loadout_id = str(state["module_id"])
	for field in state.keys():
		if run_state.get(field) != null:
			run_state.set(field, state[field])
	run_state.paused = true
	var hero_state: Dictionary = {}
	for actor in snapshot["actors"]:
		if actor["kind"] == "hero":
			hero_state = actor
			break
	if hero_state.is_empty():
		return
	hero.position = Vector2(hero_state["position"][0], hero_state["position"][1])
	hero.restore_snapshot_state(hero_state["component_state"])
	_clear_transients()
	for actor in snapshot["actors"]:
		if actor["kind"] == "hero" or actor["kind"] == "machine":
			continue
		var kind: int = EnemyScript.EnemyKind.RANGED if actor["kind"] == "ranged" else EnemyScript.EnemyKind.BREAKER if actor["kind"] == "breaker" else EnemyScript.EnemyKind.PURSUER
		var restored_enemy: Node = spawn_enemy(kind, int(actor["component_state"].get("side", 1)))
		if restored_enemy != null:
			restored_enemy.enemy_id = int(actor["component_state"].get("enemy_id", restored_enemy.enemy_id))
			restored_enemy.position = Vector2(actor["position"][0], actor["position"][1])
			restored_enemy.health = float(actor["health"])
			restored_enemy.cooldown_remaining = float(actor["cooldown_remaining"])
			restored_enemy.windup_remaining = float(actor["windup_remaining"])
			restored_enemy.restore_snapshot_state(actor["component_state"])
	for projectile_data in snapshot["projectiles"]:
		var restored_projectile: Node = ProjectileScript.new()
		add_child(restored_projectile)
		restored_projectile.controller = self
		restored_projectile.position = Vector2(projectile_data["position"][0], projectile_data["position"][1])
		restored_projectile.velocity = Vector2(float(projectile_data["velocity"][0]), float(projectile_data["velocity"][1]))
		restored_projectile.velocity_x = restored_projectile.velocity.x
		restored_projectile.damage = float(projectile_data["damage"])
		restored_projectile.lifetime_remaining = float(projectile_data["lifetime_remaining"])
		restored_projectile.hostile = projectile_data["kind"] == "hostile"
		restored_projectile.owner_id = str(projectile_data["owner_id"])
		restored_projectile.target_id = str(projectile_data["target_id"])
		if restored_projectile.hostile and restored_projectile.owner_id.begins_with("enemy-"):
			restored_projectile.source_enemy_id = int(restored_projectile.owner_id.trim_prefix("enemy-"))
		projectiles.append(restored_projectile)
	spawn_timer = snapshot["spawner"]["spawn_timer"]
	spawn_index = snapshot["spawner"]["spawn_index"]
	next_enemy_id = snapshot["spawner"]["next_id"]
	spawner_rng_state = int(snapshot["spawner"]["rng_state"])
	frozen_level_definition = snapshot["level_definition"].duplicate(true)
	frozen_level_content_hash = str(snapshot["level_content_hash"])
	_apply_level_backdrop()
	var campaign: Dictionary = snapshot["campaign"]
	if campaign.has("act_id") and campaign["act_id"] is String:
		campaign_state.active_act_id = campaign["act_id"]
	if campaign.has("node_id") and campaign["node_id"] is String:
		campaign_state.active_node_id = campaign["node_id"]
	var objective: Dictionary = snapshot["objective"]
	objective_progress = int(objective["progress"])
	objective_required = int(objective["required"])
	objective_credited_ids.assign(objective["credited_ids"])
	claim_receipts.assign(snapshot["reward_state"]["claim_receipts"])
	var director: Dictionary = snapshot.get("director", {})
	side_sequence = int(director.get("side_sequence", 0))
	pending_entry_warnings.clear()
	for warning in director.get("pending_entry_warnings", []):
		if warning is Dictionary:
			pending_entry_warnings.append(warning.duplicate(true))
	weapon_clock = snapshot["weapon_state"]["shot_accumulator"]
	dash_cooldown_remaining = float(snapshot["player_abilities"]["dash_cooldown_remaining"])
	pulse_cooldown_remaining = float(snapshot["player_abilities"]["pulse_cooldown_remaining"])
	dash_remaining = float(snapshot["player_abilities"]["dash_remaining"])
	dash_direction = -1 if float(snapshot["player_abilities"]["dash_direction"][0]) < 0.0 else 1
	assignment_notice = "Encounter restored at the last checkpoint. Resume when ready."

func _freeze_level_definition(well_data: Dictionary) -> void:
	var source_level_id := str(well_data.get("source_level_id", ""))
	if not source_level_id.is_empty():
		var definitions: RefCounted = CampaignCatalogScript.new()
		var node: Dictionary = definitions.get_node("act_01", source_level_id)
		if not node.is_empty():
			frozen_level_definition = node.get("level_data", {}).duplicate(true)
	if frozen_level_definition.is_empty():
		frozen_level_definition = {"well": well_data.duplicate(true)}
	frozen_level_content_hash = SnapshotScript.content_hash_for(frozen_level_definition)
	_apply_level_backdrop()

func _apply_level_backdrop() -> void:
	if environment_visual == null:
		return
	environment_visual.call("set_backdrop_id", str(frozen_level_definition.get("backdrop_id", "")))

func _update_hud() -> void:
	if encounter_hud == null:
		return
	var ability_state := {
		"dash_cooldown_remaining": dash_cooldown_remaining,
		"pulse_cooldown_remaining": pulse_cooldown_remaining,
	}
	var view_state: Dictionary = UiViewStateScript.build(account_state, run_state, selected_well_id, {}, ability_state, campaign_state)
	view_state["director"] = get_director_state()
	var combat_view: Dictionary = view_state.get("combat", {})
	var director_state: Dictionary = view_state["director"]
	combat_view["threat_label"] = "Next spawn: %.1fs" % maxf(0.0, float(director_state["spawn_interval"]) - spawn_timer) if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else "No active surge"
	view_state["combat"] = combat_view
	encounter_hud.set_view_state(view_state)

func apply_enemy_damage(target: int, amount: float) -> bool:
	if target == RunStateScript.DamageTarget.HERO and dash_remaining > 0.0:
		return false
	return run_state.apply_damage(target, amount)

func set_experiment_paused(should_pause: bool) -> void:
	run_state.set_paused(should_pause)
	if pause_button != null:
		pause_button.text = "RESUME" if run_state.paused else "PAUSE"
	_update_hud()

func try_dash(direction: int = 0) -> bool:
	if run_state.paused or dash_cooldown_remaining > 0.0 or dash_remaining > 0.0 or run_state.phase != RunStateScript.Phase.EXTRACTING:
		return false
	dash_direction = direction if direction != 0 else last_input_direction
	if dash_direction == 0:
		dash_direction = hero.last_facing
	dash_remaining = BalanceData.DASH_DURATION
	dash_cooldown_remaining = BalanceData.DASH_COOLDOWN
	return true

func try_pulse() -> int:
	if run_state.paused or pulse_cooldown_remaining > 0.0 or run_state.phase != RunStateScript.Phase.EXTRACTING:
		return 0
	pulse_cooldown_remaining = BalanceData.PULSE_COOLDOWN
	pulse_feedback_remaining = 0.28
	var hit_count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_kind := "ranged" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "breaker" if enemy.enemy_kind == EnemyScript.EnemyKind.BREAKER else "pursuer"
		if CombatGeometryScript.circle_intersects_hurtbox(CombatGeometryScript.body_center("hero", hero.position), BalanceData.PULSE_RADIUS * SPATIAL_PIXELS_PER_UNIT, enemy_kind, enemy.position):
			if enemy.take_damage(BalanceData.PULSE_DAMAGE):
				hit_count += 1
	return hit_count

func spawn_enemy(kind: int, side: int) -> Node:
	_prune_enemies()
	if enemies.size() >= BalanceData.MAX_LIVE_ENEMIES:
		return null
	side = 1
	var enemy: Node = EnemyScript.new()
	enemy.setup(kind, next_enemy_id, side, self, _enemy_damage_multiplier())
	next_enemy_id += 1
	enemy.position = Vector2(40.0 if side < 0 else 1240.0, GROUND_Y - 40.0)
	pending_entry_warnings.append({"id": next_enemy_id, "side": side, "remaining": 0.8})
	add_child(enemy)
	enemy.z_index = 2
	enemies.append(enemy)
	if not spawned_kinds.has(kind):
		spawned_kinds.append(kind)
	return enemy

func spawn_hostile_projectile(origin_x: float, target_x: float, damage: float, source_enemy: Node = null, target_y: float = INF) -> void:
	var projectile: Node = ProjectileScript.new()
	var source_position := hero.position
	var facing: int = hero.last_facing
	var source_kind := "hero"
	if source_enemy != null and source_enemy.enemy_kind == EnemyScript.EnemyKind.RANGED:
		source_position = source_enemy.position
		facing = -source_enemy.side
		source_kind = "ranged"
	var origin := Vector2(origin_x, GROUND_Y - 58.0)
	if source_enemy != null:
		origin = CombatGeometryScript.muzzle_position(source_kind, source_position, facing)
	var locked_target_y := target_y if is_finite(target_y) else CombatGeometryScript.body_center("hero", hero.position).y
	projectile.setup(self, origin, Vector2(target_x, locked_target_y), damage, BalanceData.RANGED_PROJECTILE_SPEED, BalanceData.RANGED_PROJECTILE_LIFETIME, true, facing)
	projectile.source_enemy_id = source_enemy.enemy_id if source_enemy != null else 0
	add_child(projectile)
	projectile.z_index = 3
	projectiles.append(projectile)

func spawn_friendly_projectile(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	var projectile: Node = ProjectileScript.new()
	var origin := CombatGeometryScript.muzzle_position("hero", hero.position, hero.last_facing)
	var target_kind := "pursuer"
	if target_enemy != null:
		target_kind = "ranged" if target_enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "breaker" if target_enemy.enemy_kind == EnemyScript.EnemyKind.BREAKER else "pursuer"
	var target := CombatGeometryScript.body_center(target_kind, target_enemy.position) if target_enemy != null else Vector2(target_x, CombatGeometryScript.body_center("hero", hero.position).y)
	projectile.setup(self, origin, target, weapon_damage, BalanceData.WEAPON_PROJECTILE_SPEED, BalanceData.WEAPON_PROJECTILE_LIFETIME, false, hero.last_facing)
	projectile.owner_id = "hero"
	projectile.target_id = "enemy-%d" % target_enemy.enemy_id if target_enemy != null else "hero"
	add_child(projectile)
	projectile.z_index = 3
	projectiles.append(projectile)

func spawn_friendly_volley(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	for _shot in range(maxi(1, weapon_projectile_count)):
		spawn_friendly_projectile(origin_x, target_x, target_enemy)

func is_hero_on_segment(start_position: Vector2, end_position: Vector2) -> bool:
	return CombatGeometryScript.segment_fraction_against_rect(start_position, end_position, CombatGeometryScript.hurtbox_rect("hero", hero.position)) >= 0.0

func closest_live_enemy() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_kind := "ranged" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "breaker" if enemy.enemy_kind == EnemyScript.EnemyKind.BREAKER else "pursuer"
		var distance := CombatGeometryScript.body_center(enemy_kind, enemy.position).distance_to(CombatGeometryScript.body_center("hero", hero.position))
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (nearest == null or enemy.enemy_id < nearest.enemy_id)):
			nearest = enemy
			nearest_distance = distance
	return nearest if nearest_distance <= BalanceData.WEAPON_RANGE * SPATIAL_PIXELS_PER_UNIT else null

func closest_live_enemy_between(start_position: Vector2, end_position: Vector2) -> Node:
	var nearest: Node = null
	var nearest_fraction := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_kind := "ranged" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "breaker" if enemy.enemy_kind == EnemyScript.EnemyKind.BREAKER else "pursuer"
		var fraction := CombatGeometryScript.segment_fraction_against_rect(start_position, end_position, CombatGeometryScript.hurtbox_rect(enemy_kind, enemy.position))
		if fraction >= 0.0 and (fraction < nearest_fraction or (is_equal_approx(fraction, nearest_fraction) and (nearest == null or enemy.enemy_id < nearest.enemy_id))):
			nearest = enemy
			nearest_fraction = fraction
	return nearest

func retry() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return
	_clear_transients()
	run_state.reset()
	next_enemy_id = 1
	spawn_timer = 0.0
	spawn_index = 0
	side_sequence = 0
	pending_entry_warnings.clear()
	spawned_kinds.clear()
	weapon_clock = 0.0
	dash_remaining = 0.0
	dash_cooldown_remaining = 0.0
	pulse_cooldown_remaining = 0.0
	last_input_direction = 0
	presentation_time = 0.0
	machine_flash_remaining = 0.0
	pulse_feedback_remaining = 0.0
	harvest_feedback_elapsed = 0.0
	harvest_feedback_amount = 0.0
	harvest_feedback_remaining = 0.0
	last_machine_integrity = BalanceData.MACHINE_INTEGRITY
	hero.reset_motion()
	hero.position = Vector2(320.0, GROUND_Y - 40.0)
	hero.last_facing = 1
	run_state.set_paused(false)
	status_text = "READY - clean encounter"
	start_run()

func _advance_spawning(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or run_state.paused:
		return
	spawn_timer += delta
	for warning in pending_entry_warnings:
		warning["remaining"] = maxf(0.0, float(warning.get("remaining", 0.0)) - delta)
	var interval := _spawn_interval()
	while spawn_timer >= interval:
		spawn_timer -= interval
		_spawn_next_enemy()
		interval = _spawn_interval()

func _spawn_interval() -> float:
	var tier: int = run_state.completed_surges
	var rule: Dictionary = content_catalog.spawn_rule_for_tier(tier)
	var interval: float = float(rule.get("spawn_interval", 3.0))
	if tier >= 4:
		interval = maxf(0.4, 1.5 * pow(0.9, tier - 4))
	interval *= float(content_catalog.get_well(run_state.selected_well_id).get("spawn_interval_factor", 1.0))
	if run_state.selected_module_id == "overdrive":
		interval *= 0.8
	return interval

func _spawn_next_enemy() -> void:
	_prune_enemies()
	if enemies.size() >= BalanceData.LIVE_ENEMY_LIMIT:
		spawn_index += 1
		return
	var kind := _next_enemy_kind()
	var side := -1 if side_sequence % 2 == 0 else 1
	if spawn_index % 3 == 2:
		side = -side
	spawn_enemy(kind, side)
	spawn_index += 1
	side_sequence += 1

func _next_enemy_kind() -> int:
	var rule: Dictionary = content_catalog.spawn_rule_for_tier(run_state.completed_surges)
	if run_state.completed_surges <= 0:
		return EnemyScript.EnemyKind.PURSUER
	var ranged_cycle: int = int(rule.get("ranged_cycle", -1))
	var breaker_cycle: int = int(rule.get("breaker_cycle", -1))
	if ranged_cycle >= 0 and spawn_index % 4 == ranged_cycle:
		return EnemyScript.EnemyKind.RANGED
	if breaker_cycle >= 0 and spawn_index % 4 == breaker_cycle:
		return EnemyScript.EnemyKind.BREAKER
	return EnemyScript.EnemyKind.PURSUER

func _enemy_damage_multiplier() -> float:
	var multiplier := 1.0 + 0.15 * maxf(0.0, run_state.completed_surges - 4)
	multiplier *= float(content_catalog.get_well(run_state.selected_well_id).get("enemy_damage_factor", 1.0))
	return multiplier

func get_director_state() -> Dictionary:
	return {
		"spawn_timer": spawn_timer,
		"spawn_index": spawn_index,
		"side_sequence": side_sequence,
		"pending_entry_warnings": pending_entry_warnings.duplicate(true),
		"spawn_interval": _spawn_interval() if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else 0.0,
		"completed_surges": run_state.completed_surges,
	}

func _prune_enemies() -> void:
	for index in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[index]) or enemies[index].dead:
			enemies.remove_at(index)

func _simulate_enemies(delta: float) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.simulate_tick(delta)
	for index in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[index]) or enemies[index].dead:
			enemies.remove_at(index)

func _simulate_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.simulate_tick(delta)
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]) or projectiles[index].is_queued_for_deletion():
			projectiles.remove_at(index)

func _simulate_weapon(delta: float) -> void:
	weapon_clock += delta
	while weapon_clock >= BalanceData.WEAPON_INTERVAL:
		weapon_clock -= BalanceData.WEAPON_INTERVAL
		var target := closest_live_enemy()
		if target != null:
			if hero != null and hero.visual != null:
				hero.visual.play_attack()
			if account_state.has_upgrade("spread_1"):
				spawn_friendly_volley(hero.position.x, target.position.x, target)
			else:
				spawn_friendly_projectile(hero.position.x, target.position.x, target)

func _build_controls() -> void:
	var controls := CanvasLayer.new()
	controls.name = "Controls"
	add_child(controls)
	var title := Label.new()
	title.position = Vector2(48, 34)
	title.text = "TEL0S // SIDE-VIEW DEFENSE"
	title.add_theme_color_override("font_color", Color("d7e4e6"))
	title.add_theme_font_size_override("font_size", 24)
	controls.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(50, 68)
	subtitle.text = "ACTIVE 2D BUILD  /  FIXED CAMERA  /  1280 x 720"
	subtitle.add_theme_color_override("font_color", Color("71929a"))
	subtitle.add_theme_font_size_override("font_size", 13)
	controls.add_child(subtitle)
	var legend := Label.new()
	legend.position = Vector2(48, 646)
	legend.text = "A / D or ARROWS MOVE   |   SPACE JUMP   |   S / DOWN + SPACE DROP   |   SHIFT DASH   |   Q PULSE   |   E START / HARVEST   |   ESC PAUSE"
	legend.add_theme_color_override("font_color", Color("a7bcc0"))
	legend.add_theme_font_size_override("font_size", 14)
	controls.add_child(legend)
	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(48, 104)
	status.add_theme_color_override("font_color", Color("66d9c4"))
	status.add_theme_font_size_override("font_size", 16)
	controls.add_child(status)
	var start_button := Button.new()
	start_button.text = "START / HARVEST"
	start_button.position = Vector2(950, 40)
	start_button.size = Vector2(140, 36)
	start_button.pressed.connect(_on_start_pressed)
	controls.add_child(start_button)
	var retry_button := Button.new()
	retry_button.text = "RETRY"
	retry_button.position = Vector2(1100, 40)
	retry_button.size = Vector2(80, 36)
	retry_button.pressed.connect(_on_retry_pressed)
	controls.add_child(retry_button)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.position = Vector2(950, 84)
	pause_button.size = Vector2(230, 34)
	pause_button.pressed.connect(_on_pause_pressed)
	controls.add_child(pause_button)
	_update_status(status)

func _process(_delta: float) -> void:
	_settle_production()
	checkpoint_elapsed += maxf(0.0, _delta)
	if persistence_enabled and checkpoint_elapsed >= 5.0:
		checkpoint_elapsed = fmod(checkpoint_elapsed, 5.0)
		_save_account(_capture_snapshot() if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else {})
	presentation_time += _delta
	if not run_state.paused:
		queue_redraw()
	_update_hud()

func _update_status(status: Label) -> void:
	if status == null:
		return
	if run_state.phase == RunStateScript.Phase.SUCCESS:
		status_text = "SUCCESS - payout locked: %d" % run_state.locked_payout
	elif run_state.phase == RunStateScript.Phase.FAILED:
		status_text = "FAILED - %s" % run_state.terminal_reason
	var payout_text := "PAYOUT %d" % run_state.locked_payout if run_state.phase == RunStateScript.Phase.SEALING or run_state.phase == RunStateScript.Phase.SUCCESS else "TANK %.1f" % run_state.tank_base
	status.text = ("PAUSED  /  " if run_state.paused else "") + status_text + "   //   HERO X %d   FACING %s   HP %.0f   MACHINE %.0f   %s" % [roundi(hero.position.x), ">" if hero.last_facing > 0 else "<", run_state.hero_health, run_state.machine_integrity, payout_text]

func _on_start_pressed() -> void:
	if run_state.phase == RunStateScript.Phase.READY:
		start_run()
	elif run_state.phase == RunStateScript.Phase.EXTRACTING:
		request_harvest()

func _on_retry_pressed() -> void:
	retry()

func _on_pause_pressed() -> void:
	set_experiment_paused(not run_state.paused)

func _draw() -> void:
	if machine_flash_remaining > 0.0:
		draw_arc(Vector2(MACHINE_X, GROUND_Y - 92), 104.0, -PI, 0.0, 32, Color("f0a04b"), 8.0)
	if run_state.phase == RunStateScript.Phase.EXTRACTING:
		draw_arc(Vector2(MACHINE_X, GROUND_Y - 62), 63.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(run_state.tank_base / 20.0, 0.0, 1.0), 32, Color("66d9c4"), 3.0)
	if pulse_feedback_remaining > 0.0:
		var pulse_size := 220.0 * (1.0 - pulse_feedback_remaining / 0.28)
		draw_arc(hero.position, pulse_size, 0.0, TAU, 48, Color(0.4, 0.85, 0.77, pulse_feedback_remaining / 0.28), 5.0)
	draw_string(ThemeDB.fallback_font, Vector2(MACHINE_X - 72, GROUND_Y - 165), "HARVESTER / SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a7bcc0"))
	if harvest_feedback_remaining > 0.0:
		var feedback_alpha := clampf(harvest_feedback_remaining / 0.85, 0.0, 1.0)
		var feedback_y := GROUND_Y - 190.0 - (1.0 - feedback_alpha) * 18.0
		draw_string(ThemeDB.fallback_font, Vector2(MACHINE_X - 56.0, feedback_y), "+%.1f mana" % harvest_feedback_amount, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 16, Color(0.35, 0.72, 1.0, feedback_alpha))
	draw_string(ThemeDB.fallback_font, Vector2(96, GROUND_Y + 58), "LEFT ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("59777b"))
	draw_string(ThemeDB.fallback_font, Vector2(1080, GROUND_Y + 58), "RIGHT ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("59777b"))
