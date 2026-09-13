class_name UiViewState
extends RefCounted

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const BalanceData = preload("res://data/balance.gd")
const ProductionScript = preload("res://scripts/model/production.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")
const ResearchResolverScript = preload("res://scripts/model/research_resolver.gd")
const ResearchCatalogScript = preload("res://scripts/model/research_catalog.gd")
const HeroStatResolverScript = preload("res://scripts/model/hero_stat_resolver.gd")

static func build(account: RefCounted, run_state: RefCounted, selected_well_id: String = "well_1", notices: Dictionary = {}, ability_state: Dictionary = {}, campaign_state: RefCounted = null) -> Dictionary:
	var catalog: RefCounted = account.content_catalog if account != null and account.get("content_catalog") != null else ContentCatalogScript.new()
	var destination_id: String = selected_well_id if catalog.has_well(selected_well_id) else "well_1"
	var active_run: bool = run_state != null and (run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING)
	var active_well_id: String = run_state.selected_well_id if active_run else ""
	var rates: Dictionary = ProductionScript.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades, active_well_id, account.research_ranks)
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
			"research": _research_view(account, catalog, run_state, destination_id),
			"inventory": _inventory_view(account),
		},
		"combat": _combat_view(run_state, catalog, active_run, ability_state),
		"campaign": _campaign_view(account, campaign_state),
		"results": {
			"item_drops": account.item_reward_ids.duplicate() if account.item_reward_run_id == str(terminal_result.get("run_id", "")) and run_state != null and run_state.phase == RunStateScript.Phase.SUCCESS else [],
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

static func _campaign_view(account: RefCounted, campaign_state: RefCounted) -> Dictionary:
	var state: RefCounted = campaign_state if campaign_state != null else CampaignStateScript.new()
	var definitions: RefCounted = CampaignCatalogScript.new()
	var act_id: String = state.active_act_id if not state.active_act_id.is_empty() else definitions.first_act_id()
	var act: Dictionary = definitions.get_act(act_id)
	var nodes: Array = act.get("nodes", [])
	var statuses: Dictionary = {}
	var wells: Dictionary = {}
	var paths: Array[Dictionary] = []
	for node in nodes:
		var node_id: String = str(node.get("id", ""))
		statuses[node_id] = state.node_status(act_id, node_id, definitions)
		if node.get("type", "") == "well":
			var well_id: String = str(node.get("well_id", ""))
			var well_status: Dictionary = state.well_status(well_id, account)
			var rate: float = float(ProductionScript.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades).get(well_id, 0.0)) * 60.0
			well_status["rate_per_minute"] = rate
			well_status["guard_label"] = account.get_guard_for_well(well_id) if well_status.get("guarded", false) else "Unstaffed"
			well_status["indicator"] = "active" if well_status.get("active", false) else "producing" if well_status.get("producing", false) else "idle"
			wells[well_id] = well_status
	for index in range(1, nodes.size()):
		var previous_node: Dictionary = nodes[index - 1]
		var node: Dictionary = nodes[index]
		paths.append({"from": str(previous_node.get("id", "")), "to": str(node.get("id", "")), "points": [previous_node.get("position", [0.0, 0.0]), node.get("position", [0.0, 0.0])]})
	return {"act_id": act_id, "act_name": str(act.get("display_name", act_id)), "nodes": nodes, "statuses": statuses, "wells": wells, "paths": paths, "active_act_id": state.active_act_id}

