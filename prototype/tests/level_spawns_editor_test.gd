extends SceneTree

## Dev Encyclopedia > Level spawns: edit the tutorial's creatures, Preview it
## live, and come back to the editor on the same level.

const LevelSpawns = preload("res://scripts/model/level_spawns.gd")
const GameFlow = preload("res://scripts/model/game_flow.gd")
const MonsterStats = preload("res://scripts/model/monster_stats.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	LevelSpawns.reload()
	change_scene_to_file("res://scenes/title_screen.tscn")
	for i in 4: await process_frame
	var title: Node = current_scene
	var book = title.monster_encyclopedia
	book.open()
	book.show_tab("spawns")
	assert(book.spawns_page.visible and not book.monster_body.visible, "spawns tab replaces the monster page")
	var page = book.spawns_page
	page.select_level("tutorial")
	assert(page.level_buttons.has("tutorial") and page.level_buttons.size() >= 2, "tutorial + campaign levels listed")
	page.mode_buttons["custom"].emit_signal("pressed")
	assert(page.custom_box.visible)
	page.mix_rows["pursuer"].slider.value = 0
	page.mix_rows["ranged"].slider.value = 100
	page.setting_rows["interval"].spin.value = 0.5
	var profile := LevelSpawns.profile("tutorial")
	assert(profile.mode == "custom" and is_equal_approx(profile.interval, 0.5) and profile.mix.ranged == 100.0)
	assert(page.mix_rows["ranged"].share.text == "100%")
	assert(LevelSpawns.has_unsaved_changes())
	# Preview: straight into the tutorial with these (unsaved) settings.
	page.preview()
	for i in 6: await process_frame
	var controller: Node = current_scene
	assert(controller.preview_mode and controller.tutorial_mode, "preview opened the tutorial")
	controller.run_state.hero_health = 1.0e9
	controller.run_state.machine_integrity = 1.0e9
	controller.simulate_step(3.0)
	assert(not controller.enemies.is_empty(), "the tutorial spawns the previewed creatures")
	for enemy in controller.enemies:
		assert(MonsterStats.id_for_kind(enemy.enemy_kind) == "ranged")
	var back: Button = controller.encounter_hud.router.pause_panel.find_child("QuitToTitle", true, false)
	assert(back.text == "Back to spawn editor")
	back.emit_signal("pressed")
	for i in 6: await process_frame
	var again: Node = current_scene
	assert(again.scene_file_path == "res://scenes/title_screen.tscn")
	assert(again.monster_encyclopedia.is_open() and again.monster_encyclopedia.tab == "spawns", "editor reopened")
	assert(again.monster_encyclopedia.spawns_page.selected_level == "tutorial")
	assert(LevelSpawns.profile("tutorial").mode == "custom", "unsaved edits survive the preview")
	LevelSpawns.reload()
	print("PASS level spawns editor: tab, edit, live preview, back to editor")
	quit(0)
