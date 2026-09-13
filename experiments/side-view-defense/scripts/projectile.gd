class_name DefenseProjectile
extends Node2D

const RunStateScript = preload("res://data/run_state.gd")

var controller: Node
var start_x := 0.0
var end_x := 0.0
var velocity_x := 0.0
var damage := 0.0
var lifetime_remaining := 0.0
var hostile := false
var hit_target := false

func setup(owner_controller: Node, origin_x: float, target_x: float, projectile_damage: float, speed_units: float, lifetime: float, is_hostile: bool) -> void:
	controller = owner_controller
	position = Vector2(origin_x, controller.GROUND_Y - 58.0)
	start_x = origin_x
	end_x = target_x
	velocity_x = signf(target_x - origin_x) * speed_units * controller.SPATIAL_PIXELS_PER_UNIT
	damage = projectile_damage
	lifetime_remaining = lifetime
	hostile = is_hostile
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if hit_target or controller == null or controller.paused:
		return
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	var previous_x := position.x
	position.x += velocity_x * delta
	var crossed_target := (previous_x - end_x) * (position.x - end_x) <= 0.0
	if crossed_target:
		hit_target = true
		if hostile:
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, damage)
		else:
			var target: Node = controller.closest_live_enemy_between(start_x, position.x)
			if target != null:
				target.take_damage(damage)
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-10.0 if velocity_x < 0.0 else 10.0, 0.0), Vector2(10.0 if velocity_x < 0.0 else -10.0, 0.0), Color("ff9f43") if hostile else Color("66d9c4"), 4.0)
