class_name UiPreviewFixtures
extends RefCounted

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")

static func all() -> Dictionary:
	var fixtures: Dictionary = {}
	for fixture_id in ["fresh_account", "one_well_commissioned", "both_commissioned", "no_reserve_hero", "extracting", "sealing", "failure", "paused_recovery", "save_failure"]:
		fixtures[fixture_id] = make(fixture_id)
	return fixtures

static func make(fixture_id: String) -> Dictionary:
	var account: RefCounted = _account_for(fixture_id)
	var run_state: RefCounted = RunStateScript.new()
	var notices: Dictionary = {}
	if fixture_id in ["extracting", "sealing", "failure", "paused_recovery"]:
		run_state.start("preview-run", "well_1", account.get_active_hero_id(), "standard")
		run_state.advance(8.0)
	if fixture_id == "sealing":
		run_state.request_harvest()
	elif fixture_id == "failure":
		run_state.apply_damage(RunStateScript.DamageTarget.HERO, 999.0)
	elif fixture_id == "paused_recovery":
		run_state.set_paused(true)
		notices["recovery"] = "Recovered at your last checkpoint."
	if fixture_id == "save_failure":
		notices["save_failure"] = "Save failed; retry save before leaving."
	var selected_well_id: String = "well_1"
	return {"account": account, "run_state": run_state, "selected_well_id": selected_well_id, "notices": notices, "view_state": UiViewStateScript.build(account, run_state, selected_well_id, notices)}

static func _account_for(fixture_id: String) -> RefCounted:
	var account: RefCounted = AccountStateScript.new()
	if fixture_id == "fresh_account":
		return account
	var payload: Dictionary = {
		"bank": 48.0,
		"credited_run_ids": [],
		"owned_upgrades": [],
		"unlocked_wells": ["well_1", "well_2"],
		"commissioned_wells": ["well_1"],
		"roster_heroes": ["hero_1", "hero_2"],
		"hero_assignments": {
			"hero_1": {"role": "active", "well_id": ""},
			"hero_2": {"role": "guard", "well_id": "well_1"},
		},
		"well_loadouts": {"well_1": "standard", "well_2": "standard"},
	}
	if fixture_id == "both_commissioned":
		payload["commissioned_wells"] = ["well_1", "well_2"]
	if fixture_id == "no_reserve_hero":
		payload["roster_heroes"] = ["hero_1"]
		payload["hero_assignments"] = {"hero_1": {"role": "active", "well_id": ""}}
	account.from_save_payload(payload)
	return account