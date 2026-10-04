class_name WeaponLootRegistration
extends RefCounted

const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const DEFAULT_PATH := "res://data/loot/weapon_registrations.json"
const DEFAULT_INDEX_PATH := "res://data/weapons/index.json"
const DEFAULT_DATA_ROOT := "res://data/weapons"
const TABLE_ID := "foundry_physical_v1"
const SCHEMA_VERSION := 1

static func empty_document() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "registration_revision": 0, "tables": {TABLE_ID: {"weapons": {}}}}

static func load_document(path: String = DEFAULT_PATH) -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return empty_document()
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary:
		return empty_document()
	var validation := validate_document(value)
	return value if validation.valid else empty_document()

static func validate_document(document: Dictionary) -> Dictionary:
	if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
		return _failure("registration schema version is invalid")
	var revision: Variant = document.get("registration_revision", 0)
	if not _valid_integer(revision) or int(revision) < 0:
		return _failure("registration revision is invalid")
	var tables: Variant = document.get("tables", {})
	if not tables is Dictionary:
		return _failure("registration tables must be an object")
	for table_id in tables.keys():
		var table: Variant = tables[table_id]
		if not table is Dictionary or not table.get("weapons", {}) is Dictionary:
			return _failure("registration table is invalid")
		for weapon_id in table.weapons.keys():
			var entry: Variant = table.weapons[weapon_id]
			var result := validate_entry(entry, str(weapon_id))
			if not result.valid:
				return result
	return {"valid": true, "diagnostics": []}

static func validate_entry(entry: Variant, weapon_id: String = "") -> Dictionary:
	if not entry is Dictionary:
		return _failure("registration entry must be an object")
	if weapon_id.is_empty() or weapon_id.contains("/") or weapon_id.contains("\\") or weapon_id.contains("..") or weapon_id.contains(":"):
		return _failure("registration weapon ID is unsafe")
	if str(entry.get("weapon_id", weapon_id)) != weapon_id:
		return _failure("registration weapon ID does not match its key")
	if not entry.get("enabled", false) is bool:
		return _failure("registration enabled flag is invalid")
	var weight: Variant = entry.get("weight", 1.0)
	if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) <= 0.0 or float(weight) > 1000.0:
		return _failure("registration weight must be finite and in (0,1000]")
	for field in ["min_item_level", "max_item_level", "revision"]:
		var field_value: Variant = entry.get(field, 0)
		if not _valid_integer(field_value) or int(field_value) < 1 or (field != "revision" and int(field_value) > 3):
			return _failure("registration %s is invalid" % field)
	if int(entry.min_item_level) > int(entry.max_item_level):
		return _failure("registration item level range is invalid")
	if str(entry.get("recipe_id", "")).is_empty():
		return _failure("registration recipe ID is required")
	# Optional per-creature chances (CreatureDrops), percent per kill.
	if entry.has("monster_chances"):
		var chances: Variant = entry.monster_chances
		if not chances is Dictionary:
			return _failure("registration monster chances must be an object")
		for key in chances:
			var chance: Variant = chances[key]
			if not key is String or str(key).is_empty() or str(key).length() > 40 or not (chance is int or chance is float) or not is_finite(float(chance)) or float(chance) < 0.0 or float(chance) > 100.0:
				return _failure("registration monster chance must be 0-100 for a named creature")
	return {"valid": true, "diagnostics": []}

