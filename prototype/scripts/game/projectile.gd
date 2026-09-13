class_name DefenseProjectile
extends Node2D

const RunStateScript = preload("res://scripts/model/run_state.gd")

var controller: Node
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var velocity := Vector2.ZERO
var velocity_x := 0.0
var direction := Vector2.RIGHT
var direction_x := 1.0
var damage := 0.0
var lifetime_remaining := 0.0
var hostile := false
var hit_target := false
var owner_id := ""
var target_id := ""
var source_enemy_id: int = 0
var pierce_remaining: int = 0
var hit_target_ids: Dictionary = {}

func setup(owner_controller: Node, origin: Vector2, target: Vector2, projectile_damage: float, speed_units: float, lifetime: float, is_hostile: bool, facing: int = 1, pierces: int = 0) -> void:
	controller = owner_controller
	position = origin
	start_position = origin
	target_position = target
	direction = (target - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2(-1.0 if facing < 0 else 1.0, 0.0)
	direction_x = direction.x
	velocity = direction * speed_units * controller.SPATIAL_PIXELS_PER_UNIT
	velocity_x = velocity.x
	damage = projectile_damage
	lifetime_remaining = lifetime
	hostile = is_hostile
	pierce_remaining = maxi(0, pierces)
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if hit_target or controller == null or controller.run_state.paused:
		return
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	var previous_position := position
	position += velocity * delta
	var hit := false
	var target: Node = null
	if hostile:
		hit = controller.is_hero_on_segment(previous_position, position)
	else:
		target = controller.closest_live_enemy_between(previous_position, position, hit_target_ids)
		hit = target != null
	if hit:
		hit_target = true
		if hostile:
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, damage)
		elif target != null:
			controller.apply_hero_attack_damage(target, damage, "gun")
			var target_key := "enemy-%d" % target.enemy_id
			hit_target_ids[target_key] = true
			if pierce_remaining > 0:
				pierce_remaining -= 1
			else:
				queue_free()
	queue_redraw()

func _draw() -> void:
	var aim := velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT
	draw_line(-aim * 10.0, aim * 10.0, Color("ff9f43") if hostile else Color("66d9c4"), 4.0)
