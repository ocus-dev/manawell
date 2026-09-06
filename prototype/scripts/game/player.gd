extends CharacterBody3D

const BalanceData = preload("res://data/balance.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

@export var movement_speed: float = 6.0

var run_state: RefCounted
var dash_cooldown_remaining: float = 0.0
var pulse_cooldown_remaining: float = 0.0
var dash_remaining: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_active: bool = false
var ability_flash_remaining: float = 0.0

func setup_abilities(state: RefCounted) -> void:
	run_state = state

func reset_abilities() -> void:
	dash_cooldown_remaining = 0.0
	pulse_cooldown_remaining = 0.0
	dash_remaining = 0.0
	dash_direction = Vector3.ZERO
	dash_active = false
	ability_flash_remaining = 0.0

func get_input_direction() -> Vector3:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return get_camera_relative_direction(input_vector)

func _ready() -> void:
	if run_state == null:
		return

func simulate_tick(delta: float, movement_direction: Vector3 = Vector3.ZERO) -> void:
	if run_state != null and (run_state.paused or (run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING)):
		velocity = Vector3.ZERO
		return
	if run_state != null:
		simulate_ability_tick(delta)
	if not is_inside_tree():
		velocity = Vector3.ZERO
		return
	if dash_active:
		velocity = dash_direction * BalanceData.DASH_SPEED
		move_and_slide()
		return

	velocity.x = movement_direction.x * movement_speed
	velocity.z = movement_direction.z * movement_speed
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func simulate_ability_tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if run_state != null and run_state.paused:
		return
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	pulse_cooldown_remaining = maxf(0.0, pulse_cooldown_remaining - delta)
	ability_flash_remaining = maxf(0.0, ability_flash_remaining - delta)
	if dash_active:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		if is_zero_approx(dash_remaining):
			dash_active = false
			dash_direction = Vector3.ZERO

func try_dash(direction: Vector3) -> bool:
	if not _abilities_available() or dash_cooldown_remaining > 0.0 or dash_active:
		return false
	direction.y = 0.0
	if direction.length_squared() <= 0.0:
		direction = -global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() <= 0.0:
		return false
	dash_direction = direction.normalized()
	dash_remaining = BalanceData.DASH_DURATION
	dash_cooldown_remaining = BalanceData.DASH_COOLDOWN
	dash_active = true
	ability_flash_remaining = BalanceData.DASH_DURATION
	return true

func try_pulse(targets: Array[Node3D]) -> int:
	if not _abilities_available() or pulse_cooldown_remaining > 0.0:
		return 0
	pulse_cooldown_remaining = BalanceData.PULSE_COOLDOWN
	ability_flash_remaining = 0.2
	var hit_count: int = 0
	var origin: Vector3 = global_position if is_inside_tree() else position
	for target in targets:
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.get("dead") or not target.has_method("take_damage"):
			continue
		var target_position: Vector3 = target.global_position if target.is_inside_tree() else target.position
		if origin.distance_to(target_position) <= BalanceData.PULSE_RADIUS and target.take_damage(BalanceData.PULSE_DAMAGE):
			hit_count += 1
	_show_pulse_feedback()
	return hit_count

func receive_damage(amount: float) -> bool:
	if dash_active or run_state == null:
		return false
	return run_state.apply_damage(RunStateScript.DamageTarget.HERO, amount)

func is_dash_active() -> bool:
	return dash_active

func capture_snapshot_state() -> Dictionary:
	return {"dash_cooldown_remaining": dash_cooldown_remaining, "pulse_cooldown_remaining": pulse_cooldown_remaining, "dash_remaining": dash_remaining, "dash_direction": [dash_direction.x, dash_direction.y, dash_direction.z], "dash_active": dash_active, "ability_flash_remaining": ability_flash_remaining}

func restore_snapshot_state(state: Dictionary) -> void:
	dash_cooldown_remaining = state["dash_cooldown_remaining"]
	pulse_cooldown_remaining = state["pulse_cooldown_remaining"]
	dash_remaining = state["dash_remaining"]
	dash_direction = Vector3(state["dash_direction"][0], state["dash_direction"][1], state["dash_direction"][2])
	dash_active = state["dash_active"]
	ability_flash_remaining = state["ability_flash_remaining"]

func _abilities_available() -> bool:
	return run_state != null and not run_state.paused and (run_state.phase == RunStateScript.Phase.EXTRACTING or run_state.phase == RunStateScript.Phase.SEALING)

func _show_pulse_feedback() -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = BalanceData.PULSE_RADIUS
	mesh.bottom_radius = BalanceData.PULSE_RADIUS
	mesh.height = 0.04
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.85, 1.0, 0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	add_child(ring)
	if is_inside_tree():
		get_tree().create_timer(0.2).timeout.connect(ring.queue_free)
	else:
		ring.free()

static func get_camera_relative_direction(input_vector: Vector2, camera_basis: Basis = Basis.IDENTITY) -> Vector3:
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()
	var camera_right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var camera_forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z)
	if camera_right.length_squared() > 0.0:
		camera_right = camera_right.normalized()
	if camera_forward.length_squared() > 0.0:
		camera_forward = camera_forward.normalized()
	return (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
