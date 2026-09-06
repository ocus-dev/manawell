class_name WeaponProjectile
extends Node3D

var owner_node: Node3D
var target: Node3D
var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var lifetime_remaining: float = 0.0
var hit_target: bool = false

func setup(projectile_owner: Node3D, target_node: Node3D, projectile_damage: float, projectile_speed: float, lifetime: float, angle_degrees: float = 0.0) -> void:
	owner_node = projectile_owner
	target = target_node
	damage = projectile_damage
	lifetime_remaining = lifetime
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var start_position: Vector3 = projectile_owner.global_position if projectile_owner.is_inside_tree() else projectile_owner.position
	var direction := target_position - start_position
	direction.y = 0.0
	if not is_zero_approx(angle_degrees):
		direction = direction.rotated(Vector3.UP, deg_to_rad(angle_degrees))
	velocity = direction.normalized() * projectile_speed if direction.length_squared() > 0.0 else Vector3.ZERO
	position = start_position

func _ready() -> void:
	_build_visual()

func simulate_tick(delta: float) -> void:
	if hit_target or not is_finite(delta) or delta < 0.0:
		return
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var start_position: Vector3 = global_position if is_inside_tree() else position
	var end_position := start_position + velocity * delta
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	var closest_position := start_position
	if segment_length_squared > 0.0:
		var projection := clampf((target_position - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
		closest_position = start_position + segment * projection
	position = end_position
	if closest_position.distance_to(target_position) <= 0.55:
		_hit_target()

func _hit_target() -> void:
	if hit_target:
		return
	hit_target = true
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
		target.take_damage(damage)
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

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.9, 1.0, 1)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.45, 0.55, 1)
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material
	add_child(mesh_instance)
