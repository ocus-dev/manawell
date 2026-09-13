extends RefCounted

class_name SpySaveStore

var account: RefCounted
var loaded_production_utc_timestamp: float = 0.0
var loaded_snapshot: Dictionary = {}
var writes_allowed: bool = true
var last_error: String = ""
var recovery_message: String = ""
var save_count: int = 0
var fail_next_saves: int = 0
var saved_envelopes: Array[Dictionary] = []

func _init(new_account: RefCounted) -> void:
	account = new_account

func load_account() -> RefCounted:
	return account

func save_envelope(envelope: Dictionary) -> bool:
	save_count += 1
	if fail_next_saves > 0:
		fail_next_saves -= 1
		last_error = "spy save failed"
		return false
	saved_envelopes.append(envelope.duplicate(true))
	loaded_production_utc_timestamp = float(envelope["production_utc_timestamp"])
	loaded_snapshot = envelope["snapshot"].duplicate(true)
	last_error = ""
	return true
