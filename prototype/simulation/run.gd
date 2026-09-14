extends SceneTree
const Model = preload("res://simulation/player_model.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario := "res://simulation/scenario.json"
	var output := "res://../work/simulation/latest"
	if args.size() > 0:
		scenario = args[0]
	if args.size() > 1:
		output = args[1]
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(scenario)) != OK or not parser.data is Dictionary:
		push_error("Invalid scenario JSON: " + scenario)
		quit(1)
		return
	var settings: Dictionary = parser.data
	settings = expand_experiments(settings)
	var error := validate(settings)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	var players: Array = []
	for p in range(settings.profiles.size()):
		var profile: Dictionary = settings.profiles[p]
		for i in range(int(settings.players_per_profile)):
			var model = Model.new()
			# Same player seed across profiles supports controlled comparisons.
			players.append(model.simulate(settings, profile, i, i < 3))
		print("Simulated %s: %d players" % [profile.name, settings.players_per_profile])
	var summaries := summarize(players, settings)
	var stage_summaries := summarize_stages(players, settings)
	var xp_summary := summarize_xp(players)
	var manifest: Dictionary = {}
	for path in ["data/balance.gd", "data/campaign_definitions.gd", "data/campaign_encounters.gd", "scripts/model/run_state.gd", "scripts/model/account_state.gd", "scripts/model/campaign_state.gd", "scripts/model/content_catalog.gd", "scripts/model/campaign_catalog.gd", "scripts/model/research_catalog.gd", "scripts/model/research_resolver.gd", "scripts/model/production.gd", "scripts/model/loadout.gd", "simulation/player_model.gd", "simulation/run.gd", "simulation/experiments/combat_model.gd", "simulation/experiments/xp_model.gd"]:
		manifest[path] = FileAccess.get_sha256("res://" + path)
	var result := {"schema_version": 2, "status": "UNCALIBRATED MODEL ESTIMATES", "engine": Engine.get_version_info().string, "scenario": settings, "source_sha256": manifest, "summary": summaries, "stage_summary": stage_summaries, "xp_summary": xp_summary, "players": players, "payout_curve": payout_curve(), "assumptions": ["Combat uses discrete attacks and configurable contact assumptions, not movement or collision fidelity.", "Milestone times are conditional on reaching the milestone; completion fraction includes censored players.", "First-boss 45–60 attended-minute target is an experiment goal, not an achieved promise.", "Whole-tank repricing is the primary payout candidate; marginal production is not enabled by default."]}
	var destination := ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		push_error("Cannot create report directory")
		quit(1)
		return
	if not write_file(destination.path_join("results.json"), JSON.stringify(result, "\t")) or not write_file(destination.path_join("milestones.csv"), csv(summaries)) or not write_file(destination.path_join("report.html"), html_report(result)):
		quit(1)
		return
	print("Report: " + destination.path_join("report.html"))
	quit(0)

