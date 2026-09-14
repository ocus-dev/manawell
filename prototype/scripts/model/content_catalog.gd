class_name ContentCatalog
extends RefCounted

const BalanceData = preload("res://data/balance.gd")
const ResearchCatalogScript = preload("res://scripts/model/research_catalog.gd")
const LevelDataLoaderScript = preload("res://scripts/model/level_data_loader.gd")
static var _cached_wells: Dictionary = {}

static func invalidate_cache() -> void:
	_cached_wells.clear()

var wells: Dictionary = {
	"well_1": {"label": "Well 1", "base_output": BalanceData.WELL_1_BASE_OUTPUT, "spawn_interval_factor": 1.0, "enemy_damage_factor": 1.0},
	"well_2": {"label": "Well 2", "base_output": BalanceData.WELL_2_BASE_OUTPUT, "spawn_interval_factor": 0.8, "enemy_damage_factor": 1.25},
	"well_3": {"label": "Well 3", "base_output": BalanceData.WELL_3_BASE_OUTPUT, "spawn_interval_factor": 0.7, "enemy_damage_factor": 1.4},
}
var heroes: Dictionary = {
	"hero_1": {"label": "Hero 1"},
	"hero_2": {"label": "Hero 2"},
}
var upgrades: Dictionary = {
	"damage_1": {"cost": BalanceData.DAMAGE_UPGRADE_COST, "label": "Damage +5", "effect": "Damage +5"},
	"pump_1": {"cost": BalanceData.PUMP_UPGRADE_COST, "label": "Pump +25% output", "effect": "Pump +25% output"},
	"spread_1": {"cost": BalanceData.SPREAD_UPGRADE_COST, "label": "Spread: three shots", "effect": "Spread: three shots"},
}
var research_tracks: Dictionary = ResearchCatalogScript.TRACKS.duplicate(true)
var research_unlocks: Dictionary = ResearchCatalogScript.UNLOCKS.duplicate(true)
var surge_rules: Array[Dictionary] = [
	{"tier": 0, "spawn_interval": 3.0, "breaker_cycle": -1, "ranged_cycle": -1},
	{"tier": 1, "spawn_interval": 2.5, "breaker_cycle": 3, "ranged_cycle": -1},
	{"tier": 2, "spawn_interval": 2.0, "breaker_cycle": 2, "ranged_cycle": 3},
	{"tier": 3, "spawn_interval": 2.0, "breaker_cycle": 2, "ranged_cycle": 3},
]

func _init() -> void:
	if not _cached_wells.is_empty():
		wells = _cached_wells.duplicate(true)
		return
	var loader: RefCounted = LevelDataLoaderScript.new()
	if not loader.load("res://data/campaign"):
		return
	for act_id in loader.act_ids():
		for level_id in loader.level_ids(act_id):
			var level: Dictionary = loader.get_level(act_id, level_id)
			if level.get("type", "") != "well":
				continue
			var well: Dictionary = level.get("well", {})
			var well_id := str(well.get("id", ""))
			if well_id.is_empty():
				continue
			wells[well_id] = {
				"id": well_id,
				"label": level.get("display_name", well_id),
				"base_output": float(well.get("base_mana_per_second", 0.0)),
				"spawn_interval_factor": float(well.get("spawn_interval_multiplier", 1.0)),
				"enemy_damage_factor": float(well.get("enemy_damage_factor", 1.0)),
				"source_level_id": level_id,
			}
	_cached_wells = wells.duplicate(true)

func define_well(well_id: String, definition: Dictionary) -> void:
	wells[well_id] = definition.duplicate(true)

func define_hero(hero_id: String, definition: Dictionary) -> void:
	heroes[hero_id] = definition.duplicate(true)

func define_upgrade(upgrade_id: String, definition: Dictionary) -> void:
	upgrades[upgrade_id] = definition.duplicate(true)

func define_surge_rule(rule: Dictionary) -> void:
	surge_rules.append(rule.duplicate(true))

func has_well(well_id: String) -> bool:
	return wells.has(well_id)

func has_hero(hero_id: String) -> bool:
	return heroes.has(hero_id)

func has_upgrade(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)

func has_research(research_id: String) -> bool:
	return research_tracks.has(research_id) or research_unlocks.has(research_id)

func get_research(research_id: String) -> Dictionary:
	if research_tracks.has(research_id):
		return research_tracks[research_id].duplicate(true)
	return research_unlocks.get(research_id, {}).duplicate(true)

func research_ids() -> Array[String]:
	return ResearchCatalogScript.all_ids()

func get_well(well_id: String) -> Dictionary:
	return wells.get(well_id, {})

func get_hero(hero_id: String) -> Dictionary:
	return heroes.get(hero_id, {})

func get_upgrade(upgrade_id: String) -> Dictionary:
	return upgrades.get(upgrade_id, {})

func well_ids() -> Array[String]:
	return _string_ids(wells)

func hero_ids() -> Array[String]:
	return _string_ids(heroes)

func upgrade_ids() -> Array[String]:
	return _string_ids(upgrades)

func spawn_rule_for_tier(tier: int) -> Dictionary:
	var selected: Dictionary = surge_rules[0]
	for rule in surge_rules:
		if int(rule.get("tier", 0)) <= tier:
			selected = rule
	return selected

func _string_ids(values: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for value in values.keys():
		ids.append(str(value))
	ids.sort()
	return ids
