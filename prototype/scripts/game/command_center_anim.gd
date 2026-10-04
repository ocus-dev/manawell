class_name CommandCenterAnim
extends Node2D

## Brings the Home command center to life on top of its still art:
##   - the radar dish turns (its own picture, cut out of the building art)
##   - red beacons on the antennas blink
##   - the cyan light strips and door lights pulse, the amber lamps flicker
##   - a scan line sweeps the control-room windows
##   - steam puffs rise from the two tanks
##   - crew in the control tower: two walk between the windows, two sit at
##     the consoles and look about (drawn in a room behind see-through glass)
## It also draws the building itself, so the room and crew can sit behind it.
## Every position is in the building picture's own pixels (1650 x 750) and is
## mapped onto wherever HomeArea draws the building (`building_rect`).

const DISH_PATH := "res://assets/side-view/environment/home_command_center_dish.png"
const INTERIOR_PATH := "res://assets/side-view/environment/home_command_center_interior.png"
## The room picture's top-left in building pixels.
const INTERIOR_ORIGIN := Vector2(612, 282)
## Crew. Walkers pace between `from` and `to` (building pixels) at `speed`
## px/s, resting `rest` seconds at each end; sitters stay put and look around.
const WALKERS := [
	{"from": 708.0, "to": 982.0, "speed": 16.0, "rest": 2.2, "offset": 0.0, "height": 0.0},
	{"from": 960.0, "to": 790.0, "speed": 11.0, "rest": 3.0, "offset": 5.0, "height": 2.0},
]
const SITTERS := [{"x": 744.0, "phase": 0.0}, {"x": 932.0, "phase": 2.3}, {"x": 646.0, "phase": 4.1}]
const STANDING_HEAD_Y := 299.0
const SEATED_HEAD_Y := 311.0
const CREW_COLOR := Color(0.04, 0.06, 0.08)
const CREW_RIM := Color(0.45, 0.85, 0.95, 0.35)
## The dish picture's top-left in building pixels, and the mast it turns on.
const DISH_ORIGIN := Vector2(1017, 162)
const DISH_PIVOT_X := 32.0
const DISH_TURN_SECONDS := 9.0

const BEACONS := [
	Vector2(586, 8), Vector2(677, 82), Vector2(1104, 82), Vector2(1120, 96),
	Vector2(1137, 203), Vector2(478, 268), Vector2(642, 186), Vector2(1110, 225),
]
## Light strips: [centre, size] in building pixels.
const CYAN_STRIPS := [
	[Vector2(438, 452), Vector2(58, 8)], [Vector2(1252, 452), Vector2(58, 8)],
	[Vector2(843, 576), Vector2(74, 8)],
	[Vector2(670, 665), Vector2(7, 40)], [Vector2(1014, 665), Vector2(7, 40)],
]
const AMBER_LAMPS := [
	Vector2(701, 576), Vector2(982, 576), Vector2(380, 603), Vector2(1300, 603),
	Vector2(622, 702), Vector2(1062, 702),
]
const WINDOWS := Rect2(620, 284, 450, 52)
const STEAM_VENTS := [Vector2(245, 466), Vector2(1445, 466), Vector2(475, 300)]

var building_rect := Rect2()
## The building's tint (HomeArea warms it to the sunset), applied to the dish too.
var tint := Color.WHITE
var texture_size := Vector2(1650, 750)
var dish_texture: Texture2D
var interior_texture: Texture2D
var building_texture: Texture2D
var time := 0.0
var puffs: Array[Dictionary] = []
var puff_timer := 0.0
var rng := RandomNumberGenerator.new()
var glow_layer: Node2D

func _ready() -> void:
	rng.seed = 7
	dish_texture = _load(DISH_PATH)
	interior_texture = _load(INTERIOR_PATH)
	glow_layer = Node2D.new()
	glow_layer.name = "Glow"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	glow_layer.draw.connect(_draw_glow)
	add_child(glow_layer)

func configure(rect: Rect2, building_size: Vector2, building_tint: Color = Color.WHITE, building: Texture2D = null) -> void:
	building_rect = rect
	texture_size = building_size
	tint = building_tint
	building_texture = building
	queue_redraw()

