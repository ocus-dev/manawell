extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")

const LIVE_PATH: String = "user://test_account_save.json"
const TEMP_PATH: String = "user://test_account_save.tmp"
const BACKUP_PATH: String = "user://test_account_save.bak"
const RECOVERY_PATH: String = "user://test_account_save.json.recovery"

func _init() -> void:
	_cleanup()
	_test_round_trip()
	_test_validation_and_recovery()
	_test_temp_file_is_not_loaded()
	_test_load_outcomes_and_protected_recovery()
	_test_failed_file_operations_preserve_commit()
	_test_unsupported_startup_is_protected()
	_test_clear_save()
	_cleanup()
	quit(0)

func _test_round_trip() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.bank = 137
	account.credited_run_ids["run-1"] = true
	account.owned_upgrades["damage_1"] = true
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account))
	var loaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var loaded: RefCounted = loaded_store.load_account()
	assert(loaded_store.last_error.is_empty())
	assert(loaded.bank == 137)
	assert(loaded.has_upgrade("damage_1"))
	assert(loaded.credited_run_ids.has("run-1"))
	assert(loaded_store.save_account(loaded))
	var restarted: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(restarted.bank == 137)

func _test_validation_and_recovery() -> void:
	_write_text(LIVE_PATH, "not json")
	_write_text(BACKUP_PATH, JSON.stringify({"version": 1, "account": {"bank": 42, "credited_run_ids": [], "owned_upgrades": ["pump_1"]}}))
	var recovered_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var recovered: RefCounted = recovered_store.load_account()
	assert(recovered.bank == 42)
	assert(recovered.has_upgrade("pump_1"))
	assert(recovered_store.recovery_message.contains("last-good backup"))
	assert(FileAccess.file_exists(LIVE_PATH))

	_write_text(LIVE_PATH, JSON.stringify({"version": 1, "account": {"bank": -1, "credited_run_ids": [], "owned_upgrades": []}}))
	var invalid_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, "user://missing_backup.json")
	var invalid: RefCounted = invalid_store.load_account()
	assert(invalid.bank == 0)
	assert(invalid_store.last_error.contains("invalid"))
	assert(FileAccess.file_exists(LIVE_PATH))

	_write_text(LIVE_PATH, JSON.stringify({"version": 99, "account": {"bank": 0, "credited_run_ids": [], "owned_upgrades": []}}))
	var future_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, "user://missing_backup.json")
	future_store.load_account()
	assert(future_store.last_error.contains("invalid"))
	assert(FileAccess.file_exists(LIVE_PATH))

func _test_temp_file_is_not_loaded() -> void:
	_write_text(LIVE_PATH, JSON.stringify({"version": 1, "account": {"bank": 7, "credited_run_ids": [], "owned_upgrades": []}}))
	_write_text(TEMP_PATH, JSON.stringify({"version": 1, "account": {"bank": 999, "credited_run_ids": [], "owned_upgrades": []}}))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var loaded: RefCounted = store.load_account()
	assert(loaded.bank == 7)

func _test_clear_save() -> void:
	_write_text(LIVE_PATH, "live")
	_write_text(TEMP_PATH, "temp")
	_write_text(BACKUP_PATH, "backup")
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.clear_save())
	assert(not FileAccess.file_exists(LIVE_PATH))
	assert(not FileAccess.file_exists(TEMP_PATH))
	assert(not FileAccess.file_exists(BACKUP_PATH))
	assert(not FileAccess.file_exists(RECOVERY_PATH))

func _test_load_outcomes_and_protected_recovery() -> void:
	_cleanup()
	_write_text(BACKUP_PATH, JSON.stringify({"version": 1, "account": {"bank": 42, "credited_run_ids": [], "owned_upgrades": []}}))
	var recovered_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var recovered: RefCounted = recovered_store.load_account()
	assert(recovered.bank == 42)
	assert(recovered_store.get_load_result()["outcome"] == "recovered")
	assert(recovered_store.writes_allowed)

	_cleanup()
	var fresh_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var fresh: RefCounted = fresh_store.load_account()
	assert(fresh.bank == 0)
	assert(fresh_store.get_load_result()["outcome"] == "fresh")
	assert(fresh_store.writes_allowed)

	_cleanup()
	var unsupported_text := JSON.stringify({"version": 99, "account": {"bank": 7, "credited_run_ids": [], "owned_upgrades": []}})
	_write_text(LIVE_PATH, unsupported_text)
	var unsupported_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var unsupported: RefCounted = unsupported_store.load_account()
	assert(unsupported.bank == 0)
	assert(unsupported_store.get_load_result()["outcome"] == "unsupported")
	assert(not unsupported_store.writes_allowed)
	assert(not unsupported_store.save_account(AccountStateScript.new()))
	assert(_read_text(LIVE_PATH) == unsupported_text)
	assert(_read_text(RECOVERY_PATH) == unsupported_text)

	_cleanup()
	_write_text(LIVE_PATH, "corrupt live")
	var committed_text := JSON.stringify({"version": 1, "account": {"bank": 42, "credited_run_ids": [], "owned_upgrades": []}})
	_write_text(BACKUP_PATH, committed_text)
	var corrupt_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var from_backup: RefCounted = corrupt_store.load_account()
	assert(from_backup.bank == 42)
	assert(corrupt_store.get_load_result()["outcome"] == "recovered")
	assert(_read_text(RECOVERY_PATH) == "corrupt live")
	from_backup.bank = 55
	assert(corrupt_store.save_account(from_backup))
	from_backup.bank = 66
	assert(corrupt_store.save_account(from_backup))
	assert(_read_text(RECOVERY_PATH) == "corrupt live")
	var after_writes: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(after_writes.bank == 66)

func _test_failed_file_operations_preserve_commit() -> void:
	_cleanup()
	_write_text(LIVE_PATH, JSON.stringify({"version": 1, "account": {"bank": 7, "credited_run_ids": [], "owned_upgrades": []}}))
	var temp_failure: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var account: RefCounted = temp_failure.load_account()
	temp_failure.set_file_operations({"write": Callable(self, "_fail_temp_write")})
	account.bank = 8
	assert(not temp_failure.save_account(account))
	assert(SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account().bank == 7)

	var rename_failure: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	account = rename_failure.load_account()
	rename_failure.set_file_operations({"rename": Callable(self, "_fail_rename")})
	account.bank = 9
	assert(not rename_failure.save_account(account))
	assert(SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account().bank == 7)
	rename_failure.set_file_operations({})
	assert(rename_failure.save_account(account))
	assert(SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account().bank == 9)

func _test_unsupported_startup_is_protected() -> void:
	_cleanup()
	var unsupported_text := JSON.stringify({"version": 99, "account": {"bank": 12, "credited_run_ids": [], "owned_upgrades": []}})
	_write_text(LIVE_PATH, unsupported_text)
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	controller.persistence_enabled = true
	controller.save_store = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	controller.configure_persistence(controller.save_store)
	controller._load_account()
	assert(controller.save_store.get_load_result()["outcome"] == "unsupported")
	assert(not controller.save_store.writes_allowed)
	assert(not controller._settle_offline_production(100.0))
	assert(_read_text(LIVE_PATH) == unsupported_text)
	controller.free()

func _fail_temp_write(path: String, _text: String) -> bool:
	return path != TEMP_PATH

func _fail_rename(_from_path: String, _to_path: String) -> bool:
	return false

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, RECOVERY_PATH, "user://missing_backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null)
	var text := file.get_as_text()
	file.close()
	return text
