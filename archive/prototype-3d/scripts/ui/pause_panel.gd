extends PanelContainer

signal resume_requested
signal settings_requested
signal abandon_requested

var at_risk_label: Label
var confirmation: PanelContainer
var opener: Control

func _ready() -> void:
	if at_risk_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if at_risk_label == null:
		_build()
	at_risk_label.text = "Current tank at risk: %d mana" % int(view_data.get("at_risk_payout", 0))
	_hide_confirmation()

func request_abandon() -> void:
	confirmation.visible = true
	var confirm_button: Button = confirmation.get_node("ConfirmationContent/ConfirmAbandon")
	confirm_button.grab_focus()

func _on_confirm_abandon() -> void:
	confirmation.visible = false
	abandon_requested.emit()

func _on_cancel_abandon() -> void:
	_hide_confirmation()

func _hide_confirmation() -> void:
	if confirmation != null:
		confirmation.visible = false

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if confirmation.visible:
			_hide_confirmation()
		else:
			resume_requested.emit()

func _build() -> void:
	custom_minimum_size = Vector2(360, 250)
	var content := VBoxContainer.new()
	content.name = "PauseContent"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "PAUSED"
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)
	at_risk_label = Label.new()
	at_risk_label.name = "AtRisk"
	at_risk_label.add_theme_font_size_override("font_size", 18)
	content.add_child(at_risk_label)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(0, 44)
	resume.pressed.connect(resume_requested.emit)
	content.add_child(resume)
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "Settings"
	settings.custom_minimum_size = Vector2(0, 44)
	settings.pressed.connect(settings_requested.emit)
	content.add_child(settings)
	var abandon := Button.new()
	abandon.name = "Abandon"
	abandon.text = "Abandon current tank"
	abandon.custom_minimum_size = Vector2(0, 44)
	abandon.pressed.connect(request_abandon)
	content.add_child(abandon)
	confirmation = PanelContainer.new()
	confirmation.name = "AbandonConfirmation"
	confirmation.visible = false
	content.add_child(confirmation)
	var confirmation_content := VBoxContainer.new()
	confirmation_content.name = "ConfirmationContent"
	confirmation.add_child(confirmation_content)
	var confirmation_label := Label.new()
	confirmation_label.text = "Abandon current tank? The at-risk amount will be forfeited."
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_content.add_child(confirmation_label)
	var confirm := Button.new()
	confirm.name = "ConfirmAbandon"
	confirm.text = "Confirm abandon"
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.pressed.connect(_on_confirm_abandon)
	confirmation_content.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "CancelAbandon"
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_on_cancel_abandon)
	confirmation_content.add_child(cancel)
