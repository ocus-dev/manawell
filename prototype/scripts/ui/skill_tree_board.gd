class_name SkillTreeBoard
extends Control

## The skill tree drawn on Scott's painted circuit board
## (assets/ui/skill_tree/). The painting supplies everything that never
## changes: the riveted frame, blueprint sketches, branch names, the data buses
## and the MK-I core chip. The parts that change are drawn on top using pieces
## cut from the same painting:
##   - skill_keystone.png / skill_chip.png / skill_pad.png: a keystone chip, a
##     smaller chip and a solder pad, with their printed text removed (each
##     node's code is drawn on its screen instead)
##   - traces between nodes, in the painting's orange
## States:
##   - locked: chip darkened, trace dead copper
##   - reachable (its parent is powered): chip half-lit and breathing, trace
##     dim orange
##   - powered: chip at full brightness with an orange glow, trace glowing with
##     current pulses running outward from the core
## Board units are painting pixels with the core at (0, 0) (see SkillTree); the
## painting is scaled to fit this control.

signal node_selected(node_id: String)
signal node_activated(node_id: String)

const SkillTreeScript = preload("res://scripts/model/skill_tree.gd")

const ART_DIR := "res://assets/ui/skill_tree/"
const PLATE_PATH := ART_DIR + "skill_board_plate.png"
const KEYSTONE_PATH := ART_DIR + "skill_keystone.png"
const CHIP_PATH := ART_DIR + "skill_chip.png"
const PAD_PATH := ART_DIR + "skill_pad.png"

## Half the size of the painted core chip (board units), for clicks.
const CORE_HALF := Vector2(80.0, 82.0)
## The core's cyan screen, relative to the core centre.
const CORE_SCREEN := Rect2(-38.0, -42.0, 76.0, 38.0)
const PAD_RADIUS: float = 13.0
const NOTABLE_HALF: float = 25.0
const KEYSTONE_HALF: float = 31.0

const COLOR_FALLBACK_BOARD := Color("1a1714")
const COLOR_DEAD := Color(0.24, 0.17, 0.11)
const COLOR_DIM := Color(0.62, 0.37, 0.13)
const COLOR_LIVE := Color(1.0, 0.76, 0.40)
const COLOR_GLOW := Color(1.0, 0.48, 0.10)
const COLOR_CORE_GLOW := Color(0.35, 0.85, 1.0)
const COLOR_SELECT := Color("f5dc79")
const COLOR_TEXT_LIT := Color("ece6d8")
const COLOR_TEXT_DIM := Color("aca393")
const COLOR_TEXT_DEAD := Color("5c5650")
const COLOR_COUNT := Color("b9b2a3")
const COLOR_COUNT_LIT := Color("f0b05a")
## How bright a node's sprite is when locked / reachable.
const LOCKED_MODULATE := Color(0.34, 0.32, 0.30)
const REACHABLE_LOW: float = 0.58
const REACHABLE_HIGH: float = 0.82

var unlocked: Dictionary = {}
var scrap: int = 0
var mech_id: String = SkillTreeScript.DEFAULT_MECH_TYPE
var hovered_id: String = ""
var selected_id: String = ""
var time: float = 0.0
## Trace polylines by child node id (from its parent, or the core).
var routes: Dictionary = {}
var plate_texture: Texture2D
var keystone_texture: Texture2D
var chip_texture: Texture2D
var pad_texture: Texture2D
## Additive layer on top for glows and current pulses.
var glow_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	plate_texture = _load_texture(PLATE_PATH)
	keystone_texture = _load_texture(KEYSTONE_PATH)
	chip_texture = _load_texture(CHIP_PATH)
	pad_texture = _load_texture(PAD_PATH)
	_build_routes()
	glow_layer = Control.new()
	glow_layer.name = "Glow"
	glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	glow_layer.draw.connect(_draw_glow)
	add_child(glow_layer)

## The imported texture when Godot has imported the PNG; otherwise the raw file.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_warning("Skill tree art missing: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func set_state(new_unlocked: Dictionary, new_scrap: int) -> void:
	unlocked = new_unlocked
	scrap = new_scrap
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()
	if glow_layer != null:
		glow_layer.queue_redraw()

# --- Layout ------------------------------------------------------------------

func board_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / SkillTreeScript.ART_SIZE.x, size.y / SkillTreeScript.ART_SIZE.y)

## Where board (0, 0), the core, lands in control pixels: the painting is
## centred in the control.
func board_origin() -> Vector2:
	var s := board_scale()
	return (size - SkillTreeScript.ART_SIZE * s) * 0.5 + SkillTreeScript.ART_CORE * s

## Control-local pixel -> board units.
func to_board(local: Vector2) -> Vector2:
	return (local - board_origin()) / board_scale()

## Board units -> control-local pixel.
func to_local_point(board: Vector2) -> Vector2:
	return board_origin() + board * board_scale()

