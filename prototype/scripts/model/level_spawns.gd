class_name LevelSpawns
extends RefCounted

## Which monsters each level spawns, and how often (edited in the Dev
## Encyclopedia's "Level spawns" tab, saved to res://data/level_spawns.json).
##
## Every level has a mode:
##   "default"  the game's built-in surge director (the original spawning)
##   "custom"   spawn every `interval` seconds, `surge_speedup`% faster for each
##              surge reached (never faster than `min_interval`), at most
##              `max_alive` on screen, creatures picked by `mix` weights
##   "none"     no monsters (the tutorial's default)
## Monsters are the ones in the encyclopedia (MonsterStats.MONSTERS).

const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")

const DATA_PATH := "res://data/level_spawns.json"
## Exported builds can't write into res://, so saves go here instead.
const EXPORTED_BUILD_PATH := "user://level_spawns.json"
const FORMAT_VERSION := 1

const TUTORIAL_ID := "tutorial"
## The campaign map's slot for the tutorial (Sector B). It *is* the tutorial:
## one level, one set of settings, one save.
const TUTORIAL_NODE_ID := "act_01_node_02"
const MODE_DEFAULT := "default"
const MODE_CUSTOM := "custom"
const MODE_NONE := "none"
const MODES := [MODE_DEFAULT, MODE_CUSTOM, MODE_NONE]

const SETTING_DEFS := {
	"interval": {"label": "Spawn every", "hint": "Seconds between spawns before any surge", "min": 0.3, "max": 20.0, "step": 0.1, "default": 3.0},
	"surge_speedup": {"label": "Faster per surge", "hint": "% shorter wait for each surge reached", "min": 0.0, "max": 50.0, "step": 1.0, "default": 10.0},
	"min_interval": {"label": "Fastest spawn", "hint": "Surges can't push spawns below this (s)", "min": 0.2, "max": 10.0, "step": 0.1, "default": 0.6},
	"max_alive": {"label": "Max alive", "hint": "Spawning waits while this many are out", "min": 1.0, "max": 60.0, "step": 1.0, "default": 12.0},
}
const SETTING_ORDER := ["interval", "surge_speedup", "min_interval", "max_alive"]

## Progression: reach `progress_surge` to face the zone boss; killing it clears
## the level (unlocks the next one). 0 = no boss, the level just farms.
const PROGRESS_DEFS := {
	"progress_surge": {"label": "Surge to progress", "hint": "Boss comes at this surge (0 = none)", "min": 0.0, "max": 50.0, "step": 1.0, "default": 8.0},
	"boss_health": {"label": "Boss health", "hint": "× the creature's normal health", "min": 1.0, "max": 50.0, "step": 0.5, "default": 8.0},
	"boss_damage": {"label": "Boss damage", "hint": "× the creature's normal damage", "min": 0.5, "max": 10.0, "step": 0.1, "default": 1.5},
	"boss_size": {"label": "Boss size", "hint": "× the creature's normal size", "min": 1.0, "max": 3.0, "step": 0.05, "default": 1.5},
}
const PROGRESS_ORDER := ["progress_surge", "boss_health", "boss_damage", "boss_size"]
const DEFAULT_BOSS_MONSTER := "breaker"
const WEIGHT_MAX := 100.0

static var _levels: Dictionary = {}
static var _saved: Dictionary = {}
static var _loaded := false
static var last_load_message := ""

# ---------- levels ----------

## [{id, name, type}] in editor order: the tutorial area, then the campaign.
static func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id": TUTORIAL_ID, "name": "Tutorial (Sector B)", "type": "tutorial"}]
	var catalog: RefCounted = CampaignCatalogScript.new()
	for act_id in catalog.act_order:
		for node_id in catalog.node_ids(act_id):
			if node_id == TUTORIAL_NODE_ID:
				continue # listed once, as the tutorial
			var node: Dictionary = catalog.get_node(act_id, node_id)
			result.append({"id": node_id, "name": str(node.get("display_name", node.get("level_data", {}).get("display_name", node_id))), "type": str(node.get("type", node.get("level_data", {}).get("type", "")))})
	return result

## The id settings are stored under (the tutorial's map slot -> "tutorial").
static func canonical_id(level_id: String) -> String:
	return TUTORIAL_ID if level_id == TUTORIAL_NODE_ID else level_id

