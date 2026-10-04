class_name CreatureRegistry
extends RefCounted

## Creatures made in the Creature Lab (scripts/tools/creature_lab.gd), and the
## database that lets every animation be recreated.
##
##   data/creatures/index.json            every creature in development: name,
##                                        family, evolution stage, concept art,
##                                        behavior archetype, reference
##                                        calibration, installed clips, and
##                                        whether it's in the encyclopedia.
##   data/creatures/<id>/prompts.json     the prompt for each animation state,
##                                        with every version ever used.
##   data/creatures/<id>/takes/<take>.json one file per ComfyUI generation:
##                                        prompt, seed, length, models, the
##                                        exact API graph submitted, reference
##                                        hashes, server, prompt id, outputs.
##
## MonsterStats lists creatures with "in_encyclopedia": true next to the
## built-in monsters, and SideViewVisualConfig builds their art from here, so
## a new creature needs no code changes.

const FORMAT_VERSION := 1
const DEFAULT_DATA_ROOT := "res://data/creatures"
const STILLS_ROOT := "res://assets/side-view/creatures"
const CONCEPTS_RELATIVE := "art/creatures/enemies"
const REFERENCES_RELATIVE := "art/creatures/references"
const TAKES_RELATIVE := "art/creatures/animations"

## Behavior a creature borrows from a built-in monster. The id is the
## built-in monster's id (its stats are the starting point), kind is
## DefenseEnemy.EnemyKind.
const ARCHETYPES := {
	"pursuer": {"kind": 0, "label": "Hunter (melee, chases the hero)", "role": "Melee", "target": "Hunts the hero", "display_height": 58.0},
	"breaker": {"kind": 1, "label": "Breaker (melee, attacks the harvester)", "role": "Melee", "target": "Attacks the harvester", "display_height": 112.0},
	"ranged": {"kind": 2, "label": "Ranged (keeps distance, shoots the hero)", "role": "Ranged", "target": "Shoots the hero", "display_height": 90.0},
}
const ARCHETYPE_ORDER := ["pursuer", "breaker", "ranged"]

## The animation states the lab makes for monsters (a subset of
## SideViewVisualConfig.STATES; jump/fall/dash are hero-only).
const STATES := ["idle", "walk", "attack", "windup", "hurt", "death", "spawn"]

## Tests point these at temporary folders.
static var data_root := DEFAULT_DATA_ROOT
static var stills_root := STILLS_ROOT
static var repo_root_override := ""

static var _index: Dictionary = {}
static var _loaded := false

# ---------- paths ----------

static func repo_root() -> String:
	if not repo_root_override.is_empty():
		return repo_root_override
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()

static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path

static func index_path() -> String:
	return _abs(data_root.path_join("index.json"))

static func creature_dir(creature_id: String) -> String:
	return _abs(data_root.path_join(creature_id))

static func prompts_path(creature_id: String) -> String:
	return creature_dir(creature_id).path_join("prompts.json")

static func takes_dir(creature_id: String) -> String:
	return creature_dir(creature_id).path_join("takes")

static func take_path(creature_id: String, take_id: String) -> String:
	return takes_dir(creature_id).path_join(take_id + ".json")

static func concepts_dir() -> String:
	return repo_root().path_join(CONCEPTS_RELATIVE)

static func reference_dir(creature_id: String) -> String:
	return repo_root().path_join(REFERENCES_RELATIVE).path_join(creature_id)

## Where a take's frames (masters, cut frames) are kept, next to the art.
static func take_files_dir(creature_id: String, take_id: String) -> String:
	return repo_root().path_join(TAKES_RELATIVE).path_join(creature_id).path_join(take_id)

static func still_path(creature_id: String) -> String:
	return stills_root.path_join(creature_id + ".png")

# ---------- concept art ----------

