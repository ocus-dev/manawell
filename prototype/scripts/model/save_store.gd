class_name SaveStore
extends RefCounted

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")

const CURRENT_VERSION: int = 4
const DEFAULT_LIVE_PATH: String = "user://account_save.json"
const DEFAULT_TEMP_PATH: String = "user://account_save.tmp"
const DEFAULT_BACKUP_PATH: String = "user://account_save.bak"
const DEFAULT_RECOVERY_PATH_SUFFIX: String = ".recovery"

enum LoadOutcome { FRESH, LOADED, RECOVERED, UNSUPPORTED, CORRUPT }

var live_path: String
var temp_path: String
var backup_path: String
var recovery_path: String
var last_error: String = ""
var recovery_message: String = ""
var loaded_production_timestamp: float = 0.0
var loaded_production_utc_timestamp: float = 0.0
var loaded_snapshot: Dictionary = {}
var load_outcome: LoadOutcome = LoadOutcome.FRESH
var writes_allowed: bool = true
var file_operations: Dictionary = {}
var _rejected_live: bool = false

func _init(new_live_path: String = DEFAULT_LIVE_PATH, new_temp_path: String = "", new_backup_path: String = "") -> void:
	live_path = new_live_path
	temp_path = new_temp_path if not new_temp_path.is_empty() else "%s.tmp" % live_path
	backup_path = new_backup_path if not new_backup_path.is_empty() else "%s.bak" % live_path
	recovery_path = "%s%s" % [live_path, DEFAULT_RECOVERY_PATH_SUFFIX]

func load_account() -> RefCounted:
	last_error = ""
	recovery_message = ""
	loaded_production_timestamp = 0.0
	loaded_production_utc_timestamp = 0.0
	loaded_snapshot = {}
	load_outcome = LoadOutcome.FRESH
	writes_allowed = true
	_rejected_live = false
	if not _file_exists(live_path):
		if _file_exists(backup_path):
			var missing_live_backup := _read_account(backup_path)
			if missing_live_backup.valid:
				_apply_loaded_result(missing_live_backup)
				load_outcome = LoadOutcome.RECOVERED
				recovery_message = "Save recovery: loaded the last-good backup because the live save was missing."
				return missing_live_backup.account
			return _reject_without_recovery(missing_live_backup)
		return AccountStateScript.new()
	var live_result := _read_account(live_path)
	if live_result.valid:
		_apply_loaded_result(live_result)
		load_outcome = LoadOutcome.LOADED
		if not live_result.snapshot_error.is_empty():
			recovery_message = live_result.snapshot_error
		return live_result.account
	_rejected_live = true
	_preserve_rejected_live()
	if _file_exists(backup_path):
		var backup_result := _read_account(backup_path)
		if backup_result.valid:
			_apply_loaded_result(backup_result)
			load_outcome = LoadOutcome.RECOVERED
			recovery_message = "Save recovery: loaded the last-good backup. The original save was preserved."
			return backup_result.account
	return _reject_without_recovery(live_result)

func get_load_result() -> Dictionary:
	return {
		"outcome": LoadOutcome.keys()[load_outcome].to_lower(),
		"writes_allowed": writes_allowed,
		"recovery_path": recovery_path,
	}

func set_file_operations(overrides: Dictionary) -> void:
	file_operations = overrides.duplicate()

func _apply_loaded_result(result: Dictionary) -> void:
	loaded_production_timestamp = result.production_timestamp
	loaded_production_utc_timestamp = result.production_timestamp
	loaded_snapshot = result.snapshot

func _reject_without_recovery(result: Dictionary) -> RefCounted:
	writes_allowed = false
	load_outcome = LoadOutcome.UNSUPPORTED if result.status == "unsupported" else LoadOutcome.CORRUPT
	last_error = "Save recovery failed: invalid or unsupported save (%s) and no valid backup was found." % result.error
	recovery_message = last_error
	return AccountStateScript.new()

func save_account(account: RefCounted, production_timestamp: float = 0.0, snapshot: Dictionary = {}) -> bool:
	return save_envelope({
		"account": account,
		"production_utc_timestamp": production_timestamp,
		"snapshot": snapshot,
	})

func save_envelope(envelope: Dictionary) -> bool:
	last_error = ""
	if not writes_allowed:
		return _fail_save("Save blocked: the loaded save is %s and must be recovered or reset first." % get_load_result()["outcome"])
	var account: RefCounted = envelope.get("account")
	var production_utc_timestamp: float = float(envelope.get("production_utc_timestamp", 0.0))
	var snapshot: Dictionary = envelope.get("snapshot", {})
	if account == null:
		return _fail_save("Save failed: account state is missing.")
	var payload: Dictionary = {
		"version": CURRENT_VERSION,
		"account": account.to_save_payload(),
		"production_utc_timestamp": production_utc_timestamp if is_finite(production_utc_timestamp) else 0.0,
	}
	if not snapshot.is_empty():
		var snapshot_result: Dictionary = SnapshotScript.encode(snapshot)
		if not snapshot_result["valid"]:
			return _fail_save("Save failed: %s" % snapshot_result["error"])
		payload["snapshot"] = snapshot_result["payload"]
	var validation := _validate_payload(payload)
	if not validation.valid:
		return _fail_save("Save failed: %s" % validation.error)
	var json_text := JSON.stringify(payload)
	if not _write_file(temp_path, json_text):
		return _fail_save("Save failed: could not open temporary save.")
	if not _replace_live_with_temp():
		return _fail_save("Save failed: could not replace the account save.")
	return true

