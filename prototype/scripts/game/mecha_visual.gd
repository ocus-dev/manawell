extends Node3D
## Cosmetic presentation only: never rotates or moves the physics body.
var stride: float = 0.0
var recoil: float = 0.0
var aim_remaining: float = 0.0
var facing: Vector3 = Vector3.BACK
@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var model: Node3D = $Model

func _ready() -> void:
	# A small texture-colored fill keeps the dark generated paint readable overhead.
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(surface).duplicate()
			if material is StandardMaterial3D:
				material.emission_enabled = true
				material.emission = Color.WHITE
				material.emission_texture = material.albedo_texture
				material.emission_energy_multiplier = 0.15
				mesh.set_surface_override_material(surface, material)

func _process(delta: float) -> void:
	if not visible or actor == null:
		return
	var state = actor.get("run_state")
	if state != null and state.paused:
		return
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	aim_remaining = maxf(0.0, aim_remaining - delta)
	if speed > 0.1 and aim_remaining == 0.0:
		facing = Vector3(actor.velocity.x, 0, actor.velocity.z).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 12.0))
	stride += delta * minf(speed, 8.0) * 2.0
	recoil = move_toward(recoil, 0.0, delta * 0.7)
	model.position.y = absf(sin(stride)) * 0.035 * minf(speed / 6.0, 1.0)
	model.position.z = recoil
	model.rotation.x = -recoil * 0.6

func show_shot(target_position: Vector3) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		facing = direction.normalized()
	aim_remaining = 0.3
	recoil = 0.055
