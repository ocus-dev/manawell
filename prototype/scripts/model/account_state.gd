class_name AccountState
extends RefCounted

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const ResearchCatalogScript = preload("res://scripts/model/research_catalog.gd")
const ItemCatalogScript = preload("res://scripts/model/item_catalog.gd")
const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const LootGeneratorScript = preload("res://scripts/model/loot_generator.gd")
const INVENTORY_CAPACITY := 100
const INVENTORY_MIGRATION_VERSION := 1
const MAX_PENDING_REWARDS := 3200000

var owned_items: Dictionary = {}
var new_items: Dictionary = {}
var item_reward_run_id := ""
var item_reward_ids: Array[String] = []
var item_instances: Dictionary = {}
var hero_kits: Dictionary = {}
var inventory_migration_version: int = 0
var last_loot_result: Dictionary = {"run_id": "", "item_ids": []}
var reward_entitlements: Dictionary = {}
var pending_rewards: Array[Dictionary] = []
var discarded_reward_ids: Dictionary = {}
var inventory_command_error := ""

var bank: float = 0.0
var credited_run_ids: Dictionary = {}
var run_sequence: int = 1
var committed_run_id: String = ""
var legacy_identity_error: String = ""
var owned_upgrades: Dictionary = {}
var research_ranks: Dictionary = {}
var equipped_harvester_id: String = "harvest.standard"
var equipped_weapon_mode_id: String = "weapon.standard"
var unlocked_wells: Dictionary = {"well_1": true}
var commissioned_wells: Dictionary = {}
var roster_heroes: Dictionary = {"hero_1": true}
var hero_assignments: Dictionary = {"hero_1": {"role": "active", "well_id": ""}}
var well_loadouts: Dictionary = {"well_1": LoadoutScript.STANDARD, "well_2": LoadoutScript.STANDARD, "well_3": LoadoutScript.STANDARD}

var content_catalog: RefCounted = ContentCatalogScript.new()

func to_save_payload() -> Dictionary:
	var credited_ids: Array[String] = []
	if committed_run_id.is_empty() or not legacy_identity_error.is_empty():
		for run_id in credited_run_ids.keys():
			credited_ids.append(str(run_id))
	credited_ids.sort()
	var upgrades: Array[String] = []
	for upgrade_id in owned_upgrades.keys():
		upgrades.append(str(upgrade_id))
	upgrades.sort()
	var ranks: Dictionary = research_ranks.duplicate()
	var instances: Array[Dictionary] = []
	for instance_id in item_instances.keys():
		instances.append(item_instances[instance_id].duplicate(true))
	instances.sort_custom(func(left: Dictionary, right: Dictionary): return str(left.get("instance_id", "")) < str(right.get("instance_id", "")))
	return {
		"bank": bank,
		"owned_items": _known_ids(owned_items),
		"new_items": _known_ids(new_items),
		"item_reward_run_id": item_reward_run_id,
		"item_reward_ids": item_reward_ids.duplicate(),
		"item_instances": instances,
		"hero_kits": hero_kits.duplicate(true),
		"inventory_migration_version": inventory_migration_version,
		"last_loot_result": last_loot_result.duplicate(true),
		"reward_entitlements": reward_entitlements.duplicate(true),
		"pending_rewards": pending_rewards.duplicate(true),
		"discarded_reward_ids": _known_ids(discarded_reward_ids),
		"credited_run_ids": credited_ids,
		"run_sequence": run_sequence,
		"committed_run_id": committed_run_id,
		"owned_upgrades": upgrades,
		"research_ranks": ranks,
		"equipped_harvester_id": equipped_harvester_id,
		"equipped_weapon_mode_id": equipped_weapon_mode_id,
		"unlocked_wells": _known_ids(unlocked_wells),
		"commissioned_wells": _known_ids(commissioned_wells),
		"roster_heroes": _known_ids(roster_heroes),
		"hero_assignments": hero_assignments.duplicate(true),
		"well_loadouts": well_loadouts.duplicate(true),
	}

