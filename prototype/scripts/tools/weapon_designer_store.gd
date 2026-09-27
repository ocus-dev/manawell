class_name WeaponDesignerStore
extends RefCounted

const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const WeaponEffectsScript = preload("res://scripts/model/weapon_effects.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")
## Stand-in sheet path for draft effects; publishing copies the real file in.
const PENDING_EFFECT_SHEET := "res://assets/weapons/effect-pending.png"
const DATA_ROOT := "res://data/designer"
const DRAFT_ROOT := DATA_ROOT + "/drafts"
const JOB_ROOT := DATA_ROOT + "/jobs"
const MAX_ID_LENGTH := 80

static func default_draft(draft_id: String = "draft.new_weapon") -> Dictionary:
    return {"schema_version": 1, "draft_id": draft_id, "weapon_id": draft_id.trim_prefix("draft.") if draft_id.begins_with("draft.") else draft_id, "label": "New weapon", "description": "Draft weapon description.", "behavior_id": Catalog.SUPPORTED_BEHAVIOR_IDS[0], "base_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "designer.base.attack_damage", "value": 0}], "rarity": "common", "item_level": 1, "explicit_modifiers": [], "art": {"source": "", "job_id": "", "icon": "", "world_sprite": "", "crop": [0, 0, 0, 0], "grip": [0.5, 0.75], "facing": "right", "world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}}

static func validate_authored(draft: Dictionary) -> Dictionary:
    var result := Catalog.validate_draft(draft)
    if not result.valid:
        return result
    var revision := revision_for(draft)
    result = Catalog.validate_revision(revision)
    if not result.valid:
        return result
    return Catalog.validate_draft_recipe(draft, revision, recipe_for(draft))

static func revision_for(draft: Dictionary) -> Dictionary:
    var art: Dictionary = draft.get("art", {})
    var revision := {"schema_version": 1, "weapon_id": str(draft.get("weapon_id", "")), "revision": revision_number(draft), "label": str(draft.get("label", "")), "description": str(draft.get("description", "")), "behavior_id": str(draft.get("behavior_id", "")), "base_modifiers": draft.get("base_modifiers", []).duplicate(true), "assets": {"icon": _asset_path(art.get("icon", "")), "world_sprite": _asset_path(art.get("world_sprite", ""))}, "pivot": {"coordinate_space": "normalized", "origin": "top_left", "grip": art.get("grip", [0.5, 0.75]), "facing": str(art.get("facing", "right")), "world_scale": float(art.get("world_scale", 1.0)), "rotation_degrees": float(art.get("rotation_degrees", 0.0)), "hand_offset": art.get("hand_offset", [0.0, 0.0])}}
    if draft.get("effects") is Array and not draft.effects.is_empty():
        revision["effects"] = []
        for effect in draft.effects:
            var entry: Dictionary = WeaponEffectsScript.normalize(effect)
            var sheet := str(entry.get("sheet", ""))
            if not sheet.begins_with("res://") or not str(entry.get("source", "")).is_empty():
                entry["sheet"] = sheet if sheet.begins_with("res://") and str(entry.get("source", "")).is_empty() else PENDING_EFFECT_SHEET
            revision.effects.append(entry)
    if draft.get("attack_clip") is Dictionary and not draft.attack_clip.is_empty():
        var clip: Dictionary = WeaponClipScript.normalize(draft.attack_clip)
        clip.erase("project")
        if not str(clip.get("source", "")).is_empty() or not str(clip.get("sheet", "")).begins_with("res://"):
            clip["sheet"] = PENDING_EFFECT_SHEET
        revision["attack_clip"] = clip
    if draft.get("swing") is Dictionary and not draft.swing.is_empty():
        revision["swing"] = draft.swing.duplicate(true)
    if draft.get("base_stats") is Dictionary:
        revision["base_stats"] = {}
        for key in draft.base_stats:
            revision.base_stats[key] = float(draft.base_stats[key])
    return revision

