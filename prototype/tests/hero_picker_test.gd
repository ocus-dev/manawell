extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const FixtureScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const PickerScript = preload("res://scripts/ui/hero_picker.gd")

var selected_ids: Array[String] = []
var recalled_wells: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var picker = PickerScript.new()
	root.add_child(picker)
	picker.hero_selected.connect(func(hero_id: String, _mode: String, _well_id: String): selected_ids.append(hero_id))
	picker.guard_recall_requested.connect(func(well_id: String): recalled_wells.append(well_id))
	var fixture: Dictionary = FixtureScript.make("one_well_commissioned")
	var well_data: Dictionary = fixture.view_state.operations.wells[0]
	picker.open_guard(well_data, fixture.view_state.operations.heroes)
	assert(TestCheckScript.check(picker.visible, "guard picker opens"))
	assert(TestCheckScript.check(picker.action_buttons["hero_1"].disabled, "active hero cannot become guard"))
	assert(TestCheckScript.check(picker.action_buttons["hero_2"].text == "Recall", "current guard offers explicit recall"))
	picker.recall_current_guard()
	assert(TestCheckScript.check(recalled_wells == ["well_1"], "recall emits the requested well ID"))
	var recalled_well := well_data.duplicate(true)
	recalled_well["guard"] = {"id": "", "label": "Assign guard", "assigned": false, "role_label": "Unstaffed"}
	var recalled_heroes: Array[Dictionary] = fixture.view_state.operations.heroes.duplicate(true)
	recalled_heroes[1]["role_id"] = "reserve"
	recalled_heroes[1]["role_label"] = "Reserve"
	recalled_heroes[1]["available_for_guard"] = true
	picker.refresh_guard_state(recalled_well, recalled_heroes)
	assert(TestCheckScript.check(picker.action_buttons["hero_2"].text == "Assign", "recall updates the open picker"))
	picker.select_hero("hero_2")
	assert(TestCheckScript.check(selected_ids == ["hero_2"], "reserve selection emits the hero ID"))
	assert(TestCheckScript.check(picker.visible, "selection waits for authoritative result"))
	var assigned_well := recalled_well.duplicate(true)
	assigned_well["guard"] = {"id": "hero_2", "label": "Hero 2", "assigned": true, "role_label": "Guard"}
	picker.refresh_guard_state(assigned_well, recalled_heroes)
	assert(TestCheckScript.check(not picker.visible, "successful assignment closes the picker"))

	var no_reserve: Dictionary = FixtureScript.make("no_reserve_hero")
	var no_reserve_well: Dictionary = no_reserve.view_state.operations.wells[0]
	picker.open_guard(no_reserve_well, no_reserve.view_state.operations.heroes)
	assert(TestCheckScript.check(picker.empty_label.text.begins_with("No reserve heroes"), "no-reserve state explains the next action"))
	picker.close_picker()
	assert(TestCheckScript.check(selected_ids == ["hero_2"], "cancel does not select a hero"))

	var heroes: Array[Dictionary] = [
		{"id": "hero_1", "label": "Hero 1", "role_id": "active", "role_label": "Expedition hero", "availability_reason": "Expedition hero", "available_for_guard": false},
		{"id": "hero_2", "label": "Hero 2", "role_id": "reserve", "role_label": "Reserve", "availability_reason": "Available to assign.", "available_for_guard": true},
		{"id": "hero_3", "label": "Hero 3", "role_id": "guard", "role_label": "Guard", "availability_reason": "Guarding Well 2 - recall there first.", "available_for_guard": false},
	]
	picker.open_expedition(heroes, "hero_1")
	assert(TestCheckScript.check(not picker.action_buttons["hero_1"].disabled, "current expedition hero remains selectable"))
	assert(TestCheckScript.check(not picker.action_buttons["hero_2"].disabled, "reserve hero is selectable for expedition"))
	assert(TestCheckScript.check(picker.action_buttons["hero_3"].disabled, "guarded hero is unavailable for expedition"))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	picker._input(escape)
	assert(TestCheckScript.check(not picker.visible, "Escape closes the topmost picker"))
	print("hero_picker: guard+expedition availability=verified recall_in_place=verified modal_keys=verified")
	quit(0)