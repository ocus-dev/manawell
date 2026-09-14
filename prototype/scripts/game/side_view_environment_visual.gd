class_name SideViewEnvironmentVisual
extends Node2D

const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const GROUND_Y := 652.0
const BACKDROP_ROOT := "res://assets/side-view/environment/"
const GENERIC_BACKDROP_ID := "generic_backdrop"
const LANE_PATH := "res://assets/side-view/environment/lane.png"

@export var use_prepared_layers := true
@export var show_lane := false

var backdrop_texture: Texture2D
var lane_texture: Texture2D
var backdrop_id := GENERIC_BACKDROP_ID

func _ready() -> void:
	z_index = 0
	set_backdrop_id(GENERIC_BACKDROP_ID)
	lane_texture = load(LANE_PATH)
	queue_redraw()

func set_backdrop_id(requested_id: String) -> void:
	var candidate_id := requested_id.strip_edges()
	if candidate_id.is_empty():
		candidate_id = GENERIC_BACKDROP_ID
	var candidate_path := BACKDROP_ROOT + candidate_id + ".png"
	if not ResourceLoader.exists(candidate_path):
		candidate_id = GENERIC_BACKDROP_ID
		candidate_path = BACKDROP_ROOT + GENERIC_BACKDROP_ID + ".png"
	backdrop_id = candidate_id
	backdrop_texture = load(candidate_path) as Texture2D
	queue_redraw()

func is_prepared() -> bool:
	return use_prepared_layers and backdrop_texture != null and lane_texture != null

func layer_count() -> int:
	return 2 if is_prepared() else 1

func get_platform_rects() -> Array[Dictionary]:
	return ArenaLayoutScript.platform_supports()

func _draw() -> void:
	if is_prepared():
		draw_texture_rect(backdrop_texture, Rect2(Vector2.ZERO, LOGICAL_SIZE), false)
		if show_lane:
			draw_texture_rect(lane_texture, Rect2(0.0, GROUND_Y, LOGICAL_SIZE.x, LOGICAL_SIZE.y - GROUND_Y), false)
	else:
		_draw_debug_fallback()
	_draw_platforms()

func _draw_platforms() -> void:
	for support in ArenaLayoutScript.platform_supports():
		var rect: Rect2 = support["rect"]
		draw_rect(Rect2(rect.position + Vector2(0.0, 5.0), Vector2(rect.size.x, 22.0)), Color("17282d"), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color("c38a43"), true)
		draw_line(rect.position + Vector2(0.0, 7.0), rect.position + Vector2(rect.size.x, 7.0), Color("5f7778"), 2.0)
		for bracket_x in range(int(rect.position.x + 24.0), int(rect.end.x), 48):
			draw_line(Vector2(bracket_x, rect.position.y + 6.0), Vector2(bracket_x - 8.0, rect.position.y + 25.0), Color("536b6c"), 3.0)

func _draw_debug_fallback() -> void:
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color("091116"), true)
	for index in range(9):
		var x := 80.0 + index * 145.0
		draw_line(Vector2(x, 180), Vector2(x + 70, 110), Color("172d33"), 4.0)
		draw_line(Vector2(x + 70, 110), Vector2(x + 120, 180), Color("172d33"), 4.0)
		draw_rect(Rect2(x + 30, 180, 22, 250), Color("102127"), true)
		if index % 2 == 0:
			draw_rect(Rect2(x + 2, 205, 14, 78), Color("334a4d"), true)
	for stack in range(6):
		var stack_x := 105.0 + stack * 215.0
		draw_rect(Rect2(stack_x, 350.0 - stack % 2 * 28.0, 54.0, 190.0 + stack % 2 * 28.0), Color("1a3035"), true)
		draw_rect(Rect2(stack_x + 9.0, 365.0 - stack % 2 * 28.0, 36.0, 8.0), Color("c38a43"), true)
		draw_line(Vector2(stack_x + 27.0, 342.0 - stack % 2 * 28.0), Vector2(stack_x + 27.0, 320.0 - stack % 2 * 28.0), Color("536b6c"), 3.0)
	draw_line(Vector2(0.0, GROUND_Y), Vector2(LOGICAL_SIZE.x, GROUND_Y), Color("5f7778"), 3.0)
	draw_rect(Rect2(0.0, GROUND_Y + 3.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y - GROUND_Y - 3.0), Color("101d21"), true)
	for tile in range(40):
		draw_line(Vector2(tile * 34.0, GROUND_Y + 18.0), Vector2(tile * 34.0 + 20.0, GROUND_Y + 18.0), Color("314347"), 2.0)
