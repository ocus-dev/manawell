extends Button

## A round check mark drawn in code (no font glyph needed).
##   toggle mode (the Weapon Lab "done" mark): green check when on, a faint
##   empty ring when off; click to flip it.
##   status mode (checklist rows): set `status` to "ok", "warn" or "need".

const GREEN := Color("4fd08a")
const AMBER := Color("f0a836")
const RED := Color("f07a7a")
const RING := Color("6b7680")

var status := ""

func _init(diameter: float = 22.0, toggle: bool = true) -> void:
	toggle_mode = toggle
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if toggle else Control.CURSOR_ARROW
	mouse_filter = Control.MOUSE_FILTER_STOP if toggle else Control.MOUSE_FILTER_IGNORE
	for style in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func set_status(value: String) -> void:
	status = value
	queue_redraw()

func _draw() -> void:
	var diameter := minf(size.x, size.y)
	var center := size * 0.5
	var radius := diameter * 0.5 - 1.0
	var kind := status
	if toggle_mode:
		kind = "ok" if button_pressed else "off"
	match kind:
		"ok":
			draw_circle(center, radius, GREEN)
			_check(center, radius, Color("0f2a1b"))
		"warn":
			draw_circle(center, radius, AMBER)
			draw_line(center + Vector2(0, -radius * 0.5), center + Vector2(0, radius * 0.12), Color("2a1d06"), maxf(2.0, radius * 0.22))
			draw_circle(center + Vector2(0, radius * 0.45), maxf(1.2, radius * 0.13), Color("2a1d06"))
		"need":
			draw_circle(center, radius, RED)
			var arm := radius * 0.4
			var width := maxf(2.0, radius * 0.2)
			draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), Color("2a0e0e"), width)
			draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), Color("2a0e0e"), width)
		_:
			var ring := Color(RING, 1.0 if is_hovered() else 0.7)
			draw_arc(center, radius - 0.5, 0.0, TAU, 32, ring, 1.5, true)
			if is_hovered():
				_check(center, radius, Color(GREEN, 0.6))

func _check(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(-radius * 0.45, radius * 0.02), center + Vector2(-radius * 0.12, radius * 0.36), center + Vector2(radius * 0.5, -radius * 0.34)])
	draw_polyline(points, color, maxf(2.0, radius * 0.22), true)