static func level_name(level_id: String) -> String:
	level_id = canonical_id(level_id)
	for entry in levels():
		if entry.id == level_id:
			return str(entry.name)
	return level_id

# ---------- profiles ----------

static func default_profile(level_id: String) -> Dictionary:
	var mix := {}
	for monster_id in MonsterStatsScript.monster_ids():
		mix[monster_id] = WEIGHT_MAX if monster_id == "pursuer" else 0.0
	var profile := {"mode": MODE_NONE if level_id == TUTORIAL_ID else MODE_DEFAULT, "mix": mix}
	for key in SETTING_ORDER:
		profile[key] = clamp_value(key, float(SETTING_DEFS[key].default))
	for key in PROGRESS_ORDER:
		profile[key] = clamp_value(key, float(PROGRESS_DEFS[key].default))
	profile["boss_monster"] = DEFAULT_BOSS_MONSTER
	return profile

## The level's settings (a copy), with defaults filled in.
static func profile(level_id: String) -> Dictionary:
	level_id = canonical_id(level_id)
	_ensure_loaded()
	return _normalized(level_id, _levels.get(level_id, {}))

static func set_profile(level_id: String, value: Dictionary) -> void:
	_ensure_loaded()
	var normalized := _normalized(level_id, value)
	if normalized == default_profile(level_id):
		_levels.erase(level_id)
	else:
		_levels[level_id] = normalized

static func set_mode(level_id: String, mode: String) -> void:
	var current := profile(level_id)
	current.mode = mode if MODES.has(mode) else current.mode
	set_profile(level_id, current)

static func set_value(level_id: String, key: String, value: float) -> void:
	if not SETTING_DEFS.has(key) and not PROGRESS_DEFS.has(key):
		return
	var current := profile(level_id)
	current[key] = clamp_value(key, value)
	set_profile(level_id, current)

static func set_weight(level_id: String, monster_id: String, weight: float) -> void:
	var current := profile(level_id)
	current.mix[monster_id] = clampf(weight, 0.0, WEIGHT_MAX)
	set_profile(level_id, current)

static func set_boss_monster(level_id: String, monster_id: String) -> void:
	if not MonsterStatsScript.monster_ids().has(monster_id):
		return
	var current := profile(level_id)
	current.boss_monster = monster_id
	set_profile(level_id, current)

## The surge that brings the boss (0 = this level has no boss gate).
static func progress_surge(level_id: String) -> int:
	return int(profile(level_id).get("progress_surge", 0))

## Plain-language progression line for the editor.
static func describe_progress(value: Dictionary) -> String:
	var surge := int(value.get("progress_surge", 0))
	if surge <= 0:
		return "No boss: this level is for farming only and never unlocks anything."
	var boss_name := str(MonsterStatsScript.monster(str(value.get("boss_monster", DEFAULT_BOSS_MONSTER))).get("name", "Boss"))
	return "Reach surge %d (about %d:%02d in) and a boss %s spawns: %s× health, %s× damage. Kill it to clear the level and unlock the next one." % [surge, surge * 20 / 60, surge * 20 % 60, boss_name, _num(float(value.boss_health)), _num(float(value.boss_damage))]