func hit_radius(node_id: String) -> float:
	if node_id == SkillTreeScript.CORE_ID:
		return CORE_HALF.x
	match str(SkillTreeScript.node_def(node_id).get("tier", "minor")):
		"keystone":
			return KEYSTONE_HALF + 3.0
		"notable":
			return NOTABLE_HALF + 3.0
	return PAD_RADIUS + 5.0

## The node under a board-space point ("" for none).
func node_at(board: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for node_id in SkillTreeScript.node_ids():
		var distance := board.distance_to(SkillTreeScript.position_of(node_id))
		if distance <= hit_radius(node_id) and distance < best_distance:
			best = node_id
			best_distance = distance
	if best.is_empty() and absf(board.x) <= CORE_HALF.x and absf(board.y) <= CORE_HALF.y:
		return SkillTreeScript.CORE_ID
	return best

## Trace from a node's parent (or the core's painted exit) to the node.
static func route_for(node_id: String) -> PackedVector2Array:
	var node: Dictionary = SkillTreeScript.node_def(node_id)
	var parent := str(node.parent)
	var start: Vector2 = SkillTreeScript.position_of(parent)
	if parent == SkillTreeScript.CORE_ID:
		start = SkillTreeScript.core_exit_of(str(node.branch))
	var target: Vector2 = node.position
	return PackedVector2Array([start, target])

func _build_routes() -> void:
	routes = {}
	for node_id in SkillTreeScript.node_ids():
		routes[node_id] = route_for(node_id)

# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := node_at(to_board(event.position))
		if over != hovered_id:
			hovered_id = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not over.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := node_at(to_board(event.position))
		if clicked.is_empty():
			return
		select(clicked)
		if event.double_click:
			node_activated.emit(clicked)
		accept_event()

func select(node_id: String) -> void:
	selected_id = node_id
	node_selected.emit(node_id)
	queue_redraw()

# --- State -------------------------------------------------------------------

func node_state(node_id: String) -> String:
	if unlocked.has(node_id):
		return "powered"
	if SkillTreeScript.is_reachable(unlocked, node_id):
		return "reachable"
	return "locked"

func _breathe() -> float:
	return 0.5 + 0.5 * sin(time * 3.0)

func _sprite_modulate(state: String) -> Color:
	match state:
		"powered":
			return Color.WHITE
		"reachable":
			var v := lerpf(REACHABLE_LOW, REACHABLE_HIGH, _breathe())
			return Color(v, v, v)
	return LOCKED_MODULATE

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var s := board_scale()
	draw_set_transform(board_origin(), 0.0, Vector2(s, s))
	var art_rect := Rect2(-SkillTreeScript.ART_CORE, SkillTreeScript.ART_SIZE)
	if plate_texture != null:
		draw_texture_rect(plate_texture, art_rect, false)
	else:
		draw_rect(art_rect, COLOR_FALLBACK_BOARD)
	for node_id in SkillTreeScript.node_ids():
		_draw_trace(node_id)
	for node_id in SkillTreeScript.node_ids():
		_draw_node(node_id)
	_draw_counts()
	_draw_core_marks()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_trace(node_id: String) -> void:
	var path: PackedVector2Array = routes.get(node_id, PackedVector2Array())
	if path.size() < 2:
		return
	match node_state(node_id):
		"powered":
			draw_polyline(path, COLOR_LIVE, 2.6, true)
		"reachable":
			draw_polyline(path, COLOR_DIM.lerp(COLOR_LIVE, 0.25 * _breathe()), 2.4, true)
		_:
			draw_polyline(path, COLOR_DEAD, 2.4, true)

func _draw_node(node_id: String) -> void:
	var node: Dictionary = SkillTreeScript.node_def(node_id)
	var at: Vector2 = node.position
	var state := node_state(node_id)
	var tier := str(node.tier)
	var texture: Texture2D = pad_texture
	if tier == "keystone":
		texture = keystone_texture
	elif tier == "notable":
		texture = chip_texture
	var tint := _sprite_modulate(state)
	if texture != null:
		var half := Vector2(texture.get_size()) * 0.5
		draw_texture_rect(texture, Rect2(at - half, half * 2.0), false, tint)
	else:
		_draw_fallback_node(at, tier, tint)
	if tier != "minor":
		_draw_code(at, str(node.code), tier == "keystone", state)
	var radius := hit_radius(node_id)
	if node_id == hovered_id:
		if tier == "minor":
			draw_arc(at, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 1.5, true)
		else:
			draw_rect(Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), Color(1, 1, 1, 0.7), false, 1.5)
	if node_id == selected_id:
		_draw_brackets(at, Vector2(radius + 5.0, radius + 5.0), COLOR_SELECT)

## When the art is missing: plain shapes so the tree still works.
func _draw_fallback_node(at: Vector2, tier: String, tint: Color) -> void:
	var body := Color(0.16, 0.15, 0.14) * tint
	var edge := Color(1.0, 0.6, 0.2) * tint
	if tier == "minor":
		draw_circle(at, PAD_RADIUS, edge)
		draw_circle(at, PAD_RADIUS - 4.0, body)
		return
	var half := KEYSTONE_HALF if tier == "keystone" else NOTABLE_HALF
	var rect := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(rect, body)
	draw_rect(rect, edge, false, 2.0)

