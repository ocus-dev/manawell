extends PanelContainer

signal settings_requested(opener: Control)

var bank_label: Label
var passive_label: Label

func _ready() -> void:
	if bank_label == null:
		_build()

func configure(view_data: Dictionary) -> void:
	if bank_label == null:
		_build()
	bank_label.text = "Banked mana %0.2f" % float(view_data.get("banked_mana", 0.0))
	passive_label.text = "Passive %0.2f mana/min" % float(view_data.get("passive_rate_per_minute", 0.0))

func _build() -> void:
	var row := HBoxContainer.new()
	row.name = "ResourceStripContent"
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	var title := Label.new()
	title.text = "MANA WELL / OPERATIONS"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	bank_label = Label.new()
	bank_label.name = "BankedMana"
	bank_label.custom_minimum_size = Vector2(170, 40)
	row.add_child(bank_label)
	passive_label = Label.new()
	passive_label.name = "PassiveRate"
	passive_label.custom_minimum_size = Vector2(190, 40)
	row.add_child(passive_label)
	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.text = "Settings"
	settings.custom_minimum_size = Vector2(110, 40)
	settings.pressed.connect(func(): settings_requested.emit(settings))
	row.add_child(settings)