static func validate(s: Dictionary) -> String:
	for key in ["seed", "players_per_profile", "horizon_seconds", "max_attempts", "tick_seconds", "combat", "profiles"]:
		if not s.has(key):
			return "Missing scenario field: " + key
	for key in ["seed", "players_per_profile", "horizon_seconds", "max_attempts", "tick_seconds"]:
		if not (s[key] is float or s[key] is int) or not is_finite(float(s[key])):
			return "Invalid numeric field: " + key
	if s.players_per_profile < 1 or s.players_per_profile > 10000 or fmod(float(s.players_per_profile), 1.0) != 0.0 or s.max_attempts < 1 or s.max_attempts > 10000 or fmod(float(s.max_attempts), 1.0) != 0.0:
		return "Player and attempt counts must be integers in 1..10000"
	if s.tick_seconds < 0.05 or s.tick_seconds > 1.0 or s.horizon_seconds <= 0 or s.horizon_seconds > 2592000:
		return "Tick must be 0.05..1 seconds; horizon must be positive and <=30 days"
	if not s.combat is Dictionary or not s.profiles is Array or s.profiles.is_empty():
		return "Combat must be an object and profiles a nonempty array"
	if s.get("xp_enabled", false) and not FileAccess.file_exists("res://simulation/experiments/xp_model.gd"):
		return "XP is enabled but simulation/experiments/xp_model.gd is unavailable"
	for key in ["passive_income_multiplier", "specialization_cost_multiplier", "post_surge_four_increment"]:
		if s.has(key) and (not (s[key] is float or s[key] is int) or not is_finite(float(s[key])) or float(s[key]) < 0):
			return "Invalid pacing override: " + key
	if s.has("research_rank_cost_multipliers") and (not s.research_rank_cost_multipliers is Array or s.research_rank_cost_multipliers.is_empty()):
		return "Research rank multipliers must be a nonempty array"
	for key in ["contact_probability_per_second", "skill_spread", "pulse_efficiency", "fan_extra_hit_fraction", "travel_seconds"]:
		if not s.combat.has(key) or not (s.combat[key] is float or s.combat[key] is int) or not is_finite(float(s.combat[key])) or float(s.combat[key]) < 0:
			return "Invalid combat assumption: " + key
	var names: Dictionary = {}
	for p in s.profiles:
		if not p is Dictionary:
			return "Profiles must be objects"
		for key in ["name", "skill", "target_surges", "retreat_health", "push_probability", "menu_seconds", "session_seconds", "absence_seconds", "purchase_style", "loadout", "specialization"]:
			if not p.has(key):
				return "Missing profile field: " + key
		if not p.name is String or p.name.is_empty() or names.has(p.name):
			return "Profile names must be unique nonempty strings"
		names[p.name] = true
		for key in ["skill", "target_surges", "retreat_health", "push_probability", "menu_seconds", "session_seconds", "absence_seconds"]:
			if not (p[key] is float or p[key] is int) or not is_finite(float(p[key])) or float(p[key]) < 0:
				return "Invalid profile number: " + key
		if p.skill <= 0 or p.target_surges < 1 or p.target_surges > 50 or fmod(float(p.target_surges), 1.0) != 0 or p.retreat_health > 1 or p.push_probability > 1 or p.session_seconds <= 0:
			return "Profile skill/session must be positive; surge target integer 1..50; probabilities 0..1"
		if not p.purchase_style in ["balanced", "production"] or not p.loadout in ["standard", "fortified", "overdrive"] or not p.specialization in ["harvest.rapid_seal", "harvest.deep_draw", "harvest.standard"]:
			return "Unknown purchase style, loadout, or specialization"
	return ""

static func expand_experiments(source: Dictionary) -> Dictionary:
	if not source.has("experiments"):
		return source
	var result := source.duplicate(true)
	var base_profiles: Array = result.profiles.duplicate(true)
	var expanded: Array = []
	for experiment in source.experiments:
		for profile in base_profiles:
			var candidate: Dictionary = profile.duplicate(true)
			candidate.name = str(experiment.name) + "/" + str(profile.name)
			candidate.experiment = str(experiment.name)
			candidate.experiment_overrides = experiment.get("overrides", {}).duplicate(true)
			expanded.append(candidate)
	result.profiles = expanded
	return result

static func merge_dict(target: Dictionary, patch: Dictionary) -> void:
	for key in patch.keys():
		if target.get(key) is Dictionary and patch[key] is Dictionary:
			merge_dict(target[key], patch[key])
		else:
			target[key] = patch[key]

static func percentile(values: Array, fraction: float):
	if values.is_empty():
		return null
	var sorted := values.duplicate()
	sorted.sort()
	var index := (sorted.size() - 1) * fraction
	return lerpf(float(sorted[floori(index)]), float(sorted[ceili(index)]), index - floorf(index))

