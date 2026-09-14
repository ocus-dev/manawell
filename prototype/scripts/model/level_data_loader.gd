class_name LevelDataLoader
extends RefCounted

const MAX_ACTS := 64
const MAX_LEVELS_PER_ACT := 256
const MAX_PREREQUISITES := 32
const MAX_WAVES := 128
const MAX_SPAWNS_PER_WAVE := 64
const MAX_POOL_ENTRIES := 64
const MAX_GUARANTEED_ITEMS := 32
const MAX_COUNT := 100000
const MAX_STRING_LENGTH := 256
const SUPPORTED_ITEM_LEVELS := [1, 2, 3]
const MONSTER_IDS := ["pursuer", "breaker", "ranged", "boss"]
const ENVIRONMENT_IDS := ["foundry"]
const LOOT_TABLE_IDS := ["foundry_physical_v1"]
const SCHEDULE_IDS := ["foundry_surges_v1"]
const BASE_ITEM_IDS := ["core.heavy_breech", "module.high_volume", "chassis.bulwark", "core.cycler", "module.fast_cycle", "chassis.runner", "core.accelerator", "module.bracing", "chassis.jump_servos"]

var _acts: Dictionary = {}
var _levels: Dictionary = {}
var _act_order: Array = []
var diagnostics: Array = []

func load(root_path: String) -> bool:
	diagnostics.clear()
	_acts.clear()
	_levels.clear()
	_act_order.clear()
	var manifest_path := root_path.path_join("index.json")
	var manifest_result := _read_json(manifest_path)
	if not manifest_result["valid"]:
		_add_error(manifest_result["error"])
		return false
	var manifest: Dictionary = manifest_result["value"]
	if not _check_object(manifest, ["schema_version", "act_files"], [], manifest_path):
		return false
	if manifest["schema_version"] != 1 or not manifest["act_files"] is Array:
		_add_error("%s: schema_version must be 1 and act_files must be an array" % manifest_path)
		return false
	if manifest["act_files"].is_empty() or manifest["act_files"].size() > MAX_ACTS:
		_add_error("%s: act_files count must be 1..%d" % [manifest_path, MAX_ACTS])
		return false
	for relative_path in manifest["act_files"]:
		if not relative_path is String or not _safe_relative_path(relative_path):
			_add_error("%s: act_files contains an unsafe path" % manifest_path)
			return false
		var act_path := root_path.path_join(relative_path)
		var act_result := _read_json(act_path)
		if not act_result["valid"]:
			_add_error(act_result["error"])
			return false
		if not _load_act(act_result["value"], act_path):
			return false
	if not _validate_act_references_and_cycles():
		return false
	return true

func is_valid() -> bool:
	return diagnostics.is_empty()

func get_diagnostics() -> Array:
	return diagnostics.duplicate(true)

func act_ids() -> Array:
	return _act_order.duplicate()

func get_act(act_id: String) -> Dictionary:
	return _acts.get(act_id, {}).duplicate(true)

func level_ids(act_id: String) -> Array:
	var result: Array = []
	for level_id in _acts.get(act_id, {}).get("level_ids", []):
		result.append(level_id)
	return result

func get_level(act_id: String, level_id: String) -> Dictionary:
	return _levels.get("%s/%s" % [act_id, level_id], {}).duplicate(true)

