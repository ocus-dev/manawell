extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const MeleeEnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.request_start_or_harvest()
	var hero: Node3D = controller.get_node("Hero")
	hero.setup_abilities(controller.run_state)
	assert(hero.try_dash(Vector3.RIGHT))
	assert(hero.is_dash_active())
	var hero_health: float = controller.run_state.hero_health
	assert(not hero.receive_damage(25.0))
	assert(is_equal_approx(controller.run_state.hero_health, hero_health))
	assert(controller.run_state.apply_damage(RunStateScript.DamageTarget.MACHINE, 10.0))
	assert(is_equal_approx(controller.run_state.machine_integrity, BalanceData.MACHINE_INTEGRITY - 10.0))
	hero.simulate_ability_tick(BalanceData.DASH_DURATION)
	assert(not hero.is_dash_active())
	assert(hero.dash_cooldown_remaining > 0.0)

	var pulse_enemy = MeleeEnemyScript.new()
	pulse_enemy.setup(MeleeEnemyScript.EnemyKind.PURSUER, controller.run_state, hero)
	pulse_enemy.position = hero.position + Vector3(2.0, 0.0, 0.0)
	get_root().add_child(pulse_enemy)
	var pulse_targets: Array[Node3D] = [pulse_enemy]
	var first_hits: int = hero.try_pulse(pulse_targets)
	assert(first_hits == 1)
	assert(is_equal_approx(pulse_enemy.health, BalanceData.PURSUER_HEALTH - BalanceData.PULSE_DAMAGE))
	assert(hero.try_pulse(pulse_targets) == 0)
	var pulse_cooldown: float = hero.pulse_cooldown_remaining
	controller.run_state.set_paused(true)
	hero.simulate_ability_tick(10.0)
	assert(is_equal_approx(hero.pulse_cooldown_remaining, pulse_cooldown))
	assert(not hero.try_dash(Vector3.LEFT))
	assert(hero.try_pulse(pulse_targets) == 0)
	controller.run_state.set_paused(false)
	controller.run_state.abandon()
	assert(not hero.try_dash(Vector3.LEFT))
	assert(hero.try_pulse(pulse_targets) == 0)

	controller.retry()
	assert(is_equal_approx(hero.dash_cooldown_remaining, 0.0))
	assert(is_equal_approx(hero.pulse_cooldown_remaining, 0.0))
	assert(not hero.is_dash_active())
	pulse_enemy.free()
	controller.free()
	quit(0)
