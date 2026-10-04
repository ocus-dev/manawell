extends SceneTree

## SideViewActorVisual's animation states: locomotion picking, fallbacks when
## an actor has no clip for a state, actions with their own clips (registered
## as runtime clips here), priorities, death/revive, and the encounter wiring.

const Visual = preload("res://scripts/game/side_view_actor_visual.gd")
const Config = preload("res://scripts/game/side_view_visual_config.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_run()

func _run() -> void:
	_test_states_known()
	_test_fallbacks()
	_test_own_clips_and_priority()
	_test_death_and_revive()
	await _test_encounter_wiring()
	Config.runtime_frames.clear()
	Config.runtime_manifests.clear()
	Config.clear_disk_cache()
	print("PASS: animation states, fallbacks, priorities, death/revive and encounter wiring")
	quit(0)

func _visual(asset_id: String) -> Node2D:
	var visual := Visual.new()
	root.add_child(visual)
	assert(visual.configure(asset_id))
	return visual

## A tiny SpriteFrames standing in for an imported clip.
func _clip(state: String, frame_count: int = 3) -> SpriteFrames:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(StringName(state))
	frames.set_animation_loop(StringName(state), Config.loops(state))
	frames.set_animation_speed(StringName(state), 10.0)
	for index in range(frame_count):
		frames.add_frame(StringName(state), texture)
	return frames

func _register(folder: String, state: String) -> void:
	Config.runtime_frames["%s_%s" % [folder, state]] = _clip(state)
	Config.runtime_manifests["%s_%s" % [folder, state]] = {"cell_size": [8, 8], "union_crop": [284, 488, 292, 496]}

func _test_states_known() -> void:
	for state in ["idle", "walk", "attack", "windup", "hurt", "dash", "jump", "fall", "death", "spawn"]:
		assert(Config.STATES.has(state), "state %s listed" % state)
	assert(Config.loops("walk") and Config.loops("idle") and not Config.loops("attack") and not Config.loops("death"))
	var pursuer := Config.asset_for("pursuer")
	assert(Config.frames_for(pursuer, "walk") != null)
	assert(Config.frames_for(pursuer, "jump") == null, "no jump clip on disk yet")

func _test_fallbacks() -> void:
	var visual := _visual("pursuer")
	assert(visual.has_state("idle") and visual.has_state("walk") and visual.has_state("attack"))
	assert(not visual.has_state("hurt") and not visual.has_state("dash"))
	assert(visual.current_state == "idle" and visual.idle_sprite.visible)
	visual.set_locomotion(true)
	assert(visual.current_state == "walk" and visual.walk_sprite.visible and not visual.idle_sprite.visible)
	# Dash without a clip: the walk, faster, leaving afterimages.
	visual.set_dashing(true)
	assert(visual.current_state == "dash" and visual.walk_sprite.visible)
	assert(is_equal_approx(visual.walk_sprite.speed_scale, Visual.DASH_FALLBACK_SPEED))
	visual.advance_effects(0.1)
	assert(visual.afterimage_count() > 0, "afterimages while dashing")
	visual.set_dashing(false)
	assert(visual.current_state == "walk" and is_equal_approx(visual.walk_sprite.speed_scale, 1.0))
	visual.advance_effects(Visual.AFTERIMAGE_LIFETIME + 0.05)
	# Airborne without jump/fall clips: idle.
	visual.set_airborne(true, -50.0)
	assert(visual.current_state == "jump" and visual.idle_sprite.visible)
	visual.set_airborne(true, 50.0)
	assert(visual.current_state == "fall")
	visual.set_airborne(false)
	visual.set_locomotion(false)
	assert(visual.current_state == "idle")
	# Hurt without a clip: a tint that fades; the body keeps showing.
	visual.play_hurt()
	assert(visual.modulate != Color.WHITE and visual.idle_sprite.visible and visual.action_state.is_empty())
	visual.advance_effects(Visual.HURT_FLASH_SECONDS + 0.01)
	assert(visual.modulate == Color.WHITE)
	# Spawn without a clip: fade in.
	visual.play_spawn()
	assert(is_zero_approx(visual.modulate.a))
	visual.advance_effects(Visual.SPAWN_FADE_SECONDS * 0.5)
	assert(visual.modulate.a > 0.3 and visual.modulate.a < 0.7)
	visual.advance_effects(Visual.SPAWN_FADE_SECONDS)
	assert(is_equal_approx(visual.modulate.a, 1.0))
	# Wind-up without a clip: the attack, as before.
	var started := [0]
	visual.attack_started.connect(func() -> void: started[0] += 1)
	assert(not visual.play_windup())
	assert(visual.current_state == "attack" and visual.attack_sprite.visible and started[0] == 1)
	visual._on_attack_animation_finished()
	assert(visual.current_state == "idle" and visual.idle_sprite.visible)
	visual.free()

func _test_own_clips_and_priority() -> void:
	for state in ["hurt", "windup", "dash", "spawn"]:
		_register("pursuer", state)
	var visual := _visual("pursuer")
	assert(visual.has_state("hurt") and visual.has_state("windup") and visual.has_state("dash"))
	assert(visual.get_node_or_null("HurtSprite") != null, "state sprites are made on demand")
	# Locomotion with its own clip.
	visual.set_dashing(true)
	var dash_sprite: AnimatedSprite2D = visual.state_sprites["dash"]
	assert(visual.current_state == "dash" and dash_sprite.visible and not visual.walk_sprite.visible)
	assert(is_equal_approx(dash_sprite.speed_scale, 1.0), "own dash clip plays at its own speed")
	visual.set_dashing(false)
	# Hurt clip plays over locomotion, then hands back.
	visual.play_hurt()
	assert(visual.current_state == "hurt" and visual.state_sprites["hurt"].visible and not visual.idle_sprite.visible)
	visual.set_locomotion(true)
	assert(visual.current_state == "hurt", "locomotion waits for the action")
	visual._on_state_animation_finished("hurt")
	assert(visual.current_state == "walk" and visual.walk_sprite.visible)
	visual.set_locomotion(false)
	# Attack outranks hurt; hurt during an attack only tints.
	visual.play_attack()
	assert(visual.current_state == "attack")
	visual.play_hurt()
	assert(visual.current_state == "attack" and visual.modulate != Color.WHITE)
	visual._on_attack_animation_finished()
	# Own wind-up: telegraph, hold, then the attack when it lands.
	assert(visual.play_windup())
	assert(visual.current_state == "windup" and visual.state_sprites["windup"].visible)
	visual._on_state_animation_finished("windup")
	assert(visual.current_state == "windup", "wind-up holds its last frame")
	visual.play_attack()
	assert(visual.current_state == "attack" and visual.attack_sprite.visible and not visual.state_sprites["windup"].visible)
	visual._on_attack_animation_finished()
	# A wind-up that's never followed up gives up after the hold limit.
	visual.play_windup()
	visual.advance_effects(Visual.WINDUP_HOLD_LIMIT + 0.1)
	assert(visual.current_state == "idle")
	# Own spawn clip instead of the fade.
	visual.play_spawn()
	assert(visual.current_state == "spawn" and is_equal_approx(visual.modulate.a, 1.0))
	visual._on_state_animation_finished("spawn")
	assert(visual.current_state == "idle")
	# Reconfiguring without the clips drops them again.
	Config.runtime_frames.clear()
	Config.runtime_manifests.clear()
	assert(visual.configure("pursuer"))
	assert(not visual.has_state("hurt") and not visual.has_state("windup"))
	visual.free()

func _test_death_and_revive() -> void:
	# Code-driven death: fade and sink, then free when asked.
	var holder := Node2D.new()
	root.add_child(holder)
	var visual := Visual.new()
	holder.add_child(visual)
	assert(visual.configure("breaker"))
	var finished := [0]
	visual.death_finished.connect(func() -> void: finished[0] += 1)
	var start := visual.position
	visual.play_death(true)
	assert(visual.is_dying())
	visual.play_attack()
	assert(visual.current_state != "attack", "the dead don't attack")
	visual.advance_effects(Visual.DEATH_FADE_SECONDS * 0.5)
	assert(visual.modulate.a < 0.75 and visual.position.y > start.y)
	visual.advance_effects(Visual.DEATH_FADE_SECONDS)
	assert(finished[0] == 1 and visual.is_queued_for_deletion())
	holder.free()
	# Death clip: plays, holds, reports; revive brings the actor back.
	_register("ranged", "death")
	var ranged := _visual("ranged")
	var done := [0]
	ranged.death_finished.connect(func() -> void: done[0] += 1)
	ranged.play_death()
	assert(ranged.current_state == "death" and ranged.state_sprites["death"].visible and is_equal_approx(ranged.modulate.a, 1.0))
	ranged._on_state_animation_finished("death")
	assert(done[0] == 1 and not ranged.is_queued_for_deletion())
	ranged.revive()
	assert(not ranged.is_dying() and ranged.current_state == "idle" and ranged.idle_sprite.visible and ranged.modulate == Color.WHITE)
	Config.runtime_frames.clear()
	Config.runtime_manifests.clear()
	ranged.free()

func _test_encounter_wiring() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	await process_frame
	assert(controller.start_run())
	var enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	await process_frame
	assert(enemy.visual != null and enemy.visual.modulate.a < 1.0, "enemies fade in")
	enemy.take_damage(1.0)
	assert(enemy.visual._hurt_flash > 0.0, "a hit flashes the enemy")
	enemy.take_damage(enemy.health + 1.0)
	controller.simulate_step(1.0 / 60.0)
	var corpse: Node = controller.get_node_or_null("DyingEnemyVisual")
	assert(corpse != null and corpse.is_dying(), "the body stays to play its death")
	assert(enemy.is_queued_for_deletion() and enemy.visual == null, "but the enemy itself is gone from the fight")
	# The hero flashes on a hit, and dashing shows the dash state.
	controller.apply_enemy_damage(RunStateScript.DamageTarget.HERO, 1.0)
	assert(controller.hero.visual._hurt_flash > 0.0)
	assert(controller.try_dash(1))
	controller.simulate_step(1.0 / 60.0)
	assert(controller.hero.visual.current_state == "dash")
	controller.queue_free()
