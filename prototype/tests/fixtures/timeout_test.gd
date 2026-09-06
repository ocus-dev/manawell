extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")

func _init() -> void:
	assert(TestCheckScript.check(true, "fixture helper is available"))
	while true:
		OS.delay_msec(100)