static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null

func _process(delta: float) -> void:
	time += delta
	puff_timer -= delta
	if puff_timer <= 0.0:
		puff_timer = rng.randf_range(0.35, 0.8)
		var vent: Vector2 = STEAM_VENTS[rng.randi() % STEAM_VENTS.size()]
		puffs.append({"at": vent, "age": 0.0, "life": rng.randf_range(1.8, 2.8), "drift": rng.randf_range(-6.0, 10.0), "size": rng.randf_range(6.0, 11.0)})
	var alive: Array[Dictionary] = []
	for puff in puffs:
		puff.age += delta
		if puff.age < puff.life:
			alive.append(puff)
	puffs = alive
	queue_redraw()
	glow_layer.queue_redraw()

## Building pixels -> screen, and building pixel lengths -> screen lengths.
func _at(p: Vector2) -> Vector2:
	return building_rect.position + p * (building_rect.size / texture_size)

func _len() -> float:
	return building_rect.size.x / texture_size.x

func _draw() -> void:
	if building_rect.size == Vector2.ZERO:
		return
	_draw_tower_room()
	if building_texture != null:
		draw_texture_rect(building_texture, building_rect, false, tint)
	_draw_dish()
	_draw_steam()

## The room behind the control-tower glass, its flickering screens and crew.
func _draw_tower_room() -> void:
	var s := _len()
	if interior_texture != null:
		draw_texture_rect(interior_texture, Rect2(_at(INTERIOR_ORIGIN), Vector2(interior_texture.get_size()) * s), false, tint)
	for i in 6:
		var flicker := 0.5 + 0.5 * sin(time * (3.0 + float(i)) + float(i) * 2.1)
		var screen := Vector2(INTERIOR_ORIGIN.x + 24.0 + float(i) * 68.0, INTERIOR_ORIGIN.y + 38.0)
		draw_rect(Rect2(_at(screen), Vector2(14, 5) * s), Color(0.5, 0.95, 1.0, 0.25 * flicker))
	for walker in WALKERS:
		_draw_walker(walker)
	for sitter in SITTERS:
		var look := sin(time * 0.6 + float(sitter.phase)) * 1.6
		var lean := maxf(0.0, sin(time * 0.23 + float(sitter.phase))) * 1.5
		_draw_person(Vector2(float(sitter.x), SEATED_HEAD_Y + lean), look)

func _draw_walker(walker: Dictionary) -> void:
	var from := float(walker.from)
	var to := float(walker.to)
	var leg := absf(to - from) / float(walker.speed)
	var rest := float(walker.rest)
	var cycle := (leg + rest) * 2.0
	var t := fposmod(time + float(walker.offset), cycle)
	var x := from
	var moving := false
	if t < leg:
		x = lerpf(from, to, t / leg)
		moving = true
	elif t < leg + rest:
		x = to
	elif t < leg * 2.0 + rest:
		x = lerpf(to, from, (t - leg - rest) / leg)
		moving = true
	var bob := absf(sin(time * 6.0)) * 1.2 if moving else 0.0
	_draw_person(Vector2(x, STANDING_HEAD_Y + float(walker.height) - bob), 0.0)

## Head and shoulders, in building pixels (head centre at `head`).
func _draw_person(head: Vector2, look: float) -> void:
	var s := _len()
	var neck := head + Vector2(0, 7)
	var shoulders := PackedVector2Array([
		_at(neck + Vector2(-3, 0)), _at(neck + Vector2(3, 0)), _at(neck + Vector2(12, 5)),
		_at(neck + Vector2(13, 40)), _at(neck + Vector2(-13, 40)), _at(neck + Vector2(-12, 5)),
	])
	draw_colored_polygon(shoulders, CREW_COLOR)
	draw_circle(_at(head + Vector2(look, 0)), 6.9 * s, CREW_RIM)
	draw_circle(_at(head + Vector2(look - 0.4, 0.4)), 6.5 * s, CREW_COLOR)