func _load_act(value: Variant, path: String) -> bool:
	if not value is Dictionary:
		_add_error("%s: root must be an object" % path)
		return false
	var required := ["schema_version", "id", "display_name", "layout_revision", "level_files", "completion_requires"]
	if not _check_object(value, required, ["next_act_id"], path):
		return false
	var act: Dictionary = value
	if act["schema_version"] != 1 or not _nonempty_string(act["id"]) or not _nonempty_string(act["display_name"]) or not _nonempty_string(act["layout_revision"]):
		_add_error("%s: schema_version, id, display_name and layout_revision are invalid" % path)
		return false
	var act_id: String = act["id"]
	if _acts.has(act_id):
		_add_error("%s: duplicate act ID '%s'" % [path, act_id])
		return false
	if not act["level_files"] is Array or act["level_files"].is_empty() or act["level_files"].size() > MAX_LEVELS_PER_ACT:
		_add_error("%s: level_files count must be 1..%d" % [path, MAX_LEVELS_PER_ACT])
		return false
	if not act["completion_requires"] is Array or act["completion_requires"].size() > MAX_PREREQUISITES:
		_add_error("%s: completion_requires must contain at most %d IDs" % [path, MAX_PREREQUISITES])
		return false
	for prerequisite in act["completion_requires"]:
		if not _nonempty_string(prerequisite):
			_add_error("%s: completion_requires IDs must be nonempty strings" % path)
			return false
	var level_ids_for_act: Array = []
	for relative_path in act["level_files"]:
		if not relative_path is String or not _safe_relative_path(relative_path):
			_add_error("%s: level_files contains an unsafe path" % path)
			return false
		var level_path := path.get_base_dir().get_base_dir().path_join(relative_path)
		var level_result := _read_json(level_path)
		if not level_result["valid"]:
			_add_error(level_result["error"])
			return false
		var resolved_result := _resolve_level(level_result["value"], level_path, act_id)
		if not resolved_result["valid"]:
			return false
		var level: Dictionary = resolved_result["value"]
		var key := "%s/%s" % [act_id, level["id"]]
		if _levels.has(key) or _level_id_exists(level["id"]):
			_add_error("%s: duplicate level ID '%s'" % [level_path, level["id"]])
			return false
		_levels[key] = level
		level_ids_for_act.append(level["id"])
	_act_order.append(act_id)
	_acts[act_id] = {"schema_version": 1, "id": act_id, "display_name": act["display_name"], "layout_revision": act["layout_revision"], "level_ids": level_ids_for_act, "completion_requires": act["completion_requires"].duplicate(), "next_act_id": act.get("next_act_id", "")}
	return true

