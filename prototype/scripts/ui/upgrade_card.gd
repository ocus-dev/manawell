extends PanelContainer

signal purchase_requested(upgrade_id: String)

var upgrade_id: String = ""
var title_label: Label
var effect_label: Label
var cost_label: Label
var action_button: Button
var reason_label: Label

func _ready() -> void:
	if title_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if title_label == null:
		_build()
	upgrade_id = str(view_data.get("id", ""))
	title_label.text = str(view_data.get("label", upgrade_id))
	effect_label.text = str(view_data.get("effect", ""))
	cost_label.text = "Cost: %d mana" % int(view_data.get("cost", 0))
	var owned: bool = bool(view_data.get("owned", false))
	var available: bool = bool(view_data.get("available", false))
	var amount_needed: int = int(view_data.get("amount_needed", 0))
	action_button.text = "Owned" if owned else "Buy" if available else "Need %d more" % amount_needed if amount_needed > 0 else "Unavailable"
	action_button.disabled = owned or not bool(view_data.get("available", false))
	action_button.tooltip_text = str(view_data.get("availability_reason", ""))
	reason_label.text = ""
	reason_label.visible = false

func _on_purchase_pressed() -> void:
	if not action_button.disabled:
		purchase_requested.emit(upgrade_id)

func _build() -> void:
	custom_minimum_size = Vector2(0, 0)
	var content := VBoxContainer.new()
	content.name = "UpgradeCardContent"
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)
	effect_label = Label.new()
	effect_label.name = "Effect"
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(effect_label)
	cost_label = Label.new()
	cost_label.name = "Cost"
	content.add_child(cost_label)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	action_button = Button.new()
	action_button.name = "Purchase"
	action_button.custom_minimum_size = Vector2(100, 40)
	action_button.pressed.connect(_on_purchase_pressed)
	action_row.add_child(action_button)
	reason_label = Label.new()
	reason_label.name = "AvailabilityReason"
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_row.add_child(reason_label)
	content.add_child(action_row)
