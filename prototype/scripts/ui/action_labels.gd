class_name ActionLabels
extends RefCounted

static func key_label(action_id: String) -> String:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey:
			var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return OS.get_keycode_string(keycode)
	return "?"

static func tooltip(action_id: String, name: String, description: String) -> String:
	return "%s (%s)\n%s" % [name, key_label(action_id), description]
