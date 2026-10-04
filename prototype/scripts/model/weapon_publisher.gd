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
    var effect_files: Variant = _stage_effects(revision, stage_assets, final_asset_dir)
    if effect_files == null:
        return _failure("staging.effects", "STAGING_FAILED", "could not stage weapon effect sheets")
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
    for name in effect_files:
        if not _copy_immutable(stage_assets.path_join(name), final_asset_dir_resolved.path_join(name)):
            return _failure("assets.effects", "PUBLISH_FAILED", "could not install weapon effect sheets")
    var revision_dir := data_root.path_join(weapon_id).path_join(str(revision_number))
    if not _mkdir(revision_dir) or not _copy_immutable(stage_data.path_join("definition.json"), revision_dir.path_join("definition.json")) or not _copy_immutable(stage_data.path_join("recipe.json"), revision_dir.path_join("recipe.json")):
        return _failure("revision", "PUBLISH_FAILED", "could not preserve published revision")
    var history := data_root.path_join("history")
    if not _mkdir(history) or not _write_json(history.path_join("index-%s.json" % _sha256(data_root.path_join(INDEX_NAME)).left(12)), index):
        return _failure("history", "PUBLISH_FAILED", "could not preserve the previous publication index")
    if not _write_json(data_root.path_join(INDEX_NAME), next_index):
        return _failure("index", "COMMIT_FAILED", "could not commit publication index")
    return {"valid": true, "committed": true, "idempotent": false, "preview": preview(draft, index), "index": next_index, "diagnostics": []}

## Copies each draft effect's sheet into staging as effects/<n>.png and points
## the revision at its final published path. Returns the staged file names,
## or null if a sheet is missing.
static func _stage_effects(revision: Dictionary, stage_assets: String, final_asset_dir: String) -> Variant:
    var names: Array = []
    # (No early return without effects: the attack clip below still has to be
    # staged. Skipping it left clips with the placeholder sheet, so every
    # weapon without effects looked unpublished right after publishing.)
    var effects: Array = revision.effects if revision.get("effects") is Array else []
    for index in range(effects.size()):
        var effect: Dictionary = revision.effects[index]
        var source := str(effect.get("source", ""))
        if source.is_empty() and str(effect.get("sheet", "")) != Store.PENDING_EFFECT_SHEET:
            source = str(effect.get("sheet", ""))
        var name := "effects/%d.png" % index
        if source.is_empty() or not _copy_immutable(source, stage_assets.path_join(name)):
            return null
        effect.erase("source")
        effect["sheet"] = final_asset_dir.path_join(name)
        names.append(name)
    # The attack clip's packed sheet goes in as clip.png.
    var clip: Variant = revision.get("attack_clip")
    if clip is Dictionary and not clip.is_empty():
        var clip_source := str(clip.get("source", ""))
        if clip_source.is_empty() and str(clip.get("sheet", "")) != Store.PENDING_EFFECT_SHEET:
            clip_source = str(clip.get("sheet", ""))
        if clip_source.is_empty() or not _copy_immutable(clip_source, stage_assets.path_join("clip.png")):
            return null
        clip.erase("source")
        clip.erase("project")
        clip["sheet"] = final_asset_dir.path_join("clip.png")
        names.append("clip.png")
        var hand_source := str(clip.get("hand_source", ""))
        if hand_source.is_empty() and clip.has("hand_sheet") and str(clip.hand_sheet) != Store.PENDING_EFFECT_SHEET:
            hand_source = str(clip.hand_sheet)
        if not hand_source.is_empty():
            if not _copy_immutable(hand_source, stage_assets.path_join("hand.png")):
                return null
            clip.erase("hand_source")
            clip["hand_sheet"] = final_asset_dir.path_join("hand.png")
            names.append("hand.png")
    # Own idle / walk clips go in as idle.png / walk.png (+ idle_hand.png ...).
    var poses: Variant = revision.get("pose_clips")
    if poses is Dictionary:
        for animation in poses:
            var pose: Variant = poses[animation]
            if not pose is Dictionary or pose.is_empty():
                continue
            var pose_source := str(pose.get("source", ""))
            if pose_source.is_empty() and str(pose.get("sheet", "")) != Store.PENDING_EFFECT_SHEET:
                pose_source = str(pose.get("sheet", ""))
            var sheet_name := "%s.png" % str(animation)
            if pose_source.is_empty() or not _copy_immutable(pose_source, stage_assets.path_join(sheet_name)):
                return null
            pose.erase("source")
            pose.erase("project")
            pose["sheet"] = final_asset_dir.path_join(sheet_name)
            names.append(sheet_name)
            var pose_hand := str(pose.get("hand_source", ""))
            if pose_hand.is_empty() and pose.has("hand_sheet") and str(pose.hand_sheet) != Store.PENDING_EFFECT_SHEET:
                pose_hand = str(pose.hand_sheet)
            if not pose_hand.is_empty():
                var hand_name := "%s_hand.png" % str(animation)
                if not _copy_immutable(pose_hand, stage_assets.path_join(hand_name)):
                    return null
                pose.erase("hand_source")
                pose["hand_sheet"] = final_asset_dir.path_join(hand_name)
                names.append(hand_name)
    return names

