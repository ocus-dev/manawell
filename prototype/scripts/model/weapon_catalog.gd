class_name WeaponCatalog
extends RefCounted

const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")
const ItemCatalogScript = preload("res://scripts/model/item_catalog.gd")

const SCHEMA_VERSION := 1
const MIN_ITEM_LEVEL := 1
const MAX_ITEM_LEVEL := 99
const MAX_LABEL_LENGTH := 80
const MAX_DESCRIPTION_LENGTH := 2000
const MAX_AFFIXES := 3
const SUPPORTED_BEHAVIOR_IDS := ["weapon.standard", "weapon.fan", "weapon.lance"]
const ASSET_KEYS := ["icon", "world_sprite"]
const IMAGE_COORDINATE_CONVENTION := "pixel origin is top-left; pivot is normalized [0,1] with x right and y down"

static func legacy_catalog() -> Dictionary:
    var result := {}
    for item_id in ItemCatalogScript.ITEMS:
        var item: Dictionary = ItemCatalogScript.ITEMS[item_id]
        if item.get("category", "") != "weapon":
            continue
        var base: Dictionary = ItemDefinitionsScript.PRODUCTION_BASES.get(item_id, {})
        result[item_id] = {
            "id": item_id,
            "label": item.get("label", item_id),
            "description": item.get("description", ""),
            "slot": "weapon",
            "behavior_id": "weapon.standard",
            "implicits": base.get("implicits", []),
            "icon": "res://assets/ui-icons/items/%s.png" % item_id,
        }
    return result

static func has_weapon(weapon_id: String, publication_index: Dictionary = {}) -> bool:
    return legacy_catalog().has(weapon_id) or publication_index.get("weapons", {}).has(weapon_id)

static func lookup(weapon_id: String, publication_index: Dictionary = {}) -> Dictionary:
    if publication_index.get("weapons", {}).has(weapon_id):
        return publication_index.weapons[weapon_id].duplicate(true)
    return legacy_catalog().get(weapon_id, {}).duplicate(true)

static func description_for(weapon_id: String, publication_index: Dictionary = {}) -> String:
    return str(lookup(weapon_id, publication_index).get("description", ""))

static func icon_path_for(weapon_id: String, publication_index: Dictionary = {}) -> String:
    var entry := lookup(weapon_id, publication_index)
    if entry.has("assets"):
        return str(entry.assets.get("icon", ""))
    return str(entry.get("icon", ""))

static func validate_publication_index(index: Dictionary, check_assets: bool = false) -> Dictionary:
    var result := _object_check(index, "publication_index")
    if not result.valid:
        return result
    result = _schema_check(index, "publication_index")
    if not result.valid:
        return result
    if not index.get("weapons", {}) is Dictionary:
        return _failure("publication.weapons", "WEAPONS_OBJECT", "publication index weapons must be an object")
    var seen := {}
    for weapon_id in index.weapons:
        if seen.has(weapon_id):
            return _failure("publication.weapons.%s" % weapon_id, "DUPLICATE_ID", "weapon ID is duplicated")
        seen[weapon_id] = true
        var revision: Variant = index.weapons[weapon_id]
        result = validate_revision(revision, check_assets)
        if not result.valid:
            return result
        if revision.weapon_id != weapon_id:
            return _failure("publication.weapons.%s.weapon_id" % weapon_id, "ID_MISMATCH", "revision weapon_id must match its publication key")
    return _success()

static func validate_publication_entries(entries: Array, check_assets: bool = false) -> Dictionary:
    var seen := {}
    for index in range(entries.size()):
        var revision: Variant = entries[index]
        if not revision is Dictionary:
            return _failure("publication.entries[%d]" % index, "OBJECT_REQUIRED", "publication entry must be an object")
        var weapon_id := str(revision.get("weapon_id", ""))
        if seen.has(weapon_id):
            return _failure("publication.entries[%d].weapon_id" % index, "DUPLICATE_ID", "weapon ID is duplicated: %s" % weapon_id)
        seen[weapon_id] = true
        var result := validate_revision(revision, check_assets)
        if not result.valid:
            return result
    return _success()