func _resolve_level(value: Variant, path: String, expected_act_id: String) -> Dictionary:
	if not value is Dictionary:
		return _invalid("%s: root must be an object" % path)
	var required := ["schema_version", "content_revision", "id", "act_id", "display_name", "type", "map", "requires_completed", "environment_id", "encounter", "completion", "rewards"]
	var optional := ["designer_notes", "tuning_targets", "well", "boss"]
	if not _check_object(value, required, optional, path):
		return {"valid": false}
	var level: Dictionary = value
	if level["schema_version"] != 1:
		return _invalid("%s: schema_version must be 1" % path)
	if not _integer_value(level["content_revision"]) or float(level["content_revision"]) < 0.0:
		return _invalid("%s: content_revision must be a nonnegative integer" % path)
	if not _nonempty_string(level["id"]):
		return _invalid("%s: id must be a nonempty string" % path)
	if level["act_id"] != expected_act_id:
		return _invalid("%s: act_id must match its act file" % path)
	if not _nonempty_string(level["display_name"]):
		return _invalid("%s: display_name must be a nonempty string" % path)
	if not ["monster", "well", "boss"].has(level["type"]):
		return _invalid("%s: type is unsupported" % path)
	if not level["map"] is Dictionary or not _check_object(level["map"], ["position"], [], "%s: map" % path) or not _normalized_position(level["map"]["position"]):
		return _invalid("%s: map.position must contain two finite values in [0, 1]" % path)
	if not level["requires_completed"] is Array or level["requires_completed"].size() > MAX_PREREQUISITES:
		return _invalid("%s: requires_completed must be an array of at most %d IDs" % [path, MAX_PREREQUISITES])
	for prerequisite in level["requires_completed"]:
		if not _nonempty_string(prerequisite):
			return _invalid("%s: requires_completed IDs must be nonempty strings" % path)
	if not _nonempty_string(level["environment_id"]) or not ENVIRONMENT_IDS.has(level["environment_id"]):
		return _invalid("%s: unknown environment_id '%s'" % [path, level["environment_id"]])
	var encounter_result := _resolve_encounter(level["encounter"], level["type"], path)
	if not encounter_result["valid"]:
		return encounter_result
	var completion_result := _resolve_completion(level["completion"], level["type"], encounter_result["mode"], path)
	if not completion_result["valid"]:
		return completion_result
	var rewards_result := _resolve_rewards(level["rewards"], path)
	if not rewards_result["valid"]:
		return rewards_result
	if level["type"] == "well":
		if not level.has("well"):
			return _invalid("%s: well levels require a well block" % path)
		var well_result := _resolve_well(level["well"], path)
		if not well_result["valid"]:
			return well_result
	elif level.has("well"):
		return _invalid("%s: only well levels may contain a well block" % path)
	var resolved := {"schema_version": 1, "content_revision": level["content_revision"], "id": level["id"], "act_id": level["act_id"], "display_name": level["display_name"], "type": level["type"], "map": {"position": [float(level["map"]["position"][0]), float(level["map"]["position"][1])]}, "requires_completed": level["requires_completed"].duplicate(), "environment_id": level["environment_id"], "encounter": encounter_result["value"], "completion": completion_result["value"], "rewards": rewards_result["value"]}
	if level.has("designer_notes"):
		if not level["designer_notes"] is String:
			return _invalid("%s: designer_notes must be a string" % path)
		resolved["designer_notes"] = level["designer_notes"]
	if level.has("tuning_targets"):
		if not level["tuning_targets"] is Dictionary or not _check_object(level["tuning_targets"], ["first_clear_seconds"], [], "%s: tuning_targets" % path) or not _range_pair(level["tuning_targets"]["first_clear_seconds"], 0.0, INF, false):
			return _invalid("%s: tuning_targets.first_clear_seconds is invalid" % path)
		resolved["tuning_targets"] = {"first_clear_seconds": [float(level["tuning_targets"]["first_clear_seconds"][0]), float(level["tuning_targets"]["first_clear_seconds"][1])]}
	if level.has("well"):
		resolved["well"] = _resolve_well(level["well"], path)["value"]
	if level.has("boss"):
		var boss_result := _resolve_boss(level["boss"], path)
		if not boss_result["valid"]:
			return boss_result
		resolved["boss"] = boss_result["value"]
	var canonical := _canonical_json(resolved)
	resolved["content_hash"] = _sha256(canonical)
	return {"valid": true, "value": resolved}

func _resolve_encounter(value: Variant, level_type: String, path: String) -> Dictionary:
	if not value is Dictionary or not _check_object(value, ["mode", "available_monsters", "scaling", "spawning"], ["monster_overrides"], "%s: encounter" % path):
		return _invalid("%s: encounter is invalid" % path)
	var encounter: Dictionary = value
	if not ["waves", "kill_quota", "extraction"].has(encounter["mode"]):
		return _invalid("%s: encounter.mode is unsupported" % path)
	if level_type == "well" and encounter["mode"] != "extraction":
		return _invalid("%s: well level must use extraction mode" % path)
	if level_type == "boss" and encounter["mode"] != "waves":
		return _invalid("%s: boss level must use waves mode" % path)
	if not encounter["available_monsters"] is Array or encounter["available_monsters"].is_empty() or encounter["available_monsters"].size() > MAX_POOL_ENTRIES:
		return _invalid("%s: encounter.available_monsters must be a bounded nonempty array" % path)
	var available: Array = []
	for monster_id in encounter["available_monsters"]:
		if not _nonempty_string(monster_id) or not MONSTER_IDS.has(monster_id) or available.has(monster_id):
			return _invalid("%s: encounter.available_monsters contains an invalid or duplicate ID" % path)
		available.append(monster_id)
	var scaling_result := _resolve_scaling(encounter["scaling"], "%s: encounter.scaling" % path)
	if not scaling_result["valid"]:
		return scaling_result
	var resolved := {"mode": encounter["mode"], "available_monsters": available, "scaling": scaling_result["value"]}
	if encounter.has("monster_overrides"):
		if not encounter["monster_overrides"] is Dictionary:
			return _invalid("%s: encounter.monster_overrides must be an object" % path)
		var overrides: Dictionary = {}
		for monster_id in encounter["monster_overrides"]:
			if not available.has(monster_id) or not encounter["monster_overrides"][monster_id] is Dictionary:
				return _invalid("%s: monster override references an unavailable monster" % path)
			var override_result := _resolve_scaling(encounter["monster_overrides"][monster_id], "%s: monster_overrides.%s" % [path, monster_id], ["role"])
			if not override_result["valid"]:
				return override_result
			overrides[monster_id] = override_result["value"]
		resolved["monster_overrides"] = overrides
	var spawning_result := _resolve_spawning(encounter["spawning"], encounter["mode"], level_type, available, path)
	if not spawning_result["valid"]:
		return spawning_result
	resolved["spawning"] = spawning_result["value"]
	return {"valid": true, "mode": encounter["mode"], "value": resolved}

