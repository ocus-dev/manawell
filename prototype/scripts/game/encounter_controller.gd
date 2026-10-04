extends Node2D

const WeaponTypesScript = preload("res://scripts/model/weapon_types.gd")
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
const HeroStatResolverScript = preload("res://scripts/model/hero_stat_resolver.gd")
const WeaponLootRegistrationScript = preload("res://scripts/model/weapon_loot_registration.gd")
const LootGeneratorScript = preload("res://scripts/model/loot_generator.gd")
const CreatureDropsScript = preload("res://scripts/model/creature_drops.gd")
const EnvironmentScript = preload("res://scripts/game/side_view_environment_visual.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const LevelSpawnsScript = preload("res://scripts/model/level_spawns.gd")
const MonsterEncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const GameFlowScript = preload("res://scripts/model/game_flow.gd")
const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const MELEE_REACH_UNITS: float = 1.5
const MELEE_STRIKE_FRACTION: float = 0.4
const FIXED_STEP: float = 1.0 / 60.0
const GROUND_Y: float = 652.0
const MACHINE_X: float = 160.0

@export var persistence_enabled: bool = true
@export var use_prepared_environment: bool = true

@onready var hero: Node2D = $Hero

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
var frozen_loot_registration: Dictionary = {}
var loot_enabled := false
var loot_item_level := 1
var loot_rng_state := 1
var loot_acquired_item_ids: Array[String] = []
var pending_enemy_deaths: Array[Dictionary] = []
var development_drop_percent := -1.0
var weapon_clock: float = 0.0
var dash_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var pulse_cooldown_remaining: float = 0.0
var spawn_timer: float = 0.0
var spawn_index: int = 0
var content_catalog: RefCounted = ContentCatalogScript.new()
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
var weapon_damage: float = BalanceData.WEAPON_DAMAGE
var weapon_interval: float = BalanceData.WEAPON_INTERVAL
var weapon_projectile_count: int = 1
var weapon_behavior_id := "weapon.ranged"
var melee_phase := ""
var melee_strike_delay_remaining := 0.0
var melee_locked_facing := 1
var melee_target_id := ""
var melee_damage_committed := false
var checkpoint_elapsed: float = 0.0
var save_store: RefCounted = SaveStoreScript.new()
var session_persistence: RefCounted
var production_utc_timestamp: float = 0.0
var assignment_notice: String = ""
## "While away" message after idle income is credited at startup.
var offline_notice: String = ""
## Offline income already in the bank but not yet saved (Retry settlement).
var offline_pending_total: float = 0.0
var ui_scale: float = 1.0
var harvester_visual: Node
## The drill's info panel (mana per second, surge limit), opened by clicking the drill.
var drill_panel_open := false
const HUD_FULL_REFRESH_INTERVAL := 0.25
const RUN_CHECKPOINT_SECONDS := 15.0
const MENU_CHECKPOINT_SECONDS := 60.0
var hud_full_refresh_elapsed := 0.0
var hud_last_phase := -1
var hud_last_paused := false
const MAX_SURGE_LIMIT := 99
var environment_visual: Node
var monster_encyclopedia: CanvasLayer
## Tutorial: just the hero and the drill on the Sector B map. No monsters spawn.
var tutorial_mode := false
## This level's spawn settings (LevelSpawns); empty = the built-in director.
var spawn_profile: Dictionary = {}
## Dev spawn preview: persistence is off and quitting returns to the editor.
var preview_mode := false
## Zone boss for this run: "" (no boss gate), "waiting", "active", "defeated".
var boss_state := ""
var boss_enemy: Node

func _ready() -> void:
	if not GameFlowScript.preview_level_id.is_empty():
		preview_mode = true
		persistence_enabled = false
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
		_credit_time_away()
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
	_attach_monster_encyclopedia()
	queue_redraw()
	if GameFlowScript.start_tutorial:
		GameFlowScript.start_tutorial = false
		start_tutorial.call_deferred()
	elif GameFlowScript.play_requested:
		GameFlowScript.play_requested = false
		# First-time players always land on the tutorial map (a saved run in
		# progress is resumed instead).
		if run_state.phase == RunStateScript.Phase.READY and not tutorial_done():
			start_tutorial.call_deferred()
	elif preview_mode:
		_start_preview.call_deferred()
	if GameFlowScript.return_to_map:
		# Back from Home: land on the map page.
		GameFlowScript.return_to_map = false
		if encounter_hud != null and encounter_hud.operations != null:
			encounter_hud.operations.show_page.call_deferred("map")

## Dev spawn preview: opens the chosen level on a throwaway profile (nothing is
## saved) with the spawn settings from the editor.
func _start_preview() -> bool:
	var level_id := GameFlowScript.preview_level_id
	campaign_state.all_levels_enabled = true
	var started := false
	if level_id == LevelSpawnsScript.TUTORIAL_ID:
		started = start_tutorial()
	else:
		var catalog: RefCounted = campaign_state_catalog()
		for act_id in catalog.act_order:
			if catalog.node_ids(act_id).has(level_id):
				started = start_campaign_node(act_id, level_id)
				break
	var level_name := LevelSpawnsScript.level_name(level_id)
	var goal := assignment_notice
	assignment_notice = ("PREVIEW: %s. Nothing is saved. Pause > Back to spawn editor.%s" % [level_name, ("\n" + goal) if not goal.is_empty() else ""]) if started else "Preview couldn't open %s." % level_name
	var back: Button = encounter_hud.router.pause_panel.find_child("QuitToTitle", true, false) if encounter_hud != null and encounter_hud.router != null and encounter_hud.router.pause_panel != null else null
	if back != null:
		back.text = "Back to spawn editor"
	_update_hud()
	return started

## Starts the tutorial run: the hero and the drill, no monsters.
func start_tutorial() -> bool:
	if run_state.phase != RunStateScript.Phase.READY:
		return false
	tutorial_mode = true
	selected_well_id = "well_1"
	_equip_tutorial_weapon()
	# The tutorial is the campaign's Sector B slot: harvests and the boss clear
	# count for that level (and unlock the next one).
	var zone := _tutorial_zone()
	if not zone.is_empty():
		campaign_state.start_node(str(zone.act_id), str(zone.node_id), campaign_state_catalog())
	if not start_run():
		tutorial_mode = false
		campaign_state.clear_active_node()
		return false
	_update_hud()
	return true

## The tutorial's main weapon: a published weapon id from Weapon Lab.
const TUTORIAL_WEAPON_ID := "gun_test"

## Makes the tutorial gun the hero's equipped weapon, giving the profile a copy
## the first time. It stays equipped afterwards (the inventory can change it).
func _equip_tutorial_weapon() -> void:
	if not account_state.published_weapons.has(TUTORIAL_WEAPON_ID):
		push_warning("Tutorial weapon \"%s\" isn't published; keeping the current weapon." % TUTORIAL_WEAPON_ID)
		return
	var hero_id: String = account_state.get_active_hero_id()
	var instance_id := _owned_weapon_instance(TUTORIAL_WEAPON_ID)
	if instance_id.is_empty():
		if not account_state.grant_published_weapon(TUTORIAL_WEAPON_ID):
			push_warning("Couldn't give the tutorial gun: %s" % account_state.inventory_command_error)
			return
		instance_id = _owned_weapon_instance(TUTORIAL_WEAPON_ID)
	if str(account_state.hero_kits.get(hero_id, {}).get("weapon", "")) != instance_id:
		account_state.equip_instance(hero_id, "weapon", instance_id)

func _owned_weapon_instance(weapon_id: String) -> String:
	for instance_id in account_state.item_instances.keys():
		if str(account_state.item_instances[instance_id].get("weapon_id", "")) == weapon_id:
			return str(instance_id)
	return ""

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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_run_for_exit()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_account()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause_game"):
		pending_pause = true
	if run_state.paused:
		return
	simulate_step(FIXED_STEP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if handle_world_click(get_viewport().get_mouse_position()):
			get_viewport().set_input_as_handled()
		return
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
	_advance_burst(delta)
	_advance_spawning(delta)
	_simulate_enemies(delta)
	_process_enemy_deaths()
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
	_update_zone_boss()
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
	_reset_run_counters()
	_configure_weapon_loadout(hero_id)
	var run_id: String = account_state.allocate_run_id()
	var machine_max: float = BalanceData.MACHINE_INTEGRITY * float(modifiers["machine_integrity_multiplier"])
	if not run_state.start(run_id, selected_well_id, hero_id, selected_loadout_id, extraction_rate, BalanceData.SEALING_DURATION, BalanceData.HERO_HEALTH, machine_max, float(modifiers["pressure_time_scale"])):
		return false
	run_state.set_surge_limit(account_state.get_surge_limit(selected_well_id))
	assignment_notice = ""
	if hero != null:
		hero.configure_hero(hero_id)
	_freeze_level_definition(well_data)
	_begin_zone()
	_initialize_loot(run_id)
	spawner_rng_state = 1
	objective_progress = 0
	objective_required = 0
	objective_credited_ids.clear()
	claim_receipts.clear()
	if hero == null:
		hero = get_node_or_null("Hero") as Node2D
	account_state.release_guard_for_start(selected_well_id)
	production.reset_cursor(_current_production_time())
	_save_account()
	_update_hud()
	return true

func _configure_weapon_loadout(hero_id: String) -> void:
	weapon_behavior_id = "weapon.ranged"
	weapon_interval = BalanceData.WEAPON_INTERVAL
	weapon_damage = BalanceData.WEAPON_DAMAGE + (BalanceData.DAMAGE_UPGRADE_BONUS if account_state.has_upgrade("damage_1") else 0.0)
	weapon_projectile_count = 1
	var kit: Dictionary = account_state.hero_kits.get(hero_id, {})
	var instance_id := str(kit.get("weapon", ""))
	var instance: Dictionary = account_state.item_instances.get(instance_id, {})
	var publication: Dictionary = account_state.published_weapons.get(str(instance.get("base_id", "")), {})
	var revision: Dictionary = publication.get("revision", {})
	var authored := not instance.is_empty() and not revision.is_empty() and instance.has("revision")
	var behavior_id := str(revision.get("behavior_id", "")) if authored else ""
	# Cleave can extend this dispatch as a future skill/effect. The base melee
	# behavior intentionally locks and damages exactly one target.
	if authored and behavior_id == "weapon.melee":
		weapon_behavior_id = "weapon.melee"
	var research_mode: String = str(account_state.equipped_weapon_mode_id) if weapon_behavior_id != "weapon.melee" else "weapon.standard"
	var resolved: Dictionary = HeroStatResolverScript.resolve(account_state.research_ranks, account_state.item_instances, kit, float(content_catalog.get_well(selected_well_id).get("base_output", BalanceData.WELL_1_BASE_OUTPUT)), 1.0, "", research_mode)
	weapon_damage = float(resolved.get("stats", {}).get("attack_damage", weapon_damage))
	weapon_interval = maxf(0.01, float(resolved.get("stats", {}).get("attack_interval", weapon_interval)))
	if weapon_behavior_id != "weapon.melee":
		weapon_projectile_count = maxi(3, int(resolved.get("stats", {}).get("weapon_projectile_count", 1))) if account_state.has_upgrade("spread_1") else 1
	if hero != null:
		_configure_held_weapon_visual(revision if authored else {})

func _configure_held_weapon_visual(revision: Dictionary) -> void:
	if hero == null:
		return
	if revision.is_empty():
		hero.clear_held_weapon()
		hero.configure_held_weapon_swing({})
		hero.configure_held_weapon_effects([])
		hero.configure_attack_clip({})
		hero.configure_pose_clips({})
		return
	var assets: Dictionary = revision.get("assets", {})
	var texture := load(str(assets.get("world_sprite", ""))) as Texture2D
	var pivot: Dictionary = revision.get("pivot", {})
	var grip: Array = pivot.get("grip", [0.5, 0.75])
	var hand_offset: Array = pivot.get("hand_offset", [0.0, 0.0])
	hero.configure_held_weapon(texture, Vector2(float(grip[0]), float(grip[1])), str(pivot.get("facing", "right")), float(pivot.get("world_scale", 1.0)), float(pivot.get("rotation_degrees", 0.0)), Vector2(float(hand_offset[0]), float(hand_offset[1])))
	var swing: Variant = revision.get("swing", {})
	hero.configure_held_weapon_swing(swing if swing is Dictionary else {})
	var effects: Variant = revision.get("effects", [])
	# Melee damage lands MELEE_STRIKE_FRACTION into the attack; ranged shots fire at once.
	hero.configure_held_weapon_effects(effects if effects is Array else [], weapon_interval * MELEE_STRIKE_FRACTION if weapon_behavior_id == "weapon.melee" else 0.0)
	# The weapon's own animation, its type's default, or none (WeaponTypes).
	var clip: Dictionary = WeaponTypesScript.resolve_clip(revision, WeaponTypesScript.game_library())
	var fit: Variant = revision.get("hand_fit", {})
	hero.configure_attack_clip(clip, weapon_interval * MELEE_STRIKE_FRACTION if weapon_behavior_id == "weapon.melee" else 0.0, weapon_interval, fit if fit is Dictionary else {})
	# Its own idle / walk, or its type's (WeaponTypes); none = the hero's own art.
	hero.configure_pose_clips(WeaponTypesScript.resolve_pose_clips(revision, WeaponTypesScript.game_library()), fit if fit is Dictionary else {})

func request_harvest() -> bool:
	var harvested: bool = run_state.request_harvest()
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
	if node_id == LevelSpawnsScript.TUTORIAL_NODE_ID and not tutorial_mode:
		return start_tutorial()
	if run_state.phase != RunStateScript.Phase.READY or not campaign_state.start_node(act_id, node_id, campaign_state_catalog()):
		return false
	var node: Dictionary = campaign_state_catalog().get_node(act_id, node_id)
	var well_id: String = str(node.get("well_id", selected_well_id))
	# The map decides what's playable: a well level unlocked on the map opens
	# its well too (wells used to unlock one after another on their own).
	if content_catalog.has_well(well_id) and not account_state.is_well_unlocked(well_id):
		account_state.unlocked_wells[well_id] = true
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
	_freeze_loot_registration_from_definition()
	_apply_level_backdrop()
	_begin_zone()
	# Show this level's notice (start_run showed the well's default level's).
	_update_hud()
	return true

## Map selection: an unlocked level becomes the Operations destination right
## away (briefing, threats, Start extraction), before it is played.
func select_campaign_node(act_id: String, node_id: String) -> bool:
	if campaign_state.node_status(act_id, node_id, campaign_state_catalog())["status"] == CampaignStateScript.STATUS_LOCKED:
		return false
	if run_state.phase == RunStateScript.Phase.READY and not preview_mode:
		campaign_state.start_node(act_id, node_id, campaign_state_catalog())
		_update_hud()
	return true

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
	var saved: bool = session_persistence.retry_pending_save()
	if saved:
		offline_pending_total = 0.0
	_update_hud()
	return saved

func retry_offline_settlement() -> bool:
	return retry_pending_save()

## Idle income for the time the game was closed (capped by
## Production.MAX_OFFLINE_SECONDS), credited once when the save is loaded.
func _credit_time_away() -> void:
	if save_store.loaded_production_utc_timestamp <= 0.0:
		return
	var bank_before: float = account_state.bank
	var saved := _settle_offline_production(session_persistence.now_utc())
	var earned: float = account_state.bank - bank_before
	if earned <= 0.0:
		return
	var away := ProductionScript.offline_elapsed(session_persistence.now_utc(), save_store.loaded_production_utc_timestamp)
	offline_notice = "Your guarded wells made %d mana while you were away (%s)." % [floori(earned), _duration_text(away)]
	offline_pending_total = 0.0 if saved else earned

static func _duration_text(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	if minutes < 1:
		return "under a minute"
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %d min" % [minutes / 60, minutes % 60]

func _settle_offline_production(now_timestamp: float) -> bool:
	_ensure_session_persistence()
	if not save_store.writes_allowed:
		return false
	var rates: Dictionary = ProductionScript.calculate_rates(account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, "", account_state.research_ranks)
	var result: Dictionary = ProductionScript.offline_settlement(now_timestamp, save_store.loaded_production_utc_timestamp, rates)
	account_state.bank += float(result.get("total", 0.0))
	return session_persistence.save()

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
	tutorial_mode = false
	boss_state = ""
	boss_enemy = null
	drill_panel_open = false
	credited_run_id = ""
	_update_hud()

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const HOME_SCENE := "res://scenes/home_area.tscn"

## Map > Home: the main city (a walkable area, nothing to fight). Only from the
## menus, never mid-run. The profile is saved first.
func enter_home() -> bool:
	if run_state.phase != RunStateScript.Phase.READY or preview_mode:
		return false
	if persistence_enabled:
		_save_account()
	GameFlowScript.home_hero_id = account_state.get_active_hero_id()
	get_tree().change_scene_to_file(HOME_SCENE)
	return true

## Leaving the game mid-run (quit to title, closing the window) ends the run:
## the tank's mana is lost and the next run starts at surge 0.
func _end_run_for_exit() -> void:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		run_state.abandon()
		_clear_transients()
		return_to_operations()

## Pause menu > Quit to title. A run in progress ends (it isn't saved).
func quit_to_title() -> void:
	if preview_mode:
		# Back to the spawn editor on the title screen, on the same level.
		GameFlowScript.reopen_spawn_editor_level = GameFlowScript.preview_level_id
		GameFlowScript.preview_level_id = ""
		GameFlowScript.preview_profile = {}
		get_tree().change_scene_to_file(TITLE_SCENE)
		return
	_end_run_for_exit()
	_save_account()
	get_tree().change_scene_to_file(TITLE_SCENE)

## Pause menu > Return to operations screen: ends the run (the tank's mana is
## lost) and goes straight back to Operations, skipping the results card.
func abandon() -> void:
	if run_state.abandon():
		_clear_transients()
		return_to_operations()
		_save_account()

func _clear_transients() -> void:
	burst_shots_left = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	enemies.clear()
	projectiles.clear()
	# Loot pickups still flying toward the hero belong to the run being cleared.
	for child in get_children():
		if child.is_in_group("loot_drop_visuals"):
			child.queue_free()

func _credit_if_complete() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS or credited_run_id == run_state.run_id:
		return
	var result: Dictionary = run_state.get_terminal_result()
	result["zone_cleared"] = boss_state == "" or boss_state == "defeated"
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
	# Research ranks included so idle income matches the rate the HUD shows.
	var settlement: Dictionary = production.settle(timestamp, account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, active_well, account_state.research_ranks)
	account_state.bank += float(settlement.get("total", 0.0))

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

func purchase_research(research_id: String, expected_rank: int, expected_cost: int = -1) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	var purchased: bool = account_state.purchase_research(research_id, expected_rank, expected_cost)
	if purchased:
		_save_account()
	_update_hud()
	return purchased

func inspect_inventory_item(id: String) -> void:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return
	if account_state.inspect_item(id):
		_save_account()
		_update_hud()

func equip_inventory_item(hero_id: String, slot: String, instance_id: String) -> bool:
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	if active_run or not account_state.equip_instance(hero_id, slot, instance_id, active_run):
		_update_hud()
		return false
	_save_account()
	_update_hud()
	return true

func unequip_inventory_item(hero_id: String, slot: String) -> bool:
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	if active_run or not account_state.unequip_instance(hero_id, slot, active_run):
		_update_hud()
		return false
	_save_account()
	_update_hud()
	return true

func lock_inventory_item(instance_id: String, locked: bool) -> bool:
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	if not account_state.set_instance_locked(instance_id, locked, active_run):
		_update_hud()
		return false
	_save_account()
	_update_hud()
	return true

## Salvage the given items into banked mana and scrap. Locked and equipped
## items are skipped. Returns the account's salvage result.
func salvage_inventory_items(instance_ids: Array) -> Dictionary:
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	var result: Dictionary = account_state.salvage_instances(instance_ids, active_run)
	if not result.salvaged.is_empty():
		_save_account()
	_update_hud()
	return result

func salvage_inventory_item(instance_id: String) -> bool:
	return not salvage_inventory_items([instance_id]).salvaged.is_empty()

func equip_research_choice(choice_id: String) -> bool:
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	var equipped: bool = account_state.equip_research_choice(choice_id, active_run)
	if equipped:
		_save_account()
		_update_hud()
	return equipped

## Runs aren't saved: leaving a run ends it, and the next one starts again at
## surge 0. Only the profile (bank, unlocks, items...) is saved, so any run
## snapshot passed in is dropped.
const SAVE_RUN_SNAPSHOTS := false

func _save_account(snapshot: Dictionary = {}) -> bool:
	if not persistence_enabled:
		return true
	_ensure_session_persistence()
	# Bank idle income up to now so the saved bank matches the saved timestamp.
	_settle_production()
	return session_persistence.save(snapshot if SAVE_RUN_SNAPSHOTS else {})

func _capture_snapshot() -> Dictionary:
	var actors: Array = [
		{"id": "hero", "kind": "hero", "position": [hero.position.x, hero.position.y], "health": run_state.hero_health, "max_health": BalanceData.HERO_HEALTH, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": hero.capture_snapshot_state()},
		{"id": "machine", "kind": "machine", "position": [MACHINE_X, GROUND_Y], "health": run_state.machine_integrity, "max_health": run_state.machine_max_integrity, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}},
	]
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			actors.append({"id": "enemy-%d" % enemy.enemy_id, "kind": _kind_name(enemy), "position": [enemy.position.x, enemy.position.y], "health": enemy.health, "max_health": enemy.max_health, "cooldown_remaining": enemy.cooldown_remaining, "windup_remaining": enemy.windup_remaining, "target_id": "hero" if enemy.enemy_kind == EnemyScript.EnemyKind.RANGED or enemy.enemy_kind == EnemyScript.EnemyKind.PURSUER else "", "dead": false, "component_state": enemy.capture_snapshot_state()})
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
	return {"run_state": {"run_id": run_state.run_id, "well_id": run_state.selected_well_id, "hero_id": run_state.selected_hero_id, "module_id": run_state.selected_module_id, "phase": run_state.phase, "paused": true, "simulation_elapsed": run_state.simulation_elapsed, "tank_base": run_state.tank_base, "extraction_rate": run_state.extraction_rate, "pressure_time_scale": run_state.pressure_time_scale, "completed_surges": run_state.completed_surges, "surge_limit": run_state.surge_limit, "surge_clock": run_state.surge_clock, "multiplier": run_state.multiplier, "locked_payout": run_state.locked_payout, "sealing_remaining": run_state.sealing_remaining, "sealing_duration": run_state.sealing_duration, "hero_health": run_state.hero_health, "machine_integrity": run_state.machine_integrity, "machine_max_integrity": run_state.machine_max_integrity, "terminal_reason": run_state.terminal_reason}, "actors": actors, "projectiles": projectile_states, "player_abilities": {"dash_cooldown_remaining": dash_cooldown_remaining, "pulse_cooldown_remaining": pulse_cooldown_remaining, "dash_remaining": dash_remaining, "dash_direction": [float(dash_direction), 0.0], "dash_active": dash_remaining > 0.0, "ability_flash_remaining": 0.0}, "weapon_state": {"damage": weapon_damage, "spread_enabled": account_state.has_upgrade("spread_1"), "attack_interval": weapon_interval, "shot_accumulator": weapon_clock, "behavior_id": weapon_behavior_id, "phase": melee_phase, "strike_delay_remaining": melee_strike_delay_remaining, "locked_facing": melee_locked_facing, "target_id": melee_target_id, "damage_committed": melee_damage_committed}, "spawner": {"tutorial": tutorial_mode, "boss_state": boss_state, "spawn_timer": spawn_timer, "spawn_index": spawn_index, "spawn_position": [ENEMY_SPAWN_X, GROUND_Y], "config_id": "%s-%s" % [selected_well_id, selected_loadout_id], "next_id": next_enemy_id, "rng_state": spawner_rng_state}, "arena_config_id": ArenaLayoutScript.CONFIG_ID, "director": get_director_state(), "level_definition": frozen_level_definition.duplicate(true), "level_content_hash": frozen_level_content_hash, "loot_registration": frozen_loot_registration.duplicate(true), "loot_state": {"enabled": loot_enabled, "item_level": loot_item_level, "rng_state": loot_rng_state, "acquired_item_ids": loot_acquired_item_ids.duplicate()}, "campaign": {"act_id": campaign_state.active_act_id, "node_id": campaign_state.active_node_id, "config_id": "%s-%s" % [selected_well_id, selected_loadout_id], "wave_index": spawn_index, "boss_timer": 0.0}, "objective": {"objective_id": "", "progress": objective_progress, "required": objective_required, "credited_ids": objective_credited_ids.duplicate()}, "reward_state": {"claim_receipts": claim_receipts.duplicate(), "pending_items": account_state.pending_rewards.duplicate(true)}}

func _restore_saved_snapshot() -> void:
	if not persistence_enabled:
		return
	if save_store.loaded_snapshot.is_empty():
		return
	if not SAVE_RUN_SNAPSHOTS:
		# A run saved by an older build: drop it (the run ended when it was left).
		save_store.loaded_snapshot = {}
		_save_account()
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
	hero.configure_hero(str(state.get("hero_id", account_state.get_active_hero_id())))
	_configure_weapon_loadout(str(state.get("hero_id", account_state.get_active_hero_id())))
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
		# Creature Lab creatures are saved under their archetype's kind plus their id.
		var saved_monster := str(actor["component_state"].get("monster", ""))
		var override := saved_monster if not saved_monster.is_empty() and bool(MonsterStatsScript.monster(saved_monster).get("custom", false)) else ""
		var restored_enemy: Node = spawn_enemy(kind, int(actor["component_state"].get("side", 1)), override)
		if restored_enemy != null:
			restored_enemy.enemy_id = int(actor["component_state"].get("enemy_id", restored_enemy.enemy_id))
			restored_enemy.position = Vector2(actor["position"][0], actor["position"][1])
			restored_enemy.health = float(actor["health"])
			restored_enemy.cooldown_remaining = float(actor["cooldown_remaining"])
			restored_enemy.windup_remaining = float(actor["windup_remaining"])
			restored_enemy.restore_snapshot_state(actor["component_state"])
			if restored_enemy.is_boss:
				boss_enemy = restored_enemy
	for projectile_data in snapshot["projectiles"]:
		var restored_projectile: Node = ProjectileScript.new()
		add_child(restored_projectile)
		restored_projectile.controller = self
		restored_projectile.position = Vector2(projectile_data["position"][0], projectile_data["position"][1])
		restored_projectile.velocity = Vector2(float(projectile_data["velocity"][0]), float(projectile_data["velocity"][1]))
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
	# A tutorial run stays monster-free when it is resumed.
	tutorial_mode = bool(snapshot["spawner"].get("tutorial", false))
	boss_state = str(snapshot["spawner"].get("boss_state", ""))
	frozen_level_definition = snapshot["level_definition"].duplicate(true)
	frozen_level_content_hash = str(snapshot["level_content_hash"])
	load_spawn_profile()
	frozen_loot_registration = snapshot.get("loot_registration", {}).duplicate(true)
	var saved_loot: Dictionary = snapshot.get("loot_state", {})
	loot_enabled = bool(saved_loot.get("enabled", false))
	loot_item_level = clampi(int(saved_loot.get("item_level", 1)), 1, 3)
	loot_rng_state = int(saved_loot.get("rng_state", 1))
	loot_acquired_item_ids.assign(saved_loot.get("acquired_item_ids", []))
	pending_enemy_deaths.clear()
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
	weapon_clock = snapshot["weapon_state"]["shot_accumulator"]
	weapon_interval = maxf(0.01, float(snapshot["weapon_state"].get("attack_interval", BalanceData.WEAPON_INTERVAL)))
	weapon_behavior_id = str(snapshot["weapon_state"].get("behavior_id", "weapon.ranged"))
	melee_phase = str(snapshot["weapon_state"].get("phase", ""))
	melee_strike_delay_remaining = maxf(0.0, float(snapshot["weapon_state"].get("strike_delay_remaining", 0.0)))
	melee_locked_facing = -1 if int(snapshot["weapon_state"].get("locked_facing", 1)) < 0 else 1
	melee_target_id = str(snapshot["weapon_state"].get("target_id", ""))
	melee_damage_committed = bool(snapshot["weapon_state"].get("damage_committed", false))
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
	_freeze_loot_registration_from_definition()
	_apply_level_backdrop()

func _freeze_loot_registration_from_definition() -> void:
	var loot: Dictionary = frozen_level_definition.get("rewards", {}).get("loot", {})
	var item_level := int(loot.get("item_level", 1))
	frozen_loot_registration = WeaponLootRegistrationScript.snapshot_for(WeaponLootRegistrationScript.TABLE_ID, clampi(item_level, 1, 3))

## Dev Encyclopedia > Weapons: tries unsaved drop settings
## ({weapon_id: registration}) in this level straight away.
func apply_loot_overrides(overrides: Dictionary) -> void:
	frozen_loot_registration = WeaponLootRegistrationScript.snapshot_for(WeaponLootRegistrationScript.TABLE_ID, loot_item_level, WeaponLootRegistrationScript.DEFAULT_PATH, WeaponLootRegistrationScript.DEFAULT_INDEX_PATH, overrides)

func _initialize_loot(run_id: String) -> void:
	var loot: Dictionary = frozen_level_definition.get("rewards", {}).get("loot", {})
	loot_enabled = not loot.is_empty()
	loot_item_level = clampi(int(loot.get("item_level", 1)), 1, 3)
	loot_rng_state = LootGeneratorScript.seed_for("%s|%s" % [run_id, frozen_level_content_hash])
	loot_acquired_item_ids.clear()
	pending_enemy_deaths.clear()

func enqueue_enemy_death(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	for event in pending_enemy_deaths:
		if int(event.get("enemy_id", 0)) == int(enemy.enemy_id):
			return
	pending_enemy_deaths.append({"enemy_id": int(enemy.enemy_id), "enemy": enemy})

func _process_enemy_deaths() -> void:
	if pending_enemy_deaths.is_empty():
		return
	pending_enemy_deaths.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.enemy_id) < int(right.enemy_id))
	for event in pending_enemy_deaths:
		var enemy: Node = event.get("enemy")
		if loot_enabled and enemy != null and is_instance_valid(enemy):
			_roll_enemy_reward(enemy)
		if enemy != null and is_instance_valid(enemy):
			# The body stays behind to play its death animation, then frees itself.
			if enemy.has_method("release_death_visual"):
				enemy.release_death_visual(self)
			enemy.queue_free()
	pending_enemy_deaths.clear()

func _roll_enemy_reward(enemy: Node) -> void:
	var source_node_id := str(frozen_level_definition.get("id", campaign_state.active_node_id))
	if source_node_id.is_empty():
		source_node_id = selected_well_id
	var roll_input := {
		"eligible": true,
		"occurrence_kind": "boss" if str(frozen_level_definition.get("type", "")) == "boss" else "ordinary",
		"drop_bonus": 0.0,
		"item_level": loot_item_level,
		"inventory_count": account_state.item_instances.size(),
		"inventory_capacity": AccountStateScript.INVENTORY_CAPACITY,
		"run_id": run_state.run_id,
		"enemy_id": int(enemy.enemy_id),
		"node_id": source_node_id,
		"published_pool": frozen_loot_registration.get("pool", []).duplicate(true),
	}
	if OS.is_debug_build() and development_drop_percent >= 0.0:
		roll_input["development_drop_percent"] = development_drop_percent
	_roll_creature_weapon(enemy, roll_input)
	var result: Dictionary = LootGeneratorScript.generate(roll_input, loot_rng_state)
	if not result.get("valid", false):
		push_warning("Loot generation failed: %s" % str(result.get("error", "unknown error")))
		return
	loot_rng_state = int(result.get("rng_state", loot_rng_state))
	if not result.get("generated", false):
		return
	var instance: Dictionary = result.get("instance", {})
	if account_state.add_monster_instance(instance):
		loot_acquired_item_ids.append(str(instance.get("instance_id", "")))
		var visual := preload("res://scripts/game/loot_drop_visual.gd").new()
		visual.setup(self, enemy.position, instance)
		add_child(visual)

## Weapons with per-creature chances (Dev Encyclopedia > Weapons > Loot drops)
## roll on their own for this kill, smoothed by PRD (CreatureDrops).
func _roll_creature_weapon(enemy: Node, roll_input: Dictionary) -> void:
	if account_state.item_instances.size() >= AccountStateScript.INVENTORY_CAPACITY:
		return
	var key := CreatureDropsScript.BOSS_KEY if bool(enemy.get("is_boss")) else (str(enemy.monster_id()) if enemy.has_method("monster_id") else "")
	if key.is_empty():
		return
	var rolled: Dictionary = CreatureDropsScript.roll(frozen_loot_registration.get("pool", []), key, account_state.loot_streaks, loot_rng_state)
	loot_rng_state = int(rolled.get("rng_state", loot_rng_state))
	var entry: Dictionary = rolled.get("entry", {})
	if entry.is_empty():
		return
	var made: Dictionary = CreatureDropsScript.instance_for(entry, roll_input, loot_rng_state)
	if not made.get("valid", false):
		push_warning("Creature weapon drop failed: %s" % str(made.get("error", "unknown error")))
		return
	var instance: Dictionary = made.get("instance", {})
	if account_state.add_monster_instance(instance):
		loot_acquired_item_ids.append(str(instance.get("instance_id", "")))
		var visual := preload("res://scripts/game/loot_drop_visual.gd").new()
		visual.setup(self, enemy.position, instance)
		add_child(visual)

## Dev Encyclopedia > Weapons > "Drop one now": drops a published weapon in
## front of the hero through the normal monster-drop path (same orb, same
## inventory entry, marked new). Debug builds only. Returns a status line.
var _dev_drop_count := 0

func drop_weapon_now(weapon_id: String) -> String:
	if not OS.is_debug_build():
		return "Test drops are for development builds only."
	var publication: Dictionary = account_state.published_weapons.get(weapon_id, {})
	if publication.is_empty():
		return "That weapon isn't published."
	if account_state.item_instances.size() >= AccountStateScript.INVENTORY_CAPACITY:
		return "Inventory is full (%d items)." % AccountStateScript.INVENTORY_CAPACITY
	_dev_drop_count += 1
	var entry := {"weapon_id": weapon_id, "revision": int(publication.revision.get("revision", 1)), "recipe": publication.recipe, "definition": publication.revision}
	var run_id := str(run_state.run_id) if not str(run_state.run_id).is_empty() else "dev-drop"
	var node_id := current_level_id()
	if node_id.is_empty():
		node_id = "dev"
	var input := {"run_id": run_id, "enemy_id": 900000 + next_enemy_id * 100 + _dev_drop_count, "node_id": node_id}
	var made: Dictionary = CreatureDropsScript.instance_for(entry, input, loot_rng_state)
	if not made.get("valid", false):
		return "Couldn't make the drop: %s" % str(made.get("error", "unknown error"))
	var instance: Dictionary = made.instance
	if not account_state.add_monster_instance(instance):
		return "Couldn't add it: %s" % account_state.inventory_command_error
	loot_acquired_item_ids.append(str(instance.get("instance_id", "")))
	var visual := preload("res://scripts/game/loot_drop_visual.gd").new()
	var spot: Vector2 = hero.position + Vector2(140 * hero.last_facing, 0) if hero != null else Vector2(640, GROUND_Y)
	visual.setup(self, spot, instance)
	add_child(visual)
	return "Dropped one in front of the hero. Close the encyclopedia to watch it fly in."

func execute_loot_command(value: String) -> String:
	if not OS.is_debug_build():
		return "Loot commands are available in development builds only."
	var words := value.strip_edges().to_lower().split(" ", false)
	if words.size() != 2 or words[0] != "drop_rate":
		return "Use: drop_rate <0–100> or drop_rate reset"
	if words[1] == "reset":
		development_drop_percent = -1.0
		return "Normal drop rates restored."
	if not words[1].is_valid_float():
		return "Enter a percentage from 0 to 100."
	var percent := words[1].to_float()
	if not is_finite(percent) or percent < 0.0 or percent > 100.0:
		return "Enter a percentage from 0 to 100."
	development_drop_percent = percent
	loot_enabled = true
	return "Drop chance: %s%% for eligible enemies." % str(percent)

## Levels whose art has the walkway higher up the screen (the Broken Viaduct's
## bridge deck): the play field (hero, drill, monsters, shots) is drawn this
## many pixels higher so it stands on it. Gameplay coordinates don't change.
const BACKDROP_FLOOR_LIFT := {"broken_viaduct": 225.0, "crown_furnace": -25.0}
var world_lift := 0.0

func _apply_level_backdrop() -> void:
	if environment_visual == null:
		return
	environment_visual.call("set_backdrop_id", str(frozen_level_definition.get("backdrop_id", "")))
	set_world_lift(float(BACKDROP_FLOOR_LIFT.get(str(environment_visual.backdrop_id), 0.0)))

## Raises everything in the world except the backdrop by `lift` pixels.
func set_world_lift(lift: float) -> void:
	world_lift = lift
	position.y = -lift
	if environment_visual != null:
		environment_visual.position.y = lift

func _update_hud() -> void:
	if encounter_hud == null:
		return
	hud_full_refresh_elapsed = 0.0
	hud_last_phase = int(run_state.phase)
	hud_last_paused = run_state.paused
	var ability_state := {
		"dash_cooldown_remaining": dash_cooldown_remaining,
		"pulse_cooldown_remaining": pulse_cooldown_remaining,
	}
	var view_state: Dictionary = UiViewStateScript.build(account_state, run_state, selected_well_id, _notices(), ability_state, campaign_state)
	view_state["director"] = get_director_state()
	var combat_view: Dictionary = view_state.get("combat", {})
	var director_state: Dictionary = view_state["director"]
	combat_view["threat_label"] = "Next spawn: %.1fs" % maxf(0.0, float(director_state["spawn_interval"]) - spawn_timer) if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else "No active surge"
	combat_view["drill"] = drill_view()
	combat_view["boss_label"] = boss_label()
	combat_view["level_name"] = _level_display_name()
	view_state["combat"] = combat_view
	encounter_hud.set_view_state(view_state)

## Where the drill is on screen, in world coordinates (the click target).
func drill_rect() -> Rect2:
	if harvester_visual == null or not is_instance_valid(harvester_visual):
		return Rect2()
	var ground: Vector2 = harvester_visual.to_global(harvester_visual.ground_anchor_local())
	var top: float = harvester_visual.to_global(Vector2(0.0, harvester_visual.visible_top_local_y())).y
	var height := maxf(40.0, ground.y - top)
	var width := height * 1.17
	return Rect2(ground.x - width * 0.5, ground.y - height, width, height)

## A left click on the game view (viewport coordinates). The HUD forwards
## clicks that land on empty screen here. Returns true if it hit the drill.
func handle_world_click(viewport_position: Vector2) -> bool:
	var world := get_canvas_transform().affine_inverse() * viewport_position
	if drill_rect().has_point(world):
		toggle_drill_panel()
		return true
	return false

func toggle_drill_panel() -> void:
	drill_panel_open = not drill_panel_open
	_update_hud()

func close_drill_panel() -> void:
	if drill_panel_open:
		drill_panel_open = false
		_update_hud()

## Sets the surge limit for the current level (0 = no limit). It is saved per
## level and applies right away to a run in progress.
func set_surge_limit(limit: int) -> void:
	var clamped := clampi(limit, 0, MAX_SURGE_LIMIT)
	account_state.set_surge_limit(selected_well_id, clamped)
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		run_state.set_surge_limit(clamped)
	_save_account()
	_update_hud()

## What the drill panel shows.
func drill_view() -> Dictionary:
	var running: bool = run_state.phase == RunStateScript.Phase.EXTRACTING
	var limit: int = account_state.get_surge_limit(selected_well_id)
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		limit = run_state.surge_limit
	var anchor := Vector2.ZERO
	var rect := drill_rect()
	if rect.size != Vector2.ZERO:
		# Bottom-left corner of the panel: beside the top of the drill, above the floor lane.
		anchor = get_canvas_transform() * Vector2(rect.end.x + 4.0, rect.position.y + rect.size.y * 0.3)
	return {
		"open": drill_panel_open,
		"running": running,
		"phase": int(run_state.phase),
		"mana_per_second": run_state.mana_per_second(),
		"base_mana_per_second": run_state.base_mana_per_second() if running else 0.0,
		"multiplier": run_state.multiplier,
		"completed_surges": run_state.completed_surges,
		"surge_limit": limit,
		"progress_surge": int(spawn_profile.get("progress_surge", 0)) if boss_state == "waiting" else 0,
		"at_surge_limit": run_state.at_surge_limit(),
		"max_surge_limit": MAX_SURGE_LIMIT,
		"screen_anchor": anchor,
	}

func apply_enemy_damage(target: int, amount: float) -> bool:
	if target == RunStateScript.DamageTarget.HERO and dash_remaining > 0.0:
		return false
	var applied: bool = run_state.apply_damage(target, amount)
	if applied and target == RunStateScript.DamageTarget.HERO and hero != null and hero.visual != null:
		# Presentation only: hurt / death animation on the hero.
		if run_state.hero_health <= 0.0:
			hero.visual.play_death()
		else:
			hero.visual.play_hurt()
	return applied

func _attach_monster_encyclopedia() -> void:
	# Developer tool: F9 in debug builds. Not added to exported release builds.
	if not OS.is_debug_build():
		return
	monster_encyclopedia = MonsterEncyclopediaScript.new()
	monster_encyclopedia.name = "MonsterEncyclopedia"
	monster_encyclopedia.controller = self
	add_child(monster_encyclopedia)

## Pushes edited MonsterStats onto enemies already in the arena.
func apply_monster_stats() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.refresh_stats()

## Dev Encyclopedia > Weapons: new numbers for a published weapon reach this
## run at once (owned copies, and the hero's weapon if it's the one equipped).
func apply_weapon_stats(weapon_id: String, patch: Dictionary) -> void:
	account_state.apply_weapon_patch(weapon_id, patch)
	_configure_weapon_loadout(str(run_state.selected_hero_id) if not str(run_state.selected_hero_id).is_empty() else account_state.get_active_hero_id())

func set_experiment_paused(should_pause: bool) -> void:
	run_state.set_paused(should_pause)
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

## Q: a burst of BURST_SHOTS bullets fired BURST_INTERVAL apart at the
## nearest monster (straight ahead if none is in range), each doing
## PULSE_DAMAGE. Same cooldown as before (BalanceData.PULSE_COOLDOWN).
const BURST_SHOTS := 3
const BURST_INTERVAL := 0.09
var burst_shots_left := 0
var burst_timer := 0.0

## Returns the number of bullets queued (0 if Q isn't ready).
func try_pulse() -> int:
	if run_state.paused or pulse_cooldown_remaining > 0.0 or run_state.phase != RunStateScript.Phase.EXTRACTING:
		return 0
	pulse_cooldown_remaining = BalanceData.PULSE_COOLDOWN
	burst_shots_left = BURST_SHOTS
	burst_timer = 0.0
	_fire_burst_shot()
	return BURST_SHOTS

func _advance_burst(delta: float) -> void:
	if burst_shots_left <= 0:
		return
	burst_timer += delta
	while burst_shots_left > 0 and burst_timer >= BURST_INTERVAL:
		burst_timer -= BURST_INTERVAL
		_fire_burst_shot()

func _fire_burst_shot() -> void:
	if burst_shots_left <= 0 or hero == null:
		return
	burst_shots_left -= 1
	var target: Node = closest_live_enemy()
	var target_x: float = target.position.x if target != null else hero.position.x + float(hero.last_facing) * 1400.0
	spawn_friendly_projectile(hero.position.x, target_x, target)
	var bullet: Node = projectiles.back() if not projectiles.is_empty() else null
	if bullet != null:
		bullet.damage = BalanceData.PULSE_DAMAGE

## Enemies always enter from the right: the drill sits on the left edge, so
## the fight comes toward it. (_side is kept so callers and old saves that
## pass a side still work; it is ignored.)
const ENEMY_SPAWN_X := 1240.0

## `monster_override`: a Creature Lab creature id (its art and stats, `kind`'s AI).
func spawn_enemy(kind: int, _side: int = 1, monster_override: String = "") -> Node:
	_prune_enemies()
	if enemies.size() >= BalanceData.MAX_LIVE_ENEMIES:
		return null
	var enemy: Node = EnemyScript.new()
	enemy.monster_override = monster_override
	enemy.setup(kind, next_enemy_id, 1, self, _enemy_damage_multiplier())
	next_enemy_id += 1
	enemy.position = Vector2(ENEMY_SPAWN_X, GROUND_Y - 40.0)
	add_child(enemy)
	enemy.z_index = 2
	enemies.append(enemy)
	if not spawned_kinds.has(kind):
		spawned_kinds.append(kind)
	return enemy

## Spawns any encyclopedia monster by id: a built-in ("breaker") or a Creature
## Lab creature, which fights with its archetype's AI. null if unknown or full.
func spawn_monster_id(monster_id: String, side: int = 1) -> Node:
	var entry := MonsterStatsScript.monster(monster_id)
	if entry.is_empty():
		return null
	return spawn_enemy(int(entry.get("kind", 0)), side, monster_id if bool(entry.get("custom", false)) else "")

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
	# A ranged creature fires at its own projectile speed.
	var shooter: String = source_enemy.monster_id() if source_enemy != null and source_enemy.has_method("monster_id") and source_enemy.enemy_kind == EnemyScript.EnemyKind.RANGED else "ranged"
	projectile.setup(self, origin, Vector2(target_x, locked_target_y), damage, MonsterStatsScript.get_stat(shooter, "projectile_speed"), BalanceData.RANGED_PROJECTILE_LIFETIME, true, facing)
	projectile.source_enemy_id = source_enemy.enemy_id if source_enemy != null else 0
	add_child(projectile)
	projectile.z_index = 3
	projectiles.append(projectile)

func spawn_friendly_projectile(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	var projectile: Node = ProjectileScript.new()
	var origin := CombatGeometryScript.muzzle_position("hero", hero.position, hero.last_facing)
	var target_kind := "pursuer"
	if target_enemy != null:
		target_kind = _kind_name(target_enemy)
	var target := CombatGeometryScript.body_center(target_kind, target_enemy.position) if target_enemy != null else Vector2(target_x, CombatGeometryScript.body_center("hero", hero.position).y)
	projectile.setup(self, origin, target, weapon_damage, BalanceData.WEAPON_PROJECTILE_SPEED, BalanceData.WEAPON_PROJECTILE_LIFETIME, false, hero.last_facing)
	projectile.owner_id = "hero"
	projectile.target_id = "enemy-%d" % target_enemy.enemy_id if target_enemy != null else "hero"
	add_child(projectile)
	projectile.z_index = 3
	projectiles.append(projectile)

func spawn_friendly_volley(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	var shot_count := maxi(3, weapon_projectile_count) if account_state.has_upgrade("spread_1") else maxi(1, weapon_projectile_count)
	for _shot in range(shot_count):
		spawn_friendly_projectile(origin_x, target_x, target_enemy)

func is_hero_on_segment(start_position: Vector2, end_position: Vector2) -> bool:
	return CombatGeometryScript.segment_fraction_against_rect(start_position, end_position, CombatGeometryScript.hurtbox_rect("hero", hero.position)) >= 0.0

func closest_live_enemy() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_kind := _kind_name(enemy)
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
		var enemy_kind := _kind_name(enemy)
		var fraction := CombatGeometryScript.segment_fraction_against_rect(start_position, end_position, CombatGeometryScript.hurtbox_rect(enemy_kind, enemy.position))
		if fraction >= 0.0 and (fraction < nearest_fraction or (is_equal_approx(fraction, nearest_fraction) and (nearest == null or enemy.enemy_id < nearest.enemy_id))):
			nearest = enemy
			nearest_fraction = fraction
	return nearest

## Spawner and ability state that belongs to one run. Reset by start_run so a
## new level doesn't inherit the previous run's spawn cycle or cooldowns.
func _reset_run_counters() -> void:
	next_enemy_id = 1
	spawn_timer = 0.0
	spawn_index = 0
	spawned_kinds.clear()
	weapon_clock = 0.0
	_cancel_melee_swing()
	dash_remaining = 0.0
	dash_cooldown_remaining = 0.0
	pulse_cooldown_remaining = 0.0

func retry() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return
	_clear_transients()
	run_state.reset()
	_reset_run_counters()
	last_input_direction = 0
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
	if tutorial_mode:
		start_tutorial()
	else:
		start_run()

func _advance_spawning(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or run_state.paused:
		return
	if str(spawn_profile.get("mode", "")) == LevelSpawnsScript.MODE_NONE:
		return
	spawn_timer += delta
	var interval := _spawn_interval()
	while spawn_timer >= interval:
		spawn_timer -= interval
		_spawn_next_enemy()
		interval = _spawn_interval()

func _spawn_interval() -> float:
	if _custom_spawns():
		return LevelSpawnsScript.interval_for(spawn_profile, run_state.completed_surges)
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
	var cap: int = mini(BalanceData.LIVE_ENEMY_LIMIT, int(spawn_profile.get("max_alive", BalanceData.LIVE_ENEMY_LIMIT))) if _custom_spawns() else BalanceData.LIVE_ENEMY_LIMIT
	if enemies.size() >= cap:
		spawn_index += 1
		return
	if _custom_spawns():
		var monster_id := LevelSpawnsScript.pick(spawn_profile, spawn_index)
		if not monster_id.is_empty():
			spawn_monster_id(monster_id)
	else:
		spawn_enemy(_next_enemy_kind())
	spawn_index += 1

## A level starts: read its spawn/progression settings and announce the goal.
func _begin_zone() -> void:
	load_spawn_profile()
	boss_enemy = null
	var gate := int(spawn_profile.get("progress_surge", 0))
	boss_state = "waiting" if gate > 0 else ""
	if gate > 0:
		assignment_notice = "%s: reach surge %d to face the zone boss. Defeat it to unlock %s." % [LevelSpawnsScript.level_name(current_level_id()), gate, _next_zone_name()] if not _zone_already_cleared() else "%s is cleared. Farm it, or reach surge %d to fight the boss again." % [LevelSpawnsScript.level_name(current_level_id()), gate]

## Spawns the boss when the run reaches the level's progress surge, and clears
## the level when it dies.
func _update_zone_boss() -> void:
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		return
	match boss_state:
		"waiting":
			if run_state.completed_surges >= int(spawn_profile.get("progress_surge", 0)):
				_spawn_zone_boss()
		"active":
			if boss_enemy == null or not is_instance_valid(boss_enemy) or boss_enemy.dead:
				_on_zone_boss_defeated()

func _spawn_zone_boss() -> void:
	var monster_id := LevelSpawnsScript.boss_monster(spawn_profile)
	var boss: Node = spawn_monster_id(monster_id)
	if boss == null:
		return # arena full: try again next step
	boss.make_boss(float(spawn_profile.get("boss_health", 8.0)), float(spawn_profile.get("boss_damage", 1.5)), float(spawn_profile.get("boss_size", 1.5)))
	boss_enemy = boss
	boss_state = "active"
	assignment_notice = "The zone boss is here! Defeat it to clear %s." % LevelSpawnsScript.level_name(current_level_id())
	_update_hud()

func _on_zone_boss_defeated() -> void:
	boss_state = "defeated"
	boss_enemy = null
	var first_clear := not _zone_already_cleared()
	var zone := _campaign_zone()
	if tutorial_mode:
		campaign_state.tutorial_cleared = true
	if not zone.is_empty():
		campaign_state.mark_cleared(str(zone.act_id), str(zone.node_id), campaign_state_catalog())
	if first_clear:
		assignment_notice = "Zone cleared! %s is unlocked. Keep farming, or Harvest to leave." % _next_zone_name()
	else:
		assignment_notice = "Boss defeated. Keep farming, or Harvest to leave."
	# Save right away so the unlock survives even if this run is lost.
	_save_account()
	_update_hud()

## The level's name for the HUD (levels can share a backdrop, e.g. the
## tutorial and Intake Well both use the Sector B art).
func _level_display_name() -> String:
	if run_state.phase == RunStateScript.Phase.READY:
		return ""
	return LevelSpawnsScript.level_name(current_level_id()).to_upper()

## One line for the surge box: where the boss comes, or how the fight went.
func boss_label() -> String:
	var gate := int(spawn_profile.get("progress_surge", 0))
	match boss_state:
		"waiting":
			if run_state.surge_limit > 0 and run_state.surge_limit < gate:
				return "Boss at surge %d · limit %d (farming)" % [gate, run_state.surge_limit]
			return "Boss at surge %d" % gate
		"active":
			return "BOSS FIGHT"
		"defeated":
			return "Zone boss defeated"
	return ""

## The campaign level this run is on ({act_id, node_id}), however it was
## started (from the map, or Start extraction on a well); {} for the tutorial.
func _campaign_zone() -> Dictionary:
	var node_id := LevelSpawnsScript.TUTORIAL_NODE_ID if tutorial_mode else current_level_id()
	var catalog: RefCounted = campaign_state_catalog()
	for act_id in catalog.act_order:
		if catalog.node_ids(act_id).has(node_id):
			return {"act_id": act_id, "node_id": node_id}
	return {}

func _tutorial_zone() -> Dictionary:
	var catalog: RefCounted = campaign_state_catalog()
	for act_id in catalog.act_order:
		if catalog.node_ids(act_id).has(LevelSpawnsScript.TUTORIAL_NODE_ID):
			return {"act_id": act_id, "node_id": LevelSpawnsScript.TUTORIAL_NODE_ID}
	return {}

## True once the tutorial's boss has been beaten (on this profile).
func tutorial_done() -> bool:
	var zone := _tutorial_zone()
	return campaign_state.tutorial_cleared or (not zone.is_empty() and campaign_state.is_cleared(str(zone.act_id), str(zone.node_id)))

func _zone_already_cleared() -> bool:
	if tutorial_mode:
		return tutorial_done()
	var zone := _campaign_zone()
	return not zone.is_empty() and campaign_state.is_cleared(str(zone.act_id), str(zone.node_id))

func _next_zone_name() -> String:
	var catalog: RefCounted = campaign_state_catalog()
	var zone := _campaign_zone()
	if zone.is_empty():
		var first_act: String = catalog.first_act_id()
		var ids: Array = catalog.node_ids(first_act)
		return str(catalog.get_node(first_act, str(ids[0])).get("display_name", "the next level")) if not ids.is_empty() else "the next level"
	var next: Dictionary = campaign_state.next_node(str(zone.act_id), str(zone.node_id), catalog)
	return str(next.get("display_name", "the next act")) if not next.is_empty() else "the next act"

## Which level the spawn settings are looked up under.
func current_level_id() -> String:
	if tutorial_mode:
		return LevelSpawnsScript.TUTORIAL_ID
	return str(frozen_level_definition.get("id", campaign_state.active_node_id if not campaign_state.active_node_id.is_empty() else selected_well_id))

## Reads this level's spawn settings (or the preview's). Called when a level
## starts or is restored, and by the spawn editor after an edit.
func load_spawn_profile() -> void:
	var level_id := current_level_id()
	if preview_mode and GameFlowScript.preview_level_id == level_id and not GameFlowScript.preview_profile.is_empty():
		spawn_profile = GameFlowScript.preview_profile.duplicate(true)
	else:
		spawn_profile = LevelSpawnsScript.profile(level_id)

func _custom_spawns() -> bool:
	return str(spawn_profile.get("mode", "")) == LevelSpawnsScript.MODE_CUSTOM

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
		"spawn_interval": _spawn_interval() if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING else 0.0,
		"completed_surges": run_state.completed_surges,
	}

## "pursuer", "breaker" or "ranged" (the id used by hurtboxes, saves and stats).
static func _kind_name(enemy: Node) -> String:
	return MonsterStatsScript.id_for_kind(enemy.enemy_kind)

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
	if weapon_behavior_id == "weapon.melee":
		_simulate_melee_weapon(delta)
		return
	while weapon_clock >= weapon_interval:
		weapon_clock -= weapon_interval
		var target := closest_live_enemy()
		if target != null:
			if hero != null and hero.visual != null:
				hero.visual.play_attack()
			if account_state.has_upgrade("spread_1"):
				spawn_friendly_volley(hero.position.x, target.position.x, target)
			else:
				spawn_friendly_projectile(hero.position.x, target.position.x, target)

func _simulate_melee_weapon(delta: float) -> void:
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		_cancel_melee_swing()
		return
	if run_state.hero_health <= 0.0:
		_cancel_melee_swing()
		return
	if melee_phase.is_empty():
		while weapon_clock >= weapon_interval:
			weapon_clock -= weapon_interval
			var target := _closest_melee_target(hero.last_facing)
			if target == null:
				continue
			_begin_melee_swing(target)
			break
	if melee_phase.is_empty():
		return
	melee_strike_delay_remaining = maxf(0.0, melee_strike_delay_remaining - delta)
	if not melee_damage_committed and is_zero_approx(melee_strike_delay_remaining):
		_commit_melee_strike()
	if melee_strike_delay_remaining <= 0.0:
		# The strike delay is consumed; recovery lasts until the next cadence.
		var recovery: float = weapon_interval * (1.0 - MELEE_STRIKE_FRACTION)
		if melee_phase == "windup":
			melee_phase = "recovery"
			melee_strike_delay_remaining = recovery
		else:
			_cancel_melee_swing()

func _begin_melee_swing(target: Node) -> void:
	melee_phase = "windup"
	melee_strike_delay_remaining = weapon_interval * MELEE_STRIKE_FRACTION
	melee_locked_facing = hero.last_facing
	melee_target_id = "enemy-%d" % int(target.enemy_id)
	melee_damage_committed = false
	if hero != null and hero.visual != null:
		hero.visual.play_attack()

func _commit_melee_strike() -> void:
	if melee_damage_committed:
		return
	melee_damage_committed = true
	var target := _enemy_by_id(melee_target_id)
	if target == null or target.dead or not _melee_target_in_reach(target, melee_locked_facing):
		return
	target.take_damage(weapon_damage)

func _cancel_melee_swing() -> void:
	melee_phase = ""
	melee_strike_delay_remaining = 0.0
	melee_target_id = ""
	melee_damage_committed = false
	if hero != null:
		hero.interrupt_held_weapon_attack()

func _enemy_by_id(target_id: String) -> Node:
	if not target_id.begins_with("enemy-"):
		return null
	var enemy_id := int(target_id.trim_prefix("enemy-"))
	for enemy in enemies:
		if is_instance_valid(enemy) and int(enemy.enemy_id) == enemy_id:
			return enemy
	return null

func _melee_target_in_reach(target: Node, facing: int) -> bool:
	if target == null or target.dead:
		return false
	var kind := _kind_name(target)
	var center := CombatGeometryScript.body_center("hero", hero.position)
	var reach := MELEE_REACH_UNITS * SPATIAL_PIXELS_PER_UNIT
	var reach_rect := Rect2(center.x if facing > 0 else center.x - reach, center.y - 48.0, reach, 96.0)
	return CombatGeometryScript.hurtbox_rect(kind, target.position).intersects(reach_rect)

func _closest_melee_target(facing: int) -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or not _melee_target_in_reach(enemy, facing):
			continue
		var distance := absf(enemy.position.x - hero.position.x)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (nearest == null or enemy.enemy_id < nearest.enemy_id)):
			nearest = enemy
			nearest_distance = distance
	return nearest

func _process(_delta: float) -> void:
	# Safety-net autosave. Purchases, run results, equips etc. already save
	# immediately, and quitting or alt-tabbing saves too, so the timer only
	# limits what a crash can lose: 15 s of a run in progress, or a minute on
	# the menus (idle income is recalculated from the save time on load anyway).
	checkpoint_elapsed += maxf(0.0, _delta)
	var run_active: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	var interval: float = RUN_CHECKPOINT_SECONDS if run_active else MENU_CHECKPOINT_SECONDS
	if persistence_enabled and checkpoint_elapsed >= interval:
		checkpoint_elapsed = 0.0
		_save_account()
	if not run_state.paused:
		queue_redraw()
	_refresh_hud(_delta)

## Per-frame HUD refresh. During a run only the combat readout (health, surge,
## mana, drill panel) is rebuilt each frame; the full view (Operations, map,
## inventory, research) is rebuilt when the run's phase or pause state changes,
## and at most HUD_FULL_REFRESH_INTERVAL apart otherwise. Button presses and
## other events still call _update_hud() directly for an immediate full refresh.
func _refresh_hud(delta: float) -> void:
	hud_full_refresh_elapsed += maxf(0.0, delta)
	var run_active: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	var state_changed: bool = int(run_state.phase) != hud_last_phase or run_state.paused != hud_last_paused
	if run_active and not state_changed:
		_update_combat_hud()
	elif state_changed or hud_full_refresh_elapsed >= HUD_FULL_REFRESH_INTERVAL:
		_settle_production()
		_update_hud()

## Save problems, save recovery, time-away income and one-off action messages
## for the notice box and the Settings retry buttons.
func _notices() -> Dictionary:
	var pending_save: bool = persistence_enabled and session_persistence != null and session_persistence.has_pending_save()
	var save_failure := ""
	if pending_save:
		save_failure = str(save_store.last_error) if not str(save_store.last_error).is_empty() else "The last save didn't complete. Your progress is kept in memory."
	return {
		"save_failure": save_failure,
		"recovery": str(save_store.recovery_message) if persistence_enabled else "",
		"offline": offline_notice,
		"assignment": assignment_notice,
		"pending_save": pending_save,
		"offline_pending_total": offline_pending_total,
	}

func _combat_view_now() -> Dictionary:
	var ability_state := {
		"dash_cooldown_remaining": dash_cooldown_remaining,
		"pulse_cooldown_remaining": pulse_cooldown_remaining,
	}
	var active_run: bool = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	var combat_view: Dictionary = UiViewStateScript.combat_view(run_state, account_state.content_catalog, active_run, ability_state)
	var director_state: Dictionary = get_director_state()
	combat_view["threat_label"] = "Next spawn: %.1fs" % maxf(0.0, float(director_state["spawn_interval"]) - spawn_timer) if active_run else "No active surge"
	combat_view["drill"] = drill_view()
	combat_view["boss_label"] = boss_label()
	combat_view["level_name"] = _level_display_name()
	return combat_view

func _update_combat_hud() -> void:
	if encounter_hud == null:
		return
	encounter_hud.update_combat(_combat_view_now())

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
