extends RefCounted
class_name SimulationXPModel

## Opt-in XP experiment for the pacing simulator.
##
## This module intentionally has no dependency on the live account or run
## models. Kill XP is committed when the kill event arrives; completion XP is
## committed only for a successful terminal encounter. The event ledger is
## part of the serializable state so replayed events cannot award twice.

signal xp_awarded(event: Dictionary)
signal level_changed(event: Dictionary)
signal milestone_reached(event: Dictionary)

const STATE_SCHEMA_VERSION := 1
const EPSILON := 0.000001

const DEFAULT_SETTINGS := {
	"enabled": false,
	"default_kill_xp": 0.0,
	"kill_xp_by_enemy": {},
	"default_completion_xp": 0.0,
	"completion_xp_by_encounter": {},
	"leveling": {
		"first_level_xp": 100.0,
		"curve": "linear",
		"growth": 1.0,
		"max_level": 50,
	},
	"stat_bonuses": {},
	"milestone_levels": [],
	"power_weights": {},
}

## Conservative starting-point hypotheses, not approved balance values.
## They are deliberately separate from DEFAULT_SETTINGS and remain opt-in.
const CONSERVATIVE_HYPOTHESIS_SETTINGS := {
	"enabled": true,
	"default_kill_xp": 8.0,
	"kill_xp_by_enemy": {
		"pursuer": 8.0,
		"ranged": 12.0,
		"breaker": 18.0,
		"boss": 100.0,
	},
	"default_completion_xp": 60.0,
	"completion_xp_by_encounter": {
		"well": 60.0,
		"level": 90.0,
		"boss": 180.0,
	},
	"leveling": {
		"first_level_xp": 100.0,
		"curve": "linear",
		"growth": 1.0,
		"max_level": 50,
	},
	"stat_bonuses": {
		"attack_damage": {"per_level": 0.01, "mode": "fraction", "curve": "linear", "growth": 1.0},
		"max_health": {"per_level": 2.0, "mode": "flat", "curve": "linear", "growth": 1.0},
	},
	"milestone_levels": [2, 5, 10, 20],
	"power_weights": {"attack_damage": 0.7, "max_health": 0.3},
}

var settings: Dictionary
var persistent_kill_xp := 0.0
var persistent_completion_xp := 0.0

var _processed_event_ids: Dictionary = {}
var _milestones_reached: Dictionary = {}
var _milestone_events: Array = []
var _current_level := 1

func _init(experiment_settings: Dictionary = {}) -> void:
	settings = _merge_settings(default_settings(), experiment_settings)
	_current_level = level_for_xp(0.0)

static func default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)

static func conservative_hypothesis_settings() -> Dictionary:
	return CONSERVATIVE_HYPOTHESIS_SETTINGS.duplicate(true)

func is_enabled() -> bool:
	return bool(settings.get("enabled", false))

func total_xp() -> float:
	return persistent_kill_xp + persistent_completion_xp

func kill_xp() -> float:
	return persistent_kill_xp

func completion_xp() -> float:
	return persistent_completion_xp

func current_level() -> int:
	return _current_level

func level_for_xp(xp: float) -> int:
	if not is_finite(xp) or xp <= 0.0:
		return 1
	var leveling: Dictionary = settings.get("leveling", {})
	var max_level := maxi(1, int(leveling.get("max_level", 50)))
	var resolved := 1
	for candidate in range(2, max_level + 1):
		if xp + EPSILON >= xp_required_for_level(candidate):
			resolved = candidate
		else:
			break
	return resolved

func xp_required_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	var leveling: Dictionary = settings.get("leveling", {})
	var first := maxf(0.0, float(leveling.get("first_level_xp", 100.0)))
	var step := float(level - 1)
	var curve := str(leveling.get("curve", "linear"))
	var growth := float(leveling.get("growth", 1.0))
	match curve:
		"quadratic":
			return first * step * step
		"geometric":
			if is_equal_approx(growth, 1.0):
				return first * step
			return first * (pow(maxf(0.0, growth), step) - 1.0) / (growth - 1.0)
		"linear":
			return first * step
		_:
			return first * step

