class_name MonsterStats
extends RefCounted

## Tunable monster stats used by DefenseEnemy at runtime.
##
## Defaults come from data/balance.gd. Tuned values live in
## res://data/monster_stats.json and are applied on top of the defaults the
## first time any stat is read. The Monster Encyclopedia dev tool edits these
## values live and saves them back to that file.

const BalanceData = preload("res://data/balance.gd")
const CreatureRegistryScript = preload("res://scripts/model/creature_registry.gd")

const DATA_PATH := "res://data/monster_stats.json"
## Exported builds cannot write into res://, so saves fall back to this path
## and it is loaded on top of DATA_PATH in exported builds only.
const EXPORTED_BUILD_PATH := "user://monster_stats.json"
const FORMAT_VERSION := 1

## The built-in monsters. Creatures added in the Creature Lab follow them (see
## monsters()); each borrows the stats of one of these (its archetype).
## Order here is the order shown in the encyclopedia.
const MONSTERS: Array = [
	{
		"id": "pursuer",
		"name": "Pursuer",
		"kind": 0,
		"role": "Melee",
		"target": "Hunts the hero",
		"desc": "Fast, fragile biological hunter. Ignores the harvester and runs straight at the pilot.",
		"stats": ["health", "move_speed", "damage", "attack_range", "attack_interval"],
	},
	{
		"id": "breaker",
		"name": "Breaker",
		"kind": 1,
		"role": "Melee",
		"target": "Attacks the harvester",
		"desc": "Slow, heavy bruiser. Walks past the pilot and batters the harvester until it breaks.",
		"stats": ["health", "move_speed", "damage", "attack_range", "attack_interval"],
	},
	{
		"id": "ranged",
		"name": "Ranged",
		"kind": 2,
		"role": "Ranged",
		"target": "Shoots the hero",
		"desc": "Keeps its distance, telegraphs with a wind-up, then fires a slow projectile at the pilot.",
		"stats": ["health", "move_speed", "damage", "stop_range", "attack_interval", "windup", "projectile_speed"],
	},
]

const STAT_DEFS: Dictionary = {
	"health": {"label": "Health", "hint": "Hit points", "min": 1.0, "max": 1000.0, "step": 1.0},
	"move_speed": {"label": "Move speed", "hint": "Units per second", "min": 0.0, "max": 12.0, "step": 0.1},
	"damage": {"label": "Damage", "hint": "Per hit, before surge scaling", "min": 0.0, "max": 200.0, "step": 1.0},
	"attack_range": {"label": "Attack range", "hint": "Units from its target", "min": 0.2, "max": 6.0, "step": 0.1},
	"attack_interval": {"label": "Attack interval", "hint": "Seconds between attacks", "min": 0.1, "max": 10.0, "step": 0.05},
	"stop_range": {"label": "Firing range", "hint": "Stops and shoots within this many units", "min": 1.0, "max": 30.0, "step": 0.5},
	"windup": {"label": "Wind-up", "hint": "Warning time before each shot (s)", "min": 0.05, "max": 3.0, "step": 0.05},
	"projectile_speed": {"label": "Projectile speed", "hint": "Units per second", "min": 1.0, "max": 40.0, "step": 0.5},
}

const DEFAULTS: Dictionary = {
	"pursuer": {
		"health": BalanceData.PURSUER_HEALTH,
		"move_speed": BalanceData.PURSUER_SPEED,
		"damage": BalanceData.PURSUER_DAMAGE,
		"attack_range": BalanceData.PURSUER_RANGE,
		"attack_interval": BalanceData.MELEE_ATTACK_INTERVAL,
	},
	"breaker": {
		"health": BalanceData.BREAKER_HEALTH,
		"move_speed": BalanceData.BREAKER_SPEED,
		"damage": BalanceData.BREAKER_DAMAGE,
		"attack_range": BalanceData.BREAKER_RANGE,
		"attack_interval": BalanceData.MELEE_ATTACK_INTERVAL,
	},
	"ranged": {
		"health": BalanceData.RANGED_HEALTH,
		"move_speed": BalanceData.RANGED_SPEED,
		"damage": BalanceData.RANGED_DAMAGE,
		"stop_range": BalanceData.RANGED_STOP_RANGE,
		"attack_interval": BalanceData.RANGED_ATTACK_INTERVAL,
		"windup": BalanceData.RANGED_WINDUP,
		"projectile_speed": BalanceData.RANGED_PROJECTILE_SPEED,
	},
}

