extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const ProductionScript = preload("res://scripts/model/production.gd")

const LIVE_PATH: String = "user://test_offline_save.json"
const TEMP_PATH: String = "user://test_offline_save.tmp"
const BACKUP_PATH: String = "user://test_offline_save.bak"

func _init() -> void:
	_cleanup()
	_test_offline_model_and_reload()
	_test_clock_and_guard_edges()
	_test_save_failure_retry()
	_cleanup()
	quit(0)

func _test_offline_model_and_reload() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.commissioned_wells = {"well_1": true}
	account.roster_heroes["hero_2"] = true
	account.hero_assignments = {
		"hero_1": {"role": "active", "well_id": ""},
		"hero_2": {"role": "guard", "well_id": "well_1"},
	}
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account, 1000.0))
	var loaded: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var restarted: RefCounted = loaded.load_account()
	var rates: Dictionary = preload("res://scripts/model/production.gd").calculate_rates(restarted.commissioned_wells, restarted.hero_assignments, restarted.owned_upgrades)
	var offline: Dictionary = preload("res://scripts/model/production.gd").offline_settlement(4600.0, loaded.loaded_production_timestamp, rates)
	restarted.bank += offline["total"]
	assert(is_equal_approx(restarted.bank, 1800.0))
	assert(loaded.save_account(restarted, 4600.0))
	var repeated_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var repeated: RefCounted = repeated_store.load_account()
	var repeated_rates: Dictionary = preload("res://scripts/model/production.gd").calculate_rates(repeated.commissioned_wells, repeated.hero_assignments, repeated.owned_upgrades)
	assert(ProductionScript.offline_settlement(4600.0, repeated_store.loaded_production_timestamp, repeated_rates)["total"] == 0.0)

func _test_clock_and_guard_edges() -> void:
	assert(ProductionScript.offline_elapsed(90000.0, 0.0) == 86400.0)
	assert(ProductionScript.offline_elapsed(40.0, 100.0) == 0.0)
	var no_guards: Dictionary = ProductionScript.calculate_rates({"well_1": true}, {}, {})
	assert(no_guards.is_empty())
	var two_guards: Dictionary = ProductionScript.calculate_rates({"well_1": true, "well_2": true}, {
		"hero_1": {"role": "guard", "well_id": "well_1"},
		"hero_2": {"role": "guard", "well_id": "well_2"},
	}, {})
	assert(is_equal_approx(ProductionScript.total_for_elapsed(3600.0, two_guards), 5040.0))

func _test_save_failure_retry() -> void:
	var controller: Node = ControllerScript.new()
	controller.persistence_enabled = true
	controller.account_state.commissioned_wells["well_1"] = true
	controller.account_state.hero_assignments["hero_1"] = {"role": "guard", "well_id": "well_1"}
	controller.save_store = SaveStoreScript.new("user://missing_offline_dir/save.json", "user://missing_offline_dir/save.tmp", "user://missing_offline_dir/save.bak")
	controller.save_store.loaded_production_timestamp = 100.0
	assert(not controller._settle_offline_production(3700.0))
	assert(controller.offline_pending_total > 0.0)
	var credited_bank: float = controller.account_state.bank
	assert(credited_bank > 0.0)
	controller.save_store = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(controller.retry_offline_settlement())
	assert(controller.offline_pending_total == 0.0)
	var reloaded: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(is_equal_approx(reloaded.bank, credited_bank))
	controller.free()

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)