func _known_ids(values: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for value in values.keys():
		ids.append(str(value))
	ids.sort()
	return ids

static func validate_save_payload(payload: Dictionary, definitions: RefCounted = null) -> Dictionary:
	var catalog: RefCounted = ContentCatalogScript.new() if definitions == null else definitions
	var item_instance_values: Variant = payload.get("item_instances", [])
	if not item_instance_values is Array or item_instance_values.size() > INVENTORY_CAPACITY:
		return {"valid": false, "error": "item instances must be an array of at most 100 items"}
	var item_definitions: RefCounted = ItemDefinitionsScript.new()
	var production_catalog: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES
	var production_affixes: Dictionary = ItemDefinitionsScript.PRODUCTION_AFFIXES
	if not item_instance_values.is_empty():
		var instance_validation: Dictionary = item_definitions.validate_instances(item_instance_values, production_catalog, production_affixes)
		if not instance_validation.valid:
			return instance_validation
	var loot_result: Variant = payload.get("last_loot_result", {"run_id": "", "item_ids": []})
	if not loot_result is Dictionary or not loot_result.get("run_id", "") is String or not loot_result.get("item_ids", []) is Array:
		return {"valid": false, "error": "last loot result is invalid"}
	for item_id in loot_result.get("item_ids", []):
		if not item_id is String or not item_instance_values.any(func(instance): return str(instance.get("instance_id", "")) == item_id):
			return {"valid": false, "error": "last loot result references an unknown item"}
	var entitlements: Variant = payload.get("reward_entitlements", {})
	if not entitlements is Dictionary:
		return {"valid": false, "error": "reward entitlements must be an object"}
	var entitlement_item_ids := {}
	for reward_id in entitlements.keys():
		if not reward_id is String or str(reward_id).is_empty() or not entitlements[reward_id] is Dictionary:
			return {"valid": false, "error": "reward entitlement identity is invalid"}
		var entitlement: Dictionary = entitlements[reward_id]
		for field in ["node_id", "completion_run_id"]:
			if not entitlement.get(field, "") is String:
				return {"valid": false, "error": "reward entitlement %s is invalid" % field}
		for field in ["item_ids", "delivered_item_ids"]:
			if not entitlement.get(field, []) is Array:
				return {"valid": false, "error": "reward entitlement %s is invalid" % field}
		for item_id in entitlement.get("item_ids", []):
			if not item_id is String or str(item_id).is_empty() or entitlement_item_ids.has(item_id):
				return {"valid": false, "error": "reward entitlement item identity is invalid"}
			entitlement_item_ids[item_id] = true
		for item_id in entitlement.get("delivered_item_ids", []):
			if not item_id is String or not item_id in entitlement.get("item_ids", []):
				return {"valid": false, "error": "reward entitlement delivery is invalid"}
	var pending: Variant = payload.get("pending_rewards", [])
	if not pending is Array or pending.size() > MAX_PENDING_REWARDS:
		return {"valid": false, "error": "pending rewards are invalid"}
	var pending_ids := {}
	for item in pending:
		if not item is Dictionary:
			return {"valid": false, "error": "pending reward item is invalid"}
		var item_validation: Dictionary = item_definitions.validate_instance(item, production_catalog, production_affixes)
		if not item_validation.valid or item.get("provenance", {}).get("kind", "") != "campaign":
			return {"valid": false, "error": "pending reward item is invalid"}
		var pending_id := str(item.get("instance_id", ""))
		if pending_id.is_empty() or pending_ids.has(pending_id) or not entitlement_item_ids.has(pending_id):
			return {"valid": false, "error": "pending reward identity is invalid"}
		pending_ids[pending_id] = true
	var discarded: Variant = payload.get("discarded_reward_ids", [])
	if not discarded is Array:
		return {"valid": false, "error": "discarded reward IDs must be an array"}
	var discarded_seen := {}
	for reward_id in discarded:
		if not reward_id is String or str(reward_id).is_empty() or discarded_seen.has(reward_id):
			return {"valid": false, "error": "discarded reward identity is invalid"}
		discarded_seen[reward_id] = true
	var kit_validation := _validate_hero_kits(payload.get("hero_kits", {}), item_instance_values, catalog)
	if not kit_validation.valid:
		return kit_validation
	if payload.has("inventory_migration_version") and (not _valid_integer(payload.inventory_migration_version) or int(payload.inventory_migration_version) < 0 or int(payload.inventory_migration_version) > INVENTORY_MIGRATION_VERSION):
		return {"valid": false, "error": "inventory migration version is invalid"}
	for field in ["owned_items", "new_items", "item_reward_ids"]:
		var values: Variant = payload.get(field, [])
		if not values is Array:
			return {"valid": false, "error": field + " must be an array"}
		var seen := {}
		for id in values:
			if not id is String or not ItemCatalogScript.ITEMS.has(id) or seen.has(id):
				return {"valid": false, "error": "Invalid or duplicate inventory item"}
			seen[id] = true
			if field != "owned_items" and not id in payload.get("owned_items", []):
				return {"valid": false, "error": "Item metadata references an unowned item"}
	if not payload.get("item_reward_run_id", "") is String:
		return {"valid": false, "error": "Invalid item reward run identity"}
	if not payload.get("item_reward_ids", []).is_empty() and str(payload.get("item_reward_run_id", "")).is_empty():
		return {"valid": false, "error": "Item reward has no run identity"}
	if not payload.has("bank") or not (payload["bank"] is int or payload["bank"] is float):
		return {"valid": false, "error": "bank must be a finite nonnegative number"}
	var bank_value: float = float(payload["bank"])
	if not is_finite(bank_value) or bank_value < 0.0:
		return {"valid": false, "error": "bank must be a finite nonnegative number"}
	if not payload.has("credited_run_ids") or not payload["credited_run_ids"] is Array:
		return {"valid": false, "error": "credited_run_ids must be an array"}
	if payload.has("run_sequence") and (not (payload["run_sequence"] is int or payload["run_sequence"] is float) or int(payload["run_sequence"]) < 1):
		return {"valid": false, "error": "run_sequence must be a positive integer"}
	if payload.has("committed_run_id") and not payload["committed_run_id"] is String:
		return {"valid": false, "error": "committed_run_id must be a string"}
	for run_id in payload["credited_run_ids"]:
		if not run_id is String or run_id.is_empty():
			return {"valid": false, "error": "credited run IDs must be non-empty strings"}
	if not payload.has("owned_upgrades") or not payload["owned_upgrades"] is Array:
		return {"valid": false, "error": "owned_upgrades must be an array"}
	for upgrade_id in payload["owned_upgrades"]:
		if not upgrade_id is String or not catalog.has_upgrade(upgrade_id):
			return {"valid": false, "error": "owned upgrades must use known IDs"}
	if payload.has("research_ranks") and not payload["research_ranks"] is Dictionary:
		return {"valid": false, "error": "research_ranks must be an object"}
	for research_id in payload.get("research_ranks", {}).keys():
		if not research_id is String or not catalog.has_research(research_id) or not (payload["research_ranks"][research_id] is int) or int(payload["research_ranks"][research_id]) < 0:
			return {"valid": false, "error": "research ranks are invalid"}
		var definition: Dictionary = catalog.get_research(research_id)
		if definition.has("max_rank") and int(payload["research_ranks"][research_id]) > int(definition["max_rank"]):
			return {"valid": false, "error": "research rank exceeds cap"}
	for equipment_field in ["equipped_harvester_id", "equipped_weapon_mode_id"]:
		if payload.has(equipment_field) and not payload[equipment_field] is String:
			return {"valid": false, "error": "%s must be a string" % equipment_field}
	if payload.get("equipped_harvester_id", "harvest.standard") not in ["harvest.standard", "harvest.rapid_seal", "harvest.deep_draw"] or payload.get("equipped_weapon_mode_id", "weapon.standard") not in ["weapon.standard", "weapon.fan", "weapon.lance"]:
		return {"valid": false, "error": "equipment ID is invalid"}
	for field in ["unlocked_wells", "commissioned_wells", "roster_heroes"]:
		if payload.has(field) and not payload[field] is Array:
			return {"valid": false, "error": "%s must be an array" % field}
	for well_id in payload.get("unlocked_wells", []):
		if not well_id is String or not catalog.has_well(well_id):
			return {"valid": false, "error": "unlocked wells must use known IDs"}
	for well_id in payload.get("commissioned_wells", []):
		if not well_id is String or not catalog.has_well(well_id):
			return {"valid": false, "error": "commissioned wells must use known IDs"}
	for hero_id in payload.get("roster_heroes", []):
		if not hero_id is String or not catalog.has_hero(hero_id):
			return {"valid": false, "error": "roster heroes must use known IDs"}
	if payload.has("hero_assignments") and not payload["hero_assignments"] is Dictionary:
		return {"valid": false, "error": "hero assignments must be an object"}
	if payload.has("well_loadouts") and not payload["well_loadouts"] is Dictionary:
		return {"valid": false, "error": "well loadouts must be an object"}
	var well_2_commissioned: bool = "well_2" in payload.get("commissioned_wells", [])
	for well_id in payload.get("well_loadouts", {}).keys():
		if not well_id is String or not catalog.has_well(well_id):
			return {"valid": false, "error": "well loadouts must use known well IDs"}
		var loadout_id: Variant = payload["well_loadouts"][well_id]
		if not loadout_id is String or not LoadoutScript.is_available(loadout_id, well_2_commissioned):
			return {"valid": false, "error": "well loadout is unavailable"}
	var active_count: int = 0
	var guarded_wells: Dictionary = {}
	for hero_id in payload.get("hero_assignments", {}).keys():
		if not hero_id is String or not catalog.has_hero(hero_id):
			return {"valid": false, "error": "hero assignments must use known IDs"}
		var assignment: Variant = payload["hero_assignments"][hero_id]
		if not assignment is Dictionary or not ["active", "reserve", "guard"].has(assignment.get("role", "")):
			return {"valid": false, "error": "hero assignment role is invalid"}
		var well_id: String = assignment.get("well_id", "")
		if assignment["role"] == "guard":
			if not catalog.has_well(well_id) or guarded_wells.has(well_id):
				return {"valid": false, "error": "hero guard site is invalid or duplicated"}
			guarded_wells[well_id] = true
		elif not well_id.is_empty():
			return {"valid": false, "error": "non-guard hero assignment cannot have a site"}
		if assignment["role"] == "active":
			active_count += 1
	if active_count > 1:
		return {"valid": false, "error": "only one active hero is allowed"}
	return {"valid": true}

func from_save_payload(payload: Dictionary) -> void:
	owned_items.clear()
	new_items.clear()
	for id in payload.get("owned_items", []):
		owned_items[id] = true
	for id in payload.get("new_items", []):
		new_items[id] = true
	item_reward_run_id = str(payload.get("item_reward_run_id", ""))
	item_reward_ids.assign(payload.get("item_reward_ids", []))
	item_instances.clear()
	for instance in payload.get("item_instances", []):
		item_instances[str(instance.instance_id)] = instance.duplicate(true)
	hero_kits = payload.get("hero_kits", {}).duplicate(true)
	inventory_migration_version = int(payload.get("inventory_migration_version", 0))
	last_loot_result = payload.get("last_loot_result", {"run_id": "", "item_ids": []}).duplicate(true)
	reward_entitlements = payload.get("reward_entitlements", {}).duplicate(true)
	pending_rewards.assign(payload.get("pending_rewards", []))
	discarded_reward_ids.clear()
	for reward_id in payload.get("discarded_reward_ids", []):
		discarded_reward_ids[reward_id] = true
	if inventory_migration_version < INVENTORY_MIGRATION_VERSION:
		_migrate_legacy_items(payload)
	if not payload.has("owned_items") and payload.has("item_instances"):
		owned_items.clear()
		new_items.clear()
	bank = float(payload["bank"])
	credited_run_ids.clear()
	legacy_identity_error = ""
	run_sequence = maxi(1, int(payload.get("run_sequence", 1)))
	committed_run_id = str(payload.get("committed_run_id", ""))
	var legacy_sequence: int = 0
	var run_pattern := RegEx.new()
	run_pattern.compile("^run-([0-9]+)$")
	for run_id in payload["credited_run_ids"]:
		credited_run_ids[run_id] = true
		var match: RegExMatch = run_pattern.search(str(run_id))
		if match == null:
			legacy_identity_error = "Legacy credited run ID cannot be mapped safely: %s" % str(run_id)
		else:
			legacy_sequence = maxi(legacy_sequence, int(match.get_string(1)))
	run_sequence = maxi(run_sequence, legacy_sequence + 1)
	if committed_run_id.is_empty() and legacy_sequence > 0:
		committed_run_id = "run-%d" % legacy_sequence
	owned_upgrades.clear()
	for upgrade_id in payload["owned_upgrades"]:
		owned_upgrades[upgrade_id] = true
	research_ranks.clear()
	for research_id in payload.get("research_ranks", {}).keys():
		research_ranks[research_id] = int(payload["research_ranks"][research_id])
	if research_ranks.is_empty():
		if owned_upgrades.has("damage_1"):
			research_ranks["weapon.damage"] = 1
		if owned_upgrades.has("pump_1"):
			research_ranks["harvest.amount"] = 1
		if owned_upgrades.has("spread_1"):
			research_ranks["weapon.shots"] = 1
	equipped_harvester_id = str(payload.get("equipped_harvester_id", "harvest.standard"))
	equipped_weapon_mode_id = str(payload.get("equipped_weapon_mode_id", "weapon.standard"))
	if owned_upgrades.has("spread_1") and not payload.has("equipped_weapon_mode_id"):
		equipped_weapon_mode_id = "weapon.fan"
	unlocked_wells = {"well_1": true}
	for well_id in payload.get("unlocked_wells", []):
		unlocked_wells[well_id] = true
	commissioned_wells.clear()
	for well_id in payload.get("commissioned_wells", []):
		commissioned_wells[well_id] = true
	roster_heroes = {"hero_1": true}
	for hero_id in payload.get("roster_heroes", []):
		roster_heroes[hero_id] = true
	hero_assignments = {"hero_1": {"role": "active", "well_id": ""}}
	for hero_id in roster_heroes.keys():
		if hero_id != "hero_1":
			hero_assignments[hero_id] = {"role": "reserve", "well_id": ""}
	for hero_id in payload.get("hero_assignments", {}).keys():
		if roster_heroes.has(hero_id):
			hero_assignments[hero_id] = payload["hero_assignments"][hero_id].duplicate(true)
	_normalize_assignments()
	well_loadouts = {"well_1": LoadoutScript.STANDARD, "well_2": LoadoutScript.STANDARD, "well_3": LoadoutScript.STANDARD}
	for well_id in payload.get("well_loadouts", {}).keys():
		if is_well_commissioned(well_id) and LoadoutScript.is_available(payload["well_loadouts"][well_id], is_well_commissioned("well_2")):
			well_loadouts[well_id] = payload["well_loadouts"][well_id]

func is_well_unlocked(well_id: String) -> bool:
	return unlocked_wells.has(well_id)

func is_well_commissioned(well_id: String) -> bool:
	return commissioned_wells.has(well_id)

func get_loadout_for_well(well_id: String) -> String:
	return well_loadouts.get(well_id, LoadoutScript.STANDARD)

func select_loadout(well_id: String, loadout_id: String) -> bool:
	if not is_well_commissioned(well_id) or not LoadoutScript.is_available(loadout_id, is_well_commissioned("well_2")):
		return false
	well_loadouts[well_id] = loadout_id
	return true

func has_hero(hero_id: String) -> bool:
	return roster_heroes.has(hero_id)

func get_active_hero_id() -> String:
	for hero_id in hero_assignments.keys():
		if hero_assignments[hero_id].get("role", "") == "active":
			return hero_id
	return ""

func get_hero_role(hero_id: String) -> String:
	return hero_assignments.get(hero_id, {}).get("role", "locked")

func get_guard_for_well(well_id: String) -> String:
	for hero_id in hero_assignments.keys():
		var assignment: Dictionary = hero_assignments[hero_id]
		if assignment.get("role", "") == "guard" and assignment.get("well_id", "") == well_id:
			return hero_id
	return ""

func select_active_hero(hero_id: String) -> bool:
	if not has_hero(hero_id) or get_hero_role(hero_id) == "guard":
		return false
	var current_active: String = get_active_hero_id()
	if current_active == hero_id:
		return true
	if not current_active.is_empty():
		hero_assignments[current_active] = {"role": "reserve", "well_id": ""}
	hero_assignments[hero_id] = {"role": "active", "well_id": ""}
	return true

func assign_guard(hero_id: String, well_id: String) -> bool:
	if not has_hero(hero_id) or not is_well_commissioned(well_id):
		return false
	if get_guard_for_well(well_id) != "" or get_hero_role(hero_id) != "reserve":
		return false
	hero_assignments[hero_id] = {"role": "guard", "well_id": well_id}
	return true

func recall_guard(well_id: String) -> bool:
	var hero_id: String = get_guard_for_well(well_id)
	if hero_id.is_empty():
		return false
	hero_assignments[hero_id] = {"role": "reserve", "well_id": ""}
	return true

func release_guard_for_start(well_id: String) -> String:
	var hero_id: String = get_guard_for_well(well_id)
	if not hero_id.is_empty():
		recall_guard(well_id)
	return hero_id

func _normalize_assignments() -> void:
	var active_seen: bool = false
	for hero_id in roster_heroes.keys():
		if not hero_assignments.has(hero_id):
			hero_assignments[hero_id] = {"role": "reserve", "well_id": ""}
		if hero_assignments[hero_id].get("role", "") == "active":
			if active_seen:
				hero_assignments[hero_id] = {"role": "reserve", "well_id": ""}
			else:
				active_seen = true
	if not active_seen and not roster_heroes.is_empty():
		var fallback: String = roster_heroes.keys()[0]
		hero_assignments[fallback] = {"role": "active", "well_id": ""}

func credit_terminal_result_with_commission(result: Dictionary, well_id: String, completed_surges: int) -> bool:
	return complete_run(result, result.get("run_id", ""), well_id, completed_surges)

func complete_run(result: Dictionary, expected_run_id: String, well_id: String, completed_surges: int) -> bool:
	if result.is_empty() or result.get("phase", -1) != RunStateScript.Phase.SUCCESS:
		return false
	var result_run_id: String = result.get("run_id", "")
	var payout: int = result.get("payout", 0)
	if result_run_id.is_empty() or result_run_id != expected_run_id or payout < 0 or committed_run_id == result_run_id or credited_run_ids.has(result_run_id):
		return false
	committed_run_id = result_run_id
	bank += payout
	if completed_surges >= 1 and content_catalog.has_well(well_id) and not well_id.is_empty() and not commissioned_wells.has(well_id):
		commissioned_wells[well_id] = true
		var well_ids: Array[String] = content_catalog.well_ids()
		var well_index: int = well_ids.find(well_id)
		if well_index >= 0 and well_index + 1 < well_ids.size():
			unlocked_wells[well_ids[well_index + 1]] = true
		if well_id == "well_1":
			roster_heroes["hero_2"] = true
			hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	return true

func allocate_run_id() -> String:
	var run_id := "run-%d" % run_sequence
	run_sequence += 1
	return run_id

func purchase_upgrade(upgrade_id: String) -> bool:
	if not content_catalog.has_upgrade(upgrade_id) or owned_upgrades.has(upgrade_id):
		return false
	var cost: int = int(content_catalog.get_upgrade(upgrade_id).get("cost", -1))
	if bank < cost:
		return false
	bank -= cost
	owned_upgrades[upgrade_id] = true
	if upgrade_id == "damage_1":
		research_ranks["weapon.damage"] = maxi(1, int(research_ranks.get("weapon.damage", 0)))
	elif upgrade_id == "pump_1":
		research_ranks["harvest.amount"] = maxi(1, int(research_ranks.get("harvest.amount", 0)))
	elif upgrade_id == "spread_1":
		research_ranks["weapon.shots"] = maxi(1, int(research_ranks.get("weapon.shots", 0)))
		equipped_weapon_mode_id = "weapon.fan"
	return true

func purchase_research(research_id: String, expected_rank: int = 0, expected_cost: int = -1, active_run: bool = false) -> bool:
	if active_run or not content_catalog.has_research(research_id):
		return false
	var definition: Dictionary = content_catalog.get_research(research_id)
	if not definition.has("ranks") or expected_rank != int(research_ranks.get(research_id, 0)):
		return false
	var ranks: Array = definition.get("ranks", [])
	if expected_rank < 0 or expected_rank >= ranks.size():
		return false
	var node: Dictionary = ranks[expected_rank]
	var cost := int(node.get("cost", -1))
	if expected_cost >= 0 and expected_cost != cost or bank < cost:
		return false
	var prerequisite: Dictionary = definition.get("prerequisite", {})
	if not prerequisite.is_empty() and int(research_ranks.get(prerequisite.get("track", ""), 0)) < int(prerequisite.get("rank", 0)):
		return false
	research_ranks[research_id] = expected_rank + 1
	bank -= cost
	return true

func equip_research_choice(choice_id: String, active_run: bool = false) -> bool:
	if active_run:
		return false
	if choice_id == "harvest.standard":
		equipped_harvester_id = choice_id
		return true
	if choice_id == "weapon.standard":
		equipped_weapon_mode_id = choice_id
		return true
	if choice_id == "harvest.rapid_seal" and int(research_ranks.get("harvest.cadence", 0)) >= 2:
		equipped_harvester_id = choice_id
		return true
	if choice_id == "harvest.deep_draw" and int(research_ranks.get("harvest.amount", 0)) >= 2:
		equipped_harvester_id = choice_id
		return true
	if choice_id == "weapon.fan" and int(research_ranks.get("weapon.shots", 0)) >= 1:
		equipped_weapon_mode_id = choice_id
		return true
	if choice_id == "weapon.lance" and int(research_ranks.get("weapon.damage", 0)) >= 2 and int(research_ranks.get("weapon.velocity", 0)) >= 2:
		equipped_weapon_mode_id = choice_id
		return true
	return false

func has_upgrade(upgrade_id: String) -> bool:
	return owned_upgrades.has(upgrade_id)

func grant_item(id: String) -> bool:
	if not ItemCatalogScript.ITEMS.has(id):
		return false
	return add_transitional_item(id, "", "")

func add_transitional_item(base_id: String, run_id: String, node_id: String) -> bool:
	if not ItemCatalogScript.ITEMS.has(base_id):
		return false
	if item_instances.has("legacy:" + base_id):
		var was_owned := owned_items.has(base_id)
		if was_owned:
			return false
		owned_items[base_id] = true
		new_items[base_id] = true
		return true
	if item_instances.size() >= INVENTORY_CAPACITY:
		inventory_command_error = "Inventory is full (100 items)."
		return false
	var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES.get(base_id, {})
	if base.is_empty():
		return false
	var instance := _legacy_instance(base_id, base, run_id, node_id)
	item_instances[instance.instance_id] = instance
	owned_items[base_id] = true
	new_items[base_id] = true
	inventory_migration_version = INVENTORY_MIGRATION_VERSION
	return true

func inspect_item(id: String) -> bool:
	if item_instances.has(id):
		item_instances[id].inspected = true
		return true
	if not owned_items.has(id) or not new_items.has(id):
		return false
	new_items.erase(id)
	return true

func reconcile_item_rewards(completed: Dictionary) -> bool:
	var changed := false
	var catalog: RefCounted = CampaignCatalogScript.new()
	if not catalog.is_valid():
		return false
	for act_id in catalog.act_order:
		for node_id in catalog.level_ids(act_id):
			var completion_key := "%s/%s" % [act_id, node_id]
			if not completed.has(completion_key):
				continue
			var level: Dictionary = catalog.get_node(act_id, node_id).get("level_data", {})
			for reward in level.get("rewards", {}).get("guaranteed_items", []):
				var reward_id := str(reward.get("reward_id", ""))
				var base_id := str(reward.get("base_id", ""))
				if reward.get("trigger", "") != "first_clear" or reward_id.is_empty() or reward_entitlements.has(reward_id) or discarded_reward_ids.has(reward_id):
					continue
				var legacy_id := "legacy:" + base_id
				if item_instances.has(legacy_id) or add_transitional_item(base_id, "", node_id):
					reward_entitlements[reward_id] = {"node_id": node_id, "completion_run_id": "", "item_ids": [legacy_id], "delivered_item_ids": [legacy_id], "migration": "completion_evidence"}
					changed = true
	return changed

func complete_campaign_run(result: Dictionary, expected_run_id: String, node_id: String, level_data: Dictionary, well_id: String = "", completed_surges: int = 0) -> bool:
	var rewards: Array = level_data.get("rewards", {}).get("guaranteed_items", [])
	var prepared: Array[Dictionary] = []
	for reward in rewards:
		var reward_id := str(reward.get("reward_id", ""))
		if reward_id.is_empty() or reward.get("trigger", "") != "first_clear" or reward_entitlements.has(reward_id):
			continue
		for index in range(int(reward.get("quantity", 0))):
			var child_id := "reward:%s:%d" % [reward_id, index]
			var generated := LootGeneratorScript.generate_guaranteed({"reward_id": reward_id, "instance_id": child_id, "base_id": reward.get("base_id", ""), "rarity": reward.get("rarity", ""), "item_level": reward.get("item_level", 0), "run_id": expected_run_id, "node_id": node_id}, LootGeneratorScript.seed_for(child_id))
			if not generated.valid:
				return false
			prepared.append(generated.instance)
	if not complete_run(result, expected_run_id, well_id, completed_surges):
		return false
	for reward in rewards:
		var reward_id := str(reward.get("reward_id", ""))
		if reward_id.is_empty() or reward_entitlements.has(reward_id):
			continue
		var item_ids: Array[String] = []
		for item in prepared:
			if str(item.provenance.get("node_id", "")) == node_id and str(item.instance_id).begins_with("reward:%s:" % reward_id):
				item_ids.append(str(item.instance_id))
				pending_rewards.append(item.duplicate(true))
		reward_entitlements[reward_id] = {"node_id": node_id, "completion_run_id": expected_run_id, "item_ids": item_ids, "delivered_item_ids": []}
		if pending_rewards.size() > MAX_PENDING_REWARDS:
			return false
	claim_pending_rewards()
	return true

func claim_pending_rewards() -> int:
	var delivered := 0
	while not pending_rewards.is_empty() and item_instances.size() < INVENTORY_CAPACITY:
		var item: Dictionary = pending_rewards.pop_front()
		if add_campaign_instance(item):
			delivered += 1
			var instance_id := str(item.instance_id)
			for reward_id in reward_entitlements.keys():
				var entitlement: Dictionary = reward_entitlements[reward_id]
				if instance_id in entitlement.get("item_ids", []) and not instance_id in entitlement.get("delivered_item_ids", []):
					entitlement.delivered_item_ids.append(instance_id)
					break
		else:
			pending_rewards.push_front(item)
			break
	return delivered

func add_campaign_instance(instance: Dictionary) -> bool:
	var validation := ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.PRODUCTION_BASES, ItemDefinitionsScript.PRODUCTION_AFFIXES)
	if not validation.valid or instance.get("provenance", {}).get("kind", "") != "campaign" or item_instances.has(instance.get("instance_id", "")) or item_instances.size() >= INVENTORY_CAPACITY:
		return false
	item_instances[str(instance.instance_id)] = instance.duplicate(true)
	owned_items[str(instance.base_id)] = true
	new_items[str(instance.base_id)] = true
	item_reward_run_id = str(instance.get("provenance", {}).get("run_id", item_reward_run_id))
	if not item_reward_ids.has(str(instance.base_id)):
		item_reward_ids.append(str(instance.base_id))
	inventory_migration_version = INVENTORY_MIGRATION_VERSION
	return true

