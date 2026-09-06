class_name UiViewState
extends RefCounted

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const ProductionScript = preload("res://scripts/model/production.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")

static func build(account: RefCounted, run_state: RefCounted, selected_well_id: String = "well_1", notices: Dictionary = {}, ability_state: Dictionary = {}) -> Dictionary:
	var catalog: RefCounted = account.content_catalog if account != null and account.get("content_catalog") != null else ContentCatalogScript.new()
	var destination_id: String = selected_well_id if catalog.has_well(selected_well_id) else "well_1"
	var active_run: bool = run_state != null and (run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING)
	var active_well_id: String = run_state.selected_well_id if active_run else ""
	var rates: Dictionary = ProductionScript.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades, active_well_id)
	var wells: Array[Dictionary] = []
	for well_id in catalog.well_ids():
		wells.append(_well_view(account, catalog, well_id, rates, destination_id, active_well_id))
	var heroes: Array[Dictionary] = []
	for hero_id in catalog.hero_ids():
		if account.has_hero(hero_id):
			heroes.append(_hero_view(account, catalog, hero_id))
	var terminal_result: Dictionary = run_state.get_terminal_result() if run_state != null else {}
	var run_reward: int = int(terminal_result.get("payout", 0))
	var expedition: Dictionary = _expedition_view(account, catalog, destination_id, run_state)
	return {
		"operations": {
			"id": "operations",
			"banked_mana": account.bank,
			"passive_rate_per_minute": _total_rate_per_minute(rates),
			"passive_rates_per_minute": _rates_per_minute(rates),
			"selected_destination_id": destination_id,
			"wells": wells,
			"heroes": heroes,
			"expedition": expedition,
			"research": _research_view(account, catalog, run_state),
		},
		"combat": _combat_view(run_state, catalog, active_run, ability_state),
		"results": {
			"phase": int(run_state.phase) if run_state != null else RunStateScript.Phase.READY,
			"run_id": str(terminal_result.get("run_id", "")),
			"actual_run_reward": run_reward,
			"outcome": "Harvest secured" if run_state != null and run_state.phase == RunStateScript.Phase.SUCCESS else "Extraction lost" if run_state != null and run_state.phase == RunStateScript.Phase.FAILED else "",
			"amount_label": "%d mana banked" % run_reward if run_state != null and run_state.phase == RunStateScript.Phase.SUCCESS else "0 mana lost" if run_state != null and run_state.phase == RunStateScript.Phase.FAILED else "",
			"reward_source": "run",
			"terminal_reason": str(terminal_result.get("terminal_reason", "")),
			"completed_surges": int(run_state.completed_surges) if run_state != null else 0,
			"can_retry": run_state != null and (run_state.phase == RunStateScript.Phase.SUCCESS or run_state.phase == RunStateScript.Phase.FAILED),
			"passive_rate_per_minute": _total_rate_per_minute(rates),
		},
		"notices": {
			"save_failure": str(notices.get("save_failure", "")),
			"recovery": str(notices.get("recovery", "")),
			"offline": str(notices.get("offline", "")),
			"assignment": str(notices.get("assignment", "")),
			"pending_save": bool(notices.get("pending_save", false)),
			"offline_pending_total": float(notices.get("offline_pending_total", 0.0)),
		},
	}

static func _research_view(account: RefCounted, catalog: RefCounted, run_state: RefCounted) -> Dictionary:
	var active_run: bool = run_state != null and (run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING)
	var upgrades: Array[Dictionary] = []
	for upgrade_id in catalog.upgrade_ids():
		var definition: Dictionary = catalog.get_upgrade(upgrade_id)
		var cost: int = int(definition.get("cost", 0))
		var owned: bool = account.has_upgrade(upgrade_id)
		var amount_needed: int = maxi(0, cost - int(account.bank))
		var available: bool = not active_run and not owned and amount_needed == 0
		var reason: String = "Owned" if owned else "Unavailable during extraction." if active_run else "Need %d more mana." % amount_needed if amount_needed > 0 else "Ready to purchase."
		upgrades.append({
			"id": upgrade_id,
			"label": str(definition.get("label", upgrade_id)),
			"effect": str(definition.get("effect", "")),
			"cost": cost,
			"owned": owned,
			"available": available,
			"amount_needed": amount_needed,
			"availability_reason": reason,
		})
	return {
		"banked_mana": float(account.bank),
		"passive_rate_per_minute": _total_rate_per_minute(ProductionScript.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades)),
		"upgrades": upgrades,
	}

