extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	assert(controller.encounter_hud != null)
	assert(controller.encounter_hud.get_parent() is CanvasLayer)
	assert(controller.encounter_hud.operations.visible)
	assert(not controller.encounter_hud.combat.visible)
	assert(controller.start_run())
	await process_frame
	assert(not controller.encounter_hud.operations.visible)
	assert(controller.encounter_hud.combat.visible)
	assert(str(controller.encounter_hud.view_state["combat"]["threat_label"]).contains("Next spawn"))
	controller.toggle_pause()
	await process_frame
	assert(controller.encounter_hud.router.mode == "pause")
	controller.toggle_pause()
	controller.return_to_operations() if controller.run_state.phase >= 3 else controller.abandon()
	controller.queue_free()
	print("2D presentation ownership checks passed")
	quit(0)
