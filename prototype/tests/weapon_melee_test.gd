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
	assert(controller.account_state.grant_published_weapon("light blade"), controller.account_state.inventory_command_error)
	controller.account_state.published_weapons["light blade"].revision.behavior_id = "weapon.melee"
	var weapon_id := "designer:light blade:1"
	assert(controller.account_state.equip_instance("hero_1", "weapon", weapon_id))
	assert(controller.start_run())
	assert(controller.weapon_behavior_id == "weapon.melee")
	assert(controller.hero.held_weapon.texture != null)
	assert(controller.hero.held_weapon.visible)
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
	controller.hero.visual.play_attack()
	assert(not controller.hero.held_weapon.visible, "baked-weapon attack clip hides held art")
	controller.hero.visual._on_attack_animation_finished()
	assert(controller.hero.held_weapon.visible)
	controller.hero.last_facing = -1
	controller.hero.simulate_motion(0.0, 0.0, 0, false)
	assert(controller.hero.weapon_socket.position.x < 0.0)
	assert(controller.hero.held_weapon.scale.x < 0.0)
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
