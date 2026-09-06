extends PanelContainer

signal action_requested(action_id: String)
signal dismissed

var title_label: Label
var message_label: Label
var state_label: Label
var action_button: Button
var current_action: String = ""
var current_signature: String = ""
var dismissed_signature: String = ""

func _ready() -> void:
	if title_label == null:
		_build()

func configure(notices: Dictionary) -> void:
	if title_label == null:
		_build()
	current_action = ""
	var title := ""
	var message := ""
	if not str(notices.get("save_failure", "")).is_empty():
		title = "SAVE ISSUE"
		message = str(notices.get("save_failure", ""))
		current_action = "retry_save"
	elif not str(notices.get("recovery", "")).is_empty():
		title = "RECOVERY"
		message = str(notices.get("recovery", ""))
	elif not str(notices.get("offline", "")).is_empty():
		title = "WHILE AWAY"
		message = str(notices.get("offline", ""))
		if float(notices.get("offline_pending_total", 0.0)) > 0.0:
			current_action = "retry_settlement"
	elif not str(notices.get("assignment", "")).is_empty():
		title = "ACTION"
		message = str(notices.get("assignment", ""))
	current_signature = JSON.stringify([title, message, current_action, bool(notices.get("pending_save", false)), float(notices.get("offline_pending_total", 0.0))])
	if message.is_empty():
		dismissed_signature = ""
		visible = false
	else:
		visible = current_signature != dismissed_signature
	title_label.text = title
	message_label.text = message
	state_label.text = "Pending in memory; retry the action to confirm it was saved." if bool(notices.get("pending_save", false)) else ""
	state_label.visible = not state_label.text.is_empty()
	action_button.visible = not current_action.is_empty()
	action_button.text = "Retry save" if current_action == "retry_save" else "Retry settlement"

func dismiss() -> void:
	dismissed_signature = current_signature
	visible = false
	dismissed.emit()

func _on_action_pressed() -> void:
	if not current_action.is_empty():
		action_requested.emit(current_action)

func _build() -> void:
	custom_minimum_size = Vector2(360, 110)
	var content := VBoxContainer.new()
	content.name = "NoticeContent"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 14)
	content.add_child(title_label)
	message_label = Label.new()
	message_label.name = "Message"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)
	state_label = Label.new()
	state_label.name = "State"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(state_label)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	action_button = Button.new()
	action_button.name = "Retry"
	action_button.custom_minimum_size = Vector2(130, 40)
	action_button.pressed.connect(_on_action_pressed)
	actions.add_child(action_button)
	var dismiss_button := Button.new()
	dismiss_button.name = "Dismiss"
	dismiss_button.text = "Dismiss"
	dismiss_button.custom_minimum_size = Vector2(100, 40)
	dismiss_button.pressed.connect(dismiss)
	actions.add_child(dismiss_button)
	content.add_child(actions)