static func publish_placement_revision(weapon_id: String, pivot: Dictionary, data_root: String = DEFAULT_DATA_ROOT, asset_root: String = DEFAULT_ASSET_ROOT) -> Dictionary:
    return _publish_patched_revision(weapon_id, {"pivot": pivot.duplicate(true)}, "placement", data_root, asset_root)

## Keys the Weapon Encyclopedia may change on a published weapon.
const STATS_PATCH_KEYS := ["base_stats", "base_modifiers", "behavior_id"]

## Publishes the next revision of a published weapon with new numbers
## (Dev Encyclopedia > Weapons). `patch` may hold base_stats, base_modifiers and
## behavior_id; everything else (art, placement, animation, effects) carries
## over from the current revision. Old revisions stay on disk, as always.
static func publish_stats_revision(weapon_id: String, patch: Dictionary, data_root: String = DEFAULT_DATA_ROOT, asset_root: String = DEFAULT_ASSET_ROOT) -> Dictionary:
    var clean := {}
    for key in patch:
        if not STATS_PATCH_KEYS.has(key):
            return _failure("patch.%s" % str(key), "UNSUPPORTED_FIELD", "only stats can change here")
        clean[key] = patch[key].duplicate(true) if (patch[key] is Dictionary or patch[key] is Array) else patch[key]
    if clean.is_empty():
        return _failure("patch", "EMPTY_PATCH", "nothing to change")
    return _publish_patched_revision(weapon_id, clean, "stats", data_root, asset_root)

static func _publish_patched_revision(weapon_id: String, patch: Dictionary, kind: String, data_root: String, asset_root: String) -> Dictionary:
    if weapon_id.is_empty() or weapon_id.contains("/") or weapon_id.contains("\\") or weapon_id.contains("..") or weapon_id.contains(":"):
        return _failure("weapon_id", "UNSAFE_ID", "weapon ID must be a safe catalog name")
    var index := _load_index(data_root)
    var current: Dictionary = index.get("weapons", {}).get(weapon_id, {})
    if current.is_empty():
        return _failure("weapon_id", "UNKNOWN_WEAPON", "published weapon does not exist")
    var current_revision := int(current.get("revision", 0))
    if current_revision < 1:
        return _failure("revision", "INVALID_REVISION", "published weapon revision is invalid")
    var current_data_dir := data_root.path_join(weapon_id).path_join(str(current_revision))
    var recipe := _read_json(current_data_dir.path_join("recipe.json"))
    if recipe.is_empty():
        return _failure("recipe", "MISSING_RECIPE", "current weapon recipe is not preserved")
    var next_revision := current.duplicate(true)
    next_revision["revision"] = current_revision + 1
    for key in patch:
        next_revision[key] = patch[key]
    var revision_validation := Catalog.validate_revision(next_revision, false)
    if not revision_validation.valid:
        return revision_validation
    recipe["revision"] = current_revision + 1
    var base_recipe_id := str(recipe.get("recipe_id", weapon_id))
    if kind != "placement":
        # "sword.common.r3" -> "sword.common.r4" (placement keeps its old naming).
        var suffix := RegEx.create_from_string("\\.r\\d+$")
        base_recipe_id = suffix.sub(base_recipe_id, "")
    recipe["recipe_id"] = "%s.r%d" % [base_recipe_id, current_revision + 1]
    recipe["weapon_id"] = weapon_id
    var recipe_validation := Catalog.validate_recipe(recipe, next_revision)
    if not recipe_validation.valid:
        return recipe_validation

    var transaction_id := "%s-%s-%d" % [weapon_id, kind, Time.get_unix_time_from_system()]
    var staging := data_root.path_join(".staging").path_join(transaction_id)
    var stage_assets := staging.path_join("assets")
    var stage_data := staging.path_join("data")
    if not _mkdir(stage_assets) or not _mkdir(stage_data):
        return _failure("staging", "STAGING_FAILED", "could not create %s staging directory" % kind)
    var current_assets: Dictionary = current.get("assets", {})
    if not _copy_immutable(str(current_assets.get("icon", "")), stage_assets.path_join("icon.png")) or not _copy_immutable(str(current_assets.get("world_sprite", "")), stage_assets.path_join("world-sprite.png")):
        return _failure("staging.assets", "STAGING_FAILED", "could not preserve current published assets")
    var final_asset_dir := asset_root.path_join(weapon_id).path_join(str(current_revision + 1))
    next_revision["assets"] = {"icon": final_asset_dir.path_join("icon.png"), "world_sprite": final_asset_dir.path_join("world-sprite.png")}
    if not _write_json(stage_data.path_join("definition.json"), next_revision) or not _write_json(stage_data.path_join("recipe.json"), recipe):
        return _failure("staging.data", "STAGING_FAILED", "could not stage %s revision" % kind)
    revision_validation = Catalog.validate_revision(next_revision, false)
    if not revision_validation.valid:
        return revision_validation
    recipe_validation = Catalog.validate_recipe(recipe, next_revision)
    if not recipe_validation.valid:
        return recipe_validation
    var next_index := index.duplicate(true)
    next_index.schema_version = SCHEMA_VERSION
    next_index.weapons[weapon_id] = next_revision
    var index_validation := Catalog.validate_publication_index(next_index, false)
    if not index_validation.valid:
        return index_validation
    if not _mkdir(final_asset_dir) or not _copy_immutable(stage_assets.path_join("icon.png"), final_asset_dir.path_join("icon.png")) or not _copy_immutable(stage_assets.path_join("world-sprite.png"), final_asset_dir.path_join("world-sprite.png")):
        return _failure("assets", "PUBLISH_FAILED", "could not install %s assets" % kind)
    var revision_dir := data_root.path_join(weapon_id).path_join(str(current_revision + 1))
    if not _mkdir(revision_dir) or not _copy_immutable(stage_data.path_join("definition.json"), revision_dir.path_join("definition.json")) or not _copy_immutable(stage_data.path_join("recipe.json"), revision_dir.path_join("recipe.json")):
        return _failure("revision", "PUBLISH_FAILED", "could not preserve %s revision" % kind)
    var history := data_root.path_join("history")
    if not _mkdir(history) or not _write_json(history.path_join("index-%s.json" % _sha256(data_root.path_join(INDEX_NAME)).left(12)), index):
        return _failure("history", "PUBLISH_FAILED", "could not preserve the previous publication index")
    if not _write_json(data_root.path_join(INDEX_NAME), next_index):
        return _failure("index", "COMMIT_FAILED", "could not commit %s index" % kind)
    return {"valid": true, "committed": true, "revision": next_revision, "recipe": recipe, "index": next_index, "diagnostics": []}

