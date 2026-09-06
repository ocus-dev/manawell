extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")

func _init() -> void:
	_test_rejects_malformed_sections_and_references()
	_test_ids_survive_prune_and_restore()
	quit(0)

func _base_snapshot() -> Dictionary:
	return {
		"run_state": {"run_id": "run-1", "well_id": "well_1", "hero_id": "hero_1", "module_id": "standard", "phase": 2, "paused": false, "simulation_elapsed": 1.0, "tank_base": 2.0, "extraction_rate": 2.0, "completed_surges": 0, "multiplier": 1.0, "locked_payout": 0, "sealing_remaining": 1.0, "sealing_duration": 2.0, "hero_health": 100.0, "machine_integrity": 150.0, "terminal_reason": ""},
		"actors": [
			{"id": "hero", "kind": "hero", "position": [0.0, 1.0, 6.0], "health": 100.0, "max_health": 100.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}},
			{"id": "machine", "kind": "machine", "position": [0.0, 0.7, 0.0], "health": 150.0, "max_health": 150.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}},
		],
		"projectiles": [],
		"player_abilities": {"dash_cooldown_remaining": 0.0, "pulse_cooldown_remaining": 0.0, "dash_remaining": 0.0, "dash_direction": [0.0, 0.0, 0.0], "dash_active": false, "ability_flash_remaining": 0.0},
		"weapon_state": {"damage": 6.0, "spread_enabled": false, "attack_interval": 0.6, "shot_accumulator": 0.0},
		"spawner": {"spawn_timer": 0.0, "spawn_index": 0, "spawn_position": [0.0, 0.8, -10.0], "config_id": "well_1-standard", "next_id": 1},
	}

func _test_rejects_malformed_sections_and_references() -> void:
	var encoded: Dictionary = SnapshotScript.encode(_base_snapshot())
	assert(encoded["valid"])
	var malformed_section: Dictionary = encoded["payload"].duplicate(true)
	malformed_section["run_state"] = 42
	var malformed_result: Dictionary = SnapshotScript.decode(malformed_section)
	assert(not malformed_result["valid"])
	var invalid_kind: Dictionary = encoded["payload"].duplicate(true)
	invalid_kind["actors"][0]["kind"] = "unknown"
	assert(not SnapshotScript.decode(invalid_kind)["valid"])
	var invalid_boolean: Dictionary = encoded["payload"].duplicate(true)
	invalid_boolean["player_abilities"]["dash_active"] = "false"
	assert(not SnapshotScript.decode(invalid_boolean)["valid"])
	var duplicate_machine: Dictionary = encoded["payload"].duplicate(true)
	duplicate_machine["actors"].append(duplicate_machine["actors"][1].duplicate(true))
	duplicate_machine["actors"][2]["id"] = "machine-copy"
	assert(not SnapshotScript.decode(duplicate_machine)["valid"])
	var invalid_reference: Dictionary = encoded["payload"].duplicate(true)
	invalid_reference["projectiles"].append({"id": "entity-99", "owner_id": "missing", "target_id": "hero", "position": [0.0, 0.0, 0.0], "velocity": [0.0, 0.0, 0.0], "damage": 1.0, "lifetime_remaining": 1.0, "hit_target": false})
	assert(not SnapshotScript.decode(invalid_reference)["valid"])
	var unsupported: Dictionary = encoded["payload"].duplicate(true)
	unsupported["snapshot_version"] = 99
	var unsupported_result: Dictionary = SnapshotScript.decode(unsupported)
	assert(not unsupported_result["valid"])
	assert(unsupported_result["error"].contains("unsupported"))

func _test_ids_survive_prune_and_restore() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.request_start_or_harvest()
	controller._spawn_next_enemy()
	controller._spawn_next_enemy()
	var first_id: String = controller.enemies[0].get_meta("snapshot_id")
	var second_id: String = controller.enemies[1].get_meta("snapshot_id")
	assert(first_id != second_id)
	controller.enemies[0].die()
	controller._prune_enemies()
	controller._spawn_next_enemy()
	var third_id: String = controller.enemies[1].get_meta("snapshot_id")
	assert(third_id != first_id and third_id != second_id)
	var payload: Dictionary = SnapshotScript.encode(controller._capture_snapshot())["payload"]
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	restored.persistence_enabled = false
	get_root().add_child(restored)
	restored.save_store.loaded_snapshot = payload
	restored._restore_saved_snapshot()
	var restored_ids: Dictionary = {}
	for enemy in restored.enemies:
		var restored_id: String = enemy.get_meta("snapshot_id")
		assert(not restored_ids.has(restored_id))
		restored_ids[restored_id] = true
	assert(restored.next_snapshot_id == controller.next_snapshot_id)
	restored._spawn_next_enemy()
	var after_restore_id: String = restored.enemies.back().get_meta("snapshot_id")
	assert(not restored_ids.has(after_restore_id))
	controller.free()
	restored.free()
