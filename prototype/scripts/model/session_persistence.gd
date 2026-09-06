class_name SessionPersistence
extends RefCounted

var store: RefCounted
var account: RefCounted
var monotonic_clock: Callable
var utc_clock: Callable
var dirty: bool = false
var pending_snapshot: Dictionary = {}
var utc_high_water_mark: float = 0.0

func _init(new_store: RefCounted, new_account: RefCounted, new_monotonic_clock: Callable = Callable(), new_utc_clock: Callable = Callable()) -> void:
	store = new_store
	account = new_account
	monotonic_clock = new_monotonic_clock
	utc_clock = new_utc_clock

func load_account() -> RefCounted:
	account = store.load_account()
	utc_high_water_mark = store.loaded_production_utc_timestamp
	dirty = false
	pending_snapshot = {}
	return account

func build_envelope(snapshot: Dictionary = {}) -> Dictionary:
	var current_utc: float = _utc_now()
	utc_high_water_mark = maxf(utc_high_water_mark, current_utc)
	return {
		"account": account,
		"production_utc_timestamp": utc_high_water_mark,
		"snapshot": snapshot.duplicate(true),
	}

func mark_dirty(snapshot: Dictionary = {}) -> void:
	dirty = true
	pending_snapshot = snapshot.duplicate(true)

func save(snapshot: Dictionary = {}) -> bool:
	mark_dirty(snapshot)
	return retry_pending_save()

func retry_pending_save() -> bool:
	if not dirty:
		return true
	if store.save_envelope(build_envelope(pending_snapshot)):
		dirty = false
		pending_snapshot = {}
		return true
	return false

func has_pending_save() -> bool:
	return dirty

func reset_after_clear() -> void:
	dirty = false
	pending_snapshot = {}
	utc_high_water_mark = 0.0

func now_monotonic() -> float:
	if monotonic_clock.is_valid():
		return float(monotonic_clock.call())
	return Time.get_ticks_msec() / 1000.0

func now_utc() -> float:
	return _utc_now()

func _utc_now() -> float:
	if utc_clock.is_valid():
		return float(utc_clock.call())
	return Time.get_unix_time_from_system()
