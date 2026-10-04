class_name LootOdds
extends RefCounted

## Plain-number drop odds for the Dev Encyclopedia, worked out from the same
## rules LootGenerator uses:
##   1. Does this kill drop an item? ORDINARY_OCCURRENCE (2%) per kill,
##      BOSS_OCCURRENCE (25%) on boss levels.
##   2. Which item? The 9 gear bases count 100 each; each loot-enabled weapon
##      counts weight x 100 (only at item levels inside its range).
## Kills per run are estimated from the level's spawn settings (LevelSpawns):
## every spawn up to the boss surge, plus the boss.

const LootGeneratorScript = preload("res://scripts/model/loot_generator.gd")
const LevelSpawnsScript = preload("res://scripts/model/level_spawns.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const BalanceData = preload("res://data/balance.gd")
const CreatureDropsScript = preload("res://scripts/model/creature_drops.gd")

## A level with no boss gate is estimated over this many surges.
const FARMING_SURGES := 5

static func item_chance(kind: String = "ordinary") -> float:
	return float(LootGeneratorScript.BOSS_OCCURRENCE if kind == "boss" else LootGeneratorScript.ORDINARY_OCCURRENCE) / 10000.0

static func gear_weight_units() -> int:
	return LootGeneratorScript.BASE_IDS.size() * 100

static func weight_units(weight: float) -> int:
	return maxi(1, int(round(weight * 100.0)))

## This weapon's share of item drops at `item_level` (0 when it can't drop
## there). `table` is {weapon_id: {enabled, weight, min_item_level, max_item_level}}.
static func share(weapon_id: String, table: Dictionary, item_level: int) -> float:
	var mine := 0
	var total := gear_weight_units()
	for id in table:
		var entry: Dictionary = table[id]
		if not bool(entry.get("enabled", false)) or item_level < int(entry.get("min_item_level", 1)) or item_level > int(entry.get("max_item_level", 3)):
			continue
		# Per-creature weapons don't take part in the shared roll.
		if CreatureDropsScript.is_per_creature({"monster_chances": entry.get("chances", entry.get("monster_chances", {}))}):
			continue
		var units := weight_units(float(entry.get("weight", 1.0)))
		total += units
		if id == weapon_id:
			mine = units
	return float(mine) / float(total) if total > 0 else 0.0

static func per_kill(weapon_id: String, table: Dictionary, item_level: int, kind: String = "ordinary") -> float:
	return item_chance(kind) * share(weapon_id, table, item_level)

## Chance of at least one success in `tries` independent tries.
static func at_least_once(chance: float, tries: float) -> float:
	if chance <= 0.0 or tries <= 0.0:
		return 0.0
	return 1.0 - pow(1.0 - minf(chance, 1.0), tries)

## Tries needed for a `confidence` chance (0.5 = the median player) of one success.
static func tries_for(chance: float, confidence: float = 0.5) -> float:
	if chance <= 0.0:
		return INF
	if chance >= 1.0:
		return 1.0
	return log(1.0 - confidence) / log(1.0 - chance)

# ---------- levels ----------

## [{id, name, item_level, kind, kills}] for every level that spawns monsters.
static func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog: RefCounted = CampaignCatalogScript.new()
	for entry in LevelSpawnsScript.levels():
		var node_id: String = LevelSpawnsScript.TUTORIAL_NODE_ID if entry.id == LevelSpawnsScript.TUTORIAL_ID else str(entry.id)
		var node := _node(catalog, node_id)
		var data: Dictionary = node.get("level_data", node)
		var loot: Dictionary = data.get("rewards", {}).get("loot", {})
		var kills := kills_per_run(str(entry.id))
		if kills <= 0.0:
			continue
		result.append({"id": str(entry.id), "name": str(entry.name), "item_level": clampi(int(loot.get("item_level", 1)), 1, 3), "kind": "boss" if str(data.get("type", "")) == "boss" else "ordinary", "kills": kills, "creature_kills": creature_kills(str(entry.id))})
	return result

## About how many monsters a run kills: every spawn until the boss surge
## (or FARMING_SURGES surges on a level with no boss), plus the boss.
static func kills_per_run(level_id: String) -> float:
	var profile: Dictionary = LevelSpawnsScript.profile(level_id)
	if str(profile.get("mode", "")) == LevelSpawnsScript.MODE_NONE:
		return 0.0
	var boss_surge := int(profile.get("progress_surge", 0))
	var surges := boss_surge if boss_surge > 0 else FARMING_SURGES
	var kills := 0.0
	for surge in range(surges):
		kills += BalanceData.SURGE_DURATION / maxf(0.1, LevelSpawnsScript.interval_for(profile, surge))
	return floorf(kills) + (1.0 if boss_surge > 0 else 0.0)

## Kills per run split by creature: {creature: kills} (+ "boss": 1 with a boss gate).
static func creature_kills(level_id: String) -> Dictionary:
	var profile: Dictionary = LevelSpawnsScript.profile(level_id)
	var boss_surge := int(profile.get("progress_surge", 0))
	var total := kills_per_run(level_id) - (1.0 if boss_surge > 0 else 0.0)
	var result := {}
	var mix: Dictionary = LevelSpawnsScript.shares(profile)
	if mix.is_empty():
		mix = {"pursuer": 1.0}
	for monster_id in mix:
		result[monster_id] = total * float(mix[monster_id])
	if boss_surge > 0:
		result[CreatureDropsScript.BOSS_KEY] = 1.0
	return result

## Chance of at least one drop in a run from per-creature chances ({creature: percent}).
static func creature_per_run(chances: Dictionary, kills: Dictionary) -> float:
	var miss := 1.0
	for key in kills:
		var chance := float(chances.get(key, 0.0)) / 100.0
		if chance > 0.0:
			miss *= pow(1.0 - minf(chance, 1.0), float(kills[key]))
	return 1.0 - miss

static func _node(catalog: RefCounted, node_id: String) -> Dictionary:
	for act_id in catalog.act_order:
		if catalog.node_ids(act_id).has(node_id):
			return catalog.get_node(act_id, node_id)
	return {}
