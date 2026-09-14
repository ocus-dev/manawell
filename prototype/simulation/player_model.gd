extends RefCounted
## Exact domain economy; deliberately approximate, calibratable combat/decisions.
const Account = preload("res://scripts/model/account_state.gd")
const Run = preload("res://scripts/model/run_state.gd")
const Research = preload("res://scripts/model/research_resolver.gd")
const Catalog = preload("res://scripts/model/research_catalog.gd")
const Production = preload("res://scripts/model/production.gd")
const Loadout = preload("res://scripts/model/loadout.gd")
const Campaign = preload("res://scripts/model/campaign_state.gd")
const Definitions = preload("res://data/campaign_definitions.gd")
const Encounters = preload("res://data/campaign_encounters.gd")
const Balance = preload("res://data/balance.gd")
const Combat = preload("res://simulation/experiments/combat_model.gd")
const XP = preload("res://simulation/experiments/xp_model.gd")

const MILESTONES = ["first_extraction", "first_research", "passive_income", "fan", "well_2", "specialization", "three_surges", "well_3", "boss", "all_core_research"]
var account = Account.new()
var campaign = Campaign.new()
var rng = RandomNumberGenerator.new()
var config: Dictionary
var profile: Dictionary
var wall := 0.0
var attended := 0.0
var session := 0.0
var milestones: Dictionary = {}
var events: Array = []
var runs: Array = []
var failures := 0
var active_income := 0.0
var passive_income := 0.0
var skill := 1.0
var player_id := 0
var keep_events := true
var active_stage_override: Dictionary = {}
var charged_specializations: Dictionary = {}
var xp := 0
var xp_milestones: Dictionary = {}
var xp_model = XP.new()
var combat_model = Combat.new()
var combat_state: Dictionary = {}
var research_spent := 0.0
var specialization_spent := 0.0

func merge_overrides(target: Dictionary, patch: Dictionary) -> void:
	for key in patch.keys():
		if target.get(key) is Dictionary and patch[key] is Dictionary:
			merge_overrides(target[key], patch[key])
		else:
			target[key] = patch[key]

func simulate(settings: Dictionary, persona: Dictionary, id: int, trace: bool = true) -> Dictionary:
	config = settings.duplicate(true)
	account = Account.new()
	campaign = Campaign.new()
	profile = persona
	if persona.has("experiment_overrides"):
		merge_overrides(config, persona.experiment_overrides)
	xp_model = XP.new(config.get("xp_settings", {}))
	player_id = id
	keep_events = trace
	wall = 0.0
	attended = 0.0
	session = 0.0
	milestones = {}
	events = []
	runs = []
	failures = 0
	active_income = 0.0
	passive_income = 0.0
	charged_specializations = {}
	xp = 0
	research_spent = 0.0
	specialization_spent = 0.0
	xp_milestones = {}
	rng.seed = int(config.seed) + id * 1000003
	skill = clampf(rng.randfn(float(profile.skill), float(config.combat.skill_spread)), 0.2, 2.0)
	var attempts := 0
	while wall < float(config.horizon_seconds) and attempts < int(config.max_attempts):
		assign_guard("")
		if session >= float(profile.session_seconds):
			var gap := minf(float(profile.absence_seconds), float(config.horizon_seconds) - wall)
			advance_clock(gap, "", true)
			session = 0.0
			if wall >= float(config.horizon_seconds):
				break
		var overhead := minf(float(profile.menu_seconds), float(config.horizon_seconds) - wall)
		advance_clock(overhead, "")
		if wall >= float(config.horizon_seconds):
			break
		buy_research()
		var node := choose_node()
		attempts += 1
		encounter(node)
		if milestones.has("boss") and milestones.has("all_core_research"):
			break
	return {"id": id, "profile": profile.name, "experiment": profile.get("experiment", "baseline"), "skill": skill, "milestones": milestones, "xp_milestones": xp_milestones, "xp": xp_model.total_xp(), "xp_enabled": xp_model.is_enabled(), "level": xp_model.current_level(), "research_spent": research_spent, "specialization_spent": specialization_spent, "attempts": attempts, "failures": failures, "active_income": active_income, "passive_income": passive_income, "bank": account.bank, "research_ranks": account.research_ranks, "wall_seconds": wall, "attended_seconds": attended, "end_reason": "complete" if milestones.has("boss") and milestones.has("all_core_research") else "horizon" if wall >= float(config.horizon_seconds) else "attempt_limit", "runs": runs, "events": events}

