extends SceneTree

const LoaderScript = preload("res://scripts/model/level_data_loader.gd")
const ROOT := "res://data/ld01/fixtures/valid"

func _init() -> void:
	var loader: RefCounted = LoaderScript.new()
	var loaded: bool = loader.load(ROOT)
	if not loaded:
		printerr(loader.get_diagnostics())
	assert(loaded)
	assert(loader.level_ids("act_01").size() == 4)
	var quota: Dictionary = loader.get_level("act_01", "quota")
	assert(quota["encounter"]["scaling"]["hp_multiplier"] == 1.2)
	assert(quota.has("content_hash"))
	var copy: Dictionary = loader.get_level("act_01", "quota")
	copy["encounter"]["scaling"]["hp_multiplier"] = 99.0
	assert(loader.get_level("act_01", "quota")["encounter"]["scaling"]["hp_multiplier"] == 1.2)
	var reordered: Dictionary = loader.get_level("act_01", "quota")
	assert(reordered["content_hash"] == quota["content_hash"])
	assert(not loader.get_level("act_01", "missing").has("id"))
	_assert_invalid("malformed", "{")
	_assert_invalid_level("unknown", func(level: Dictionary): level["unknown"] = true, "unknown field")
	_assert_invalid_level("wrong_type", func(level: Dictionary): level["map"]["position"] = "bad", "map.position")
	_assert_invalid_level("probability", func(level: Dictionary): level["rewards"]["loot"]["ordinary_drop_chance"] = 1.1, "probability")
	_assert_invalid_level("scaling", func(level: Dictionary): level["encounter"]["scaling"]["hp_multiplier"] = 0, "must be > 0")
	_assert_invalid_level("item_level", func(level: Dictionary): level["rewards"]["loot"]["item_level"] = 4, "item level")
	_assert_invalid_level("reward_ids", func(level: Dictionary): level["rewards"]["guaranteed_items"] = [_reward("same"), _reward("same")], "guaranteed reward")
	_assert_invalid_level("bad_reference", func(level: Dictionary): level["requires_completed"] = ["missing"], "unknown level")
	_assert_invalid_level("objective_mode", func(level: Dictionary): level["completion"] = {"objective": "extract", "minimum_completed_surges": 1}, "does not match")
	_assert_invalid_level("cycle", func(level: Dictionary): level["requires_completed"] = ["cycle"], "cycle")
	_assert_invalid_manifest("unsafe_path", "../escape.json", "unsafe path")
	_assert_invalid_act("duplicate_ids", ["level.json", "level2.json"], "duplicate level ID")
	var hash_level: Dictionary = _base_level()
	_write_case("hash_base", hash_level)
	var hash_loader: RefCounted = LoaderScript.new()
	assert(hash_loader.load("user://ld01-tests/hash_base"))
	var hash_a: String = hash_loader.get_level("act_01", "quota")["content_hash"]
	var reordered_level: Dictionary = _base_level()
	var reversed: Dictionary = {}
	var keys: Array = reordered_level.keys()
	keys.reverse()
	for key in keys:
		reversed[key] = reordered_level[key]
	_write_case("hash_reordered", reversed)
	var reordered_loader: RefCounted = LoaderScript.new()
	var reordered_loaded: bool = reordered_loader.load("user://ld01-tests/hash_reordered")
	if not reordered_loaded:
		printerr(reordered_loader.get_diagnostics())
	assert(reordered_loaded)
	assert(reordered_loader.get_level("act_01", "quota")["content_hash"] == hash_a)
	var changed: Dictionary = _base_level()
	changed["encounter"]["scaling"]["hp_multiplier"] = 1.1
	_write_case("hash_changed", changed)
	var changed_loader: RefCounted = LoaderScript.new()
	assert(changed_loader.load("user://ld01-tests/hash_changed"))
	assert(changed_loader.get_level("act_01", "quota")["content_hash"] != hash_a)
	print("LD01 loader checks passed")
	quit(0)

func _assert_invalid_level(name: String, mutate: Callable, expected: String) -> void:
	var level := _base_level()
	mutate.call(level)
	_write_case(name, level)
	var loader: RefCounted = LoaderScript.new()
	assert(not loader.load("user://ld01-tests/%s" % name))
	assert(_diagnostics_contain(loader, expected))

