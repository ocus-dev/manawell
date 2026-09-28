class_name WeaponTypes
extends RefCounted

## Weapon types (axe, sword, gun...) and the default attack animation for each
## type. A weapon names its type on its revision ("weapon_type") and chooses
## where its attack animation comes from ("clip_source"):
##   type  use its type's default (the usual choice; new weapons start here)
##   own   its own attack_clip
##   none  the hero's normal attack
## Revisions without clip_source use "own" when they carry an attack_clip,
## otherwise "type".
##
## Type defaults live in data/weapons/type_clips.json:
##   {"schema_version": 1, "types": {"axe": {"label": "Axe", "revision": 2,
##     "clip": {WeaponClip fields, "sheet": res://assets/weapons/_types/axe/2/clip.png},
##     "project": "<clip importer project folder>"}}}
## Setting a default copies its sheet into a new immutable revision folder, so
## every weapon of that type picks it up without being republished.

const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

const LIBRARY_NAME := "type_clips.json"
const TYPES_ASSET_FOLDER := "_types"
const SOURCES := ["type", "own", "none"]
const BUILTIN := ["sword", "axe", "hammer", "spear", "dagger", "club", "staff", "gun", "bow"]
const KEYWORDS := {
	"axe": ["axe", "ax ", "hatchet", "cleaver"],
	"sword": ["sword", "blade", "saber", "sabre", "katana", "rapier", "cutlass"],
	"hammer": ["hammer", "maul", "mallet"],
	"spear": ["spear", "lance", "pike", "halberd", "trident", "glaive"],
	"dagger": ["dagger", "knife", "dirk", "shiv"],
	"club": ["club", "bat", "stick", "baton", "batton", "mace", "cudgel"],
	"staff": ["staff", "rod", "wand"],
	"gun": ["gun", "rifle", "pistol", "blaster", "cannon", "shotgun", "smg", "breech"],
	"bow": ["bow", "crossbow"],
}

static var _game_library: Dictionary = {}
static var _game_library_loaded := false

static func slug(text: String) -> String:
	var result := ""
	for character in text.strip_edges().to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			result += character
		elif not result.is_empty() and not result.ends_with("_"):
			result += "_"
	return result.trim_suffix("_").left(40)

static func label_of(type_id: String, library: Dictionary = {}) -> String:
	var entry: Dictionary = library.get("types", {}).get(type_id, {})
	if not str(entry.get("label", "")).is_empty():
		return str(entry.label)
	return type_id.replace("_", " ").capitalize()

## Best guess at a type from a weapon's name ("" if nothing matches).
static func guess(name: String) -> String:
	var text := " " + name.to_lower() + " "
	for type_id in KEYWORDS:
		for word in KEYWORDS[type_id]:
			if text.contains(str(word)):
				return str(type_id)
	return ""

static func is_valid_type(type_id: Variant) -> bool:
	return type_id is String and (type_id == "" or (type_id.is_valid_identifier() and type_id == type_id.to_lower() and type_id.length() <= 40))

## A type id from anything typed in ("Great Sword" -> great_sword).
static func type_id_from(text: String) -> String:
	var id := slug(text)
	if not id.is_empty() and not id.is_valid_identifier():
		id = ("t_" + id).left(40)
	return id

## "type" | "own" | "none" for a draft or revision.
static func clip_source(revision: Dictionary) -> String:
	var source := str(revision.get("clip_source", ""))
	if SOURCES.has(source):
		return source
	return "own" if WeaponClipScript.is_set(revision.get("attack_clip", {})) else "type"

## The attack clip a weapon actually plays ({} for the hero's normal attack).
static func resolve_clip(revision: Dictionary, library: Dictionary) -> Dictionary:
	match clip_source(revision):
		"own":
			var own: Variant = revision.get("attack_clip", {})
			return own if WeaponClipScript.is_set(own) else {}
		"type":
			return default_clip(library, str(revision.get("weapon_type", "")))
	return {}

static func default_clip(library: Dictionary, type_id: String) -> Dictionary:
	if type_id.is_empty():
		return {}
	var clip: Variant = library.get("types", {}).get(type_id, {}).get("clip", {})
	return clip if WeaponClipScript.is_set(clip) else {}

static func library_path(data_root: String) -> String:
	return data_root.path_join(LIBRARY_NAME)