static func _inventory_view(account: RefCounted) -> Dictionary:
	var items: Array[Dictionary] = []
	var catalog = preload("res://scripts/model/item_catalog.gd")
	for id in catalog.ITEMS:
		var item: Dictionary = catalog.ITEMS[id].duplicate()
		var instances: Array[Dictionary] = []
		for instance in account.item_instances.values():
			if instance.get("base_id", "") == id:
				instances.append(instance.duplicate(true))
		instances.sort_custom(func(left: Dictionary, right: Dictionary): return str(left.get("instance_id", "")) < str(right.get("instance_id", "")))
		var equipped_by: Dictionary = {}
		for hero_id in account.hero_kits:
			for slot in account.hero_kits[hero_id]:
				if str(account.hero_kits[hero_id][slot]) in instances.map(func(instance): return str(instance.get("instance_id", ""))):
					equipped_by[str(account.hero_kits[hero_id][slot])] = "%s · %s" % [str(hero_id), str(slot)]
		item.merge({"id": id, "owned": account.owned_items.has(id), "is_new": account.new_items.has(id), "source": catalog.source_for(id), "instance_count": instances.size(), "instance_ids": instances.map(func(instance): return str(instance.get("instance_id", ""))), "instances": instances, "equipped_by": equipped_by})
		items.append(item)
	var heroes: Array[Dictionary] = []
	for hero_id in account.content_catalog.hero_ids():
		if account.has_hero(hero_id):
			heroes.append({"id": hero_id, "label": _hero_label(account.content_catalog, hero_id), "kit": account.hero_kits.get(hero_id, {"weapon": "", "hero": "", "harvester": ""}).duplicate(true)})
	var selected_hero_id := str(heroes[0].get("id", "")) if not heroes.is_empty() else ""
	return {"items": items, "owned_count": account.owned_items.size(), "new_count": account.new_items.size(), "capacity": AccountStateScript.INVENTORY_CAPACITY, "stored_count": account.item_instances.size(), "heroes": heroes, "selected_hero_id": selected_hero_id, "instances": account.item_instances.duplicate(true), "ranks": account.research_ranks.duplicate(true), "hero_resolver": {"ranks": account.research_ranks.duplicate(true), "instances": account.item_instances.duplicate(true)}}

