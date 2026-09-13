extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	var first_view: Dictionary = controller.encounter_hud.view_state
	var first_loadouts: Array = first_view["operations"]["expedition"]["loadouts"]
	assert(bool(first_loadouts[0]["available"]))
	assert(not bool(first_loadouts[1]["available"]))
	assert(str(first_view["operations"]["wells"][1]["availability_reason"]).contains("Surge 1"))
	assert(not controller.select_well_by_id("well_2"))
	controller.account_state.bank = 200.0
	assert(controller.purchase_upgrade("pump_1"))
	assert(controller.purchase_upgrade("damage_1"))
	assert(controller.purchase_upgrade("spread_1"))
	assert(controller.start_run())
	assert(is_equal_approx(controller.run_state.extraction_rate, BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER))
	assert(is_equal_approx(controller.weapon_damage, 9.75))
	var bank_before_refresh: float = controller.account_state.bank
	controller._update_hud()
	assert(is_equal_approx(controller.account_state.bank, bank_before_refresh))
	controller.run_state.completed_surges = 1
	controller.run_state.request_harvest()
	controller.run_state.advance(BalanceData.SEALING_DURATION)
	controller._credit_if_complete()
	assert(controller.account_state.is_well_commissioned("well_1"))
	assert(controller.account_state.has_hero("hero_2"))
	assert(controller.account_state.bank == 200.0 - BalanceData.PUMP_UPGRADE_COST - BalanceData.DAMAGE_UPGRADE_COST - BalanceData.SPREAD_UPGRADE_COST + controller.run_state.locked_payout)
	controller.return_to_operations()
	assert(controller.select_active_hero_by_id("hero_2"))
	assert(controller.assign_guard_by_id("hero_1", "well_1"))
	assert(controller.recall_guard_by_well_id("well_1"))
	assert(controller.select_well_by_id("well_2"))
	assert(controller.select_loadout_by_id(LoadoutScript.STANDARD))
	assert(controller.start_run())
	assert(is_equal_approx(controller.run_state.machine_max_integrity, BalanceData.MACHINE_INTEGRITY))
	var guarded_rates: Dictionary = controller.production.calculate_rates(controller.account_state.commissioned_wells, controller.account_state.hero_assignments, controller.account_state.owned_upgrades, controller.run_state.selected_well_id)
	assert(guarded_rates.is_empty())
	controller.queue_free()
	print("2D progression checks passed")
	quit(0)
