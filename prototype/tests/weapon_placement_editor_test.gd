extends SceneTree

const PlacementEditorScript = preload("res://scripts/tools/weapon_placement_editor.gd")
const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const DATA_ROOT := "res://data/weapons_placement_test"
const ASSET_ROOT := "res://assets/weapons_placement_test"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	_test_live_transform_preview()
	_test_revision_publication()
	_cleanup()
	print("PASS weapon placement editor: live transform, drag offset, bounded bounds, grip alignment, immutable revision, recipe consistency, and invalid rejection")
	quit(0)

func _test_live_transform_preview() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var revision := {"assets": {"world_sprite": "res://assets/weapons/batton of beating/1/world-sprite.png"}, "pivot": {"grip": [0.5, 0.75], "facing": "right", "world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}}
	var editor: Control = PlacementEditorScript.new()
	root.add_child(editor)
	editor.configure(controller, "batton of beating", revision)
	assert(controller.hero.held_weapon.texture != null)
	assert(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position) < 0.01)
	var original_grip: Vector2 = controller.hero.held_weapon_grip
	var target_center: Vector2 = controller.hero.weapon_socket.to_global(controller.hero.held_weapon_base_position() + Vector2(18.0, -24.0))
	assert(editor.set_hand_offset_from_world_point(target_center), "drag target must update hand offset")
	assert(controller.hero.held_weapon_grip == original_grip, "dragging must preserve internal grip")
	assert(is_equal_approx(float(editor.current_pivot().hand_offset[0]), 18.0))
	assert(is_equal_approx(float(editor.current_pivot().hand_offset[1]), -24.0))
	assert(controller.hero.held_weapon.to_global(Vector2.ZERO).distance_to(target_center) < 0.01, "weapon center must follow drag target")
	assert(controller.hero.hero_world_rect().size.y > 0.0, "hero bounds must be visible to placement guide")
	var persisted_revision: Dictionary = revision.duplicate(true)
	persisted_revision.pivot = editor.current_pivot()
	controller._configure_held_weapon_visual(persisted_revision)
	assert(controller.hero.held_weapon_hand_offset == Vector2(18.0, -24.0), "runtime load must preserve persisted hand offset")
	assert(controller.hero.held_weapon.to_global(Vector2.ZERO).distance_to(target_center) < 0.01, "runtime load must preserve weapon placement")
	assert(maxf(controller.hero.held_weapon_world_rect().size.x, controller.hero.held_weapon_world_rect().size.y) <= 96.01 * controller.hero.display_scale())
	editor.grip_x.value = 0.2
	editor.grip_y.value = 0.4
	editor.world_scale.value = 1.5
	editor.weapon_rotation.value = 22.0
	editor.facing.select(1)
	editor.facing.item_selected.emit(1)
	assert(is_equal_approx(controller.hero.held_weapon_grip.x, 0.2))
	assert(is_equal_approx(controller.hero.held_weapon_grip.y, 0.4))
	assert(is_equal_approx(controller.hero.held_weapon_scale, 1.5))
	assert(is_equal_approx(controller.hero.held_weapon_rotation_degrees, 22.0))
	assert(controller.hero.held_weapon_facing == "left")
	assert(is_equal_approx(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position), Vector2(18.0, -24.0).length() * controller.hero.display_scale()))
	var chosen_point: Vector2 = controller.hero.weapon_socket.to_global(controller.hero.held_weapon.position)
	assert(editor.set_grip_from_world_point(chosen_point), "weapon click must select a grip point")
	assert(is_equal_approx(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position), Vector2(18.0, -24.0).length() * controller.hero.display_scale()))
	editor.queue_free()
	controller.queue_free()
	await process_frame

func _test_revision_publication() -> void:
	var weapon_id := "placement.test"
	var icon_source := "res://assets/weapons/light blade/1/icon.png"
	var world_source := "res://assets/weapons/light blade/1/world-sprite.png"
	var revision := {"schema_version": 1, "weapon_id": weapon_id, "revision": 1, "label": "Placement Test", "description": "Placement test weapon", "behavior_id": "weapon.melee", "base_modifiers": [], "assets": {"icon": ASSET_ROOT + "/" + weapon_id + "/1/icon.png", "world_sprite": ASSET_ROOT + "/" + weapon_id + "/1/world-sprite.png"}, "pivot": {"coordinate_space": "normalized", "origin": "top_left", "grip": [0.5, 0.75], "facing": "right", "world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}}
	var recipe := {"schema_version": 1, "recipe_id": weapon_id + ".common", "weapon_id": weapon_id, "revision": 1, "rarity": "common", "item_level": 1, "explicit_modifiers": [], "provenance": {"kind": "designer", "source_id": "placement-test", "run_id": ""}}
	assert(Catalog.validate_revision(revision, false).valid)
	assert(Catalog.validate_recipe(recipe, revision).valid)
	_copy(icon_source, revision.assets.icon)
	_copy(world_source, revision.assets.world_sprite)
	_write(DATA_ROOT + "/index.json", {"schema_version": 1, "weapons": {weapon_id: revision}})
	_write(DATA_ROOT + "/" + weapon_id + "/1/recipe.json", recipe)
	_write(DATA_ROOT + "/" + weapon_id + "/1/definition.json", revision)
	var invalid := Publisher.publish_placement_revision(weapon_id, {"coordinate_space": "normalized", "origin": "top_left", "grip": [-0.2, 0.75], "facing": "right", "world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}, DATA_ROOT, ASSET_ROOT)
	assert(not invalid.get("valid", false), "invalid placement must be rejected")
	assert(int(_read(DATA_ROOT + "/index.json").weapons[weapon_id].revision) == 1)
	var saved := Publisher.publish_placement_revision(weapon_id, {"coordinate_space": "normalized", "origin": "top_left", "grip": [0.2, 0.4], "facing": "left", "world_scale": 1.5, "rotation_degrees": 22.0, "hand_offset": [18.0, -24.0]}, DATA_ROOT, ASSET_ROOT)
	assert(saved.get("valid", false) and saved.get("committed", false))
	assert(int(saved.revision.revision) == 2)
	assert(saved.revision.pivot.hand_offset == [18.0, -24.0])
	assert(int(_read(DATA_ROOT + "/index.json").weapons[weapon_id].revision) == 2)
	assert(int(_read(DATA_ROOT + "/" + weapon_id + "/1/definition.json").revision) == 1, "old definition must be retained")
	var new_recipe := _read(DATA_ROOT + "/" + weapon_id + "/2/recipe.json")
	assert(int(new_recipe.revision) == 2 and str(new_recipe.weapon_id) == weapon_id)
	assert(str(new_recipe.recipe_id).ends_with(".r2"), "new revision gets a distinct recipe identity")
	assert(int(_read(DATA_ROOT + "/" + weapon_id + "/2/definition.json").revision) == int(new_recipe.revision))

func _copy(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(source))
	file.close()

func _write(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value

func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(DATA_ROOT))
	_remove_tree(ProjectSettings.globalize_path(ASSET_ROOT))

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
