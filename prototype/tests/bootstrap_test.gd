extends SceneTree

func _init() -> void:
	var project_config: String = ProjectSettings.get_setting("application/config/name", "")
	assert(project_config == "Telos Prototype", "project name is configured")
	assert(FileAccess.file_exists("res://scenes/main.tscn"), "main scene exists")
	quit(0)
