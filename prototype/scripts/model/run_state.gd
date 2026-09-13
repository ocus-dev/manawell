class_name RunState
extends RefCounted

const BalanceData = preload("res://data/balance.gd")

enum Phase {
	READY,
	EXTRACTING,
	SEALING,
	SUCCESS,
	FAILED,
}

enum DamageTarget {
	HERO,
	MACHINE,
}

var run_id: String = ""
var selected_well_id: String = ""
var selected_hero_id: String = ""
var selected_module_id: String = ""
var phase: Phase = Phase.READY
var paused: bool = false
var simulation_elapsed: float = 0.0
var tank_base: float = 0.0
var extraction_rate: float = 0.0
var pressure_time_scale: float = 1.0
var completed_surges: int = 0
var multiplier: float = 1.0
var locked_payout: int = 0
var sealing_remaining: float = 0.0
var sealing_duration: float = 0.0
var hero_health: float = 0.0
var machine_integrity: float = 0.0
var machine_max_integrity: float = 0.0
var terminal_reason: String = ""
var harvest_specialization_id: String = "harvest.standard"
var harvest_cycle_progress: float = 0.0
var harvest_cycle_amount: float = 0.0
var harvest_cycle_interval: float = 1.0
var weapon_mode_id: String = "weapon.standard"
var weapon_projectile_speed: float = BalanceData.WEAPON_PROJECTILE_SPEED

func start(
	new_run_id: String,
	well_id: String = "well_1",
	hero_id: String = "hero_1",
	module_id: String = "standard",
	new_extraction_rate: float = BalanceData.WELL_1_BASE_OUTPUT,
	new_sealing_duration: float = BalanceData.SEALING_DURATION,
	new_hero_health: float = BalanceData.HERO_HEALTH,
	new_machine_integrity: float = BalanceData.MACHINE_INTEGRITY,
	new_pressure_time_scale: float = 1.0,
	new_harvest_specialization_id: String = "harvest.standard",
	new_cycle_amount: float = 0.0,
	new_cycle_interval: float = 1.0,
	new_weapon_mode_id: String = "weapon.standard",
	new_weapon_speed: float = BalanceData.WEAPON_PROJECTILE_SPEED
) -> bool:
	if phase != Phase.READY:
		return false
	if new_run_id.is_empty() or not is_finite(new_extraction_rate) or new_extraction_rate < 0.0:
		return false
	if not is_finite(new_sealing_duration) or new_sealing_duration < 0.0:
		return false
	if not is_finite(new_hero_health) or new_hero_health <= 0.0:
		return false
	if not is_finite(new_machine_integrity) or new_machine_integrity <= 0.0:
		return false
	if not is_finite(new_pressure_time_scale) or new_pressure_time_scale <= 0.0:
		return false
	if well_id.is_empty() or hero_id.is_empty() or module_id.is_empty():
		return false
	run_id = new_run_id
	selected_well_id = well_id
	selected_hero_id = hero_id
	selected_module_id = module_id
	phase = Phase.EXTRACTING
	paused = false
	simulation_elapsed = 0.0
	tank_base = 0.0
	extraction_rate = new_extraction_rate
	pressure_time_scale = new_pressure_time_scale
	completed_surges = 0
	multiplier = BalanceData.multiplier_for(completed_surges)
	locked_payout = 0
	sealing_remaining = 0.0
	sealing_duration = new_sealing_duration
	hero_health = new_hero_health
	machine_integrity = new_machine_integrity
	machine_max_integrity = new_machine_integrity
	terminal_reason = ""
	harvest_specialization_id = new_harvest_specialization_id
	harvest_cycle_progress = 0.0
	harvest_cycle_amount = new_cycle_amount
	harvest_cycle_interval = new_cycle_interval
	weapon_mode_id = new_weapon_mode_id
	weapon_projectile_speed = new_weapon_speed
	return true

func start_combat(
	new_run_id: String,
	hero_id: String = "hero_1",
	module_id: String = "standard",
	new_reward: int = 0,
	new_hero_health: float = BalanceData.HERO_HEALTH
) -> bool:
	if phase != Phase.READY or new_run_id.is_empty() or hero_id.is_empty() or module_id.is_empty() or new_reward < 0:
		return false
	run_id = new_run_id
	selected_well_id = ""
	selected_hero_id = hero_id
	selected_module_id = module_id
	phase = Phase.EXTRACTING
	paused = false
	simulation_elapsed = 0.0
	tank_base = 0.0
	extraction_rate = 0.0
	pressure_time_scale = 1.0
	completed_surges = 0
	multiplier = 1.0
	locked_payout = new_reward
	sealing_remaining = 0.0
	sealing_duration = 0.0
	hero_health = new_hero_health
	machine_integrity = 1.0
	machine_max_integrity = 1.0
	terminal_reason = ""
	harvest_specialization_id = "harvest.standard"
	harvest_cycle_progress = 0.0
	harvest_cycle_amount = 0.0
	harvest_cycle_interval = 1.0
	weapon_mode_id = "weapon.standard"
	weapon_projectile_speed = BalanceData.WEAPON_PROJECTILE_SPEED
	return true