## Concept images under art/creatures/enemies/<family>/, grouped by family
## folder and sorted by evolution stage:
## [{"family", "files": [{"path" (repo-relative), "stage", "id", "name"}]}]
static func list_concepts() -> Array:
	var families: Array = []
	var root := DirAccess.open(concepts_dir())
	if root == null:
		return families
	var folders := Array(root.get_directories())
	folders.sort()
	for folder in folders:
		var files: Array = []
		var directory := DirAccess.open(concepts_dir().path_join(folder))
		if directory == null:
			continue
		for filename in directory.get_files():
			var lower := filename.to_lower()
			if not (lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp")):
				continue
			var stem := filename.get_basename()
			files.append({
				"path": CONCEPTS_RELATIVE.path_join(folder).path_join(filename),
				"stage": stage_from_name(stem),
				"id": id_from_name(stem),
				"name": name_from_name(stem),
				"family": str(folder),
			})
		files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.stage) != int(b.stage):
				return int(a.stage) < int(b.stage)
			return str(a.path) < str(b.path))
		if not files.is_empty():
			families.append({"family": str(folder), "files": files})
	return families

## "shell_walker_stage_2" -> 2. Images without a stage number are stage -1
## (listed first, shown as "base").
static func stage_from_name(stem: String) -> int:
	var found := RegEx.create_from_string("(?i)stage[ _-]?(\\d+)").search(stem)
	return int(found.get_string(1)) if found != null else -1

static func id_from_name(stem: String) -> String:
	var text := stem.to_lower()
	var result := ""
	for character in text:
		result += character if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") else "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.strip_edges().trim_prefix("_").trim_suffix("_")

## "shell_walker_stage_2" -> "Shell Walker", "gordon_queen" -> "Gordon Queen".
static func name_from_name(stem: String) -> String:
	var cleaned := RegEx.create_from_string("(?i)[ _-]*stage[ _-]?\\d+").sub(stem, "", true)
	cleaned = cleaned.replace("_", " ").replace("-", " ").strip_edges()
	return cleaned.capitalize() if not cleaned.is_empty() else stem.capitalize()

static func stage_label(stage: int) -> String:
	return "Base" if stage < 0 else "Stage %d" % stage

# ---------- index ----------

static func reload_index() -> void:
	_loaded = false
	_ensure_loaded()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_index = {"format_version": FORMAT_VERSION, "creatures": {}}
	var parsed: Variant = _read_json(index_path())
	if parsed is Dictionary and parsed.get("creatures") is Dictionary:
		_index = parsed

static func ids() -> Array:
	_ensure_loaded()
	var result: Array = (_index["creatures"] as Dictionary).keys()
	result.sort()
	return result

static func has(creature_id: String) -> bool:
	_ensure_loaded()
	return (_index["creatures"] as Dictionary).has(creature_id)

