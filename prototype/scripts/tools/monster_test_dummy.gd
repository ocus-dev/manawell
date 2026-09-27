extends Node2D

## Invincible training dummy for the Monster Test Arena.
##
## It stands in for the hero (and the harvester) so monsters attack it with
## their real AI. It never loses health; every hit is shown as a floating
## damage number colored by the monster that dealt it.
##
## Like the hero, `position` is the feet anchor used by CombatGeometry
## ("hero" hurtbox); the drawn ground line is 40 px below it.

const GROUND_LOCAL_Y := 40.0
const NUMBER_LIFETIME := 1.1
const NUMBER_RISE := 64.0
const MAX_NUMBERS := 48
const FLASH_DURATION := 0.14
const SHAKE_DURATION := 0.18

const WOOD := Color("7a5634")
const WOOD_DARK := Color("4f3721")
const SACK := Color("c2a878")
const SACK_DARK := Color("8f7a52")
const ROPE := Color("5e4a2e")
const TARGET := Color("c2493b")
const INFINITE := Color("f0a836")

const MONSTER_COLORS := {
	"pursuer": Color("ff6b5a"),
	"breaker": Color("f0a836"),
	"ranged": Color("5fd4ff"),
}

## Same field the hero exposes; some shared code reads it.
var last_facing: int = 1
var numbers: Array[Dictionary] = []
var flash_remaining := 0.0
var shake_remaining := 0.0
var shake_side := 1.0
var number_layer: Node2D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7
	number_layer = Node2D.new()
	number_layer.name = "DamageNumbers"
	number_layer.z_as_relative = false
	number_layer.z_index = 20
	number_layer.draw.connect(_draw_numbers)
	add_child(number_layer)

static func color_for(monster_id: String) -> Color:
	return MONSTER_COLORS.get(monster_id, Color("ece6da"))

## Records a hit for display. The dummy itself never takes damage.
func show_hit(amount: float, monster_id: String = "", from_x: float = NAN) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	var jitter := _rng.randf_range(-22.0, 22.0)
	if is_finite(from_x):
		# Lean the number toward the side the hit came from.
		jitter += clampf((from_x - global_position.x) * 0.08, -18.0, 18.0)
	# Stack numbers that land at nearly the same moment so they don't overlap.
	var fresh := 0
	for entry in numbers:
		if float(entry["age"]) < 0.2:
			fresh += 1
	numbers.append({"amount": amount, "color": color_for(monster_id), "age": 0.0, "x": jitter, "y": -22.0 * (fresh % 4)})
	while numbers.size() > MAX_NUMBERS:
		numbers.pop_front()
	flash_remaining = FLASH_DURATION
	shake_remaining = SHAKE_DURATION
	shake_side = -1.0 if is_finite(from_x) and from_x > global_position.x else 1.0
	queue_redraw()
	number_layer.queue_redraw()

func clear_numbers() -> void:
	numbers.clear()
	number_layer.queue_redraw()