static func instance_revision(instance: Dictionary) -> int:
    return int(instance.get("revision", 0))

static func is_legacy_instance(instance: Dictionary) -> bool:
    return not instance.has("revision")

static func validate_draft(draft: Dictionary) -> Dictionary:
    var result := _object_check(draft, "draft")
    if not result.valid:
        return result
    for field in ["schema_version", "draft_id", "weapon_id", "label", "description", "behavior_id", "base_modifiers"]:
        if not draft.has(field):
            return _failure("draft.%s" % field, "MISSING_FIELD", "draft is missing %s" % field)
    result = _schema_check(draft, "draft")
    if not result.valid:
        return result
    result = _string_check(draft.draft_id, "draft.draft_id", "DRAFT_ID")
    if not result.valid:
        return result
    result = _string_check(draft.weapon_id, "draft.weapon_id", "WEAPON_ID")
    if not result.valid:
        return result
    result = _bounded_string(draft.label, "draft.label", MAX_LABEL_LENGTH, "LABEL")
    if not result.valid:
        return result
    result = _bounded_string(draft.description, "draft.description", MAX_DESCRIPTION_LENGTH, "DESCRIPTION")
    if not result.valid:
        return result
    if not SUPPORTED_BEHAVIOR_IDS.has(draft.behavior_id):
        return _failure("draft.behavior_id", "UNSUPPORTED_BEHAVIOR", "behavior ID is not supported")
    if not draft.base_modifiers is Array:
        return _failure("draft.base_modifiers", "MODIFIERS_ARRAY", "base_modifiers must be an array")
    return _validate_modifiers(draft.base_modifiers, "draft.base_modifiers")

static func validate_revision(revision: Variant, check_assets: bool = false) -> Dictionary:
    var result := _object_check(revision, "revision")
    if not result.valid:
        return result
    for field in ["schema_version", "weapon_id", "revision", "label", "description", "behavior_id", "base_modifiers", "assets", "pivot"]:
        if not revision.has(field):
            return _failure("revision.%s" % field, "MISSING_FIELD", "revision is missing %s" % field)
    result = _schema_check(revision, "revision")
    if not result.valid:
        return result
    result = _string_check(revision.weapon_id, "revision.weapon_id", "WEAPON_ID")
    if not result.valid:
        return result
    result = _integer_range(revision.revision, "revision.revision", 1, MAX_ITEM_LEVEL, "REVISION")
    if not result.valid:
        return result
    if not SUPPORTED_BEHAVIOR_IDS.has(revision.behavior_id):
        return _failure("revision.behavior_id", "UNSUPPORTED_BEHAVIOR", "behavior ID is not supported")
    result = _bounded_string(revision.label, "revision.label", MAX_LABEL_LENGTH, "LABEL")
    if not result.valid:
        return result
    result = _bounded_string(revision.description, "revision.description", MAX_DESCRIPTION_LENGTH, "DESCRIPTION")
    if not result.valid:
        return result
    result = _validate_modifiers(revision.base_modifiers, "revision.base_modifiers")
    if not result.valid:
        return result
    result = _validate_assets(revision.assets, "revision.assets", check_assets)
    if not result.valid:
        return result
    return _validate_pivot(revision.pivot)