func _resolve_scaling(value: Variant, path: String, extra_fields: Array = []) -> Dictionary:
	if not value is Dictionary or not _check_object(value, ["hp_multiplier", "damage_multiplier", "move_speed_multiplier", "attack_interval_multiplier"], extra_fields, path):
		return _invalid("%s must define all four multipliers" % path)
	var result := {}
	for field in ["hp_multiplier", "damage_multiplier", "move_speed_multiplier", "attack_interval_multiplier"]:
		if not _positive_finite(value[field]):
			return _invalid("%s.%s must be > 0 and finite" % [path, field])
		result[field] = float(value[field])
	for field in extra_fields:
		if field == "role":
			if not value.has(field) or value[field] != "boss":
				return _invalid("%s.role must be 'boss'" % path)
			result[field] = value[field]
	return {"valid": true, "value": result}

func _resolve_spawning(value: Variant, mode: String, level_type: String, available: Array, path: String) -> Dictionary:
	if not value is Dictionary:
		return _invalid("%s: encounter.spawning must be an object" % path)
	if mode == "waves":
		if not _check_object(value, ["waves"], [], "%s: spawning" % path) or not value["waves"] is Array or value["waves"].is_empty() or value["waves"].size() > MAX_WAVES:
			return _invalid("%s: spawning.waves must be a bounded nonempty array" % path)
		var waves: Array = []
		for wave in value["waves"]:
			if not wave is Dictionary or not _check_object(wave, ["monsters", "delay_before_seconds"], [], "%s: wave" % path) or not wave["monsters"] is Array or wave["monsters"].is_empty() or wave["monsters"].size() > MAX_SPAWNS_PER_WAVE or not _nonnegative_finite(wave["delay_before_seconds"]):
				return _invalid("%s: wave is invalid" % path)
			var entries: Array = []
			for entry in wave["monsters"]:
				if not entry is Dictionary or not _check_object(entry, ["monster_id", "count"], ["role", "spawn_id"], "%s: wave monster" % path) or not available.has(entry["monster_id"]) or not _positive_int(entry["count"], MAX_COUNT):
					return _invalid("%s: wave monster is invalid or unavailable" % path)
				var normalized_entry := {"monster_id": entry["monster_id"], "count": entry["count"]}
				if entry.has("role"):
					if entry["role"] != "boss" or level_type != "boss":
						return _invalid("%s: boss role is only valid on boss levels" % path)
					normalized_entry["role"] = "boss"
				if entry.has("spawn_id"):
					if not _nonempty_string(entry["spawn_id"]):
						return _invalid("%s: spawn_id must be a nonempty string" % path)
					normalized_entry["spawn_id"] = entry["spawn_id"]
				entries.append(normalized_entry)
			waves.append({"monsters": entries, "delay_before_seconds": float(wave["delay_before_seconds"])})
		return {"valid": true, "value": {"waves": waves}}
	if mode == "kill_quota":
		if not _check_object(value, ["interval_seconds", "max_alive", "pool"], [], "%s: spawning" % path) or not _positive_finite(value["interval_seconds"]) or not _positive_int(value["max_alive"], MAX_COUNT) or not value["pool"] is Array or value["pool"].is_empty() or value["pool"].size() > MAX_POOL_ENTRIES:
			return _invalid("%s: kill-quota spawning is invalid" % path)
		var pool: Array = []
		var total_weight := 0.0
		for entry in value["pool"]:
			if not entry is Dictionary or not _check_object(entry, ["monster_id", "weight"], [], "%s: spawning.pool" % path) or not available.has(entry["monster_id"]) or not _positive_finite(entry["weight"]):
				return _invalid("%s: spawning.pool entry is invalid" % path)
			total_weight += float(entry["weight"])
			pool.append({"monster_id": entry["monster_id"], "weight": float(entry["weight"])})
		if not _positive_finite(total_weight):
			return _invalid("%s: spawning.pool must have positive finite total weight" % path)
		return {"valid": true, "value": {"interval_seconds": float(value["interval_seconds"]), "max_alive": value["max_alive"], "pool": pool}}
	if not _check_object(value, ["schedule_id"], [], "%s: spawning" % path) or not SCHEDULE_IDS.has(value["schedule_id"]):
		return _invalid("%s: unknown extraction schedule_id" % path)
	return {"valid": true, "value": {"schedule_id": value["schedule_id"]}}