func mark(key: String) -> void:
	if not milestones.has(key):
		milestones[key] = {"wall_seconds": wall, "attended_seconds": attended}
		log_event("milestone", {"name": key})

func log_event(kind: String, data: Dictionary) -> void:
	if keep_events:
		var row := data.duplicate(true)
		row.merge({"kind": kind, "wall_seconds": wall, "attended_seconds": attended, "bank": account.bank})
		events.append(row)

func assign_guard(active_well: String) -> void:
	if not account.has_hero("hero_2"):
		return
	for well in account.content_catalog.well_ids():
		account.recall_guard(well)
	var best := ""
	var output := 0.0
	for well in account.content_catalog.well_ids():
		var value: float = account.content_catalog.get_well(well).base_output
		if account.is_well_commissioned(well) and well != active_well and value > output:
			best = well
			output = value
	if not best.is_empty():
		if account.assign_guard("hero_2", best):
			mark("passive_income")

func advance_clock(seconds: float, active_well: String, offline: bool = false) -> void:
	var rates: Dictionary = Production.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades, active_well, account.research_ranks)
	var eligible := minf(seconds, Production.MAX_OFFLINE_SECONDS) if offline else seconds
	var earned: float = Production.total_for_elapsed(eligible, rates) * float(config.get("passive_income_multiplier", 1.0))
	account.bank += earned
	passive_income += earned
	wall += seconds
	if not offline:
		attended += seconds
		session += seconds
	if offline:
		log_event("absence", {"seconds": seconds, "eligible_seconds": eligible, "income": earned})

func buy_research() -> void:
	# Sequential saving policy: do not spend a reserved budget on cheaper alternatives.
	var order := ["weapon.damage", "harvest.amount", "weapon.shots", "weapon.rate", "harvest.cadence", "weapon.velocity"]
	if profile.purchase_style == "production":
		order = ["harvest.amount", "harvest.cadence", "weapon.damage", "weapon.shots", "weapon.rate", "weapon.velocity"]
	for round_index in range(3):
		for key in order:
			var definition: Dictionary = Catalog.TRACKS[key]
			var current := int(account.research_ranks.get(key, 0))
			if current > round_index or current >= int(definition.max_rank):
				continue
			if not purchase_research(key, current):
				update_choices()
				return
			mark("first_research")
			log_event("purchase", {"track": key, "rank": current + 1, "cost": definition.ranks[current].cost})
	update_choices()
	mark("all_core_research")

func update_choices() -> void:
	if account.equip_research_choice("weapon.fan"):
		mark("fan")
	# Runtime equips specializations for free once prerequisites are met.
	# Catalog UNLOCKS costs are NOT charged by current AccountState.
	var specialization := str(profile.specialization)
	if account.equip_research_choice(specialization) and specialization != "harvest.standard":
		var unlock: Dictionary = Catalog.UNLOCKS.get(specialization, {})
		var cost := float(unlock.get("cost", 0)) * float(config.get("specialization_cost_multiplier", 0.0))
		if cost <= 0.0 or charged_specializations.has(specialization) or account.bank >= cost:
			if cost > 0.0 and not charged_specializations.has(specialization):
				account.bank -= cost
				specialization_spent += cost
				charged_specializations[specialization] = true
			mark("specialization")
		else:
			account.equipped_harvester_id = "harvest.standard"

func purchase_research(research_id: String, rank: int) -> bool:
	var definition: Dictionary = Catalog.TRACKS[research_id]
	var base_cost := float(definition.ranks[rank].cost)
	var multipliers: Array = config.get("research_rank_cost_multipliers", [1.0, 1.0, 1.0])
	var multiplier := float(multipliers[min(rank, multipliers.size() - 1)]) if not multipliers.is_empty() else 1.0
	var cost := base_cost * multiplier
	if account.bank < cost:
		return false
	if not account.purchase_research(research_id, rank, int(base_cost)):
		return false
	# AccountState deducted the authored cost; deduct the experiment delta here.
	account.bank -= cost - base_cost
	research_spent += cost
	return true