func equip_instance(hero_id: String, slot: String, instance_id: String, active_run: bool = false) -> bool:
	inventory_command_error = ""
	if active_run or not has_hero(hero_id) or not ItemDefinitionsScript.SLOTS.has(slot) or not item_instances.has(instance_id):
		inventory_command_error = "Equipment change is unavailable."
		return false
	var instance: Dictionary = item_instances[instance_id]
	var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES.get(instance.base_id, {})
	if base.get("slot", "") != slot:
		inventory_command_error = "Item slot does not match the requested kit slot."
		return false
	for other_hero in hero_kits.keys():
		if other_hero != hero_id and hero_kits[other_hero].get(slot, "") == instance_id:
			inventory_command_error = "Item is already equipped by another hero."
			return false
	if not hero_kits.has(hero_id):
		hero_kits[hero_id] = {"weapon": "", "hero": "", "harvester": ""}
	hero_kits[hero_id][slot] = instance_id
	return true

func unequip_instance(hero_id: String, slot: String, active_run: bool = false) -> bool:
	if active_run or not hero_kits.has(hero_id) or not ItemDefinitionsScript.SLOTS.has(slot):
		return false
	hero_kits[hero_id][slot] = ""
	return true

func set_instance_locked(instance_id: String, locked: bool, active_run: bool = false) -> bool:
	if active_run or not item_instances.has(instance_id):
		return false
	item_instances[instance_id].locked = locked
	return true

