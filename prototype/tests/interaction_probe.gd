class_name InteractionProbe
extends RefCounted

const TestCheckScript = preload("res://tests/test_check.gd")

static func hover_and_click(tree: SceneTree, control: Control, label: String) -> bool:
	var window := control.get_window()
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.window_id = window.get_window_id()
	motion.position = point
	viewport.push_input(motion)
	var hovered := viewport.gui_get_hovered_control()
	var hit := hovered == control or (hovered != null and control.is_ancestor_of(hovered))
	if not TestCheckScript.check(hit, "%s receives pointer hover" % label):
		return false
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.window_id = window.get_window_id()
	press.position = point
	press.pressed = true
	viewport.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.window_id = window.get_window_id()
	release.position = point
	release.pressed = false
	viewport.push_input(release)
	return true

static func assert_interactable(control: Control, label: String) -> bool:
	var rect := control.get_global_rect()
	return TestCheckScript.check(control.is_visible_in_tree(), "%s is visible" % label) and TestCheckScript.check(not control.disabled, "%s is enabled" % label) and TestCheckScript.check(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has a hit rectangle" % label)
