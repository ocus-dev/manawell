extends SceneTree

const HeroScript = preload("res://scripts/game/player.gd")
const ControllerScript = preload("res://scripts/game/encounter_controller.gd")

func _init() -> void:
	var hero: Node2D = HeroScript.new()
	hero.position = Vector2(640.0, 500.0)
	hero.simulate_tick(1.0 / 60.0, 1.0)
	assert(is_equal_approx(hero.position.x, 643.2))
	assert(hero.last_facing == 1)
	hero.simulate_tick(1.0 / 60.0, -1.0)
	assert(is_equal_approx(hero.position.x, 640.0))
	assert(hero.last_facing == -1)
	hero.position.x = HeroScript.RIGHT_BOUND
	hero.simulate_tick(1.0, 1.0)
	assert(is_equal_approx(hero.position.x, HeroScript.RIGHT_BOUND))
	hero.position.x = HeroScript.LEFT_BOUND
	hero.simulate_tick(1.0, -1.0)
	assert(is_equal_approx(hero.position.x, HeroScript.LEFT_BOUND))
	assert(is_equal_approx(HeroScript.normalized_horizontal_input(1.0, 1.0), 0.0))
	assert(is_equal_approx(HeroScript.normalized_horizontal_input(0.0, 1.0), 1.0))
	assert(is_equal_approx(HeroScript.normalized_horizontal_input(1.0, 0.0), -1.0))
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	assert(controller.start_run())
	controller.hero.last_facing = -1
	assert(controller.try_dash(0))
	assert(controller.dash_direction == -1)
	controller.retry()
	controller.queue_free()
	hero.free()
	print("2D movement checks passed")
	quit(0)