func choose_node() -> Dictionary:
	var nodes: Array = Definitions.ACTS[0].nodes
	var frontier: Dictionary = nodes[-1]
	for node in nodes:
		if not campaign.completed_nodes.has("act_01/" + str(node.id)):
			frontier = node
			break
	var farms: Array = []
	for node in nodes:
		if node.type == "well" and account.is_well_commissioned(str(node.well_id)):
			farms.append(node)
	if not farms.is_empty() and (milestones.has("boss") or rng.randf() > float(profile.push_probability)):
		return farms[-1]
	return frontier

func encounter(node: Dictionary) -> void:
	var well_id: String = str(node.get("well_id", ""))
	assign_guard(well_id)
	var is_well: bool = node.type == "well"
	var state = Run.new()
	var run_id: String = account.allocate_run_id()
	var loadout := str(profile.loadout) if account.is_well_commissioned("well_2") else "standard"
	var mods: Dictionary = Loadout.modifiers(loadout)
	var weapon: Dictionary = Research.resolve_weapon(account.research_ranks, account.equipped_weapon_mode_id)
	var derived: Dictionary = xp_model.derived_stats({"attack_damage": weapon.damage, "max_health": Balance.HERO_HEALTH})
	weapon.damage = derived.attack_damage
	var settings: Dictionary = Encounters.for_node(str(node.id), str(node.type)).duplicate(true)
	active_stage_override = config.get("stage_overrides", {}).get(str(node.id), {})
	if not active_stage_override.is_empty():
		if active_stage_override.has("waves"):
			settings["waves"] = scaled_waves(settings.get("waves", []), active_stage_override.get("waves"))
	if is_well:
		var base: float = account.content_catalog.get_well(well_id).base_output
		var harvest: Dictionary = Research.resolve_harvest(base, account.research_ranks, mods.extraction_multiplier, account.equipped_harvester_id)
		state.start(run_id, well_id, "hero_1", loadout, harvest.mean_output_per_second, Balance.SEALING_DURATION * harvest.sealing_multiplier, Balance.HERO_HEALTH, Balance.MACHINE_INTEGRITY * mods.machine_integrity_multiplier, mods.pressure_time_scale * harvest.pressure_multiplier, account.equipped_harvester_id, harvest.cycle_amount, harvest.cycle_interval)
	else:
		state.start_combat(run_id, "hero_1", "standard", int(settings.reward))
	state.hero_health = float(derived.max_health)
	combat_state = combat_model.begin({"is_well": is_well, "assumptions": {"travel_seconds": float(config.combat.get("projectile_travel_seconds", 0.15)), "contact_delay": float(config.combat.travel_seconds), "contact_chance": clampf(float(config.combat.contact_probability_per_second) / skill, 0.0, 1.0), "hero_uptime": minf(skill, 1.0), "fan_coverage": float(config.combat.fan_extra_hit_fraction), "pulse_use": float(config.combat.pulse_efficiency)}}, {"damage": weapon.damage, "attack_interval": weapon.attack_interval, "projectile_count": weapon.projectile_count, "hero_health": state.hero_health, "machine_integrity": state.machine_integrity, "pulse_damage": Balance.PULSE_DAMAGE, "pulse_cooldown": Balance.PULSE_COOLDOWN}, int(config.seed) + player_id * 1000003 + account.run_sequence * 7919)
	var target := maxi(1, int(profile.target_surges) + rng.randi_range(-1, 1))
	var start_wall := wall
	var start_passive := passive_income
	var elapsed := 0.0
	var spawn_clock := 0.0
	var spawn_index := 0
	var wave := 0
	var enemies: Array = []
	var stopped := false
	while state.phase == Run.Phase.EXTRACTING or state.phase == Run.Phase.SEALING:
		if wall >= float(config.horizon_seconds):
			stopped = true
			break
		var dt := minf(float(config.tick_seconds), float(config.horizon_seconds) - wall)
		# Expose sealing risk before completing its final timer tick.
		if is_well:
			spawn_clock += dt
			var rule: Dictionary = account.content_catalog.spawn_rule_for_tier(state.completed_surges)
			var interval := float(rule.spawn_interval)
			if state.completed_surges >= 4:
				interval = maxf(0.4, 1.5 * pow(0.9, state.completed_surges - 4))
			interval *= float(account.content_catalog.get_well(well_id).spawn_interval_factor)
			if loadout == "overdrive":
				interval *= 0.8
			while spawn_clock >= interval:
				spawn_clock -= interval
				var kind := "pursuer"
				if state.completed_surges > 0:
					if spawn_index % 4 == int(rule.get("ranged_cycle", -1)):
						kind = "ranged"
					elif spawn_index % 4 == int(rule.get("breaker_cycle", -1)):
						kind = "breaker"
				spawn_index += 1
				if enemies.size() < Balance.MAX_LIVE_ENEMIES:
					enemies.append(enemy(kind, settings))
		elif enemies.is_empty():
			if wave >= settings.waves.size():
				state.complete_combat()
				break
			for kind in settings.waves[wave]:
				enemies.append(enemy(kind, settings))
			wave += 1
		if str(config.get("combat_model", "discrete")) == "legacy":
			combat_tick(state, enemies, weapon, dt, settings, well_id)
		else:
			var hero_before: float = combat_state.incoming_hero_damage
			var machine_before: float = combat_state.incoming_machine_damage
			for foe in enemies:
				foe.damage = float(foe.get("base_damage", foe.damage)) * (float(account.content_catalog.get_well(well_id).enemy_damage_factor) * (1.0 + 0.15 * maxi(0, state.completed_surges - 4)) if is_well else 1.0)
			var kills: Array = combat_model.step_external(combat_state, enemies, dt)
			state.apply_damage(Run.DamageTarget.HERO, float(combat_state.incoming_hero_damage) - hero_before)
			state.apply_damage(Run.DamageTarget.MACHINE, float(combat_state.incoming_machine_damage) - machine_before)
			for kill in kills:
				xp_model.record_kill_event(run_id + "/kill/" + str(kill.id), str(kill.kind))
		if state.phase != Run.Phase.FAILED:
			state.advance(dt)
			if is_well:
				state.multiplier = configured_multiplier(state.completed_surges)
		elapsed += dt
		advance_clock(dt, well_id)
		update_xp_milestones()
		if is_well and state.phase == Run.Phase.EXTRACTING and state.completed_surges >= 1:
			var health_fraction := minf(state.hero_health / float(derived.max_health), state.machine_integrity / state.machine_max_integrity)
			if state.completed_surges >= target or health_fraction <= float(profile.retreat_health):
				state.request_harvest()
	var success: bool = state.phase == Run.Phase.SUCCESS
	var payout := 0
	if success:
		var started: bool = campaign.start_node("act_01", str(node.id))
		var result: Dictionary = state.get_terminal_result()
		var committed: bool = started and campaign.commit_terminal_result(result, account)
		assert(committed, "Simulator attempted an illegal campaign transition")
		payout = int(result.payout)
		active_income += payout
		if is_well:
			mark("first_extraction")
			if well_id != "well_1":
				mark(well_id)
			if state.completed_surges >= 3:
				mark("three_surges")
		if node.type == "boss":
			mark("boss")
		xp_model.record_completion_event(run_id + "/complete", "well" if is_well else "boss" if node.type == "boss" else "level", true, state.multiplier)
		update_xp_milestones()
	elif not stopped:
		failures += 1
	var row := {"node": node.id, "success": success, "censored": stopped, "duration": wall - start_wall, "target_surges": target, "surges": state.completed_surges, "multiplier": state.multiplier, "tank": state.tank_base, "payout": payout, "passive_income": passive_income - start_passive, "hero_health": state.hero_health, "machine_integrity": state.machine_integrity, "loadout": loadout, "specialization": account.equipped_harvester_id, "wall_seconds": wall}
	runs.append(row)
	log_event("run", row)
	row["level_end"] = xp_model.current_level()
	row["xp_end"] = xp_model.total_xp()
	row["kills"] = combat_state.kills
	row["attended_seconds"] = attended
	row["hero_max_health"] = derived.max_health
	row["projectile_damage"] = weapon.damage