static func _expedition_view(account: RefCounted, catalog: RefCounted, destination_id: String, run_state: RefCounted) -> Dictionary:
	var well_definition: Dictionary = catalog.get_well(destination_id)
	var selected_loadout_id: String = account.get_loadout_for_well(destination_id)
	var well_commissioned: bool = account.is_well_commissioned(destination_id)
	var well_2_commissioned: bool = account.is_well_commissioned("well_2")
	var loadouts: Array[Dictionary] = []
	for loadout_id in LoadoutScript.IDS:
		var available: bool = well_commissioned and LoadoutScript.is_available(loadout_id, well_2_commissioned)
		loadouts.append({
			"id": loadout_id,
			"label": LoadoutScript.label(loadout_id),
			"summary": LoadoutScript.summary(loadout_id),
			"selected": loadout_id == selected_loadout_id,
			"available": available,
			"availability_reason": "Commission this well first." if not well_commissioned else "Commission Well 2 to unlock this loadout." if not LoadoutScript.is_available(loadout_id, well_2_commissioned) else "Ready.",
		})
	var active_hero_id: String = account.get_active_hero_id()
	var guard_id: String = account.get_guard_for_well(destination_id)
	var ready: bool = run_state == null or run_state.phase == RunStateScript.Phase.READY or run_state.phase == RunStateScript.Phase.SUCCESS or run_state.phase == RunStateScript.Phase.FAILED
	var start_available: bool = ready and well_commissioned and not active_hero_id.is_empty() and LoadoutScript.is_available(selected_loadout_id, well_2_commissioned)
	var disabled_reason: String = ""
	if not ready:
		disabled_reason = "Finish the current extraction before starting another."
	elif not well_commissioned:
		disabled_reason = "Commission this well through a qualifying harvest first."
	elif active_hero_id.is_empty():
		disabled_reason = "Choose an expedition hero first."
	elif not LoadoutScript.is_available(selected_loadout_id, well_2_commissioned):
		disabled_reason = "Choose an available harvester loadout."
	return {
		"active_hero_id": active_hero_id,
		"active_hero_label": _hero_label(catalog, active_hero_id),
		"capability_summary": "Ready for active expeditions." if not active_hero_id.is_empty() else "No expedition hero selected.",
		"destination_id": destination_id,
		"destination_label": str(well_definition.get("label", destination_id)),
		"base_extraction_rate": float(well_definition.get("base_output", 0.0)),
		"threat_summary": "Threat interval x%.2f · damage x%.2f" % [float(well_definition.get("spawn_interval_factor", 1.0)), float(well_definition.get("enemy_damage_factor", 1.0))],
		"loadout_id": selected_loadout_id,
		"loadouts": loadouts,
		"start_available": start_available,
		"start_disabled_reason": disabled_reason,
		"guard_warning": "Starting here recalls %s and stops this well's passive income." % _hero_label(catalog, guard_id) if not guard_id.is_empty() else "",
	}

static func _well_view(account: RefCounted, catalog: RefCounted, well_id: String, rates: Dictionary, destination_id: String, active_well_id: String) -> Dictionary:
	var definition: Dictionary = catalog.get_well(well_id)
	var unlocked: bool = account.is_well_unlocked(well_id)
	var commissioned: bool = account.is_well_commissioned(well_id)
	var guard_id: String = account.get_guard_for_well(well_id)
	var active_here: bool = well_id == active_well_id
	var rate: float = float(rates.get(well_id, 0.0)) * 60.0
	var state_id: String = "locked"
	var state_label: String = "Locked"
	var availability_reason: String = "Unlock this well through a qualifying harvest."
	if unlocked and not commissioned:
		state_id = "available"
		state_label = "Available"
		availability_reason = "Complete a qualifying harvest first."
	elif commissioned:
		state_id = "commissioned"
		state_label = "Commissioned"
		availability_reason = "Ready to operate."
	if active_here:
		state_id = "active"
		state_label = "Extracting"
		availability_reason = "You are here; passive production is paused at this site."
	return {
		"id": well_id,
		"label": str(definition.get("label", well_id)),
		"state_id": state_id,
		"state_label": state_label,
		"unlocked": unlocked,
		"commissioned": commissioned,
		"available": unlocked and commissioned and not active_here,
		"availability_reason": availability_reason,
		"selected": well_id == destination_id,
		"prepare_available": unlocked and not active_here,
		"activity_label": "You are here · %s" % _hero_label(catalog, account.get_active_hero_id()) if active_here else "",
		"passive_rate_per_minute": rate if commissioned and not active_here else 0.0,
		"guard": {
			"id": guard_id,
			"label": _hero_label(catalog, guard_id) if not guard_id.is_empty() else "Assign guard",
			"role_label": "Guard" if not guard_id.is_empty() else "Unstaffed",
			"assigned": not guard_id.is_empty(),
		},
	}

