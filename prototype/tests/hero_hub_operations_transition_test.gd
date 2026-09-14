extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub: Control = load("res://scenes/hero_hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	hub._open_operations()
	for _frame in range(4):
		await process_frame
	var operations_scene := current_scene
	assert(operations_scene != null and operations_scene.name == "SideViewDefense", "Hero hub opens the gameplay controller")
	assert(operations_scene.environment_visual != null, "Operations transition initializes the environment")
	assert(operations_scene.encounter_hud != null, "Operations transition initializes the interface")
	assert(operations_scene.encounter_hud.operations.mission_briefing != null, "Operations transition displays the mission briefing")
	print("PASS hero hub to operations: controller, environment, HUD, and briefing initialize")
	quit(0)
