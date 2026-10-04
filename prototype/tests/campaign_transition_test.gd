extends SceneTree

const BalanceData = preload("res://data/balance.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var operations: Control = controller.encounter_hud.operations
	var campaign: Dictionary = controller.encounter_hud.view_state["campaign"]
	assert(campaign["briefing_node"]["id"] == "act_01_node_02", "a new profile is briefed on the tutorial")
	operations.start_requested.emit()
	assert(controller.tutorial_mode, "Start opens the tutorial")
	assert(controller.campaign_state.active_node_id == "act_01_node_02")
	assert(controller.run_state.phase == controller.run_state.Phase.EXTRACTING)
	# Clearing a level means reaching its progress surge and killing the boss.
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	var gate: int = int(controller.spawn_profile.get("progress_surge", 0))
	while controller.run_state.completed_surges < gate:
		controller.run_state.advance(1.0)
	controller.simulate_step(1.0 / 60.0)
	if gate > 0:
		assert(controller.boss_enemy != null, "boss spawned at surge %d" % gate)
		controller.boss_enemy.take_damage(controller.boss_enemy.health)
		controller.simulate_step(1.0 / 60.0)
	controller.run_state.request_harvest()
	controller.run_state.advance(BalanceData.SEALING_DURATION)
	controller._credit_if_complete()
	controller._update_hud()
	assert(controller.campaign_state.node_status("act_01", "act_01_node_02")["status"] == "completed")
	assert(controller.encounter_hud.view_state["campaign"]["briefing_node"]["id"] == "act_01_node_01", "next up: Scrap Approach")
	controller.return_to_operations()
	operations._show_page("map")
	assert(operations.campaign_map.select_node("act_01_node_01"))
	operations.campaign_map.activate_button.emit_signal("pressed")
	assert(controller.campaign_state.active_node_id == "act_01_node_01")
	assert(not controller.tutorial_mode)
	assert(controller.run_state.phase == controller.run_state.Phase.EXTRACTING)
	controller.queue_free()
	print("Campaign transition checks passed")
	quit(0)