func discard_instance(instance_id: String, confirmed_name: String = "", active_run: bool = false) -> bool:
	inventory_command_error = ""
	if active_run or not item_instances.has(instance_id):
		inventory_command_error = "Unknown item."
		return false
	var instance: Dictionary = item_instances[instance_id]
	if instance.locked or _is_equipped(instance_id):
		inventory_command_error = "Equipped or locked items cannot be discarded."
		return false
	var label: String = str(ItemDefinitionsScript.PRODUCTION_BASES.get(instance.base_id, {}).get("label", instance.base_id))
	if confirmed_name != label:
		inventory_command_error = "Item name confirmation is required."
		return false
	var provenance: Dictionary = instance.get("provenance", {})
	if provenance.get("kind", "") == "campaign":
		var reward_id := _campaign_reward_id_for_node(str(provenance.get("node_id", "")), str(instance.get("base_id", "")))
		if not reward_id.is_empty():
			discarded_reward_ids[reward_id] = true
			if reward_entitlements.has(reward_id):
				reward_entitlements[reward_id].item_ids.erase(instance_id)
				reward_entitlements[reward_id].delivered_item_ids.erase(instance_id)
	item_instances.erase(instance_id)
	owned_items.erase(instance.base_id)
	new_items.erase(instance.base_id)
	last_loot_result.item_ids.erase(instance_id)
	return true