func complete_combat() -> bool:
	if phase != Phase.EXTRACTING:
		return false
	phase = Phase.SUCCESS
	paused = false
	terminal_reason = "objective_cleared"
	return true

func set_paused(should_pause: bool) -> void:
	if phase == Phase.EXTRACTING or phase == Phase.SEALING:
		paused = should_pause

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0 or paused:
		return false
	if phase == Phase.EXTRACTING:
		simulation_elapsed += delta * pressure_time_scale
		if harvest_cycle_amount > 0.0 and harvest_cycle_interval > 0.0:
			harvest_cycle_progress += delta
			while harvest_cycle_progress >= harvest_cycle_interval:
				harvest_cycle_progress -= harvest_cycle_interval
				tank_base += harvest_cycle_amount
		else:
			tank_base += extraction_rate * delta
		_update_surges()
		return true
	if phase == Phase.SEALING:
		sealing_remaining = maxf(0.0, sealing_remaining - delta)
		if is_zero_approx(sealing_remaining):
			_complete_success()
		return true
	return false

func request_harvest() -> bool:
	if phase != Phase.EXTRACTING:
		return false
	locked_payout = floori(tank_base * multiplier + 0.000001)
	sealing_remaining = sealing_duration
	phase = Phase.SEALING
	return true

func apply_damage(target: DamageTarget, amount: float) -> bool:
	if (phase != Phase.EXTRACTING and phase != Phase.SEALING) or not is_finite(amount) or amount <= 0.0:
		return false
	if target == DamageTarget.HERO:
		hero_health = maxf(0.0, hero_health - amount)
	elif target == DamageTarget.MACHINE:
		machine_integrity = maxf(0.0, machine_integrity - amount)
	else:
		return false
	if hero_health <= 0.0:
		_fail("hero_destroyed")
	elif machine_integrity <= 0.0:
		_fail("machine_destroyed")
	return true

func abandon() -> bool:
	if phase != Phase.EXTRACTING and phase != Phase.SEALING:
		return false
	tank_base = 0.0
	locked_payout = 0
	_fail("abandoned")
	return true

func reset() -> void:
	run_id = ""
	selected_well_id = ""
	selected_hero_id = ""
	selected_module_id = ""
	phase = Phase.READY
	paused = false
	simulation_elapsed = 0.0
	tank_base = 0.0
	extraction_rate = 0.0
	pressure_time_scale = 1.0
	completed_surges = 0
	multiplier = 1.0
	locked_payout = 0
	sealing_remaining = 0.0
	sealing_duration = 0.0
	hero_health = 0.0
	machine_integrity = 0.0
	machine_max_integrity = 0.0
	terminal_reason = ""
	harvest_specialization_id = "harvest.standard"
	harvest_cycle_progress = 0.0
	harvest_cycle_amount = 0.0
	harvest_cycle_interval = 1.0
	weapon_mode_id = "weapon.standard"
	weapon_projectile_speed = BalanceData.WEAPON_PROJECTILE_SPEED

func get_terminal_result() -> Dictionary:
	if phase != Phase.SUCCESS and phase != Phase.FAILED:
		return {}
	return {
		"run_id": run_id,
		"phase": phase,
		"payout": locked_payout if phase == Phase.SUCCESS else 0,
		"completed_surges": completed_surges,
		"terminal_reason": terminal_reason,
	}

func _update_surges() -> void:
	var expected_surges: int = floori(simulation_elapsed / BalanceData.SURGE_DURATION)
	if expected_surges > completed_surges:
		completed_surges = expected_surges
		multiplier = BalanceData.multiplier_for(completed_surges)

func _complete_success() -> void:
	if phase != Phase.SEALING:
		return
	phase = Phase.SUCCESS
	terminal_reason = "sealed"

func _fail(reason: String) -> void:
	phase = Phase.FAILED
	paused = false
	terminal_reason = reason
	locked_payout = 0
