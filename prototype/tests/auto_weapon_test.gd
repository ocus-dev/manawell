extends SceneTree

const AutoWeaponScript = preload("res://scripts/game/auto_weapon.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_gating_and_range()
	_test_projectile_hit_once()
	_test_kills_both_enemy_types()
	_test_elapsed_cadence_and_freed_targets()
	quit(0)

func _make_state() -> RefCounted:
	var state: RefCounted = RunStateScript.new()
	assert(state.start("weapon-test"))
	return state

func _make_enemy(state: RefCounted, kind: int, position: Vector3) -> Node3D:
	var enemy = EnemyScript.new()
	enemy.setup(kind, state, null)
	enemy.position = position
	get_root().add_child(enemy)
	return enemy

func _make_weapon(state: RefCounted, owner: Node3D, enemies: Array[Node3D]) -> Node:
	var weapon: Node = AutoWeaponScript.new()
	get_root().add_child(weapon)
	weapon.setup(owner, state)
	weapon.set_enemies(enemies)
	return weapon

func _test_gating_and_range() -> void:
	var ready_state: RefCounted = RunStateScript.new()
	var ready_owner := Node3D.new()
	ready_owner.position = Vector3.ZERO
	get_root().add_child(ready_owner)
	var ready_enemy: Node3D = _make_enemy(ready_state, EnemyScript.EnemyKind.PURSUER, Vector3(5.0, 0.0, 0.0))
	var ready_weapon: Node = _make_weapon(ready_state, ready_owner, [ready_enemy])
	ready_weapon.tick(1.0)
	assert(ready_weapon.shot_count == 0)
	ready_weapon.free()
	ready_enemy.free()
	ready_owner.free()

	var state: RefCounted = _make_state()
	var owner := Node3D.new()
	owner.position = Vector3.ZERO
	get_root().add_child(owner)
	var distant_enemy: Node3D = _make_enemy(state, EnemyScript.EnemyKind.PURSUER, Vector3(13.0, 0.0, 0.0))
	var weapon: Node = _make_weapon(state, owner, [distant_enemy])
	weapon.tick(1.0)
	assert(weapon.shot_count == 0)
	state.set_paused(true)
	weapon.tick(1.0)
	assert(weapon.shot_count == 0)
	weapon.free()
	distant_enemy.free()
	owner.free()

func _test_projectile_hit_once() -> void:
	var state: RefCounted = _make_state()
	var owner := Node3D.new()
	owner.position = Vector3.ZERO
	get_root().add_child(owner)
	var enemy: Node3D = _make_enemy(state, EnemyScript.EnemyKind.BREAKER, Vector3(5.0, 0.0, 0.0))
	var weapon: Node = _make_weapon(state, owner, [enemy])
	weapon.tick(0.6)
	assert(weapon.shot_count == 1)
	assert(is_equal_approx(enemy.health, 40.0))
	weapon.tick(0.0)
	assert(is_equal_approx(enemy.health, 40.0))
	weapon.free()
	enemy.free()
	owner.free()

func _test_kills_both_enemy_types() -> void:
	var state: RefCounted = _make_state()
	var owner := Node3D.new()
	owner.position = Vector3.ZERO
	get_root().add_child(owner)
	var pursuer: Node3D = _make_enemy(state, EnemyScript.EnemyKind.PURSUER, Vector3(5.0, 0.0, 0.0))
	var breaker: Node3D = _make_enemy(state, EnemyScript.EnemyKind.BREAKER, Vector3(6.0, 0.0, 0.0))
	var weapon: Node = _make_weapon(state, owner, [pursuer, breaker])
	for _shot in range(7):
		weapon.tick(0.6)
	assert(pursuer.dead)
	assert(breaker.dead)
	weapon.free()
	if is_instance_valid(pursuer):
		pursuer.free()
	if is_instance_valid(breaker):
		breaker.free()
	owner.free()

func _test_elapsed_cadence_and_freed_targets() -> void:
	var state: RefCounted = _make_state()
	var owner := Node3D.new()
	owner.position = Vector3.ZERO
	get_root().add_child(owner)
	var enemy: Node3D = _make_enemy(state, EnemyScript.EnemyKind.BREAKER, Vector3(11.0, 0.0, 0.0))
	var weapon: Node = _make_weapon(state, owner, [enemy])
	for _frame in range(3):
		weapon.tick(0.2)
	assert(weapon.shot_count == 1)
	for _frame in range(3):
		weapon.tick(0.2)
	assert(weapon.shot_count == 2)
	enemy.free()
	weapon.tick(0.6)
	assert(weapon.shot_count == 2)
	weapon.clear_projectiles()
	assert(weapon.projectiles.is_empty())
	weapon.free()
	owner.free()
