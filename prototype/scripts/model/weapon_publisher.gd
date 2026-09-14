class_name WeaponPublisher
extends RefCounted

const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")

const SCHEMA_VERSION := 1
const DEFAULT_DATA_ROOT := "res://data/weapons"
const DEFAULT_ASSET_ROOT := "res://assets/weapons"
const INDEX_NAME := "index.json"

static func preview(draft: Dictionary, index: Dictionary = {}) -> Dictionary:
    var weapon_id := str(draft.get("weapon_id", ""))
    var current: Dictionary = index.get("weapons", {}).get(weapon_id, {})
    if current.is_empty():
        return {"valid": true, "added_ids": [weapon_id], "changed_ids": [], "unchanged_ids": [], "diagnostics": []}
    var revision := Store.revision_for(draft)
    var changed := JSON.stringify(current, "", true) != JSON.stringify(revision, "", true)
    return {"valid": true, "added_ids": [], "changed_ids": [weapon_id] if changed else [], "unchanged_ids": [] if changed else [weapon_id], "diagnostics": []}

static func publish(draft: Dictionary, preparation_root: String, job_id: String, data_root: String = DEFAULT_DATA_ROOT, asset_root: String = DEFAULT_ASSET_ROOT, interrupt_after_stage: bool = false) -> Dictionary:
    var authored := Store.validate_authored(draft)
    if not authored.valid:
        return authored
    if job_id.is_empty() or job_id.contains("/") or job_id.contains("\\") or job_id.contains(".."):
        return _failure("job_id", "UNSAFE_JOB_ID", "preparation job ID is not a safe name")
    var source_dir := preparation_root.path_join(job_id)
    var manifest := _read_json(source_dir.path_join("manifest.json"))
    if manifest.is_empty() or manifest.get("status", "") != "complete":
        return _failure("preparation.manifest", "JOB_INCOMPLETE", "preparation job must be complete before publication")
    var prepared := _verify_prepared(source_dir, manifest)
    if not prepared.valid:
        return prepared

    var revision := Store.revision_for(draft)
    var recipe := Store.recipe_for(draft)
    var weapon_id := str(revision.weapon_id)
    var revision_number := int(revision.revision)
    var final_asset_dir := asset_root.path_join(weapon_id).path_join(str(revision_number))
    revision.assets = {"icon": final_asset_dir.path_join("icon.png"), "world_sprite": final_asset_dir.path_join("world-sprite.png")}
    revision["source_hashes"] = {"job_id": job_id, "manifest_sha256": _sha256(source_dir.path_join("manifest.json")), "icon_sha256": prepared.icon_sha256, "world_sprite_sha256": prepared.world_sha256}
    var validation := Catalog.validate_draft_recipe(draft, revision, recipe, false)
    if not validation.valid:
        return validation

    var index := _load_index(data_root)
    var current: Dictionary = index.get("weapons", {}).get(weapon_id, {})
    if not current.is_empty():
        if int(current.get("revision", 0)) == revision_number:
            if _values_equal(current, revision) and _published_assets_match(revision):
                return {"valid": true, "committed": false, "idempotent": true, "preview": preview(draft, index), "index": index, "diagnostics": []}
            return _failure("weapon_id", "COLLISION", "published weapon revision already exists with different content")
        if revision_number <= int(current.get("revision", 0)):
            return _failure("revision.revision", "REVISION_COLLISION", "a published revision cannot replace the current revision")

    var transaction_id := "%s-%s" % [weapon_id, str(Time.get_unix_time_from_system())]
    var staging := data_root.path_join(".staging").path_join(transaction_id)
    var stage_assets := staging.path_join("assets")
    var stage_data := staging.path_join("data")
    if not _mkdir(stage_assets) or not _mkdir(stage_data):
        return _failure("staging", "STAGING_FAILED", "could not create publication staging directory")
    if not _copy_immutable(source_dir.path_join("square-icon.png"), stage_assets.path_join("icon.png")) or not _copy_immutable(source_dir.path_join("world-sprite.png"), stage_assets.path_join("world-sprite.png")):
        return _failure("staging.assets", "STAGING_FAILED", "could not stage prepared assets")
    revision.assets = {"icon": final_asset_dir.path_join("icon.png"), "world_sprite": final_asset_dir.path_join("world-sprite.png")}
    if not _write_json(stage_data.path_join("definition.json"), revision) or not _write_json(stage_data.path_join("recipe.json"), recipe):
        return _failure("staging.data", "STAGING_FAILED", "could not stage definition and recipe")
    var staged_validation := Catalog.validate_draft_recipe(draft, revision, recipe, false)
    if not staged_validation.valid:
        return staged_validation
    if interrupt_after_stage:
        return {"valid": true, "committed": false, "interrupted": true, "staging": staging, "preview": preview(draft, index), "diagnostics": []}

    var next_index := index.duplicate(true)
    next_index.schema_version = SCHEMA_VERSION
    next_index.weapons[weapon_id] = revision
    var index_validation := Catalog.validate_publication_index(next_index, false)
    if not index_validation.valid:
        return index_validation
    var final_asset_dir_resolved := asset_root.path_join(weapon_id).path_join(str(revision_number))
    if not _mkdir(final_asset_dir_resolved) or not _copy_immutable(stage_assets.path_join("icon.png"), final_asset_dir_resolved.path_join("icon.png")) or not _copy_immutable(stage_assets.path_join("world-sprite.png"), final_asset_dir_resolved.path_join("world-sprite.png")):
        return _failure("assets", "PUBLISH_FAILED", "could not install immutable published assets")
    var revision_dir := data_root.path_join(weapon_id).path_join(str(revision_number))
    if not _mkdir(revision_dir) or not _copy_immutable(stage_data.path_join("definition.json"), revision_dir.path_join("definition.json")) or not _copy_immutable(stage_data.path_join("recipe.json"), revision_dir.path_join("recipe.json")):
        return _failure("revision", "PUBLISH_FAILED", "could not preserve published revision")
    var history := data_root.path_join("history")
    if not _mkdir(history) or not _write_json(history.path_join("index-%s.json" % _sha256(data_root.path_join(INDEX_NAME)).left(12)), index):
        return _failure("history", "PUBLISH_FAILED", "could not preserve the previous publication index")
    if not _write_json(data_root.path_join(INDEX_NAME), next_index):
        return _failure("index", "COMMIT_FAILED", "could not commit publication index")
    return {"valid": true, "committed": true, "idempotent": false, "preview": preview(draft, index), "index": next_index, "diagnostics": []}

