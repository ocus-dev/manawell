extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const SessionPersistenceScript = preload("res://scripts/model/session_persistence.gd")

const LIVE_PATH: String = "user://test_session_boundary.json"
const TEMP_PATH: String = "user://test_session_boundary.tmp"
const BACKUP_PATH: String = "user://test_session_boundary.bak"

var monotonic_value: float = 110.0
var utc_value: float = 1000000000000.0
var startup_controller: Node

func _init() -> void:
	_cleanup()
	_test_distinct_clocks_and_purchase_reload()
	_test_injected_startup_uses_fixture()
	call_deferred("_finish_startup_test")

func _test_distinct_clocks_and_purchase_reload() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.bank = 100.0
	account.commissioned_wells = {"well_1": true}
	account.roster_heroes["hero_2"] = true
	account.hero_assignments = {
		"hero_1": {"role": "active", "well_id": ""},
		"hero_2": {"role": "guard", "well_id": "well_1"},
	}
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account, utc_value))
	var controller: Node = ControllerScript.new()
	controller.persistence_enabled = true
	controller.account_state = account
	controller.configure_persistence(store, Callable(self, "_monotonic_now"), Callable(self, "_utc_now"))
	controller.production.reset_cursor(100.0)
	controller._settle_production()
	assert(is_equal_approx(controller.account_state.bank, 105.0))
	var purchased: bool = controller.purchase_upgrade("damage_1")
	assert(purchased)
	var reloaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var reloaded: RefCounted = reloaded_store.load_account()
	assert(is_equal_approx(reloaded.bank, 65.0))
	assert(reloaded.has_upgrade("damage_1"))
	assert(reloaded_store.loaded_production_utc_timestamp == utc_value)
	controller.free()

func _test_injected_startup_uses_fixture() -> void:
	_cleanup()
	var account: RefCounted = AccountStateScript.new()
	account.bank = 17.0
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account, utc_value))
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = true
	controller.configure_persistence(store, Callable(self, "_monotonic_now"), Callable(self, "_utc_now"))
	get_root().add_child(controller)
	startup_controller = controller

func _finish_startup_test() -> void:
	assert(startup_controller.account_state.bank == 17.0)
	assert(startup_controller.save_store.loaded_production_utc_timestamp == utc_value)
	startup_controller.free()
	_cleanup()
	quit(0)

func _monotonic_now() -> float:
	return monotonic_value

func _utc_now() -> float:
	return utc_value

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, LIVE_PATH + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
