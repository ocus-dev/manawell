extends SceneTree

## Creature Lab creatures in the level spawn editor and in the game: their
## rows and boss choice in the editor, custom levels spawning them with their
## own art and stats, the zone boss, saves, and weights kept for creatures
## that are out of the encyclopedia. Writes only under user://.

const LevelSpawns = preload("res://scripts/model/level_spawns.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")
const MonsterStats = preload("res://scripts/model/monster_stats.gd")
const Registry = preload("res://scripts/model/creature_registry.gd")
const EncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

var failures := 0
var temp := ""

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	temp = ProjectSettings.globalize_path("user://level_spawns_creatures_test")
	DirAccess.make_dir_recursive_absolute(temp.path_join("stills"))
	var still := Image.create_empty(576, 576, false, Image.FORMAT_RGBA8)
	still.fill_rect(Rect2i(200, 300, 180, 196), Color(0.4, 0.3, 0.5))
	for id in ["test_spitter", "test_crusher", "test_lurker"]:
		still.save_png(temp.path_join("stills/%s.png" % id))
	Registry.data_root = temp.path_join("data")
	Registry.stills_root = temp.path_join("stills")
	Registry.reload_index()
	_add("test_spitter", "spitters", "ranged", {"health": 33.0, "damage": 4.0})
	_add("test_crusher", "crushers", "breaker", {"health": 70.0})
	MonsterStats.reset_all()
	LevelSpawns.reload()

	await _check_editor()
	await _check_custom_level()
	_check_kept_weights()

	LevelSpawns.reload()
	Registry.data_root = Registry.DEFAULT_DATA_ROOT
	Registry.stills_root = Registry.STILLS_ROOT
	Registry.reload_index()
	Registry.clear_art_cache()
	MonsterStats.reset_all()
	for name in ["data/index.json", "stills/test_spitter.png", "stills/test_crusher.png", "stills/test_lurker.png"]:
		DirAccess.remove_absolute(temp.path_join(name))
	if failures == 0:
		print("PASS level spawns creatures: editor rows, families, filter, boss list, custom spawns, boss, saves, kept weights")
		quit(0)
	else:
		push_error("level spawns creature checks failed: %d" % failures)
		quit(1)

func _add(id: String, family: String, archetype: String, base_stats: Dictionary, listed: bool = true) -> void:
	Registry.put_creature(id, {"name": id.capitalize(), "family": family, "stage": 1, "archetype": archetype, "in_encyclopedia": listed, "base_stats": base_stats, "reference": {"still": temp.path_join("stills/%s.png" % id), "ground_anchor": [288, 495], "body_height": 196.0, "visible_bounds": [200, 300, 180, 196]}})

func _check_editor() -> void:
	var book: CanvasLayer = EncyclopediaScript.new()
	root.add_child(book)
	await process_frame
	book.open()
	book.show_tab("spawns")
	var page = book.spawns_page
	page.select_level("act_01_node_03")
	check(page.mix_rows.has("test_spitter") and page.mix_rows.has("test_crusher"), "creatures have weight rows")
	check(page.mix_list.get_node_or_null("Family_spitters") != null and page.mix_list.get_node_or_null("Family_crushers") != null, "creatures grouped by family")
	var boss_ids: Array = []
	for index in page.boss_picker.item_count:
		boss_ids.append(str(page.boss_picker.get_item_metadata(index)))
	check(boss_ids.has("test_crusher") and boss_ids.has("pursuer") and boss_ids.has("breaker") and boss_ids.has("ranged"), "creatures can be the boss")
	page.mix_filter.text = "crush"
	page._filter_mix_rows()
	check(page.mix_rows["test_crusher"].row.visible and not page.mix_rows["pursuer"].row.visible and not page.mix_list.get_node("Family_spitters").visible, "filter finds a creature by name/family")
	page.mix_filter.text = ""
	page._filter_mix_rows()
	page.set_mode(LevelSpawns.MODE_CUSTOM)
	page.mix_rows["pursuer"].slider.value = 0
	page.mix_rows["test_spitter"].slider.value = 100
	check(page.mix_rows["test_spitter"].share.text == "100%", "creature share shown")
	check(LevelSpawns.describe(LevelSpawns.profile("act_01_node_03")).contains("100% Test Spitter"), "summary names the creature")
	page.set_boss_monster("test_crusher")
	check(LevelSpawns.profile("act_01_node_03").boss_monster == "test_crusher", "boss set to a creature")
	check(LevelSpawns.describe_progress(LevelSpawns.profile("act_01_node_03")).contains("Test Crusher"), "progression line names the boss creature")
	# A creature added while the editor is open shows up on the next refresh.
	_add("test_lurker", "spitters", "pursuer", {})
	page.refresh()
	check(page.mix_rows.has("test_lurker"), "new creature gets a row")
	Registry.put_creature("test_lurker", {"in_encyclopedia": false})
	page.refresh()
	check(not page.mix_rows.has("test_lurker"), "removed creature's row goes")
	book.close()
	book.queue_free()
	await process_frame