## The chip's code on its screen, in the painting's pale stencil look.
func _draw_code(at: Vector2, code: String, big: bool, state: String) -> void:
	if code.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := 17 if big else 14
	var color := COLOR_TEXT_DEAD
	if state == "powered":
		color = COLOR_TEXT_LIT
	elif state == "reachable":
		color = COLOR_TEXT_DIM
	var width := 80.0
	var baseline := at + Vector2(-width * 0.5, float(font_size) * 0.36)
	# Drawn twice, a hair apart, for a bolder stencil.
	draw_string(font, baseline, code, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	draw_string(font, baseline + Vector2(0.6, 0.0), code, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)

## "n/6" under each painted branch name.
func _draw_counts() -> void:
	var font := ThemeDB.fallback_font
	for branch in SkillTreeScript.BRANCHES:
		var powered := 0
		for shape in SkillTreeScript.BRANCH_TEMPLATE:
			if unlocked.has("%s_%s" % [branch.id, shape.key]):
				powered += 1
		var at := SkillTreeScript.count_position_of(str(branch.id))
		var text := "%d/%d" % [powered, SkillTreeScript.BRANCH_TEMPLATE.size()]
		var color := COLOR_COUNT_LIT if powered > 0 else COLOR_COUNT
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
		draw_string(font, at + Vector2(0.6, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)

func _draw_core_marks() -> void:
	var box := Rect2(-CORE_HALF, CORE_HALF * 2.0)
	if hovered_id == SkillTreeScript.CORE_ID:
		draw_rect(box.grow(3.0), Color(1, 1, 1, 0.6), false, 1.5)
	if selected_id == SkillTreeScript.CORE_ID:
		_draw_brackets(Vector2.ZERO, CORE_HALF + Vector2(8.0, 8.0), COLOR_SELECT)

func _draw_brackets(at: Vector2, reach: Vector2, color: Color) -> void:
	var arm := minf(reach.x, reach.y) * 0.45
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c: Vector2 = at + corner * reach
		draw_line(c, c - Vector2(corner.x * arm, 0), color, 2.0)
		draw_line(c, c - Vector2(0, corner.y * arm), color, 2.0)

# --- Glow (additive layer) ---------------------------------------------------

func _draw_glow() -> void:
	var s := board_scale()
	glow_layer.draw_set_transform(board_origin(), 0.0, Vector2(s, s))
	# The core screen breathes.
	var pulse := 0.5 + 0.5 * sin(time * 1.6)
	var screen := CORE_SCREEN
	for layer in 3:
		var grow := float(layer) * 5.0
		glow_layer.draw_rect(screen.grow(grow), COLOR_CORE_GLOW * Color(1, 1, 1, (0.05 + 0.05 * pulse) / float(layer + 1)))
	for node_id in SkillTreeScript.node_ids():
		var state := node_state(node_id)
		var path: PackedVector2Array = routes.get(node_id, PackedVector2Array())
		if state == "powered":
			glow_layer.draw_polyline(path, COLOR_GLOW * Color(1, 1, 1, 0.16), 12.0, true)
			glow_layer.draw_polyline(path, COLOR_GLOW * Color(1, 1, 1, 0.32), 5.0, true)
			_glow_current(path)
			_glow_node(node_id, 1.0)
		elif state == "reachable":
			glow_layer.draw_polyline(path, COLOR_GLOW * Color(1, 1, 1, 0.08 + 0.08 * _breathe()), 6.0, true)
			_glow_node(node_id, 0.25 + 0.2 * _breathe())
	glow_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A warm halo around a lit node.
func _glow_node(node_id: String, strength: float) -> void:
	var at := SkillTreeScript.position_of(node_id)
	var radius := hit_radius(node_id) + 10.0
	for k in 4:
		var r := radius * (1.0 - float(k) * 0.2)
		glow_layer.draw_circle(at, r, COLOR_GLOW * Color(1, 1, 1, 0.05 * strength * float(k + 1)))

## Bright pulses running from the parent toward the node along the trace.
func _glow_current(path: PackedVector2Array) -> void:
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	if length <= 0.0:
		return
	for k in 2:
		var travelled := fposmod(time * 70.0 + float(k) * length * 0.5, length)
		var point := _point_along(path, travelled)
		glow_layer.draw_circle(point, 6.0, COLOR_GLOW * Color(1, 1, 1, 0.35))
		glow_layer.draw_circle(point, 2.5, COLOR_LIVE)

static func _point_along(path: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in path.size() - 1:
		var segment := path[i].distance_to(path[i + 1])
		if left <= segment and segment > 0.0:
			return path[i].lerp(path[i + 1], left / segment)
		left -= segment
	return path[path.size() - 1]
