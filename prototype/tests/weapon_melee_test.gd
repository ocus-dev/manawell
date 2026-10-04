extends SceneTree

const ControllerScript = preload("res://scripts/game/encounter_controller.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var published := _published_weapon()
	assert(controller.account_state.grant_published_weapon(published.id), controller.account_state.inventory_command_error)
	controller.account_state.published_weapons[published.id].revision.behavior_id = "weapon.melee"
	# This test checks the plain socket placement: no authored hand offset.
	# It checks the plain built-in setup, so strip this weapon's own placement,
	# swing, animation and effects.
	var revision: Dictionary = controller.account_state.published_weapons[published.id].revision
	revision.get("pivot", {})["hand_offset"] = [0.0, 0.0]
	for key in ["swing", "attack_clip", "effects", "hand_fit"]:
		revision.erase(key)
	revision["clip_source"] = "none"
	var weapon_id := "designer:%s:%d" % [published.id, published.revision]
	assert(controller.account_state.equip_instance("hero_1", "weapon", weapon_id))
	assert(controller.start_run())
	assert(controller.weapon_behavior_id == "weapon.melee")
	assert(controller.hero.held_weapon.texture != null)
	assert(controller.hero.held_weapon.visible)
	var right_grip: Vector2 = controller.hero.held_weapon_grip_world_position()
	var right_socket: Vector2 = controller.hero.weapon_socket.global_position
	var right_bounds: Rect2 = controller.hero.held_weapon_world_rect()
	assert(right_grip.distance_to(right_socket) < 0.01, "right-facing grip stays attached to the socket")
	assert(maxf(right_bounds.size.x, right_bounds.size.y) <= 96.01 * controller.hero.display_scale() and right_bounds.size.x < 100.0 * controller.hero.display_scale(), "held art uses bounded gameplay scale instead of raw texture pixels")
	var long_weapon_texture: Texture2D = load("res://assets/weapons/batton of beating/1/world-sprite.png")
	controller.hero.configure_held_weapon(long_weapon_texture, Vector2(0.5, 0.75), "right", 1.0)
	var long_bounds: Rect2 = controller.hero.held_weapon_world_rect()
	assert(maxf(long_bounds.size.x, long_bounds.size.y) <= 96.01 * controller.hero.display_scale(), "long prepared weapons stay within the gameplay size bound")
	assert(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position) < 0.01, "long weapon grip stays attached")
	controller.hero.configure_held_weapon(long_weapon_texture, Vector2(0.5, 0.75), "left", 1.0)
	assert(controller.hero.held_weapon.scale.x < 0.0, "authored left-facing art is preserved")
	assert(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position) < 0.01, "authored facing preserves grip alignment")
	controller.hero.configure_held_weapon(long_weapon_texture, Vector2(0.5, 0.75), "right", 1.0)
	if "--capture-layout" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://../work/weapon-flow/w06-equipped-melee.png")
	var front: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	front.position = controller.hero.position + Vector2(32.0, 0.0)
	var second: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	second.position = controller.hero.position + Vector2(42.0, 0.0)
	var front_health: float = front.health
	var second_health: float = second.health
	controller.simulate_step(controller.weapon_interval)
	assert(controller.melee_phase == "windup")
	var delay_before_pause: float = controller.melee_strike_delay_remaining
	controller.set_experiment_paused(true)
	controller.simulate_step(1.0)
	assert(is_equal_approx(controller.melee_strike_delay_remaining, delay_before_pause))
	controller.set_experiment_paused(false)
	controller.move_right_held = true
	controller.simulate_step(0.05)
	controller.move_right_held = false
	assert(controller.hero.position.x > 320.0, "movement remains enabled during a swing")
	var snapshot: Dictionary = controller._capture_snapshot()
	var weapon_state: Dictionary = snapshot.weapon_state
	for field in ["behavior_id", "shot_accumulator", "phase", "strike_delay_remaining", "locked_facing", "target_id", "damage_committed"]:
		assert(weapon_state.has(field), "snapshot records " + field)
	var encoded := SnapshotScript.encode(snapshot)
	assert(encoded.valid, str(encoded.get("error", "snapshot encoding failed")))
	assert(SnapshotScript.decode(encoded.payload).valid)
	controller.simulate_step(controller.weapon_interval)
	assert(front.health < front_health, "locked target takes one strike")
	assert(is_equal_approx(second.health, second_health), "a swing remains single-target")
	var health_after_strike: float = front.health
	controller.melee_phase = "recovery"
	controller.melee_target_id = "enemy-%d" % front.enemy_id
	controller.melee_damage_committed = true
	controller._commit_melee_strike()
	assert(is_equal_approx(front.health, health_after_strike), "a resumed committed swing cannot deal duplicate damage")
	var idle_weapon_position: Vector2 = controller.hero.held_weapon.position
	var idle_weapon_rotation: float = controller.hero.held_weapon.rotation
	var idle_weapon_scale: Vector2 = controller.hero.held_weapon.scale
	controller.hero.visual._on_attack_animation_finished()
	controller.hero.visual.play_attack()
	assert(controller.hero.held_weapon.visible, "held art stays visible during baked-weapon attack clip")
	var windup_rotation: float = controller.hero.held_weapon.rotation
	controller.hero._process(0.08)
	var swing_rotation: float = controller.hero.held_weapon.rotation
	controller.hero._process(0.08)
	var recover_rotation: float = controller.hero.held_weapon.rotation
	assert(not is_equal_approx(windup_rotation, swing_rotation), "attack presentation advances through the swing")
	assert(not is_equal_approx(swing_rotation, recover_rotation), "attack presentation has a recover phase")
	assert(controller.hero.held_weapon_grip_world_position().distance_to(controller.hero.weapon_socket.global_position) < 0.01, "attack pose preserves authored grip alignment")
	controller.hero.visual._on_attack_animation_finished()
	assert(controller.hero.held_weapon.visible)
	assert(is_equal_approx(controller.hero.held_weapon.rotation, idle_weapon_rotation), "attack finish restores authored rotation")
	assert(controller.hero.held_weapon.position == idle_weapon_position, "attack finish restores authored position")
	assert(controller.hero.held_weapon.scale == idle_weapon_scale, "attack finish restores authored scale")
	controller.hero.visual.play_attack()
	assert(controller.hero.held_weapon.visible)
	controller.hero.interrupt_held_weapon_attack()
	assert(is_equal_approx(controller.hero.held_weapon.rotation, idle_weapon_rotation), "interruption restores authored rotation")
	assert(controller.hero.held_weapon.position == idle_weapon_position, "interruption restores authored position")
	controller.hero.last_facing = -1
	controller.hero.simulate_motion(0.0, 0.0, 0, false)
	assert(controller.hero.weapon_socket.position.x < 0.0)
	assert(controller.hero.held_weapon.scale.x < 0.0)
	var left_grip: Vector2 = controller.hero.held_weapon_grip_world_position()
	var left_socket: Vector2 = controller.hero.weapon_socket.global_position
	var left_bounds: Rect2 = controller.hero.held_weapon_world_rect()
	assert(left_grip.distance_to(left_socket) < 0.01, "left-facing grip stays attached to the socket")
	assert(left_bounds.size == long_bounds.size, "facing mirrors long held art without changing its bounds")
	controller.hero.last_facing = 1
	controller.hero.simulate_motion(0.0, 0.0, 0, false)
	var behind: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	behind.position = controller.hero.position + Vector2(-24.0, 0.0)
	var behind_health: float = behind.health
	controller.weapon_clock = controller.weapon_interval
	controller._cancel_melee_swing()
	controller.simulate_step(0.0)
	assert(controller.melee_target_id != "enemy-%d" % behind.enemy_id, "targets behind the hero are ignored")
	controller.run_state.apply_damage(0, 99999.0)
	controller._cancel_melee_swing()
	controller.weapon_clock = controller.weapon_interval
	controller.simulate_step(controller.weapon_interval * 0.2)
	assert(is_equal_approx(behind.health, behind_health), "death cancels an uncommitted strike")
	controller.queue_free()
	print("PASS W06 melee: target lock, single hit, cadence, movement, pause, death cancel, snapshot, facing, and held art")
	quit(0)

## Any weapon currently in the game (the tests used to rely on "light blade",
## which has since been removed in the Weapon Lab).
func _published_weapon() -> Dictionary:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/index.json"))
	var weapons: Dictionary = index.get("weapons", {}) if index is Dictionary else {}
	var ids: Array = weapons.keys()
	ids.sort()
	assert(not ids.is_empty(), "at least one weapon must be published")
	return {"id": str(ids[0]), "revision": int(weapons[ids[0]].get("revision", 1))}
