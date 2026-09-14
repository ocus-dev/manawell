extends SceneTree
const Model = preload("res://simulation/player_model.gd")
const Report = preload("res://simulation/run.gd")
var checks := 0
var failed_checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed_checks += 1
		push_error(message)

func _init() -> void:
	var scenario: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://simulation/scenario.json"))
	check(Report.validate(scenario).is_empty(), "Default scenario validates")
	var bad := scenario.duplicate(true)
	bad.tick_seconds = 0
	check(not Report.validate(bad).is_empty(), "Reject nonadvancing clock")
	bad = scenario.duplicate(true)
	bad.profiles[0].skill = "invalid"
	check(not Report.validate(bad).is_empty(), "Reject malformed skill")
	# Whole-tank multiplier, sealing freeze and loss of locked reward.
	var state = Model.Run.new()
	state.start("boundary")
	state.advance(59)
	check(is_equal_approx(state.tank_base * state.multiplier, 177.0), "59 seconds earns 118 x 1.5")
	state.advance(1)
	state.request_harvest()
	check(state.locked_payout == 240, "60-second boundary reprices the full tank")
	state.advance(1)
	check(state.tank_base == 120 and state.locked_payout == 240, "Sealing adds no income")
	state.apply_damage(Model.Run.DamageTarget.HERO, 1000)
	check(state.get_terminal_result().payout == 0, "Sealing death forfeits tank")
	# Native cycle counting and pressure affect different clocks.
	state = Model.Run.new()
	state.start("pressure", "well_1", "hero_1", "standard", 2, 2, 100, 150, 1.25, "harvest.standard", 2, 1)
	state.advance(16)
	state.request_harvest()
	check(state.completed_surges == 1 and state.locked_payout == 40, "Pressure speeds surge clock but does not create extra extraction cycles")
	# Guard allocation, active-well exclusion, cadence exclusion and offline cap.
	var model = Model.new()
	model.account.commissioned_wells = {"well_1": true}
	model.account.roster_heroes["hero_2"] = true
	model.account.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	model.assign_guard("")
	model.advance_clock(60, "")
	check(is_equal_approx(model.account.bank, 30), "Hero 2 first-well rate")
	model.account.research_ranks["harvest.cadence"] = 3
	model.advance_clock(60, "")
	check(is_equal_approx(model.account.bank, 60), "Cadence does not affect current passive implementation")
	model.advance_clock(60, "well_1")
	check(is_equal_approx(model.account.bank, 60), "Active well cannot earn passive income")
	model.advance_clock(172800, "", true)
	check(is_equal_approx(model.account.bank, 43260), "Offline credit caps at 24h")
	check(model.attended == 180 and model.wall == 172980, "Separate attended and wall clocks")
	# Same seed reproduces outcomes and event traces.
	scenario.horizon_seconds = 2000
	scenario.max_attempts = 30
	var first: Dictionary = Model.new().simulate(scenario, scenario.profiles[1], 42)
	var repeat: Dictionary = Model.new().simulate(scenario, scenario.profiles[1], 42)
	check(JSON.stringify(first) == JSON.stringify(repeat), "Deterministic seeded replay")
	var spent := 0.0
	for key in first.research_ranks:
		for rank_index in range(int(first.research_ranks[key])):
			spent += float(Model.Catalog.TRACKS[key].ranks[rank_index].cost)
	check(is_equal_approx(first.bank + spent, first.active_income + first.passive_income), "Whole-player economy conserves currency")
	# Censoring is not success and missing milestones do not become zero times.
	scenario.horizon_seconds = 1
	var censored: Dictionary = Model.new().simulate(scenario, scenario.profiles[1], 42)
	check(censored.milestones.is_empty() and censored.wall_seconds == 1 and censored.end_reason == "horizon", "Short horizon stays censored")
	var summaries: Array = Report.summarize([censored], {"profiles": [scenario.profiles[1]]})
	check(summaries[0].completion_rate == 0 and summaries[0].p50_wall_seconds_reached == null, "Unreached outcomes included in denominator with null time")
	check(Report.percentile([10, 20, 30], 0.5) == 20, "Percentile interpolation")
	# Forced dangerous encounter loses its tank and never commissions.
	model = Model.new()
	model.config = scenario.duplicate(true)
	model.config.horizon_seconds = 500
	model.config.combat.contact_probability_per_second = 1000
	model.config.combat.travel_seconds = 0
	model.profile = scenario.profiles[2]
	model.skill = 0.01
	model.rng.seed = 5
	model.encounter(Model.Definitions.ACTS[0].nodes[1])
	check(model.failures == 1 and model.active_income == 0 and model.account.commissioned_wells.is_empty(), "Failed extraction cannot award or commission")
	print("pacing_simulation: %d/%d checks passed" % [checks - failed_checks, checks])
	quit(1 if failed_checks else 0)
