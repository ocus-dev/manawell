extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")

const LIVE_PATH: String = "user://test_two_wells_save.json"
const TEMP_PATH: String = "user://test_two_wells_save.tmp"
const BACKUP_PATH: String = "user://test_two_wells_save.bak"

func _init() -> void:
	_cleanup()
	_test_account_commission_rules()
	_test_controller_well_selection()
	_cleanup()
	quit(0)

func _test_account_commission_rules() -> void:
	var account: RefCounted = AccountStateScript.new()
	var early_result := {"phase": RunStateScript.Phase.SUCCESS, "run_id": "early", "payout": 2}
	assert(account.credit_terminal_result_with_commission(early_result, "well_1", 0))
	assert(not account.is_well_commissioned("well_1"))
	assert(not account.is_well_unlocked("well_2"))
	var failed_result := {"phase": RunStateScript.Phase.FAILED, "run_id": "failed", "payout": 0}
	assert(not account.credit_terminal_result_with_commission(failed_result, "well_1", 1))
	var qualifying_result := {"phase": RunStateScript.Phase.SUCCESS, "run_id": "qualifying", "payout": 4}
	assert(account.credit_terminal_result_with_commission(qualifying_result, "well_1", 1))
	assert(account.is_well_commissioned("well_1"))
	assert(account.is_well_unlocked("well_2"))
	assert(account.has_hero("hero_2"))
	var bank_after_commission: int = account.bank
	assert(not account.credit_terminal_result_with_commission(qualifying_result, "well_1", 1))
	assert(account.bank == bank_after_commission)
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account))
	var restarted: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(restarted.is_well_commissioned("well_1"))
	assert(restarted.is_well_unlocked("well_2"))
	assert(restarted.has_hero("hero_2"))

func _test_controller_well_selection() -> void:
	var qualifying_controller: Node = load("res://scenes/main.tscn").instantiate()
	qualifying_controller.persistence_enabled = false
	get_root().add_child(qualifying_controller)
	qualifying_controller.run_state.start("commission-check", "well_1", "hero_1", "standard", BalanceData.WELL_1_BASE_OUTPUT, 0.0)
	qualifying_controller.run_state.completed_surges = 1
	qualifying_controller.run_state.request_harvest()
	qualifying_controller.tick(0.0)
	assert(qualifying_controller.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(qualifying_controller.account_state.has_hero("hero_2"))
	assert(qualifying_controller.account_state.is_well_unlocked("well_2"))
	qualifying_controller.free()

	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.unlocked_wells["well_2"] = true
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	assert(controller.account_state.select_active_hero("hero_2"))
	controller.select_well(1)
	assert(controller.selected_well_id == "well_2")
	controller.request_start_or_harvest()
	assert(controller.run_state.selected_well_id == "well_2")
	assert(controller.run_state.selected_hero_id == "hero_2")
	assert(is_equal_approx(controller.run_state.extraction_rate, BalanceData.WELL_2_BASE_OUTPUT))
	assert(is_equal_approx(controller._spawn_interval(), 2.4))
	assert(is_equal_approx(controller._enemy_damage_multiplier(), 1.25))
	controller.select_well(0)
	assert(controller.selected_well_id == "well_2")
	controller.run_state.apply_damage(RunStateScript.DamageTarget.HERO, BalanceData.HERO_HEALTH)
	controller.retry()
	assert(controller.run_state.selected_well_id == "well_2")
	var preserved_bank: int = controller.account_state.bank
	controller.run_state.apply_damage(RunStateScript.DamageTarget.HERO, BalanceData.HERO_HEALTH)
	controller.select_well(0)
	assert(controller.selected_well_id == "well_1")
	assert(controller.run_state.phase == RunStateScript.Phase.READY)
	assert(controller.account_state.bank == preserved_bank)
	controller.free()

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
