extends SceneTree

## Pause > Save & quit to title checkpoints the run, and Continue resumes it
## (a tutorial run stays a tutorial run, with no monsters).

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const LIVE := "user://quit_to_title_test.json"
const TEMP := "user://quit_to_title_test.tmp"
const BACKUP := "user://quit_to_title_test.bak"

func _init() -> void:
	call_deferred("_run")

func _controller(store: RefCounted) -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = true
	controller.save_store = store
	root.add_child(controller)
	return controller

func _run() -> void:
	_cleanup()
	var controller := _controller(SaveStoreScript.new(LIVE, TEMP, BACKUP))
	await process_frame
	assert(controller.start_tutorial())
	controller.tick(3.0)
	var tank: float = controller.run_state.tank_base
	controller.quit_to_title()
	assert(FileAccess.file_exists(LIVE), "quitting did not save")
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.scene_file_path == "res://scenes/title_screen.tscn", "did not open the title screen")
	# Continue: the run comes back paused, still a tutorial.
	var reload: RefCounted = SaveStoreScript.new(LIVE, TEMP, BACKUP)
	var resumed := _controller(reload)
	await process_frame
	assert(resumed.run_state.phase == preload("res://scripts/model/run_state.gd").Phase.EXTRACTING)
	assert(resumed.run_state.paused)
	assert(resumed.tutorial_mode, "resumed tutorial would spawn monsters")
	assert(is_equal_approx(resumed.run_state.tank_base, tank))
	_cleanup()
	print("PASS quit to title: checkpoint, title scene, tutorial resumes monster-free")
	quit(0)

func _cleanup() -> void:
	for path in [LIVE, TEMP, BACKUP, LIVE + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
