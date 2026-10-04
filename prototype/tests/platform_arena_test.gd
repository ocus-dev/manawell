extends SceneTree

## The floating walkways were removed on 2026-09-28: the arena is floor only.
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const HeroScript = preload("res://scripts/game/player.gd")

func _init() -> void:
	assert(ArenaLayoutScript.platform_supports().is_empty(), "no platforms in the arena")
	assert(ArenaLayoutScript.support_by_id("platform_left").is_empty(), "the old platform ids are gone")
	assert(not ArenaLayoutScript.overlaps_hero({}, 300.0), "an unknown support never holds the hero")
	var hero: Node2D = HeroScript.new()
	hero.position = Vector2(320.0, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID))
	# A jump from the floor comes back down to the floor, where the platform used to be.
	hero.simulate_tick(1.0 / 60.0, 0.0, true, true)
	for step in range(120):
		hero.simulate_tick(1.0 / 60.0, 0.0, false, true)
	assert(hero.grounded and hero.support_id == ArenaLayoutScript.FLOOR_ID, "the hero lands on the floor")
	assert(is_equal_approx(hero.position.y, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID)))
	# A save made on an old platform falls back to the floor instead of erroring.
	hero.support_id = "platform_left"
	hero.simulate_tick(1.0 / 60.0, 0.0, false, true)
	for step in range(120):
		hero.simulate_tick(1.0 / 60.0, 0.0, false, true)
	assert(hero.support_id == ArenaLayoutScript.FLOOR_ID, "a removed platform drops the hero to the floor")
	hero.free()
	print("Platform arena checks passed (floor only)")
	quit(0)
