extends SceneTree

func _init() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.commissioned_wells["well_1"] = true
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_1"] = {"role": "reserve", "well_id": ""}
	controller.account_state.hero_assignments["hero_2"] = {"role": "guard", "well_id": "well_1"}
	controller.production_time_override = 60.0
	controller.production.reset_cursor(0.0)
	controller._settle_production()
	assert(controller.account_state.bank >= 29.9 and controller.account_state.bank <= 30.2)
	var bank_before_active: float = controller.account_state.bank
	controller.run_state.start("network-run", "well_1", "hero_1", "standard", 2.0, 2.0)
	controller.production_time_override = 120.0
	controller.production.reset_cursor(60.0)
	controller._settle_production()
	assert(controller.account_state.bank - bank_before_active < 0.1)
	controller.free()
	quit(0)