static func load_library(data_root: String) -> Dictionary:
	var path := library_path(data_root)
	if not FileAccess.file_exists(path):
		return {"schema_version": 1, "types": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("types") is Dictionary:
		return {"schema_version": 1, "types": {}}
	return parsed

## The published library, read once per run by the game.
static func game_library() -> Dictionary:
	if not _game_library_loaded:
		_game_library = load_library("res://data/weapons")
		_game_library_loaded = true
	return _game_library

static func reload_game_library() -> void:
	_game_library_loaded = false

## Every type worth offering: built-ins, types with defaults, and `extra`.
static func known_types(library: Dictionary, extra: Array = []) -> Array:
	var hidden: Array = library.get("hidden", [])
	var result: Array = BUILTIN.filter(func(type_id: String) -> bool: return not hidden.has(type_id))
	for type_id in library.get("types", {}):
		if not result.has(type_id):
			result.append(type_id)
	for type_id in extra:
		if is_valid_type(type_id) and not str(type_id).is_empty() and not result.has(type_id):
			result.append(type_id)
	return result

## Makes `clip` the default attack animation for `type_id`. The clip's sheet
## (a draft file or another published sheet) is copied into
## <asset_root>/_types/<type>/<revision>/clip.png. Returns {ok, error, clip}.
static func set_default(type_id: String, clip: Dictionary, data_root: String, asset_root: String) -> Dictionary:
	if not is_valid_type(type_id) or type_id.is_empty():
		return {"ok": false, "error": "Pick a weapon type first.", "clip": {}}
	if not WeaponClipScript.is_set(clip):
		return {"ok": false, "error": "There's no animation to use.", "clip": {}}
	var library := load_library(data_root)
	var types: Dictionary = library.get("types", {})
	var previous: Dictionary = types.get(type_id, {})
	var revision := int(previous.get("revision", 0)) + 1
	var folder := asset_root.path_join(TYPES_ASSET_FOLDER).path_join(type_id).path_join(str(revision))
	var source := WeaponClipScript.sheet_path(clip)
	var source_file := ProjectSettings.globalize_path(source) if source.begins_with("res://") else source
	var target := folder.path_join("clip.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if not FileAccess.file_exists(source_file) or DirAccess.copy_absolute(source_file, ProjectSettings.globalize_path(target)) != OK:
		return {"ok": false, "error": "Couldn't copy the animation sheet (%s)." % source, "clip": {}}
	var published := WeaponClipScript.normalize(clip)
	var project := str(published.get("project", previous.get("project", "")))
	var hand := WeaponClipScript.hand_path(clip)
	published.erase("source")
	published.erase("project")
	published.erase("hand_source")
	published.erase("hand_sheet")
	published["sheet"] = target
	if not hand.is_empty():
		var hand_file := ProjectSettings.globalize_path(hand) if hand.begins_with("res://") else hand
		var hand_target := folder.path_join("hand.png")
		if not FileAccess.file_exists(hand_file) or DirAccess.copy_absolute(hand_file, ProjectSettings.globalize_path(hand_target)) != OK:
			return {"ok": false, "error": "Couldn't copy the front-hand sheet (%s)." % hand, "clip": {}}
		published["hand_sheet"] = hand_target
	var check := WeaponClipScript.validate(published)
	if not check.valid:
		return {"ok": false, "error": str(check.error), "clip": {}}
	_backup(library, data_root)
	types[type_id] = {"label": label_of(type_id, library), "revision": revision, "clip": published, "project": project}
	library["schema_version"] = 1
	library["types"] = types
	if not _write(library, data_root):
		return {"ok": false, "error": "Couldn't write %s." % library_path(data_root), "clip": {}}
	reload_game_library()
	return {"ok": true, "error": "", "clip": published}

static func remove_default(type_id: String, data_root: String) -> bool:
	var library := load_library(data_root)
	if not library.get("types", {}).has(type_id):
		return false
	_backup(library, data_root)
	# Keep the category (and its revision count); only the animation goes.
	var entry: Dictionary = library.types[type_id]
	entry.erase("clip")
	entry.erase("project")
	reload_game_library()
	return _write(library, data_root)

# ---------- categories ----------

## Adds a weapon category (type). Returns its id ("" if the name is empty).
static func add_category(name: String, data_root: String) -> String:
	var type_id := type_id_from(name)
	if type_id.is_empty():
		return ""
	var library := load_library(data_root)
	var types: Dictionary = library.get("types", {})
	var entry: Dictionary = types.get(type_id, {})
	entry["label"] = name.strip_edges().left(40) if not name.strip_edges().is_empty() else label_of(type_id)
	types[type_id] = entry
	library["types"] = types
	var hidden: Array = library.get("hidden", [])
	hidden.erase(type_id)
	library["hidden"] = hidden
	library["schema_version"] = 1
	_backup(library, data_root)
	_write(library, data_root)
	reload_game_library()
	return type_id

static func rename_category(type_id: String, name: String, data_root: String) -> bool:
	if name.strip_edges().is_empty():
		return false
	var library := load_library(data_root)
	var types: Dictionary = library.get("types", {})
	var entry: Dictionary = types.get(type_id, {})
	entry["label"] = name.strip_edges().left(40)
	types[type_id] = entry
	library["types"] = types
	_backup(library, data_root)
	reload_game_library()
	return _write(library, data_root)

## Removes a category from the list (and its default animation). Weapons that
## still use it keep their type, so it shows again while any weapon has it.
static func remove_category(type_id: String, data_root: String) -> bool:
	var library := load_library(data_root)
	_backup(library, data_root)
	library.get("types", {}).erase(type_id)
	if BUILTIN.has(type_id):
		var hidden: Array = library.get("hidden", [])
		if not hidden.has(type_id):
			hidden.append(type_id)
		library["hidden"] = hidden
	reload_game_library()
	return _write(library, data_root)

static func _backup(library: Dictionary, data_root: String) -> void:
	if library.get("types", {}).is_empty():
		return
	var history := data_root.path_join("history")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(history))
	var file := FileAccess.open(history.path_join("type_clips-%d.json" % int(Time.get_unix_time_from_system() * 1000.0)), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(library, "\t"))

static func _write(library: Dictionary, data_root: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(data_root))
	var file := FileAccess.open(library_path(data_root), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(library, "\t"))
	return true