static var _values: Dictionary = {}
static var _saved: Dictionary = {}
static var _loaded := false
static var last_load_message := ""

# ---------- lookup ----------

## Every encyclopedia monster, grouped by family and sorted by evolution
## stage: the three originals (now stages of Creature Lab families, named
## after them) and the Creature Lab's creatures (data/creatures/index.json).
static func monsters() -> Array:
	var by_id := {}
	for entry in MONSTERS:
		by_id[entry["id"]] = _builtin_entry(str(entry["id"]))
	for creature_id in CreatureRegistryScript.encyclopedia_ids():
		var base_id := CreatureRegistryScript.archetype(creature_id)
		by_id[creature_id] = CreatureRegistryScript.monster_entry(creature_id, _builtin(base_id).get("stats", []))
	var result: Array = []
	for id in CreatureRegistryScript.sort_by_lineage(by_id.keys()):
		result.append(by_id[id])
	return result

static func monster_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster in monsters():
		ids.append(str(monster["id"]))
	return ids

static func monster(monster_id: String) -> Dictionary:
	if not _builtin(monster_id).is_empty():
		return _builtin_entry(monster_id)
	if CreatureRegistryScript.has(monster_id) and CreatureRegistryScript.encyclopedia_ids().has(monster_id):
		return CreatureRegistryScript.monster_entry(monster_id, _builtin(CreatureRegistryScript.archetype(monster_id)).get("stats", []))
	return {}

static func _builtin(monster_id: String) -> Dictionary:
	for entry in MONSTERS:
		if entry["id"] == monster_id:
			return entry
	return {}

## An original monster's entry with its family name and stage
## ("Void Stalker (Stage 2)"); "legacy_name" keeps the old one ("Pursuer").
static func _builtin_entry(monster_id: String) -> Dictionary:
	var entry: Dictionary = _builtin(monster_id).duplicate()
	var info := CreatureRegistryScript.builtin_info(monster_id)
	entry["legacy_name"] = entry["name"]
	entry["name"] = "%s (%s)" % [info.name, CreatureRegistryScript.stage_label(int(info.stage))]
	entry["family"] = info.family
	entry["stage"] = int(info.stage)
	if not str(info.desc).is_empty():
		entry["desc"] = info.desc
	return entry

## The built-in monster whose behavior (and starting stats) a monster uses:
## itself for built-ins, the archetype for Creature Lab creatures.
static func archetype(monster_id: String) -> String:
	if DEFAULTS.has(monster_id):
		return monster_id
	return CreatureRegistryScript.archetype(monster_id)

## The original monster for a DefenseEnemy kind (0 pursuer, 1 breaker, 2 ranged).
static func id_for_kind(kind: int) -> String:
	for entry in MONSTERS:
		if int(entry["kind"]) == kind:
			return str(entry["id"])
	return "pursuer"

static func stat_keys(monster_id: String) -> Array:
	return monster(monster_id).get("stats", [])

static func default_value(monster_id: String, key: String) -> float:
	return float(defaults_for(monster_id).get(key, 0.0))

## Default stats: data/balance.gd for built-ins; a Creature Lab creature
## starts from its archetype's defaults, overridden by its own "base_stats".
static func defaults_for(monster_id: String) -> Dictionary:
	if DEFAULTS.has(monster_id):
		return DEFAULTS[monster_id]
	if not CreatureRegistryScript.has(monster_id):
		return {}
	var row: Dictionary = (DEFAULTS[archetype(monster_id)] as Dictionary).duplicate()
	var own: Variant = CreatureRegistryScript.get_creature(monster_id).get("base_stats", {})
	if own is Dictionary:
		for key in own:
			if row.has(key) and (typeof(own[key]) == TYPE_INT or typeof(own[key]) == TYPE_FLOAT):
				row[key] = clamp_value(str(key), float(own[key]))
	return row

static func _all_defaults() -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for id in monster_ids():
		if not result.has(id):
			result[id] = defaults_for(id).duplicate()
	return result