func _resolve_completion(value: Variant, level_type: String, mode: String, path: String) -> Dictionary:
	if not value is Dictionary or not value.has("objective"):
		return _invalid("%s: completion.objective is required" % path)
	if not _check_object(value, ["objective"], ["required_kills", "count_monsters", "progress_scope", "boss_spawn_id", "minimum_completed_surges"], "%s: completion" % path):
		return {"valid": false}
	var objective: String = value["objective"] if value["objective"] is String else ""
	var allowed := {"waves": ["clear_waves", "defeat_boss"], "kill_quota": ["kill_count"], "extraction": ["extract"]}
	if not allowed[mode].has(objective):
		return _invalid("%s: completion.objective does not match encounter.mode" % path)
	if level_type == "boss" and objective != "defeat_boss":
		return _invalid("%s: boss level must defeat a boss" % path)
	if level_type != "boss" and objective == "defeat_boss":
		return _invalid("%s: only boss levels may defeat a boss" % path)
	var result := {"objective": objective}
	if objective == "kill_count":
		if not _check_object(value, ["objective", "required_kills", "count_monsters", "progress_scope"], [], "%s: completion" % path) or not _positive_int(value["required_kills"], MAX_COUNT) or value["progress_scope"] != "run" or not value["count_monsters"] is Array or value["count_monsters"].is_empty():
			return _invalid("%s: kill-count completion is invalid" % path)
		result["required_kills"] = value["required_kills"]
		result["count_monsters"] = value["count_monsters"].duplicate()
		result["progress_scope"] = "run"
	elif objective == "defeat_boss":
		if not _check_object(value, ["objective", "boss_spawn_id"], [], "%s: completion" % path) or not _nonempty_string(value["boss_spawn_id"]):
			return _invalid("%s: boss_spawn_id is required" % path)
		result["boss_spawn_id"] = value["boss_spawn_id"]
	elif objective == "extract":
		if not _check_object(value, ["objective", "minimum_completed_surges"], [], "%s: completion" % path) or not _positive_int(value["minimum_completed_surges"], MAX_COUNT):
			return _invalid("%s: minimum_completed_surges is invalid" % path)
		result["minimum_completed_surges"] = value["minimum_completed_surges"]
	return {"valid": true, "value": result}

