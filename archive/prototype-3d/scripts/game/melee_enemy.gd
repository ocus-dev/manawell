class_name MeleeEnemy
extends CharacterBody3D

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")

enum EnemyKind {
	PURSUER,
	BREAKER,
}

var enemy_kind: EnemyKind = EnemyKind.PURSUER
var run_state: RefCounted
var target: Node3D
var health: float = 1.0
var max_health: float = 1.0
var movement_speed: float = 0.0
var attack_damage: float = 0.0
var attack_range: float = 0.0
var attack_cooldown: float = 0.0
var cooldown_remaining: float = 0.0
var damage_target: int = 0
var dead: bool = false
var damage_multiplier: float = 1.0

func setup(kind: EnemyKind, state: RefCounted, target_node: Node3D, new_damage_multiplier: float = 1.0) -> void:
	enemy_kind = kind
	run_state = state
	target = target_node
	damage_multiplier = new_damage_multiplier if is_finite(new_damage_multiplier) and new_damage_multiplier > 0.0 else 1.0
	_apply_stats()

func _ready() -> void:
	_apply_stats()
	_build_visuals()

func simulate_tick(delta: float) -> void:
	if dead or run_state == null or target == null or not is_finite(delta) or delta < 0.0:
		return
	if run_state.paused or (run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING):
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var enemy_position: Vector3 = global_position if is_inside_tree() else position
	var offset := target_position - enemy_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > attack_range:
		velocity = offset.normalized() * movement_speed if distance > 0.0 else Vector3.ZERO
		if is_inside_tree():
			move_and_slide()
	else:
		velocity = Vector3.ZERO
		if cooldown_remaining <= 0.0:
			if _apply_damage_to_target():
				cooldown_remaining = attack_cooldown

func _apply_damage_to_target() -> bool:
	if is_instance_valid(target) and target.has_method("receive_damage"):
		return target.receive_damage(attack_damage)
	return run_state.apply_damage(damage_target, attack_damage)

func take_damage(amount: float) -> bool:
	if dead or not is_finite(amount) or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		die()
	return true

func capture_snapshot_state() -> Dictionary:
	return {"damage_multiplier": damage_multiplier, "attack_damage": attack_damage}

func restore_snapshot_state(state: Dictionary) -> void:
	damage_multiplier = state["damage_multiplier"]
	attack_damage = state["attack_damage"]

func die() -> void:
	if dead:
		return
	dead = true
	queue_free()

func _apply_stats() -> void:
	if enemy_kind == EnemyKind.PURSUER:
		max_health = BalanceData.PURSUER_HEALTH
		movement_speed = BalanceData.PURSUER_SPEED
		attack_damage = BalanceData.PURSUER_DAMAGE * damage_multiplier
		attack_range = BalanceData.PURSUER_RANGE
		attack_cooldown = BalanceData.MELEE_ATTACK_INTERVAL
		damage_target = 0
	else:
		max_health = BalanceData.BREAKER_HEALTH
		movement_speed = BalanceData.BREAKER_SPEED
		attack_damage = BalanceData.BREAKER_DAMAGE * damage_multiplier
		attack_range = BalanceData.BREAKER_RANGE
		attack_cooldown = BalanceData.MELEE_ATTACK_INTERVAL
		damage_target = 1
	health = max_health

func _build_visuals() -> void:
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if enemy_kind == EnemyKind.PURSUER:
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.45
		mesh.height = 1.4
		mesh_instance.mesh = mesh
		material.albedo_color = Color(0.75, 0.12, 0.12, 1)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.38
		shape.height = 1.4
		_add_collision(shape)
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.2, 1.6, 1.2)
		mesh_instance.mesh = mesh
		material.albedo_color = Color(0.55, 0.08, 0.08, 1)
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.2, 1.6, 1.2)
		_add_collision(shape)
	material.roughness = 0.75
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _add_collision(shape: Shape3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
