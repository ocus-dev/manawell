extends SceneTree

const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const ROOT := "user://weapon_designer_w03"
const DRAFTS := ROOT + "/drafts"
const JOBS := ROOT + "/jobs"

func _init() -> void:
    _cleanup()
    _test_two_draft_round_trips()
    _test_field_diagnostics_block()
    _test_rare_preserves_affixes()
    _test_art_metadata_survives()
    _test_running_job_reopens()
    _cleanup()
    print("PASS weapon_designer_test: drafts, diagnostics, rare affixes, art metadata, and running receipt recovery")
    quit(0)

func _test_two_draft_round_trips() -> void:
    for suffix in ["one", "two"]:
        var draft := Store.default_draft("draft." + suffix)
        draft.weapon_id = "weapon." + suffix
        draft.label = "Weapon " + suffix
        assert(Store.save_draft(draft, DRAFTS).valid)
        var reopened := Store.load_draft(draft.draft_id, DRAFTS)
        assert(reopened.label == draft.label and reopened.weapon_id == draft.weapon_id)
    assert(Store.list_drafts(DRAFTS).size() == 2)

func _test_field_diagnostics_block() -> void:
    var draft := Store.default_draft("draft.invalid")
    draft.behavior_id = "weapon.invalid"
    var result := Store.validate_authored(draft)
    assert(not result.valid and result.diagnostics[0].path == "draft.behavior_id")
    assert(not Store.save_draft(draft, DRAFTS).valid)

func _test_rare_preserves_affixes() -> void:
    var draft := Store.default_draft("draft.rare")
    draft.weapon_id = "weapon.rare"
    draft.rarity = "rare"
    draft.item_level = 2
    draft.explicit_modifiers = [{"affix_id": "affix.payload", "tier": 1, "value": 1}, {"affix_id": "affix.tempo", "tier": 1, "value": 0.03}]
    var before: Array = draft.explicit_modifiers.duplicate(true)
    assert(Store.validate_authored(draft).valid)
    draft.rarity = "common"
    assert(draft.explicit_modifiers == before)
    draft.rarity = "rare"
    assert(Store.validate_authored(draft).valid)

func _test_art_metadata_survives() -> void:
    var draft := Store.default_draft("draft.art")
    draft.weapon_id = "weapon.art"
    draft.art = {"source": "art/source.png", "job_id": "job-art", "icon": "res://prepared/icon.png", "world_sprite": "res://prepared/world.png", "crop": [2, 3, 90, 120], "grip": [0.2, 0.8], "facing": "left", "world_scale": 1.4}
    assert(Store.save_draft(draft, DRAFTS).valid)
    var reopened := Store.load_draft(draft.draft_id, DRAFTS)
    reopened.label = "Edited metadata"
    assert(reopened.art.job_id == "job-art")
    assert(is_equal_approx(float(reopened.art.crop[0]), 2.0) and is_equal_approx(float(reopened.art.crop[3]), 120.0))
    assert(is_equal_approx(float(reopened.art.grip[0]), 0.2) and is_equal_approx(float(reopened.art.grip[1]), 0.8))

func _test_running_job_reopens() -> void:
    var receipt := {"job_id": "job-running", "draft_id": "draft.art", "status": "running", "stage": "prepare", "progress": 0.75, "failure": ""}
    assert(Store.save_job_receipt(receipt, JOBS).valid)
    var reopened := Store.load_job_receipt("job-running", JOBS)
    assert(reopened.status == "running" and reopened.stage == "prepare" and is_equal_approx(float(reopened.progress), 0.75))

func _cleanup() -> void:
    _remove_tree(ProjectSettings.globalize_path(ROOT))

func _remove_tree(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null:
        return
    directory.list_dir_begin()
    var name := directory.get_next()
    while not name.is_empty():
        var child := path.path_join(name)
        if directory.current_is_dir():
            _remove_tree(child)
        else:
            DirAccess.remove_absolute(child)
        name = directory.get_next()
    directory.list_dir_end()
    DirAccess.remove_absolute(path)