func update_xp_milestones() -> void:
	for level in xp_model.reached_milestones():
		if not xp_milestones.has(str(level)):
			xp_milestones[str(level)] = {"wall_seconds": wall, "attended_seconds": attended}

func grant_xp(amount: int) -> void:
	var before := xp
	xp += amount
	for threshold in [10, 25, 50, 100]:
		if before < threshold and xp >= threshold and not xp_milestones.has(str(threshold)):
			xp_milestones[str(threshold)] = {"wall_seconds": wall, "attended_seconds": attended}
			log_event("xp_milestone", {"threshold": threshold})

func enemy(kind: String, settings: Dictionary) -> Dictionary:
	var hp := Balance.PURSUER_HEALTH
	var damage := Balance.PURSUER_DAMAGE
	var interval := Balance.MELEE_ATTACK_INTERVAL
	if kind == "breaker":
		hp = Balance.BREAKER_HEALTH
		damage = Balance.BREAKER_DAMAGE
	elif kind == "ranged":
		hp = Balance.RANGED_HEALTH
		damage = Balance.RANGED_DAMAGE
		interval = Balance.RANGED_ATTACK_INTERVAL
	elif kind == "boss":
		hp = float(settings.boss_health)
		damage = float(settings.boss_attack_damage)
		interval = float(settings.boss_attack_interval)
	var hp_scale := float(active_stage_override.get("hp_multiplier", config.get("combat", {}).get("hp_multiplier", 1.0)))
	var damage_scale := float(active_stage_override.get("damage_multiplier", config.get("combat", {}).get("damage_multiplier", 1.0)))
	return {"kind": kind, "hp": hp * hp_scale, "damage": damage * damage_scale, "base_damage": damage * damage_scale, "interval": interval, "age": 0.0}