func _campaign_reward_id_for_node(node_id: String, base_id: String) -> String:
	var catalog: RefCounted = CampaignCatalogScript.new()
	if not catalog.is_valid():
		return ""
	var level: Dictionary = catalog.get_node("act_01", node_id).get("level_data", {})
	for reward in level.get("rewards", {}).get("guaranteed_items", []):
		if reward.get("trigger", "") == "first_clear" and str(reward.get("base_id", "")) == base_id:
			return str(reward.get("reward_id", ""))
	return ""

func credit_terminal_result(result: Dictionary) -> bool:
	return complete_run(result, result.get("run_id", ""), "", 0)

func add_monster_instance(instance: Dictionary) -> bool:
	inventory_command_error = ""
	var validation: Dictionary = ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.PRODUCTION_BASES, ItemDefinitionsScript.PRODUCTION_AFFIXES)
	if not validation.valid or instance.get("generation_version", "") != ItemDefinitionsScript.GENERATION_VERSION or instance.get("provenance", {}).get("kind", "") != "monster":
		inventory_command_error = "Invalid monster item."
		return false
	var instance_id := str(instance.get("instance_id", ""))
	if instance_id.is_empty() or item_instances.has(instance_id):
		inventory_command_error = "Monster item was already secured."
		return false
	if item_instances.size() >= INVENTORY_CAPACITY:
		inventory_command_error = "Inventory is full (100 items)."
		return false
	item_instances[instance_id] = instance.duplicate(true)
	var base_id := str(instance.get("base_id", ""))
	owned_items[base_id] = true
	new_items[base_id] = true
	inventory_migration_version = INVENTORY_MIGRATION_VERSION
	return true

