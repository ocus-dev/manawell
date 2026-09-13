extends SceneTree

const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")

func _init() -> void:
	var snapshot: Dictionary = _synthetic_snapshot()
	var encoded: Dictionary = SnapshotScript.encode(snapshot)
	assert(encoded["valid"])
	var decoded: Dictionary = SnapshotScript.decode(encoded["payload"])
	assert(decoded["valid"])
	assert(decoded["snapshot"]["run_state"]["phase"] == 2)
	assert(decoded["snapshot"]["actors"][1]["health"] == 17.0)
	assert(decoded["snapshot"]["projectiles"][0]["lifetime_remaining"] == 1.2)
	assert(decoded["snapshot"]["player_abilities"]["dash_active"])
	assert(decoded["snapshot"]["spawner"]["spawn_index"] == 11)
	assert(decoded["snapshot"]["arena_config_id"] == ArenaLayoutScript.CONFIG_ID)
	_test_rejections(encoded["payload"])
	quit(0)

func _synthetic_snapshot() -> Dictionary:
	return {
		"run_state": {
			"run_id": "run-snapshot-1",
			"well_id": "well_1",
			"hero_id": "hero_1",
			"module_id": "standard",
			"phase": 2,
			"paused": false,
			"simulation_elapsed": 23.5,
			"tank_base": 47.0,
			"extraction_rate": 2.0,
			"pressure_time_scale": 1.0,
			"completed_surges": 1,
			"multiplier": 1.25,
			"locked_payout": 58,
			"sealing_remaining": 1.1,
			"sealing_duration": 2.0,
			"hero_health": 72.0,
			"machine_integrity": 133.0,
			"machine_max_integrity": 150.0,
			"terminal_reason": "",
		},
		"actors": [
			{"id": "enemy-1", "kind": "pursuer", "position": [3.0, 0.0], "health": 9.0, "max_health": 20.0, "cooldown_remaining": 0.4, "windup_remaining": 0.0, "target_id": "hero", "dead": false, "component_state": {"damage_multiplier": 1.0, "attack_damage": 10.0}},
			{"id": "ranged-1", "kind": "ranged", "position": [-4.0, 1.0], "health": 17.0, "max_health": 25.0, "cooldown_remaining": 0.8, "windup_remaining": 0.3, "target_id": "hero", "dead": false, "component_state": {"damage_multiplier": 1.0, "attack_damage": 8.0, "locked_target_point": [0.0, 6.0]}, "attack_count": 2},
			{"id": "hero", "kind": "hero", "position": [0.0, 6.0], "health": 72.0, "max_health": 100.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {"last_facing": 1, "vertical_velocity": 0.0, "grounded": false, "support_id": "", "ignored_support_id": "", "drop_through_remaining": 0.0, "jump_buffer_remaining": 0.0, "coyote_remaining": 0.0}},
			{"id": "machine", "kind": "machine", "position": [0.0, 0.0], "health": 133.0, "max_health": 150.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}},
		],
		"projectiles": [
			{"id": "projectile-1", "kind": "hostile", "owner_id": "ranged-1", "target_id": "hero", "position": [-2.0, 1.0], "velocity": [8.0, 0.0], "damage": 8.0, "lifetime_remaining": 1.2, "hit_target": false},
		],
		"player_abilities": {
			"dash_cooldown_remaining": 3.2,
			"pulse_cooldown_remaining": 0.0,
			"dash_remaining": 0.1,
			"dash_direction": [1.0, 0.0],
			"dash_active": true,
			"ability_flash_remaining": 0.1,
		},
		"weapon_state": {"damage": 6.0, "spread_enabled": true, "attack_interval": 0.6, "shot_accumulator": 0.25},
		"spawner": {"spawn_timer": 0.7, "spawn_index": 11, "spawn_position": [10.0, 0.0], "config_id": "well-1-standard", "next_id": 12},
		"arena_config_id": ArenaLayoutScript.CONFIG_ID,
	}

func _test_rejections(payload: Dictionary) -> void:
	var invalid_target: Dictionary = payload.duplicate(true)
	invalid_target["projectiles"][0]["target_id"] = "missing-target"
	assert(not SnapshotScript.decode(invalid_target)["valid"])
	var invalid_phase: Dictionary = payload.duplicate(true)
	invalid_phase["run_state"]["phase"] = 0
	assert(not SnapshotScript.decode(invalid_phase)["valid"])
	var invalid_position: Dictionary = payload.duplicate(true)
	invalid_position["actors"][0]["position"][0] = INF
	assert(not SnapshotScript.decode(invalid_position)["valid"])
	var incompatible: Dictionary = payload.duplicate(true)
	incompatible["config_version"] = "future-config"
	assert(not SnapshotScript.decode(incompatible)["valid"])
	var invalid_owner: Dictionary = payload.duplicate(true)
	invalid_owner["projectiles"][0]["owner_id"] = "unknown-owner"
	assert(not SnapshotScript.decode(invalid_owner)["valid"])
