extends SceneTree

const PlayerScript = preload("res://scripts/game/player.gd")

func _init() -> void:
	var straight := PlayerScript.get_camera_relative_direction(Vector2(0.0, -1.0), Basis.IDENTITY)
	var diagonal := PlayerScript.get_camera_relative_direction(Vector2(1.0, -1.0), Basis.IDENTITY)
	assert(is_equal_approx(straight.length(), 1.0), "straight movement is normalized")
	assert(is_equal_approx(diagonal.length(), 1.0), "diagonal movement is normalized")
	assert(is_equal_approx(abs(diagonal.x), abs(diagonal.z)), "diagonal movement has equal horizontal components")
	for action in ["pulse", "dash", "harvest", "pause_game"]:
		assert(InputMap.has_action(action), "%s action is defined" % action)
	var arena: Node3D = load("res://scenes/main.tscn").instantiate()
	assert(arena.get_node("Hero") is CharacterBody3D, "hero uses CharacterBody3D")
	assert(arena.get_node("Machine") is StaticBody3D, "machine blocks movement")
	assert(arena.get_node("Boundaries/West") is StaticBody3D, "west boundary blocks movement")
	get_root().add_child(arena)
	quit(0)
