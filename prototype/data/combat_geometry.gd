class_name CombatGeometry
extends RefCounted

const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")

const HERO_HURTBOX := Rect2(-18.0, -78.0, 36.0, 78.0)
const PURSUER_HURTBOX := Rect2(-18.0, -58.0, 36.0, 58.0)
const BREAKER_HURTBOX := Rect2(-28.0, -112.0, 56.0, 112.0)
const RANGED_HURTBOX := Rect2(-22.0, -90.0, 44.0, 90.0)
const MACHINE_HURTBOX := Rect2(-104.0, -190.0, 208.0, 190.0)

static func hurtbox_for_kind(kind: String) -> Rect2:
	match kind:
		"hero":
			return HERO_HURTBOX
		"pursuer":
			return PURSUER_HURTBOX
		"breaker":
			return BREAKER_HURTBOX
		"ranged":
			return RANGED_HURTBOX
		"machine":
			return MACHINE_HURTBOX
	return Rect2()

static func hurtbox_rect(kind: String, feet_position: Vector2) -> Rect2:
	var local := hurtbox_for_kind(kind)
	return Rect2(feet_position + local.position, local.size)

static func body_center(kind: String, feet_position: Vector2) -> Vector2:
	var box := hurtbox_rect(kind, feet_position)
	return box.get_center()

static func muzzle_position(kind: String, feet_position: Vector2, facing: int) -> Vector2:
	var local := VisualConfigScript.HERO_EMITTER_LOCAL if kind == "hero" else VisualConfigScript.RANGED_EMITTER_LOCAL
	var direction := -1.0 if facing < 0 else 1.0
	return feet_position + Vector2(local.x * direction, local.y)

static func circle_intersects_hurtbox(center: Vector2, radius: float, kind: String, feet_position: Vector2) -> bool:
	var rect := hurtbox_rect(kind, feet_position)
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) <= radius * radius

static func melee_hits(attacker_kind: String, attacker_position: Vector2, target_kind: String, target_position: Vector2, reach: float) -> bool:
	var attacker_box := hurtbox_rect(attacker_kind, attacker_position)
	var target_box := hurtbox_rect(target_kind, target_position)
	var expanded_attacker := attacker_box.grow_individual(reach, 0.0, reach, 0.0)
	return expanded_attacker.intersects(target_box)

static func segment_fraction_against_rect(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var delta := end - start
	var entry := 0.0
	var exit := 1.0
	for axis in 2:
		var origin := start.x if axis == 0 else start.y
		var direction := delta.x if axis == 0 else delta.y
		var minimum := rect.position.x if axis == 0 else rect.position.y
		var maximum := rect.end.x if axis == 0 else rect.end.y
		if is_zero_approx(direction):
			if origin < minimum or origin > maximum:
				return -1.0
			continue
		var inverse := 1.0 / direction
		var near_value := (minimum - origin) * inverse
		var far_value := (maximum - origin) * inverse
		if near_value > far_value:
			var swap := near_value
			near_value = far_value
			far_value = swap
		entry = maxf(entry, near_value)
		exit = minf(exit, far_value)
		if entry > exit:
			return -1.0
	return entry

static func platform_shots_are_open() -> bool:
	return true
