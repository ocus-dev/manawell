extends SceneTree

const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

const LIVE_PATH := "user://campaign-state-test.json"
const TEMP_PATH := "user://campaign-state-test.tmp"
const BACKUP_PATH := "user://campaign-state-test.bak"

func _init() -> void:
	_cleanup()
	var catalog: RefCounted = CampaignCatalogScript.new()
	assert(catalog.is_valid())
	var act: Dictionary = catalog.get_act("act_01")
	assert(act["nodes"].size() == 9)
	assert(_count_type(act, "well") == 3)
	assert(_count_type(act, "monster") == 5)
	assert(_count_type(act, "boss") == 1)
	var campaign: RefCounted = CampaignStateScript.new()
	assert(campaign.node_status("act_01", "act_01_node_01", catalog)["status"] == CampaignStateScript.STATUS_AVAILABLE)
	assert(campaign.node_status("act_01", "act_01_node_02", catalog)["status"] == CampaignStateScript.STATUS_LOCKED)
	assert(campaign.furthest_progression_node(catalog)["id"] == "act_01_node_01", "Fresh progress briefs the first campaign node")
	assert(campaign.start_node("act_01", "act_01_node_01", catalog))
	var account: RefCounted = AccountStateScript.new()
	var result := {"run_id": "campaign-run-1", "phase": RunStateScript.Phase.SUCCESS, "payout": 3, "completed_surges": 0}
	assert(campaign.commit_terminal_result(result, account, catalog))
	assert(campaign.node_status("act_01", "act_01_node_01", catalog)["status"] == CampaignStateScript.STATUS_COMPLETED)
	assert(campaign.furthest_progression_node(catalog)["id"] == "act_01_node_02", "Operations advances to the newly available node")
	assert(not campaign.commit_terminal_result(result, account, catalog))
	assert(campaign.start_node("act_01", "act_01_node_02", catalog))
	result = {"run_id": "campaign-run-2", "phase": RunStateScript.Phase.SUCCESS, "payout": 3, "completed_surges": 1}
	assert(campaign.commit_terminal_result(result, account, catalog))
	assert(account.is_well_commissioned("well_1"))
	assert(account.is_well_unlocked("well_2"))
	assert(campaign.furthest_progression_node(catalog)["id"] == "act_01_node_03", "Operations follows the next stage after the well")
	assert(not account.is_well_unlocked("well_3"))
	account.commissioned_wells["well_2"] = true
	account.unlocked_wells["well_3"] = true
	assert(account.content_catalog.has_well("well_3"))
	for node in act["nodes"]:
		if node["id"] != "act_01_node_09":
			campaign.completed_nodes["act_01/%s" % node["id"]] = true
	assert(campaign.start_node("act_01", "act_01_node_09", catalog))
	result = {"run_id": "campaign-boss-1", "phase": RunStateScript.Phase.SUCCESS, "payout": 5, "completed_surges": 2}
	assert(campaign.commit_terminal_result(result, account, catalog))
	assert(campaign.unlocked_acts.has("act_01"))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	var envelope := {"account": account, "campaign_state": campaign.to_save_payload()}
	assert(store.save_envelope(envelope))
	var loaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	loaded_store.load_account()
	var restored: RefCounted = CampaignStateScript.new()
	assert(restored.from_save_payload(loaded_store.loaded_campaign_state, catalog))
	assert(restored.completed_nodes.has("act_01/act_01_node_09"))
	var invalid: Dictionary = campaign.to_save_payload()
	invalid["completed_nodes"].append("act_01/missing")
	assert(not CampaignStateScript.validate_save_payload(invalid, catalog)["valid"])
	_cleanup()
	print("Campaign state checks passed")
	quit(0)

func _count_type(act: Dictionary, node_type: String) -> int:
	var count := 0
	for node in act["nodes"]:
		if node["type"] == node_type:
			count += 1
	return count

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, LIVE_PATH + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
