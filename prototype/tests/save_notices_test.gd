extends SceneTree

## Idle income for time the game was closed is credited on load, and save
## problems reach the notice box (with its Retry button).

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SpySaveStoreScript = preload("res://tests/spy_save_store.gd")

func _init() -> void:
	call_deferred("_run")

func _guarded_account() -> RefCounted:
	var account: RefCounted = AccountStateScript.new()
	account.bank = 100.0
	account.commissioned_wells = {"well_1": true}
	account.roster_heroes["hero_2"] = true
	account.hero_assignments = {
		"hero_1": {"role": "active", "well_id": ""},
		"hero_2": {"role": "guard", "well_id": "well_1"},
	}
	return account

func _controller(store: RefCounted) -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = true
	controller.save_store = store
	root.add_child(controller)
	return controller

func _run() -> void:
	# Time away: ten minutes closed with a guarded well.
	var store: RefCounted = SpySaveStoreScript.new(_guarded_account())
	store.loaded_production_utc_timestamp = Time.get_unix_time_from_system() - 600.0
	var controller := _controller(store)
	await process_frame
	assert(controller.account_state.bank > 100.0, "time away was not credited")
	assert(controller.offline_notice.contains("while you were away"))
	assert(is_zero_approx(controller.offline_pending_total))
	assert(store.save_count >= 1, "credited income was not saved")
	var notice = controller.encounter_hud.notice_host
	controller._update_hud()
	assert(notice.visible and notice.title_label.text == "WHILE AWAY")
	controller.queue_free()
	await process_frame

	# A new save (no timestamp) earns nothing for "time away".
	var fresh: RefCounted = SpySaveStoreScript.new(_guarded_account())
	controller = _controller(fresh)
	await process_frame
	assert(is_equal_approx(controller.account_state.bank, 100.0))
	assert(controller.offline_notice.is_empty())

	# A failed save shows SAVE ISSUE with Retry, and enables Settings > Retry save.
	fresh.fail_next_saves = 1
	assert(not controller._save_account())
	controller._update_hud()
	notice = controller.encounter_hud.notice_host
	assert(notice.visible and notice.title_label.text == "SAVE ISSUE")
	assert(notice.action_button.visible)
	notice.action_button.emit_signal("pressed")
	assert(not controller.session_persistence.has_pending_save(), "retry did not save")
	assert(not notice.visible or notice.title_label.text != "SAVE ISSUE")

	# Recovery messages from the save store are shown.
	fresh.recovery_message = "Save recovery: loaded the last-good backup."
	controller._update_hud()
	assert(notice.visible and notice.title_label.text == "RECOVERY")
	controller.queue_free()
	await process_frame
	print("PASS save notices: time-away income, save failure + retry, recovery")
	quit(0)
