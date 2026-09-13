extends SceneTree

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")

func _init() -> void:
	_test_ready_and_pause()
	_test_surge_boundary_and_harvest_lock()
	_test_zero_duration_sealing()
	_test_lethal_damage_and_repeated_harvest()
	_test_abandon_and_reset()
	_test_invalid_inputs()
	quit(0)

func _new_state(sealing_duration: float = BalanceData.SEALING_DURATION) -> RefCounted:
	var state: RefCounted = RunStateScript.new()
	assert(state.start("run-test", "well_1", "hero_1", "standard", 2.0, sealing_duration))
	return state

func _test_ready_and_pause() -> void:
	var state: RefCounted = RunStateScript.new()
	assert(state.phase == RunStateScript.Phase.READY)
	assert(not state.advance(1.0))
	assert(is_zero_approx(state.tank_base))
	assert(state.start("run-pause"))
	assert(state.advance(19.0))
	var tank_before_pause: float = state.tank_base
	state.set_paused(true)
	assert(not state.advance(10.0))
	assert(is_equal_approx(state.tank_base, tank_before_pause))
	state.set_paused(false)
	assert(state.advance(1.0))
	assert(state.completed_surges == 1)

func _test_surge_boundary_and_harvest_lock() -> void:
	var state: RefCounted = _new_state()
	assert(state.advance(19.999))
	assert(state.completed_surges == 0)
	assert(is_equal_approx(state.multiplier, 1.0))
	assert(state.advance(0.001))
	assert(state.completed_surges == 1)
	assert(is_equal_approx(state.multiplier, 1.25))
	var tank_at_harvest: float = state.tank_base
	assert(state.request_harvest())
	assert(state.phase == RunStateScript.Phase.SEALING)
	assert(state.locked_payout == floori(tank_at_harvest * 1.25))
	assert(state.advance(1.0))
	assert(state.phase == RunStateScript.Phase.SEALING)
	assert(is_equal_approx(state.tank_base, tank_at_harvest))
	assert(state.advance(1.0))
	assert(state.phase == RunStateScript.Phase.SUCCESS)
	assert(state.get_terminal_result()["run_id"] == state.run_id)
	assert(state.get_terminal_result()["payout"] == state.locked_payout)
	assert(not state.request_harvest())

func _test_zero_duration_sealing() -> void:
	var state: RefCounted = _new_state(0.0)
	assert(state.advance(1.0))
	assert(state.request_harvest())
	assert(state.phase == RunStateScript.Phase.SEALING)
	assert(state.advance(0.0))
	assert(state.phase == RunStateScript.Phase.SUCCESS)

func _test_lethal_damage_and_repeated_harvest() -> void:
	var state: RefCounted = _new_state()
	assert(state.advance(5.0))
	assert(state.request_harvest())
	assert(not state.request_harvest())
	assert(state.apply_damage(RunStateScript.DamageTarget.HERO, 100.0))
	assert(state.phase == RunStateScript.Phase.FAILED)
	assert(state.locked_payout == 0)
	assert(state.get_terminal_result()["payout"] == 0)
	assert(not state.advance(2.0))

func _test_abandon_and_reset() -> void:
	var state: RefCounted = _new_state()
	assert(state.advance(3.0))
	assert(state.tank_base > 0.0)
	assert(state.abandon())
	assert(state.phase == RunStateScript.Phase.FAILED)
	assert(is_zero_approx(state.tank_base))
	assert(state.get_terminal_result()["terminal_reason"] == "abandoned")
	assert(not state.abandon())
	state.reset()
	assert(state.phase == RunStateScript.Phase.READY)
	assert(state.run_id.is_empty())
	assert(is_zero_approx(state.tank_base))
	assert(is_zero_approx(state.hero_health))
	assert(state.get_terminal_result().is_empty())

func _test_invalid_inputs() -> void:
	var state: RefCounted = RunStateScript.new()
	assert(not state.start("bad", "well_1", "hero_1", "standard", -1.0))
	assert(state.phase == RunStateScript.Phase.READY)
	assert(not state.start("bad", "well_1", "hero_1", "standard", INF))
	assert(state.start("run-invalid"))
	var tank_before: float = state.tank_base
	assert(not state.advance(-1.0))
	assert(not state.advance(INF))
	assert(is_equal_approx(state.tank_base, tank_before))
	assert(not state.apply_damage(RunStateScript.DamageTarget.HERO, -1.0))
	assert(not state.apply_damage(RunStateScript.DamageTarget.HERO, INF))
	assert(not state.apply_damage(99, 1.0))
	assert(is_equal_approx(state.hero_health, BalanceData.HERO_HEALTH))