## A copy of the creature's record ({} when unknown).
static func get_creature(creature_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Variant = (_index["creatures"] as Dictionary).get(creature_id, {})
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

## Saves a creature's record (merged over what's there) and writes the index.
static func put_creature(creature_id: String, record: Dictionary) -> Dictionary:
	_ensure_loaded()
	if creature_id.is_empty() or id_from_name(creature_id) != creature_id:
		return {"ok": false, "error": "Ids are lowercase letters, numbers and underscores (got \"%s\")." % creature_id}
	var creatures: Dictionary = _index["creatures"]
	var merged: Dictionary = creatures.get(creature_id, {}).duplicate(true)
	for key in record:
		merged[key] = record[key]
	merged["id"] = creature_id
	merged["updated_at"] = Time.get_datetime_string_from_system()
	creatures[creature_id] = merged
	return _save_index()

static func remove_from_encyclopedia(creature_id: String) -> Dictionary:
	if not has(creature_id):
		return {"ok": false, "error": "Unknown creature."}
	return put_creature(creature_id, {"in_encyclopedia": false})

static func _save_index() -> Dictionary:
	var path := index_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_index["format_version"] = FORMAT_VERSION
	if not _write_json(path, _index):
		return {"ok": false, "error": "Couldn't write %s." % path}
	return {"ok": true, "error": ""}

## Creatures shown in the encyclopedia (and so in MonsterStats), by family
## then stage. Ones whose still picture is missing (not committed, say) are
## left out rather than shown broken.
static func encyclopedia_ids() -> Array:
	var result: Array = []
	for creature_id in ids():
		var record := get_creature(creature_id)
		if not bool(record.get("in_encyclopedia", false)):
			continue
		var still := str(record.get("reference", {}).get("still", ""))
		if still.is_empty() or not FileAccess.file_exists(_abs(still)):
			continue
		result.append(creature_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		var left := get_creature(a)
		var right := get_creature(b)
		if str(left.get("family", "")) != str(right.get("family", "")):
			return str(left.get("family", "")) < str(right.get("family", ""))
		return int(left.get("stage", -1)) < int(right.get("stage", -1)))
	return result

static func archetype(creature_id: String) -> String:
	var value := str(get_creature(creature_id).get("archetype", "pursuer"))
	return value if ARCHETYPES.has(value) else "pursuer"

static func kind(creature_id: String) -> int:
	return int(ARCHETYPES[archetype(creature_id)]["kind"])

## The MonsterStats.MONSTERS-shaped entry for an encyclopedia creature.
static func monster_entry(creature_id: String, stat_keys: Array) -> Dictionary:
	var record := get_creature(creature_id)
	var type: Dictionary = ARCHETYPES[archetype(creature_id)]
	var stage := int(record.get("stage", -1))
	var title := str(record.get("name", creature_id.capitalize()))
	if stage >= 0:
		title += " (%s)" % stage_label(stage)
	return {
		"id": creature_id,
		"name": title,
		"kind": int(type["kind"]),
		"role": str(type["role"]),
		"target": str(type["target"]),
		"desc": str(record.get("desc", "")) if not str(record.get("desc", "")).is_empty() else "New creature from the Creature Lab.",
		"stats": stat_keys,
		"archetype": archetype(creature_id),
		"custom": true,
	}

# ---------- art for SideViewVisualConfig ----------

static var _asset_cache: Dictionary = {}

## The SideViewVisualConfig.ASSETS-shaped dictionary for a creature with a
## prepared reference, else {}. Clips come from
## assets/side-view/animations/<id>_<state>/ like every other actor.
static func asset_for(creature_id: String) -> Dictionary:
	if _asset_cache.has(creature_id):
		return _asset_cache[creature_id]
	var record := get_creature(creature_id)
	var reference: Dictionary = record.get("reference", {})
	if reference.is_empty():
		return {}
	var texture := load_texture(str(reference.get("still", still_path(creature_id))))
	if texture == null:
		return {}
	var anchor_values: Array = reference.get("ground_anchor", [288, 495])
	var anchor := Vector2(float(anchor_values[0]), float(anchor_values[1]))
	var bounds_values: Array = reference.get("visible_bounds", [])
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	if bounds_values.size() == 4:
		bounds = Rect2(float(bounds_values[0]), float(bounds_values[1]), float(bounds_values[2]), float(bounds_values[3]))
	var asset := {
		"texture": texture,
		"animation_folder": creature_id,
		"animation_reference_height": maxf(1.0, float(reference.get("body_height", bounds.size.y))),
		"animation_source_anchor": anchor,
		"visible_bounds": bounds,
		"ground_anchor": anchor,
		"initial_visible_height": float(record.get("display_height", ARCHETYPES[archetype(creature_id)]["display_height"])),
	}
	_asset_cache[creature_id] = asset
	return asset

## Forget built art (after preparing a reference or installing a clip).
static func clear_art_cache() -> void:
	_asset_cache.clear()

## An imported texture when Godot has one, else the PNG read straight from
## disk (art made this run, before the editor imports it).
static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var absolute := _abs(path)
	if not FileAccess.file_exists(absolute):
		return null
	var image := Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

# ---------- prompts ----------

static func load_prompts(creature_id: String) -> Dictionary:
	var parsed: Variant = _read_json(prompts_path(creature_id))
	if parsed is Dictionary and parsed.get("states") is Dictionary:
		return parsed
	return {"format_version": FORMAT_VERSION, "creature": creature_id, "states": {}}

## Every saved version of a state's prompt, oldest first:
## [{"version", "text", "sha256", "created_at", "note"}]
static func prompt_versions(creature_id: String, state: String) -> Array:
	var states: Dictionary = load_prompts(creature_id)["states"]
	return (states.get(state, {}) as Dictionary).get("versions", [])

## The prompt in use for a state ({} when none was saved yet).
static func current_prompt(creature_id: String, state: String) -> Dictionary:
	var states: Dictionary = load_prompts(creature_id)["states"]
	var row: Dictionary = states.get(state, {})
	var current := int(row.get("current", 0))
	for version in row.get("versions", []):
		if int(version.get("version", 0)) == current:
			return version
	return {}

## Saves `text` as the state's current prompt. Identical text reuses its
## version (no duplicates), so the number identifies the exact wording.
## Returns {"ok", "error", "version", "new"}.
static func save_prompt(creature_id: String, state: String, text: String, note: String = "") -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "error": "The prompt is empty.", "version": 0, "new": false}
	var data := load_prompts(creature_id)
	var states: Dictionary = data["states"]
	var row: Dictionary = states.get(state, {"current": 0, "versions": []})
	var versions: Array = row.get("versions", [])
	var digest := cleaned.sha256_text()
	var number := 0
	var created := false
	for version in versions:
		if str(version.get("sha256", "")) == digest:
			number = int(version.get("version", 0))
	if number == 0:
		number = versions.size() + 1
		versions.append({"version": number, "text": cleaned, "sha256": digest, "created_at": Time.get_datetime_string_from_system(), "note": note})
		created = true
	row["versions"] = versions
	row["current"] = number
	states[state] = row
	data["states"] = states
	data["creature"] = creature_id
	data["format_version"] = FORMAT_VERSION
	var path := prompts_path(creature_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if not _write_json(path, data):
		return {"ok": false, "error": "Couldn't write %s." % path, "version": 0, "new": false}
	return {"ok": true, "error": "", "version": number, "new": created}

# ---------- takes ----------

static func new_take_id(state: String) -> String:
	var stamp := Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "")
	return "%s_%s_%03d" % [state, stamp, randi() % 1000]