static func _research_view(account: RefCounted, catalog: RefCounted, run_state: RefCounted, well_id: String = "well_1") -> Dictionary:
	var loadout_id: String = account.get_loadout_for_well(well_id)
	var modifiers: Dictionary = LoadoutScript.modifiers(loadout_id)
	var output_factor: float = float(modifiers.get("extraction_multiplier", 1.0))
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
	var tracks: Array[Dictionary] = []
	for research_id in ResearchCatalogScript.TRACKS:
		var definition: Dictionary = ResearchCatalogScript.TRACKS[research_id]
		var current_rank := int(account.research_ranks.get(research_id, 0))
		var nodes: Array[Dictionary] = []
		for rank_index in range(definition.ranks.size()):
			var rank_data: Dictionary = definition.ranks[rank_index]
			var prerequisite: Dictionary = definition.get("prerequisite", {})
			var prerequisite_met: bool = prerequisite.is_empty() or int(account.research_ranks.get(prerequisite.get("track", ""), 0)) >= int(prerequisite.get("rank", 0))
			var available: bool = not active_run and rank_index == current_rank and prerequisite_met and account.bank >= int(rank_data.cost)
			nodes.append({"rank": rank_index + 1, "cost": int(rank_data.cost), "effect": str(rank_data.effect), "owned": rank_index < current_rank, "selected": rank_index == current_rank, "available": available, "availability_reason": "Unavailable during extraction." if active_run else "Requires %s %s." % [str(prerequisite.get("track", "")), str(prerequisite.get("rank", ""))] if not prerequisite_met else "Need %d more mana." % maxi(0, int(rank_data.cost) - int(account.bank)) if rank_index == current_rank and account.bank < int(rank_data.cost) else "Maxed." if rank_index < current_rank else "Ready to purchase."})
		tracks.append({"id": research_id, "label": str(definition.label), "group": str(definition.group), "rank": current_rank, "max_rank": int(definition.max_rank), "nodes": nodes})
	var unlocks: Array[Dictionary] = []
	for unlock_id in ResearchCatalogScript.UNLOCKS:
		var unlock: Dictionary = ResearchCatalogScript.UNLOCKS[unlock_id]
		var requirements: Array = unlock.get("prerequisites", [unlock.get("prerequisite", {})])
		var requirements_met := true
		for prerequisite in requirements:
			requirements_met = requirements_met and int(account.research_ranks.get(prerequisite.get("track", ""), 0)) >= int(prerequisite.get("rank", 0))
		unlocks.append({"id": unlock_id, "label": str(unlock.label), "cost": int(unlock.cost), "effect": str(unlock.effect), "unlocked": requirements_met, "equipped": account.equipped_harvester_id == unlock_id or account.equipped_weapon_mode_id == unlock_id})
	var harvest_preview: Dictionary = ResearchResolverScript.resolve_harvest(float(catalog.get_well(well_id).get("base_output", 0.0)), account.research_ranks, output_factor, account.equipped_harvester_id)
	var weapon_preview: Dictionary = ResearchResolverScript.resolve_weapon(account.research_ranks, account.equipped_weapon_mode_id)
	for track in tracks:
		var next_ranks: Dictionary = account.research_ranks.duplicate()
		next_ranks[track.id] = mini(int(track.rank) + 1, int(track.max_rank))
		if track.group == "harvester":
			var after: Dictionary = ResearchResolverScript.resolve_harvest(float(catalog.get_well(well_id).get("base_output", 0.0)), next_ranks, output_factor, account.equipped_harvester_id)
			track["comparison"] = "%s · %s loadout\nCurrent → next rank\nMana / cycle   %.2f → %.2f\nCycles / sec   %.2f → %.2f\nMana / sec   %.2f → %.2f\nSeal duration ×%.2f · Pressure ×%.2f" % [str(catalog.get_well(well_id).get("label", well_id)), LoadoutScript.label(loadout_id), harvest_preview.cycle_amount, after.cycle_amount, 1.0 / harvest_preview.cycle_interval, 1.0 / after.cycle_interval, harvest_preview.mean_output_per_second, after.mean_output_per_second, after.sealing_multiplier, after.pressure_multiplier]
		else:
			var after: Dictionary = ResearchResolverScript.resolve_weapon(next_ranks, account.equipped_weapon_mode_id)
			track["comparison"] = "Equipped weapon · Current → next rank\nDamage / projectile   %.2f → %.2f\nProjectiles / attack   %d → %d\nAttacks / sec   %.2f → %.2f\nProjectile speed   %.2f → %.2f" % [weapon_preview.damage, after.damage, weapon_preview.projectile_count, after.projectile_count, weapon_preview.attacks_per_second, after.attacks_per_second, weapon_preview.projectile_speed, after.projectile_speed]
			if track.id == "weapon.shots":
				track["comparison"] += "\nEquip Fan after researching to use additional projectiles."
	var choices: Array[Dictionary] = []
	for id in ["harvest.standard", "harvest.rapid_seal", "harvest.deep_draw", "weapon.standard", "weapon.fan", "weapon.lance"]:
		var requirements: Array = []
		var effect := "No specialization modifiers"
		if ResearchCatalogScript.UNLOCKS.has(id):
			var definition: Dictionary = ResearchCatalogScript.UNLOCKS[id]
			requirements = definition.get("prerequisites", [definition.get("prerequisite", {})])
			effect = str(definition.effect)
		elif id == "weapon.fan":
			requirements = [{"track": "weapon.shots", "rank": 1}]
			effect = "Spread projectiles; reduced damage per projectile"
		var missing: Array[String] = []
		for requirement in requirements:
			if int(account.research_ranks.get(requirement.track, 0)) < int(requirement.rank):
				missing.append("%s rank %d" % [ResearchCatalogScript.TRACKS[requirement.track].label, requirement.rank])
		var equipped: bool = id == account.equipped_harvester_id or id == account.equipped_weapon_mode_id
		choices.append({"id": id, "label": id.get_slice(".", 1).replace("_", " ").capitalize(), "equipped": equipped, "available": missing.is_empty() and not active_run, "reason": "Equipped" if equipped else "Finish the current run" if active_run else "Requires " + ", ".join(missing) if not missing.is_empty() else "Ready to equip", "effect": effect})
	return {
		"equipment_choices": choices,
		"banked_mana": float(account.bank),
		"passive_rate_per_minute": _total_rate_per_minute(ProductionScript.calculate_rates(account.commissioned_wells, account.hero_assignments, account.owned_upgrades, "", account.research_ranks)),
		"upgrades": upgrades,
		"tracks": tracks,
		"unlocks": unlocks,
		"harvest_preview": harvest_preview,
		"weapon_preview": weapon_preview,
	}