func xp_to_next_level() -> Variant:
	var leveling: Dictionary = settings.get("leveling", {})
	var max_level := maxi(1, int(leveling.get("max_level", 50)))
	if _current_level >= max_level:
		return null
	return maxf(0.0, xp_required_for_level(_current_level + 1) - total_xp())

func progress_to_next_level() -> float:
	var needed = xp_to_next_level()
	if needed == null:
		return 1.0
	var previous := xp_required_for_level(_current_level)
	var next := xp_required_for_level(_current_level + 1)
	if next <= previous:
		return 1.0
	return clampf((total_xp() - previous) / (next - previous), 0.0, 1.0)

## Award persistent XP for a defeated enemy. This is intentionally independent
## of whether the enclosing run later succeeds, fails, or is abandoned.
func record_kill_event(event_id: String, enemy_kind: String, enemy_level: int = 1, xp_override: float = -1.0, metadata: Dictionary = {}) -> Dictionary:
	var amount := maxf(0.0, xp_override) if xp_override >= 0.0 else _configured_kill_xp(enemy_kind)
	return _record_award(event_id, "kill", amount, {"enemy_kind": enemy_kind, "enemy_level": maxi(1, enemy_level)}, metadata)

## Award completion XP only after a successful terminal encounter. The
## extraction/mana multiplier is accepted for integration-call compatibility,
## recorded for audit, and deliberately does not affect XP.
func record_completion_event(event_id: String, encounter_kind: String, successful: bool, extraction_multiplier: float = 1.0, xp_override: float = -1.0, metadata: Dictionary = {}) -> Dictionary:
	if not _claim_event_id(event_id):
		return _ignored_event(event_id, "duplicate_event")
	if not successful:
		return _ignored_event(event_id, "encounter_failed", {"encounter_kind": encounter_kind, "extraction_multiplier_ignored": extraction_multiplier})
	var amount := maxf(0.0, xp_override) if xp_override >= 0.0 else _configured_completion_xp(encounter_kind)
	return _award_claimed_event(event_id, "completion", amount, {"encounter_kind": encounter_kind, "extraction_multiplier_ignored": extraction_multiplier}, metadata)

func on_enemy_defeated(event_id: String, enemy_kind: String, enemy_level: int = 1, xp_override: float = -1.0, metadata: Dictionary = {}) -> Dictionary:
	return record_kill_event(event_id, enemy_kind, enemy_level, xp_override, metadata)

func on_encounter_completed(event_id: String, encounter_kind: String, successful: bool, extraction_multiplier: float = 1.0, xp_override: float = -1.0, metadata: Dictionary = {}) -> Dictionary:
	return record_completion_event(event_id, encounter_kind, successful, extraction_multiplier, xp_override, metadata)

## No clock-based or automatic offline XP exists in this experiment. An
## explicit call returns a rejection so an integration cannot accidentally
## turn offline time into progression.
func record_offline_xp(_event_id: String, _seconds: float) -> Dictionary:
	return {"accepted": false, "awarded": 0.0, "reason": "offline_xp_disabled"}

func derived_stats(base_stats: Dictionary) -> Dictionary:
	var result := base_stats.duplicate(true)
	for stat in settings.get("stat_bonuses", {}):
		if not result.has(stat):
			continue
		var rule: Dictionary = settings.stat_bonuses[stat]
		var levels_gained := maxi(0, _current_level - 1)
		var curve_total := _curve_total(levels_gained, str(rule.get("curve", "linear")), float(rule.get("growth", 1.0)))
		var bonus := float(rule.get("per_level", 0.0)) * curve_total
		var base := float(result[stat])
		if str(rule.get("mode", "flat")) == "fraction":
			result[stat] = base * (1.0 + bonus)
		else:
			result[stat] = base + bonus
	return result

