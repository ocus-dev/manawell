extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

const LIVE_PATH: String = "user://run_identity_credit.json"
const TEMP_PATH: String = "user://run_identity_credit.tmp"
const BACKUP_PATH: String = "user://run_identity_credit.bak"

func _init() -> void:
	_cleanup()
	_test_bounded_completion_metadata()
	_test_legacy_identity_migration()
	_test_arbitrary_legacy_id_rejects_active_snapshot()
	_cleanup()
	quit(0)

func _test_bounded_completion_metadata() -> void:
	var account: RefCounted = AccountStateScript.new()
	for index in 2000:
		var run_id: String = account.allocate_run_id()
		assert(account.complete_run({"phase": RunStateScript.Phase.SUCCESS, "run_id": run_id, "payout": 1}, run_id, "well_1", 0))
	assert(account.run_sequence == 2001)
	assert(account.committed_run_id == "run-2000")
	assert(account.credited_run_ids.is_empty())
	assert(account.to_save_payload()["credited_run_ids"].is_empty())
	assert(account.bank == 2000.0)
	assert(not account.complete_run({"phase": RunStateScript.Phase.SUCCESS, "run_id": "run-2000", "payout": 1}, "run-1999", "well_1", 0))
	assert(not account.complete_run({"phase": RunStateScript.Phase.FAILED, "run_id": "run-2001", "payout": 1}, "run-2001", "well_1", 0))

func _test_legacy_identity_migration() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.from_save_payload({"bank": 4.0, "credited_run_ids": ["run-3", "run-8"], "owned_upgrades": [], "unlocked_wells": ["well_1"], "commissioned_wells": [], "roster_heroes": ["hero_1"], "hero_assignments": {"hero_1": {"role": "active", "well_id": ""}}, "well_loadouts": {"well_1": "standard"}})
	assert(account.run_sequence == 9)
	assert(account.committed_run_id == "run-8")
	assert(account.legacy_identity_error.is_empty())

func _test_arbitrary_legacy_id_rejects_active_snapshot() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.from_save_payload({"bank": 4.0, "credited_run_ids": ["legacy-arbitrary-id"], "owned_upgrades": [], "unlocked_wells": ["well_1"], "commissioned_wells": [], "roster_heroes": ["hero_1"], "hero_assignments": {"hero_1": {"role": "active", "well_id": ""}}, "well_loadouts": {"well_1": "standard"}})
	assert(not account.legacy_identity_error.is_empty())
	assert(account.bank == 4.0)

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, "%s.recovery" % LIVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
