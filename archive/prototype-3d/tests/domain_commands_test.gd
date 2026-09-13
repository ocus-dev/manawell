extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_id_commands_without_hud()
	quit(0)

func _test_id_commands_without_hud() -> void:
	var controller: Node = ControllerScript.new()
	controller.persistence_enabled = false
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_2"] = {"role": "reserve", "well_id": ""}
	controller.account_state.commissioned_wells["well_1"] = true
	controller.account_state.unlocked_wells["well_2"] = true
	assert(controller.select_well_by_id("well_2"))
	assert(controller.selected_well_id == "well_2")
	assert(not controller.select_well_by_id("well_unknown"))
	assert(controller.select_active_hero_by_id("hero_2"))
	assert(controller.account_state.get_active_hero_id() == "hero_2")
	assert(controller.assign_guard_by_id("hero_1", "well_1"))
	assert(controller.account_state.get_guard_for_well("well_1") == "hero_1")
	assert(controller.recall_guard_by_well_id("well_1"))
	assert(not controller.assign_guard_by_id("hero_unknown", "well_1"))
	assert(controller.select_loadout_by_id("standard") == false)
	controller.run_state.phase = RunStateScript.Phase.EXTRACTING
	var selected_well: String = controller.selected_well_id
	assert(not controller.select_well_by_id("well_1"))
	assert(controller.selected_well_id == selected_well)
	assert(not controller.select_active_hero_by_id("hero_1"))
	assert(controller.account_state.get_active_hero_id() == "hero_2")
	controller.free()