func scaled_waves(source: Array, override) -> Array:
	var result: Array = []
	if override is Array:
		for i in range(source.size()):
			var count: int = int(override[min(i, override.size() - 1)]) if not override.is_empty() else source[i].size()
			result.append(repeated_wave(source[i], count))
	else:
		for wave in source:
			result.append(repeated_wave(wave, int(ceil(float(wave.size()) * float(override)))))
	return result

func repeated_wave(wave: Array, count: int) -> Array:
	var result: Array = []
	if wave.is_empty():
		return result
	for i in range(maxi(0, count)):
		result.append(wave[i % wave.size()])
	return result

func configured_multiplier(surges: int) -> float:
	if surges < 5 or not config.has("post_surge_four_increment"):
		return Balance.multiplier_for(surges)
	return float(config.get("post_surge_four_base", 2.5)) + float(surges - 4) * float(config.post_surge_four_increment)

func combat_tick(state, enemies: Array, weapon: Dictionary, dt: float, _settings: Dictionary, well: String) -> void:
	# Surrogate: continuous effective DPS and stochastic contacts, not movement AI.
	var extra_hits := minf(float(weapon.projectile_count - 1), float(maxi(0, enemies.size() - 1))) * float(config.combat.fan_extra_hit_fraction)
	var damage_budget := float(weapon.damage) * float(weapon.attacks_per_second) * (1.0 + extra_hits) * minf(skill, 1.0) * dt
	damage_budget += Balance.PULSE_DAMAGE / Balance.PULSE_COOLDOWN * float(config.combat.pulse_efficiency) * dt
	while damage_budget > 0.0 and not enemies.is_empty():
		var used := minf(damage_budget, float(enemies[0].hp))
		enemies[0].hp -= used
		damage_budget -= used
		if enemies[0].hp <= 0.0:
			enemies.pop_front()
	for foe in enemies:
		foe.age += dt
		if foe.age < float(config.combat.travel_seconds):
			continue
		var hazard := float(config.combat.contact_probability_per_second) / skill / float(foe.interval)
		if rng.randf() < 1.0 - exp(-hazard * dt):
			var factor := 1.0
			if not well.is_empty():
				factor = float(account.content_catalog.get_well(well).enemy_damage_factor) * (1.0 + 0.15 * maxi(0, state.completed_surges - 4))
			var target := Run.DamageTarget.MACHINE if foe.kind == "breaker" and not well.is_empty() else Run.DamageTarget.HERO
			state.apply_damage(target, float(foe.damage) * factor)
			if state.phase == Run.Phase.FAILED:
				break
