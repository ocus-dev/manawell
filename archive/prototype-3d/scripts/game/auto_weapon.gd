class_name AutoWeapon
extends Node

signal fired(target_position: Vector3)

const BalanceData = preload("res://data/balance.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

var owner_node: Node3D
var run_state: RefCounted
var enemies: Array[Node3D] = []
var projectiles: Array[Node3D] = []
var shot_accumulator: float = 0.0
var damage: float = BalanceData.WEAPON_DAMAGE
var attack_interval: float = BalanceData.WEAPON_INTERVAL
var range: float = BalanceData.WEAPON_RANGE
var projectile_speed: float = BalanceData.WEAPON_PROJECTILE_SPEED
var projectile_lifetime: float = BalanceData.WEAPON_PROJECTILE_LIFETIME
var shot_count: int = 0
var spread_enabled: bool = false
var id_allocator: Callable

func setup(weapon_owner: Node3D, state: RefCounted) -> void:
	owner_node = weapon_owner
	run_state = state

func set_id_allocator(allocator: Callable) -> void:
	id_allocator = allocator

func configure(new_damage: float, should_spread: bool) -> void:
	damage = new_damage if is_finite(new_damage) and new_damage > 0.0 else BalanceData.WEAPON_DAMAGE
	spread_enabled = should_spread

func set_enemies(enemy_list: Array[Node3D]) -> void:
	enemies = enemy_list

func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	_cleanup_projectiles()
	if run_state == null or (run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING):
		clear_projectiles()
		return
	if run_state.paused:
		return
	shot_accumulator += delta
	while shot_accumulator >= attack_interval:
		shot_accumulator -= attack_interval
		var target := _nearest_target()
		if target == null:
			continue
		_fire(target)
	_update_projectiles(delta)

func clear_projectiles() -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.free()
	projectiles.clear()
	shot_accumulator = 0.0

func capture_snapshot_state() -> Dictionary:
	return {"damage": damage, "spread_enabled": spread_enabled, "attack_interval": attack_interval, "shot_accumulator": shot_accumulator}

func restore_snapshot_state(state: Dictionary) -> void:
	damage = state["damage"]
	spread_enabled = state["spread_enabled"]
	attack_interval = state["attack_interval"]
	shot_accumulator = state["shot_accumulator"]

func _nearest_target() -> Node3D:
	if owner_node == null or not is_instance_valid(owner_node):
		return null
	var nearest: Node3D
	var nearest_distance: float = range
	var owner_position: Vector3 = owner_node.global_position if owner_node.is_inside_tree() else owner_node.position
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		if enemy.get("dead"):
			continue
		var enemy_position: Vector3 = enemy.global_position if enemy.is_inside_tree() else enemy.position
		var distance := owner_position.distance_to(enemy_position)
		if distance <= nearest_distance:
			if nearest == null or distance < nearest_distance:
				nearest = enemy
				nearest_distance = distance
	return nearest

func _fire(target: Node3D) -> void:
	fired.emit(target.global_position if target.is_inside_tree() else target.position)
	var angles: Array[float] = [0.0]
	if spread_enabled:
		angles = [-BalanceData.SPREAD_ANGLE_DEGREES, 0.0, BalanceData.SPREAD_ANGLE_DEGREES]
	for angle in angles:
		var projectile = ProjectileScript.new()
		projectile.setup(owner_node, target, damage, projectile_speed, projectile_lifetime, angle)
		if id_allocator.is_valid():
			projectile.set_meta("snapshot_id", id_allocator.call())
		add_child(projectile)
		projectiles.append(projectile)
		shot_count += 1

func _update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.simulate_tick(delta)
	_cleanup_projectiles()

func _cleanup_projectiles() -> void:
	projectiles = projectiles.filter(func(projectile: Node3D) -> bool:
		return is_instance_valid(projectile) and not projectile.is_queued_for_deletion()
	)