func _assert_invalid(name: String, level_text: String) -> void:
	_prepare_case(name)
	_write_text("user://ld01-tests/%s/index.json" % name, "{\"schema_version\":1,\"act_files\":[\"acts/act.json\"]}")
	_write_text("user://ld01-tests/%s/acts/act.json" % name, "{\"schema_version\":1,\"id\":\"act_01\",\"display_name\":\"Test\",\"layout_revision\":\"a\",\"level_files\":[\"level.json\"],\"completion_requires\":[]}")
	_write_text("user://ld01-tests/%s/level.json" % name, level_text)
	var loader: RefCounted = LoaderScript.new()
	assert(not loader.load("user://ld01-tests/%s" % name))
	assert(_diagnostics_contain(loader, "malformed JSON"))

func _assert_invalid_manifest(name: String, act_path: String, expected: String) -> void:
	_prepare_case(name)
	_write_text("user://ld01-tests/%s/index.json" % name, JSON.stringify({"schema_version": 1, "act_files": [act_path]}))
	var loader: RefCounted = LoaderScript.new()
	assert(not loader.load("user://ld01-tests/%s" % name))
	assert(_diagnostics_contain(loader, expected))

func _assert_invalid_act(name: String, files: Array, expected: String) -> void:
	_prepare_case(name)
	_write_text("user://ld01-tests/%s/index.json" % name, JSON.stringify({"schema_version": 1, "act_files": ["acts/act.json"]}))
	_write_text("user://ld01-tests/%s/acts/act.json" % name, JSON.stringify({"schema_version": 1, "id": "act_01", "display_name": "Test", "layout_revision": "a", "level_files": files, "completion_requires": []}))
	var level := _base_level()
	_write_text("user://ld01-tests/%s/level.json" % name, JSON.stringify(level))
	_write_text("user://ld01-tests/%s/level2.json" % name, JSON.stringify(level))
	var loader: RefCounted = LoaderScript.new()
	assert(not loader.load("user://ld01-tests/%s" % name))
	assert(_diagnostics_contain(loader, expected))

func _write_case(name: String, level: Dictionary) -> void:
	_prepare_case(name)
	_write_text("user://ld01-tests/%s/index.json" % name, JSON.stringify({"schema_version": 1, "act_files": ["acts/act.json"]}))
	_write_text("user://ld01-tests/%s/acts/act.json" % name, JSON.stringify({"schema_version": 1, "id": "act_01", "display_name": "Test", "layout_revision": "a", "level_files": ["level.json"], "completion_requires": []}))
	_write_text("user://ld01-tests/%s/level.json" % name, JSON.stringify(level))

func _prepare_case(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://ld01-tests/%s/acts" % name))

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)

func _diagnostics_contain(loader: RefCounted, text: String) -> bool:
	for diagnostic in loader.get_diagnostics():
		if str(diagnostic).contains(text):
			return true
	return false

func _reward(reward_id: String) -> Dictionary:
	return {"reward_id": reward_id, "trigger": "first_clear", "base_id": "core.cycler", "item_level": 1, "rarity": "common", "quantity": 1}

func _base_level() -> Dictionary:
	return {"schema_version": 1, "content_revision": 1, "id": "quota", "act_id": "act_01", "display_name": "Quota", "type": "monster", "map": {"position": [0.2, 0.3]}, "requires_completed": [], "environment_id": "foundry", "encounter": {"mode": "kill_quota", "available_monsters": ["pursuer"], "scaling": {"hp_multiplier": 1.0, "damage_multiplier": 1.0, "move_speed_multiplier": 1.0, "attack_interval_multiplier": 1.0}, "spawning": {"interval_seconds": 2.0, "max_alive": 4, "pool": [{"monster_id": "pursuer", "weight": 1.0}]}}, "completion": {"objective": "kill_count", "required_kills": 1, "count_monsters": ["pursuer"], "progress_scope": "run"}, "rewards": {"mana_on_success": 1.0, "loot": {"table_id": "foundry_physical_v1", "item_level": 1, "ordinary_drop_chance": 0.0, "boss_drop_chance": 0.0}, "guaranteed_items": []}}