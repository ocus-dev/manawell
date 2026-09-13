extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")

const LIVE_PATH: String = "user://test_loadouts_save.json"
const TEMP_PATH: String = "user://test_loadouts_save.tmp"
const BACKUP_PATH: String = "user://test_loadouts_save.bak"

func _init() -> void:
	_cleanup()
	_test_availability_and_persistence()
	_test_run_modifiers_and_boundaries()
	_test_controller_switch_lock_and_snapshot()
	_cleanup()
	quit(0)

func _test_availability_and_persistence() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.commissioned_wells["well_1"] = true
	assert(not account.select_loadout("well_1", LoadoutScript.OVERDRIVE))
	account.commissioned_wells["well_2"] = true
	assert(account.select_loadout("well_1", LoadoutScript.OVERDRIVE))
	assert(account.select_loadout("well_2", LoadoutScript.FORTIFIED))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account))
	var restarted: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(restarted.get_loadout_for_well("well_1") == LoadoutScript.OVERDRIVE)
	assert(restarted.get_loadout_for_well("well_2") == LoadoutScript.FORTIFIED)

func _test_run_modifiers_and_boundaries() -> void:
	var overdrive: RefCounted = RunStateScript.new()
	assert(overdrive.start("overdrive", "well_2", "hero_1", LoadoutScript.OVERDRIVE, BalanceData.WELL_2_BASE_OUTPUT * 1.25, BalanceData.SEALING_DURATION, BalanceData.HERO_HEALTH, BalanceData.MACHINE_INTEGRITY, 1.25))
	overdrive.advance(16.0)
	assert(is_equal_approx(overdrive.tank_base, BalanceData.WELL_2_BASE_OUTPUT * 1.25 * 16.0))
	assert(overdrive.completed_surges == 1)
	var standard: RefCounted = RunStateScript.new()
	assert(standard.start("standard", "well_2", "hero_1", LoadoutScript.STANDARD, BalanceData.WELL_2_BASE_OUTPUT, BalanceData.SEALING_DURATION))
	standard.advance(16.0)
	assert(standard.completed_surges == 0)
	var fortified: RefCounted = RunStateScript.new()
	assert(fortified.start("fortified", "well_2", "hero_1", LoadoutScript.FORTIFIED, BalanceData.WELL_2_BASE_OUTPUT, BalanceData.SEALING_DURATION, BalanceData.HERO_HEALTH, BalanceData.MACHINE_INTEGRITY * 1.5))
	assert(is_equal_approx(fortified.machine_integrity, BalanceData.MACHINE_INTEGRITY * 1.5))
	assert(is_equal_approx(fortified.extraction_rate, BalanceData.WELL_2_BASE_OUTPUT))
	assert(is_equal_approx(fortified.pressure_time_scale, 1.0))

func _test_controller_switch_lock_and_snapshot() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.commissioned_wells = {"well_1": true, "well_2": true}
	controller.account_state.unlocked_wells["well_2"] = true
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	controller.account_state.owned_upgrades["pump_1"] = true
	assert(controller.account_state.select_loadout("well_1", LoadoutScript.OVERDRIVE))
	controller.selected_loadout_id = LoadoutScript.OVERDRIVE
	controller.request_start_or_harvest()
	assert(controller.run_state.selected_module_id == LoadoutScript.OVERDRIVE)
	assert(is_equal_approx(controller.run_state.extraction_rate, BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER * 1.25))
	var rate_before: float = controller.run_state.extraction_rate
	controller.select_loadout(2)
	assert(controller.run_state.selected_module_id == LoadoutScript.OVERDRIVE)
	assert(is_equal_approx(controller.run_state.extraction_rate, rate_before))
	var snapshot: Dictionary = controller._capture_snapshot()
	assert(snapshot["run_state"]["module_id"] == LoadoutScript.OVERDRIVE)
	assert(is_equal_approx(snapshot["run_state"]["pressure_time_scale"], 1.25))
	assert(is_equal_approx(snapshot["run_state"]["machine_max_integrity"], BalanceData.MACHINE_INTEGRITY))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(controller.account_state, 100.0, snapshot))
	var restarted: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var reloaded_account: RefCounted = restarted.load_account()
	assert(reloaded_account.get_loadout_for_well("well_1") == LoadoutScript.OVERDRIVE)
	assert(is_equal_approx(restarted.loaded_snapshot["run_state"]["extraction_rate"], rate_before))
	assert(is_equal_approx(restarted.loaded_snapshot["run_state"]["pressure_time_scale"], 1.25))
	assert(SnapshotScript.decode(SnapshotScript.encode(snapshot)["payload"])["valid"])
	controller.free()

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