static func validate_recipe(recipe: Dictionary, revision: Dictionary = {}) -> Dictionary:
    var result := _object_check(recipe, "recipe")
    if not result.valid:
        return result
    for field in ["schema_version", "recipe_id", "weapon_id", "revision", "rarity", "item_level", "explicit_modifiers", "provenance"]:
        if not recipe.has(field):
            return _failure("recipe.%s" % field, "MISSING_FIELD", "recipe is missing %s" % field)
    result = _schema_check(recipe, "recipe")
    if not result.valid:
        return result
    result = _string_check(recipe.recipe_id, "recipe.recipe_id", "RECIPE_ID")
    if not result.valid:
        return result
    result = _integer_range(recipe.revision, "recipe.revision", 1, MAX_ITEM_LEVEL, "REVISION")
    if not result.valid:
        return result
    result = _integer_range(recipe.item_level, "recipe.item_level", MIN_ITEM_LEVEL, MAX_ITEM_LEVEL, "ITEM_LEVEL")
    if not result.valid:
        return result
    if not ItemDefinitionsScript.RARITY_MODIFIER_COUNTS.has(recipe.rarity):
        return _failure("recipe.rarity", "INVALID_RARITY", "rarity is not supported")
    if not recipe.explicit_modifiers is Array:
        return _failure("recipe.explicit_modifiers", "MODIFIERS_ARRAY", "explicit_modifiers must be an array")
    var expected_count: int = ItemDefinitionsScript.RARITY_MODIFIER_COUNTS[recipe.rarity]
    if recipe.explicit_modifiers.size() != expected_count or recipe.explicit_modifiers.size() > MAX_AFFIXES:
        return _failure("recipe.explicit_modifiers", "INVALID_AFFIX_COUNT", "rarity %s requires exactly %d explicit modifiers" % [recipe.rarity, expected_count])
    var families := {}
    for index in range(recipe.explicit_modifiers.size()):
        var modifier: Variant = recipe.explicit_modifiers[index]
        if not modifier is Dictionary:
            return _failure("recipe.explicit_modifiers[%d]" % index, "MODIFIER_OBJECT", "explicit modifier must be an object")
        for field in ["affix_id", "tier", "value"]:
            if not modifier.has(field):
                return _failure("recipe.explicit_modifiers[%d].%s" % [index, field], "MISSING_FIELD", "explicit modifier is missing %s" % field)
        var affix: Dictionary = ItemDefinitionsScript.PRODUCTION_AFFIXES.get(str(modifier.affix_id), {})
        if affix.is_empty():
            return _failure("recipe.explicit_modifiers[%d].affix_id" % index, "UNKNOWN_AFFIX", "affix ID is not supported")
        var tier := int(modifier.tier)
        if not _valid_integer(modifier.tier) or tier < 1 or tier > 3 or tier > int(recipe.item_level):
            return _failure("recipe.explicit_modifiers[%d].tier" % index, "ILLEGAL_TIER_LEVEL", "affix tier must be an integer no greater than item level")
        var range: Dictionary = affix.get("tiers", {}).get(tier, {})
        if range.is_empty() or not _finite_number(modifier.value) or not _value_in_range(float(modifier.value), range):
            return _failure("recipe.explicit_modifiers[%d].value" % index, "INVALID_AFFIX_VALUE", "affix value is outside its authored tier range")
        var family := str(affix.family)
        if families.has(family):
            return _failure("recipe.explicit_modifiers[%d].affix_id" % index, "DUPLICATE_FAMILY", "explicit modifier families cannot repeat")
        families[family] = true
    if not revision.is_empty() and (revision.weapon_id != recipe.weapon_id or int(revision.revision) != int(recipe.revision)):
        return _failure("recipe.revision", "REVISION_MISMATCH", "recipe must reference the selected weapon revision")
    return _success()

static func validate_draft_recipe(draft: Dictionary, revision: Dictionary, recipe: Dictionary, check_assets: bool = false) -> Dictionary:
    var result := validate_draft(draft)
    if not result.valid:
        return result
    result = validate_revision(revision, check_assets)
    if not result.valid:
        return result
    if draft.weapon_id != revision.weapon_id or draft.behavior_id != revision.behavior_id:
        return _failure("revision.weapon_id", "DRAFT_REVISION_MISMATCH", "draft and revision identity or behavior differs")
    return validate_recipe(recipe, revision)

static func _validate_assets(assets: Variant, path: String, check_assets: bool) -> Dictionary:
    if not assets is Dictionary:
        return _failure(path, "ASSETS_OBJECT", "assets must be an object")
    for key in ASSET_KEYS:
        if not assets.has(key):
            return _failure(path + "." + key, "MISSING_ASSET", "asset reference is required")
        var asset_path := str(assets[key])
        if not asset_path.begins_with("res://") or asset_path.contains("..") or asset_path.contains("\\"):
            return _failure(path + "." + key, "PATH_ESCAPE", "asset path must be a repository-local res:// path")
        if check_assets and not ResourceLoader.exists(asset_path):
            return _failure(path + "." + key, "MISSING_ASSET", "asset does not exist: %s" % asset_path)
    return _success()

