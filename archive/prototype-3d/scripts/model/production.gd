class_name ProductionAccounting
extends RefCounted

const BalanceData = preload("res://data/balance.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")

const PASSIVE_OUTPUT_FACTOR: float = 0.20
const HERO_2_GUARD_FACTOR: float = 1.25
const MAX_OFFLINE_SECONDS: float = 86400.0

var settlement_cursor: float = -1.0

func settle(timestamp: float, commissioned_wells: Dictionary, hero_assignments: Dictionary, owned_upgrades: Dictionary, active_well_id: String = "") -> Dictionary:
	var rates: Dictionary = calculate_rates(commissioned_wells, hero_assignments, owned_upgrades, active_well_id)
	if not is_finite(timestamp):
		return {"elapsed": 0.0, "total": 0.0, "rates": rates}
	if settlement_cursor < 0.0:
		settlement_cursor = timestamp
		return {"elapsed": 0.0, "total": 0.0, "rates": rates}
	var elapsed: float = max(0.0, timestamp - settlement_cursor)
	settlement_cursor = max(settlement_cursor, timestamp)
	return {"elapsed": elapsed, "total": total_for_elapsed(elapsed, rates), "rates": rates}

func reset_cursor(timestamp: float) -> void:
	if is_finite(timestamp):
		settlement_cursor = timestamp

static func calculate_rates(commissioned_wells: Dictionary, hero_assignments: Dictionary, owned_upgrades: Dictionary, active_well_id: String = "") -> Dictionary:
	var rates: Dictionary = {}
	var catalog: RefCounted = ContentCatalogScript.new()
	var pump_factor: float = BalanceData.PUMP_OUTPUT_MULTIPLIER if owned_upgrades.has("pump_1") else 1.0
	for well_id in catalog.well_ids():
		if not commissioned_wells.has(well_id) or well_id == active_well_id:
			continue
		var guard_id: String = _guard_for_well(hero_assignments, well_id)
		if guard_id.is_empty():
			continue
		var base_output: float = float(catalog.get_well(well_id).get("base_output", 0.0))
		var guard_factor: float = HERO_2_GUARD_FACTOR if guard_id == "hero_2" else 1.0
		rates[well_id] = base_output * pump_factor * guard_factor * PASSIVE_OUTPUT_FACTOR
	return rates

static func total_for_elapsed(elapsed: float, rates: Dictionary) -> float:
	if not is_finite(elapsed) or elapsed <= 0.0:
		return 0.0
	var total: float = 0.0
	for rate in rates.values():
		total += float(rate) * elapsed
	return total

static func offline_elapsed(now_timestamp: float, saved_timestamp: float) -> float:
	if not is_finite(now_timestamp) or not is_finite(saved_timestamp):
		return 0.0
	return clamp(now_timestamp - saved_timestamp, 0.0, MAX_OFFLINE_SECONDS)

static func offline_settlement(now_timestamp: float, saved_timestamp: float, rates: Dictionary) -> Dictionary:
	var elapsed: float = offline_elapsed(now_timestamp, saved_timestamp)
	return {"elapsed": elapsed, "total": total_for_elapsed(elapsed, rates), "rates": rates.duplicate(true)}

static func _guard_for_well(hero_assignments: Dictionary, well_id: String) -> String:
	for hero_id in hero_assignments.keys():
		var assignment: Variant = hero_assignments[hero_id]
		if assignment is Dictionary and assignment.get("role", "") == "guard" and assignment.get("well_id", "") == well_id:
			return str(hero_id)
	return ""
