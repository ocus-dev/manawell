extends SceneTree

const XPModel = preload("res://simulation/experiments/xp_model.gd")

var checks := 0
var failed_checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed_checks += 1
		push_error("TEST CHECK FAILED: " + message)

func _init() -> void:
	var settings := XPModel.conservative_hypothesis_settings()
	settings.leveling = {"first_level_xp": 100.0, "curve": "linear", "growth": 1.0, "max_level": 5}
	settings.milestone_levels = [2, 3]
	var model = XPModel.new(settings)
	var base_stats := {"attack_damage": 100.0, "max_health": 100.0}

	# Default-off baseline parity is explicit and does not mutate the event ledger into XP.
	var baseline = XPModel.new()
	var disabled_award: Dictionary = baseline.record_kill_event("off-kill", "pursuer")
	check(not baseline.is_enabled() and disabled_award.awarded == 0.0, "Default settings keep XP experiment off")
	check(baseline.current_level() == 1 and baseline.derived_stats(base_stats) == base_stats, "Disabled model preserves level-one stats")

	# Thresholds, overflow, additive stats and milestone emission.
	var observed_milestones: Array = []
	model.milestone_reached.connect(func(event: Dictionary): observed_milestones.append(int(event.level)))
	check(model.xp_required_for_level(1) == 0.0 and model.xp_required_for_level(2) == 100.0, "Level one and first threshold")
	check(model.xp_required_for_level(3) == 200.0, "Linear threshold curve")
	var first: Dictionary = model.record_kill_event("kill-1", "pursuer", 1, 100.0)
	check(first.awarded == 100.0 and model.current_level() == 2, "First threshold levels up")
	var second: Dictionary = model.record_completion_event("complete-1", "well", true, 1.5, 250.0)
	check(second.awarded == 250.0 and model.current_level() == 4, "Overflow crosses multiple levels")
	check(model.total_xp() == 350.0 and model.xp_to_next_level() == 50.0, "XP overflow remains banked")
	check(observed_milestones == [2, 3], "Milestones emit once while crossing levels")
	var stats: Dictionary = model.derived_stats(base_stats)
	check(is_equal_approx(float(stats.attack_damage), 103.0), "Fractional stat bonus is additive by level")
	check(is_equal_approx(float(stats.max_health), 106.0), "Flat stat bonus is additive by level")

	# Event identity deduplication and failure retention.
	var duplicate: Dictionary = model.record_kill_event("kill-1", "pursuer", 1, 999.0)
	check(duplicate.reason == "duplicate_event" and model.kill_xp() == 100.0, "Duplicate kill identity cannot award twice")
	var failed: Dictionary = model.record_completion_event("failed-run", "well", false, 4.0, 500.0)
	check(failed.reason == "encounter_failed" and model.completion_xp() == 250.0, "Failed completion awards no completion XP")
	var retained: Dictionary = model.record_kill_event("failed-kill", "breaker", 1, 18.0)
	check(retained.awarded == 18.0 and model.kill_xp() == 118.0, "Kill XP persists through failed extraction")
	var duplicate_failure: Dictionary = model.record_completion_event("failed-run", "well", true, 1.0, 500.0)
	check(duplicate_failure.reason == "duplicate_event", "Failed terminal identity cannot later replay as success")

	# Completion XP is independent of the mana/extraction multiplier.
	var multiplier_model = XPModel.new(settings)
	var normal: Dictionary = multiplier_model.record_completion_event("normal", "well", true, 1.0, 60.0)
	var boosted: Dictionary = multiplier_model.record_completion_event("boosted", "well", true, 9.0, 60.0)
	check(normal.awarded == boosted.awarded and multiplier_model.completion_xp() == 120.0, "Mana multiplier does not multiply XP")
	var offline: Dictionary = multiplier_model.record_offline_xp("offline", 86400.0)
	check(not offline.accepted and multiplier_model.total_xp() == 120.0, "Offline time awards no automatic XP")

	# Persist the ledger and restore it before replaying events.
	var restored = XPModel.new(settings)
	check(restored.restore_state(model.capture_state()), "XP state round-trips")
	var replay: Dictionary = restored.record_kill_event("kill-1", "pursuer", 1, 999.0)
	check(replay.reason == "duplicate_event" and restored.total_xp() == model.total_xp(), "Restored event ledger prevents replay")

	# Configurable curves and added-vs-redistributed comparison are integration hooks.
	var quadratic_settings := XPModel.conservative_hypothesis_settings()
	quadratic_settings.leveling = {"first_level_xp": 100.0, "curve": "quadratic", "growth": 1.0, "max_level": 5}
	var quadratic = XPModel.new(quadratic_settings)
	check(quadratic.xp_required_for_level(3) == 400.0, "Quadratic XP curve is configurable")
	var redistributed_settings := settings.duplicate(true)
	redistributed_settings.stat_bonuses.attack_damage.per_level = 0.005
	var redistributed = XPModel.new(redistributed_settings)
	redistributed.record_kill_event("redistributed", "pursuer", 1, 350.0)
	var comparison: Dictionary = XPModel.compare_progression_power(base_stats, model, redistributed)
	check(comparison.has("added_delta") and comparison.has("redistributed_delta"), "Power comparison exposes both progression cases")
	check(float(comparison.added_minus_redistributed) > 0.0, "Power comparison distinguishes added power")

	print("xp_model: %d/%d checks passed" % [checks - failed_checks, checks])
	quit(1 if failed_checks else 0)
