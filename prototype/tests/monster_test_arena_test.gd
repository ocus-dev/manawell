extends SceneTree

const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const BalanceData = preload("res://data/balance.gd")
const TestCheckScript = preload("res://tests/test_check.gd")
const RegistryScript = preload("res://scripts/model/creature_registry.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")

const ARENA_SCENE := "res://scenes/tools/monster_test_arena.tscn"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	MonsterStatsScript.reset_all()
	await _check_arena()
	await _check_creatures()
	await _check_title_entry()
	MonsterStatsScript.reload()
	if failures == 0:
		print("PASS monster test arena: invincible dummy, per-monster damage numbers, add/remove, live encyclopedia edits, surge scaling, Creature Lab creatures, title entry")
		quit(0)
	else:
		push_error("monster test arena checks failed: %d" % failures)
		quit(1)

func _new_arena() -> Node:
	var arena: Node = load(ARENA_SCENE).instantiate()
	root.add_child(arena)
	# Drive the simulation by hand so results don't depend on frame timing.
	arena.set_physics_process(false)
	await process_frame
	return arena

func _check_arena() -> void:
	var arena: Node = await _new_arena()
	var dummy: Node2D = arena.dummy
	check(dummy != null and arena.hero == dummy, "dummy stands in for the hero")
	check(is_equal_approx(dummy.position.x, 640.0), "dummy is centered")
	check(arena.monster_encyclopedia != null, "arena attaches the encyclopedia")
	check(arena.monster_count() == 0, "arena starts empty")

	# Pursuer walks in from the right and hits the dummy.
	var pursuer: Node = arena.spawn_monster(EnemyScript.EnemyKind.PURSUER, 1)
	check(pursuer != null and pursuer.position.x > 640.0, "pursuer spawns on the right")
	arena.simulate_step(10.0)
	var pursuer_hits := int(arena.hits_by_monster.get("pursuer", 0))
	check(pursuer_hits > 0, "pursuer reaches and hits the dummy")
	check(is_equal_approx(arena.total_damage, pursuer_hits * BalanceData.PURSUER_DAMAGE), "damage meter adds up pursuer hits")
	check(is_equal_approx(arena.largest_hit, BalanceData.PURSUER_DAMAGE), "largest hit tracked")
	check(not dummy.numbers.is_empty(), "hits show floating damage numbers")
	check(dummy.numbers.back()["color"] == dummy.color_for("pursuer"), "numbers are colored by monster")
	check(arena.damage_per_second() > 0.0, "DPS reported")
	check(is_instance_valid(dummy) and arena.monster_count() == 1, "dummy survives and pursuer stays")

	# Live encyclopedia edit changes the next hits.
	arena.reset_meter()
	check(arena.total_damage == 0.0 and dummy.numbers.is_empty(), "reset meter clears totals and numbers")
	arena.monster_encyclopedia.open()
	check(arena.run_state.paused, "opening the encyclopedia pauses the arena")
	arena.monster_encyclopedia.set_stat("pursuer", "damage", 25.0)
	arena.monster_encyclopedia.close()
	arena.run_state.paused = false
	arena.simulate_step(2.5)
	check(is_equal_approx(arena.largest_hit, 25.0), "live damage edit reaches the next hits")

	# Surge level scales monster damage.
	arena.reset_meter()
	arena.set_surge_level(2)
	arena.simulate_step(2.5)
	check(is_equal_approx(arena.largest_hit, 25.0 * BalanceData.multiplier_for(2)), "surge multiplier applies to live monsters")
	arena.set_surge_level(0)
	MonsterStatsScript.reset_all()
	arena.apply_monster_stats()

	# Pause freezes the fight.
	arena.reset_meter()
	arena.set_experiment_paused(true)
	arena.simulate_step(3.0)
	check(arena.total_hits == 0, "paused arena deals no damage")
	arena.set_experiment_paused(false)

	# Breakers attack the dummy in place of the harvester; ranged shoot it.
	arena.clear_monsters()
	check(arena.monster_count() == 0, "clear all removes every monster")
	arena.reset_meter()
	arena.spawn_monster(EnemyScript.EnemyKind.BREAKER, -1)
	arena.spawn_monster(EnemyScript.EnemyKind.RANGED, 1)
	arena.simulate_step(15.0)
	check(int(arena.hits_by_monster.get("breaker", 0)) > 0, "breaker hits the dummy")
	check(is_equal_approx(float(arena.damage_by_monster.get("breaker", 0.0)), int(arena.hits_by_monster["breaker"]) * BalanceData.BREAKER_DAMAGE), "breaker damage attributed")
	check(int(arena.hits_by_monster.get("ranged", 0)) > 0, "ranged projectiles hit the dummy")
	check(is_equal_approx(float(arena.damage_by_monster.get("ranged", 0.0)), int(arena.hits_by_monster["ranged"]) * BalanceData.RANGED_DAMAGE), "ranged damage attributed")

	# Remove by kind, by click position, and by keyboard.
	check(arena.remove_monster_of_kind(EnemyScript.EnemyKind.RANGED), "remove newest ranged")
	check(arena.monster_count(EnemyScript.EnemyKind.RANGED) == 0, "ranged gone")
	check(not arena.remove_monster_of_kind(EnemyScript.EnemyKind.RANGED), "nothing left to remove")
	var breaker: Node = arena.enemies[0]
	var picked: Node = arena.monster_near(breaker.position + Vector2(0.0, -40.0))
	check(picked == breaker, "click picking finds the monster under the cursor")
	arena.remove_monster(picked)
	check(arena.monster_count() == 0, "picked monster removed")

	var key := InputEventKey.new()
	key.keycode = KEY_1 + arena.spawn_ids.find("ranged")
	key.pressed = true
	arena._unhandled_input(key)
	check(arena.monster_count(EnemyScript.EnemyKind.RANGED) == 1, "its number key adds a ranged monster")
	key.shift_pressed = true
	arena._unhandled_input(key)
	check(arena.monster_count() == 0, "shift + its number removes it")

	# Both-sides spawning alternates.
	arena.set_spawn_side(arena.SpawnSide.BOTH)
	var first: Node = arena.spawn_monster(EnemyScript.EnemyKind.PURSUER)
	var second: Node = arena.spawn_monster(EnemyScript.EnemyKind.PURSUER)
	check(first.side != second.side, "both-sides mode alternates spawn sides")
	for _i in range(BalanceData.MAX_LIVE_ENEMIES + 5):
		arena.spawn_monster(EnemyScript.EnemyKind.PURSUER)
	check(arena.monster_count() == BalanceData.MAX_LIVE_ENEMIES, "monster count is capped")
	arena.queue_free()
	await process_frame

