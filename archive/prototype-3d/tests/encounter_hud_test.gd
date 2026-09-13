extends SceneTree

const EncounterHUDScript = preload("res://scripts/ui/encounter_hud.gd")

var received: Array = []

func _init() -> void:
	var hud: Node = EncounterHUDScript.new()
	hud.well_selected.connect(func(well_id: String): received.append(["well", well_id]))
	hud.loadout_selected.connect(func(loadout_id: String): received.append(["loadout", loadout_id]))
	hud.active_hero_selected.connect(func(hero_id: String): received.append(["hero", hero_id]))
	hud.guard_assigned.connect(func(hero_id: String, well_id: String): received.append(["assign", hero_id, well_id]))
	hud.set_view_state({"selected_well_id": "well_2", "selected_loadout_id": "fortified", "active_hero_id": "hero_2", "guard_id": "hero_1"})
	assert(hud.selected_well_id == "well_2")
	assert(hud.router == null)
	assert(hud.selected_loadout_id == "fortified")
	for frame in 120:
		hud.set_view_state(hud.view_state)
	assert(hud.selected_well_id == "well_2")
	hud.choose_well("well_2")
	hud.choose_loadout("fortified")
	hud.choose_active_hero("hero_2")
	hud.assign_guard("hero_1", "well_2")
	assert(received == [["well", "well_2"], ["loadout", "fortified"], ["hero", "hero_2"], ["assign", "hero_1", "well_2"]])
	hud.free()
	quit(0)
