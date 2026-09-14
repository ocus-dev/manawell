class_name RunSnapshot
extends RefCounted

const SNAPSHOT_VERSION: int = 5
const LEGACY_SNAPSHOT_VERSION: int = 4
const CONFIG_VERSION: String = "prototype-platform-recovery-v1"
const RunStateScript = preload("res://scripts/model/run_state.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")

static func encode(snapshot: Dictionary) -> Dictionary:
	var normalized: Dictionary = _with_defaults(snapshot)
	var validation: Dictionary = validate(normalized)
	if not validation["valid"]:
		return {"valid": false, "error": validation["error"]}
	return {
		"valid": true,
		"payload": {
			"snapshot_version": SNAPSHOT_VERSION,
			"config_version": CONFIG_VERSION,
			"run_state": normalized["run_state"],
			"actors": normalized["actors"],
			"projectiles": normalized["projectiles"],
			"player_abilities": normalized["player_abilities"],
			"weapon_state": normalized["weapon_state"],
			"spawner": normalized["spawner"],
			"arena_config_id": normalized["arena_config_id"],
			"level_definition": normalized["level_definition"],
			"level_content_hash": normalized["level_content_hash"],
			"campaign": normalized["campaign"],
			"objective": normalized["objective"],
			"reward_state": normalized["reward_state"],
		},
	}

