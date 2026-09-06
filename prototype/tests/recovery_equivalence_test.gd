extends SceneTree

const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const SpySaveStoreScript = preload("res://tests/spy_save_store.gd")
const RangedEnemyScript = preload("res://scripts/game/ranged_enemy.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

const LIVE_PATH: String = "user://recovery_equivalence.json"
const TEMP_PATH: String = "user://recovery_equivalence.tmp"
const BACKUP_PATH: String = "user://recovery_equivalence.bak"

func _init() -> void:
	_cleanup()
	_test_uninterrupted_and_resumed_paths_match()
	_test_failed_checkpoint_keeps_last_committed_snapshot()
	_cleanup()
	quit(0)

func _test_uninterrupted_and_resumed_paths_match() -> void:
	var uninterrupted: Node = _new_controller()
	var checkpointed: Node = _new_controller()
	for controller in [uninterrupted, checkpointed]:
		controller.account_state.owned_upgrades["damage_1"] = true
		controller.account_state.owned_upgrades["spread_1"] = true
		controller.sealing_duration_setting = 2.0
		controller.request_start_or_harvest()
		controller.get_node("Hero").position = Vector3(2.0, 0.0, 2.0)
		controller.request_start_or_harvest()
		controller._spawn_ranged_enemy(controller, Vector3(10.0, 0.0, 2.0), 1.25)
		var ranged: Node = controller.enemies.back()
		ranged._fire()
		ranged._fire()
		controller.auto_weapon._fire(ranged)
		controller.auto_weapon.shot_accumulator = 0.25
	assert(uninterrupted.run_state.phase == RunStateScript.Phase.SEALING)
	var checkpoint: Dictionary = checkpointed._capture_snapshot()
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(checkpointed.account_state, 100.0, checkpoint))
	var loaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	loaded_store.load_account()
	var resumed: Node = _new_controller()
	resumed.save_store.loaded_snapshot = loaded_store.loaded_snapshot
	resumed._restore_saved_snapshot()
	assert(resumed.run_state.paused)
	assert(resumed.assignment_notice.contains("restored"))
	resumed.toggle_pause()
	for controller in [uninterrupted, resumed]:
		controller.tick(0.5)
	_assert_equivalent(uninterrupted, resumed)
	for controller in [uninterrupted, resumed]:
		controller.tick(2.0)
		controller._credit_if_complete()
	assert(uninterrupted.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(resumed.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(is_equal_approx(uninterrupted.account_state.bank, resumed.account_state.bank))
	var uninterrupted_bank: float = uninterrupted.account_state.bank
	uninterrupted._credit_if_complete()
	resumed._credit_if_complete()
	assert(is_equal_approx(uninterrupted.account_state.bank, uninterrupted_bank))
	assert(is_equal_approx(resumed.account_state.bank, uninterrupted_bank))
	uninterrupted.free()
	checkpointed.free()
	resumed.free()

func _test_failed_checkpoint_keeps_last_committed_snapshot() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	var spy: RefCounted = SpySaveStoreScript.new(controller.account_state)
	controller.persistence_enabled = true
	controller.configure_persistence(spy)
	get_root().add_child(controller)
	controller.request_start_or_harvest()
	controller.run_state.request_harvest()
	var committed: Dictionary = controller._capture_snapshot()
	assert(controller.session_persistence.save(committed))
	controller.run_state.sealing_remaining = 0.25
	var pending: Dictionary = controller._capture_snapshot()
	spy.fail_next_saves = 1
	assert(not controller.session_persistence.save(pending))
	assert(controller.session_persistence.has_pending_save())
	var saved_snapshot: Dictionary = spy.saved_envelopes[0]["snapshot"]
	assert(is_equal_approx(saved_snapshot["run_state"]["sealing_remaining"], committed["run_state"]["sealing_remaining"]))
	controller.free()

func _assert_equivalent(left: Node, right: Node) -> void:
	assert(left.run_state.phase == right.run_state.phase)
	assert(is_equal_approx(left.run_state.hero_health, right.run_state.hero_health))
	assert(is_equal_approx(left.run_state.machine_integrity, right.run_state.machine_integrity))
	assert(is_equal_approx(left.run_state.sealing_remaining, right.run_state.sealing_remaining))
	var left_encoded: Dictionary = SnapshotScript.encode(left._capture_snapshot())
	var right_encoded: Dictionary = SnapshotScript.encode(right._capture_snapshot())
	assert(left_encoded["valid"], str(left_encoded.get("error", "")))
	assert(right_encoded["valid"], str(right_encoded.get("error", "")))
	var left_snapshot: Dictionary = left_encoded["payload"]
	var right_snapshot: Dictionary = right_encoded["payload"]
	assert(left_snapshot["actors"].map(func(actor): return actor["id"]) == right_snapshot["actors"].map(func(actor): return actor["id"]))
	assert(left_snapshot["projectiles"].size() == right_snapshot["projectiles"].size())
	for index in left_snapshot["projectiles"].size():
		var left_projectile: Dictionary = left_snapshot["projectiles"][index]
		var right_projectile: Dictionary = right_snapshot["projectiles"][index]
		assert(left_projectile["id"] == right_projectile["id"])
		assert(left_projectile["kind"] == right_projectile["kind"])
		assert(is_equal_approx(left_projectile["position"][0], right_projectile["position"][0]))
		assert(is_equal_approx(left_projectile["position"][2], right_projectile["position"][2]))
		assert(is_equal_approx(left_projectile["lifetime_remaining"], right_projectile["lifetime_remaining"]))

func _new_controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	return controller

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