## Creature Lab creatures can be spawned like the built-ins.
func _check_creatures() -> void:
	var temp := ProjectSettings.globalize_path("user://arena_creature_test")
	DirAccess.make_dir_recursive_absolute(temp.path_join("stills"))
	var still := Image.create_empty(576, 576, false, Image.FORMAT_RGBA8)
	still.fill_rect(Rect2i(200, 300, 180, 196), Color(0.4, 0.3, 0.5))
	still.save_png(temp.path_join("stills/test_spitter.png"))
	still.save_png(temp.path_join("stills/test_crusher.png"))
	RegistryScript.data_root = temp.path_join("data")
	RegistryScript.stills_root = temp.path_join("stills")
	RegistryScript.reload_index()
	for pair in [["test_spitter", "ranged", 90.0], ["test_crusher", "breaker", 224.0]]:
		RegistryScript.put_creature(pair[0], {"name": str(pair[0]).capitalize(), "family": "test", "stage": 1, "archetype": pair[1], "display_height": pair[2], "in_encyclopedia": true, "base_stats": {"damage": 3.0, "projectile_speed": 12.0}, "reference": {"still": temp.path_join("stills/%s.png" % pair[0]), "ground_anchor": [288, 495], "body_height": 196.0, "visible_bounds": [200, 300, 180, 196]}})
	MonsterStatsScript.reset_all()
	var arena: Node = await _new_arena()
	check(arena.spawn_ids == RegistryScript.sort_by_lineage(arena.spawn_ids) and arena.spawn_ids.has("pursuer") and arena.spawn_ids.has("test_spitter") and arena.spawn_ids.has("test_crusher"), "spawner lists every monster by family and stage")
	check(arena.spawn_rows.has("test_spitter") and arena.spawn_rows["test_spitter"].get_node("Icon").texture != null, "creature row with its picture")
	check(arena.spawn_search.visible, "search box once there are more than four monsters")
	var spitter: Node = arena.spawn_creature("test_spitter", 1)
	check(spitter != null and spitter.monster_override == "test_spitter" and spitter.enemy_kind == EnemyScript.EnemyKind.RANGED, "creature spawns with its archetype's AI")
	check(spitter.visual.asset_id == "test_spitter", "creature drawn with its own art")
	check(arena.monster_count_of("test_spitter") == 1 and arena.monster_count(EnemyScript.EnemyKind.RANGED) == 1, "counted by id and by kind")
	arena.reset_meter()
	arena.simulate_step(15.0)
	check(int(arena.hits_by_monster.get("test_spitter", 0)) > 0, "creature's shots hit the dummy")
	check(is_equal_approx(float(arena.damage_by_monster.get("test_spitter", 0.0)), int(arena.hits_by_monster["test_spitter"]) * 3.0), "creature's own damage stat used")
	check(not arena.hits_by_monster.has("ranged"), "hits credited to the creature, not its archetype")
	check(arena.dummy.color_for("test_spitter") != arena.dummy.color_for("ranged"), "creature has its own number color")
	arena._refresh_ui()
	check(arena.meter_rows["test_spitter"].visible, "meter row appears for the creature")
	check(arena.monster_near(spitter.position + Vector2(0.0, -40.0)) == spitter, "click picking finds a creature")
	var crusher_box := CombatGeometryScript.hurtbox_for_kind("test_crusher")
	check(is_equal_approx(crusher_box.size.y, CombatGeometryScript.BREAKER_HURTBOX.size.y * 2.0), "hurtbox scaled to the creature's height")
	check(arena.remove_monster_of_id("test_spitter") and arena.monster_count() == 0, "remove a creature by id")
	var index: int = arena.spawn_ids.find("test_crusher")
	var key := InputEventKey.new()
	key.keycode = KEY_1 + index
	key.pressed = true
	arena._unhandled_input(key)
	check(arena.monster_count_of("test_crusher") == 1, "number key adds the creature")
	key.shift_pressed = true
	arena._unhandled_input(key)
	check(arena.monster_count() == 0, "shift + number removes it")
	arena.place_picker.select(index + 1)
	arena.place_picker.item_selected.emit(index + 1)
	check(arena.place_id == "test_crusher", "click-to-place can pick a creature")
	arena.spawn_search.text = "crusher"
	arena._filter_spawn_rows()
	check(arena.spawn_rows["test_crusher"].visible and not arena.spawn_rows["pursuer"].visible, "search filters the list")
	# A creature taken out of the encyclopedia leaves the list on refresh.
	RegistryScript.put_creature("test_spitter", {"in_encyclopedia": false})
	arena.refresh_monster_list()
	check(not arena.spawn_ids.has("test_spitter") and arena.place_id == "test_crusher", "list refreshes and keeps the placement choice")
	arena.queue_free()
	await process_frame
	RegistryScript.data_root = RegistryScript.DEFAULT_DATA_ROOT
	RegistryScript.stills_root = RegistryScript.STILLS_ROOT
	RegistryScript.reload_index()
	RegistryScript.clear_art_cache()
	MonsterStatsScript.reset_all()
	for name in ["data/index.json", "stills/test_spitter.png", "stills/test_crusher.png"]:
		DirAccess.remove_absolute(temp.path_join(name))

func _check_title_entry() -> void:
	var scene: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var entry: Button = scene.get_node_or_null("Menu/MonsterTestArena")
	check(entry != null, "title screen has the monster arena entry")
	if entry != null:
		check(entry.get_index() < scene.get_node("Menu/Quit").get_index(), "arena entry sits above Quit")
		check(scene.get_node("Menu/DevEncyclopedia").get_index() == entry.get_index() - 1, "arena entry follows the encyclopedia")
	check(ResourceLoader.exists(scene.MONSTER_TEST_ARENA_SCENE), "arena scene path resolves")
	scene.queue_free()
	await process_frame