static func _hero_view(account: RefCounted, catalog: RefCounted, hero_id: String) -> Dictionary:
	var role: String = account.get_hero_role(hero_id)
	var role_label: String = "Expedition hero" if role == "active" else "Guard" if role == "guard" else "Reserve"
	var reason: String = "Available to assign." if role == "reserve" else role_label
	if role == "guard":
		for well_id in catalog.well_ids():
			if account.get_guard_for_well(well_id) == hero_id:
				reason = "Guarding %s - recall there first." % str(catalog.get_well(well_id).get("label", well_id))
	return {
		"id": hero_id,
		"label": _hero_label(catalog, hero_id),
		"role_id": role,
		"role_label": role_label,
		"availability_reason": reason,
		"available_for_guard": role == "reserve",
	}

static func _combat_view(run_state: RefCounted, catalog: RefCounted, active_run: bool, ability_state: Dictionary = {}) -> Dictionary:
	if run_state == null:
		return {"active": false, "phase": RunStateScript.Phase.READY}
	var next_surge: float = 0.0
	if run_state.phase == RunStateScript.Phase.EXTRACTING:
		next_surge = maxf(0.0, (BalanceData.SURGE_DURATION - fmod(run_state.simulation_elapsed, BalanceData.SURGE_DURATION)) / run_state.pressure_time_scale)
	var at_risk: int = floori(run_state.tank_base * run_state.multiplier) if run_state.phase == RunStateScript.Phase.EXTRACTING else run_state.locked_payout
	return {
		"active": active_run,
		"phase": int(run_state.phase),
		"paused": run_state.paused,
		"well_id": run_state.selected_well_id,
		"hero_id": run_state.selected_hero_id,
		"hero_label": _hero_label(catalog, run_state.selected_hero_id),
		"hero_health": run_state.hero_health,
		"hero_max_health": BalanceData.HERO_HEALTH,
		"harvester_integrity": run_state.machine_integrity,
		"harvester_max_integrity": run_state.machine_max_integrity,
		"completed_surges": run_state.completed_surges,
		"multiplier": run_state.multiplier,
		"next_surge_seconds": next_surge,
		"pressure_time_scale": run_state.pressure_time_scale,
		"threat_label": "Surge pressure" if active_run else "No active surge",
		"at_risk_payout": at_risk,
		"sealing_remaining": run_state.sealing_remaining,
		"sealing_duration": run_state.sealing_duration,
		"terminal_reason": run_state.terminal_reason,
		"abilities": {
			"dash_cooldown_remaining": float(ability_state.get("dash_cooldown_remaining", 0.0)),
			"pulse_cooldown_remaining": float(ability_state.get("pulse_cooldown_remaining", 0.0)),
			"dash_cooldown": BalanceData.DASH_COOLDOWN,
			"pulse_cooldown": BalanceData.PULSE_COOLDOWN,
		},
	}

static func _hero_label(catalog: RefCounted, hero_id: String) -> String:
	if hero_id.is_empty():
		return ""
	return str(catalog.get_hero(hero_id).get("label", hero_id))

static func _rates_per_minute(rates: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for well_id in rates.keys():
		result[str(well_id)] = float(rates[well_id]) * 60.0
	return result

static func _total_rate_per_minute(rates: Dictionary) -> float:
	var total: float = 0.0
	for rate in rates.values():
		total += float(rate) * 60.0
	return total