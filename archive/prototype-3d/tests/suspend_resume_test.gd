extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")

const LIVE_PATH: String = "user://test_snapshot_save.json"
const TEMP_PATH: String = "user://test_snapshot_save.tmp"
const BACKUP_PATH: String = "user://test_snapshot_save.bak"

func _init() -> void:
	_cleanup()
	_test_suspend_restore_and_reward_clear()
	_test_malformed_snapshot_preserves_account()
	_cleanup()
	quit(0)

func _test_suspend_restore_and_reward_clear() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.run_state.start("resume-run", "well_1", "hero_1", "standard", 2.0, 2.0)
	controller.tick(3.0)
	controller.run_state.completed_surges = 2
	controller.spawn_index = 3
	controller._spawn_next_enemy()
	var ranged_snapshot: Dictionary = controller._capture_snapshot()
	assert(ranged_snapshot["actors"].any(func(actor): return actor["kind"] == "ranged"))
	controller.request_start_or_harvest()
	controller.tick(0.5)
	var snapshot: Dictionary = controller._capture_snapshot()
	assert(int(snapshot["run_state"]["phase"]) == 2)
	assert(is_equal_approx(float(snapshot["run_state"]["sealing_remaining"]), 1.5))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(controller.account_state, 100.0, snapshot))
	controller.save_store = store
	controller.persistence_enabled = true
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not controller.run_state.paused)
	var focus_checkpoint_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	focus_checkpoint_store.load_account()
	assert(not focus_checkpoint_store.loaded_snapshot.is_empty())
	var raw_file := FileAccess.open(LIVE_PATH, FileAccess.READ)
	var raw_payload = JSON.parse_string(raw_file.get_as_text())
	raw_file.close()
	assert(SnapshotScript.decode(raw_payload["snapshot"])["valid"])
	var loaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var loaded_account: RefCounted = loaded_store.load_account()
	assert(loaded_account.bank == 0.0)
	assert(not loaded_store.loaded_snapshot.is_empty())
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	restored.persistence_enabled = false
	get_root().add_child(restored)
	restored.save_store.loaded_snapshot = loaded_store.loaded_snapshot
	restored._restore_saved_snapshot()
	assert(restored.run_state.phase == 2)
	assert(restored.run_state.paused)
	assert(is_equal_approx(restored.run_state.sealing_remaining, 1.5))
	restored.tick(2.0)
	assert(restored.run_state.phase == 2)
	restored.toggle_pause()
	restored.tick(2.0)
	assert(restored.run_state.phase == 3)
	restored._credit_if_complete()
	assert(restored.account_state.bank == 6.0)
	assert(store.save_account(restored.account_state, 102.0))
	var completed_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	completed_store.load_account()
	assert(completed_store.loaded_snapshot.is_empty())
	controller.free()
	restored.free()

func _test_malformed_snapshot_preserves_account() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.bank = 42.5
	var file := FileAccess.open(LIVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "account": account.to_save_payload(), "production_timestamp": 100.0, "snapshot": {"snapshot_version": 999}}))
	file.close()
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var loaded: RefCounted = store.load_account()
	assert(is_equal_approx(loaded.bank, 42.5))
	assert(store.loaded_snapshot.is_empty())
	assert(store.recovery_message.contains("snapshot"))

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
