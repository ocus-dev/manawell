extends SceneTree

const ObjectiveStateScript = preload("res://scripts/model/objective_state.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")

var failures := 0

func _init() -> void:
	_check_objective_progress_and_eligibility()
	_check_seeded_weighted_spawning()
	_check_retry_and_suspend_restore()
	_check_boss_and_extraction_boundaries()
	_check_failed_well_and_no_successor_launch()
	if failures == 0:
		print("PASS LD04 objective checks")
		quit(0)
	else:
		push_error("LD04 objective checks failed: %d" % failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("LD04: " + message)

func _kill_objective(required: int = 24) -> RefCounted:
	var state: RefCounted = ObjectiveStateScript.new()
	state.configure({"objective": "kill_count", "required_kills": required, "count_monsters": ["pursuer", "breaker"], "progress_scope": "run"}, {"interval_seconds": 1.0, "max_alive": 2, "pool": [{"monster_id": "pursuer", "weight": 3.0}, {"monster_id": "breaker", "weight": 1.0}]}, 17)
	return state

func _check_objective_progress_and_eligibility() -> void:
	var state := _kill_objective()
	for death_id in range(1, 24):
		_check(state.credit_death(death_id, "pursuer"), "eligible kill %d was rejected" % death_id)
	_check(state.progress == 23 and not state.completed, "23/24 completed too early")
	_check(not state.credit_death(1, "pursuer"), "duplicate death was credited")
	_check(not state.credit_death(200, "scenery"), "decorative death was credited")
	_check(not state.credit_death(201, "pursuer", false), "uncredited death was counted")
	_check(not state.credit_death(202, "pursuer", true, false), "summoned death was counted")
	_check(state.credit_death(24, "breaker"), "24th eligible kill was rejected")
	_check(state.completed and state.completion_count == 1, "quota did not complete exactly once")
	_check(not state.credit_death(25, "pursuer"), "post-quota kill changed completion")
	_check(state.completion_count == 1, "completion callback was repeated")
	var view: Dictionary = state.objective_view()
	_check(view.remaining == 0 and view.completed, "HUD view model did not expose terminal quota state")

func _check_seeded_weighted_spawning() -> void:
	var first := _kill_objective()
	var second := _kill_objective()
	var first_choices: Array[String] = []
	var second_choices: Array[String] = []
	for index in range(8):
		first_choices.append(first.advance_spawner(1.0, 0))
		second_choices.append(second.advance_spawner(1.0, 0))
	_check(first_choices == second_choices, "same objective seed produced different weighted spawns")
	_check(first_choices.any(func(value: String): return value == "pursuer"), "weighted pool never selected the first entry")
	_check(first_choices.any(func(value: String): return value == "breaker"), "weighted pool never selected the second entry")
	var skipped := _kill_objective()
	_check(skipped.advance_spawner(1.0, 2).is_empty(), "alive-cap skip queued a quota spawn")

func _check_retry_and_suspend_restore() -> void:
	var state := _kill_objective()
	state.credit_death(4, "pursuer")
	state.credit_death(7, "breaker")
	var snapshot: Dictionary = state.to_snapshot()
	var restored := _kill_objective()
	restored.restore_snapshot(snapshot)
	_check(restored.progress == 2 and restored.credited_ids.has(4) and restored.credited_ids.has(7), "suspend restore lost objective progress or IDs")
	state.reset_for_retry()
	_check(state.progress == 0 and state.credited_ids.is_empty() and not state.completed, "retry did not reset per-run objective state")

func _check_boss_and_extraction_boundaries() -> void:
	var boss: RefCounted = ObjectiveStateScript.new()
	boss.configure({"objective": "defeat_boss", "boss_spawn_id": "crown_guardian"})
	_check(not boss.credit_death(1, "pursuer"), "ordinary kill satisfied boss objective")
	_check(not boss.record_boss_defeat("other_boss"), "wrong boss satisfied boss objective")
	_check(boss.record_boss_defeat("crown_guardian"), "named boss did not satisfy boss objective")
	_check(boss.completion_count == 1, "boss objective completed more than once")
	var extraction: RefCounted = ObjectiveStateScript.new()
	extraction.configure({"objective": "extract", "minimum_completed_surges": 1})
	_check(not extraction.extraction_satisfied(0), "early extraction qualified as objective success")
	_check(extraction.extraction_satisfied(1), "completed surge did not qualify extraction objective")

func _check_failed_well_and_no_successor_launch() -> void:
	var account: RefCounted = AccountStateScript.new()
	var campaign: RefCounted = CampaignStateScript.new()
	var catalog: RefCounted = CampaignCatalogScript.new()
	campaign.active_act_id = "act_01"
	campaign.active_node_id = "act_01_node_02"
	var failed: bool = campaign.commit_terminal_result({"run_id": "ld04-failed", "phase": RunStateScript.Phase.FAILED, "payout": 0, "completed_surges": 0}, account, catalog)
	_check(not failed and not account.is_well_commissioned("well_1"), "failed seal commissioned a well")
	campaign.active_act_id = "act_01"
	campaign.active_node_id = "act_01_node_01"
	var success: bool = campaign.commit_terminal_result({"run_id": "ld04-success", "phase": RunStateScript.Phase.SUCCESS, "payout": 3, "completed_surges": 0}, account, catalog)
	_check(success and campaign.active_node_id.is_empty(), "successful node was not committed")
	_check(not campaign.active_node_id == "act_01_node_02", "success auto-launched a successor")
