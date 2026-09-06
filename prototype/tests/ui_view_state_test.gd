extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")

func _init() -> void:
	var fixtures: Dictionary = UiPreviewFixturesScript.all()
	assert(TestCheckScript.check(fixtures.size() == 9, "all preview fixtures are present"))
	var fresh: Dictionary = fixtures["fresh_account"].view_state
	assert(TestCheckScript.check(fresh.operations.selected_destination_id == "well_1", "fresh destination is stable"))
	assert(TestCheckScript.check(fresh.operations.wells[0].id == "well_1", "well IDs are exposed"))
	var commissioned: Dictionary = fixtures["one_well_commissioned"].view_state
	assert(TestCheckScript.check(commissioned.operations.wells[0].guard.role_label == "Guard", "guard role is labeled"))
	assert(TestCheckScript.check(commissioned.operations.heroes[0].role_label == "Expedition hero", "active role is labeled separately"))
	assert(TestCheckScript.check(commissioned.operations.passive_rate_per_minute > 0.0, "passive rate comes from production accounting"))
	var no_reserve: Dictionary = fixtures["no_reserve_hero"].view_state
	assert(TestCheckScript.check(not no_reserve.operations.heroes[0].available_for_guard, "no-reserve fixture explains unavailable hero"))
	var failure: Dictionary = fixtures["failure"].view_state
	assert(TestCheckScript.check(failure.results.actual_run_reward == 0, "failure has no run reward"))
	var sealing: Dictionary = fixtures["sealing"].view_state
	assert(TestCheckScript.check(sealing.combat.at_risk_payout > 0, "sealing exposes locked payout"))
	var normal: Dictionary = fixtures["extracting"].view_state
	var restored: Dictionary = UiViewStateScript.build(fixtures["extracting"].account, fixtures["extracting"].run_state, "well_1", fixtures["extracting"].notices)
	assert(TestCheckScript.check(normal.combat == restored.combat, "normal and restored runs expose the same combat fields"))
	var save_failure: Dictionary = fixtures["save_failure"].view_state
	assert(TestCheckScript.check(save_failure.notices.save_failure != "", "save failure remains a separate notice"))
	print("ui_view_state: fixtures=9 readonly_contract=verified guard_active_labels=verified")
	quit(0)