func power_snapshot(base_stats: Dictionary) -> Dictionary:
	var stats := derived_stats(base_stats)
	return {
		"level": _current_level,
		"total_xp": total_xp(),
		"kill_xp": persistent_kill_xp,
		"completion_xp": persistent_completion_xp,
		"stats": stats,
		"power_index": power_index(base_stats, stats),
	}

func power_index(base_stats: Dictionary, resolved_stats: Dictionary = {}) -> float:
	var stats := resolved_stats if not resolved_stats.is_empty() else derived_stats(base_stats)
	var weights: Dictionary = settings.get("power_weights", {})
	if weights.is_empty():
		return 1.0
	var weighted := 0.0
	var total_weight := 0.0
	for stat in weights:
		var weight := maxf(0.0, float(weights[stat]))
		var baseline := float(base_stats.get(stat, 0.0))
		if weight <= 0.0 or is_zero_approx(baseline):
			continue
		weighted += weight * float(stats.get(stat, baseline)) / baseline
		total_weight += weight
	return weighted / total_weight if total_weight > 0.0 else 1.0

## Compare a model where XP is newly added with a second model where an
## equivalent progression budget is redistributed from existing progression.
## The caller supplies the two model states; this module does not change mana
## or decide how a redistribution is funded.
static func compare_progression_power(base_stats: Dictionary, added_progression, redistributed_progression) -> Dictionary:
	var baseline := _weighted_power(base_stats, base_stats, added_progression.settings.get("power_weights", {}))
	var added: Dictionary = added_progression.power_snapshot(base_stats)
	var redistributed: Dictionary = redistributed_progression.power_snapshot(base_stats)
	return {
		"baseline_power_index": baseline,
		"added_power_index": added.power_index,
		"redistributed_power_index": redistributed.power_index,
		"added_delta": added.power_index - baseline,
		"redistributed_delta": redistributed.power_index - baseline,
		"added_minus_redistributed": added.power_index - redistributed.power_index,
	}

func milestone_events() -> Array:
	return _milestone_events.duplicate(true)

func reached_milestones() -> Array:
	var result: Array = _milestones_reached.keys()
	result.sort()
	return result

func capture_state() -> Dictionary:
	var event_ids: Array = _processed_event_ids.keys()
	event_ids.sort()
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"kill_xp": persistent_kill_xp,
		"completion_xp": persistent_completion_xp,
		"processed_event_ids": event_ids,
		"milestones_reached": reached_milestones(),
		"milestone_events": _milestone_events.duplicate(true),
	}

func restore_state(state: Dictionary) -> bool:
	if int(state.get("schema_version", -1)) != STATE_SCHEMA_VERSION:
		return false
	var restored_kill := float(state.get("kill_xp", -1.0))
	var restored_completion := float(state.get("completion_xp", -1.0))
	if not is_finite(restored_kill) or not is_finite(restored_completion) or restored_kill < 0.0 or restored_completion < 0.0:
		return false
	persistent_kill_xp = restored_kill
	persistent_completion_xp = restored_completion
	_processed_event_ids.clear()
	for event_id in state.get("processed_event_ids", []):
		if str(event_id).is_empty():
			return false
		_processed_event_ids[str(event_id)] = true
	_milestones_reached.clear()
	for milestone in state.get("milestones_reached", []):
		_milestones_reached[int(milestone)] = true
	_milestone_events = state.get("milestone_events", []).duplicate(true)
	_current_level = level_for_xp(total_xp())
	return true

func _record_award(event_id: String, award_type: String, amount: float, details: Dictionary, metadata: Dictionary) -> Dictionary:
	if not _claim_event_id(event_id):
		return _ignored_event(event_id, "duplicate_event")
	return _award_claimed_event(event_id, award_type, amount, details, metadata)