## `monster_chances` = per-creature chances ({creature: percent}); null keeps
## whatever the weapon already has (the Weapon Lab doesn't edit them).
static func update_weapon(weapon_id: String, published_entry: Dictionary, enabled: bool, weight: float, min_item_level: int, max_item_level: int, path: String = DEFAULT_PATH, table_id: String = TABLE_ID, data_root: String = DEFAULT_DATA_ROOT, monster_chances: Variant = null) -> Dictionary:
	var revision := int(published_entry.get("revision", 0))
	var recipe := _read_recipe(weapon_id, revision, data_root)
	if recipe.is_empty():
		return _failure("published recipe is missing")
	var revision_check := Catalog.validate_revision(published_entry, false)
	if not revision_check.valid:
		return revision_check
	var recipe_check := Catalog.validate_recipe(recipe, published_entry)
	if not recipe_check.valid:
		return recipe_check
	var entry := {"weapon_id": weapon_id, "enabled": enabled, "weight": weight, "min_item_level": min_item_level, "max_item_level": max_item_level, "revision": revision, "recipe_id": str(recipe.get("recipe_id", ""))}
	var document := load_document(path)
	var chances: Variant = monster_chances
	if chances == null:
		chances = document.get("tables", {}).get(table_id, {}).get("weapons", {}).get(weapon_id, {}).get("monster_chances", null)
	if chances is Dictionary:
		var kept := {}
		for key in chances:
			if float(chances[key]) > 0.0:
				kept[str(key)] = float(chances[key])
		if not kept.is_empty():
			entry["monster_chances"] = kept
	var entry_check := validate_entry(entry, weapon_id)
	if not entry_check.valid:
		return entry_check
	if not document.tables.has(table_id):
		document.tables[table_id] = {"weapons": {}}
	document.tables[table_id].weapons[weapon_id] = entry
	document.registration_revision = int(document.get("registration_revision", 0)) + 1
	var document_check := validate_document(document)
	if not document_check.valid or not _write_json(path, document):
		return _failure("could not persist loot registration")
	return {"valid": true, "committed": true, "registration": entry, "document": document, "diagnostics": []}

## The weapons that can drop at `item_level`. A registration drops the
## weapon's *current* published revision: republishing it (Weapon Lab, Dev
## Encyclopedia) doesn't silently take it out of the loot table.
## `overrides` ({weapon_id: registration}) replaces saved registrations; the Dev
## Encyclopedia uses it to try unsaved drop settings in a running level.
static func snapshot_for(table_id: String = TABLE_ID, item_level: int = 1, path: String = DEFAULT_PATH, index_path: String = DEFAULT_INDEX_PATH, overrides: Dictionary = {}) -> Dictionary:
	var document := load_document(path)
	var table: Dictionary = document.get("tables", {}).get(table_id, {})
	var index := _read_json(index_path)
	var data_root := index_path.get_base_dir()
	var registrations: Dictionary = table.get("weapons", {}).duplicate(true)
	for weapon_id in overrides:
		registrations[weapon_id] = overrides[weapon_id]
	var pool: Array[Dictionary] = []
	for weapon_id in registrations.keys():
		var registration: Dictionary = registrations[weapon_id]
		if not bool(registration.get("enabled", false)) or item_level < int(registration.get("min_item_level", 1)) or item_level > int(registration.get("max_item_level", 3)):
			continue
		var published: Dictionary = index.get("weapons", {}).get(weapon_id, {})
		if published.is_empty():
			continue
		var revision := int(published.get("revision", 0))
		var recipe := _read_recipe(weapon_id, revision, data_root)
		if recipe.is_empty():
			continue
		var pooled := {"weapon_id": weapon_id, "revision": revision, "weight": float(registration.get("weight", 1.0)), "min_item_level": int(registration.get("min_item_level", 1)), "max_item_level": int(registration.get("max_item_level", 3)), "recipe": recipe.duplicate(true), "definition": published.duplicate(true)}
		if registration.get("monster_chances") is Dictionary and not registration.monster_chances.is_empty():
			pooled["monster_chances"] = registration.monster_chances.duplicate(true)
		pool.append(pooled)
	pool.sort_custom(func(left: Dictionary, right: Dictionary): return str(left.weapon_id) < str(right.weapon_id))
	return {"schema_version": SCHEMA_VERSION, "table_id": table_id, "registration_revision": int(document.get("registration_revision", 0)), "item_level": item_level, "pool": pool}

static func registration_for(weapon_id: String, path: String = DEFAULT_PATH, table_id: String = TABLE_ID) -> Dictionary:
	var document := load_document(path)
	return document.get("tables", {}).get(table_id, {}).get("weapons", {}).get(weapon_id, {"weapon_id": weapon_id, "enabled": false, "weight": 1.0, "min_item_level": 1, "max_item_level": 3, "revision": 0, "recipe_id": ""}).duplicate(true)

static func _read_recipe(weapon_id: String, revision: int, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	return _read_json(data_root.path_join(weapon_id).path_join(str(revision)).path_join("recipe.json"))

static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return {}
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}

static func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true

static func _valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and is_equal_approx(float(value), floorf(float(value)))

static func _failure(error: String) -> Dictionary:
	return {"valid": false, "error": error, "diagnostics": [{"path": "registration", "code": "INVALID_REGISTRATION", "message": error}]}
