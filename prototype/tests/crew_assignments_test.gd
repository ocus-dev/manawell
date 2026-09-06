extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")

const LIVE_PATH: String = "user://test_assignments_save.json"
const TEMP_PATH: String = "user://test_assignments_save.tmp"
const BACKUP_PATH: String = "user://test_assignments_save.bak"

func _init() -> void:
	_cleanup()
	_test_assignment_rules()
	_test_start_releases_guard()
	_cleanup()
	quit(0)

func _test_assignment_rules() -> void:
	var account: RefCounted = AccountStateScript.new()
	assert(not account.has_hero("hero_2"))
	assert(not account.assign_guard("hero_2", "well_1"))
	assert(not account.select_active_hero("hero_2"))
	account.roster_heroes["hero_2"] = true
	account.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	assert(not account.assign_guard("hero_1", "well_1"))
	account.commissioned_wells["well_1"] = true
	assert(account.assign_guard("hero_2", "well_1"))
	assert(not account.assign_guard("hero_1", "well_1"))
	assert(not account.select_active_hero("hero_2"))
	assert(account.recall_guard("well_1"))
	assert(account.get_hero_role("hero_2") == "reserve")
	assert(account.select_active_hero("hero_2"))
	assert(account.get_hero_role("hero_1") == "reserve")
	assert(account.assign_guard("hero_1", "well_1"))
	assert(not account.assign_guard("hero_2", "well_1"))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(account))
	var restarted: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(restarted.get_active_hero_id() == "hero_2")
	assert(restarted.get_guard_for_well("well_1") == "hero_1")
	assert(restarted.get_hero_role("hero_1") == "guard")

func _test_start_releases_guard() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	controller.account_state.commissioned_wells["well_1"] = true
	assert(controller.account_state.assign_guard("hero_2", "well_1"))
	controller.request_start_or_harvest()
	assert(controller.run_state.phase == 1)
	assert(controller.run_state.selected_hero_id == "hero_1")
	assert(controller.account_state.get_guard_for_well("well_1").is_empty())
	assert(controller.account_state.get_hero_role("hero_2") == "reserve")
	assert(controller.assignment_notice.contains("released"))
	assert(controller.get_node("Hero/Mesh").mesh is CapsuleMesh)
	controller.free()

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
