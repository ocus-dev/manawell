class_name RunSnapshot
extends RefCounted

const SNAPSHOT_VERSION: int = 3
const LEGACY_SNAPSHOT_VERSION: int = 1
const CONFIG_VERSION: String = "prototype-config-1"
const RunStateScript = preload("res://scripts/model/run_state.gd")

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
		},
	}

static func decode(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return {"valid": false, "error": "snapshot root must be an object"}
	var snapshot_version: Variant = payload.get("snapshot_version", -1)
	if not _valid_integer(snapshot_version) or (int(snapshot_version) != SNAPSHOT_VERSION and int(snapshot_version) != LEGACY_SNAPSHOT_VERSION):
		return {"valid": false, "error": "unsupported snapshot version"}
	if not payload.get("config_version", "") is String or payload.get("config_version", "") != CONFIG_VERSION:
		return {"valid": false, "error": "incompatible snapshot config version"}
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
		normalized["spawner"] = spawner
	return normalized

static func validate(snapshot: Dictionary) -> Dictionary:
	for field in ["run_state", "actors", "projectiles", "player_abilities", "spawner", "weapon_state"]:
		if not snapshot.has(field):
			return {"valid": false, "error": "snapshot missing %s" % field}
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
	actor_ids[actor_id] = true
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
	for field in ["spawn_timer", "spawn_index", "spawn_position", "config_id", "next_id"]:
		if not spawner.has(field):
			return {"valid": false, "error": "spawner missing %s" % field}
	if not _finite_nonnegative(spawner["spawn_timer"]) or not _valid_integer(spawner["spawn_index"]) or int(spawner["spawn_index"]) < 0 or not _valid_vector(spawner["spawn_position"]):
		return {"valid": false, "error": "spawner state is invalid"}
	if not _valid_integer(spawner["next_id"]) or int(spawner["next_id"]) < 1:
		return {"valid": false, "error": "spawner next ID is invalid"}
	if not _valid_string(spawner["config_id"]) or str(spawner["config_id"]).is_empty():
		return {"valid": false, "error": "spawner config ID is invalid"}
	return {"valid": true}

static func _valid_vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(component): return component is int or component is float and is_finite(float(component)))

static func _finite_nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

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