func _draw_dish() -> void:
	if dish_texture == null:
		return
	# Turning on its mast: the width follows the cosine of its heading, and the
	# back of the dish is a little darker.
	var heading := time / DISH_TURN_SECONDS * TAU
	var c := cos(heading)
	var width_scale := maxf(0.12, absf(c))
	var shade := 1.0 if c >= 0.0 else 0.72
	var s := _len()
	var size := Vector2(dish_texture.get_size()) * s
	var pivot := _at(DISH_ORIGIN + Vector2(DISH_PIVOT_X, 0))
	var rect := Rect2(Vector2(pivot.x - DISH_PIVOT_X * s * width_scale, pivot.y), Vector2(size.x * width_scale, size.y))
	draw_texture_rect(dish_texture, rect, false, Color(tint.r * shade, tint.g * shade, tint.b * shade))

func _draw_steam() -> void:
	var s := _len()
	for puff in puffs:
		var t: float = puff.age / puff.life
		var pos: Vector2 = _at(puff.at) + Vector2(float(puff.drift) * t, -60.0 * t) * s * 2.0
		var radius: float = float(puff.size) * (1.0 + 2.2 * t) * s * 2.0
		var alpha := 0.22 * sin(PI * t)
		draw_circle(pos, radius, Color(0.92, 0.9, 0.88, alpha))
		draw_circle(pos + Vector2(radius * 0.4, -radius * 0.2), radius * 0.7, Color(1, 0.97, 0.92, alpha * 0.7))

func _draw_glow() -> void:
	if building_rect.size == Vector2.ZERO:
		return
	var s := _len()
	# Red beacons: short double blink, each on its own beat.
	for i in BEACONS.size():
		var phase := fmod(time * 0.8 + float(i) * 0.37, 1.0)
		var on := 1.0 if phase < 0.08 or (phase > 0.16 and phase < 0.24) else 0.12
		_glow(_at(BEACONS[i]), 14.0 * s * 2.0, Color(1.0, 0.18, 0.12), 0.85 * on)
	# Cyan strips: slow breathing pulse.
	var pulse := 0.55 + 0.45 * sin(time * 2.2)
	for strip in CYAN_STRIPS:
		var centre: Vector2 = _at(strip[0])
		var half: Vector2 = Vector2(strip[1]) * s * 0.5
		for layer in 3:
			var grow := float(layer) * 3.0 * s * 2.0
			glow_layer.draw_rect(Rect2(centre - half - Vector2(grow, grow), half * 2.0 + Vector2(grow, grow) * 2.0), Color(0.25, 0.85, 1.0, 0.22 * pulse / float(layer + 1)))
	# Amber lamps: gentle uneven flicker.
	for i in AMBER_LAMPS.size():
		var flicker := 0.7 + 0.3 * sin(time * 9.0 + float(i) * 1.7) * sin(time * 3.1 + float(i))
		_glow(_at(AMBER_LAMPS[i]), 10.0 * s * 2.0, Color(1.0, 0.7, 0.3), 0.45 * flicker)
	# Control-room windows: a soft scan line sweeping left to right.
	var sweep := fmod(time / 3.5, 1.0)
	var top_left := _at(WINDOWS.position)
	var window_size := WINDOWS.size * s
	var band_x := top_left.x + window_size.x * sweep
	var band_w := 26.0 * s * 2.0
	for k in 4:
		var w := band_w * (1.0 - float(k) * 0.22)
		var x0 := clampf(band_x - w * 0.5, top_left.x, top_left.x + window_size.x)
		var x1 := clampf(band_x + w * 0.5, top_left.x, top_left.x + window_size.x)
		if x1 > x0:
			glow_layer.draw_rect(Rect2(Vector2(x0, top_left.y), Vector2(x1 - x0, window_size.y)), Color(0.4, 0.9, 1.0, 0.07))

func _glow(at: Vector2, radius: float, color: Color, strength: float) -> void:
	if strength <= 0.01:
		return
	for k in 4:
		var r := radius * (1.0 - float(k) * 0.22)
		glow_layer.draw_circle(at, r, Color(color.r, color.g, color.b, strength * 0.18 * float(k + 1) / 4.0))
	glow_layer.draw_circle(at, radius * 0.18, Color(1, 0.95, 0.9, strength))
