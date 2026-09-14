class_name DefenseEnemy
extends Node2D

enum EnemyKind { PURSUER, BREAKER, RANGED }

const BalanceData = preload("res://data/balance.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")

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
var locked_target_point := Vector2.ZERO
var dead := false
var warning_visible := false
var warning_remaining := 0.0
var damage_feedback_remaining := 0.0
var damage_feedback_amount := 0.0
var controller: Node
var damage_multiplier: float = 1.0
var visual: Node

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "EnemyVisual"
	visual.z_index = 1
	add_child(visual)
	visual.configure(VisualConfigScript.enemy_asset(enemy_kind))
	visual.set_facing(-side)

func setup(kind: EnemyKind, id: int, spawn_side: int, owner_controller: Node, new_damage_multiplier: float = 1.0) -> void:
	enemy_kind = kind
	enemy_id = id
	side = -1 if spawn_side < 0 else 1
	controller = owner_controller
	damage_multiplier = new_damage_multiplier if is_finite(new_damage_multiplier) and new_damage_multiplier > 0.0 else 1.0
	_apply_stats()
	warning_remaining = 0.8
	warning_visible = true
	queue_redraw()

func simulate_tick(delta: float) -> void:
	if dead or controller == null or controller.run_state.paused:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	warning_remaining = maxf(0.0, warning_remaining - delta)
	damage_feedback_remaining = maxf(0.0, damage_feedback_remaining - delta)
	warning_visible = warning_remaining > 0.0 or windup_remaining > 0.0
	if enemy_kind == EnemyKind.RANGED:
		_simulate_ranged(delta)
	else:
		_simulate_melee(delta)
	if visual != null:
		visual.set_facing(-side)
		var locomotion_distance := absf(position.x - (controller.hero.position.x if enemy_kind == EnemyKind.PURSUER else controller.MACHINE_X))
		var locomotion_threshold: float = attack_range_pixels if enemy_kind != EnemyKind.RANGED else BalanceData.RANGED_STOP_RANGE * controller.SPATIAL_PIXELS_PER_UNIT
		visual.set_locomotion(locomotion_distance > locomotion_threshold)
	queue_redraw()

func take_damage(amount: float) -> bool:
	if dead or not is_finite(amount) or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	damage_feedback_amount = amount
	damage_feedback_remaining = 0.65
	if health <= 0.0:
		dead = true
		queue_free()
		return true
	return true

func _simulate_melee(_delta: float) -> void:
	var target_kind := "hero" if enemy_kind == EnemyKind.PURSUER else "machine"
	var target_position: Vector2 = controller.hero.position if enemy_kind == EnemyKind.PURSUER else Vector2(controller.MACHINE_X, controller.GROUND_Y)
	var target_x: float = target_position.x
	var distance := absf(target_x - position.x)
	if distance > attack_range_pixels:
		var direction := signf(target_x - position.x)
		position.x += direction * speed_pixels * controller.FIXED_STEP
	else:
		if cooldown_remaining <= 0.0 and CombatGeometryScript.melee_hits("pursuer" if enemy_kind == EnemyKind.PURSUER else "breaker", position, target_kind, target_position, attack_range_pixels):
			controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO if enemy_kind == EnemyKind.PURSUER else RunStateScript.DamageTarget.MACHINE, attack_damage)
			if visual != null:
				visual.play_attack()
			cooldown_remaining = BalanceData.MELEE_ATTACK_INTERVAL

func _simulate_ranged(delta: float) -> void:
	var distance := absf(controller.hero.position.x - position.x)
	if windup_remaining > 0.0:
		windup_remaining = maxf(0.0, windup_remaining - delta)
		if is_zero_approx(windup_remaining):
			locked_target_point = CombatGeometryScript.body_center("hero", controller.hero.position)
			controller.spawn_hostile_projectile(position.x, locked_target_point.x, attack_damage, self, locked_target_point.y)
		return
	if distance > BalanceData.RANGED_STOP_RANGE * controller.SPATIAL_PIXELS_PER_UNIT:
		position.x += signf(controller.hero.position.x - position.x) * speed_pixels * controller.FIXED_STEP
	elif cooldown_remaining <= 0.0:
		windup_remaining = BalanceData.RANGED_WINDUP
		warning_remaining = BalanceData.RANGED_WINDUP
		if visual != null:
			visual.play_attack()

func _apply_stats() -> void:
	if enemy_kind == EnemyKind.PURSUER:
		max_health = BalanceData.PURSUER_HEALTH
		speed_pixels = BalanceData.PURSUER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.PURSUER_DAMAGE * damage_multiplier
		attack_range_pixels = BalanceData.PURSUER_RANGE * controller.SPATIAL_PIXELS_PER_UNIT
	elif enemy_kind == EnemyKind.BREAKER:
		max_health = BalanceData.BREAKER_HEALTH
		speed_pixels = BalanceData.BREAKER_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.BREAKER_DAMAGE * damage_multiplier
		attack_range_pixels = BalanceData.BREAKER_RANGE * controller.SPATIAL_PIXELS_PER_UNIT
	else:
		max_health = BalanceData.RANGED_HEALTH
		speed_pixels = BalanceData.RANGED_SPEED * controller.SPATIAL_PIXELS_PER_UNIT
		attack_damage = BalanceData.RANGED_DAMAGE * damage_multiplier
	health = max_health

func capture_snapshot_state() -> Dictionary:
	return {"side": side, "enemy_id": enemy_id, "damage_multiplier": damage_multiplier, "locked_target_point": [locked_target_point.x, locked_target_point.y], "warning_remaining": warning_remaining, "warning_visible": warning_visible, "damage_feedback_remaining": damage_feedback_remaining, "damage_feedback_amount": damage_feedback_amount}

func restore_snapshot_state(state: Dictionary) -> void:
	side = -1 if int(state.get("side", side)) < 0 else 1
	enemy_id = int(state.get("enemy_id", enemy_id))
	damage_multiplier = float(state.get("damage_multiplier", damage_multiplier))
	var locked_point: Array = state.get("locked_target_point", [0.0, 0.0])
	locked_target_point = Vector2(float(locked_point[0]), float(locked_point[1]))
	warning_remaining = maxf(0.0, float(state.get("warning_remaining", 0.0)))
	warning_visible = bool(state.get("warning_visible", false))
	damage_feedback_remaining = maxf(0.0, float(state.get("damage_feedback_remaining", 0.0)))
	damage_feedback_amount = maxf(0.0, float(state.get("damage_feedback_amount", 0.0)))

func _draw() -> void:
	var body_top: float = visual.visible_top_local_y() if visual != null else -34.0
	var health_ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(-24.0, body_top - 32.0, 48.0, 6.0), Color("111b21"), true)
	draw_rect(Rect2(-23.0, body_top - 31.0, 46.0 * health_ratio, 4.0), Color("65d18b") if health_ratio > 0.35 else Color("e56b5d"), true)
	if warning_visible:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color("ffb347"), 3.0)
	if damage_feedback_remaining > 0.0:
		var feedback_alpha := clampf(damage_feedback_remaining / 0.65, 0.0, 1.0)
		var feedback_y: float = body_top - 40.0 - (1.0 - feedback_alpha) * 16.0
		draw_string(ThemeDB.fallback_font, Vector2(-24.0, feedback_y), "-%d" % roundi(damage_feedback_amount), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 14, Color(1.0, 0.78, 0.4, feedback_alpha))