## Rows for creatures added after the stats were loaded.
static func _ensure_row(monster_id: String) -> void:
	if not _values.has(monster_id) and not defaults_for(monster_id).is_empty():
		_values[monster_id] = defaults_for(monster_id).duplicate()

static func get_stat(monster_id: String, key: String) -> float:
	_ensure_loaded()
	var row: Dictionary = _values.get(monster_id, {})
	if row.has(key):
		return float(row[key])
	return default_value(monster_id, key)

static func set_stat(monster_id: String, key: String, value: float) -> float:
	_ensure_loaded()
	_ensure_row(monster_id)
	if not _values.has(monster_id) or not STAT_DEFS.has(key) or not is_finite(value):
		return get_stat(monster_id, key)
	var clamped := clamp_value(key, value)
	_values[monster_id][key] = clamped
	return clamped

static func clamp_value(key: String, value: float) -> float:
	var definition: Dictionary = STAT_DEFS[key]
	var clamped := clampf(value, float(definition["min"]), float(definition["max"]))
	return snappedf(clamped, float(definition["step"]))

# ---------- state ----------

static func is_modified(monster_id: String) -> bool:
	for key in stat_keys(monster_id):
		if not is_equal_approx(get_stat(monster_id, key), default_value(monster_id, key)):
			return true
	return false

static func modified_count() -> int:
	var count := 0
	for id in monster_ids():
		if is_modified(id):
			count += 1
	return count

static func has_unsaved_changes() -> bool:
	_ensure_loaded()
	return JSON.stringify(export_map()) != JSON.stringify(_saved)

static func reset_monster(monster_id: String) -> void:
	_ensure_loaded()
	if not defaults_for(monster_id).is_empty():
		_values[monster_id] = defaults_for(monster_id).duplicate()

static func reset_all() -> void:
	_values = _all_defaults()
	_loaded = true

## Drops in-memory edits and reloads from disk. Tests use this for isolation.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()

## Stats keyed by monster id, e.g. {"pursuer": {"health": 20.0, ...}, ...}
static func export_map() -> Dictionary:
	_ensure_loaded()
	var result := {}
	for id in monster_ids():
		var row := {}
		for key in stat_keys(id):
			row[key] = get_stat(id, key)
		result[id] = row
	return result

## Applies a map in the export_map() shape. Unknown monsters and stats are
## ignored. Returns the number of values applied.
static func apply_map(map: Dictionary) -> int:
	_ensure_loaded()
	var applied := 0
	var source: Dictionary = map.get("monsters", map)
	for id in monster_ids():
		var row = source.get(id)
		if typeof(row) != TYPE_DICTIONARY:
			continue
		for key in stat_keys(id):
			var raw = row.get(key)
			if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
				set_stat(id, key, float(raw))
				applied += 1
	return applied

# ---------- disk ----------

static func to_json() -> String:
	return JSON.stringify({"format_version": FORMAT_VERSION, "monsters": export_map()}, "\t")

## Saves to res://data/monster_stats.json (or user:// in exported builds).
## Returns {"ok": bool, "path": String, "message": String}.
static func save_to_disk(path: String = "") -> Dictionary:
	_ensure_loaded()
	var target := path
	if target.is_empty():
		target = EXPORTED_BUILD_PATH if OS.has_feature("template") else DATA_PATH
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": target, "message": "Couldn't write %s (%s)." % [target, error_string(FileAccess.get_open_error())]}
	file.store_string(to_json() + "\n")
	file.close()
	_saved = export_map()
	return {"ok": true, "path": target, "message": "Saved to %s." % target}

static func load_from_disk(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		last_load_message = "%s is not valid JSON; using defaults." % path
		push_warning("MonsterStats: " + last_load_message)
		return false
	apply_map(parsed)
	return true

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_values = _all_defaults()
	last_load_message = ""
	var loaded_any := load_from_disk(DATA_PATH)
	if OS.has_feature("template"):
		loaded_any = load_from_disk(EXPORTED_BUILD_PATH) or loaded_any
	_saved = export_map()
	if loaded_any and last_load_message.is_empty():
		last_load_message = "Loaded tuned stats."