func _resolve_rewards(value: Variant, path: String) -> Dictionary:
	if not value is Dictionary or not _check_object(value, ["mana_on_success", "loot", "guaranteed_items"], [], "%s: rewards" % path) or not _nonnegative_finite(value["mana_on_success"]):
		return _invalid("%s: rewards are invalid" % path)
	if not value["loot"] is Dictionary or not _check_object(value["loot"], ["table_id", "item_level", "ordinary_drop_chance", "boss_drop_chance"], [], "%s: rewards.loot" % path) or not LOOT_TABLE_IDS.has(value["loot"]["table_id"]) or not _supported_item_level(value["loot"]["item_level"]) or not _probability(value["loot"]["ordinary_drop_chance"]) or not _probability(value["loot"]["boss_drop_chance"]):
		return _invalid("%s: loot table, item level or probability is invalid" % path)
	if not value["guaranteed_items"] is Array or value["guaranteed_items"].size() > MAX_GUARANTEED_ITEMS:
		return _invalid("%s: guaranteed_items exceeds the limit" % path)
	var guarantees: Array = []
	var reward_ids: Dictionary = {}
	for item in value["guaranteed_items"]:
		if not item is Dictionary or not _check_object(item, ["reward_id", "trigger", "base_id", "item_level", "rarity", "quantity"], [], "%s: guaranteed item" % path) or not _nonempty_string(item["reward_id"]) or reward_ids.has(item["reward_id"]) or item["trigger"] != "first_clear" or not BASE_ITEM_IDS.has(item["base_id"]) or not _supported_item_level(item["item_level"]) or not ["common", "rare", "epic"].has(item["rarity"]) or not _positive_int(item["quantity"], MAX_COUNT):
			return _invalid("%s: duplicate or invalid guaranteed reward" % path)
		reward_ids[item["reward_id"]] = true
		guarantees.append(item.duplicate(true))
	return {"valid": true, "value": {"mana_on_success": float(value["mana_on_success"]), "loot": {"table_id": value["loot"]["table_id"], "item_level": value["loot"]["item_level"], "ordinary_drop_chance": float(value["loot"]["ordinary_drop_chance"]), "boss_drop_chance": float(value["loot"]["boss_drop_chance"])}, "guaranteed_items": guarantees}}

func _resolve_well(value: Variant, path: String) -> Dictionary:
	if not value is Dictionary or not _check_object(value, ["id", "base_mana_per_second", "spawn_interval_multiplier", "pressure_time_multiplier", "machine_integrity", "sealing_seconds", "payout_curve_id", "allowed_loadouts"], ["enemy_damage_factor"], "%s: well" % path) or not _nonempty_string(value["id"]) or not _positive_finite(value["base_mana_per_second"]) or not _positive_finite(value["spawn_interval_multiplier"]) or not _positive_finite(value["pressure_time_multiplier"]) or not _positive_finite(value["machine_integrity"]) or not _positive_finite(value["sealing_seconds"]) or value["payout_curve_id"] != "surge_payout_v1" or not value["allowed_loadouts"] is Array or value["allowed_loadouts"].is_empty():
		return _invalid("%s: well definition is invalid" % path)
	if value.has("enemy_damage_factor") and not _positive_finite(value["enemy_damage_factor"]):
		return _invalid("%s.enemy_damage_factor must be > 0 and finite" % path)
	return {"valid": true, "value": value.duplicate(true)}

func _resolve_boss(value: Variant, path: String) -> Dictionary:
	if not value is Dictionary or not _check_object(value, ["health", "attack_interval", "attack_damage"], [], "%s: boss" % path) or not _positive_finite(value["health"]) or not _positive_finite(value["attack_interval"]) or not _positive_finite(value["attack_damage"]):
		return _invalid("%s: boss profile is invalid" % path)
	return {"valid": true, "value": {"health": float(value["health"]), "attack_interval": float(value["attack_interval"]), "attack_damage": float(value["attack_damage"])} }

