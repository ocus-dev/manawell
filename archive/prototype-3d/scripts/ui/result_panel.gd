extends PanelContainer

signal return_requested
signal retry_requested

var outcome_label: Label
var amount_label: Label
var cause_label: Label
var surge_label: Label
var retry_button: Button

func _ready() -> void:
	if outcome_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if outcome_label == null:
		_build()
	outcome_label.text = str(view_data.get("outcome", "Extraction result"))
	amount_label.text = str(view_data.get("amount_label", ""))
	cause_label.text = "Cause: %s" % _cause_text(str(view_data.get("terminal_reason", "")))
	surge_label.text = "Completed surges: %d" % int(view_data.get("completed_surges", 0))
	retry_button.disabled = not bool(view_data.get("can_retry", false))

func _cause_text(reason: String) -> String:
	match reason:
		"hero_destroyed":
			return "Hero destroyed"
		"machine_destroyed":
			return "Harvester destroyed"
		"abandoned":
			return "Abandoned"
		"sealed":
			return "Defense completed"
		_:
			return reason if not reason.is_empty() else "No terminal cause"

func _build() -> void:
	custom_minimum_size = Vector2(380, 290)
	var content := VBoxContainer.new()
	content.name = "ResultContent"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	outcome_label = Label.new()
	outcome_label.name = "Outcome"
	outcome_label.add_theme_font_size_override("font_size", 26)
	content.add_child(outcome_label)
	amount_label = Label.new()
	amount_label.name = "Amount"
	amount_label.add_theme_font_size_override("font_size", 20)
	content.add_child(amount_label)
	cause_label = Label.new()
	cause_label.name = "Cause"
	content.add_child(cause_label)
	surge_label = Label.new()
	surge_label.name = "CompletedSurges"
	content.add_child(surge_label)
	var return_button := Button.new()
	return_button.name = "ReturnToOperations"
	return_button.text = "Return to operations"
	return_button.custom_minimum_size = Vector2(0, 48)
	return_button.pressed.connect(return_requested.emit)
	content.add_child(return_button)
	retry_button = Button.new()
	retry_button.name = "RetrySameExpedition"
	retry_button.text = "Retry same expedition"
	retry_button.custom_minimum_size = Vector2(0, 44)
	retry_button.pressed.connect(retry_requested.emit)
	content.add_child(retry_button)
