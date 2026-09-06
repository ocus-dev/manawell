extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")

func _init() -> void:
	assert(TestCheckScript.check(true, "fixture helper is available"))
	_nested_failure()
	quit(0)

func _nested_failure() -> void:
	assert(false, "intentional nested assertion failure")