func _check_custom_level() -> void:
	var profile := LevelSpawns.profile("act_01_node_03")
	profile.interval = 0.5
	GameFlow.preview_level_id = "act_01_node_03"
	GameFlow.preview_profile = profile
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	controller.simulate_step(3.0)
	controller._prune_enemies()
	check(not controller.enemies.is_empty(), "the level spawns")
	var all_creature := true
	for enemy in controller.enemies:
		all_creature = all_creature and enemy.monster_id() == "test_spitter" and enemy.enemy_kind == 2 and is_equal_approx(enemy.max_health, 33.0) and enemy.visual.asset_id == "test_spitter"
	check(all_creature, "every spawn is the creature: its AI, stats and art")
	# Saved runs keep which creature each enemy is.
	var snapshot: Dictionary = controller._capture_snapshot()
	var saved := false
	for actor in snapshot.get("actors", []):
		if str(actor.get("kind", "")) == "ranged":
			saved = str(actor["component_state"].get("monster", "")) == "test_spitter"
	check(saved, "snapshot records the creature id under its archetype's kind")
	# The zone boss can be a creature.
	controller._prune_enemies()
	for enemy in controller.enemies.duplicate():
		enemy.dead = true
	controller._prune_enemies()
	controller._spawn_zone_boss()
	check(controller.boss_enemy != null and controller.boss_enemy.monster_id() == "test_crusher" and controller.boss_enemy.is_boss, "boss is the creature")
	check(controller.boss_enemy.max_health > 70.0, "boss multiplier applies to the creature's health")
	controller.quit_to_title()
	await process_frame
	await process_frame
	GameFlow.reopen_spawn_editor_level = ""
	GameFlow.preview_level_id = ""
	GameFlow.preview_profile = {}

func _check_kept_weights() -> void:
	LevelSpawns.reload()
	LevelSpawns.set_mode("act_01_node_04", LevelSpawns.MODE_CUSTOM)
	LevelSpawns.set_weight("act_01_node_04", "test_crusher", 40.0)
	LevelSpawns.set_boss_monster("act_01_node_04", "test_crusher")
	var saved_json := LevelSpawns.to_json()
	# Out of the encyclopedia: kept in the data, not spawned, boss falls back.
	Registry.put_creature("test_crusher", {"in_encyclopedia": false})
	var parsed: Dictionary = JSON.parse_string(saved_json)
	LevelSpawns.set_profile("act_01_node_04", parsed.levels["act_01_node_04"])
	var profile := LevelSpawns.profile("act_01_node_04")
	check(is_equal_approx(float(profile.mix.get("test_crusher", 0.0)), 40.0), "weight kept while the creature is out")
	check(not LevelSpawns.shares(profile).has("test_crusher"), "but it doesn't spawn")
	check(LevelSpawns.boss_monster(profile) == LevelSpawns.DEFAULT_BOSS_MONSTER and profile.boss_monster == "test_crusher", "boss falls back, choice kept")
	Registry.put_creature("test_crusher", {"in_encyclopedia": true})
	check(LevelSpawns.shares(LevelSpawns.profile("act_01_node_04")).has("test_crusher"), "back in the mix when it returns")
