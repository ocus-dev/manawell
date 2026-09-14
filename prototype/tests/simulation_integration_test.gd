extends SceneTree
const Model = preload("res://simulation/player_model.gd")
const Report = preload("res://simulation/run.gd")
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _init() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://simulation/scenario.json"))
	base.horizon_seconds = 1200
	base.max_attempts = 20
	base.tick_seconds = 0.1
	var neutral := base.duplicate(true)
	neutral.xp_settings = {"enabled": false}
	neutral.research_rank_cost_multipliers = [1,1,1]
	neutral.specialization_cost_multiplier = 0
	neutral.passive_income_multiplier = 1
	neutral.post_surge_four_increment = 0.5
	neutral.stage_overrides = {}
	var a: Dictionary = Model.new().simulate(base, base.profiles[1], 0)
	var b: Dictionary = Model.new().simulate(neutral, neutral.profiles[1], 0)
	check(JSON.stringify(a) == JSON.stringify(b), "Neutral overrides and XP disabled preserve outcomes exactly")
	var with_xp := base.duplicate(true)
	with_xp.xp_settings = Model.XP.conservative_hypothesis_settings()
	var c: Dictionary = Model.new().simulate(with_xp, base.profiles[1], 0)
	check(c.xp > 0 and c.level > 1 and not c.xp_milestones.is_empty(), "Real XP model awards kills, levels and milestones")
	var changed_stats := false
	for run in c.runs:
		changed_stats = changed_stats or run.hero_max_health > Model.Balance.HERO_HEALTH
	check(changed_stats, "Level bonuses reach encounter health")
	check(base.get("xp_settings", {}).is_empty(), "Scenario inputs not mutated")
	var model = Model.new()
	model.config = {"research_rank_cost_multipliers": [1,2,4], "specialization_cost_multiplier": 1}
	model.profile = base.profiles[1]
	model.account.bank = 2000
	check(model.purchase_research("weapon.damage", 0), "Rank one buys")
	check(model.purchase_research("weapon.damage", 1), "Rank two buys")
	check(model.account.bank == 1780 and model.research_spent == 220, "Scaled rank price debited exactly")
	model.account.research_ranks["harvest.cadence"] = 2
	model.update_choices()
	var bank_after: float = model.account.bank
	model.update_choices()
	check(model.specialization_spent == 140 and model.account.bank == bank_after, "Specialization charged exactly once")
	check(model.configured_multiplier(6) == 3.5, "Baseline multiplier retained")
	model.config.post_surge_four_increment = 0.25
	check(model.configured_multiplier(6) == 3 and model.configured_multiplier(4) == 2.5, "Late multiplier change isolated")
	check(model.scaled_waves([["pursuer","ranged"]], 3)[0].size() == 6, "Stage wave expansion applied")
	model.config.combat = {}
	model.active_stage_override = {"hp_multiplier": 4, "damage_multiplier": 1.2}
	var foe: Dictionary = model.enemy("pursuer", {})
	check(foe.hp == 80 and is_equal_approx(foe.damage, 9.6), "Authored stage scaling applied")
	var experiment := base.duplicate(true)
	experiment.experiments = [{"name": "control", "overrides": {}}, {"name": "test", "overrides": {"research_rank_cost_multipliers": [1,2,4]}}]
	var expanded: Dictionary = Report.expand_experiments(experiment)
	check(expanded.profiles.size() == 6 and not base.profiles[0].has("experiment_overrides"), "Expansion preserves source persona definitions")
	for result in [a,b,c]:
		check(is_equal_approx(result.bank + result.research_spent + result.specialization_spent, result.active_income + result.passive_income), "Integrated currency conservation")
	# Failure retention and no accidental end-of-run bonus are XP module contracts.
	var xp = Model.XP.new(with_xp.xp_settings)
	xp.record_kill_event("run/kill/1", "breaker")
	xp.record_completion_event("run/end", "well", false, 99)
	check(xp.total_xp() == 18, "Kill XP retained but no failed completion XP")
	xp.record_kill_event("run/kill/1", "breaker")
	check(xp.total_xp() == 18, "Duplicate kill cannot inflate XP")
	print("simulation_integration: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
