class_name EncounterController
extends Node

const RunStateScript = preload("res://scripts/model/run_state.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const SessionPersistenceScript = preload("res://scripts/model/session_persistence.gd")
const ProductionScript = preload("res://scripts/model/production.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const MeleeEnemyScript = preload("res://scripts/game/melee_enemy.gd")
const AutoWeaponScript = preload("res://scripts/game/auto_weapon.gd")
const RangedEnemyScript = preload("res://scripts/game/ranged_enemy.gd")
const RangedProjectileScript = preload("res://scripts/game/ranged_projectile.gd")
const EncounterHUDScript = preload("res://scripts/ui/encounter_hud.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")
const RANGED_KIND: int = 2

@export var developer_mode: bool = false
@export var persistence_enabled: bool = true
@export_range(0.0, 2.0, 2.0) var sealing_duration_setting: float = BalanceData.SEALING_DURATION

var run_state: RefCounted = RunStateScript.new()
var account_state: RefCounted = AccountStateScript.new()
var save_store: RefCounted = SaveStoreScript.new()
var session_persistence: RefCounted
var production: RefCounted = ProductionScript.new()
var save_notice: String = ""
var assignment_notice: String = ""
var enemies: Array[Node3D] = []
var selected_well_id: String = "well_1"
var selected_loadout_id: String = LoadoutScript.STANDARD
var content_catalog: RefCounted = ContentCatalogScript.new()
var auto_weapon: Node
var encounter_hud: Node
var spawn_timer: float = 0.0
var spawn_index: int = 0
var next_snapshot_id: int = 1

var phase_label: Label
var bank_label: Label
var tank_label: Label
var hero_bar: ProgressBar
var machine_bar: ProgressBar
var tier_label: Label
var surge_label: Label
var threat_label: Label
var sealing_label: Label
var reason_label: Label
var action_button: Button
var retry_button: Button
var abandon_button: Button
var pause_button: Button
var status_label: Label
var dash_label: Label
var pulse_label: Label
var damage_upgrade_button: Button
var pump_upgrade_button: Button
var spread_upgrade_button: Button
var pump_visual: MeshInstance3D
var instruction_label: Label
var developer_setting_button: Button

var well_selector: OptionButton
var loadout_selector: OptionButton
var loadout_label: Label
var preparation_label: Label
var active_hero_selector: OptionButton
var guard_hero_selector: OptionButton
var assign_guard_button: Button
var recall_guard_button: Button
var assignment_label: Label
var upgrades_section: VBoxContainer
var developer_section: VBoxContainer
var account_section: VBoxContainer
var clear_save_button: Button
var network_section: VBoxContainer
var network_label: Label
var retry_offline_button: Button
var monotonic_settlement_cursor: float = 0.0
var production_utc_timestamp: float = 0.0
var displayed_rates: Dictionary = {}
var well_selector_signature: String = ""
var loadout_selector_signature: String = ""
var assignment_selector_signature: String = ""
var production_time_override: float = -1.0
var checkpoint_elapsed: float = 0.0
const CHECKPOINT_INTERVAL: float = 5.0
const FIXED_STEP: float = 1.0 / 60.0
const FIXED_STEP_EPSILON: float = 0.00001
var fixed_step_accumulator: float = 0.0
var pending_dash: bool = false
var pending_pulse: bool = false
var pending_harvest: bool = false
var pending_pause: bool = false
var offline_pending_total: float = 0.0
var offline_pending_utc_timestamp: float = 0.0
var offline_return_notice: String = ""
var battle_camera: Camera3D
var camera_distance: float = 25.46
var camera_yaw: float = 0.0
var camera_pitch: float = 0.785398
var camera_rotating: bool = false
const CAMERA_MIN_DISTANCE: float = 10.0
const CAMERA_MAX_DISTANCE: float = 40.0
const CAMERA_ZOOM_STEP: float = 2.0
const CAMERA_ROTATION_SENSITIVITY: float = 0.01
const CAMERA_MIN_PITCH: float = 0.2
const CAMERA_MAX_PITCH: float = 1.3

func _ready() -> void:
	_ensure_session_persistence()
	_load_account()
	if persistence_enabled:
		_settle_offline_production(session_persistence.now_utc())
	else:
		monotonic_settlement_cursor = session_persistence.now_monotonic()
		production.reset_cursor(monotonic_settlement_cursor)
	_ensure_runtime()
	_setup_battle_camera()
	encounter_hud = EncounterHUDScript.new()
	add_child(encounter_hud)
	encounter_hud.well_selected.connect(select_well_by_id)
	encounter_hud.loadout_selected.connect(select_loadout_by_id)
	encounter_hud.active_hero_selected.connect(select_active_hero_by_id)
	encounter_hud.guard_assigned.connect(assign_guard_by_id)
	encounter_hud.guard_recalled.connect(recall_guard_by_well_id)
	encounter_hud.upgrade_requested.connect(purchase_upgrade)
	_build_hud()
	status_label = Label.new()
	reason_label = Label.new()
	if developer_mode:
		developer_setting_button = Button.new()
	_restore_saved_snapshot()
	_update_hud()

func _load_account() -> void:
	if not persistence_enabled:
		return
	account_state = session_persistence.load_account()
	save_notice = save_store.recovery_message if not save_store.recovery_message.is_empty() else save_store.last_error
	if not account_state.is_well_unlocked(selected_well_id):
		selected_well_id = "well_1"
	selected_loadout_id = account_state.get_loadout_for_well(selected_well_id)

func configure_persistence(new_store: RefCounted, new_monotonic_clock: Callable = Callable(), new_utc_clock: Callable = Callable()) -> void:
	save_store = new_store
	session_persistence = SessionPersistenceScript.new(save_store, account_state, new_monotonic_clock, new_utc_clock)

func _ensure_session_persistence() -> void:
	if session_persistence == null or session_persistence.store != save_store:
		var previous_persistence: RefCounted = session_persistence
		session_persistence = SessionPersistenceScript.new(save_store, account_state, Callable(self, "_production_now"), Callable(self, "_offline_now"))
		if previous_persistence != null and previous_persistence.has_pending_save():
			session_persistence.dirty = true
			session_persistence.pending_snapshot = previous_persistence.pending_snapshot.duplicate(true)
			session_persistence.utc_high_water_mark = previous_persistence.utc_high_water_mark

func _ensure_runtime() -> void:
	if auto_weapon != null:
		return
	auto_weapon = AutoWeaponScript.new()
	add_child(auto_weapon)
	auto_weapon.setup(get_node("Hero"), run_state)
	auto_weapon.fired.connect(get_node("Hero/MechaVisual").show_shot)
	auto_weapon.set_id_allocator(Callable(self, "_allocate_snapshot_id").bind("projectile"))
	get_node("Hero").setup_abilities(run_state)

func _process(delta: float) -> void:
	_settle_production()
	_checkpoint_real_time(delta)
	_update_battle_camera()
	_update_hud()

func _input(event: InputEvent) -> void:
	if not _encounter_active():
		camera_rotating = false
		return
	if run_state.paused:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			camera_rotating = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_battle_camera(-CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_battle_camera(CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and camera_rotating:
		camera_yaw -= event.relative.x * CAMERA_ROTATION_SENSITIVITY
		camera_pitch = clampf(camera_pitch - event.relative.y * CAMERA_ROTATION_SENSITIVITY, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
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

func _setup_battle_camera() -> void:
	battle_camera = get_node_or_null("Camera") as Camera3D
	if battle_camera == null:
		return
	var target := get_node("Hero") as Node3D
	var offset := battle_camera.global_position - target.global_position
	var horizontal_distance := Vector2(offset.x, offset.z).length()
	camera_distance = clampf(offset.length(), CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	camera_yaw = atan2(offset.x, offset.z)
	camera_pitch = clampf(atan2(offset.y, horizontal_distance), CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	_update_battle_camera()

func _zoom_battle_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	_update_battle_camera()

func _update_battle_camera() -> void:
	if battle_camera == null or not is_instance_valid(battle_camera):
		return
	var target := get_node_or_null("Hero") as Node3D
	if target == null:
		return
	var horizontal_distance := cos(camera_pitch) * camera_distance
	var offset := Vector3(sin(camera_yaw) * horizontal_distance, sin(camera_pitch) * camera_distance, cos(camera_yaw) * horizontal_distance)
	battle_camera.global_position = target.global_position + offset
	battle_camera.look_at(target.global_position)

func _checkpoint_real_time(delta: float) -> void:
	checkpoint_elapsed += maxf(0.0, delta)
	if checkpoint_elapsed >= CHECKPOINT_INTERVAL:
		checkpoint_elapsed = fmod(checkpoint_elapsed, CHECKPOINT_INTERVAL)
		if session_persistence.has_pending_save():
			_save_checkpoint()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _encounter_active():
		_save_checkpoint()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_settle_production()
		_save_checkpoint()
		get_tree().quit()

func _physics_process(delta: float) -> void:
	fixed_step_accumulator += maxf(0.0, delta)
	while fixed_step_accumulator + FIXED_STEP_EPSILON >= FIXED_STEP:
		fixed_step_accumulator -= FIXED_STEP
		fixed_step_accumulator = maxf(0.0, fixed_step_accumulator)
		_simulate_fixed_step(FIXED_STEP)

func tick(delta: float) -> void:
	# Compatibility wrapper for tests; the running scene uses _physics_process.
	_settle_production()
	_run_fixed_steps(delta)
	_checkpoint_real_time(delta)
	_update_hud()

func _run_fixed_steps(delta: float) -> void:
	fixed_step_accumulator += maxf(0.0, delta)
	if is_zero_approx(delta):
		_simulate_fixed_step(0.0)
		return
	while fixed_step_accumulator + FIXED_STEP_EPSILON >= FIXED_STEP:
		fixed_step_accumulator -= FIXED_STEP
		fixed_step_accumulator = maxf(0.0, fixed_step_accumulator)
		_simulate_fixed_step(FIXED_STEP)

func _simulate_fixed_step(delta: float) -> void:
	var hero = get_node("Hero")
	_apply_pending_commands(hero)
	var was_active: bool = _encounter_active()
	if not was_active or run_state.paused:
		hero.simulate_tick(delta, Vector3.ZERO)
	else:
		hero.simulate_tick(delta, hero.get_input_direction())
	if auto_weapon != null:
		auto_weapon.set_enemies(enemies)
		auto_weapon.tick(delta)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("simulate_tick"):
			enemy.simulate_tick(delta)
	if was_active and not run_state.paused:
		# Combat and damage resolve before sealing/extraction terminal checks.
		run_state.advance(delta)
		_advance_spawning(delta)
	_credit_if_complete()

func _apply_pending_commands(hero: Node3D) -> void:
	if pending_dash:
		pending_dash = false
		hero.try_dash(hero.get_input_direction())
	if pending_pulse:
		pending_pulse = false
		hero.try_pulse(enemies)
	if pending_harvest:
		pending_harvest = false
		request_start_or_harvest()
	if pending_pause:
		pending_pause = false
		toggle_pause()

func request_start_or_harvest() -> void:
	if run_state.phase == RunStateScript.Phase.READY:
		_start_run()
	elif run_state.phase == RunStateScript.Phase.EXTRACTING:
		run_state.request_harvest()
		_update_hud()

func retry() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return
	_clear_enemies()
	if auto_weapon != null:
		auto_weapon.clear_projectiles()
	run_state.reset()
	_save_account()
	_start_run()

func return_to_operations() -> void:
	if run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return
	_clear_enemies()
	if auto_weapon != null:
		auto_weapon.clear_projectiles()
	run_state.reset()
	_save_account()
	_update_hud()

func abandon() -> void:
	if run_state.abandon():
		_save_account()
		_update_hud()

func toggle_pause() -> void:
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		return
	run_state.set_paused(not run_state.paused)
	_update_hud()

func damage_hero() -> void:
	get_node("Hero").receive_damage(25.0)
	_credit_if_complete()
	_update_hud()

func damage_machine() -> void:
	run_state.apply_damage(RunStateScript.DamageTarget.MACHINE, 25.0)
	_credit_if_complete()
	_update_hud()

func _start_run() -> void:
	_ensure_runtime()
	_settle_production()
	var extraction_rate: float = float(content_catalog.get_well(selected_well_id).get("base_output", BalanceData.WELL_1_BASE_OUTPUT))
	if account_state.has_upgrade("pump_1"):
		extraction_rate *= BalanceData.PUMP_OUTPUT_MULTIPLIER
	var loadout_modifiers: Dictionary = LoadoutScript.modifiers(selected_loadout_id)
	extraction_rate *= loadout_modifiers["extraction_multiplier"]
	var hero_id: String = account_state.get_active_hero_id()
	if hero_id.is_empty():
		return
	var machine_max_integrity: float = BalanceData.MACHINE_INTEGRITY * loadout_modifiers["machine_integrity_multiplier"]
	var run_id: String = account_state.allocate_run_id()
	if not run_state.start(run_id, selected_well_id, hero_id, selected_loadout_id, extraction_rate, sealing_duration_setting, BalanceData.HERO_HEALTH, machine_max_integrity, loadout_modifiers["pressure_time_scale"]):
		return
	var released_guard: String = account_state.release_guard_for_start(selected_well_id)
	if not released_guard.is_empty():
		assignment_notice = "%s released from guard duty to start this site." % _hero_name(released_guard)
	_save_account()
	var weapon_damage: float = BalanceData.WEAPON_DAMAGE + (BalanceData.DAMAGE_UPGRADE_BONUS if account_state.has_upgrade("damage_1") else 0.0)
	auto_weapon.configure(weapon_damage, account_state.has_upgrade("spread_1"))
	_apply_hero_visual(hero_id)
	get_node("Hero").reset_abilities()
	spawn_timer = 0.0
	spawn_index = 0
	next_snapshot_id = 1
	_clear_enemies()
	_update_hud()

func select_well(index: int) -> void:
	select_well_by_id("well_1" if index == 0 else "well_2")

func _on_well_index_selected(index: int) -> void:
	encounter_hud.choose_well("well_1" if index == 0 else "well_2")

func select_well_by_id(well_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY and run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return false
	if not content_catalog.has_well(well_id) or not account_state.is_well_unlocked(well_id):
		return false
	if run_state.phase == RunStateScript.Phase.SUCCESS or run_state.phase == RunStateScript.Phase.FAILED:
		_clear_enemies()
		if auto_weapon != null:
			auto_weapon.clear_projectiles()
		run_state.reset()
	selected_well_id = well_id
	selected_loadout_id = account_state.get_loadout_for_well(selected_well_id)
	_update_hud()
	return true

func select_loadout(index: int) -> void:
	if loadout_selector == null or index < 0 or index >= loadout_selector.item_count:
		return
	select_loadout_by_id(str(loadout_selector.get_item_metadata(index)))

func _on_loadout_index_selected(index: int) -> void:
	if loadout_selector == null or index < 0 or index >= loadout_selector.item_count:
		return
	encounter_hud.choose_loadout(str(loadout_selector.get_item_metadata(index)))

func select_loadout_by_id(loadout_id: String) -> bool:
	if run_state.phase != RunStateScript.Phase.READY and run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED:
		return false
	if account_state.select_loadout(selected_well_id, loadout_id):
		selected_loadout_id = loadout_id
		_save_account()
		_update_hud()
		return true
	return false

func _update_well_selector() -> void:
	pass

func _update_loadout_selector() -> void:
	pass

func _well_summary(well_id: String) -> String:
	var definition: Dictionary = content_catalog.get_well(well_id)
	if well_id == "well_1":
		return "%s: %.0f mana/sec | standard threats" % [definition.get("label", well_id), definition.get("base_output", 0.0)]
	if not account_state.is_well_unlocked("well_2"):
		return "%s: locked | qualify a Well 1 harvest" % definition.get("label", well_id)
	return "%s: %.0f mana/sec | threats 20%% faster, 25%% stronger" % [definition.get("label", well_id), definition.get("base_output", 0.0)]

func _update_assignment_controls() -> void:
	if active_hero_selector == null:
		return
	var signature := JSON.stringify([account_state.roster_heroes, account_state.hero_assignments, selected_well_id, run_state.phase])
	if signature == assignment_selector_signature:
		return
	assignment_selector_signature = signature
	active_hero_selector.clear()
	guard_hero_selector.clear()
	var active_index: int = 0
	var guard_index: int = 0
	var hero_index: int = 0
	for hero_id in content_catalog.hero_ids():
		if not account_state.has_hero(hero_id):
			continue
		active_hero_selector.add_item("Active: %s" % _hero_name(hero_id))
		active_hero_selector.set_item_metadata(active_hero_selector.item_count - 1, hero_id)
		if account_state.get_active_hero_id() == hero_id:
			active_index = hero_index
		active_hero_selector.set_item_disabled(active_hero_selector.item_count - 1, account_state.get_hero_role(hero_id) == "guard")
		guard_hero_selector.add_item("Guard: %s (%s)" % [_hero_name(hero_id), account_state.get_hero_role(hero_id)])
		guard_hero_selector.set_item_metadata(guard_hero_selector.item_count - 1, hero_id)
		guard_index = guard_hero_selector.item_count - 1
		hero_index += 1
	active_hero_selector.select(active_index)
	guard_hero_selector.select(guard_index)
	active_hero_selector.disabled = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	guard_hero_selector.disabled = not account_state.is_well_commissioned(selected_well_id) or run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	assign_guard_button.disabled = guard_hero_selector.disabled
	recall_guard_button.disabled = not account_state.is_well_commissioned(selected_well_id) or account_state.get_guard_for_well(selected_well_id).is_empty()
	var guard_id: String = account_state.get_guard_for_well(selected_well_id)
	assignment_label.text = "Guard: %s | Active: %s" % ["none" if guard_id.is_empty() else _hero_name(guard_id), _hero_name(account_state.get_active_hero_id())]

func select_active_hero(index: int) -> void:
	if active_hero_selector == null or index < 0 or index >= active_hero_selector.item_count:
		return
	var hero_id: String = active_hero_selector.get_item_metadata(index)
	select_active_hero_by_id(hero_id)

func _on_active_hero_index_selected(index: int) -> void:
	if active_hero_selector == null or index < 0 or index >= active_hero_selector.item_count:
		return
	encounter_hud.choose_active_hero(str(active_hero_selector.get_item_metadata(index)))

func select_active_hero_by_id(hero_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	_settle_production()
	if account_state.select_active_hero(hero_id):
		assignment_notice = "%s selected for active expeditions." % _hero_name(hero_id)
		_save_account()
		_update_assignment_controls()
		_update_hud()
		return true
	return false

func assign_selected_guard() -> void:
	if guard_hero_selector == null or guard_hero_selector.selected < 0:
		return
	var hero_id: String = guard_hero_selector.get_item_metadata(guard_hero_selector.selected)
	assign_guard_by_id(hero_id, selected_well_id)

func _on_assign_selected_guard() -> void:
	if guard_hero_selector == null or guard_hero_selector.selected < 0:
		return
	encounter_hud.assign_guard(str(guard_hero_selector.get_item_metadata(guard_hero_selector.selected)), selected_well_id)

func assign_guard_by_id(hero_id: String, well_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	_settle_production()
	if account_state.assign_guard(hero_id, well_id):
		assignment_notice = "%s assigned as guard for %s." % [_hero_name(hero_id), _well_name(well_id)]
		_save_account()
	else:
		assignment_notice = "Guard assignment unavailable: use a reserve hero and one commissioned site."
	_update_assignment_controls()
	_update_hud()
	return account_state.get_guard_for_well(well_id) == hero_id

func recall_selected_guard() -> void:
	recall_guard_by_well_id(selected_well_id)

func _on_recall_selected_guard() -> void:
	encounter_hud.recall_guard(selected_well_id)

func recall_guard_by_well_id(well_id: String) -> bool:
	var guard_id: String = account_state.get_guard_for_well(well_id)
	_settle_production()
	if account_state.recall_guard(well_id):
		assignment_notice = "%s recalled to reserve." % _hero_name(guard_id)
		_save_account()
	else:
		assignment_notice = "No guard is assigned to this site."
	_update_assignment_controls()
	_update_hud()
	return not guard_id.is_empty() and account_state.get_guard_for_well(well_id).is_empty()

func _save_account(snapshot: Dictionary = {}) -> void:
	_ensure_session_persistence()
	if persistence_enabled and not save_store.writes_allowed:
		save_notice = save_store.last_error if not save_store.last_error.is_empty() else "Save is protected until the rejected account is recovered or reset."
		return
	if snapshot.is_empty() and _encounter_active():
		snapshot = _capture_snapshot()
	if persistence_enabled:
		production_utc_timestamp = session_persistence.now_utc()
	if persistence_enabled and not session_persistence.save(snapshot):
		save_notice = save_store.last_error

func _encounter_active() -> bool:
	return run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING

func _save_checkpoint() -> void:
	_ensure_session_persistence()
	if not session_persistence.has_pending_save():
		return
	var snapshot: Dictionary = _capture_snapshot() if _encounter_active() else {}
	if persistence_enabled and not session_persistence.save(snapshot):
		save_notice = save_store.last_error

func _capture_snapshot() -> Dictionary:
	_ensure_runtime()
	var actors: Array = [_snapshot_actor("hero", "hero", get_node("Hero"), run_state.hero_health, BalanceData.HERO_HEALTH, ""), _snapshot_actor("machine", "machine", get_node("Machine"), run_state.machine_integrity, run_state.machine_max_integrity, "")]
	var projectiles: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var actor_id: String = _ensure_snapshot_id(enemy, "enemy")
		var kind: String = "ranged" if enemy is RangedEnemyScript else "pursuer" if enemy.enemy_kind == MeleeEnemyScript.EnemyKind.PURSUER else "breaker"
		var target_id: String = "hero" if kind != "breaker" else "machine"
		actors.append(_snapshot_actor(actor_id, kind, enemy, enemy.health, enemy.max_health, target_id))
		if kind == "ranged":
			for projectile in enemy.projectiles:
				if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
					continue
				var projectile_id: String = str(projectile.get_meta("snapshot_id", ""))
				if projectile_id.is_empty():
					projectile_id = _allocate_snapshot_id("projectile")
				projectile.set_meta("snapshot_id", projectile_id)
				var projectile_state: Dictionary = projectile.capture_snapshot_state()
				projectile_state["id"] = projectile_id
				projectile_state["kind"] = "hostile"
				projectile_state["owner_id"] = actor_id
				projectile_state["target_id"] = "hero"
				projectiles.append(projectile_state)
	for projectile in auto_weapon.projectiles:
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		var projectile_id: String = str(projectile.get_meta("snapshot_id", ""))
		if projectile_id.is_empty():
			projectile_id = _allocate_snapshot_id("projectile")
			projectile.set_meta("snapshot_id", projectile_id)
		var projectile_state: Dictionary = projectile.capture_snapshot_state()
		projectile_state["id"] = projectile_id
		projectile_state["kind"] = "friendly"
		projectile_state["owner_id"] = "hero"
		projectile_state["target_id"] = _ensure_snapshot_id(projectile.target, "enemy")
		projectiles.append(projectile_state)
	return {
		"run_state": {"run_id": run_state.run_id, "well_id": run_state.selected_well_id, "hero_id": run_state.selected_hero_id, "module_id": run_state.selected_module_id, "phase": run_state.phase, "paused": true, "simulation_elapsed": run_state.simulation_elapsed, "tank_base": run_state.tank_base, "extraction_rate": run_state.extraction_rate, "pressure_time_scale": run_state.pressure_time_scale, "completed_surges": run_state.completed_surges, "multiplier": run_state.multiplier, "locked_payout": run_state.locked_payout, "sealing_remaining": run_state.sealing_remaining, "sealing_duration": run_state.sealing_duration, "hero_health": run_state.hero_health, "machine_integrity": run_state.machine_integrity, "machine_max_integrity": run_state.machine_max_integrity, "terminal_reason": run_state.terminal_reason},
		"actors": actors,
		"projectiles": projectiles,
		"player_abilities": get_node("Hero").capture_snapshot_state(),
		"weapon_state": auto_weapon.capture_snapshot_state(),
		"spawner": {"spawn_timer": spawn_timer, "spawn_index": spawn_index, "spawn_position": _vector_array(_spawn_position(spawn_index)), "config_id": "%s-standard" % run_state.selected_well_id, "next_id": next_snapshot_id},
	}

func _snapshot_actor(actor_id: String, kind: String, actor: Node3D, health: float, max_health: float, target_id: String) -> Dictionary:
	var component_state: Dictionary = actor.capture_snapshot_state() if actor.has_method("capture_snapshot_state") else {}
	return {"id": actor_id, "kind": kind, "position": _vector_array(_world_position(actor)), "health": health, "max_health": max_health, "cooldown_remaining": actor.get("cooldown_remaining") if actor.get("cooldown_remaining") != null else 0.0, "windup_remaining": actor.get("windup_remaining") if actor.get("windup_remaining") != null else 0.0, "target_id": target_id, "dead": actor.get("dead") == true, "component_state": component_state}

func _world_position(actor: Node3D) -> Vector3:
	return actor.global_position if actor.is_inside_tree() else actor.position

func _ensure_snapshot_id(actor: Node, prefix: String) -> String:
	if actor.has_meta("snapshot_id"):
		return str(actor.get_meta("snapshot_id"))
	var actor_id: String = _allocate_snapshot_id(prefix)
	actor.set_meta("snapshot_id", actor_id)
	return actor_id

func _allocate_snapshot_id(_prefix: String = "actor") -> String:
	var actor_id: String = "entity-%d" % next_snapshot_id
	next_snapshot_id += 1
	return actor_id

func _vector_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _restore_saved_snapshot() -> void:
	if save_store.loaded_snapshot.is_empty():
		return
	_ensure_runtime()
	var decoded: Dictionary = SnapshotScript.decode(save_store.loaded_snapshot)
	if not decoded["valid"]:
		save_notice = "Save recovery: active encounter snapshot was rejected; banked progress was preserved."
		return
	var snapshot: Dictionary = decoded["snapshot"]
	var state: Dictionary = snapshot["run_state"]
	run_state.run_id = state["run_id"]
	run_state.selected_well_id = state["well_id"]
	run_state.selected_hero_id = state["hero_id"]
	run_state.selected_module_id = state["module_id"]
	for field in ["phase", "paused", "simulation_elapsed", "tank_base", "extraction_rate", "pressure_time_scale", "completed_surges", "multiplier", "locked_payout", "sealing_remaining", "sealing_duration", "hero_health", "machine_integrity", "machine_max_integrity", "terminal_reason"]:
		run_state.set(field, state[field])
	run_state.paused = true
	selected_well_id = state["well_id"]
	selected_loadout_id = state["module_id"]
	spawn_timer = snapshot["spawner"]["spawn_timer"]
	spawn_index = snapshot["spawner"]["spawn_index"]
	next_snapshot_id = snapshot["spawner"]["next_id"]
	var restored_next_snapshot_id: int = next_snapshot_id
	auto_weapon.restore_snapshot_state(snapshot["weapon_state"])
	run_state.machine_max_integrity = state["machine_max_integrity"]
	var hero = get_node("Hero")
	var machine = get_node("Machine")
	var enemy_parent := get_node_or_null("Enemies") as Node3D
	if enemy_parent == null:
		enemy_parent = Node3D.new()
		enemy_parent.name = "Enemies"
		add_child(enemy_parent)
	for actor in snapshot["actors"]:
		if actor["id"] == "hero":
			_set_world_position(hero, _vector_from_array(actor["position"]))
			hero.restore_snapshot_state(actor["component_state"])
		elif actor["id"] == "machine":
			_set_world_position(machine, _vector_from_array(actor["position"]))
		elif actor["kind"] == "ranged":
			_spawn_ranged_enemy(enemy_parent, _vector_from_array(actor["position"]), 1.0)
			var restored_ranged = enemies.back()
			restored_ranged.set_meta("snapshot_id", actor["id"])
			restored_ranged.health = actor["health"]
			restored_ranged.cooldown_remaining = actor["cooldown_remaining"]
			restored_ranged.windup_remaining = actor["windup_remaining"]
			restored_ranged.restore_snapshot_state(actor["component_state"])
		else:
			var kind: int = MeleeEnemyScript.EnemyKind.BREAKER if actor["kind"] == "breaker" else MeleeEnemyScript.EnemyKind.PURSUER
			_spawn_enemy(enemy_parent, kind, _vector_from_array(actor["position"]), machine if kind == MeleeEnemyScript.EnemyKind.BREAKER else hero, 1.0)
			var restored_enemy = enemies.back()
			restored_enemy.set_meta("snapshot_id", actor["id"])
			restored_enemy.health = actor["health"]
			restored_enemy.cooldown_remaining = actor["cooldown_remaining"]
			restored_enemy.restore_snapshot_state(actor["component_state"])
	for projectile_data in snapshot["projectiles"]:
		if projectile_data["kind"] == "friendly":
			var friendly_target: Node3D = _find_snapshot_actor(projectile_data["target_id"])
			if friendly_target == null:
				continue
			var restored_friendly = preload("res://scripts/game/projectile.gd").new()
			restored_friendly.owner_node = hero
			restored_friendly.target = friendly_target
			restored_friendly.restore_snapshot_state(projectile_data)
			restored_friendly.set_meta("snapshot_id", projectile_data["id"])
			auto_weapon.add_child(restored_friendly)
			auto_weapon.projectiles.append(restored_friendly)
		else:
			var hostile_owner: Node3D = _find_snapshot_actor(projectile_data["owner_id"])
			if hostile_owner == null or not hostile_owner is RangedEnemyScript:
				continue
			var restored_hostile = RangedProjectileScript.new()
			restored_hostile.run_state = run_state
			restored_hostile.target = hero
			restored_hostile.restore_snapshot_state(projectile_data)
			restored_hostile.set_meta("snapshot_id", projectile_data["id"])
			hostile_owner.add_child(restored_hostile)
			hostile_owner.projectile = restored_hostile
			hostile_owner.projectiles.append(restored_hostile)
	next_snapshot_id = restored_next_snapshot_id
	_apply_hero_visual(run_state.selected_hero_id)
	assignment_notice = "Encounter restored at the last checkpoint. Resume when ready."
	save_store.loaded_snapshot = {}

func _vector_from_array(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _set_world_position(actor: Node3D, value: Vector3) -> void:
	if actor.is_inside_tree():
		actor.global_position = value
	else:
		actor.position = value

func _find_snapshot_actor(actor_id: String) -> Node3D:
	if actor_id == "hero":
		return get_node("Hero")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get_meta("snapshot_id", "") == actor_id:
			return enemy
	return null

func _settle_offline_production(now_timestamp: float) -> bool:
	_ensure_session_persistence()
	if not save_store.writes_allowed:
		save_notice = save_store.last_error if not save_store.last_error.is_empty() else "Offline production is paused until the account save is recovered or reset."
		return false
	var saved_timestamp: float = save_store.loaded_production_utc_timestamp
	var snapshot_active_well: String = ""
	if not save_store.loaded_snapshot.is_empty():
		snapshot_active_well = save_store.loaded_snapshot.get("run_state", {}).get("well_id", "")
	var rates: Dictionary = ProductionScript.calculate_rates(account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, snapshot_active_well)
	var result: Dictionary = ProductionScript.offline_settlement(now_timestamp, saved_timestamp, rates)
	var total: float = result["total"]
	if total <= 0.0 and now_timestamp < saved_timestamp:
		production_utc_timestamp = saved_timestamp
		production.reset_cursor(session_persistence.now_monotonic())
		offline_return_notice = "Clock moved backward; offline production held at the later save time."
		return true
	var previous_timestamp: float = saved_timestamp
	account_state.bank += total
	if not session_persistence.save(save_store.loaded_snapshot):
		offline_pending_total = total
		offline_pending_utc_timestamp = now_timestamp
		production_utc_timestamp = previous_timestamp
		production.reset_cursor(previous_timestamp)
		save_notice = save_store.last_error
		return false
	production_utc_timestamp = now_timestamp
	production.reset_cursor(session_persistence.now_monotonic())
	offline_pending_total = 0.0
	offline_pending_utc_timestamp = 0.0
	if total > 0.0:
		offline_return_notice = "Welcome back: %.2f mana earned while away." % total
	else:
		offline_return_notice = "Welcome back: no offline mana accrued."
	return true

func retry_offline_settlement() -> bool:
	_ensure_session_persistence()
	if not session_persistence.has_pending_save():
		return true
	if not save_store.writes_allowed:
		save_notice = save_store.last_error if not save_store.last_error.is_empty() else "Save is protected until the rejected account is recovered or reset."
		return false
	if not session_persistence.retry_pending_save():
		save_notice = save_store.last_error
		return false
	production_utc_timestamp = offline_pending_utc_timestamp
	production.reset_cursor(session_persistence.now_monotonic())
	offline_return_notice = "Welcome back: %.2f mana earned while away." % offline_pending_total
	offline_pending_total = 0.0
	offline_pending_utc_timestamp = 0.0
	save_notice = ""
	return true

func retry_pending_save() -> bool:
	_ensure_session_persistence()
	if not session_persistence.has_pending_save():
		return true
	if not session_persistence.retry_pending_save():
		save_notice = save_store.last_error
		return false
	save_notice = ""
	return true

func notice_state() -> Dictionary:
	return {
		"save_failure": save_notice,
		"offline": offline_return_notice,
		"assignment": assignment_notice,
		"pending_save": session_persistence != null and session_persistence.has_pending_save(),
		"offline_pending_total": offline_pending_total,
		"developer_mode": developer_mode,
		"run_active": _encounter_active(),
	}

func _production_now() -> float:
	if production_time_override >= 0.0:
		return production_time_override
	return Time.get_ticks_msec() / 1000.0

func _offline_now() -> float:
	if production_time_override >= 0.0:
		return production_time_override
	return Time.get_unix_time_from_system()

func _settle_production() -> void:
	_ensure_session_persistence()
	if offline_pending_total > 0.0:
		return
	var active_well_id: String = ""
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		active_well_id = run_state.selected_well_id
	var result: Dictionary = production.settle(session_persistence.now_monotonic(), account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, active_well_id)
	monotonic_settlement_cursor = production.settlement_cursor
	displayed_rates = result["rates"]
	if result["total"] > 0.0:
		account_state.bank += result["total"]
		session_persistence.mark_dirty()

func _hero_name(hero_id: String) -> String:
	return "Hero 1" if hero_id == "hero_1" else "Hero 2"

func _well_name(well_id: String) -> String:
	return "Well 1" if well_id == "well_1" else "Well 2"

func _apply_hero_visual(hero_id: String) -> void:
	var hero_mesh := get_node("Hero/Mesh") as MeshInstance3D
	hero_mesh.visible = hero_id == "hero_2"
	get_node("Hero/MechaVisual").visible = hero_id != "hero_2"
	var material := StandardMaterial3D.new()
	if hero_id == "hero_2":
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 1.8, 1.0)
		hero_mesh.mesh = box
		material.albedo_color = Color(0.1, 0.55, 0.95, 1.0)
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.5
		capsule.height = 1.8
		hero_mesh.mesh = capsule
		material.albedo_color = Color(0.85, 0.1, 0.12, 1.0)
	material.roughness = 0.7
	hero_mesh.material_override = material

func _advance_spawning(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	spawn_timer += delta
	var interval := _spawn_interval()
	while spawn_timer + FIXED_STEP_EPSILON >= interval:
		spawn_timer -= interval
		spawn_timer = maxf(0.0, spawn_timer)
		_spawn_next_enemy()
		interval = _spawn_interval()

func _spawn_interval() -> float:
	var tier: int = run_state.completed_surges
	var interval: float = float(content_catalog.spawn_rule_for_tier(tier).get("spawn_interval", 3.0))
	if tier >= 4:
		interval = maxf(0.4, 1.5 * pow(0.9, tier - 4))
	interval *= float(content_catalog.get_well(run_state.selected_well_id).get("spawn_interval_factor", 1.0))
	return interval

func _spawn_next_enemy() -> void:
	_prune_enemies()
	if enemies.size() >= BalanceData.LIVE_ENEMY_LIMIT:
		spawn_index += 1
		return
	var enemy_parent := get_node_or_null("Enemies") as Node3D
	if enemy_parent == null:
		enemy_parent = Node3D.new()
		enemy_parent.name = "Enemies"
		add_child(enemy_parent)
	var kind: int = _next_enemy_kind()
	var spawn_position := _spawn_position(spawn_index)
	var damage_multiplier := _enemy_damage_multiplier()
	if kind == RANGED_KIND:
		_spawn_ranged_enemy(enemy_parent, spawn_position, damage_multiplier)
	else:
		_spawn_enemy(enemy_parent, kind, spawn_position, get_node("Machine") if kind == MeleeEnemyScript.EnemyKind.BREAKER else get_node("Hero"), damage_multiplier)
	spawn_index += 1

func _next_enemy_kind() -> int:
	var tier: int = run_state.completed_surges
	var rule: Dictionary = content_catalog.spawn_rule_for_tier(tier)
	if tier <= 0:
		return MeleeEnemyScript.EnemyKind.PURSUER
	if int(rule.get("ranged_cycle", -1)) >= 0 and spawn_index % 4 == int(rule["ranged_cycle"]):
		return RANGED_KIND
	if int(rule.get("breaker_cycle", -1)) >= 0 and spawn_index % 4 == int(rule["breaker_cycle"]):
		return MeleeEnemyScript.EnemyKind.BREAKER
	return MeleeEnemyScript.EnemyKind.PURSUER

func _spawn_position(index: int) -> Vector3:
	var points := [Vector3(-10.0, 0.8, -10.0), Vector3(10.0, 0.8, -10.0), Vector3(-10.0, 0.8, 10.0), Vector3(10.0, 0.8, 10.0), Vector3(0.0, 0.8, -10.0), Vector3(0.0, 0.8, 10.0)]
	return points[index % points.size()]

func _enemy_damage_multiplier() -> float:
	var multiplier := 1.0 + 0.15 * maxf(0.0, run_state.completed_surges - 4)
	multiplier *= float(content_catalog.get_well(run_state.selected_well_id).get("enemy_damage_factor", 1.0))
	return multiplier

func _spawn_enemy(parent: Node3D, kind: int, spawn_position: Vector3, target: Node3D, damage_multiplier: float) -> void:
	var enemy = MeleeEnemyScript.new()
	enemy.position = spawn_position
	enemy.setup(kind, run_state, target, damage_multiplier)
	enemy.set_meta("snapshot_id", _allocate_snapshot_id("actor"))
	parent.add_child(enemy)
	enemies.append(enemy)

func _spawn_ranged_enemy(parent: Node3D, spawn_position: Vector3, damage_multiplier: float) -> void:
	var enemy = RangedEnemyScript.new()
	enemy.position = spawn_position
	enemy.setup(run_state, get_node("Hero"), damage_multiplier)
	enemy.set_id_allocator(Callable(self, "_allocate_snapshot_id").bind("projectile"))
	enemy.set_meta("snapshot_id", _allocate_snapshot_id("actor"))
	parent.add_child(enemy)
	enemies.append(enemy)

func _prune_enemies() -> void:
	var live_enemies: Array[Node3D] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.get("dead"):
			live_enemies.append(enemy)
	enemies = live_enemies

func _clear_enemies() -> void:
	if auto_weapon != null:
		auto_weapon.clear_projectiles()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.free()
	enemies.clear()
	var existing_parent := get_node_or_null("Enemies")
	if existing_parent != null:
		existing_parent.free()
	spawn_timer = 0.0
	spawn_index = 0

func _credit_if_complete() -> void:
	var result: Dictionary = run_state.get_terminal_result()
	if not account_state.complete_run(result, run_state.run_id, run_state.selected_well_id, run_state.completed_surges):
		return
	_save_account()

func purchase_upgrade(upgrade_id: String) -> bool:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		return false
	_settle_production()
	var purchased: bool = account_state.purchase_upgrade(upgrade_id)
	if purchased:
		_save_account()
	if purchased and upgrade_id == "pump_1":
		_show_pump_visual()
	_update_hud()
	return purchased

func purchase_damage_upgrade() -> void:
	purchase_upgrade("damage_1")

func purchase_pump_upgrade() -> void:
	purchase_upgrade("pump_1")

func purchase_spread_upgrade() -> void:
	purchase_upgrade("spread_1")

func clear_saved_progress() -> void:
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		assignment_notice = "Finish or abandon the active run before clearing saved progress."
		_update_hud()
		return
	if not save_store.clear_save():
		save_notice = save_store.last_error
		_update_hud()
		return
	account_state = AccountStateScript.new()
	_ensure_session_persistence()
	session_persistence.account = account_state
	session_persistence.reset_after_clear()
	selected_well_id = "well_1"
	production.reset_cursor(session_persistence.now_monotonic())
	displayed_rates.clear()
	assignment_notice = "Saved progress cleared. Well 1 and Hero 1 restored."
	run_state.reset()
	_clear_enemies()
	if auto_weapon != null:
		auto_weapon.clear_projectiles()
	_apply_hero_visual("hero_1")
	_update_hud()

func _build_hud() -> void:
	encounter_hud.build(self)
	return
	var layer := CanvasLayer.new()
	layer.name = "EncounterHUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(390, 650)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(360, 0)
	scroll.add_child(content)
	var status_section := _add_collapsible_section(content, "RUN STATUS", true)
	phase_label = _add_label(status_section, "PHASE: READY", 24)
	bank_label = _add_label(status_section, "Bank: 0", 18)
	tank_label = _add_label(status_section, "Tank payout: 0", 18)
	tier_label = _add_label(status_section, "Completed tier: 0", 18)
	surge_label = _add_label(status_section, "Next surge: 20.0s", 18)
	threat_label = _add_label(status_section, "Upcoming threat: pursuer", 18)
	sealing_label = _add_label(status_section, "Sealing: --", 18)
	dash_label = _add_label(status_section, "Dash [Space]: ready", 16)
	pulse_label = _add_label(status_section, "Pulse [Q]: ready", 16)
	reason_label = _add_label(status_section, "Reason: --", 18)
	instruction_label = _add_label(status_section, "WASD move | E start/harvest | Space dash | Q pulse | Escape pause", 14)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var preparation_section := _add_collapsible_section(content, "PREPARATION", true)
	preparation_label = _add_label(preparation_section, "Preparation", 18)
	well_selector = OptionButton.new()
	well_selector.item_selected.connect(_on_well_index_selected)
	preparation_section.add_child(well_selector)
	_add_label(preparation_section, "Well output and threat summary", 14)
	loadout_selector = OptionButton.new()
	loadout_selector.item_selected.connect(_on_loadout_index_selected)
	preparation_section.add_child(loadout_selector)
	loadout_label = _add_label(preparation_section, "Standard: baseline active output and machine integrity. Passive rates unchanged.", 14)
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_label(preparation_section, "Loadout applies to active runs only; passive network rates do not change.", 14)
	active_hero_selector = OptionButton.new()
	active_hero_selector.item_selected.connect(_on_active_hero_index_selected)
	preparation_section.add_child(active_hero_selector)
	guard_hero_selector = OptionButton.new()
	preparation_section.add_child(guard_hero_selector)
	assign_guard_button = Button.new()
	assign_guard_button.text = "Assign selected hero as guard"
	assign_guard_button.pressed.connect(_on_assign_selected_guard)
	preparation_section.add_child(assign_guard_button)
	recall_guard_button = Button.new()
	recall_guard_button.text = "Recall site guard"
	recall_guard_button.pressed.connect(_on_recall_selected_guard)
	preparation_section.add_child(recall_guard_button)
	assignment_label = _add_label(preparation_section, "Assignments", 14)
	network_section = _add_collapsible_section(content, "NETWORK", false)
	network_label = _add_label(network_section, "No commissioned production sites.", 16)
	network_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_offline_button = Button.new()
	retry_offline_button.text = "Retry offline settlement"
	retry_offline_button.pressed.connect(retry_offline_settlement)
	network_section.add_child(retry_offline_button)
	var actions_section := _add_collapsible_section(content, "ENCOUNTER ACTIONS", true)
	_add_label(actions_section, "Hero health", 16)
	hero_bar = _add_bar(actions_section, BalanceData.HERO_HEALTH)
	_add_label(actions_section, "Machine integrity", 16)
	machine_bar = _add_bar(actions_section, BalanceData.MACHINE_INTEGRITY)
	action_button = Button.new()
	action_button.text = "Start extraction (E)"
	action_button.pressed.connect(request_start_or_harvest)
	actions_section.add_child(action_button)
	retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.pressed.connect(retry)
	actions_section.add_child(retry_button)
	abandon_button = Button.new()
	abandon_button.text = "Abandon run"
	abandon_button.pressed.connect(abandon)
	actions_section.add_child(abandon_button)
	pause_button = Button.new()
	pause_button.text = "Pause (Escape)"
	pause_button.pressed.connect(toggle_pause)
	actions_section.add_child(pause_button)
	status_label = _add_label(actions_section, "Protect the current tank. Harvest begins a sealing defense.", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrades_section = _add_collapsible_section(content, "UPGRADES", false)
	damage_upgrade_button = Button.new()
	damage_upgrade_button.pressed.connect(encounter_hud.request_upgrade.bind("damage_1"))
	upgrades_section.add_child(damage_upgrade_button)
	pump_upgrade_button = Button.new()
	pump_upgrade_button.pressed.connect(encounter_hud.request_upgrade.bind("pump_1"))
	upgrades_section.add_child(pump_upgrade_button)
	spread_upgrade_button = Button.new()
	spread_upgrade_button.pressed.connect(encounter_hud.request_upgrade.bind("spread_1"))
	upgrades_section.add_child(spread_upgrade_button)
	if developer_mode:
		developer_section = _add_collapsible_section(content, "DEVELOPER", false)
		developer_setting_button = Button.new()
		developer_setting_button.pressed.connect(_toggle_sealing_setting)
		developer_section.add_child(developer_setting_button)
		var hero_damage_button := Button.new()
		hero_damage_button.text = "DEV: damage hero 25"
		hero_damage_button.pressed.connect(damage_hero)
		developer_section.add_child(hero_damage_button)
		var machine_damage_button := Button.new()
		machine_damage_button.text = "DEV: damage machine 25"
		machine_damage_button.pressed.connect(damage_machine)
		developer_section.add_child(machine_damage_button)
	account_section = _add_collapsible_section(content, "ACCOUNT", false)
	clear_save_button = Button.new()
	clear_save_button.text = "Clear saved progress"
	clear_save_button.pressed.connect(clear_saved_progress)
	account_section.add_child(clear_save_button)

func _add_collapsible_section(parent: VBoxContainer, title: String, expanded: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	var header := Button.new()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.text = ("[-] " if expanded else "[+] ") + title
	section.add_child(header)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	section.add_child(body)
	body.visible = expanded
	header.pressed.connect(_toggle_section.bind(body, header, title))
	return body

func _toggle_section(body: VBoxContainer, header: Button, title: String) -> void:
	body.visible = not body.visible
	header.text = ("[-] " if body.visible else "[+] ") + title

func _add_label(parent: Container, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _add_bar(parent: Container, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = maximum
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(0, 24)
	parent.add_child(bar)
	return bar

func _update_hud() -> void:
	if encounter_hud == null:
		return
	var ability_hero = get_node("Hero")
	var ability_state := {"dash_cooldown_remaining": ability_hero.dash_cooldown_remaining, "pulse_cooldown_remaining": ability_hero.pulse_cooldown_remaining}
	var notices := notice_state()
	var recovery_message: Variant = save_store.get("recovery_message")
	notices["recovery"] = "" if recovery_message == null else str(recovery_message)
	status_label.text = _status_text()
	reason_label.text = _feedback_text()
	encounter_hud.set_view_state(UiViewStateScript.build(account_state, run_state, selected_well_id, notices, ability_state))
	return
	phase_label.text = "PHASE: %s%s" % [_phase_name(), " (PAUSED)" if run_state.paused else ""]
	phase_label.modulate = Color(0.55, 0.9, 1.0, 1.0)
	if run_state.phase == RunStateScript.Phase.SEALING:
		phase_label.modulate = Color(1.0, 0.75, 0.2, 1.0)
	elif run_state.phase == RunStateScript.Phase.SUCCESS:
		phase_label.modulate = Color(0.3, 1.0, 0.45, 1.0)
	elif run_state.phase == RunStateScript.Phase.FAILED:
		phase_label.modulate = Color(1.0, 0.25, 0.25, 1.0)
	bank_label.text = "Banked mana: %.2f" % account_state.bank
	_update_network_panel()
	_update_well_selector()
	_update_assignment_controls()
	tank_label.text = "Current tank: %d" % _current_payout()
	tier_label.text = "Completed tier: %d (x%.2f)" % [run_state.completed_surges, run_state.multiplier]
	var next_surge: float = BalanceData.SURGE_DURATION - fmod(run_state.simulation_elapsed, BalanceData.SURGE_DURATION)
	if run_state.phase != RunStateScript.Phase.EXTRACTING:
		next_surge = 0.0
	surge_label.text = "Next surge: %.1fs" % next_surge
	threat_label.text = "Upcoming threat: %s" % _upcoming_threat()
	sealing_label.text = "Sealing: %.1fs remaining" % run_state.sealing_remaining if run_state.phase == RunStateScript.Phase.SEALING else "Sealing: --"
	var hero = get_node("Hero")
	dash_label.text = "Dash [Space]: %.1fs" % hero.dash_cooldown_remaining if hero.dash_cooldown_remaining > 0.0 else "Dash [Space]: ready"
	pulse_label.text = "Pulse [Q]: %.1fs" % hero.pulse_cooldown_remaining if hero.pulse_cooldown_remaining > 0.0 else "Pulse [Q]: ready"
	reason_label.text = _feedback_text()
	hero_bar.value = run_state.hero_health
	machine_bar.max_value = run_state.machine_max_integrity if run_state.machine_max_integrity > 0.0 else BalanceData.MACHINE_INTEGRITY
	machine_bar.value = run_state.machine_integrity
	action_button.text = "Start extraction (E)" if run_state.phase == RunStateScript.Phase.READY else "Harvest (E)" if run_state.phase == RunStateScript.Phase.EXTRACTING else "Harvest unavailable"
	action_button.disabled = run_state.phase != RunStateScript.Phase.READY and run_state.phase != RunStateScript.Phase.EXTRACTING
	retry_button.disabled = run_state.phase != RunStateScript.Phase.SUCCESS and run_state.phase != RunStateScript.Phase.FAILED
	abandon_button.disabled = run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING
	pause_button.disabled = run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING
	pause_button.text = "Resume (Escape)" if run_state.paused else "Pause (Escape)"
	status_label.text = save_notice if not save_notice.is_empty() else offline_return_notice if not offline_return_notice.is_empty() else assignment_notice if not assignment_notice.is_empty() else _status_text()
	damage_upgrade_button.text = _upgrade_text("damage_1", "Damage +5", BalanceData.DAMAGE_UPGRADE_COST)
	pump_upgrade_button.text = _upgrade_text("pump_1", "Pump +25% output", BalanceData.PUMP_UPGRADE_COST)
	spread_upgrade_button.text = _upgrade_text("spread_1", "Spread: three shots", BalanceData.SPREAD_UPGRADE_COST)
	var can_purchase: bool = run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING
	damage_upgrade_button.disabled = not can_purchase or account_state.has_upgrade("damage_1") or account_state.bank < BalanceData.DAMAGE_UPGRADE_COST
	pump_upgrade_button.disabled = not can_purchase or account_state.has_upgrade("pump_1") or account_state.bank < BalanceData.PUMP_UPGRADE_COST
	spread_upgrade_button.disabled = not can_purchase or account_state.has_upgrade("spread_1") or account_state.bank < BalanceData.SPREAD_UPGRADE_COST
	if developer_setting_button != null:
		developer_setting_button.text = "DEV sealing: %.0fs (toggle 0/2)" % sealing_duration_setting
	if clear_save_button != null:
		clear_save_button.disabled = run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING
	if retry_offline_button != null:
		retry_offline_button.visible = offline_pending_total > 0.0
		retry_offline_button.disabled = not retry_offline_button.visible
	if account_state.has_upgrade("pump_1") and pump_visual == null:
		_show_pump_visual()
	if encounter_hud != null:
		encounter_hud.set_view_state({
			"phase": run_state.phase,
			"paused": run_state.paused,
			"hero_health": run_state.hero_health,
			"machine_integrity": run_state.machine_integrity,
			"machine_max_integrity": run_state.machine_max_integrity,
			"bank": account_state.bank,
			"selected_well_id": selected_well_id,
			"selected_loadout_id": selected_loadout_id,
			"active_hero_id": account_state.get_active_hero_id(),
			"guard_id": account_state.get_guard_for_well(selected_well_id),
		})

func _upgrade_text(upgrade_id: String, effect: String, cost: int) -> String:
	if account_state.has_upgrade(upgrade_id):
		return "%s: OWNED" % effect
	return "%s: %d mana" % [effect, cost]

func _update_network_panel() -> void:
	if network_label == null:
		return
	var active_well_id: String = ""
	if run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING:
		active_well_id = run_state.selected_well_id
	displayed_rates = ProductionScript.calculate_rates(account_state.commissioned_wells, account_state.hero_assignments, account_state.owned_upgrades, active_well_id)
	var lines: Array[String] = []
	var total_rate: float = 0.0
	for well_id in ["well_1", "well_2"]:
		if not account_state.is_well_commissioned(well_id):
			lines.append("%s: not commissioned" % _well_name(well_id))
			continue
		var guard_id: String = account_state.get_guard_for_well(well_id)
		var rate: float = float(displayed_rates.get(well_id, 0.0))
		if guard_id.is_empty():
			lines.append("%s: commissioned | guard none | 0.00 mana/min" % _well_name(well_id))
		else:
			lines.append("%s: commissioned | guard %s | %.2f mana/min" % [_well_name(well_id), _hero_name(guard_id), rate * 60.0])
			total_rate += rate
	lines.append("Total network: %.2f mana/min" % (total_rate * 60.0))
	network_label.text = "\n".join(lines)

func _show_pump_visual() -> void:
	if pump_visual != null:
		return
	pump_visual = MeshInstance3D.new()
	pump_visual.name = "PumpResearch"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.35, 1.2)
	pump_visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.85, 0.95, 1)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.5, 0.65, 1)
	pump_visual.material_override = material
	pump_visual.position = Vector3(0.0, 0.9, 0.0)
	get_node("Machine").add_child(pump_visual)

func _toggle_sealing_setting() -> void:
	sealing_duration_setting = 0.0 if is_equal_approx(sealing_duration_setting, BalanceData.SEALING_DURATION) else BalanceData.SEALING_DURATION
	_update_hud()

func _status_text() -> String:
	if run_state.phase == RunStateScript.Phase.READY:
		return "Move with WASD. Start with E. The tank is lost if the hero or machine falls."
	if run_state.phase == RunStateScript.Phase.EXTRACTING:
		return "TANK AT RISK: harvest locks the payout, then enemies can still interrupt sealing."
	if run_state.phase == RunStateScript.Phase.SEALING:
		return "SEALING DANGER: payout is locked, but defend until the timer reaches zero."
	if run_state.phase == RunStateScript.Phase.SUCCESS:
		return "BANKED: the locked payout is safe and has been added to your bank."
	return "FAILED: the current tank was lost. Retry starts a fresh extraction."

func _feedback_text() -> String:
	if run_state.phase == RunStateScript.Phase.SUCCESS:
		return "SUCCESS: banked %d mana" % run_state.locked_payout
	if run_state.phase == RunStateScript.Phase.FAILED:
		if run_state.terminal_reason == "abandoned":
			return "FAILED: run abandoned; current tank lost"
		if run_state.terminal_reason == "hero_destroyed":
			return "FAILED: hero destroyed; current tank lost"
		if run_state.terminal_reason == "machine_destroyed":
			return "FAILED: machine destroyed; current tank lost"
		return "FAILED: encounter ended; current tank lost"
	if run_state.phase == RunStateScript.Phase.SEALING:
		return "Payout locked at %d; sealing is not safe yet" % run_state.locked_payout
	return "Reason: --"

func _current_payout() -> int:
	if run_state.phase == RunStateScript.Phase.SEALING or run_state.phase == RunStateScript.Phase.SUCCESS:
		return run_state.locked_payout
	return floori(run_state.tank_base * run_state.multiplier)

func _upcoming_threat() -> String:
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		return "pursuer"
	var upcoming_index: int = spawn_index
	var tier: int = run_state.completed_surges
	if tier <= 0:
		return "pursuer"
	if tier == 1 and upcoming_index % 4 == 3:
		return "breaker"
	if tier >= 2:
		var cycle: int = upcoming_index % 4
		if cycle == 2:
			return "breaker"
		if cycle == 3:
			return "ranged"
	return "pursuer"

func _phase_name() -> String:
	return RunStateScript.Phase.keys()[run_state.phase]
