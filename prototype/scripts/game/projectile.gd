class_name DefenseProjectile
extends Node2D

const RunStateScript = preload("res://scripts/model/run_state.gd")
const ShotFxScript = preload("res://scripts/game/shot_fx.gd")
## The hero's bullet cycles its three electric frames this fast (seconds each).
const BULLET_FRAME_SECONDS := 0.05

var controller: Node
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var velocity := Vector2.ZERO
var direction := Vector2.RIGHT
var damage := 0.0
var lifetime_remaining := 0.0
var hostile := false
var hit_target := false
var owner_id := ""
var target_id := ""
var source_enemy_id: int = 0
var age := 0.0

func setup(owner_controller: Node, origin: Vector2, target: Vector2, projectile_damage: float, speed_units: float, lifetime: float, is_hostile: bool, facing: int = 1) -> void:
	controller = owner_controller
	position = origin
	start_position = origin
	target_position = target
	direction = (target - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2(-1.0 if facing < 0 else 1.0, 0.0)
	velocity = direction * speed_units * controller.SPATIAL_PIXELS_PER_UNIT
	damage = projectile_damage
	lifetime_remaining = lifetime
	hostile = is_hostile
	z_index = 3
	if not hostile:
		ShotFxScript.spawn(controller, ShotFxScript.MUZZLE, origin, direction)
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if hit_target or controller == null or controller.run_state.paused:
		return
	lifetime_remaining -= delta
	age += delta
	if lifetime_remaining <= 0.0:
		if not hostile:
			ShotFxScript.spawn(controller, ShotFxScript.IMPACT, position, direction)
		queue_free()
		return
	var previous_position := position
	position += velocity * delta
	var hit := false
	var target: Node = null
	if hostile:
		hit = controller.is_hero_on_segment(previous_position, position)
	else:
		target = controller.closest_live_enemy_between(previous_position, position)
		hit = target != null
	if hit:
		hit_target = true
		if hostile:
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, damage)
		elif target != null:
			target.take_damage(damage)
		if not hostile:
			ShotFxScript.spawn(controller, ShotFxScript.IMPACT, position, direction)
		queue_free()
	elif not hostile:
		queue_redraw()

## Hero bullets: the electric bullet art (tip at the projectile's position),
## cycling its frames. Enemy shots keep the orange streak.
func _draw() -> void:
	var aim := velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT
	if not hostile:
		var frames: Array = ShotFxScript.BULLET_FRAMES
		var frame := int(age / BULLET_FRAME_SECONDS) % frames.size()
		var tex: Texture2D = ShotFxScript.texture(str(frames[frame]))
		if tex != null:
			ShotFxScript.draw_pointing(self, tex, aim, ShotFxScript.BULLET_HEIGHT)
			return
	draw_line(-aim * 10.0, aim * 10.0, Color("ff9f43") if hostile else Color("66d9c4"), 4.0)