static func _num(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")

static func reset_level(level_id: String) -> void:
	_ensure_loaded()
	_levels.erase(level_id)

static func clamp_value(key: String, value: float) -> float:
	var definition: Dictionary = SETTING_DEFS[key] if SETTING_DEFS.has(key) else PROGRESS_DEFS[key]
	var clamped := clampf(value, float(definition.min), float(definition.max))
	return snappedf(clamped, float(definition.step))

static func is_modified(level_id: String) -> bool:
	_ensure_loaded()
	return _levels.has(level_id)

# ---------- spawning math (used by the game) ----------

## Seconds between spawns once `surges` surges have been reached.
static func interval_for(value: Dictionary, surges: int) -> float:
	var base := float(value.get("interval", SETTING_DEFS.interval.default))
	var speedup := float(value.get("surge_speedup", 0.0)) / 100.0
	var floor_seconds := minf(base, float(value.get("min_interval", SETTING_DEFS.min_interval.default)))
	return maxf(floor_seconds, base * pow(1.0 - speedup, maxi(0, surges)))

## Mix as shares that add up to 1 ({} if every weight is 0).
static func shares(value: Dictionary) -> Dictionary:
	var total := 0.0
	for monster_id in MonsterStatsScript.monster_ids():
		total += maxf(0.0, float(value.get("mix", {}).get(monster_id, 0.0)))
	var result := {}
	if total <= 0.0:
		return result
	for monster_id in MonsterStatsScript.monster_ids():
		var weight := maxf(0.0, float(value.get("mix", {}).get(monster_id, 0.0)))
		if weight > 0.0:
			result[monster_id] = weight / total
	return result

## Which monster the `index`-th spawn is. Deterministic (the same run always
## spawns the same order) and evenly spread across the mix.
static func pick(value: Dictionary, index: int) -> String:
	var mix := shares(value)
	if mix.is_empty():
		return ""
	var point := fposmod(float(index) * 0.6180339887498949 + 0.5, 1.0)
	var running := 0.0
	var last := ""
	for monster_id in MonsterStatsScript.monster_ids():
		if not mix.has(monster_id):
			continue
		running += float(mix[monster_id])
		last = monster_id
		if point < running:
			return monster_id
	return last

## Plain-language summary for the editor.
static func describe(value: Dictionary) -> String:
	match str(value.get("mode", MODE_DEFAULT)):
		MODE_NONE:
			return "No monsters spawn here."
		MODE_DEFAULT:
			return "Uses the game's built-in surge spawning."
	var parts: Array[String] = []
	var mix := shares(value)
	if mix.is_empty():
		return "No creature has any weight, so nothing spawns. Raise at least one creature."
	for monster_id in MonsterStatsScript.monster_ids():
		if mix.has(monster_id):
			parts.append("%d%% %s" % [roundi(float(mix[monster_id]) * 100.0), MonsterStatsScript.monster(monster_id).get("name", monster_id)])
	var first := interval_for(value, 0)
	return "One every %.1fs to start (%d a minute), every %.1fs by surge 5. Up to %d at once. %s." % [first, roundi(60.0 / first), interval_for(value, 5), int(value.max_alive), ", ".join(parts)]

# ---------- saving ----------

static func has_unsaved_changes() -> bool:
	_ensure_loaded()
	return _levels != _saved

static func to_json() -> String:
	_ensure_loaded()
	var keys := _levels.keys()
	keys.sort()
	var out := {}
	for key in keys:
		out[key] = _levels[key]
	return JSON.stringify({"format_version": FORMAT_VERSION, "levels": out}, "\t")

## Returns {ok, path, message}.
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
	_saved = _levels.duplicate(true)
	return {"ok": true, "path": target, "message": "Saved to %s." % target}

## Forgets unsaved edits and reads the saved file again.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_levels = {}
	last_load_message = ""
	_load_file(DATA_PATH)
	if OS.has_feature("template"):
		_load_file(EXPORTED_BUILD_PATH)
	_saved = _levels.duplicate(true)

static func _load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("levels", null) is Dictionary:
		last_load_message = "%s isn't valid; using defaults." % path
		push_warning("LevelSpawns: " + last_load_message)
		return
	for level_id in parsed.levels.keys():
		if parsed.levels[level_id] is Dictionary:
			_levels[str(level_id)] = _normalized(str(level_id), parsed.levels[level_id])

static func _normalized(level_id: String, value: Dictionary) -> Dictionary:
	var result := default_profile(level_id)
	if MODES.has(str(value.get("mode", ""))):
		result.mode = str(value.mode)
	for key in SETTING_ORDER + PROGRESS_ORDER:
		if value.has(key) and (value[key] is float or value[key] is int):
			result[key] = clamp_value(key, float(value[key]))
	if MonsterStatsScript.monster_ids().has(str(value.get("boss_monster", ""))):
		result.boss_monster = str(value.boss_monster)
	var mix: Variant = value.get("mix", {})
	if mix is Dictionary:
		for monster_id in MonsterStatsScript.monster_ids():
			if mix.has(monster_id) and (mix[monster_id] is float or mix[monster_id] is int):
				result.mix[monster_id] = clampf(float(mix[monster_id]), 0.0, WEIGHT_MAX)
	return result
