class_name DefenseEnemy
extends Node2D

enum EnemyKind { PURSUER, BREAKER, RANGED }

const BalanceData = preload("res://data/balance.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const VisualScript = preload("res://scripts/game/side_view_actor_visual.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")

var enemy_kind: EnemyKind = EnemyKind.PURSUER
var enemy_id: int = 0
var side: int = 1
var health: float = 1.0
var max_health: float = 1.0
var speed_pixels: float = 0.0
var attack_damage: float = 0.0
var attack_range_pixels: float = 0.0
var attack_interval: float = 1.0
var stop_range_pixels: float = 0.0
var windup_duration: float = 0.0
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
## Zone boss (see make_boss): tougher, bigger, labelled.
var is_boss := false
var boss_health_multiplier := 1.0
var boss_damage_multiplier := 1.0
var boss_size := 1.0
var visual: Node

func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "EnemyVisual"
	visual.z_index = 1
	add_child(visual)
	visual.configure(VisualConfigScript.enemy_asset(enemy_kind))
	visual.set_facing(-side)
	visual.play_spawn()

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
		var locomotion_threshold: float = attack_range_pixels if enemy_kind != EnemyKind.RANGED else stop_range_pixels
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
		if controller != null and controller.has_method("enqueue_enemy_death"):
			controller.enqueue_enemy_death(self)
		else:
			queue_free()
		return true
	if visual != null:
		visual.play_hurt()
	return true

## On death: hands the visual to `new_parent` (keeping its place on screen) so
## it can play its death animation after this enemy is freed. Presentation only.
func release_death_visual(new_parent: Node) -> void:
	if visual == null or not is_instance_valid(visual) or new_parent == null:
		return
	var body: Node2D = visual
	visual = null
	body.name = "DyingEnemyVisual"
	body.reparent(new_parent, true)
	body.play_death(true)

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
			cooldown_remaining = attack_interval

func _simulate_ranged(delta: float) -> void:
	var distance := absf(controller.hero.position.x - position.x)
	if windup_remaining > 0.0:
		windup_remaining = maxf(0.0, windup_remaining - delta)
		if is_zero_approx(windup_remaining):
			locked_target_point = CombatGeometryScript.body_center("hero", controller.hero.position)
			controller.spawn_hostile_projectile(position.x, locked_target_point.x, attack_damage, self, locked_target_point.y)
			# With its own wind-up clip, the shot gets the attack clip now.
			if visual != null and visual.has_state("windup"):
				visual.play_attack()
			# attack_interval is shot-to-shot time, so the wind-up counts toward it.
			cooldown_remaining = maxf(0.0, attack_interval - windup_duration)
		return
	if distance > stop_range_pixels:
		position.x += signf(controller.hero.position.x - position.x) * speed_pixels * controller.FIXED_STEP
	elif cooldown_remaining <= 0.0:
		windup_remaining = windup_duration
		warning_remaining = windup_duration
		if visual != null:
			visual.play_windup()

func monster_id() -> String:
	return MonsterStatsScript.id_for_kind(enemy_kind)

## Stats come from MonsterStats (data/monster_stats.json over data/balance.gd).
func _apply_stats() -> void:
	var id := monster_id()
	var pixels_per_unit: float = controller.SPATIAL_PIXELS_PER_UNIT if controller != null else 32.0
	max_health = MonsterStatsScript.get_stat(id, "health")
	speed_pixels = MonsterStatsScript.get_stat(id, "move_speed") * pixels_per_unit
	attack_damage = MonsterStatsScript.get_stat(id, "damage") * damage_multiplier
	attack_interval = MonsterStatsScript.get_stat(id, "attack_interval")
	if enemy_kind == EnemyKind.RANGED:
		stop_range_pixels = MonsterStatsScript.get_stat(id, "stop_range") * pixels_per_unit
		windup_duration = MonsterStatsScript.get_stat(id, "windup")
	else:
		attack_range_pixels = MonsterStatsScript.get_stat(id, "attack_range") * pixels_per_unit
	if is_boss:
		max_health *= boss_health_multiplier
		attack_damage *= boss_damage_multiplier
	health = max_health

## Turns this creature into the zone boss. `keep_health` is for restoring a
## saved boss mid-fight.
func make_boss(health_multiplier: float, damage_multiplier_scale: float, size: float, keep_health: bool = false) -> void:
	var current_health := health
	is_boss = true
	boss_health_multiplier = maxf(1.0, health_multiplier)
	boss_damage_multiplier = maxf(0.1, damage_multiplier_scale)
	boss_size = clampf(size, 1.0, 3.0)
	_apply_stats()
	if keep_health:
		health = clampf(current_health, 0.001, max_health)
	if visual != null:
		visual.set_scale_multiplier(boss_size)
	queue_redraw()

## Re-reads stats after a live edit, keeping the enemy's current health ratio.
func refresh_stats() -> void:
	if dead:
		return
	var health_ratio := clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 1.0
	_apply_stats()
	health = maxf(0.001, max_health * health_ratio)
	cooldown_remaining = minf(cooldown_remaining, attack_interval)
	queue_redraw()

func capture_snapshot_state() -> Dictionary:
	return {"boss": is_boss, "boss_health_multiplier": boss_health_multiplier, "boss_damage_multiplier": boss_damage_multiplier, "boss_size": boss_size, "side": side, "enemy_id": enemy_id, "damage_multiplier": damage_multiplier, "locked_target_point": [locked_target_point.x, locked_target_point.y], "warning_remaining": warning_remaining, "warning_visible": warning_visible, "damage_feedback_remaining": damage_feedback_remaining, "damage_feedback_amount": damage_feedback_amount}

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
	if bool(state.get("boss", false)):
		make_boss(float(state.get("boss_health_multiplier", 1.0)), float(state.get("boss_damage_multiplier", 1.0)), float(state.get("boss_size", 1.0)), true)

func _draw() -> void:
	var body_top: float = visual.visible_top_local_y() if visual != null else -34.0
	var health_ratio := clampf(health / max_health, 0.0, 1.0)
	if is_boss:
		# Wider, amber bar with a BOSS tag.
		draw_rect(Rect2(-45.0, body_top - 34.0, 90.0, 9.0), Color("111b21"), true)
		draw_rect(Rect2(-44.0, body_top - 33.0, 88.0 * health_ratio, 7.0), Color("f0a836"), true)
		draw_string(ThemeDB.fallback_font, Vector2(-45.0, body_top - 40.0), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, 90.0, 15, Color("ffd27a"))
	else:
		draw_rect(Rect2(-24.0, body_top - 32.0, 48.0, 6.0), Color("111b21"), true)
		draw_rect(Rect2(-23.0, body_top - 31.0, 46.0 * health_ratio, 4.0), Color("65d18b") if health_ratio > 0.35 else Color("e56b5d"), true)
	if warning_visible:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color("ffb347"), 3.0)
	if damage_feedback_remaining > 0.0:
		var feedback_alpha := clampf(damage_feedback_remaining / 0.65, 0.0, 1.0)
		var feedback_y: float = body_top - 40.0 - (1.0 - feedback_alpha) * 16.0
		draw_string(ThemeDB.fallback_font, Vector2(-24.0, feedback_y), "-%d" % roundi(damage_feedback_amount), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 14, Color(1.0, 0.78, 0.4, feedback_alpha))
