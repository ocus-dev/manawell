extends PanelContainer

## Opens when the drill is clicked: how much mana it makes per second right
## now, and the surge limit for this level (farm at a surge your hero can
## handle, or leave it open to see how high you can go).

signal surge_limit_changed(limit: int)
signal close_requested

const MANA := Color("66d9c4")
const MUTED := Color("a7bcc0")

var rate_label: Label
var detail_label: Label
var limit_label: Label
var hint_label: Label
var minus_button: Button
var plus_button: Button
var close_button: Button
var surge_limit := 0
var max_surge_limit := 99

func _init() -> void:
	name = "DrillPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(230, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#171c22f0")
	style.border_color = Color("#3e4852")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.name = "DrillContent"
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("DRILL", 13, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "×"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)
	rate_label = _label("0.0 mana/s", 22, MANA)
	rate_label.name = "ManaRate"
	content.add_child(rate_label)
	detail_label = _label("", 12, MUTED)
	detail_label.name = "RateDetail"
	content.add_child(detail_label)
	content.add_child(HSeparator.new())
	content.add_child(_label("SURGE LIMIT", 12, MUTED))
	var row := HBoxContainer.new()
	row.name = "LimitRow"
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	minus_button = _step_button("Minus", "−", -1)
	row.add_child(minus_button)
	limit_label = _label("None", 16, Color.WHITE)
	limit_label.name = "Limit"
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(limit_label)
	plus_button = _step_button("Plus", "+", 1)
	row.add_child(plus_button)
	hint_label = _label("", 11, MUTED)
	hint_label.name = "LimitHint"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(206, 0)
	content.add_child(hint_label)

func configure(drill: Dictionary) -> void:
	surge_limit = int(drill.get("surge_limit", 0))
	max_surge_limit = int(drill.get("max_surge_limit", 99))
	var running := bool(drill.get("running", false))
	var multiplier := float(drill.get("multiplier", 1.0))
	if running:
		rate_label.text = "%.1f mana/s" % float(drill.get("mana_per_second", 0.0))
		detail_label.text = "%.1f/s base  ×%.2f surge" % [float(drill.get("base_mana_per_second", 0.0)), multiplier]
	else:
		rate_label.text = "0.0 mana/s"
		detail_label.text = "Sealing - the drill has stopped." if int(drill.get("phase", 0)) == 2 else "The drill isn't running."
	limit_label.text = "None" if surge_limit <= 0 else "Surge %d" % surge_limit
	minus_button.disabled = surge_limit <= 0
	plus_button.disabled = surge_limit >= max_surge_limit
	var surge := int(drill.get("completed_surges", 0))
	var boss_surge := int(drill.get("progress_surge", 0))
	if boss_surge > 0 and surge_limit > 0 and surge_limit < boss_surge:
		hint_label.text = "Farming: the zone boss comes at surge %d, above your limit. Raise the limit to %d to progress." % [boss_surge, boss_surge]
	elif surge_limit <= 0:
		hint_label.text = "No limit: surges keep climbing every 20s."
	elif bool(drill.get("at_surge_limit", false)):
		hint_label.text = "Holding at surge %d. Enemies won't get any harder." % surge_limit
	else:
		hint_label.text = "Surges climb every 20s up to surge %d, then hold (now surge %d)." % [surge_limit, surge]

func _step_button(node_name: String, text: String, step: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(32, 28)
	button.pressed.connect(func() -> void: _step(step))
	return button

func _step(step: int) -> void:
	var next := clampi(surge_limit + step, 0, max_surge_limit)
	if next != surge_limit:
		surge_limit = next
		surge_limit_changed.emit(next)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
