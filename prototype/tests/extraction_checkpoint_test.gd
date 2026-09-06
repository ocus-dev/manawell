extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	call_deferred("_run_checkpoint")

func _run_checkpoint() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.request_start_or_harvest()
	controller.tick(1.0)
	print("fresh_run: phase=", controller.run_state.phase, " simulation_seconds=", controller.run_state.simulation_elapsed, " tank=", controller.run_state.tank_base)
	controller.request_start_or_harvest()
	print("harvest: phase=", controller.run_state.phase, " locked_payout=", controller.run_state.locked_payout, " sealing_remaining=", controller.run_state.sealing_remaining)
	controller.toggle_pause()
	controller.tick(1.0)
	print("pause_during_sealing: phase=", controller.run_state.phase, " remaining=", controller.run_state.sealing_remaining)
	assert(controller.run_state.phase == RunStateScript.Phase.SEALING)
	controller.toggle_pause()
	controller.tick(2.0)
	print("delayed_success: phase=", controller.run_state.phase, " bank=", controller.account_state.bank)
	assert(controller.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(controller.account_state.bank == 2)

	controller.retry()
	controller.run_state.apply_damage(RunStateScript.DamageTarget.HERO, BalanceData.HERO_HEALTH)
	controller.tick(0.0)
	print("hero_failure: phase=", controller.run_state.phase, " reason=", controller.run_state.terminal_reason, " bank=", controller.account_state.bank)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	assert(controller.run_state.terminal_reason == "hero_destroyed")
	controller.retry()
	controller.run_state.apply_damage(RunStateScript.DamageTarget.MACHINE, BalanceData.MACHINE_INTEGRITY)
	controller.tick(0.0)
	print("machine_failure: phase=", controller.run_state.phase, " reason=", controller.run_state.terminal_reason, " bank=", controller.account_state.bank)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	assert(controller.run_state.terminal_reason == "machine_destroyed")
	controller.retry()
	assert(controller.run_state.phase == RunStateScript.Phase.EXTRACTING)
	print("retry: phase=", controller.run_state.phase, " upgrades_retained=", controller.account_state.owned_upgrades.size())
	controller.free()

	var instant: Node = load("res://scenes/main.tscn").instantiate()
	instant.persistence_enabled = false
	instant.developer_mode = true
	instant.sealing_duration_setting = 0.0
	get_root().add_child(instant)
	instant.request_start_or_harvest()
	instant.tick(1.0)
	instant.request_start_or_harvest()
	instant.tick(0.0)
	print("instant_sealing: phase=", instant.run_state.phase, " sealing_duration=", instant.run_state.sealing_duration, " payout=", instant.account_state.bank)
	assert(instant.run_state.phase == RunStateScript.Phase.SUCCESS)
	instant.free()

	var upgrades: Node = load("res://scenes/main.tscn").instantiate()
	upgrades.persistence_enabled = false
	get_root().add_child(upgrades)
	upgrades.account_state.bank = BalanceData.DAMAGE_UPGRADE_COST + BalanceData.PUMP_UPGRADE_COST + BalanceData.SPREAD_UPGRADE_COST
	assert(upgrades.purchase_upgrade("damage_1"))
	assert(upgrades.purchase_upgrade("pump_1"))
	assert(upgrades.purchase_upgrade("spread_1"))
	upgrades.request_start_or_harvest()
	print("upgrades_next_run: extraction_rate=", upgrades.run_state.extraction_rate, " weapon_damage=", upgrades.auto_weapon.damage, " spread=", upgrades.auto_weapon.spread_enabled)
	assert(is_equal_approx(upgrades.run_state.extraction_rate, BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER))
	assert(is_equal_approx(upgrades.auto_weapon.damage, BalanceData.WEAPON_DAMAGE + BalanceData.DAMAGE_UPGRADE_BONUS))
	assert(upgrades.auto_weapon.spread_enabled)
	upgrades.free()
	quit(0)
