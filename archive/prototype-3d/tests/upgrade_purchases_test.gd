extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const MeleeEnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_account_purchase_rules()
	_test_controller_upgrade_effects()
	quit(0)

func _test_account_purchase_rules() -> void:
	var account = load("res://scripts/model/account_state.gd").new()
	assert(not account.purchase_upgrade("damage_1"))
	account.bank = BalanceData.DAMAGE_UPGRADE_COST
	assert(account.purchase_upgrade("damage_1"))
	assert(account.bank == 0)
	assert(account.has_upgrade("damage_1"))
	assert(not account.purchase_upgrade("damage_1"))
	assert(not account.purchase_upgrade("unknown"))

func _test_controller_upgrade_effects() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	controller.account_state.bank = BalanceData.DAMAGE_UPGRADE_COST + BalanceData.PUMP_UPGRADE_COST + BalanceData.SPREAD_UPGRADE_COST
	assert(controller.purchase_upgrade("damage_1"))
	assert(controller.purchase_upgrade("pump_1"))
	assert(controller.purchase_upgrade("spread_1"))
	assert(controller.account_state.bank == 0)
	assert(controller.get_node("Machine").get_node_or_null("PumpResearch") != null)
	controller.request_start_or_harvest()
	assert(not controller.purchase_upgrade("damage_1"))
	assert(is_equal_approx(controller.run_state.extraction_rate, BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER))
	assert(is_equal_approx(controller.auto_weapon.damage, BalanceData.WEAPON_DAMAGE + BalanceData.DAMAGE_UPGRADE_BONUS))
	assert(controller.auto_weapon.spread_enabled)

	var enemy = MeleeEnemyScript.new()
	enemy.setup(MeleeEnemyScript.EnemyKind.PURSUER, controller.run_state, controller.get_node("Hero"))
	enemy.position = Vector3(11.9, 1.0, 6.0)
	get_root().add_child(enemy)
	var weapon_targets: Array[Node3D] = [enemy]
	controller.auto_weapon.set_enemies(weapon_targets)
	controller.auto_weapon.tick(BalanceData.WEAPON_INTERVAL)
	assert(controller.auto_weapon.shot_count == 3)
	assert(controller.auto_weapon.projectiles.size() == 3)
	var first_velocity: Vector3 = controller.auto_weapon.projectiles[0].velocity
	var second_velocity: Vector3 = controller.auto_weapon.projectiles[1].velocity
	assert(not first_velocity.is_equal_approx(second_velocity))

	controller.run_state.apply_damage(RunStateScript.DamageTarget.HERO, BalanceData.HERO_HEALTH)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	controller.retry()
	assert(controller.account_state.has_upgrade("damage_1"))
	assert(controller.account_state.has_upgrade("pump_1"))
	assert(controller.account_state.has_upgrade("spread_1"))
	assert(controller.run_state.phase == RunStateScript.Phase.EXTRACTING)
	assert(is_equal_approx(controller.run_state.extraction_rate, BalanceData.WELL_1_BASE_OUTPUT * BalanceData.PUMP_OUTPUT_MULTIPLIER))
	if is_instance_valid(enemy):
		enemy.free()
	controller.free()