func record_loot_result(run_id: String, item_ids: Array[String]) -> void:
	var retained: Array[String] = []
	for item_id in item_ids:
		if item_instances.has(item_id):
			retained.append(item_id)
	retained.sort()
	last_loot_result = {"run_id": run_id, "item_ids": retained}
	item_reward_run_id = run_id
	item_reward_ids.clear()
	for item_id in retained:
		var base_id := str(item_instances[item_id].get("base_id", ""))
		if not item_reward_ids.has(base_id):
			item_reward_ids.append(base_id)

func _legacy_instance(base_id: String, base: Dictionary, run_id: String, node_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"instance_id": "legacy:" + base_id,
		"base_id": base_id,
		"rarity": "common",
		"item_level": 1,
		"implicit_modifiers": base.get("implicits", []).duplicate(true),
		"explicit_modifiers": [],
		"generation_version": ItemDefinitionsScript.GENERATION_VERSION,
		"provenance": {"kind": "campaign" if not node_id.is_empty() else "legacy", "run_id": run_id, "enemy_id": 0, "node_id": node_id},
		"inspected": not new_items.has(base_id),
		"locked": false,
	}

func _migrate_legacy_items(payload: Dictionary) -> void:
	if not item_instances.is_empty():
		inventory_migration_version = INVENTORY_MIGRATION_VERSION
		return
	for base_id in payload.get("owned_items", []):
		if ItemCatalogScript.ITEMS.has(base_id) and not item_instances.has("legacy:" + base_id):
			var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES.get(base_id, {})
			if not base.is_empty():
				var instance := _legacy_instance(base_id, base, "", "")
				item_instances[instance.instance_id] = instance
				owned_items[base_id] = true
				if payload.get("new_items", []).has(base_id):
					instance.inspected = false
	inventory_migration_version = INVENTORY_MIGRATION_VERSION

