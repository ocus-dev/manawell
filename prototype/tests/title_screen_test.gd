extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title_screen.tscn")
	assert(FileAccess.file_exists("res://assets/title/title-background.png"))
	assert(FileAccess.file_exists("res://assets/title/telos-title.png"))
	var packed_scene: PackedScene = load("res://scenes/title_screen.tscn")
	var scene: Control = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.get_node("Background").texture != null)
	assert(scene.get_node("Title").texture != null)
	assert(scene.get_node("Menu/Continue") is Button)
	assert(scene.get_node("Menu/NewGame") is Button)
	assert(scene.get_node("Menu/Settings") is Button)
	assert(scene.get_node("Menu/Quit") is Button)
	scene._show_settings()
	assert(scene.get_node("SettingsPanel").visible)
	assert(not scene.get_node("Menu").visible)
	scene._hide_settings()
	assert(not scene.get_node("SettingsPanel").visible)
	assert(scene.get_node("Menu").visible)
	scene.queue_free()
	print("PASS title screen: startup route, supplied art, menu controls, and settings overlay")
	quit(0)
