extends SceneTree

## Mech (hero) drawn 1.5x and monsters 1.2x their calibrated art size, with the
## held weapon scaled in proportion about the feet. Hurtboxes are unchanged.

const Config = preload("res://scripts/game/side_view_visual_config.gd")
const Visual = preload("res://scripts/game/side_view_actor_visual.gd")
const HeroScript = preload("res://scripts/game/player.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")

func _init() -> void:
	_run()

func _run() -> void:
	assert(is_equal_approx(Config.HERO_DISPLAY_SCALE, 1.5))
	assert(is_equal_approx(Config.MONSTER_DISPLAY_SCALE, 1.2))
	for id in ["hero", "hero_2"]:
		assert(is_equal_approx(float(Config.asset_for(id).initial_visible_height), 80.0 * 1.5), "%s is 50%% bigger" % id)
	for pair in [["pursuer", 58.0], ["breaker", 112.0], ["ranged", 90.0]]:
		assert(is_equal_approx(float(Config.asset_for(pair[0]).initial_visible_height), float(pair[1]) * 1.2), "%s is 20%% bigger" % pair[0])
	assert(is_equal_approx(float(Config.asset_for("harvester").initial_visible_height), 190.0), "the harvester keeps its size")
	assert(Config.display_scale("a_monster_added_later") == Config.MONSTER_DISPLAY_SCALE)
	# Bodies grow about the feet: the ground point doesn't move.
	var visual := Visual.new()
	root.add_child(visual)
	assert(visual.configure("pursuer", 40.0))
	assert(is_equal_approx(visual.visible_top_local_y(), 40.0 - 58.0 * 1.2 * (float(Config.ASSETS.pursuer.ground_anchor.y) - float(Config.ASSETS.pursuer.visible_bounds.position.y)) / float(Config.ASSETS.pursuer.visible_bounds.size.y)))
	visual.free()
	# The held weapon and its socket scale with the mech, about its feet.
	var hero: Node2D = HeroScript.new()
	root.add_child(hero)
	await process_frame
	assert(is_equal_approx(hero.display_scale(), 1.5))
	assert(hero.weapon_socket.scale.is_equal_approx(Vector2(1.5, 1.5)))
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	hero.configure_held_weapon(ImageTexture.create_from_image(image))
	var rect: Rect2 = hero.held_weapon_world_rect()
	assert(absf(rect.size.y - HeroScript.HELD_WEAPON_GAME_REFERENCE_MAX_DIMENSION * 1.5) < 0.5, "weapon is 50%% bigger (%s)" % str(rect.size))
	hero.visual.idle_sprite.frame = 0
	hero._update_held_weapon_transform()
	var ground_y: float = hero.visual.ground_local_y
	var rest_y: float = hero._socket_rest_position(1.0).y
	assert(is_equal_approx(rest_y - ground_y, (HeroScript.WEAPON_SOCKET_LOCAL.y - ground_y) * 1.5), "socket stays on the scaled body")
	hero.queue_free()
	print("PASS: mech 1.5x with its weapon, monsters 1.2x, harvester unchanged")
	quit(0)