func tick(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	shake_remaining = maxf(0.0, shake_remaining - delta)
	for index in range(numbers.size() - 1, -1, -1):
		numbers[index]["age"] = float(numbers[index]["age"]) + delta
		if float(numbers[index]["age"]) >= NUMBER_LIFETIME:
			numbers.remove_at(index)
	queue_redraw()
	number_layer.queue_redraw()

func _shake_offset() -> float:
	if shake_remaining <= 0.0:
		return 0.0
	var strength := shake_remaining / SHAKE_DURATION
	return sin(shake_remaining * 90.0) * 4.0 * strength * shake_side

func _tint(color: Color) -> Color:
	if flash_remaining <= 0.0:
		return color
	return color.lerp(Color.WHITE, 0.65 * flash_remaining / FLASH_DURATION)

func _draw() -> void:
	var g := GROUND_LOCAL_Y
	var sway := _shake_offset()
	# Base plate and shadow stay planted; the body sways when hit.
	draw_rect(Rect2(-34.0, g - 3.0, 68.0, 6.0), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(-24.0, g - 10.0, 48.0, 9.0), WOOD_DARK, true)
	draw_rect(Rect2(-5.0, g - 58.0, 10.0, 50.0), _tint(WOOD), true)
	var top := Vector2(sway, 0.0)
	# Crossbar arms.
	draw_rect(Rect2(top + Vector2(-44.0, -52.0), Vector2(88.0, 9.0)), _tint(WOOD), true)
	draw_rect(Rect2(top + Vector2(-44.0, -44.0), Vector2(88.0, 2.0)), WOOD_DARK, true)
	# Sack body.
	var body := Rect2(top + Vector2(-23.0, -70.0), Vector2(46.0, 66.0))
	draw_rect(body, _tint(SACK), true)
	draw_rect(body, SACK_DARK, false, 2.0)
	for stitch_y in [-58.0, -20.0]:
		draw_line(top + Vector2(-23.0, stitch_y), top + Vector2(23.0, stitch_y), SACK_DARK, 1.0)
	draw_line(top + Vector2(-23.0, -12.0), top + Vector2(23.0, -12.0), ROPE, 3.0)
	# Target on the chest.
	var chest := top + Vector2(0.0, -38.0)
	draw_circle(chest, 12.0, _tint(TARGET))
	draw_circle(chest, 8.0, _tint(SACK))
	draw_circle(chest, 4.0, _tint(TARGET))
	# Head.
	var head := top + Vector2(0.0, -86.0)
	draw_line(top + Vector2(0.0, -76.0), top + Vector2(0.0, -70.0), ROPE, 4.0)
	draw_circle(head, 14.0, _tint(SACK))
	draw_arc(head, 14.0, 0.0, TAU, 24, SACK_DARK, 2.0)
	draw_line(head + Vector2(-7.0, -3.0), head + Vector2(-3.0, 1.0), SACK_DARK, 2.0)
	draw_line(head + Vector2(-3.0, -3.0), head + Vector2(-7.0, 1.0), SACK_DARK, 2.0)
	draw_line(head + Vector2(3.0, -3.0), head + Vector2(7.0, 1.0), SACK_DARK, 2.0)
	draw_line(head + Vector2(7.0, -3.0), head + Vector2(3.0, 1.0), SACK_DARK, 2.0)
	# Invincible health bar, drawn where enemy bars sit.
	var bar_y := -124.0
	draw_rect(Rect2(-32.0, bar_y, 64.0, 8.0), Color("111b21"), true)
	draw_rect(Rect2(-31.0, bar_y + 1.0, 62.0, 6.0), INFINITE, true)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60.0, bar_y - 6.0), "INVINCIBLE", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-60.0, bar_y - 6.0), "INVINCIBLE", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, INFINITE)

func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	for entry in numbers:
		var age := float(entry["age"])
		var t := clampf(age / NUMBER_LIFETIME, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		var alpha := 1.0 if t < 0.6 else clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		var pop := 1.0 + 0.35 * clampf(1.0 - age / 0.12, 0.0, 1.0)
		var size := int(round(22.0 * pop))
		var amount := float(entry["amount"])
		var text := str(roundi(amount)) if absf(amount - roundf(amount)) < 0.05 else "%.1f" % amount
		var anchor := Vector2(float(entry["x"]) - 50.0, -140.0 + float(entry.get("y", 0.0)) - eased * NUMBER_RISE)
		var color: Color = entry["color"]
		draw_string_on(font, anchor, text, size, Color(0, 0, 0, 0.85 * alpha), Color(color.r, color.g, color.b, alpha))

func draw_string_on(font: Font, anchor: Vector2, text: String, size: int, outline: Color, fill: Color) -> void:
	number_layer.draw_string_outline(font, anchor, text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, size, 5, outline)
	number_layer.draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, size, fill)
