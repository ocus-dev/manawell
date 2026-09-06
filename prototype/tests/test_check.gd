extends RefCounted

class_name TestCheck

static func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("TEST CHECK FAILED: " + message)
	return condition