static func _validate_pivot(pivot: Variant) -> Dictionary:
    if not pivot is Dictionary:
        return _failure("revision.pivot", "PIVOT_OBJECT", "pivot must be an object")
    if pivot.get("coordinate_space", "") != "normalized" or pivot.get("origin", "") != "top_left":
        return _failure("revision.pivot", "PIVOT_CONVENTION", IMAGE_COORDINATE_CONVENTION)
    var coordinates: Variant = pivot.get("grip", null)
    if not coordinates is Array or coordinates.size() != 2 or not _finite_number(coordinates[0]) or not _finite_number(coordinates[1]) or float(coordinates[0]) < 0.0 or float(coordinates[0]) > 1.0 or float(coordinates[1]) < 0.0 or float(coordinates[1]) > 1.0:
        return _failure("revision.pivot.grip", "INVALID_PIVOT", "grip coordinates must be finite normalized values in [0,1]")
    if not ["right", "left"].has(str(pivot.get("facing", ""))):
        return _failure("revision.pivot.facing", "INVALID_FACING", "facing must be right or left")
    return _success()

static func _validate_modifiers(modifiers: Variant, path: String) -> Dictionary:
    if not modifiers is Array or modifiers.size() > MAX_AFFIXES:
        return _failure(path, "MODIFIERS_ARRAY", "modifiers must be an array of at most %d entries" % MAX_AFFIXES)
    var families := {}
    for index in range(modifiers.size()):
        var modifier: Variant = modifiers[index]
        if not modifier is Dictionary:
            return _failure("%s[%d]" % [path, index], "MODIFIER_OBJECT", "modifier must be an object")
        var result := ItemDefinitionsScript._validate_typed_modifier(modifier, families)
        if not result.valid:
            return _failure("%s[%d]" % [path, index], "INVALID_MODIFIER", result.error)
    return _success()

static func _schema_check(value: Dictionary, path: String) -> Dictionary:
    if not _valid_integer(value.get("schema_version", null)) or int(value.schema_version) != SCHEMA_VERSION:
        return _failure(path + ".schema_version", "SCHEMA_VERSION", "schema_version must be %d" % SCHEMA_VERSION)
    return _success()

static func _object_check(value: Variant, path: String) -> Dictionary:
    if not value is Dictionary:
        return _failure(path, "OBJECT_REQUIRED", "%s must be an object" % path)
    return _success()

static func _string_check(value: Variant, path: String, code: String) -> Dictionary:
    if not value is String or str(value).is_empty():
        return _failure(path, code, "value must be a non-empty string")
    return _success()

static func _bounded_string(value: Variant, path: String, limit: int, code: String) -> Dictionary:
    var result := _string_check(value, path, code)
    if not result.valid:
        return result
    if str(value).length() > limit:
        return _failure(path, code + "_TOO_LONG", "value exceeds %d characters" % limit)
    return _success()

static func _integer_range(value: Variant, path: String, minimum: int, maximum: int, code: String) -> Dictionary:
    if not _valid_integer(value) or int(value) < minimum or int(value) > maximum:
        return _failure(path, code, "value must be an integer in [%d,%d]" % [minimum, maximum])
    return _success()

static func _finite_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))

static func _valid_integer(value: Variant) -> bool:
    return _finite_number(value) and float(value) == floor(float(value))

static func _value_in_range(value: float, range: Dictionary) -> bool:
    if not _finite_number(range.get("min", null)) or not _finite_number(range.get("max", null)) or not _finite_number(range.get("step", null)):
        return false
    if value < float(range.min) - 1e-8 or value > float(range.max) + 1e-8:
        return false
    var steps := (value - float(range.min)) / float(range.step)
    return float(range.step) > 0.0 and absf(steps - roundf(steps)) <= 1e-8

static func _success() -> Dictionary:
    return {"valid": true, "diagnostics": []}

static func _failure(path: String, code: String, message: String) -> Dictionary:
    return {"valid": false, "error": message, "diagnostics": [{"path": path, "code": code, "message": message}]}