## Whole-number fields of a take (and of its API graph's inputs). JSON reads
## every number back as a float; these are written as integers again so the
## saved graph is exactly what ComfyUI accepts.
const TAKE_INTS := ["seed", "prompt_version", "steps", "size", "frames_requested", "format_version"]
const GRAPH_INTS := ["noise_seed", "steps", "width", "height", "length", "bit_depth"]

static func save_take(creature_id: String, take: Dictionary) -> bool:
	var path := take_path(creature_id, str(take.get("take_id", "")))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	take["updated_at"] = Time.get_datetime_string_from_system()
	normalize_take(take)
	return _write_json(path, take)

static func normalize_take(take: Dictionary) -> void:
	for key in TAKE_INTS:
		if take.get(key) is float:
			take[key] = int(take[key])
	var graph: Variant = take.get("graph")
	if not graph is Dictionary:
		return
	for node_id in graph:
		var inputs: Dictionary = graph[node_id].get("inputs", {})
		for name in inputs:
			var value: Variant = inputs[name]
			if value is Array and value.size() == 2 and value[0] is String and value[1] is float:
				inputs[name] = [value[0], int(value[1])]
			elif GRAPH_INTS.has(name) and value is float:
				inputs[name] = int(value)

static func load_take(creature_id: String, take_id: String) -> Dictionary:
	var parsed: Variant = _read_json(take_path(creature_id, take_id))
	return parsed if parsed is Dictionary else {}

## Takes for a creature (optionally one state), newest first.
static func list_takes(creature_id: String, state: String = "") -> Array:
	var result: Array = []
	var directory := DirAccess.open(takes_dir(creature_id))
	if directory == null:
		return result
	for filename in directory.get_files():
		if not filename.ends_with(".json"):
			continue
		var take := load_take(creature_id, filename.get_basename())
		if take.is_empty() or (not state.is_empty() and str(take.get("state", "")) != state):
			continue
		result.append(take)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	return result

# ---------- json ----------

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()
	return true
