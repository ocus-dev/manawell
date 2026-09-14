extends SceneTree

const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const ROOT := "res://data/weapons_w04_test"
const ASSETS := "res://assets/weapons_w04_test"
const PREP := "res://data/weapons_w04_preparation"

func _init() -> void:
    _cleanup()
    _mkdir(PREP + "/job-a")
    var source := "res://assets/ui-icons/items/core.heavy_breech.png"
    _copy(source, PREP + "/job-a/square-icon.png")
    _copy(source, PREP + "/job-a/world-sprite.png")
    var manifest := {"status": "complete", "outputs": {"square-icon.png": FileAccess.get_sha256(ProjectSettings.globalize_path(PREP + "/job-a/square-icon.png")), "world-sprite.png": FileAccess.get_sha256(ProjectSettings.globalize_path(PREP + "/job-a/world-sprite.png"))}}
    _write(PREP + "/job-a/manifest.json", manifest)
    var draft := Store.default_draft("draft.w04")
    draft.weapon_id = "weapon.w04"
    draft.art.job_id = "job-a"
    var corrupt_file := FileAccess.open(PREP + "/job-a/world-sprite.png", FileAccess.WRITE)
    corrupt_file.store_8(0)
    corrupt_file.close()
    var corrupt := Publisher.publish(draft, PREP, "job-a", ROOT, ASSETS)
    assert(not corrupt.valid and corrupt.diagnostics[0].code == "CORRUPT_ASSET")
    _copy(source, PREP + "/job-a/world-sprite.png")
    var first := Publisher.publish(draft, PREP, "job-a", ROOT, ASSETS)
    assert(first.valid and first.committed)
    var index := _read(ROOT + "/index.json")
    assert(index.weapons.has("weapon.w04"))
    assert(Catalog.lookup("weapon.w04", index).description == draft.description)
    assert(FileAccess.file_exists(index.weapons["weapon.w04"].assets.icon) and FileAccess.file_exists(index.weapons["weapon.w04"].assets.world_sprite))
    var repeated := Publisher.publish(draft, PREP, "job-a", ROOT, ASSETS)
    assert(repeated.get("idempotent", false))
    var interrupted := Publisher.publish(Store.default_draft("draft.interrupted"), PREP, "job-a", ROOT + "2", ASSETS + "2", true)
    assert(interrupted.valid and not FileAccess.file_exists(ROOT + "2/index.json"))
    var missing := Store.default_draft("draft.missing")
    missing.weapon_id = "weapon.missing"
    var missing_result := Publisher.publish(missing, PREP, "unknown", ROOT, ASSETS)
    assert(not missing_result.valid)
    _mkdir(PREP + "/job-missing")
    _write(PREP + "/job-missing/manifest.json", {"status": "complete", "outputs": {"square-icon.png": "missing", "world-sprite.png": "missing"}})
    missing.art.job_id = "job-missing"
    missing_result = Publisher.publish(missing, PREP, "job-missing", ROOT, ASSETS)
    assert(not missing_result.valid and missing_result.diagnostics[0].code == "MISSING_ASSET")
    var collision := Store.default_draft("draft.collision")
    collision.weapon_id = "weapon.w04"
    collision.description = "edited without a revision"
    var collision_result := Publisher.publish(collision, PREP, "job-a", ROOT, ASSETS)
    assert(not collision_result.valid and collision_result.diagnostics[0].code == "COLLISION")
    assert(Publisher.rollback("weapon.w04", 1, ROOT).valid)
    assert(_read(ROOT + "/weapon.w04/1/definition.json").weapon_id == "weapon.w04")
    _cleanup()
    print("PASS weapon_publisher_test: publication, discoverability, idempotence, staging interruption, collision, rollback, and revision retention")
    quit(0)

func _mkdir(path: String) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _copy(source: String, destination: String) -> void:
    _mkdir(destination.get_base_dir())
    var file := FileAccess.open(destination, FileAccess.WRITE)
    file.store_buffer(FileAccess.get_file_as_bytes(source))
    file.close()

func _write(path: String, value: Dictionary) -> void:
    _mkdir(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.close()

func _read(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    var value = JSON.parse_string(file.get_as_text())
    file.close()
    return value

func _cleanup() -> void:
    for path in [ROOT, ASSETS, PREP, ROOT + "2", ASSETS + "2"]:
        _remove_tree(ProjectSettings.globalize_path(path))

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