extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	assert(controller.GROUND_Y == 540.0)
	assert(controller.MACHINE_X == 640.0)
	assert(controller.environment_visual != null)
	assert(controller.environment_visual.is_prepared())
	assert(controller.environment_visual.backdrop_texture.get_width() == 1280)
	assert(controller.environment_visual.backdrop_texture.get_height() == 720)
	assert(controller.environment_visual.lane_texture.get_width() == 1280)
	assert(controller.environment_visual.lane_texture.get_height() == 180)
	assert(controller.environment_visual.layer_count() == 2)
	assert(controller.get_children().filter(func(child: Node) -> bool: return child.name == "EnvironmentVisual").size() == 1)
	var preview: Node = load("res://scenes/previews/side_view_visual_slice.tscn").instantiate()
	get_root().add_child(preview)
	await process_frame
	assert(preview.get_node("EnvironmentVisual").is_prepared())
	assert(preview.get_children().filter(func(child: Node) -> bool: return child.name == "EnvironmentVisual").size() == 1)
	controller.queue_free()
	preview.queue_free()
	print("Environment visual resource, placement, and duplicate checks passed")
	quit(0)