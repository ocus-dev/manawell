class_name AccountState
extends RefCounted

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const LoadoutScript = preload("res://scripts/model/loadout.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")

var bank: float = 0.0
var credited_run_ids: Dictionary = {}
var run_sequence: int = 1
var committed_run_id: String = ""
var legacy_identity_error: String = ""
var owned_upgrades: Dictionary = {}
var unlocked_wells: Dictionary = {"well_1": true}
var commissioned_wells: Dictionary = {}
var roster_heroes: Dictionary = {"hero_1": true}
var hero_assignments: Dictionary = {"hero_1": {"role": "active", "well_id": ""}}
var well_loadouts: Dictionary = {"well_1": LoadoutScript.STANDARD, "well_2": LoadoutScript.STANDARD}

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
	return {
		"bank": bank,
		"credited_run_ids": credited_ids,
		"run_sequence": run_sequence,
		"committed_run_id": committed_run_id,
		"owned_upgrades": upgrades,
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
	well_loadouts = {"well_1": LoadoutScript.STANDARD, "well_2": LoadoutScript.STANDARD}
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
	if completed_surges >= 1 and well_id in ["well_1", "well_2"] and not commissioned_wells.has(well_id):
		commissioned_wells[well_id] = true
		if well_id == "well_1":
			unlocked_wells["well_2"] = true
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
	return true

func has_upgrade(upgrade_id: String) -> bool:
	return owned_upgrades.has(upgrade_id)

func credit_terminal_result(result: Dictionary) -> bool:
	return complete_run(result, result.get("run_id", ""), "", 0)
