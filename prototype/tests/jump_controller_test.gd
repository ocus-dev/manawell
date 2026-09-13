extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const HeroScript = preload("res://scripts/game/player.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	_test_variable_jump_and_landing()
	_test_coyote_and_buffer_expiry()
	_test_controller_dash_and_retry()
	assert(InputMap.action_get_events("jump")[0].physical_keycode == KEY_SPACE)
	assert(InputMap.action_get_events("dash")[0].physical_keycode == KEY_SHIFT)
	print("P04 jump controller checks passed")
	quit(0)

func _test_variable_jump_and_landing() -> void:
	var hero: Node = HeroScript.new()
	hero.position = Vector2(320.0, HeroScript.GROUND_SUPPORT_Y)
	hero.simulate_tick(1.0 / 60.0, 0.0, true, true)
	assert(not hero.grounded)
	assert(hero.position.y < HeroScript.GROUND_SUPPORT_Y)
	assert(hero.vertical_velocity < 0.0)
	hero.simulate_tick(1.0 / 60.0, 0.0, false, false)
	assert(is_equal_approx(hero.vertical_velocity, BalanceData.HERO_JUMP_RELEASE_VELOCITY + BalanceData.HERO_GRAVITY / 60.0))
	hero.simulate_tick(1.0, 0.0, false, false)
	assert(hero.grounded)
	assert(is_equal_approx(hero.position.y, HeroScript.GROUND_SUPPORT_Y))
	hero.simulate_tick(1.0 / 60.0, 0.0, false, true)
	assert(hero.grounded)
	hero.free()

func _test_coyote_and_buffer_expiry() -> void:
	var hero: Node = HeroScript.new()
	hero.position = Vector2(320.0, 450.0)
	hero.grounded = false
	hero.coyote_remaining = BalanceData.HERO_COYOTE_TIME
	hero.simulate_tick(1.0 / 60.0, 0.0, true, true)
	assert(hero.vertical_velocity < 0.0)
	hero.position = Vector2(320.0, 450.0)
	hero.grounded = false
	hero.vertical_velocity = 0.0
	hero.coyote_remaining = 0.0
	hero.jump_buffer_remaining = BalanceData.HERO_JUMP_BUFFER_TIME
	hero.simulate_tick(BalanceData.HERO_JUMP_BUFFER_TIME + 0.01, 0.0, false, true)
	assert(is_equal_approx(hero.jump_buffer_remaining, 0.0))
	assert(hero.vertical_velocity > 0.0)
	hero.free()

func _test_controller_dash_and_retry() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	assert(controller.start_run())
	controller.pending_jump = true
	controller.jump_held = true
	controller.simulate_step(1.0 / 60.0)
	assert(not controller.hero.grounded)
	var y_before_dash: float = controller.hero.position.y
	assert(controller.try_dash(1))
	controller.simulate_step(0.1)
	assert(controller.hero.position.y != y_before_dash)
	assert(controller.hero.vertical_velocity > BalanceData.HERO_JUMP_VELOCITY)
	var paused_y: float = controller.hero.position.y
	var paused_velocity: float = controller.hero.vertical_velocity
	controller.set_experiment_paused(true)
	controller.simulate_step(1.0)
	assert(is_equal_approx(controller.hero.position.y, paused_y))
	assert(is_equal_approx(controller.hero.vertical_velocity, paused_velocity))
	controller.set_experiment_paused(false)
	controller.run_state.phase = RunStateScript.Phase.FAILED
	controller.retry()
	assert(controller.hero.grounded)
	assert(is_equal_approx(controller.hero.position.y, HeroScript.GROUND_SUPPORT_Y))
	assert(is_equal_approx(controller.hero.vertical_velocity, 0.0))
	controller.queue_free()
