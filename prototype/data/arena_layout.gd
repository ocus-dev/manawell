class_name ArenaLayout
extends RefCounted

const FLOOR_ID := "floor"
const CONFIG_ID := "foundry-platforms-v1"
const FLOOR_TOP_Y: float = 652.0 # 8 px above the hotbar at y=660.
const LEFT_BOUND: float = 96.0
const RIGHT_BOUND: float = 1184.0
const HERO_HALF_WIDTH: float = 18.0
const HERO_FEET_OFFSET: float = 40.0
const DROP_THROUGH_DURATION: float = 0.12
const DROP_THROUGH_CLEARANCE: float = 8.0

const SUPPORTS: Array[Dictionary] = [
	{"id": "platform_left", "rect": Rect2(260.0, FLOOR_TOP_Y - 110.0, 210.0, 16.0)},
	{"id": "platform_right", "rect": Rect2(810.0, FLOOR_TOP_Y - 110.0, 210.0, 16.0)},
]

static func support_by_id(support_id: String) -> Dictionary:
	if support_id == FLOOR_ID:
		return {"id": FLOOR_ID, "rect": Rect2(LEFT_BOUND, FLOOR_TOP_Y, RIGHT_BOUND - LEFT_BOUND, 1.0)}
	for support in SUPPORTS:
		if support["id"] == support_id:
			return support
	return {}

static func support_top(support_id: String) -> float:
	var support := support_by_id(support_id)
	return float(support.get("rect", Rect2()).position.y)

static func hero_support_y(support_id: String) -> float:
	return support_top(support_id) - HERO_FEET_OFFSET

static func platform_supports() -> Array[Dictionary]:
	return SUPPORTS.duplicate(true)

static func overlaps_hero(support: Dictionary, hero_x: float) -> bool:
	var rect: Rect2 = support["rect"]
	return hero_x + HERO_HALF_WIDTH >= rect.position.x and hero_x - HERO_HALF_WIDTH <= rect.end.x

static func support_for_landing(previous_y: float, next_y: float, hero_x: float, ignored_id: String = "") -> Dictionary:
	if next_y < previous_y:
		return {}
	var candidates: Array[Dictionary] = []
	for support in SUPPORTS:
		if support["id"] == ignored_id or not overlaps_hero(support, hero_x):
			continue
		var support_y := hero_support_y(str(support["id"]))
		if previous_y <= support_y and next_y >= support_y:
			candidates.append(support)
	var floor := support_by_id(FLOOR_ID)
	if previous_y <= hero_support_y(FLOOR_ID) and next_y >= hero_support_y(FLOOR_ID):
		candidates.append(floor)
	var landing: Dictionary = {}
	var highest_y := INF
	for support in candidates:
		var support_y := hero_support_y(str(support["id"]))
		if support_y < highest_y:
			highest_y = support_y
			landing = support
	return landing