func clear_save() -> bool:
	last_error = ""
	for path in [live_path, temp_path, backup_path, recovery_path]:
		if _file_exists(path) and not _remove_file(path):
			return _fail_save("Save reset failed: could not remove %s." % path)
	writes_allowed = true
	load_outcome = LoadOutcome.FRESH
	_rejected_live = false
	return true

func _replace_live_with_temp() -> bool:
	if _file_exists(live_path) and not _rejected_live:
		var committed_live := _read_file(live_path)
		if not committed_live.valid or not _write_file(backup_path, committed_live.text):
			return false
	if _rejected_live and _file_exists(live_path) and not _remove_file(live_path):
		return false
	if _rename_file(temp_path, live_path):
		_rejected_live = false
		return true
	return false

func _read_account(path: String) -> Dictionary:
	var file_result := _read_file(path)
	if not file_result.valid:
		return {"valid": false, "status": "corrupt", "error": "could not open save"}
	var text: String = file_result.text
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"valid": false, "status": "corrupt", "error": "JSON root must be an object"}
	var validation := _validate_payload(parsed)
	if not validation.valid:
		return {"valid": false, "status": validation.status, "error": validation.error}
	var account: RefCounted = AccountStateScript.new()
	account.from_save_payload(parsed["account"])
	var snapshot: Dictionary = {}
	var snapshot_error: String = ""
	if parsed.has("snapshot"):
		var snapshot_result: Dictionary = SnapshotScript.decode(parsed["snapshot"])
		if snapshot_result["valid"]:
			snapshot = snapshot_result["snapshot"]
		else:
			snapshot_error = "Save recovery: active encounter snapshot was rejected; banked progress was preserved."
	if not account.legacy_identity_error.is_empty() and not snapshot.is_empty():
		snapshot = {}
		snapshot_error = "Save recovery: active encounter snapshot was rejected because legacy completion identity could not be mapped safely; banked progress was preserved."
	return {"valid": true, "status": "valid", "account": account, "production_timestamp": float(parsed.get("production_utc_timestamp", parsed.get("production_timestamp", 0.0))), "snapshot": snapshot, "snapshot_error": snapshot_error}

func _preserve_rejected_live() -> void:
	if _file_exists(recovery_path):
		return
	var source := _read_file(live_path)
	if source.valid and _write_file(recovery_path, source.text):
		recovery_message = "Save recovery: the rejected live save was preserved at %s." % recovery_path

func _file_exists(path: String) -> bool:
	if file_operations.has("exists"):
		return bool(file_operations["exists"].call(path))
	return FileAccess.file_exists(path)

func _read_file(path: String) -> Dictionary:
	if file_operations.has("read"):
		return file_operations["read"].call(path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false, "text": ""}
	var text := file.get_as_text()
	file.close()
	return {"valid": true, "text": text}

func _write_file(path: String, text: String) -> bool:
	if file_operations.has("write"):
		return bool(file_operations["write"].call(path, text))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

func _remove_file(path: String) -> bool:
	if file_operations.has("remove"):
		return bool(file_operations["remove"].call(path))
	return DirAccess.remove_absolute(path) == OK

func _rename_file(from_path: String, to_path: String) -> bool:
	if file_operations.has("rename"):
		return bool(file_operations["rename"].call(from_path, to_path))
	return DirAccess.rename_absolute(from_path, to_path) == OK

func _validate_payload(payload: Dictionary) -> Dictionary:
	if not payload.has("version") or not (payload["version"] is int or payload["version"] is float):
		return {"valid": false, "status": "corrupt", "error": "missing integer schema version"}
	var version: float = float(payload["version"])
	if not is_finite(version) or not is_equal_approx(version, floorf(version)):
		return {"valid": false, "status": "corrupt", "error": "missing integer schema version"}
	if version > CURRENT_VERSION:
		return {"valid": false, "status": "unsupported", "error": "unsupported future schema version"}
	if version < 1:
		return {"valid": false, "status": "unsupported", "error": "unsupported schema version"}
	var timestamp_key: String = "production_utc_timestamp" if payload.has("production_utc_timestamp") else "production_timestamp"
	if payload.has(timestamp_key) and not (payload[timestamp_key] is int or payload[timestamp_key] is float):
		return {"valid": false, "status": "corrupt", "error": "production timestamp must be a number"}
	if payload.has(timestamp_key) and not is_finite(float(payload[timestamp_key])):
		return {"valid": false, "status": "corrupt", "error": "production timestamp must be finite"}
	if not payload.has("account") or not payload["account"] is Dictionary:
		return {"valid": false, "status": "corrupt", "error": "missing account object"}
	var account_validation: Dictionary = AccountStateScript.validate_save_payload(payload["account"])
	if not account_validation.valid:
		account_validation["status"] = "corrupt"
	return account_validation

func _fail_save(message: String) -> bool:
	last_error = message
	return false