## Takes a weapon out of the game without deleting anything: its index entry
## moves from "weapons" to "retired". Revision folders and assets stay on disk.
## AccountState still registers retired weapons so saves that own one keep
## loading, but they can't drop or be granted, and tools stop listing them.
static func retire(weapon_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
    var index := _load_index(data_root)
    if not index.get("weapons", {}).has(weapon_id):
        return _failure("weapon_id", "UNKNOWN_WEAPON", "weapon is not in the game")
    var next_index := index.duplicate(true)
    var retired: Dictionary = next_index.get("retired", {})
    retired[weapon_id] = next_index.weapons[weapon_id]
    next_index["retired"] = retired
    next_index.weapons.erase(weapon_id)
    return _commit_index(index, next_index, data_root)

## Puts a retired weapon back in the game at the revision it had.
static func restore_retired(weapon_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
    var index := _load_index(data_root)
    if not index.get("retired", {}).has(weapon_id):
        return _failure("weapon_id", "UNKNOWN_WEAPON", "weapon is not retired")
    if index.get("weapons", {}).has(weapon_id):
        return _failure("weapon_id", "COLLISION", "a weapon with this id is already in the game")
    var next_index := index.duplicate(true)
    next_index.weapons[weapon_id] = next_index.retired[weapon_id]
    next_index.retired.erase(weapon_id)
    if next_index.retired.is_empty():
        next_index.erase("retired")
    return _commit_index(index, next_index, data_root)

static func _commit_index(index: Dictionary, next_index: Dictionary, data_root: String) -> Dictionary:
    var validation := Catalog.validate_publication_index(next_index, false)
    if not validation.valid:
        return validation
    var history := data_root.path_join("history")
    if not _mkdir(history) or not _write_json(history.path_join("index-%s.json" % _sha256(data_root.path_join(INDEX_NAME)).left(12)), index):
        return _failure("history", "PUBLISH_FAILED", "could not preserve the previous publication index")
    if not _write_json(data_root.path_join(INDEX_NAME), next_index):
        return _failure("index", "COMMIT_FAILED", "could not commit publication index")
    return {"valid": true, "committed": true, "index": next_index, "diagnostics": []}

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
    var moved := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK
    # New AccountStates must see what was just written.
    load("res://scripts/model/account_state.gd").clear_published_cache()
    return moved

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
