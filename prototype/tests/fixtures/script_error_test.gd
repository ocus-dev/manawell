extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")

func _init() -> void:
	assert(TestCheckScript.check(true, "fixture helper is available"))
	push_error("SCRIPT ERROR: intentional runtime script error")
	quit(0)