static func decode(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return {"valid": false, "error": "snapshot root must be an object"}
	var snapshot_version: Variant = payload.get("snapshot_version", -1)
	if not _valid_integer(snapshot_version) or int(snapshot_version) != SNAPSHOT_VERSION:
		return {"valid": false, "error": "unsupported snapshot version"}
	if not payload.get("config_version", "") is String or payload.get("config_version", "") != CONFIG_VERSION:
		return {"valid": false, "error": "incompatible snapshot config version"}
	for field in ["level_definition", "level_content_hash", "campaign", "objective", "reward_state"]:
		if not payload.has(field):
			return {"valid": false, "error": "snapshot missing %s" % field}
	var normalized: Dictionary = _with_defaults(payload)
	var validation: Dictionary = validate(normalized)
	if not validation["valid"]:
		return validation
	return {"valid": true, "snapshot": normalized}

static func _with_defaults(snapshot: Dictionary) -> Dictionary:
	var normalized: Dictionary = snapshot.duplicate(true)
	if not normalized.get("run_state", null) is Dictionary:
		return normalized
	var state: Dictionary = normalized["run_state"].duplicate(true)
	if not state.has("pressure_time_scale"):
		state["pressure_time_scale"] = 1.0
	if not state.has("machine_max_integrity"):
		state["machine_max_integrity"] = state.get("machine_integrity", 0.0)
	normalized["run_state"] = state
	if normalized.get("spawner", null) is Dictionary:
		var spawner: Dictionary = normalized["spawner"].duplicate(true)
		if not spawner.has("next_id"):
			spawner["next_id"] = 1
		if not spawner.has("rng_state"):
			spawner["rng_state"] = 1
		normalized["spawner"] = spawner
	if not normalized.has("level_definition"):
		normalized["level_definition"] = {}
	if not normalized.has("level_content_hash"):
		normalized["level_content_hash"] = ""
	if not normalized.has("campaign"):
		normalized["campaign"] = {}
	if not normalized.has("objective"):
		normalized["objective"] = {"objective_id": "", "progress": 0, "required": 0, "credited_ids": []}
	if not normalized.has("reward_state"):
		normalized["reward_state"] = {"claim_receipts": [], "pending_items": []}
	return normalized

static func validate(snapshot: Dictionary) -> Dictionary:
	for field in ["run_state", "actors", "projectiles", "player_abilities", "spawner", "weapon_state", "arena_config_id", "level_definition", "level_content_hash", "campaign", "objective", "reward_state"]:
		if not snapshot.has(field):
			return {"valid": false, "error": "snapshot missing %s" % field}
	if not _valid_string(snapshot["arena_config_id"]) or snapshot["arena_config_id"] != ArenaLayoutScript.CONFIG_ID:
		return {"valid": false, "error": "snapshot arena config is incompatible"}
	if not snapshot["run_state"] is Dictionary or not snapshot["player_abilities"] is Dictionary or not snapshot["spawner"] is Dictionary or not snapshot["weapon_state"] is Dictionary:
		return {"valid": false, "error": "snapshot state sections must be objects"}
	if not snapshot["actors"] is Array or not snapshot["projectiles"] is Array:
		return {"valid": false, "error": "actors and projectiles must be arrays"}
	var run_validation: Dictionary = _validate_run_state(snapshot["run_state"])
	if not run_validation["valid"]:
		return run_validation
	var ability_validation: Dictionary = _validate_abilities(snapshot["player_abilities"])
	if not ability_validation["valid"]:
		return ability_validation
	var spawner_validation: Dictionary = _validate_spawner(snapshot["spawner"])
	if not spawner_validation["valid"]:
		return spawner_validation
	var weapon_validation: Dictionary = _validate_weapon(snapshot["weapon_state"])
	if not weapon_validation["valid"]:
		return weapon_validation
	var frozen_validation: Dictionary = _validate_frozen_state(snapshot)
	if not frozen_validation["valid"]:
		return frozen_validation
	var actor_ids: Dictionary = {}
	var hero_count: int = 0
	var machine_count: int = 0
	for actor in snapshot["actors"]:
		var actor_validation: Dictionary = _validate_actor(actor, actor_ids)
		if not actor_validation["valid"]:
			return actor_validation
		if actor["kind"] == "hero":
			hero_count += 1
		elif actor["kind"] == "machine":
			machine_count += 1
	if hero_count != 1 or machine_count != 1:
		return {"valid": false, "error": "snapshot must contain one hero and one machine"}
	var known_target_ids: Dictionary = actor_ids.duplicate()
	known_target_ids["hero"] = true
	known_target_ids["machine"] = true
	for actor in snapshot["actors"]:
		if not actor["target_id"].is_empty() and not known_target_ids.has(actor["target_id"]):
			return {"valid": false, "error": "actor target ID is invalid"}
	var projectile_ids: Dictionary = {}
	for projectile in snapshot["projectiles"]:
		var projectile_validation: Dictionary = _validate_projectile(projectile, known_target_ids)
		if not projectile_validation["valid"]:
			return projectile_validation
		var projectile_id: String = str(projectile["id"])
		if projectile_ids.has(projectile_id):
			return {"valid": false, "error": "projectile IDs must be unique"}
		projectile_ids[projectile_id] = true
	return {"valid": true}

static func _validate_run_state(state: Dictionary) -> Dictionary:
	for field in ["run_id", "well_id", "hero_id", "module_id", "phase", "paused", "simulation_elapsed", "tank_base", "extraction_rate", "pressure_time_scale", "completed_surges", "multiplier", "locked_payout", "sealing_remaining", "sealing_duration", "hero_health", "machine_integrity", "machine_max_integrity", "terminal_reason"]:
		if not state.has(field):
			return {"valid": false, "error": "run state missing %s" % field}
	if not _valid_string(state["run_id"]) or not _valid_string(state["well_id"]) or not _valid_string(state["hero_id"]) or not _valid_string(state["module_id"]) or not _valid_string(state["terminal_reason"]):
		return {"valid": false, "error": "run state identity fields are invalid"}
	if not _valid_integer(state["phase"]) or int(state["phase"]) < RunStateScript.Phase.EXTRACTING or int(state["phase"]) > RunStateScript.Phase.SEALING:
		return {"valid": false, "error": "snapshot phase is not resumable"}
	if not state["paused"] is bool:
		return {"valid": false, "error": "run state paused flag is invalid"}
	for field in ["simulation_elapsed", "tank_base", "extraction_rate", "pressure_time_scale", "multiplier", "sealing_remaining", "sealing_duration", "hero_health", "machine_integrity", "machine_max_integrity"]:
		if not _finite_nonnegative(state[field]):
			return {"valid": false, "error": "run state timer or value is invalid"}
	if not _valid_integer(state["completed_surges"]) or int(state["completed_surges"]) < 0 or not _valid_integer(state["locked_payout"]) or int(state["locked_payout"]) < 0:
		return {"valid": false, "error": "run state counters are invalid"}
	return {"valid": true}

static func _validate_actor(actor: Variant, actor_ids: Dictionary) -> Dictionary:
	if not actor is Dictionary:
		return {"valid": false, "error": "actor must be an object"}
	for field in ["id", "kind", "position", "health", "max_health", "cooldown_remaining", "windup_remaining", "target_id", "dead", "component_state"]:
		if not actor.has(field):
			return {"valid": false, "error": "actor missing %s" % field}
	if not _valid_string(actor["id"]) or not _valid_string(actor["kind"]):
		return {"valid": false, "error": "actor identity is invalid"}
	var actor_id: String = actor["id"]
	if actor_id.is_empty() or actor_ids.has(actor_id):
		return {"valid": false, "error": "actor IDs must be unique and non-empty"}
	if not ["hero", "machine", "pursuer", "breaker", "ranged"].has(actor["kind"]):
		return {"valid": false, "error": "actor kind is invalid"}
	if not _valid_vector(actor["position"]):
		return {"valid": false, "error": "actor position is invalid"}
	for field in ["health", "max_health", "cooldown_remaining", "windup_remaining"]:
		if not _finite_nonnegative(actor[field]):
			return {"valid": false, "error": "actor timer or health is invalid"}
	if not _valid_string(actor["target_id"]) or not actor["dead"] is bool:
		return {"valid": false, "error": "actor identity or dead flag is invalid"}
	if not actor["component_state"] is Dictionary:
		return {"valid": false, "error": "actor component state is invalid"}
	var component_validation: Dictionary = _validate_component_state(str(actor["kind"]), actor["component_state"], actor["position"])
	if not component_validation["valid"]:
		return component_validation
	actor_ids[actor_id] = true
	return {"valid": true}

static func _validate_component_state(kind: String, state: Dictionary, position: Array) -> Dictionary:
	if kind != "hero":
		if kind == "ranged":
			if not state.has("locked_target_point") or not _valid_vector(state["locked_target_point"]):
				return {"valid": false, "error": "ranged locked aim is invalid"}
		return {"valid": true}
	for field in ["last_facing", "vertical_velocity", "grounded", "support_id", "ignored_support_id", "drop_through_remaining", "jump_buffer_remaining", "coyote_remaining"]:
		if not state.has(field):
			return {"valid": false, "error": "hero component state missing %s" % field}
	if not _valid_integer(state["last_facing"]) or absi(int(state["last_facing"])) != 1:
		return {"valid": false, "error": "hero facing state is invalid"}
	if not _finite(state["vertical_velocity"]) or not _finite_nonnegative(state["drop_through_remaining"]) or not _finite_nonnegative(state["jump_buffer_remaining"]) or not _finite_nonnegative(state["coyote_remaining"]):
		return {"valid": false, "error": "hero motion state is invalid"}
	if not state["grounded"] is bool or not _valid_string(state["support_id"]) or not _valid_string(state["ignored_support_id"]):
		return {"valid": false, "error": "hero support state is invalid"}
	if state["grounded"] and state["support_id"].is_empty():
		return {"valid": false, "error": "grounded hero support ID is missing"}
	if state["grounded"] and not is_zero_approx(float(state.get("vertical_velocity", 0.0))):
		return {"valid": false, "error": "grounded hero velocity is invalid"}
	if state["grounded"] and not is_equal_approx(float(position[1]), ArenaLayoutScript.hero_support_y(state["support_id"])):
		return {"valid": false, "error": "hero support geometry is invalid"}
	if not state["support_id"].is_empty() and state["support_id"] != ArenaLayoutScript.FLOOR_ID and ArenaLayoutScript.support_by_id(state["support_id"]).is_empty():
		return {"valid": false, "error": "hero support ID is invalid"}
	if not state["ignored_support_id"].is_empty() and state["ignored_support_id"] != ArenaLayoutScript.FLOOR_ID and ArenaLayoutScript.support_by_id(state["ignored_support_id"]).is_empty():
		return {"valid": false, "error": "hero ignored support ID is invalid"}
	return {"valid": true}

static func _validate_projectile(projectile: Variant, known_target_ids: Dictionary) -> Dictionary:
	if not projectile is Dictionary:
		return {"valid": false, "error": "projectile must be an object"}
	for field in ["id", "kind", "owner_id", "target_id", "position", "velocity", "damage", "lifetime_remaining", "hit_target"]:
		if not projectile.has(field):
			return {"valid": false, "error": "projectile missing %s" % field}
	if not _valid_string(projectile["id"]) or not _valid_string(projectile["owner_id"]) or not _valid_string(projectile["target_id"]):
		return {"valid": false, "error": "projectile identity is invalid"}
	if not _valid_string(projectile["kind"]) or not ["friendly", "hostile"].has(projectile["kind"]):
		return {"valid": false, "error": "projectile kind is invalid"}
	if str(projectile["id"]).is_empty() or not known_target_ids.has(projectile["owner_id"]) or not known_target_ids.has(projectile["target_id"]):
		return {"valid": false, "error": "projectile reference ID is invalid"}
	if not _valid_vector(projectile["position"]) or not _valid_vector(projectile["velocity"]):
		return {"valid": false, "error": "projectile vector is invalid"}
	if not _finite_nonnegative(projectile["damage"]) or not _finite_nonnegative(projectile["lifetime_remaining"]):
		return {"valid": false, "error": "projectile value is invalid"}
	if not projectile["hit_target"] is bool:
		return {"valid": false, "error": "projectile hit flag is invalid"}
	return {"valid": true}

static func _validate_abilities(abilities: Dictionary) -> Dictionary:
	for field in ["dash_cooldown_remaining", "pulse_cooldown_remaining", "dash_remaining", "dash_direction", "dash_active", "ability_flash_remaining"]:
		if not abilities.has(field):
			return {"valid": false, "error": "ability state missing %s" % field}
	for field in ["dash_cooldown_remaining", "pulse_cooldown_remaining", "dash_remaining", "ability_flash_remaining"]:
		if not _finite_nonnegative(abilities[field]):
			return {"valid": false, "error": "ability timer is invalid"}
	if not _valid_vector(abilities["dash_direction"]):
		return {"valid": false, "error": "dash direction is invalid"}
	if not abilities["dash_active"] is bool:
		return {"valid": false, "error": "ability dash flag is invalid"}
	return {"valid": true}

static func _validate_spawner(spawner: Dictionary) -> Dictionary:
	for field in ["spawn_timer", "spawn_index", "spawn_position", "config_id", "next_id", "rng_state"]:
		if not spawner.has(field):
			return {"valid": false, "error": "spawner missing %s" % field}
	if not _finite_nonnegative(spawner["spawn_timer"]) or not _valid_integer(spawner["spawn_index"]) or int(spawner["spawn_index"]) < 0 or not _valid_vector(spawner["spawn_position"]):
		return {"valid": false, "error": "spawner state is invalid"}
	if not _valid_integer(spawner["next_id"]) or int(spawner["next_id"]) < 1:
		return {"valid": false, "error": "spawner next ID is invalid"}
	if not _valid_integer(spawner["rng_state"]) or int(spawner["rng_state"]) < 1 or int(spawner["rng_state"]) >= 2147483647:
		return {"valid": false, "error": "spawner RNG state is invalid"}
	if not _valid_string(spawner["config_id"]) or str(spawner["config_id"]).is_empty():
		return {"valid": false, "error": "spawner config ID is invalid"}
	return {"valid": true}

static func _validate_frozen_state(snapshot: Dictionary) -> Dictionary:
	if not snapshot["level_definition"] is Dictionary or not _valid_string(snapshot["level_content_hash"]):
		return {"valid": false, "error": "frozen level definition is invalid"}
	var definition: Dictionary = snapshot["level_definition"]
	var content_hash := str(snapshot["level_content_hash"])
	if definition.is_empty() != content_hash.is_empty():
		return {"valid": false, "error": "frozen level definition and hash must agree"}
	if not content_hash.is_empty() and content_hash != _definition_hash(definition):
		return {"valid": false, "error": "frozen level definition hash mismatch"}
	for field in ["campaign", "objective", "reward_state"]:
		if not snapshot[field] is Dictionary:
			return {"valid": false, "error": "%s state must be an object" % field}
	var objective: Dictionary = snapshot["objective"]
	for field in ["objective_id", "progress", "required", "credited_ids"]:
		if not objective.has(field):
			return {"valid": false, "error": "objective state missing %s" % field}
	if not _valid_string(objective["objective_id"]) or not _valid_integer(objective["progress"]) or int(objective["progress"]) < 0 or not _valid_integer(objective["required"]) or int(objective["required"]) < 0 or not objective["credited_ids"] is Array:
		return {"valid": false, "error": "objective state is invalid"}
	var credited: Dictionary = {}
	for credited_id in objective["credited_ids"]:
		if not _valid_string(credited_id) or str(credited_id).is_empty() or credited.has(credited_id):
			return {"valid": false, "error": "objective credited IDs are invalid"}
		credited[credited_id] = true
	var rewards: Dictionary = snapshot["reward_state"]
	for field in ["claim_receipts", "pending_items"]:
		if not rewards.has(field) or not rewards[field] is Array:
			return {"valid": false, "error": "reward state is invalid"}
	var receipts: Dictionary = {}
	for receipt in rewards["claim_receipts"]:
		if not _valid_string(receipt) or str(receipt).is_empty() or receipts.has(receipt):
			return {"valid": false, "error": "claim receipts are invalid"}
		receipts[receipt] = true
	for item in rewards["pending_items"]:
		if not item is Dictionary or not _valid_string(item.get("instance_id", "")) or str(item.get("instance_id", "")).is_empty():
			return {"valid": false, "error": "pending reward item is invalid"}
	return {"valid": true}

static func _definition_hash(definition: Dictionary) -> String:
	var copy := definition.duplicate(true)
	copy.erase("content_hash")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_canonical_json(copy).to_utf8_buffer())
	return context.finish().hex_encode()

static func content_hash_for(definition: Dictionary) -> String:
	return _definition_hash(definition)

static func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array[String] = []
		for key in value.keys():
			keys.append(str(key))
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append(JSON.stringify(key) + ":" + _canonical_json(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var entries: Array[String] = []
		for item in value:
			entries.append(_canonical_json(item))
		return "[" + ",".join(entries) + "]"
	return JSON.stringify(value)

static func _valid_vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(component): return (component is int or component is float) and is_finite(float(component)))

static func _finite_nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and is_equal_approx(float(value), floorf(float(value)))

static func _valid_string(value: Variant) -> bool:
	return value is String

static func _validate_weapon(weapon: Dictionary) -> Dictionary:
	for field in ["damage", "spread_enabled", "attack_interval", "shot_accumulator"]:
		if not weapon.has(field):
			return {"valid": false, "error": "weapon state missing %s" % field}
	if not _finite_nonnegative(weapon["damage"]) or not _finite_nonnegative(weapon["attack_interval"]) or not _finite_nonnegative(weapon["shot_accumulator"]):
		return {"valid": false, "error": "weapon state value is invalid"}
	if not weapon["spread_enabled"] is bool:
		return {"valid": false, "error": "weapon spread flag is invalid"}
	return {"valid": true}
