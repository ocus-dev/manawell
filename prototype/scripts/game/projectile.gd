class_name DefenseProjectile
extends Node2D

const RunStateScript = preload("res://scripts/model/run_state.gd")

var controller: Node
var start_x := 0.0
var end_x := 0.0
var velocity_x := 0.0
var direction_x := 1.0
var damage := 0.0
var lifetime_remaining := 0.0
var hostile := false
var hit_target := false

func setup(owner_controller: Node, origin_x: float, target_x: float, projectile_damage: float, speed_units: float, lifetime: float, is_hostile: bool, facing: int = 1, origin_y: float = -58.0) -> void:
	controller = owner_controller
	position = Vector2(origin_x, controller.GROUND_Y + origin_y)
	start_x = origin_x
	end_x = target_x
	direction_x = signf(target_x - origin_x)
	if is_zero_approx(direction_x):
		direction_x = -1.0 if facing < 0 else 1.0
	velocity_x = direction_x * speed_units * controller.SPATIAL_PIXELS_PER_UNIT
	damage = projectile_damage
	lifetime_remaining = lifetime
	hostile = is_hostile
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if hit_target or controller == null or controller.run_state.paused:
		return
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	var previous_x := position.x
	position.x += velocity_x * delta
	var hit := false
	var target: Node = null
	if hostile:
		hit = controller.is_hero_on_segment(previous_x, position.x)
	else:
		target = controller.closest_live_enemy_between(previous_x, position.x)
		hit = target != null
	if hit:
		hit_target = true
		if hostile:
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, damage)
		elif target != null:
			target.take_damage(damage)
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-10.0 if velocity_x < 0.0 else 10.0, 0.0), Vector2(10.0 if velocity_x < 0.0 else -10.0, 0.0), Color("ff9f43") if hostile else Color("66d9c4"), 4.0)