func _is_equipped(instance_id: String) -> bool:
	for kit in hero_kits.values():
		for slot in ItemDefinitionsScript.SLOTS:
			if kit.get(slot, "") == instance_id:
				return true
	return false

static func _validate_hero_kits(kits: Variant, instances: Array, definitions: RefCounted = null) -> Dictionary:
	if not kits is Dictionary:
		return {"valid": false, "error": "hero kits must be an object"}
	var owned := {}
	for instance in instances:
		owned[instance.get("instance_id", "")] = instance
	var used := {}
	for hero_id in kits.keys():
		if not hero_id is String or (definitions != null and not definitions.has_hero(hero_id)):
			return {"valid": false, "error": "hero kit references an unknown hero"}
		var kit: Variant = kits[hero_id]
		if not kit is Dictionary:
			return {"valid": false, "error": "hero kit must be an object"}
		for slot in ItemDefinitionsScript.SLOTS:
			var instance_id: Variant = kit.get(slot, "")
			if not instance_id is String:
				return {"valid": false, "error": "hero kit slot must be a string"}
			if instance_id.is_empty():
				continue
			if not owned.has(instance_id):
				return {"valid": false, "error": "hero kit references an unowned instance"}
			if used.has(instance_id):
				return {"valid": false, "error": "an instance cannot be equipped twice"}
			var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES.get(owned[instance_id].get("base_id", ""), {})
			if base.get("slot", "") != slot:
				return {"valid": false, "error": "hero kit slot does not match item slot"}
			used[instance_id] = true
	return {"valid": true}

static func _valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool and is_finite(float(value)) and float(value) == floor(float(value))
