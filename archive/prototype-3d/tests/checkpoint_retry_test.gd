extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const ProductionScript = preload("res://scripts/model/production.gd")
const SessionPersistenceScript = preload("res://scripts/model/session_persistence.gd")
const SpySaveStoreScript = preload("res://tests/spy_save_store.gd")

var utc_value: float = 1000.0

func _init() -> void:
	_test_bounded_idle_and_paused_checkpoints()
	_test_failed_purchase_retry_is_single_debit()
	_test_backward_utc_high_water_mark()
	_test_orderly_close_settles_before_save()
	quit(0)

func _test_bounded_idle_and_paused_checkpoints() -> void:
	var account: RefCounted = _guarded_account()
	var spy: RefCounted = SpySaveStoreScript.new(account)
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = true
	controller.configure_persistence(spy, Callable(controller, "_production_now"), Callable(self, "_utc_now"))
	get_root().add_child(controller)
	spy.save_count = 0
	controller.production.reset_cursor(0.0)
	for frame in range(700):
		controller.production_time_override = float(frame + 1) * 0.016
		controller.tick(0.016)
	assert(spy.save_count <= 2)
	controller.run_state.start("paused-checkpoint", "well_1", "hero_1", "standard", 2.0, 2.0)
	controller.toggle_pause()
	controller.session_persistence.mark_dirty()
	spy.save_count = 0
	controller.production_time_override = 20.0
	controller.tick(5.1)
	assert(spy.save_count == 1)
	controller.free()

func _test_failed_purchase_retry_is_single_debit() -> void:
	var account: RefCounted = _guarded_account()
	account.bank = 100.0
	var spy: RefCounted = SpySaveStoreScript.new(account)
	var controller: Node = ControllerScript.new()
	controller.persistence_enabled = true
	controller.account_state = account
	controller.configure_persistence(spy, Callable(self, "_monotonic_now"), Callable(self, "_utc_now"))
	controller.production.reset_cursor(0.0)
	spy.fail_next_saves = 1
	assert(controller.purchase_upgrade("damage_1"))
	assert(controller.account_state.bank == 65.0)
	assert(controller.session_persistence.has_pending_save())
	assert(controller.retry_pending_save())
	assert(controller.account_state.bank == 65.0)
	assert(spy.save_count == 2)
	assert(spy.saved_envelopes.size() == 1)
	controller.free()

func _test_backward_utc_high_water_mark() -> void:
	var account: RefCounted = AccountStateScript.new()
	var spy: RefCounted = SpySaveStoreScript.new(account)
	spy.loaded_production_utc_timestamp = 1000000.0
	var session: RefCounted = SessionPersistenceScript.new(spy, account, Callable(self, "_monotonic_now"), Callable(self, "_backward_utc_now"))
	session.load_account()
	assert(session.save())
	assert(spy.saved_envelopes[0]["production_utc_timestamp"] == 1000000.0)

func _test_orderly_close_settles_before_save() -> void:
	var account: RefCounted = _guarded_account()
	var spy: RefCounted = SpySaveStoreScript.new(account)
	var controller: Node = ControllerScript.new()
	controller.persistence_enabled = true
	controller.account_state = account
	controller.configure_persistence(spy, Callable(self, "_monotonic_now"), Callable(self, "_utc_now"))
	controller.production.reset_cursor(0.0)
	controller._settle_production()
	assert(controller.session_persistence.has_pending_save())
	controller._save_checkpoint()
	assert(spy.saved_envelopes.size() == 1)
	assert(spy.saved_envelopes[0]["account"].bank > 0.0)
	controller.free()

func _guarded_account() -> RefCounted:
	var account: RefCounted = AccountStateScript.new()
	account.commissioned_wells = {"well_1": true}
	account.roster_heroes["hero_2"] = true
	account.hero_assignments = {
		"hero_1": {"role": "active", "well_id": ""},
		"hero_2": {"role": "guard", "well_id": "well_1"},
	}
	return account

func _monotonic_now() -> float:
	return 10.0

func _utc_now() -> float:
	return utc_value

func _backward_utc_now() -> float:
	return 900000.0
