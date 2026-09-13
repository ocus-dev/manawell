class_name RangedEnemy
extends CharacterBody3D

const BalanceData = preload("res://data/balance.gd")
const ProjectileScript = preload("res://scripts/game/ranged_projectile.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

var run_state: RefCounted
var target: Node3D
var health: float = BalanceData.RANGED_HEALTH
var max_health: float = BalanceData.RANGED_HEALTH
var dead: bool = false
var damage_multiplier: float = 1.0
var cooldown_remaining: float = 0.0
var windup_remaining: float = 0.0
var projectile: Node3D
var projectiles: Array[Node3D] = []
var attack_count: int = 0
var telegraph_visual: MeshInstance3D
var id_allocator: Callable

func setup(state: RefCounted, target_node: Node3D, new_damage_multiplier: float = 1.0) -> void:
	run_state = state
	target = target_node
	damage_multiplier = new_damage_multiplier if is_finite(new_damage_multiplier) and new_damage_multiplier > 0.0 else 1.0
	max_health = BalanceData.RANGED_HEALTH
	health = max_health

func set_id_allocator(allocator: Callable) -> void:
	id_allocator = allocator

func _ready() -> void:
	_build_visuals()
	_build_telegraph()

func simulate_tick(delta: float) -> void:
	if dead or run_state == null or target == null or not is_finite(delta) or delta < 0.0:
		return
	if run_state.paused or (run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING):
		return
	if is_instance_valid(projectile) and not projectiles.has(projectile):
		projectiles.append(projectile)
	for active_projectile in projectiles:
		if is_instance_valid(active_projectile):
			active_projectile.simulate_tick(delta)
	projectiles = projectiles.filter(func(active_projectile: Node3D) -> bool:
		return is_instance_valid(active_projectile) and not active_projectile.is_queued_for_deletion()
	)
	if not projectiles.is_empty():
		projectile = projectiles.back()
	else:
		projectile = null
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if windup_remaining > 0.0:
		if telegraph_visual != null:
			telegraph_visual.visible = true
		windup_remaining = maxf(0.0, windup_remaining - delta)
		if is_zero_approx(windup_remaining):
			_fire()
		return
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var enemy_position: Vector3 = global_position if is_inside_tree() else position
	var offset := target_position - enemy_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > BalanceData.RANGED_STOP_RANGE:
		velocity = offset.normalized() * BalanceData.RANGED_SPEED if distance > 0.0 else Vector3.ZERO
		if is_inside_tree():
			move_and_slide()
	elif cooldown_remaining <= 0.0:
		velocity = Vector3.ZERO
		windup_remaining = BalanceData.RANGED_WINDUP

func take_damage(amount: float) -> bool:
	if dead or not is_finite(amount) or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		die()
	return true

func capture_snapshot_state() -> Dictionary:
	return {"damage_multiplier": damage_multiplier, "attack_damage": BalanceData.RANGED_DAMAGE * damage_multiplier}

func restore_snapshot_state(state: Dictionary) -> void:
	damage_multiplier = state["damage_multiplier"]

func die() -> void:
	if dead:
		return
	dead = true
	for active_projectile in projectiles:
		if is_instance_valid(active_projectile):
			active_projectile.free()
	projectiles.clear()
	projectile = null
	queue_free()

func _fire() -> void:
	if dead or target == null or not is_instance_valid(target):
		return
	if telegraph_visual != null:
		telegraph_visual.visible = false
	var projectile_instance = ProjectileScript.new()
	var origin: Vector3 = global_position if is_inside_tree() else position
	projectile_instance.setup(run_state, origin, target, BalanceData.RANGED_DAMAGE * damage_multiplier, BalanceData.RANGED_PROJECTILE_SPEED, BalanceData.RANGED_PROJECTILE_LIFETIME)
	if id_allocator.is_valid():
		projectile_instance.set_meta("snapshot_id", id_allocator.call())
	add_child(projectile_instance)
	projectile = projectile_instance
	projectiles.append(projectile_instance)
	cooldown_remaining = BalanceData.RANGED_ATTACK_INTERVAL
	attack_count += 1

func _build_visuals() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 1.5
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.2, 0.9, 1)
	material.roughness = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 1.5
	collision.shape = shape
	add_child(collision)

func _build_telegraph() -> void:
	telegraph_visual = MeshInstance3D.new()
	telegraph_visual.name = "AttackTelegraph"
	var mesh := CylinderMesh.new()
	mesh.top_radius = BalanceData.RANGED_STOP_RANGE * 0.12
	mesh.bottom_radius = BalanceData.RANGED_STOP_RANGE * 0.12
	mesh.height = 0.03
	telegraph_visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.1, 0.75)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.08, 0.02, 1.0)
	telegraph_visual.material_override = material
	telegraph_visual.position.y = -0.7
	telegraph_visual.visible = false
	add_child(telegraph_visual)