func _award_claimed_event(event_id: String, award_type: String, amount: float, details: Dictionary, metadata: Dictionary) -> Dictionary:
	var event := details.duplicate(true)
	event.merge(metadata.duplicate(true))
	event.merge({"event_id": event_id, "event_type": award_type, "awarded": 0.0, "accepted": false})
	if not is_enabled():
		event["reason"] = "experiment_disabled"
		return event
	var safe_amount := maxf(0.0, amount) if is_finite(amount) else 0.0
	var level_before := _current_level
	if award_type == "kill":
		persistent_kill_xp += safe_amount
	else:
		persistent_completion_xp += safe_amount
	event["awarded"] = safe_amount
	event["accepted"] = true
	event["total_xp"] = total_xp()
	_refresh_level(level_before)
	event["level"] = _current_level
	xp_awarded.emit(event.duplicate(true))
	return event

func _claim_event_id(event_id: String) -> bool:
	if event_id.is_empty() or _processed_event_ids.has(event_id):
		return false
	_processed_event_ids[event_id] = true
	return true

func _ignored_event(event_id: String, reason: String, details: Dictionary = {}) -> Dictionary:
	var result := details.duplicate(true)
	result.merge({"event_id": event_id, "awarded": 0.0, "accepted": false, "reason": reason, "total_xp": total_xp(), "level": _current_level})
	return result

func _refresh_level(level_before: int) -> void:
	_current_level = level_for_xp(total_xp())
	if _current_level == level_before:
		return
	var level_event := {"level_before": level_before, "level": _current_level, "total_xp": total_xp()}
	level_changed.emit(level_event.duplicate(true))
	for level in range(level_before + 1, _current_level + 1):
		if not _configured_milestones().has(level) or _milestones_reached.has(level):
			continue
		_milestones_reached[level] = true
		var milestone_event := {"level": level, "total_xp": total_xp()}
		_milestone_events.append(milestone_event.duplicate(true))
		milestone_reached.emit(milestone_event.duplicate(true))

func _configured_milestones() -> Array:
	var levels: Array = []
	for value in settings.get("milestone_levels", []):
		var level := int(value)
		if level > 1 and not levels.has(level):
			levels.append(level)
	levels.sort()
	return levels

func _configured_kill_xp(enemy_kind: String) -> float:
	var values: Dictionary = settings.get("kill_xp_by_enemy", {})
	return maxf(0.0, float(values.get(enemy_kind, settings.get("default_kill_xp", 0.0))))

func _configured_completion_xp(encounter_kind: String) -> float:
	var values: Dictionary = settings.get("completion_xp_by_encounter", {})
	return maxf(0.0, float(values.get(encounter_kind, settings.get("default_completion_xp", 0.0))))

static func _weighted_power(base_stats: Dictionary, resolved_stats: Dictionary, weights: Dictionary) -> float:
	if weights.is_empty():
		return 1.0
	var weighted := 0.0
	var total_weight := 0.0
	for stat in weights:
		var weight := maxf(0.0, float(weights[stat]))
		var baseline := float(base_stats.get(stat, 0.0))
		if weight <= 0.0 or is_zero_approx(baseline):
			continue
		weighted += weight * float(resolved_stats.get(stat, baseline)) / baseline
		total_weight += weight
	return weighted / total_weight if total_weight > 0.0 else 1.0

func _curve_total(levels_gained: int, curve: String, growth: float) -> float:
	var levels := maxf(0.0, float(levels_gained))
	match curve:
		"quadratic":
			return levels * levels
		"diminishing":
			return sqrt(levels)
		"geometric":
			if is_equal_approx(growth, 1.0):
				return levels
			return (pow(maxf(0.0, growth), levels) - 1.0) / (growth - 1.0)
		"linear":
			return levels
		_:
			return levels

static func _merge_settings(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides:
		if result.get(key) is Dictionary and overrides[key] is Dictionary:
			result[key] = _merge_settings(result[key], overrides[key])
		else:
			result[key] = overrides[key]
	return result