static func rollback(weapon_id: String, revision: int, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
    var definition_path := data_root.path_join(weapon_id).path_join(str(revision)).path_join("definition.json")
    var definition := _read_json(definition_path)
    if definition.is_empty():
        return _failure("revision", "UNKNOWN_REVISION", "published revision is not preserved")
    var validation := Catalog.validate_revision(definition, false)
    if not validation.valid:
        return validation
    var index := _load_index(data_root)
    index.weapons[weapon_id] = definition
    validation = Catalog.validate_publication_index(index, false)
    if not validation.valid:
        return validation
    if not _write_json(data_root.path_join(INDEX_NAME), index):
        return _failure("index", "COMMIT_FAILED", "could not roll back publication index")
    return {"valid": true, "rolled_back": true, "index": index, "diagnostics": []}

static func _verify_prepared(directory: String, manifest: Dictionary) -> Dictionary:
    for name in ["square-icon.png", "world-sprite.png"]:
        var expected := str(manifest.get("outputs", {}).get(name, ""))
        var path := directory.path_join(name)
        if expected.is_empty() or not FileAccess.file_exists(path):
            return _failure("preparation.%s" % name, "MISSING_ASSET", "prepared output is missing")
        if _sha256(path) != expected:
            return _failure("preparation.%s" % name, "CORRUPT_ASSET", "prepared output hash does not match manifest")
    return {"valid": true, "icon_sha256": _sha256(directory.path_join("square-icon.png")), "world_sha256": _sha256(directory.path_join("world-sprite.png")), "diagnostics": []}

static func _published_assets_match(revision: Dictionary) -> bool:
    return _published_asset_exists(str(revision.assets.icon)) and _published_asset_exists(str(revision.assets.world_sprite))

static func _published_asset_exists(path: String) -> bool:
    return FileAccess.file_exists(path) and (not path.begins_with("res://") or ResourceLoader.exists(path) or FileAccess.file_exists(path))

static func _values_equal(left: Variant, right: Variant) -> bool:
    if (left is int or left is float) and (right is int or right is float):
        return is_equal_approx(float(left), float(right))
    if left is Dictionary and right is Dictionary:
        if left.size() != right.size():
            return false
        for key in left:
            if not right.has(key) or not _values_equal(left[key], right[key]):
                return false
        return true
    if left is Array and right is Array:
        if left.size() != right.size():
            return false
        for index in range(left.size()):
            if not _values_equal(left[index], right[index]):
                return false
        return true
    return left == right

static func _load_index(data_root: String) -> Dictionary:
    var index := _read_json(data_root.path_join(INDEX_NAME))
    if index.is_empty():
        return {"schema_version": SCHEMA_VERSION, "weapons": {}}
    return index

static func _read_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var value = JSON.parse_string(file.get_as_text())
    file.close()
    return value if value is Dictionary else {}

static func _write_json(path: String, value: Dictionary) -> bool:
    if not _mkdir(path.get_base_dir()):
        return false
    var temporary := path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value, "  ") + "\n")
    file.close()
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func _copy_immutable(source: String, destination: String) -> bool:
    if not FileAccess.file_exists(source):
        return false
    if FileAccess.file_exists(destination):
        return _sha256(source) == _sha256(destination)
    if not _mkdir(destination.get_base_dir()):
        return false
    var bytes := FileAccess.get_file_as_bytes(source)
    var file := FileAccess.open(destination, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(bytes)
    file.close()
    return true

static func _mkdir(path: String) -> bool:
    var absolute := ProjectSettings.globalize_path(path)
    return DirAccess.dir_exists_absolute(absolute) or DirAccess.make_dir_recursive_absolute(absolute) == OK

static func _sha256(path: String) -> String:
    return FileAccess.get_sha256(ProjectSettings.globalize_path(path))

static func _failure(path: String, code: String, message: String) -> Dictionary:
    return {"valid": false, "error": message, "diagnostics": [{"path": path, "code": code, "message": message}]}