static func summarize(players: Array, settings: Dictionary) -> Array:
	var result: Array = []
	for profile in settings.profiles:
		var cohort := players.filter(func(p): return p.profile == profile.name)
		for milestone in Model.MILESTONES:
			var walls: Array = []
			var active: Array = []
			var total := 0.0
			for player in cohort:
				if player.milestones.has(milestone):
					var point: Dictionary = player.milestones[milestone]
					walls.append(point.wall_seconds)
					active.append(point.attended_seconds)
					total += point.wall_seconds
			result.append({"profile": profile.name, "milestone": milestone, "reached": walls.size(), "players": cohort.size(), "completion_rate": float(walls.size()) / cohort.size(), "mean_wall_seconds_reached": total / walls.size() if not walls.is_empty() else null, "p10_wall_seconds_reached": percentile(walls, 0.1), "p50_wall_seconds_reached": percentile(walls, 0.5), "p90_wall_seconds_reached": percentile(walls, 0.9), "p50_attended_seconds_reached": percentile(active, 0.5)})
	return result

static func summarize_stages(players: Array, settings: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for player in players:
		for run in player.runs:
			var key := str(player.profile) + "|" + str(run.node)
			if not seen.has(key):
				seen[key] = {"profile": player.profile, "stage": run.node, "durations": [], "successes": 0, "failures": 0, "censored": 0, "payouts": []}
			var row: Dictionary = seen[key]
			row.durations.append(run.duration)
			if run.success:
				row.successes += 1
				row.payouts.append(run.payout)
			elif run.censored:
				row.censored += 1
			else:
				row.failures += 1
	for row in seen.values():
		var durations: Array = row.durations
		var payouts: Array = row.payouts
		var total := durations.size()
		result.append({"profile": row.profile, "stage": row.stage, "attempts": total, "success_rate": float(row.successes) / total, "failure_rate": float(row.failures) / total, "censor_rate": float(row.censored) / total, "mean_duration_seconds": durations.reduce(func(a, b): return a + b, 0.0) / total, "p10_duration_seconds": percentile(durations, 0.1), "p50_duration_seconds": percentile(durations, 0.5), "p90_duration_seconds": percentile(durations, 0.9), "payout_p50": percentile(payouts, 0.5), "payout_p90": percentile(payouts, 0.9)})
	return result

static func summarize_xp(players: Array) -> Array:
	var result: Array = []
	var groups: Dictionary = {}
	for player in players:
		var profile := str(player.profile)
		if not groups.has(profile):
			groups[profile] = {"profile": profile, "players": 0, "xp_enabled": false, "milestones": {}}
		var group: Dictionary = groups[profile]
		group.players += 1
		group.xp_enabled = bool(player.get("xp_enabled", false))
		for threshold in player.xp_milestones.keys():
			group.milestones[threshold] = int(group.milestones.get(threshold, 0)) + 1
	result.append_array(groups.values())
	return result

static func payout_curve() -> Array:
	var rows: Array = []
	for seconds in [19, 20, 39, 40, 59, 60, 79, 80, 100, 120, 160, 200]:
		var run = Model.Run.new()
		run.start("curve", "well_1")
		run.advance(seconds)
		run.request_harvest()
		rows.append({"seconds": seconds, "surges": run.completed_surges, "multiplier": run.multiplier, "payout": run.locked_payout, "mana_per_minute_including_seal": run.locked_payout * 60.0 / (seconds + run.sealing_duration)})
	return rows

static func csv(rows: Array) -> String:
	var fields := ["profile", "milestone", "reached", "players", "completion_rate", "mean_wall_seconds_reached", "p10_wall_seconds_reached", "p50_wall_seconds_reached", "p90_wall_seconds_reached", "p50_attended_seconds_reached"]
	var lines := [",".join(fields)]
	for row in rows:
		var cells := PackedStringArray()
		for key in fields:
			cells.append("\"" + (str(row[key]) if row[key] != null else "").replace("\"", "\"\"") + "\"")
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"

static func minutes(value) -> String:
	return "—" if value == null else "%.1f" % (float(value) / 60.0)

static func html_report(result: Dictionary) -> String:
	var html := "<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Telos pacing simulation</title><style>body{font:16px system-ui;background:#101923;color:#e6edf3;max-width:1200px;margin:40px auto;padding:0 24px}h1,h2{color:#75dfd0}p{line-height:1.6;max-width:950px}.notice{border-left:4px solid #ffcd70;padding:16px;background:#24303b}table{border-collapse:collapse;width:100%;margin:24px 0}th,td{text-align:left;padding:10px;border-bottom:1px solid #354451}th{color:#a9bdce}svg{background:#172531;max-width:100%;height:auto}a{color:#75dfd0}.scroll{overflow:auto}</style><h1>Telos · player pacing laboratory</h1><p class='notice'><b>Uncalibrated model estimates.</b> Economy uses the current game code. Combat and player decisions are assumptions, not observed average-player behavior. No equipment, loot, platform movement, exact targeting, dash AI, or player learning is simulated. Discrete attacks and the optional XP model are integrated.</p>"
	html += "<p>Seed %d · %d players per profile · %.1f-hour horizon. Percentiles and means include only players who reached a milestone; completion rates include everyone. Attended time includes menus and encounters. Absences count only toward wall time. Sessions finish their current encounter before leaving.</p>" % [result.scenario.seed, result.scenario.players_per_profile, result.scenario.horizon_seconds / 3600.0]
	html += "<h2>The reward jump from staying longer</h2><p>Unupgraded Intake Well, successful sealing, no combat losses. These values are generated by RunState. The multiplier revalues the entire tank at withdrawal; it is not a permanent production-rate increase.</p><svg viewBox='0 0 760 250' role='img' aria-label='Successful payout versus extraction duration'>"
	var points := PackedStringArray()
	for point in result.payout_curve:
		var x: float = 50.0 + point.seconds * 3.2
		var y := 205.0 - float(point.payout) / 12.0
		points.append("%.1f,%.1f" % [x, y])
		html += "<circle cx='%.1f' cy='%.1f' r='4' fill='#ffcd70'><title>%ds: %d mana</title></circle>" % [x, y, point.seconds, point.payout]
	html += "<polyline points='%s' fill='none' stroke='#75dfd0' stroke-width='2'/><text x='50' y='235' fill='white'>0</text><text x='650' y='235' fill='white'>200 seconds</text><text x='50' y='20' fill='white'>Banked mana (0–2,200); sampled points connected</text></svg>" % " ".join(points)
	html += "<div class='scroll'><table><tr><th>Stay seconds</th><th>Surges</th><th>Multiplier</th><th>Payout</th><th>Mana/min incl. sealing</th></tr>"
	for row in result.payout_curve:
		html += "<tr><td>%d</td><td>%d</td><td>%.2f×</td><td>%d</td><td>%.1f</td></tr>" % [row.seconds, row.surges, row.multiplier, row.payout, row.mana_per_minute_including_seal]
	html += "</table></div><h2>Milestone distributions</h2><p>All times below are minutes. Profile differences combine skill, attendance, risk, purchases, and loadout; they do not isolate the causal effect of risk alone.</p>"
	for profile in result.scenario.profiles:
		html += "<h3>%s</h3><p>Target %d surges ±1 · session %.0f min · absence %.0f min · skill %.2f · retreat at %.0f%% health · %s</p>" % [str(profile.name).xml_escape(), profile.target_surges, profile.session_seconds / 60.0, profile.absence_seconds / 60.0, profile.skill, profile.retreat_health * 100.0, str(profile.loadout).xml_escape()]
		var failures := 0
		var attempts := 0
		var active := 0.0
		var passive := 0.0
		var payouts: Array = []
		var rates: Array = []
		for player in result.players:
			if player.profile == profile.name:
				failures += player.failures
				attempts += player.attempts
				active += player.active_income
				passive += player.passive_income
				for run in player.runs:
					if not run.censored and run.node in ["act_01_node_02", "act_01_node_05", "act_01_node_08"]:
						payouts.append(run.payout)
						rates.append(float(run.payout) * 60.0 / maxf(0.001, run.duration))
		html += "<p>%d failed runs / %d attempts (includes unfinished attempts). Passive share of earned mana: %.1f%%.</p>" % [failures, attempts, 100.0 * passive / maxf(1.0, passive + active)]
		if not payouts.is_empty():
			html += "<p>Extraction payout P10 / median / P90: <b>%.0f / %.0f / %.0f mana</b>. Median / P90 extraction income: <b>%.0f / %.0f mana per minute</b>. Includes failed extractions as zero; excludes menus and passive income. Mixes wells and research stages.</p>" % [percentile(payouts, 0.1), percentile(payouts, 0.5), percentile(payouts, 0.9), percentile(rates, 0.5), percentile(rates, 0.9)]
		html += "<div class='scroll'><table><tr><th>Milestone</th><th>Reached</th><th>Mean wall</th><th>P10 wall</th><th>Median wall</th><th>P90 wall</th><th>Median attended</th></tr>"
		for row in result.summary:
			if row.profile == profile.name:
				html += "<tr><td>%s</td><td>%d/%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % [str(row.milestone).xml_escape(), row.reached, row.players, minutes(row.mean_wall_seconds_reached), minutes(row.p10_wall_seconds_reached), minutes(row.p50_wall_seconds_reached), minutes(row.p90_wall_seconds_reached), minutes(row.p50_attended_seconds_reached)]
		html += "</table></div>"
	html += "<h2>Stage comparison</h2><div class='scroll'><table><tr><th>Profile / stage</th><th>Attempts</th><th>Success</th><th>Failure</th><th>Censored</th><th>Duration P10 / P50 / P90</th><th>Payout P50 / P90</th></tr>"
	for row in result.stage_summary:
		html += "<tr><td>%s / %s</td><td>%d</td><td>%.0f%%</td><td>%.0f%%</td><td>%.0f%%</td><td>%.1f / %.1f / %.1f min</td><td>%.0f / %.0f</td></tr>" % [str(row.profile).xml_escape(), str(row.stage).xml_escape(), row.attempts, row.success_rate * 100.0, row.failure_rate * 100.0, row.censor_rate * 100.0, row.p10_duration_seconds / 60.0, row.p50_duration_seconds / 60.0, row.p90_duration_seconds / 60.0, row.payout_p50 if row.payout_p50 != null else 0, row.payout_p90 if row.payout_p90 != null else 0]
	html += "</table></div><h2>XP and calibration limits</h2><p>XP is disabled in baseline. Enabled XP packages retain kill XP after failure, award completion XP only on success, and apply level bonuses to damage and health at the next encounter. Milestone counts refer to character levels.</p>"
	for row in result.xp_summary:
		html += "<p>%s: XP %s; milestone counts %s.</p>" % [str(row.profile).xml_escape(), "enabled" if row.xp_enabled else "disabled", str(row.milestones)]
	html += "<h2>Reproduce and calibrate</h2><p>results.json contains the complete scenario, source hashes, every player outcome, detailed stage summaries, and event traces for the first three players per profile. milestones.csv provides the aggregate table. Specializations currently equip for free after prerequisites unless the experiment charges the catalog unlock cost; passive income currently uses displacement, not cadence. These results are uncalibrated model estimates, not average-player measurements.</p><p><a href='results.json'>Raw results</a> · <a href='milestones.csv'>Milestone data</a></p></html>"
	return html

static func write_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return false
	file.store_string(contents)
	return true

