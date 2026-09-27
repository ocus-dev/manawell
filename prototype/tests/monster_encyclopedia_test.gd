extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const EncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

const TEMP_PATH := "user://monster_stats_test.json"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	MonsterStatsScript.reset_all()
	_check_defaults_and_clamping()
	_check_import_export_and_disk()
	await _check_live_encounter()
	await _check_title_screen()
	MonsterStatsScript.reload()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	if failures == 0:
		print("PASS monster encyclopedia: stat registry, clamping, JSON round trip, live enemy refresh, real sprites, F9 and title entry")
		quit(0)
	else:
		push_error("monster encyclopedia checks failed: %d" % failures)
		quit(1)

func _check_defaults_and_clamping() -> void:
	check(MonsterStatsScript.monster_ids() == ["pursuer", "breaker", "ranged"], "monster order")
	check(is_equal_approx(MonsterStatsScript.get_stat("pursuer", "health"), BalanceData.PURSUER_HEALTH), "pursuer health default")
	check(is_equal_approx(MonsterStatsScript.get_stat("breaker", "damage"), BalanceData.BREAKER_DAMAGE), "breaker damage default")
	check(is_equal_approx(MonsterStatsScript.get_stat("ranged", "windup"), BalanceData.RANGED_WINDUP), "ranged windup default")
	check(MonsterStatsScript.modified_count() == 0, "defaults are unmodified")
	check(is_equal_approx(MonsterStatsScript.set_stat("pursuer", "health", 99999.0), 1000.0), "health clamps to max")
	check(is_equal_approx(MonsterStatsScript.set_stat("pursuer", "move_speed", 2.34), 2.3), "move speed snaps to step")
	check(MonsterStatsScript.is_modified("pursuer") and MonsterStatsScript.modified_count() == 1, "edit marks monster modified")
	MonsterStatsScript.set_stat("pursuer", "not_a_stat", 5.0)
	check(not MonsterStatsScript.export_map()["pursuer"].has("not_a_stat"), "unknown stat ignored")
	MonsterStatsScript.reset_monster("pursuer")
	check(not MonsterStatsScript.is_modified("pursuer"), "reset monster restores defaults")
	var shipped = JSON.parse_string(FileAccess.get_file_as_string(MonsterStatsScript.DATA_PATH))
	check(typeof(shipped) == TYPE_DICTIONARY and shipped.has("monsters"), "shipped data file parses")

func _check_import_export_and_disk() -> void:
	MonsterStatsScript.reset_all()
	var applied := MonsterStatsScript.apply_map({"monsters": {"breaker": {"health": 80, "bogus": 3}, "dragon": {"health": 1}}})
	check(applied == 1, "apply_map counts only known values")
	check(is_equal_approx(MonsterStatsScript.get_stat("breaker", "health"), 80.0), "apply_map sets value")
	var saved: Dictionary = MonsterStatsScript.save_to_disk(TEMP_PATH)
	check(saved["ok"], "save to temp path")
	check(not MonsterStatsScript.has_unsaved_changes(), "save clears unsaved flag")
	MonsterStatsScript.reset_all()
	check(MonsterStatsScript.load_from_disk(TEMP_PATH), "load from temp path")
	check(is_equal_approx(MonsterStatsScript.get_stat("breaker", "health"), 80.0), "round trip keeps value")
	MonsterStatsScript.reset_all()

func _check_live_encounter() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var tool: CanvasLayer = controller.monster_encyclopedia
	check(tool != null, "encounter attaches the encyclopedia in debug builds")
	var pursuer: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	check(is_equal_approx(pursuer.max_health, BalanceData.PURSUER_HEALTH), "enemy spawns with default health")
	pursuer.take_damage(10.0)
	tool.open()
	check(tool.is_open(), "open shows the panel")
	tool.select_monster("pursuer")
	tool.set_stat("pursuer", "health", 40.0)
	check(is_equal_approx(pursuer.max_health, 40.0), "live edit reaches spawned enemy")
	check(is_equal_approx(pursuer.health, 20.0), "live edit keeps health ratio")
	tool.set_stat("pursuer", "move_speed", 5.0)
	check(is_equal_approx(pursuer.speed_pixels, 5.0 * controller.SPATIAL_PIXELS_PER_UNIT), "live speed edit")
	var fresh: Node = controller.spawn_enemy(EnemyScript.EnemyKind.PURSUER, 1)
	check(is_equal_approx(fresh.max_health, 40.0), "new spawns use edited stats")
	var stats_box: VBoxContainer = tool.stats_box
	check(stats_box.get_child_count() == MonsterStatsScript.stat_keys("pursuer").size(), "one row per pursuer stat")
	tool.select_monster("ranged")
	check(tool.stats_box.get_child_count() == 7, "ranged shows its seven stats")
	for id in MonsterStatsScript.monster_ids():
		check(tool.sprite_texture(id) != null, "real game sprite for %s" % id)
		tool.select_monster(id)
		check(tool.portrait.texture != null, "portrait renders for %s" % id)
	check(tool.import_json("{ nope") != "", "invalid JSON rejected")
	check(tool.import_json("{\"ranged\": {\"projectile_speed\": 12}}") == "", "valid JSON imported")
	check(is_equal_approx(MonsterStatsScript.get_stat("ranged", "projectile_speed"), 12.0), "imported value applied")

	var ranged: Node = controller.spawn_enemy(EnemyScript.EnemyKind.RANGED, 1)
	ranged.windup_remaining = 0.01
	ranged.cooldown_remaining = 0.0
	controller.run_state.paused = false
	ranged._simulate_ranged(0.02)
	check(is_equal_approx(ranged.cooldown_remaining, ranged.attack_interval - ranged.windup_duration), "ranged waits its attack interval after firing")
	var hostile: Node = controller.projectiles.back()
	check(hostile != null and is_equal_approx(absf(hostile.velocity.length()), 12.0 * controller.SPATIAL_PIXELS_PER_UNIT), "projectile speed comes from MonsterStats")

	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	tool._input(key)
	check(not tool.is_open(), "F9 closes")
	tool._input(key)
	check(tool.is_open(), "F9 opens")
	tool.close()
	controller.queue_free()
	await process_frame
	MonsterStatsScript.reset_all()

func _check_title_screen() -> void:
	var scene: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var entry: Button = scene.get_node_or_null("Menu/DevEncyclopedia")
	check(entry != null, "title screen has the dev encyclopedia entry")
	check(entry.get_index() < scene.get_node("Menu/Quit").get_index(), "entry sits above Quit")
	entry.pressed.emit()
	check(scene.monster_encyclopedia.is_open(), "title entry opens the encyclopedia")
	scene.monster_encyclopedia.set_stat("breaker", "damage", 30.0)
	check(is_equal_approx(MonsterStatsScript.get_stat("breaker", "damage"), 30.0), "edits work without an encounter")
	scene.monster_encyclopedia.close()
	scene.queue_free()
	await process_frame