static func recipe_for(draft: Dictionary) -> Dictionary:
    var revision := revision_number(draft)
    var recipe_id := "%s.%s" % [str(draft.get("weapon_id", "")), str(draft.get("rarity", "common"))]
    if revision > 1:
        recipe_id += ".r%d" % revision
    return {"schema_version": 1, "recipe_id": recipe_id, "weapon_id": str(draft.get("weapon_id", "")), "revision": revision, "rarity": str(draft.get("rarity", "common")), "item_level": int(draft.get("item_level", 1)), "explicit_modifiers": draft.get("explicit_modifiers", []).duplicate(true), "provenance": {"kind": "designer", "source_id": str(draft.get("draft_id", "")), "run_id": ""}}

## Drafts publish as revision 1 unless they carry "revision" (the Weapon Lab
## sets it to the next revision when updating a published weapon).
static func revision_number(draft: Dictionary) -> int:
    var value = draft.get("revision", 1)
    return maxi(1, int(value)) if (value is int or value is float) else 1

static func save_draft(draft: Dictionary, root: String = DRAFT_ROOT) -> Dictionary:
    var result := Catalog.validate_draft(draft)
    if not result.valid:
        return result
    var path := _safe_json_path(root, str(draft.draft_id))
    if path.is_empty():
        return _failure("draft.draft_id", "UNSAFE_ID", "draft ID must be a single safe repository-local name")
    if not _write_json(path, draft):
        return _failure("draft", "WRITE_FAILED", "could not save designer draft")
    return {"valid": true, "path": path, "diagnostics": []}

static func load_draft(draft_id: String, root: String = DRAFT_ROOT) -> Dictionary:
    var path := _safe_json_path(root, draft_id)
    if path.is_empty():
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var value = JSON.parse_string(file.get_as_text())
    file.close()
    return value if value is Dictionary else {}

static func list_drafts(root: String = DRAFT_ROOT) -> Array:
    return _list_json(root)

static func save_job_receipt(receipt: Dictionary, root: String = JOB_ROOT) -> Dictionary:
    var path := _safe_json_path(root, str(receipt.get("job_id", "")))
    if path.is_empty():
        return _failure("job_id", "UNSAFE_ID", "job ID must be a single safe repository-local name")
    if not _write_json(path, receipt):
        return _failure("job_id", "WRITE_FAILED", "could not save running job receipt")
    return {"valid": true, "path": path, "diagnostics": []}

static func load_job_receipt(job_id: String, root: String = JOB_ROOT) -> Dictionary:
    var path := _safe_json_path(root, job_id)
    if path.is_empty():
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var value = JSON.parse_string(file.get_as_text())
    file.close()
    return value if value is Dictionary else {}

static func list_job_receipts(root: String = JOB_ROOT) -> Array:
    return _list_json(root)

static func _asset_path(value: Variant) -> String:
    var path := str(value)
    return path if path.begins_with("res://") and not path.contains("..") and not path.contains("\\") else "res://assets/ui-icons/items/core.heavy_breech.png"

static func _safe_json_path(root: String, identifier: String) -> String:
    if identifier.is_empty() or identifier.length() > MAX_ID_LENGTH or identifier.contains("/") or identifier.contains("\\") or identifier.contains("..") or identifier.contains(":"):
        return ""
    return "%s/%s.json" % [root.trim_suffix("/"), identifier]

static func _write_json(path: String, value: Dictionary) -> bool:
    var directory := path.get_base_dir()
    var absolute_directory := ProjectSettings.globalize_path(directory)
    if not DirAccess.dir_exists_absolute(absolute_directory) and DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
        return false
    var temporary := path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value, "  ") + "\n")
    file.close()
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func _list_json(root: String) -> Array:
    var result: Array = []
    var directory := DirAccess.open(root)
    if directory == null:
        return result
    directory.list_dir_begin()
    var name := directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and name.ends_with(".json"):
            result.append(name.trim_suffix(".json"))
        name = directory.get_next()
    directory.list_dir_end()
    result.sort()
    return result

static func _failure(path: String, code: String, message: String) -> Dictionary:
    return {"valid": false, "error": message, "diagnostics": [{"path": path, "code": code, "message": message}]}