func _validate_act_references_and_cycles() -> bool:
	var reward_ids: Dictionary = {}
	for act_id: String in _act_order:
		var act: Dictionary = _acts[act_id]
		for prerequisite in act["completion_requires"]:
			if not _acts.has(prerequisite):
				_add_error("act %s: unknown completion_requires reference '%s'" % [act_id, prerequisite])
				return false
		for level_id in act["level_ids"]:
			var level: Dictionary = _levels["%s/%s" % [act_id, level_id]]
			for reward in level["rewards"]["guaranteed_items"]:
				if reward_ids.has(reward["reward_id"]):
					_add_error("%s: duplicate reward ID '%s'" % [level_id, reward["reward_id"]])
					return false
				reward_ids[reward["reward_id"]] = true
			for prerequisite in level["requires_completed"]:
				if not _levels.has("%s/%s" % [act_id, prerequisite]):
					_add_error("%s.json: requires_completed references unknown level '%s'" % [level_id, prerequisite])
					return false
			if level["completion"]["objective"] == "kill_count":
				for monster_id in level["completion"]["count_monsters"]:
					if not level["encounter"]["available_monsters"].has(monster_id):
						_add_error("%s: completion.count_monsters references unavailable monster '%s'" % [level_id, monster_id])
						return false
		if _has_cycle_for_act(act_id):
			return false
	return true

func _level_id_exists(level_id: String) -> bool:
	for existing_key in _levels:
		if _levels[existing_key]["id"] == level_id:
			return true
	return false

func _has_cycle_for_act(act_id: String) -> bool:
	var state := {}
	for level_id in _acts[act_id]["level_ids"]:
		if _visit_level(act_id, level_id, state):
			_add_error("%s: requires_completed graph contains a cycle" % act_id)
			return true
	return false

func _visit_level(act_id: String, level_id: String, state: Dictionary) -> bool:
	if state.get(level_id, 0) == 1:
		return true
	if state.get(level_id, 0) == 2:
		return false
	state[level_id] = 1
	for prerequisite in _levels["%s/%s" % [act_id, level_id]]["requires_completed"]:
		if _visit_level(act_id, prerequisite, state):
			return true
	state[level_id] = 2
	return false

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false, "error": "%s: file does not exist" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return {"valid": false, "error": "%s: malformed JSON" % path}
	return {"valid": true, "value": parsed}

func _check_object(value: Dictionary, required: Array, optional: Array, path: String) -> bool:
	for field in required:
		if not value.has(field):
			_add_error("%s: missing field '%s'" % [path, field])
			return false
	for field in value.keys():
		if not required.has(field) and not optional.has(field):
			_add_error("%s: unknown field '%s'" % [path, field])
			return false
	return true

func _safe_relative_path(path: String) -> bool:
	return not path.is_empty() and path.ends_with(".json") and not path.begins_with("/") and not path.contains("\\") and not path.split("/").has("..") and not path.split("/").has("")

func _nonempty_string(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_STRING_LENGTH

func _positive_int(value: Variant, maximum: int) -> bool:
	return _integer_value(value) and int(value) > 0 and int(value) <= maximum

func _integer_value(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value)

func _supported_item_level(value: Variant) -> bool:
	return _integer_value(value) and SUPPORTED_ITEM_LEVELS.has(int(value))

func _positive_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

func _nonnegative_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

func _probability(value: Variant) -> bool:
	return _nonnegative_finite(value) and float(value) <= 1.0

func _normalized_position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _probability(value[0]) and _probability(value[1])

func _range_pair(value: Variant, minimum: float, maximum: float, strict: bool) -> bool:
	return value is Array and value.size() == 2 and _nonnegative_finite(value[0]) and _nonnegative_finite(value[1]) and float(value[0]) <= float(value[1]) and float(value[0]) >= minimum and float(value[1]) <= maximum

func _invalid(error: String) -> Dictionary:
	_add_error(error)
	return {"valid": false, "error": error}

func _add_error(error: String) -> void:
	diagnostics.append(error)

func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array = []
		for key in keys:
			parts.append(JSON.stringify(str(key)) + ":" + _canonical_json(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_canonical_json(item))
		return "[" + ",".join(items) + "]"
	return JSON.stringify(value)

func _sha256(text: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(text.to_utf8_buffer())
	return hashing.finish().hex_encode()