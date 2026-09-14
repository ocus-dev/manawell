extends SceneTree

const AccountScript = preload("res://scripts/model/account_state.gd")
const GeneratorScript = preload("res://scripts/model/loot_generator.gd")
const RunSnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")

const LIVE_PATH := "user://ld06-persistence.json"
const TEMP_PATH := "user://ld06-persistence.tmp"
const BACKUP_PATH := "user://ld06-persistence.bak"

func _init() -> void:
	_cleanup()
	_test_frozen_snapshot_round_trip()
	_test_disk_pending_reward_reload()
	_cleanup()
	print("PASS LD06 persistence: frozen definitions, RNG/objective/reward state, safe rejection, and pending reload")
	quit(0)

func _test_frozen_snapshot_round_trip() -> void:
	var definition := {"id": "fixture-level", "content_revision": 3, "nested": {"b": 2, "a": 1}}
	var snapshot := _snapshot(definition)
	var encoded: Dictionary = RunSnapshotScript.encode(snapshot)
	assert(encoded.valid, str(encoded.get("error", "")))
	var decoded: Dictionary = RunSnapshotScript.decode(encoded.payload)
	assert(decoded.valid, str(decoded.get("error", "")))
	assert(decoded.snapshot.level_definition == definition)
	assert(decoded.snapshot.level_content_hash == RunSnapshotScript.content_hash_for(definition))
	assert(int(decoded.snapshot.spawner.rng_state) == 987654)
	assert(decoded.snapshot.objective.credited_ids == ["enemy-7", "enemy-9"])
	assert(decoded.snapshot.reward_state.claim_receipts == ["reward.receipt.1"])
	assert(decoded.snapshot.reward_state.pending_items[0].instance_id == "reward:fixture:0")

	var corrupt_hash: Dictionary = encoded.payload.duplicate(true)
	corrupt_hash.level_content_hash = "0".repeat(64)
	assert(not RunSnapshotScript.decode(corrupt_hash).valid)
	var legacy: Dictionary = encoded.payload.duplicate(true)
	legacy.snapshot_version = 4
	assert(not RunSnapshotScript.decode(legacy).valid)

func _test_disk_pending_reward_reload() -> void:
	var account := AccountScript.new()
	for index in AccountScript.INVENTORY_CAPACITY:
		var filler_id := "filler-%03d" % index
		var filler := GeneratorScript.generate_guaranteed({"reward_id": filler_id, "instance_id": "reward:%s:0" % filler_id, "base_id": "core.accelerator", "rarity": "common", "item_level": 1, "run_id": "ld06-filler", "node_id": "fixture"}, GeneratorScript.seed_for(filler_id))
		assert(filler.valid)
		assert(account.add_campaign_instance(filler.instance))
	var level := {"rewards": {"guaranteed_items": [{"reward_id": "ld06.first_clear", "trigger": "first_clear", "base_id": "module.bracing", "item_level": 2, "rarity": "rare", "quantity": 1}]}}
	var result := {"run_id": "ld06-terminal", "phase": RunStateScript.Phase.SUCCESS, "payout": 0, "completed_surges": 0}
	assert(account.complete_campaign_run(result, result.run_id, "fixture", level))
	assert(account.pending_rewards.size() == 1)
	var snapshot := _snapshot({})
	var store := SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account, 100.0, snapshot))
	var loaded_store := SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var loaded: RefCounted = loaded_store.load_account()
	assert(loaded_store.loaded_snapshot.reward_state.pending_items.size() == 1)
	assert(loaded.pending_rewards.size() == 1)
	assert(loaded.reward_entitlements["ld06.first_clear"].item_ids.size() == 1)
	assert(loaded.reward_entitlements["ld06.first_clear"].delivered_item_ids.is_empty())

func _snapshot(definition: Dictionary) -> Dictionary:
	return {
		"run_state": {"run_id": "ld06-run", "well_id": "well_1", "hero_id": "hero_1", "module_id": "standard", "phase": RunStateScript.Phase.EXTRACTING, "paused": true, "simulation_elapsed": 2.0, "tank_base": 3.0, "extraction_rate": 1.0, "pressure_time_scale": 1.0, "completed_surges": 0, "multiplier": 1.0, "locked_payout": 0, "sealing_remaining": 0.0, "sealing_duration": 2.0, "hero_health": 100.0, "machine_integrity": 150.0, "machine_max_integrity": 150.0, "terminal_reason": ""},
		"actors": [{"id": "hero", "kind": "hero", "position": [320.0, 500.0], "health": 100.0, "max_health": 100.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {"last_facing": 1, "vertical_velocity": 0.0, "grounded": false, "support_id": "", "ignored_support_id": "", "drop_through_remaining": 0.0, "jump_buffer_remaining": 0.0, "coyote_remaining": 0.0}}, {"id": "machine", "kind": "machine", "position": [640.0, 540.0], "health": 150.0, "max_health": 150.0, "cooldown_remaining": 0.0, "windup_remaining": 0.0, "target_id": "", "dead": false, "component_state": {}}],
		"projectiles": [],
		"player_abilities": {"dash_cooldown_remaining": 0.0, "pulse_cooldown_remaining": 0.0, "dash_remaining": 0.0, "dash_direction": [1.0, 0.0], "dash_active": false, "ability_flash_remaining": 0.0},
		"weapon_state": {"damage": 10.0, "spread_enabled": false, "attack_interval": 0.6, "shot_accumulator": 0.0},
		"spawner": {"spawn_timer": 0.25, "spawn_index": 2, "spawn_position": [40.0, 540.0], "config_id": "well_1-standard", "next_id": 8, "rng_state": 987654},
		"arena_config_id": ArenaLayoutScript.CONFIG_ID,
		"level_definition": definition,
		"level_content_hash": "" if definition.is_empty() else RunSnapshotScript.content_hash_for(definition),
		"campaign": {"act_id": "act_01", "node_id": "fixture", "config_id": "well_1-standard", "wave_index": 2, "boss_timer": 0.0},
		"objective": {"objective_id": "kill_count", "progress": 2, "required": 5, "credited_ids": ["enemy-7", "enemy-9"]},
		"reward_state": {"claim_receipts": ["reward.receipt.1"], "pending_items": [{"instance_id": "reward:fixture:0"}]},
	}

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, LIVE_PATH + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