static func _expedition_view(account: RefCounted, catalog: RefCounted, destination_id: String, run_state: RefCounted) -> Dictionary:
	var well_definition: Dictionary = catalog.get_well(destination_id)
	var selected_loadout_id: String = account.get_loadout_for_well(destination_id)
	var unlocked: bool = account.is_well_unlocked(destination_id)
	var well_commissioned: bool = account.is_well_commissioned(destination_id)
	var first_expedition: bool = destination_id == "well_1" and account.commissioned_wells.is_empty()
	var well_2_commissioned: bool = account.is_well_commissioned("well_2")
	var loadouts: Array[Dictionary] = []
	for loadout_id in LoadoutScript.IDS:
		var available: bool = (well_commissioned or (unlocked and loadout_id == LoadoutScript.STANDARD)) and LoadoutScript.is_available(loadout_id, well_2_commissioned)
		loadouts.append({
			"id": loadout_id,
			"label": LoadoutScript.label(loadout_id),
			"summary": LoadoutScript.summary(loadout_id),
			"selected": loadout_id == selected_loadout_id,
			"available": available,
			"availability_reason": "Standard is available for this unlocked well." if unlocked and not well_commissioned and loadout_id == LoadoutScript.STANDARD else "Complete a qualifying harvest to commission this well." if not well_commissioned else "Commission Well 2 to unlock this loadout." if not LoadoutScript.is_available(loadout_id, well_2_commissioned) else "Ready.",
		})
	var active_hero_id: String = account.get_active_hero_id()
	var guard_id: String = account.get_guard_for_well(destination_id)
	var ready: bool = run_state == null or run_state.phase == RunStateScript.Phase.READY or run_state.phase == RunStateScript.Phase.SUCCESS or run_state.phase == RunStateScript.Phase.FAILED
	var standard_uncommissioned: bool = unlocked and not well_commissioned and selected_loadout_id == LoadoutScript.STANDARD
	var start_available: bool = ready and unlocked and not active_hero_id.is_empty() and (well_commissioned or standard_uncommissioned) and LoadoutScript.is_available(selected_loadout_id, well_2_commissioned)
	var disabled_reason: String = ""
	if not ready:
		disabled_reason = "Finish the current extraction before starting another."
	elif not unlocked:
		disabled_reason = "Complete a qualifying Well 1 harvest to unlock this well."
	elif not well_commissioned and not standard_uncommissioned:
		disabled_reason = "Select the Standard loadout for this well's first expedition."
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
	var first_expedition: bool = well_id == "well_1" and account.commissioned_wells.is_empty()
	var rate: float = float(rates.get(well_id, 0.0)) * 60.0
	var state_id: String = "locked"
	var state_label: String = "Locked"
	var availability_reason: String = "Reach Surge 1 (20 seconds), then complete sealing to unlock Well 2."
	if unlocked and not commissioned:
		state_id = "available"
		state_label = "Available"
		availability_reason = "Reach Surge 1 (20 seconds), then complete sealing to commission this well."
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
		"start_available": unlocked and not active_here and (commissioned or first_expedition),
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
