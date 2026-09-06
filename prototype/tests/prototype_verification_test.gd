extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const ProductionScript = preload("res://scripts/model/production.gd")

const LIVE_PATH: String = "user://test_prototype_verification.json"
const TEMP_PATH: String = "user://test_prototype_verification.tmp"
const BACKUP_PATH: String = "user://test_prototype_verification.bak"

var controller: Node

func _init() -> void:
	_cleanup()
	var account: RefCounted = AccountStateScript.new()
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account, 100.0))
	controller = _new_controller(account, store)
	_test_fresh_progression()
	_test_production_and_recovery()
	_cleanup()
	quit(0)

func _new_controller(account: RefCounted, store: RefCounted) -> Node:
	var instance: Node = load("res://scenes/main.tscn").instantiate()
	instance.persistence_enabled = false
	get_root().add_child(instance)
	instance.account_state = account
	instance.save_store = store
	return instance

func _test_fresh_progression() -> void:
	assert(controller.account_state.bank == 0.0)
	_complete_run("well_1")
	assert(controller.account_state.is_well_commissioned("well_1"))
	assert(controller.account_state.is_well_unlocked("well_2"))
	assert(controller.account_state.has_hero("hero_2"))
	_assert_purchase_after_run("damage_1")
	_complete_run("well_1")
	_assert_purchase_after_run("pump_1")
	_complete_run("well_1")
	_complete_run("well_1")
	_assert_purchase_after_run("spread_1")
	assert(controller.account_state.has_upgrade("damage_1"))
	assert(controller.account_state.has_upgrade("pump_1"))
	assert(controller.account_state.has_upgrade("spread_1"))
	assert(controller.account_state.select_active_hero("hero_1"))
	assert(controller.account_state.assign_guard("hero_2", "well_1"))
	print("fresh_progression: bank=%.2f upgrades=damage,pump,spread guard=hero_2/well_1" % controller.account_state.bank)

func _test_production_and_recovery() -> void:
	controller.production_time_override = 100.0
	controller.production.reset_cursor(100.0)
	controller.select_well(1)
	controller.selected_loadout_id = LoadoutScript.STANDARD
	controller.request_start_or_harvest()
	assert(controller.run_state.selected_well_id == "well_2")
	var bank_before_income: float = controller.account_state.bank
	controller.production_time_override = 160.0
	controller._settle_production()
	var expected_rate: float = BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER * 1.25 * ProductionScript.PASSIVE_OUTPUT_FACTOR
	assert(is_equal_approx(float(controller.displayed_rates["well_1"]), expected_rate))
	assert(is_equal_approx(controller.account_state.bank - bank_before_income, expected_rate * 60.0))
	print("passive_income: displayed_rate=%.3f mana/sec credited=%.2f" % [expected_rate, expected_rate * 60.0])
	controller.run_state.reset()
	controller._clear_enemies()
	controller.selected_loadout_id = LoadoutScript.OVERDRIVE
	controller.request_start_or_harvest()
	controller.run_state.advance(20.0)
	controller.run_state.request_harvest()
	var snapshot: Dictionary = controller._capture_snapshot()
	var save_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(save_store.save_account(controller.account_state, 160.0, snapshot))
	var reloaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var reloaded_account: RefCounted = reloaded_store.load_account()
	assert(not reloaded_store.loaded_snapshot.is_empty())
	var restored: Node = _new_controller(reloaded_account, reloaded_store)
	restored._restore_saved_snapshot()
	assert(restored.run_state.paused)
	assert(restored.run_state.phase == RunStateScript.Phase.SEALING)
	var sealing_before: float = restored.run_state.sealing_remaining
	restored.toggle_pause()
	restored.run_state.advance(sealing_before)
	restored._credit_if_complete()
	assert(restored.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(restored.account_state.is_well_commissioned("well_2"))
	assert(restored.account_state.select_loadout("well_2", LoadoutScript.OVERDRIVE))
	assert(restored.account_state.get_loadout_for_well("well_2") == LoadoutScript.OVERDRIVE)
	print("recovery: restored_paused=true resumed_sealing=true well_2_commissioned=true loadout=overdrive")
	restored.free()

func _complete_run(well_id: String) -> void:
	if controller.run_state.phase != RunStateScript.Phase.READY:
		controller.run_state.reset()
		controller._clear_enemies()
	controller.selected_well_id = well_id
	controller.selected_loadout_id = LoadoutScript.STANDARD
	controller.request_start_or_harvest()
	controller.run_state.advance(20.0)
	controller.run_state.request_harvest()
	controller.run_state.advance(controller.run_state.sealing_duration)
	controller._credit_if_complete()
	assert(controller.run_state.phase == RunStateScript.Phase.SUCCESS)
	controller.run_state.reset()
	controller._clear_enemies()

func _assert_purchase_after_run(upgrade_id: String) -> void:
	assert(controller.purchase_upgrade(upgrade_id))
	assert(controller.account_state.has_upgrade(upgrade_id))

func _cleanup() -> void:
	if is_instance_valid(controller):
		controller.free()
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
