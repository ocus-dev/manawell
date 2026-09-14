extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var controller = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var operations = controller.encounter_hud.operations
	var briefing = operations.mission_briefing
	assert(briefing != null, "Operations exposes a mission briefing")
	assert(briefing.get_node("MissionBriefingContent/EnvironmentThumbnail").texture != null, "Briefing includes the environment thumbnail")
	assert(briefing.get_node("MissionBriefingContent/EnvironmentName").text == "SCRAP APPROACH", "Briefing uses the current campaign stage name")
	assert(briefing.get_node("MissionBriefingContent/Objective").text.contains("Clear every hostile wave"), "Briefing states the campaign objective")
	var monster_buttons: Dictionary = {}
	for monster_id in ["pursuer", "breaker", "ranged"]:
		monster_buttons[monster_id] = briefing.get_node("MissionBriefingContent/MonsterPortraits/Monster_%s" % monster_id)
	assert(monster_buttons.size() == 3, "Briefing exposes all known monster portraits")
	assert(operations.destination_picker == null, "The old destination dropdown is removed")
	var pursuer_flavor: String = briefing.get_node("MissionBriefingContent/MonsterDossier/MonsterDossierContent/MonsterFlavor").text
	monster_buttons["breaker"].emit_signal("pressed")
	assert(briefing.get_node("MissionBriefingContent/MonsterDossier/MonsterDossierContent/MonsterName").text == "BREAKER", "Monster portrait selection updates the dossier")
	assert(briefing.get_node("MissionBriefingContent/MonsterDossier/MonsterDossierContent/MonsterFlavor").text != pursuer_flavor, "Monster selection shows distinct flavor text")
	assert(operations.expedition_panel.start_button.custom_minimum_size.y <= 36.0, "Start extraction remains compact")
	for button in operations.expedition_panel.loadout_buttons.values():
		assert(button.custom_minimum_size.y <= 54.0, "Loadout choices remain compact")
	controller.campaign_state.completed_nodes["act_01/act_01_node_01"] = true
	controller._update_hud()
	await process_frame
	assert(briefing.get_node("MissionBriefingContent/EnvironmentName").text == "INTAKE WELL", "Briefing follows the newly available well")
	assert(briefing.get_node("MissionBriefingContent/Objective").text.contains("Stabilize Intake Well"), "Well objective comes from the selected campaign level")
	controller.campaign_state.completed_nodes["act_01/act_01_node_02"] = true
	controller._update_hud()
	await process_frame
	assert(briefing.get_node("MissionBriefingContent/EnvironmentName").text == "BROKEN VIADUCT", "Briefing follows the furthest advanced stage")
	assert(briefing.get_node("MissionBriefingContent/Objective").text.contains("Clear every hostile wave"), "Advanced stage objective stays synchronized")
	controller.queue_free()
	print("PASS operations briefing: environment intel, objective, clickable monster dossiers, and compact launch controls")
	quit(0)
