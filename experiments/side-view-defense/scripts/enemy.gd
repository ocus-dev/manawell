class_name DefenseEnemy
extends Node2D

enum EnemyKind { PURSUER, BREAKER, RANGED }

const BalanceData = preload("res://data/balance.gd")
const RunStateScript = preload("res://data/run_state.gd")

var enemy_kind: EnemyKind = EnemyKind.PURSUER
var enemy_id: int = 0
var side: int = 1
var health: float = 1.0
var max_health: float = 1.0
var speed_pixels: float = 0.0
var attack_damage: float = 0.0
var attack_range_pixels: float = 0.0
var cooldown_remaining: float = 0.0
var windup_remaining: float = 0.0
var dead := false
var warning_visible := false
var warning_remaining := 0.0
var controller: Node

func setup(kind: EnemyKind, id: int, spawn_side: int, owner_controller: Node) -> void:
	enemy_kind = kind
	enemy_id = id
	side = -1 if spawn_side < 0 else 1
	controller = owner_controller
	_apply_stats()
	warning_remaining = 0.8
	warning_visible = true
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if dead or controller == null or controller.paused:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	warning_remaining = maxf(0.0, warning_remaining - delta)
	warning_visible = warning_remaining > 0.0 or windup_remaining > 0.0
	if enemy_kind == EnemyKind.RANGED:
		_simulate_ranged(delta)
	else:
		_simulate_melee(delta)
	queue_redraw()

func take_damage(amount: float) -> bool:
	if dead or not is_finite(amount) or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		dead = true
		queue_free()
		return true
	return true

func _simulate_melee(_delta: float) -> void:
	var target_x: float = controller.hero.position.x if enemy_kind == EnemyKind.PURSUER else controller.MACHINE_X
	var distance := absf(target_x - position.x)
	if distance > attack_range_pixels:
		var direction := signf(target_x - position.x)
		position.x += direction * speed_pixels * controller.FIXED_STEP
	else:
		if cooldown_remaining <= 0.0:
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO if enemy_kind == EnemyKind.PURSUER else RunStateScript.DamageTarget.MACHINE, attack_damage)
			cooldown_remaining = BalanceData.MELEE_ATTACK_INTERVAL

func _simulate_ranged(delta: float) -> void:
	var distance := absf(controller.hero.position.x - position.x)
	if windup_remaining > 0.0:
		windup_remaining = maxf(0.0, windup_remaining - delta)
		if is_zero_approx(windup_remaining):
			controller.spawn_hostile_projectile(position.x, controller.hero.position.x, attack_damage)
		return
	if distance > BalanceData.RANGED_STOP_RANGE * controller.SPATIAL_PIXELS_PER_UNIT:
		position.x += signf(controller.hero.position.x - position.x) * speed_pixels * controller.FIXED_STEP
	elif cooldown_remaining <= 0.0:
		windup_remaining = BalanceData.RANGED_WINDUP
		warning_remaining = BalanceData.RANGED_WINDUP

func _apply_stats() -> void:
	if enemy_kind == EnemyKind.PURSUER:
		max_health = BalanceData.PURSUER_HEALTH
		speed_pixels = BalanceData.PURSUER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.PURSUER_DAMAGE
		attack_range_pixels = BalanceData.PURSUER_RANGE * controller.SPATIAL_PIXELS_PER_UNIT
	elif enemy_kind == EnemyKind.BREAKER:
		max_health = BalanceData.BREAKER_HEALTH
		speed_pixels = BalanceData.BREAKER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.BREAKER_DAMAGE
		attack_range_pixels = BalanceData.BREAKER_RANGE * controller.SPATIAL_PIXELS_PER_UNIT
	else:
		max_health = BalanceData.RANGED_HEALTH
		speed_pixels = BalanceData.RANGED_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.RANGED_DAMAGE
	health = max_health

func _draw() -> void:
	var body_color := Color("d94d4d") if enemy_kind == EnemyKind.PURSUER else Color("b43d38") if enemy_kind == EnemyKind.BREAKER else Color("bb75d5")
	var height := 34.0 if enemy_kind == EnemyKind.BREAKER else 28.0
	draw_circle(Vector2.ZERO, 16.0, Color("111b21"))
	if enemy_kind == EnemyKind.BREAKER:
		draw_colored_polygon(PackedVector2Array([Vector2(-18.0, 0.0), Vector2(-13.0, -height), Vector2(13.0, -height), Vector2(18.0, 0.0)]), body_color)
		draw_line(Vector2(-13.0, -height * 0.55), Vector2(13.0, -height * 0.55), Color("f0c56b"), 3.0)
	elif enemy_kind == EnemyKind.RANGED:
		draw_rect(Rect2(-10.0, -height, 20.0, height), body_color, true)
		draw_line(Vector2(0.0, -height), Vector2(0.0, -height - 16.0), Color("f0c56b"), 4.0)
		draw_circle(Vector2(0.0, -height - 18.0), 5.0, Color("f0c56b"))
	else:
		draw_rect(Rect2(-12.0, -height, 24.0, height), body_color, true)
		draw_line(Vector2(-9.0, 0.0), Vector2(-15.0, 8.0), body_color, 5.0)
		draw_line(Vector2(9.0, 0.0), Vector2(15.0, 8.0), body_color, 5.0)
	if enemy_kind == EnemyKind.RANGED:
		draw_line(Vector2(-18.0, -height + 8.0), Vector2(18.0, -height + 8.0), Color("f0c56b"), 3.0)
	if warning_visible:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color("ffb347"), 3.0)
