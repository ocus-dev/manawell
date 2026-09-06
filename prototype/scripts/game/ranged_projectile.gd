class_name RangedProjectile
extends Node3D

const RunStateScript = preload("res://scripts/model/run_state.gd")

var run_state: RefCounted
var target: Node3D
var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var lifetime_remaining: float = 0.0
var hit_target: bool = false

func setup(state: RefCounted, origin: Vector3, target_node: Node3D, projectile_damage: float, projectile_speed: float, lifetime: float) -> void:
	run_state = state
	position = origin
	target = target_node
	damage = projectile_damage
	lifetime_remaining = lifetime
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var direction := target_position - origin
	velocity = direction.normalized() * projectile_speed if direction.length_squared() > 0.0 else Vector3.ZERO

func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.35, 0.12, 1)
	material.emission_enabled = true
	material.emission = Color(0.6, 0.08, 0.02, 1)
	material.emission_energy_multiplier = 1.5
	mesh_instance.material_override = material
	add_child(mesh_instance)

func simulate_tick(delta: float) -> void:
	if hit_target or not is_finite(delta) or delta < 0.0:
		return
	if run_state == null or run_state.paused or (run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING):
		return
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var start_position := global_position if is_inside_tree() else position
	var end_position := start_position + velocity * delta
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var segment := end_position - start_position
	var closest_position := start_position
	if segment.length_squared() > 0.0:
		var projection := clampf((target_position - start_position).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest_position = start_position + segment * projection
	position = end_position
	if closest_position.distance_to(target_position) <= 0.7:
		hit_target = true
		if is_instance_valid(target) and target.has_method("receive_damage"):
			target.receive_damage(damage)
		elif run_state != null:
			run_state.apply_damage(RunStateScript.DamageTarget.HERO, damage)
		queue_free()

func capture_snapshot_state() -> Dictionary:
	var current_position: Vector3 = global_position if is_inside_tree() else position
	return {"position": [current_position.x, current_position.y, current_position.z], "velocity": [velocity.x, velocity.y, velocity.z], "damage": damage, "lifetime_remaining": lifetime_remaining, "hit_target": hit_target}

func restore_snapshot_state(state: Dictionary) -> void:
	var restored_position := Vector3(state["position"][0], state["position"][1], state["position"][2])
	if is_inside_tree():
		global_position = restored_position
	else:
		position = restored_position
	velocity = Vector3(state["velocity"][0], state["velocity"][1], state["velocity"][2])
	damage = state["damage"]
	lifetime_remaining = state["lifetime_remaining"]
	hit_target = state["hit_target"]
