extends SceneTree

## Weapon Lab: art preparation (solid-background cutout and PNG alpha), the
## run folder the publisher accepts, publishing a new weapon and an update
## revision, the weapon test arena (ranged and melee), and the title entry.
## Everything is written to temporary folders and removed afterwards.

const Art = preload("res://scripts/tools/weapon_lab_art.gd")
const ComfyScript = preload("res://scripts/tools/comfy_cutout.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Swing = preload("res://scripts/model/weapon_swing.gd")
const Effects = preload("res://scripts/model/weapon_effects.gd")
const EffectArt = preload("res://scripts/tools/weapon_effect_art.gd")
const Clip = preload("res://scripts/model/weapon_clip.gd")
const ClipImport = preload("res://scripts/tools/weapon_clip_import.gd")
const Types = preload("res://scripts/model/weapon_types.gd")
const HeroScript = preload("res://scripts/game/player.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const LabScript = preload("res://scripts/tools/weapon_lab.gd")
const Readiness = preload("res://scripts/model/weapon_readiness.gd")
const HeroAnims = preload("res://scripts/model/hero_animations.gd")
const VisualConfig = preload("res://scripts/game/side_view_visual_config.gd")
const ArenaScript = preload("res://scripts/tools/weapon_test_arena.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const BalanceData = preload("res://data/balance.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

const TEMP_USER := "user://weapon_lab_test"
const TEMP_RES := "res://tests/.tmp_weapon_lab"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	_clean()
	Art.repo_root_override = ProjectSettings.globalize_path(TEMP_USER.path_join("repo"))
	Art.receipt_root = TEMP_USER.path_join("jobs")
	MonsterStatsScript.reset_all()
	var source := _make_source()
	_check_art(source)
	await _check_lab(source)
	await _check_arena()
	await _check_title_entry()
	await _check_hero_animations()
	Art.repo_root_override = ""
	Art.receipt_root = Store.JOB_ROOT
	MonsterStatsScript.reload()
	_clean()
	if failures == 0:
		print("PASS weapon lab: solid/alpha cutouts, publisher-ready runs, new + update revisions, weapon arena ranged/melee, title entry")
		quit(0)
	else:
		push_error("weapon lab checks failed: %d" % failures)
		quit(1)

## A 200x120 "blade" (orange bar) on a flat teal backdrop.
func _make_source() -> String:
	DirAccess.make_dir_recursive_absolute(Art.sources_dir())
	var image := Image.create_empty(200, 120, false, Image.FORMAT_RGBA8)
	image.fill(Color8(40, 160, 150))
	image.fill_rect(Rect2i(30, 50, 140, 20), Color8(230, 120, 40))
	image.fill_rect(Rect2i(20, 40, 16, 40), Color8(90, 60, 40))
	var outside := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/Glow Blade.png"))
	DirAccess.make_dir_recursive_absolute(outside.get_base_dir())
	image.save_png(outside)
	return outside

func _check_art(outside: String) -> void:
	check(Art.slug("  Glow Blade #2! ") == "glow_blade_2", "slug makes ids")
	var parsed = JSON.parse_string('{"2": {"inputs": {"image": ["1", 0], "low_vram": true}}}')
	var graph: Dictionary = ComfyScript.restore_link_integers(parsed)
	check(typeof(graph["2"]["inputs"]["image"][1]) == TYPE_INT, "ComfyUI node links are sent as integers")
	var body: String = ComfyScript.prompt_json(JSON.parse_string('{"5": {"inputs": {"images": ["4", 0]}}}'), "t")
	check(body.contains("[\"4\",0]") and not body.contains("0.0"), "prompt body has integer link slots: %s" % body)
	var imported := Art.import_source(outside)
	check(imported.ok and imported.path == "art/ui-items/Weapons/glow_blade.png", "import copies into the Weapons folder")
	check(Art.import_source(outside).path == imported.path, "re-importing the same file reuses it")
	check(Art.list_sources().has(imported.path), "imported image is listed")
	var image := Image.load_from_file(Art.absolute_source(imported.path))
	check(not Art.has_transparency(image), "opaque source detected")
	var cut := Art.solid_background_cutout(image)
	check(Art.has_transparency(cut), "solid background cutout adds transparency")
	var bounds := Art.visible_bounds(cut)
	check(bounds == Rect2i(20, 40, 150, 40), "cutout keeps just the weapon (got %s)" % str(bounds))
	var prepared := Art.prepare(imported.path, cut, "solid", Vector2(0.1, 0.5), "", {"draft_id": "lab.test"})
	check(prepared.ok, "prepare writes a run: %s" % str(prepared.get("error", "")))
	var manifest := Art.load_manifest(str(prepared.job_id))
	check(manifest.get("status") == "complete" and manifest.get("kind") == "weapon-concept-preparation", "manifest matches the Python pipeline")
	for name in Art.OUTPUTS:
		check(FileAccess.file_exists(Art.run_dir(prepared.job_id).path_join(name)), "run has %s" % name)
	check(Art.is_complete(str(prepared.job_id)), "run verifies by hash")
	var world := Image.load_from_file(Art.run_dir(prepared.job_id).path_join("world-sprite.png"))
	check(world.get_height() == Art.WORLD_HEIGHT and world.get_width() == roundi(150.0 * Art.WORLD_HEIGHT / 40.0), "world sprite is 256 px tall and keeps the aspect")
	var icon := Image.load_from_file(Art.run_dir(prepared.job_id).path_join("square-icon.png"))
	check(icon.get_size() == Vector2i(Art.ICON_SIZE, Art.ICON_SIZE), "icon is square")
	check(FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_USER.path_join("jobs/%s.json" % prepared.job_id))), "job receipt written")
	# An already transparent PNG needs no cutout.
	var alpha := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	alpha.fill_rect(Rect2i(8, 20, 48, 10), Color.WHITE)
	var alpha_path := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/alpha.png"))
	alpha.save_png(alpha_path)
	var alpha_run := Art.prepare(alpha_path, null, "transparent")
	check(alpha_run.ok and Art.visible_bounds(Image.load_from_file(Art.run_dir(alpha_run.job_id).path_join("cropped-source.png"))).size == Vector2i(48, 10), "transparent PNG is trimmed to its pixels")
	var empty := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var empty_path := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/empty.png"))
	empty.save_png(empty_path)
	check(not Art.prepare(empty_path, null, "transparent").ok, "fully transparent source is rejected")

func _new_lab() -> Node:
	var lab: Node = LabScript.new()
	lab.data_root = TEMP_RES.path_join("data/weapons")
	lab.asset_root = TEMP_RES.path_join("assets/weapons")
	lab.draft_root = TEMP_USER.path_join("drafts")
	lab.loot_path = TEMP_USER.path_join("loot.json")
	root.add_child(lab)
	await process_frame
	return lab

func _check_lab(outside: String) -> void:
	var lab: Node = await _new_lab()
	check(lab.entries.is_empty() and lab.selected_id == lab.NEW_ID, "empty catalog opens a new weapon")
	lab.import_image(outside)
	check(lab.selected_source() == "art/ui-items/Weapons/glow_blade.png", "import selects the new source")
	check(lab.name_edit.text == "Glow Blade" and lab.draft.weapon_id == "glow_blade", "name and id come from the file name")
	check(not lab.publish().ok, "can't add to game before the art is prepared")
	lab.method_picker.select(2)
	await lab.prepare_art()
	check(Art.is_complete(str(lab.draft.art.job_id)), "Cut out & prepare produced a complete run")
	check(lab.world_preview.texture != null and lab.icon_preview.texture != null, "previews show the prepared art")
	lab.description_edit.text = "Hums when swung."
	lab.behavior_picker.select(1)
	check(is_equal_approx(float(lab.base_damage_spin.value), BalanceData.WEAPON_DAMAGE) and is_equal_approx(float(lab.base_rate_spin.value), 1.67), "new weapons start from the global baseline")
	lab.base_damage_spin.value = 24.0
	lab.base_rate_spin.value = 0.8
	lab.damage_spin.value = 3.0
	lab.rate_spin.value = 10.0
	var stats: Dictionary = lab.resolved_stats()
	check(is_equal_approx(stats.attack_damage, 27.0), "resolved damage is base 24 + bonus 3 (got %s)" % str(stats.attack_damage))
	check(is_equal_approx(stats.attacks_per_second, 0.88), "resolved attack speed is base 0.8 + 10%% (got %s)" % str(stats.attacks_per_second))
	lab.damage_spin.value = 20.0
	check(is_equal_approx(lab.resolved_stats().attack_damage, 36.0), "damage bonus caps at +50% of the weapon's own base")
	lab.damage_spin.value = 3.0
	lab.placement_spins["grip_x"].value = 0.12
	var result: Dictionary = lab.publish()
	check(result.ok, "new weapon published: %s" % result.message)
	var entry: Dictionary = lab.published_entry("glow_blade")
	check(int(entry.get("revision", 0)) == 1 and entry.get("behavior_id") == "weapon.melee", "index has revision 1 as melee")
	check(Catalog.validate_revision(entry, false).valid, "published revision validates")
	check(is_equal_approx(float(entry.pivot.grip[0]), 0.12), "placement published")
	check(is_equal_approx(float(entry.base_stats.attack_damage), 24.0) and is_equal_approx(float(entry.base_stats.attacks_per_second), 0.8), "base stats published")
	check(not Catalog.validate_revision(_with(entry, "base_stats", {"attack_damage": 0.0}), false).valid, "zero base damage rejected")
	check(not Catalog.validate_revision(_with(entry, "base_stats", {"crit": 2.0}), false).valid, "unknown base stat rejected")
	_check_game_uses_base_stats(entry)
	check(FileAccess.file_exists(ProjectSettings.globalize_path(str(entry.assets.world_sprite))), "world sprite installed")
	check(lab.is_published() and lab.id_edit.editable == false, "id locks once published")
	check(not lab.publish().ok, "publishing again with no changes is refused")
	lab.apply_pivot({"grip": [0.12, 0.5], "facing": "right", "world_scale": 1.3, "rotation_degrees": -20.0, "hand_offset": [4.0, -2.0]})
	lab._apply_placement_controls()
	result = lab.publish()
	check(result.ok, "placement update published: %s" % result.message)
	entry = lab.published_entry("glow_blade")
	check(int(entry.revision) == 2 and is_equal_approx(float(entry.pivot.world_scale), 1.3), "update is revision 2 with the new scale")
	var recipe = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(TEMP_RES.path_join("data/weapons/glow_blade/2/recipe.json"))))
	check(recipe is Dictionary and int(recipe.revision) == 2 and str(recipe.recipe_id).ends_with(".r2"), "revision 2 recipe written")
	check(FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_RES.path_join("data/weapons/glow_blade/1/definition.json"))), "revision 1 kept")
	lab.reload_entries()
	check(lab.entries.size() == 1 and int(lab.entries[0].revision) == 2, "index lists the weapon at r2")
	# Reopening rebuilds from the saved lab draft.
	lab.new_weapon()
	lab.select_entry("glow_blade")
	check(lab.draft.label == "Glow Blade" and lab.behavior_picker.selected == 1, "reopening restores the weapon")
	# Arena round trip carries placement back.
	lab.open_arena()
	check(lab.arena != null and not lab.ui.visible, "Test in arena opens the weapon arena")
	check(lab.arena.weapon_texture != null and lab.arena.is_melee(), "arena holds the prepared art as melee")
	lab.arena.set_pivot({"grip": [0.2, 0.4], "facing": "left", "world_scale": 0.8, "rotation_degrees": 15.0, "hand_offset": [10.0, 0.0]})
	lab.arena.return_to_title()
	check(lab.arena == null and lab.ui.visible, "Esc in the arena returns to the lab")
	check(lab.draft.art.facing == "left" and is_equal_approx(float(lab.draft.art.world_scale), 0.8), "arena placement comes back to the draft")
	check(lab.facing_picker.selected == 1, "placement controls refreshed")
	await _check_remove(lab)
	lab.queue_free()
	await process_frame

func _draft_path(name: String) -> String:
	return ProjectSettings.globalize_path(TEMP_USER.path_join("drafts/lab.%s.json" % name))

func _check_remove(lab: Node) -> void:
	# The glow blade is published (r2) with a lab draft.
	lab.select_entry("glow_blade")
	check(lab.remove_button.visible and lab.remove_button.text == "Remove", "published weapons offer Remove")
	lab.discard_draft()
	check(not FileAccess.file_exists(_draft_path("glow_blade")) and lab.is_published(), "discard draft keeps the published weapon")
	lab.save_draft()
	var result: Dictionary = lab.remove_weapon()
	check(result.ok, "remove: %s" % result.message)
	var index: Dictionary = lab.published_index()
	check(not index.weapons.has("glow_blade") and index.retired.has("glow_blade"), "removed weapon moves to retired")
	check(Catalog.validate_publication_index(index, false).valid, "index still validates")
	check(FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_RES.path_join("data/weapons/glow_blade/2/definition.json"))), "revision files are kept")
	check(not FileAccess.file_exists(_draft_path("glow_blade")), "its lab draft is deleted")
	check(lab.entries.all(func(entry: Dictionary) -> bool: return entry.id != "glow_blade"), "removed weapon leaves the list")
	lab.set_show_removed(true)
	check(lab.entries.any(func(entry: Dictionary) -> bool: return entry.id == "glow_blade" and entry.get("removed", false)), "show removed lists it")
	lab.select_entry("glow_blade")
	check(lab.is_removed() and lab.publish_button.text == "Restore to game" and not lab.remove_button.visible, "removed weapon offers Restore")
	lab.new_weapon()
	lab.name_edit.text = "Glow Blade"
	lab._on_name_changed("Glow Blade")
	check(not lab.publish().ok, "a removed weapon's id can't be reused")
	lab.select_entry("glow_blade")
	result = lab.restore_weapon()
	check(result.ok and int(lab.published_entry("glow_blade").get("revision", 0)) == 2 and lab.is_published(), "restore puts r2 back in the game")
	check(not lab.published_index().has("retired"), "retired list emptied")
	_check_swing(lab)
	await _check_effects(lab)
	await _check_clip(lab)
	# A draft that was never published is simply deleted.
	lab.new_weapon()
	lab.name_edit.text = "Scrap Idea"
	lab._on_name_changed("Scrap Idea")
	lab.save_draft()
	check(FileAccess.file_exists(_draft_path("scrap_idea")) and lab.remove_button.text == "Delete draft", "draft-only weapon offers Delete draft")
	lab.remove_weapon()
	check(not FileAccess.file_exists(_draft_path("scrap_idea")) and lab.entries.all(func(entry: Dictionary) -> bool: return entry.id != "scrap_idea"), "draft deleted")
	lab.set_show_removed(false)

func _check_swing(lab: Node) -> void:
	# Model: the default reproduces the original built-in curve.
	for t in [0.1, 0.4, 0.8]:
		var expected := lerpf(0.0, -25.0, t / 0.25) if t < 0.25 else (lerpf(-25.0, 75.0, (t - 0.25) / 0.35) if t < 0.6 else lerpf(75.0, 0.0, (t - 0.6) / 0.4))
		check(is_equal_approx(float(Swing.sample(Swing.DEFAULT, t).angle), expected), "default swing matches the old curve at %.1f" % t)
	var thrust := Swing.preset("thrust")
	check(Swing.sample(thrust, thrust.strike_time).offset.x > 20.0, "thrust pushes the weapon forward")
	check(Swing.validate(thrust).valid and not Swing.validate({"duration": 50.0}).valid and not Swing.validate({"windup_time": 0.7, "strike_time": 0.5}).valid, "swing validation")
	# Hero: a custom swing poses the weapon and ends on its own.
	var hero: Node2D = HeroScript.new()
	root.add_child(hero)
	hero.configure_held_weapon(ImageTexture.create_from_image(Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)))
	hero.configure_held_weapon_swing(thrust)
	hero._start_held_weapon_attack_presentation()
	hero._process(float(thrust.duration) * float(thrust.strike_time))
	check(hero.held_weapon_attack_active and hero.held_weapon_attack_offset.x > 20.0, "hero plays the thrust")
	hero._process(1.0)
	check(not hero.held_weapon_attack_active and hero.held_weapon_attack_offset == Vector2.ZERO, "custom swing finishes by itself")
	hero.configure_held_weapon_swing({})
	hero._start_held_weapon_attack_presentation()
	hero._process(0.1)
	check(hero.held_weapon_attack_offset == Vector2.ZERO and hero.held_weapon_attack_active, "no swing keeps the built-in motion")
	hero.queue_free()
	# Lab: the swing editor is gone (attack animations replace it), but a
	# weapon's swing data still publishes and plays.
	lab.select_entry("glow_blade")
	check(lab.swing_preview == null and lab.find_child("SwingPreset", true, false) == null, "no swing section in the lab")
	lab.apply_swing_preset("slash")
	check(str(lab.draft.swing.preset) == "slash", "swing data still settable")
	var result: Dictionary = lab.publish()
	check(result.ok, "swing published: %s" % result.message)
	var entry: Dictionary = lab.published_entry("glow_blade")
	check(entry.has("swing") and Catalog.validate_revision(entry, false).valid, "revision carries a valid swing")
	lab.open_arena()
	check(not lab.arena.weapon_hero.held_weapon_swing.is_empty() and lab.arena.find_child("WeaponTabs", true, false).get_child_count() == 1, "arena hero uses the swing; no Swing tab")
	lab.arena.return_to_title()
	lab.apply_swing_preset("default")
	check(lab.current_swing().is_empty(), "back to default stores no swing")
	# Research presets.
	var sword := Swing.preset("test_sword")
	check(Swing.preset_label("test_sword") == "Test swing sword" and Swing.preset_label("test_axe") == "Test swing ax", "research preset names")
	check(Swing.validate(sword).valid and Swing.validate(Swing.preset("test_axe")).valid, "research presets validate")
	var hit_progress := (1.0 / 1.67) * 0.4 / float(sword.duration)
	check(absf(float(Swing.sample(sword, hit_progress).angle) - 66.7) < 1.0, "sword hit lands mid-cut at about +67 degrees")
	var axe := Swing.preset("test_axe")
	var axe_mid := float(Swing.sample(axe, (float(axe.windup_time) + float(axe.strike_time)) * 0.5).angle)
	var linear_mid := (float(axe.windup_angle) + float(axe.strike_angle)) * 0.5
	check(axe_mid < linear_mid - 30.0, "negative snap: the axe accelerates late into the chop")
	check(is_equal_approx(float(Swing.sample(axe, 0.4 / float(axe.duration)).angle), float(axe.strike_angle)), "at 1.0 attacks/s the axe hit lands exactly at the end of the chop")

func _check_effects(lab: Node) -> void:
	# Model.
	var sword := Swing.preset("test_sword")
	check(is_equal_approx(Effects.trigger_seconds({"trigger": "strike"}, sword, 0.5, 0.24), 0.12), "strike trigger at the end of the wind-up")
	check(is_equal_approx(Effects.trigger_seconds({"trigger": "hit"}, sword, 0.5, 0.24), 0.24), "hit trigger at melee damage time")
	check(is_equal_approx(Effects.trigger_seconds({"trigger": "custom", "at": 0.8}, sword, 0.5, 0.24), 0.4), "custom trigger")
	check(not Effects.validate([{"sheet": "C:/x.png", "trigger": "hit"}]).valid and not Effects.validate([{"sheet": "res://a.png", "trigger": "boom"}]).valid, "effect validation")
	check(Effects.frame_rect({"frame_count": 6, "columns": 3}, Vector2(300, 200), 4) == Rect2(100, 100, 100, 100), "frame rect in a 3x2 sheet")
	# Art.
	var generated: Dictionary = EffectArt.generate_effect("spark_burst", "glow_blade")
	var strip := Image.load_from_file(str(generated.get("source", "")))
	check(strip != null and strip.get_width() == EffectArt.CELL * 8 and Art.has_transparency(strip), "generated spark strip")
	var frame_paths := PackedStringArray()
	for index in range(3):
		var frame := Image.create_empty(40, 30, false, Image.FORMAT_RGBA8)
		frame.fill_rect(Rect2i(index * 10, 5, 10, 10), Color.WHITE)
		var frame_path := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/burst_%02d.png" % index))
		frame.save_png(frame_path)
		frame_paths.append(frame_path)
	var packed: Dictionary = EffectArt.import_frames(frame_paths, "glow_blade")
	check(int(packed.get("frame_count", 0)) == 3 and Image.load_from_file(str(packed.source)).get_width() == 120, "frames packed into a strip")
	# Lab: attach, publish.
	lab.select_entry("glow_blade")
	lab.apply_swing_preset("test_sword")
	check(lab.effects_panel.generate("slash_arc") and lab.effects_panel.generate("spark_burst"), "generate effects in the lab")
	check(str(lab.draft.effects[0].source).contains("/glow_blade/"), "effect art saved under the weapon's folder")
	check(lab.draft.effects.size() == 2 and str(lab.draft.effects[0].trigger) == "strike" and str(lab.draft.effects[1].trigger) == "hit", "effects land in the draft with their triggers")
	lab.effects_panel.selected = 1
	lab.effects_panel.picking_anchor = true
	lab.effects_panel.set_selected_anchor(Vector2(0.97, 0.4))
	check(is_equal_approx(float(lab.draft.effects[1].anchor[0]), 0.97), "anchor picked on the sprite")
	for index in range(4):
		lab.effects_panel.add_effect(EffectArt.generate_effect("glow_pulse", "glow_blade"))
	check(lab.draft.effects.size() == Effects.MAX_EFFECTS, "effect count is capped")
	lab.effects_panel.selected = 3
	lab.effects_panel.remove_selected()
	lab.effects_panel.selected = 2
	lab.effects_panel.remove_selected()
	var result: Dictionary = lab.publish()
	check(result.ok, "effects published: %s" % result.message)
	var entry: Dictionary = lab.published_entry("glow_blade")
	check(entry.get("effects", []).size() == 2 and Catalog.validate_revision(entry, false).valid, "revision carries valid effects")
	var sheet := str(entry.effects[0].get("sheet", ""))
	check(sheet.begins_with(TEMP_RES) and sheet.ends_with("effects/0.png") and FileAccess.file_exists(ProjectSettings.globalize_path(sheet)) and not entry.effects[0].has("source"), "sheets copied into the revision's assets")
	check(not lab.publish().ok, "unchanged effects don't publish again")
	# Game: the hero fires them at their trigger times.
	var holder := Node2D.new()
	root.add_child(holder)
	var hero: Node2D = HeroScript.new()
	holder.add_child(hero)
	hero.configure_held_weapon(ImageTexture.create_from_image(Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)))
	hero.configure_held_weapon_swing(Swing.preset("test_sword"))
	hero.configure_held_weapon_effects(entry.effects, 0.24)
	check(hero.held_weapon_effects.size() == 2, "hero loads the published sheets")
	hero._start_held_weapon_attack_presentation()
	hero._process(0.13)
	check(hero.effects_spawned == 1 and hero.held_weapon.get_child_count() >= 1, "slash trail fires at the strike and rides on the weapon")
	hero._process(0.12)
	check(hero.effects_spawned == 2 and holder.get_children().any(func(child: Node) -> bool: return child.name.begins_with("WeaponEffect")), "sparks fire at the hit and stay in the world")
	var effect_node: Node = holder.get_children().filter(func(child: Node) -> bool: return child.name.begins_with("WeaponEffect"))[0]
	effect_node.advance(10.0)
	check(effect_node.is_queued_for_deletion(), "effects free themselves when done")
	holder.queue_free()
	# Arena gets them too.
	lab.open_arena()
	check(lab.arena.weapon_hero.held_weapon_effects.size() == 2, "arena hero has the effects")
	lab.arena.return_to_title()
	lab.apply_swing_preset("default")
	await process_frame

## A ChatGPT-style pose sheet: grey backdrop, dark screenshot border, three
## red "mechs" standing on a ground line at different spots in their slots,
## an arrow annotation, the middle pose's weapon poking into the next slot, and
## caption blocks under the line.
func _make_pose_sheet() -> String:
	var image := Image.create_empty(330, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color8(224, 224, 224))
	image.fill_rect(Rect2i(0, 0, 4, 200), Color8(20, 20, 20))
	image.fill_rect(Rect2i(326, 0, 4, 200), Color8(20, 20, 20))
	image.fill_rect(Rect2i(4, 130, 322, 3), Color8(40, 40, 40))
	for index in range(3):
		var feet_x: int = [40, 170, 290][index] - [10, 0, 14][index]
		image.fill_rect(Rect2i(feet_x - 12, 70, 24, 45), Color8(200, 40, 40))
		image.fill_rect(Rect2i(feet_x - 10, 115, 8, 15), Color8(60, 60, 70))
		image.fill_rect(Rect2i(feet_x + 2, 115, 8, 15), Color8(60, 60, 70))
		image.fill_rect(Rect2i(feet_x - 5, 85, 10, 10), Color8(224, 224, 224))
		image.fill_rect(Rect2i(8 + index * 108, 150, 60, 8), Color8(60, 60, 60))
	# Pose 2's axe reaches past the gap into slot 3.
	image.fill_rect(Rect2i(182, 80, 44, 6), Color8(90, 90, 110))
	# A motion arrow floating over pose 1.
	image.fill_rect(Rect2i(60, 40, 5, 3), Color8(120, 120, 120))
	var path := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/axe_sheet.png"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	return path

func _check_clip(lab: Node) -> void:
	# Model: timing is fitted so the hit frame lands with the game's damage.
	var clip := Clip.normalize({"frame_count": 6, "frame_ms": [100, 100, 100, 100, 100, 100], "attacks": Clip.attacks_from_marks(6, [3], [1, 4])})
	check(clip.attacks.size() == 2 and int(clip.attacks[0].hit) == 1 and int(clip.attacks[1].start) == 3 and int(clip.attacks[1].hit) == 4, "combo attacks from start/hit marks")
	var line := Clip.timeline(clip, 0, 0.24)
	check(is_equal_approx(float(line.hit_time), 0.24) and is_equal_approx(float(line.fit), 2.4) and is_equal_approx(float(line.length), 0.44), "lead-up stretched so the hit frame shows at 0.24 s; follow-through keeps its pace")
	check(Clip.frame_at(line, 0.0) == 0 and Clip.frame_at(line, 0.3) == 1 and Clip.frame_at(line, 0.4) == 2 and Clip.frame_at(line, 0.5) == -1, "frame lookup over the fitted timeline")
	check(Clip.timeline(clip, 1, 0.0).frames == [3, 4, 5] and is_equal_approx(float(Clip.timeline(clip, 1, 0.0).fit), 1.0), "second attack; ranged plays at its own speed")
	check(not Clip.validate({"sheet": "C:/a.png", "mode": "hero", "frame_count": 1, "cell": [1, 1], "anchor": [0, 0], "frame_ms": [80]}).valid and Clip.validate({"sheet": "res://a.png", "mode": "hero", "frame_count": 1, "cell": [1, 1], "anchor": [0, 0], "frame_ms": [80], "attacks": []}).valid, "clip validation")
	# Engine on a pose sheet.
	var sheet_path := _make_pose_sheet()
	var sheet := Image.load_from_file(sheet_path)
	var layout := ClipImport.detect_layout(sheet, 0)
	check(layout.boxes.size() == 3, "three poses found (got %d)" % layout.boxes.size())
	check(int(layout.ground_y) == 130 and (layout.strip as Rect2i).end.y == 130 and (layout.strip as Rect2i).position.y <= 70, "pose row ends on the ground line, captions skipped")
	var frames: Array = []
	var anchors: Array = []
	for box in layout.boxes:
		var cut := ClipImport.cut_frame(sheet, box, {"background": layout.background})
		frames.append(cut)
		anchors.append(ClipImport.feet_anchor(cut, float(int(layout.ground_y) - (box as Rect2i).position.y)))
	var box_2: Rect2i = layout.boxes[2]
	var first: Image = frames[0]
	check(first.get_pixel(30 - (layout.boxes[0] as Rect2i).position.x, 89 - (layout.boxes[0] as Rect2i).position.y).a < 0.1, "background in the gap between arms is cleared")
	check((layout.boxes[0] as Rect2i).position.y > 42 or first.get_pixel(62 - (layout.boxes[0] as Rect2i).position.x, 41 - (layout.boxes[0] as Rect2i).position.y).a < 0.1, "small annotation arrow dropped")
	check((frames[2] as Image).get_pixel(2, 82 - box_2.position.y).a < 0.1 or box_2.position.x > 226, "neighbour's axe dropped from the next frame")
	check(absf(Vector2(anchors[0]).x + (layout.boxes[0] as Rect2i).position.x - 30.0) <= 1.5 and absf(Vector2(anchors[2]).x + box_2.position.x - 276.0) <= 1.5, "feet found under each pose")
	var packed := ClipImport.pack(frames, anchors)
	var cell: Array = packed.cell
	var anchor: Array = packed.anchor
	var packed_image: Image = packed.image
	check(int(packed.columns) == 3 and packed_image.get_width() == int(cell[0]) * 3, "frames packed side by side")
	for index in range(3):
		# The left foot sits 6 px left of the anchor in every frame.
		var foot := packed_image.get_pixel(int(cell[0]) * index + int(float(anchor[0])) - 6, int(float(anchor[1])) - 3)
		check(foot.a > 0.9, "frame %d lined up on its feet" % (index + 1))
	# Poses whose swords reach under the next pose (overlapping columns, but
	# separate shapes) are still split into one frame each, with no bleed.
	var overlap := Image.create_empty(420, 120, false, Image.FORMAT_RGBA8)
	overlap.fill(Color8(236, 236, 236))
	for index in range(3):
		var x := 30 + index * 120
		overlap.fill_rect(Rect2i(x, 30, 30, 55), Color8(200, 40, 40))
		overlap.fill_rect(Rect2i(x + 5, 85, 20, 25), Color8(60, 60, 70))
		if index < 2:
			overlap.fill_rect(Rect2i(x + 20, 95, 104, 4), Color8(90, 90, 110))
	var shapes := ClipImport.detect_layout(overlap, 0)
	check(str(shapes.mode) == "figures" and shapes.boxes.size() == 3, "overlapping poses found as 3 shapes (%s, %d)" % [shapes.mode, shapes.boxes.size()])
	var middle: Rect2i = shapes.boxes[1]
	var middle_cut := ClipImport.cut_frame(overlap, middle, {"background": shapes.background, "owners": shapes.owners, "owner_strip": shapes.strip, "frame": 1})
	check(middle.position.x <= 150 and middle_cut.get_pixel(152 - middle.position.x, 97 - middle.position.y).a < 0.1 and middle_cut.get_pixel(160 - middle.position.x, 50 - middle.position.y).a > 0.9, "the previous pose's sword is cleared from the next frame")
	# Importer in the lab: slice, cut out, mark the combo, save, publish.
	lab.select_entry("glow_blade")
	lab.open_clip_importer()
	var importer: Control = lab.clip_importer
	check(importer.visible and importer.open_sheet(sheet_path) and importer.boxes.size() == 3, "importer opens and slices the sheet")
	importer.set_frame_count(3)
	check(await importer.cut_out(), "importer cuts out every frame")
	check(importer.cut.size() == 3 and importer.anchors.size() == 3 and importer.body_height >= 59.0, "frames aligned, hero height measured (%s)" % importer.body_height)
	importer.nudge(0, Vector2(2, 0))
	importer.erase_at(0, Vector2(5, 5), 3.0)
	importer.set_hit(1, true)
	importer.set_attack_start(2, true)
	importer.set_hit(2, true)
	check(importer.current_attacks().size() == 2 and int(importer.current_attacks()[0].hit) == 1 and int(importer.current_attacks()[1].hit) == 2, "combo marked in the importer")
	importer.set_hold(0, 150.0)
	var saved: Dictionary = importer.save_clip()
	check(not saved.is_empty() and not importer.visible and lab.current_clip().frame_count == 3, "clip saved to the weapon")
	check(FileAccess.file_exists(str(saved.source)) and str(saved.source).contains("/clips/glow_blade/") and FileAccess.file_exists(str(saved.project).path_join("project.json")), "clip sheet and project written under the weapon's folder")
	check(Catalog.validate_revision(Store.revision_for(lab.draft), false).valid, "draft revision with a clip validates")
	# No effects on this weapon: the clip must still be staged (regression).
	lab.effects_panel.set_effects([], "glow_blade")
	lab.draft["effects"] = []
	var result: Dictionary = lab.publish()
	check(result.ok, "clip published: %s" % result.message)
	var entry: Dictionary = lab.published_entry("glow_blade")
	var published_clip: Dictionary = entry.get("attack_clip", {})
	check(str(published_clip.get("sheet", "")).ends_with("/clip.png") and FileAccess.file_exists(ProjectSettings.globalize_path(str(published_clip.sheet))) and not published_clip.has("source") and not published_clip.has("project"), "clip sheet copied into the revision's assets")
	check(not lab.has_changes_from_published() and str(lab.readiness_info().get("has_changes")) == "false", "right after publishing, the weapon counts as in the game")
	check(not lab.publish().ok, "unchanged clip doesn't publish again")
	# An own clip whose sheet was replaced by a later importer save.
	var kept_clip: Dictionary = lab.draft.attack_clip.duplicate(true)
	var kept_source := str(lab.draft.get("clip_source", ""))
	var stale := kept_clip.duplicate(true)
	stale["source"] = ProjectSettings.globalize_path(TEMP_USER.path_join("gone/sheet_1.png"))
	lab.draft["attack_clip"] = stale
	lab.draft["clip_source"] = "own"
	var problem: String = lab.check_own_clip_files()
	check(problem.contains("sheet_1.png") and problem.contains("Edit...") and not lab.publish().ok, "a missing own sheet stops publishing with a clear message")
	lab.draft["clip_source"] = "type"
	check(lab.check_own_clip_files().is_empty() and lab.current_clip().is_empty(), "an unused stale copy is dropped instead")
	lab.draft["attack_clip"] = kept_clip
	lab.draft["clip_source"] = kept_source

	check(lab.edit_clip() and importer.cut.size() == 3 and is_equal_approx(float(importer.holds[0]), 150.0) and importer.current_attacks().size() == 2, "clip reopens in the importer for editing")
	importer.close()
	# Game: the hero plays the combo instead of its attack animation.
	var holder := Node2D.new()
	root.add_child(holder)
	var hero: Node2D = HeroScript.new()
	holder.add_child(hero)
	hero.configure_held_weapon(ImageTexture.create_from_image(Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)))
	hero.configure_attack_clip(published_clip, 0.24, 0.6)
	check(hero.visual.has_attack_clip(), "hero loads the published clip")
	var starts := [0]
	hero.visual.attack_started.connect(func() -> void: starts[0] += 1)
	hero.visual.play_attack()
	hero._process(0.0)
	check(hero.visual.clip_playing and hero.visual.clip_sprite.visible and not hero.visual.attack_sprite.visible and hero.visual.clip_frame == 0 and starts[0] == 1, "clip replaces the attack animation")
	check(is_zero_approx(hero.held_weapon.self_modulate.a), "held weapon hidden while the clip draws it")
	hero.visual.advance_attack_clip(0.25)
	check(hero.visual.clip_frame == 1, "hit frame showing when damage lands")
	hero.visual.advance_attack_clip(0.25)
	hero._process(0.0)
	check(not hero.visual.clip_playing and not hero.visual.clip_sprite.visible and is_equal_approx(hero.held_weapon.self_modulate.a, 1.0), "clip ends and the hero goes back to idle")
	hero.visual.play_attack()
	check(hero.visual.clip_frame == 2, "next attack plays the second part of the combo")
	hero.visual.advance_attack_clip(5.0)
	hero.visual.play_attack()
	check(hero.visual.clip_frame == 0, "combo restarts after a pause")
	hero.interrupt_held_weapon_attack()
	check(not hero.visual.clip_playing, "interrupting stops the clip")
	# Weapon-only clips swap the held weapon's picture.
	var weapon_clip := published_clip.duplicate(true)
	weapon_clip["mode"] = "weapon"
	var base_texture: Texture2D = hero.held_weapon.texture
	hero.configure_attack_clip(weapon_clip, 0.24, 0.6)
	check(not hero.visual.has_attack_clip(), "weapon clip leaves the hero's body animation alone")
	hero._start_held_weapon_attack_presentation()
	check(hero.held_weapon.texture is AtlasTexture and hero.held_weapon_clip_frame == 0, "weapon clip frames replace the weapon picture")
	hero._process(2.0)
	check(hero.held_weapon.texture == base_texture, "weapon picture restored after the clip")
	holder.queue_free()
	# Arena gets it too; removing it clears it.
	lab.open_arena()
	check(lab.arena.weapon_hero.has_attack_clip(), "arena hero has the clip")
	lab.arena.return_to_title()
	await process_frame
	lab.remove_clip()
	check(lab.current_clip().is_empty() and lab.has_changes_from_published(), "removing the clip is a change to publish")
	lab.draft["attack_clip"] = entry.attack_clip.duplicate(true)
	lab.draft["clip_source"] = "own"
	await _check_type_defaults(lab, sheet_path)
	await _check_hands(lab)
	# Video frames through ffmpeg, when it's installed.
	var ffmpeg := ClipImport.find_ffmpeg()
	if not ffmpeg.is_empty():
		var video := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/clip.mp4"))
		OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "color=c=gray:s=160x120:d=1:r=24", "-vf", "drawbox=x=40+t*40:y=30:w=30:h=60:color=red:t=fill", "-pix_fmt", "yuv420p", video], [], true)
		var extracted := ClipImport.extract_video(ffmpeg, video, ProjectSettings.globalize_path(TEMP_USER.path_join("video_frames")), 8.0, 5)
		check(extracted.ok and extracted.paths.size() == 5, "video frames extracted with ffmpeg (%s)" % extracted.error)
		lab.open_clip_importer()
		check(importer.open_video(video) and importer.frame_sources.size() > 1 and importer.align_mode == "fixed", "importer opens a video")
		check(await importer.cut_out() and Vector2(importer.anchors[0]) == Vector2(importer.anchors[-1]), "video frames keep their positions")
		importer.close()
	await process_frame

## A weapon-free body sheet and the same poses with a weapon drawn in: three
## poses on a flat backdrop; the weapon is a bar from the fist upward.
func _make_hands_sheet(with_weapon: bool) -> String:
	var image := Image.create_empty(360, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color8(236, 236, 236))
	for index in range(3):
		var x := 40 + index * 110
		image.fill_rect(Rect2i(x, 80, 30, 60), Color8(200, 40, 40))
		image.fill_rect(Rect2i(x + 4, 140, 22, 30), Color8(60, 60, 70))
		image.fill_rect(Rect2i(x + 30, 100, 10, 10), Color8(40, 40, 50))
		if with_weapon:
			image.fill_rect(Rect2i(x + 33, 40 + index * 10, 4, 60 - index * 10), Color8(150, 150, 170))
	var path := ProjectSettings.globalize_path(TEMP_USER.path_join("downloads/hands_%s.png" % ("axe" if with_weapon else "body")))
	image.save_png(path)
	return path

func _check_hands(lab: Node) -> void:
	# Model: a 20x80 upright weapon gripped near the bottom.
	var picture := Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)
	picture.fill_rect(Rect2i(8, 0, 4, 80), Color.WHITE)
	var tip := Clip.weapon_tip(picture, Vector2(0.5, 0.9))
	check(tip.y < 2.0 and absf(tip.x - 10.0) < 3.0, "weapon's far end found at the top (%s)" % tip)
	var clip := {"track": [{"grip": [50.0, 60.0], "angle": 0.0, "length": 36.0, "behind": false}]}
	var placed := Clip.hand_transform(clip, 0, Vector2(20, 80), Vector2(0.5, 0.9), tip)
	var grip_local := Vector2(10, 72) - Vector2(10, 40)
	check((placed * grip_local).distance_to(Vector2(50, 60)) < 0.5 and (placed * (tip - Vector2(10, 40))).distance_to(Vector2(86, 60)) < 1.0, "picture's grip on the hand, far end along the track")
	var flipped := Clip.hand_transform(clip, 0, Vector2(20, 80), Vector2(0.5, 0.9), tip, {"flip": true})
	check((flipped * grip_local).distance_to(Vector2(50, 60)) < 0.5 and (flipped * Vector2(-5, 0)).y != (placed * Vector2(-5, 0)).y, "flip mirrors the picture across its handle")
	check(Clip.validate_hand_fit({"angle": 10.0, "scale": 1.2, "flip": true}).valid and not Clip.validate_hand_fit({"scale": 9.0}).valid, "hand fit validation")
	check(Clip.resolve_tip(picture, Vector2(0.5, 0.9), {"tip": [0.5, 1.0]}) == Vector2(10, 80) and Clip.validate_hand_fit({"tip": [0.2, 0.3]}).valid and not Clip.validate_hand_fit({"tip": [2, 0]}).valid, "far end can be set by hand")
	# Importer: weapon-free body + ghost sheet, click hand then far end.
	lab.select_entry("glow_blade")
	lab.open_clip_importer()
	var importer: Control = lab.clip_importer
	check(importer.open_sheet(_make_hands_sheet(false)) and importer.boxes.size() == 3, "weapon-free sheet sliced")
	check(not importer.preview_options.is_empty() and str(importer.preview_options[0].id) == "glow_blade" and not importer.preview_weapon.is_empty(), "previews with this weapon's art by default")
	importer.choose_preview("__bar__", false)
	check(importer.preview_weapon.is_empty() and importer.preview_choice == "__bar__", "can preview with a plain bar instead")
	importer.choose_preview("glow_blade", false)
	await importer.cut_out()
	importer.set_weapon_free(true)
	check(importer.mode == "hero_weapon" and importer.tool == "weapon" and importer.track.size() == 3, "weapon-free mode starts the Place weapon tool")
	check(importer.open_reference(_make_hands_sheet(true)) and importer.ref_cut.size() == 3, "sheet with the weapon loads as a ghost")
	check(importer.save_clip("weapon").is_empty() and importer.visible, "can't save before placing the weapon")
	var fist: Vector2 = Vector2(importer.anchors[0]) + Vector2(20, -65)
	importer.select_frame(0)
	importer.weapon_click(fist)
	importer.weapon_click(fist + Vector2(0, -40))
	check(importer.selected == 1 and importer.placed_count() == 1, "placing the far end moves on to the next frame")
	importer.copy_previous_track(1)
	importer.select_frame(2)
	importer.weapon_click(Vector2(importer.anchors[2]) + Vector2(20, -65))
	importer.weapon_click(Vector2(importer.anchors[2]) + Vector2(50, -65))
	importer.set_behind(2, true)
	check(importer.placed_count() == 3, "weapon placed on every frame")
	# Auto-place finds the same grip and the weapon's true far end.
	var manual: Array = importer.track.duplicate(true)
	var manual_offsets: Array = importer.ref_offsets.duplicate()
	for index in range(3):
		importer.clear_track(index)
	check(importer.auto_place() == 3 and importer.placed_count() == 3, "auto-place fills every frame")
	var anchor0: Vector2 = importer.anchors[0]
	check(Vector2(importer.track[0].grip).distance_to(anchor0 + Vector2(20, -65)) <= 6.0, "auto grip in the fist (%s vs %s)" % [importer.track[0].grip, anchor0 + Vector2(20, -65)])
	check(Vector2(importer.track[0].tip).distance_to(anchor0 + Vector2(20, -130)) <= 6.0 and not bool(importer.track[0].behind), "auto far end at the weapon's tip (%s)" % importer.track[0].tip)
	var mask: Image = importer.hand_masks[0]
	var grip_px := Vector2i(Vector2(importer.track[0].grip).round())
	check(mask != null and mask.get_pixelv(grip_px).r > 0.5 and mask.get_pixelv(Vector2i(anchor0 + Vector2(0, -10))).r < 0.5, "front hand covers the fist, not the legs")
	importer.brush = 30.0
	importer.paint_hand(0, Vector2(grip_px), true)
	check(importer.hand_masks[0].get_pixelv(grip_px).r < 0.5 and importer.hand_painted[0], "hand brush erases (Shift)")
	importer.paint_hand(0, Vector2(grip_px) + Vector2(12, 4), false)
	var full_rebuild: Image = preload("res://scripts/tools/weapon_clip_import.gd").masked(importer.cut[0], importer.hand_masks[0])
	check(importer.hand_pictures[0] is Image and (importer.hand_pictures[0] as Image).get_data() == full_rebuild.get_data(), "brush strokes update only the painted area, matching a full rebuild")
	importer.reset_hand(0)
	check(importer.hand_masks[0].get_pixelv(grip_px).r > 0.5 and not importer.hand_painted[0], "Auto hand redoes it")
	importer.brush = 6.0
	importer.track = manual
	importer.ref_offsets = manual_offsets
	importer._after_track_changed()
	var saved: Dictionary = importer.save_clip("weapon")
	check(FileAccess.file_exists(str(saved.get("hand_source", ""))) and str(Store.revision_for(lab.draft).attack_clip.get("hand_sheet", "")) == Store.PENDING_EFFECT_SHEET, "front-hand sheet saved with the clip")
	var hand_sheet := Image.load_from_file(str(saved.hand_source))
	var body_sheet := Image.load_from_file(str(saved.source))
	check(hand_sheet.get_size() == body_sheet.get_size(), "hand sheet packs like the body sheet")
	check(str(saved.get("mode", "")) == "hero_weapon" and saved.track.size() == 3 and is_equal_approx(float(saved.track[2].angle), 0.0) and bool(saved.track[2].behind), "track saved in the clip")
	check(absf(float(saved.track[0].angle) + 90.0) < 0.5 and absf(float(saved.track[0].length) - 40.0 * float(Clip.normalize(saved).cell[0]) / float(Clip.normalize(saved).cell[0])) < 1.0, "first frame points straight up, 40 px long")
	check(Catalog.validate_revision(Store.revision_for(lab.draft), false).valid, "draft with a weapon-free animation validates")
	check(lab.hand_fit_row.visible, "lab shows the in-hands fine-tune for this animation")
	lab.picking_tip = true
	lab.set_weapon_tip(Vector2(0.5, 0.0))
	check(lab.hand_fit().has("tip") and lab.hand_fit().has("scale") and Catalog.validate_revision(Store.revision_for(lab.draft), false).valid, "far end picked on the sprite and saved")
	lab.clear_weapon_tip()
	check(not lab.hand_fit().has("tip"), "far end back to automatic")
	lab.hand_scale_spin.value = 1.5
	check(is_equal_approx(float(lab.hand_fit().scale), 1.5) and Store.revision_for(lab.draft).has("hand_fit"), "hand fit saved on the weapon")
	check(lab.edit_clip() and importer.mode == "hero_weapon" and importer.placed_count() == 3 and importer.ref_cut.size() == 3, "reopening keeps the weapon placements and the ghost")
	var before: Dictionary = importer._align_transform()
	var probe: Vector2 = Vector2(before.pivot) + Vector2(30, -40)
	importer.zoom_view(2.0, probe)
	var after: Dictionary = importer._align_transform()
	check(is_equal_approx(float(after.scale), float(before.scale) * 2.0) and (Vector2(after.pivot) + (probe - Vector2(before.pivot)) / float(before.scale) * float(after.scale)).distance_to(probe) < 0.01, "wheel zoom keeps the point under the mouse still")
	importer.fit_view()
	check(is_equal_approx(float(importer._align_transform().scale), float(before.scale)), "Fit resets the view")
	importer.close()
	# Game: the hero draws this weapon's own picture in the hands.
	var holder := Node2D.new()
	root.add_child(holder)
	var hero: Node2D = HeroScript.new()
	holder.add_child(hero)
	hero.position = Vector2(300, 200)
	hero.configure_held_weapon(ImageTexture.create_from_image(picture), Vector2(0.5, 0.9))
	hero.configure_attack_clip(saved, 0.24, 0.6)
	hero.visual.play_attack()
	hero._process(0.0)
	var normalized := Clip.normalize(saved)
	var hand_global: Vector2 = hero.visual.clip_cell_to_global() * Vector2(float(normalized.track[0].grip[0]), float(normalized.track[0].grip[1]))
	var picture_grip: Vector2 = hero.held_weapon.global_transform * grip_local
	check(hero.visual.clip_places_weapon() and picture_grip.distance_to(hand_global) < 0.5 and is_equal_approx(hero.held_weapon.self_modulate.a, 1.0), "weapon's own picture is held at the frame's grip")
	check(hero.visual.hand_sprite.visible and hero.visual.hand_sprite.region_rect == hero.visual.clip_sprite.region_rect and hero.visual.hand_sprite.z_index + hero.visual.z_index > hero.weapon_socket.z_index, "front hand drawn over the weapon")
	var far_end: Vector2 = hero.held_weapon.global_transform * (tip - Vector2(10, 40))
	check(far_end.y < picture_grip.y - 5.0, "and points up like the drawn axe")
	hero.visual.advance_attack_clip(10.0)
	hero.visual.play_attack()
	hero.visual.advance_attack_clip(0.0)
	var frame: int = hero.visual.clip_frame
	hero._process(0.0)
	check(hero.weapon_socket.z_index == (0 if bool(normalized.track[frame].behind) else 2), "behind-the-body frames draw the weapon behind")
	check(hero.visual.hand_sprite.visible == (not bool(normalized.track[frame].behind)), "no front hand when the weapon is behind")
	hero.visual.set_facing(-1)
	hero._process(0.0)
	var mirrored_grip: Vector2 = hero.held_weapon.global_transform * grip_local
	check(mirrored_grip.distance_to(hero.visual.clip_cell_to_global() * Vector2(float(normalized.track[frame].grip[0]), float(normalized.track[frame].grip[1]))) < 0.5, "facing left mirrors the placement")
	hero.interrupt_held_weapon_attack()
	hero._process(0.0)
	check(not hero._hand_placed and hero.weapon_socket.z_index == 2, "weapon goes back to its normal hold after the attack")
	holder.queue_free()
	lab.draft["hand_fit"] = {}
	lab.draft["attack_clip"] = {}
	lab.draft["clip_source"] = "type"

## Weapon types: an animation saved as the Axe default plays for every axe
## that uses its type's default, without republishing them.
func _check_type_defaults(lab: Node, sheet_path: String) -> void:
	check(Types.guess("Lumber Axe") == "axe" and Types.guess("light blade") == "sword" and Types.guess("beat stick") == "club" and Types.guess("Thing") == "", "type guessed from the name")
	check(Types.type_id_from("Great Sword") == "great_sword" and Types.is_valid_type("great_sword") and not Types.is_valid_type("Great Sword"), "type ids")
	check(Types.clip_source({"attack_clip": {"sheet": "res://a.png", "frame_count": 1}}) == "own" and Types.clip_source({}) == "type", "old revisions keep their own clip; others use the type")
	var bad: Dictionary = lab.published_entry("glow_blade").duplicate(true)
	bad["weapon_type"] = "Axe!"
	check(not Catalog.validate_revision(bad, false).valid, "invalid weapon type rejected")
	# glow_blade has its own clip; make it the Axe default.
	lab.select_entry("glow_blade")
	lab.set_weapon_type("axe")
	check(lab.type_picker.get_item_metadata(lab.type_picker.selected) == "axe", "type picker shows axe")
	check(lab.set_own_as_type_default(), "own animation becomes the Axe default")
	var library := Types.load_library(lab.data_root)
	var default_clip: Dictionary = library.types.axe.clip
	check(int(library.types.axe.revision) == 1 and str(default_clip.sheet).ends_with("_types/axe/1/clip.png") and FileAccess.file_exists(ProjectSettings.globalize_path(str(default_clip.sheet))) and not default_clip.has("source"), "default sheet copied into its own revision folder")
	lab.set_clip_source("type")
	check(Types.clip_source(lab.draft) == "type" and not lab.effective_clip().is_empty(), "weapon now uses the Axe default")
	check(lab.publish().ok and lab.published_entry("glow_blade").weapon_type == "axe" and lab.published_entry("glow_blade").clip_source == "type", "type and source publish on the revision")
	# A new axe picks up the default automatically.
	lab.new_weapon()
	lab.name_edit.text = "Lumber Axe"
	lab.name_edit.text_changed.emit("Lumber Axe")
	check(lab.weapon_type() == "axe" and Types.clip_source(lab.draft) == "type" and int(lab.effective_clip().get("frame_count", 0)) == 3, "new axe guesses its type and uses the default")
	check(lab.clip_summary.text.contains("Axe default"), "summary names the default in use")
	# Saving from the importer as the type default updates every axe.
	lab.open_clip_importer()
	var importer: Control = lab.clip_importer
	check(importer._save_default_button.visible and importer._save_default_button.text.contains("Axe"), "importer offers Save as the Axe default")
	importer.open_sheet(sheet_path)
	importer.set_frame_count(3)
	await importer.cut_out()
	importer.set_all_holds(60.0)
	importer.save_clip("type")
	library = Types.load_library(lab.data_root)
	check(int(library.types.axe.revision) == 2 and is_equal_approx(float(library.types.axe.clip.frame_ms[0]), 60.0), "importer saved a new Axe default")
	check(is_equal_approx(float(Types.resolve_clip(lab.published_entry("glow_blade"), library).frame_ms[0]), 60.0), "published axe plays the new default without republishing")
	check(lab.edit_clip() and importer.editing_default and not importer._save_button.visible, "editing the default reopens it as the default")
	importer.close()
	lab.set_clip_source("none")
	check(lab.effective_clip().is_empty(), "hero's normal attack when chosen")
	lab.select_entry("glow_blade")
	# Removing the default.
	check(Types.remove_default("axe", lab.data_root) and Types.default_clip(Types.load_library(lab.data_root), "axe").is_empty(), "type default removed")
	lab.reload_type_library()
	# Categories: add as many as you like, pick one in the art section, filter the list.
	var shotgun: String = lab.add_category("Shotgun")
	check(shotgun == "shotgun" and lab.category_ids().has("shotgun") and Types.load_library(lab.data_root).types.shotgun.label == "Shotgun", "category added and saved")
	check(lab.add_category("Great Sword") == "great_sword" and lab.category_ids().has("great_sword"), "multi-word category")
	var shotgun_index := -1
	for index in range(lab.art_type_picker.item_count):
		if lab.art_type_picker.get_item_metadata(index) == "shotgun":
			shotgun_index = index
	check(shotgun_index > 0, "art section offers the new category")
	lab.art_type_picker.select(shotgun_index)
	lab.art_type_picker.item_selected.emit(shotgun_index)
	check(lab.weapon_type() == "shotgun" and lab.type_picker.get_item_metadata(lab.type_picker.selected) == "shotgun", "picking it in the art section sets the weapon type (both pickers)")
	lab.set_category_filter("shotgun")
	check(lab.tiles.size() == 1 and lab.tiles.has(str(lab.draft.weapon_id)) and lab.tiles[str(lab.draft.weapon_id)].text.contains("Shotgun"), "list filtered to the category, tile shows it")
	lab.set_category_filter("axe")
	check(lab.tiles.is_empty() or not lab.tiles.has(str(lab.draft.weapon_id)), "other categories hide it")
	lab.set_category_filter("__all__")
	lab.rename_category("shotgun", "Scatter Gun")
	check(Types.label_of("shotgun", lab.type_library) == "Scatter Gun", "category renamed")
	lab.remove_category("great_sword")
	lab.remove_category("bow")
	check(not lab.category_ids().has("great_sword") and not lab.category_ids().has("bow"), "categories removed, built-ins too")
	lab.open_category_dialog()
	check(lab.category_rows.get_child_count() == lab.category_ids().size(), "manager lists every category")
	lab.category_dialog.hide()
	lab.set_weapon_type("axe")
	# Section 2: live previews, the readiness check, and your own green check.
	check(lab.get_window().content_scale_size == lab.lab_canvas_for(lab.get_window().size), "the lab lays out at the window's own pixel size")
	check(lab.lab_canvas_for(Vector2i(1366, 768)) == Vector2i(1366, 768) and lab.lab_canvas_for(Vector2i(3840, 2160)) == Vector2i(1920, 1080) and lab.lab_canvas_for(Vector2i(1024, 576)) == Vector2i(1280, 720), "canvas: 1:1, whole-number scale on big screens, never smaller than 1280x720")
	lab.refresh_showcase()
	await process_frame
	check(lab.showcase.attack_hero.held_weapon.texture != null and lab.showcase.hold_hero.held_weapon.texture != null, "attack and holding previews both hold this weapon")
	check(str(lab.readiness.state) == "animation" and lab.readiness_title.text == "Needs an attack animation", "no axe default yet: flagged as needing an animation")
	# Drag the weapon in the Holding preview; the wheel turns it.
	var stage: Node = lab.showcase
	var hero: Node2D = stage.hold_hero
	var grip_point: Vector2 = stage.hold_view.get_canvas_transform() * hero.held_weapon_grip_world_position()
	var before: Array = lab.draft.art.hand_offset.duplicate()
	stage.begin_drag(grip_point)
	stage.drag_to(grip_point + Vector2(28, -14))
	stage.end_drag()
	var moved: Array = lab.draft.art.hand_offset
	check(float(moved[0]) > float(before[0]) + 5.0 and float(moved[1]) < float(before[1]) - 2.0 and is_equal_approx(lab.placement_spins["offset_x"].value, float(moved[0])), "dragging in the Holding preview moves Hand X/Y")
	var base_zoom: float = stage.hold_camera.zoom.x
	stage.set_hold_zoom(3.0)
	await process_frame
	await process_frame
	check(is_equal_approx(stage.hold_camera.zoom.x, base_zoom * 3.0) and stage.hold_camera.position.distance_to(hero.weapon_socket.position) < 0.5 and stage.hold_zoom_label.text == "3x", "Holding preview zooms in on the hand")
	var zoomed_grip: Vector2 = stage.hold_view.get_canvas_transform() * hero.held_weapon_grip_world_position()
	var zoomed_before: Array = lab.draft.art.hand_offset.duplicate()
	stage.begin_drag(zoomed_grip)
	stage.drag_to(zoomed_grip + Vector2(30, 0))
	stage.end_drag()
	check(absf(float(lab.draft.art.hand_offset[0]) - float(zoomed_before[0]) - 30.0 / stage.hold_camera.zoom.x / hero.display_scale()) <= 1.0, "dragging while zoomed moves the weapon less (finer placement)")
	stage.set_hold_zoom(50.0)
	check(is_equal_approx(stage.hold_zoom, stage.HOLD_ZOOM_MAX), "zoom is capped")
	stage.set_hold_zoom(0.1)
	check(is_equal_approx(stage.hold_zoom, 1.0) and is_equal_approx(stage.hold_camera.zoom.x, base_zoom), "and goes back to the whole hero")
	var turned := float(lab.placement_spins["rotation_degrees"].value)
	lab.nudge_placement("rotation_degrees", -3.0)
	check(is_equal_approx(float(lab.draft.art.rotation_degrees), turned - 3.0), "mouse wheel turns the weapon")
	check(lab.readiness_rows.get_child_count() == lab.readiness.items.size(), "readiness lists every check")
	lab.set_clip_source("none")
	lab.refresh_showcase()
	var anim_text := ""
	for item in lab.readiness.items:
		if item.key == "animation":
			anim_text = str(item.text)
	check(anim_text.contains("normal attack") and str(lab.readiness.state) == "animation", "hero's normal attack counts as needing an animation")
	lab.set_clip_source("type")
	var marked_id := str(lab.draft.weapon_id)
	check(not lab.is_marked(marked_id), "not marked done at first")
	var tile_check: Button = lab.tiles[marked_id].get_node("DoneCheck")
	tile_check.button_pressed = true
	check(lab.is_marked(marked_id) and lab.done_check.button_pressed and FileAccess.file_exists(lab.marks_path()), "tile check marks it done, saved, details agree")
	lab.load_marks()
	check(lab.is_marked(marked_id), "done mark survives a reload")
	lab.done_check.button_pressed = false
	check(not lab.is_marked(marked_id) and not lab.tiles[marked_id].get_node("DoneCheck").button_pressed, "unticking in the details clears the tile")
	var clip := {"frame_count": 4, "sheet": "res://x.png", "mode": "hero_weapon"}
	var base := {"has_art": true, "weapon_type": "axe", "type_label": "Axe", "clip_source": "type", "clip": clip, "grip": [0.3, 0.8], "hand_offset": [0, 0], "published": 2, "removed": false, "has_changes": false}
	check(Readiness.check(base).state == "ready", "animated, published weapon is ready")
	check(Readiness.check(_with(base, "has_changes", true)).state == "publish", "unpublished edits need publishing")
	check(Readiness.check(_with(base, "clip", _with(clip, "mode", "hero"))).state == "check", "a type default with a painted-in weapon is flagged to check")
	check(Readiness.check(_with(base, "has_art", false)).state == "art", "no art comes first")
	lab.layout_for_width(1280.0)
	check(not lab.three_columns() and not lab.page_third.visible, "1280 wide: Placement sits under Art")
	lab.layout_for_width(1843.0)
	check(lab.three_columns() and lab.page_third.visible, "wide window: Placement gets its own column")
	lab.layout_for_width(1311.0)
	check(not lab.three_columns() and lab.placement_section.get_parent() == lab.page_left, "and moves back when the window shrinks")
	lab._restore_window()
	check(lab.get_window().content_scale_size == Vector2i(1280, 720), "leaving the lab puts the game canvas back")

func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := source.duplicate(true)
	copy[key] = value
	return copy

## The encounter resolves equipped weapons through HeroStatResolver; a published
## revision's base_stats reach it via the runtime base AccountState registers.
func _check_game_uses_base_stats(entry: Dictionary) -> void:
	Definitions.register_runtime_base("lab_test_weapon", {"id": "lab_test_weapon", "label": "t", "slot": "weapon", "implicits": [], "base_stats": entry.base_stats})
	var instance := {"instance_id": "w", "base_id": "lab_test_weapon", "implicit_modifiers": [], "explicit_modifiers": []}
	var resolved: Dictionary = Resolver.resolve({}, {"w": instance}, {"weapon": "w"}).stats
	check(is_equal_approx(resolved.attack_damage, 24.0) and is_equal_approx(resolved.attacks_per_second, 0.8), "game resolver uses the weapon's base stats")
	var ranked: Dictionary = Resolver.resolve({"weapon.damage": 1, "weapon.rate": 1}, {"w": instance}, {"weapon": "w"}).stats
	check(is_equal_approx(ranked.attack_damage, 29.0) and is_equal_approx(ranked.attacks_per_second, 0.92), "research still adds on top of the weapon's base")
	var plain: Dictionary = Resolver.resolve({}, {"w": {"instance_id": "w", "base_id": "core.heavy_breech", "implicit_modifiers": [], "explicit_modifiers": []}}, {"weapon": "w"}).stats
	check(is_equal_approx(plain.attack_damage, BalanceData.WEAPON_DAMAGE), "weapons without base stats keep the global baseline")

func _check_arena() -> void:
	var arena: Node = ArenaScript.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	var texture := ImageTexture.create_from_image(Image.create_empty(40, 120, false, Image.FORMAT_RGBA8))
	arena.configure_weapon("Test Rifle", texture, {"grip": [0.5, 0.8], "facing": "right"}, "weapon.standard", {"attack_damage": 12.0, "attack_interval": 0.5})
	check(arena.hero == arena.weapon_hero and arena.weapon_hero.held_weapon.visible, "hero holds the weapon")
	arena.spawn_monster(EnemyScript.EnemyKind.PURSUER, 1)
	arena.simulate_step(10.0)
	check(arena.dealt_hits > 0 and is_equal_approx(arena.dealt_total, arena.dealt_hits * 12.0), "ranged weapon hits monsters for its damage")
	check(arena.monster_count() == 1, "monsters can't die by default")
	check(arena.total_hits > 0 and not arena.hit_numbers.is_empty(), "monster hits on the hero are shown")
	arena.monsters_invincible = false
	arena.simulate_step(6.0)
	check(arena.kills >= 1 and arena.monster_count() == 0, "with dying on, the weapon kills")
	arena.shots.clear()
	arena.play_swing()
	check(arena.shots.size() == 1 and Vector2(arena.shots[0].velocity).x > 0.0 and absf(Vector2(arena.shots[0].velocity).y) < 0.001, "E with a ranged weapon fires a shot straight ahead when no monster is around")
	arena.shots.clear()
	arena.configure_weapon("Test Sword", texture, {}, "weapon.melee", {"attack_damage": 9.0, "attack_interval": 0.4})
	arena.monsters_invincible = true
	arena.reset_meter()
	arena.spawn_monster(EnemyScript.EnemyKind.PURSUER, 1)
	arena.simulate_step(11.0)
	check(arena.dealt_hits > 0 and is_equal_approx(arena.dealt_total, arena.dealt_hits * 9.0), "melee weapon strikes a monster in reach")
	arena.weapon_hero.last_facing = -1
	arena._cancel_melee()
	arena.reset_meter()
	arena.simulate_step(3.0)
	check(arena.dealt_hits == 0, "melee only hits in the facing direction")
	var swings_before: int = arena.swings
	arena.auto_attack = false
	arena.loop_attack = true
	arena.simulate_step(2.0)
	check(arena.swings > swings_before, "loop attack replays the animation")
	arena.set_speed_index(2)
	check(is_equal_approx(Engine.time_scale, 0.25), "slow motion")
	var signals := []
	arena.placement_changed.connect(func(pivot: Dictionary) -> void: signals.append(pivot))
	arena._pivot_spins["rotation_degrees"].value = 33.0
	check(signals.size() == 1 and is_equal_approx(float(signals[0].rotation_degrees), 33.0), "placement edits are reported")
	arena.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "leaving the arena restores normal speed")

func _check_title_entry() -> void:
	var scene: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var entry: Button = scene.get_node_or_null("Menu/WeaponLab")
	check(entry != null, "title screen has the weapon lab entry")
	if entry != null:
		check(entry.get_index() == scene.get_node("Menu/Quit").get_index() - 1, "weapon lab sits above Quit")
	check(ResourceLoader.exists(scene.WEAPON_LAB_SCENE), "weapon lab scene path resolves")
	scene.queue_free()
	await process_frame

func _clean() -> void:
	for path in [TEMP_USER, TEMP_RES]:
		_remove_tree(ProjectSettings.globalize_path(path))

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	for file in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for sub in directory.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)

## The hero's own idle / walk / attack from the importer (hero purpose).
func _check_hero_animations() -> void:
	HeroAnims.animations_root = TEMP_RES.path_join("animations")
	HeroAnims.backups_root = ProjectSettings.globalize_path(TEMP_USER.path_join("hero_backups"))
	# Two 40x60 cells, a 30x50 "hero" standing on the anchor (20, 58).
	var sheet := Image.create_empty(80, 60, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(5, 8, 30, 50), Color(0.9, 0.2, 0.2))
	sheet.fill_rect(Rect2i(47, 10, 30, 48), Color(0.9, 0.2, 0.2))
	var sheet_path := ProjectSettings.globalize_path(TEMP_USER.path_join("hero_sheet.png"))
	sheet.save_png(sheet_path)
	var clip := {"source": sheet_path, "frame_count": 2, "columns": 2, "cell": [40, 60], "anchor": [20, 58], "body_height": 50.0, "frame_ms": [100, 200], "mode": "hero"}
	var result: Dictionary = HeroAnims.install(clip, "walk")
	check(bool(result.ok) and int(result.frame_count) == 2, "walk installed")
	var folder := HeroAnims.folder_path("walk")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	var asset: Dictionary = VisualConfig.ASSETS.hero
	var scale := float(asset.animation_reference_height) / 50.0
	check(absf(float(manifest.union_crop[0]) + 20.0 * scale - float(asset.animation_source_anchor.x)) <= 1.0 and absf(float(manifest.union_crop[1]) + 58.0 * scale - float(asset.animation_source_anchor.y)) <= 1.0, "feet land on the hero's shared anchor, scaled to its reference height")
	check(int(manifest.cell_size[0]) == roundi(40 * scale) and is_equal_approx(float(manifest.playback_fps), 10.0) and manifest.frame_durations == [1.0, 2.0], "cell size and timing")
	var tres := FileAccess.get_file_as_string(folder.path_join("animation.tres"))
	check(tres.contains("&\"walk\"") and tres.contains("Frame_1") and not tres.contains("Frame_2") and tres.contains("\"loop\": true"), "animation.tres written")
	var frames: SpriteFrames = VisualConfig.asset_for("hero").walk_frames
	check(frames == result.frames and frames.get_frame_count(&"walk") == 2, "the game uses the new walk right away (before the editor imports it)")
	var hero: Node2D = HeroScript.new()
	root.add_child(hero)
	await process_frame
	hero.visual.set_locomotion(true)
	check(hero.visual.walk_sprite.sprite_frames == frames and hero.visual.walk_sprite.visible, "the hero walks with it")
	hero.queue_free()
	var still: Dictionary = HeroAnims.install(clip, "idle", 1)
	check(bool(still.ok) and int(still.frame_count) == 1 and VisualConfig.asset_for("hero").idle_frames.get_frame_count(&"idle") == 1, "a still idle from one frame")
	var again: Dictionary = HeroAnims.install(clip, "walk")
	check(bool(again.ok) and DirAccess.get_directories_at(HeroAnims.backups_root).size() >= 1, "the previous art is backed up")
	check(not bool(HeroAnims.install(clip, "run").ok), "unknown animation refused")
	# The importer's hero purpose.
	var lab: Node = await _new_lab()
	lab.open_hero_importer("walk")
	var importer: Node = lab.clip_importer
	check(importer.purpose == "hero" and importer.visible and importer.default_align == "body" and importer._title.text.begins_with("HERO"), "Hero animations... opens the importer for the hero")
	importer.close()
	lab.open_clip_importer()
	check(importer.purpose == "weapon" and importer.default_align == "feet", "the weapon importer is back to normal")
	importer.close()
	var dummy := Image.create_empty(60, 80, false, Image.FORMAT_RGBA8)
	dummy.fill_rect(Rect2i(10, 0, 20, 40), Color.RED)
	dummy.fill_rect(Rect2i(0, 40, 60, 40), Color.RED)
	check(is_equal_approx(ClipImport.body_center_x(dummy), 20.0), "body line-up follows the torso, not the legs")
	# Front fist: tracked across frames, saved, and the held weapon follows it.
	var blob_frames: Array = []
	for index in range(3):
		var frame := Image.create_empty(80, 80, false, Image.FORMAT_RGBA8)
		frame.fill_rect(Rect2i(10, 10, 30, 60), Color(0.8, 0.1, 0.1))
		frame.fill_rect(Rect2i(44 + index * 4, 30 - index * 3, 10, 10), Color(0.2, 0.2, 0.25))
		frame.fill_rect(Rect2i(47 + index * 4, 33 - index * 3, 4, 4), Color(0.9, 0.9, 0.9))
		blob_frames.append(frame)
	var fists: Array = ClipImport.track_patch(blob_frames, 0, Vector2(49, 35), 10, 12)
	check(fists.size() == 3 and Vector2(fists[1]).distance_to(Vector2(53, 32)) <= 2.0 and Vector2(fists[2]).distance_to(Vector2(57, 29)) <= 2.0, "front fist tracked across frames (%s)" % str(fists))
	var fist_clip := clip.duplicate(true)
	fist_clip["hand_track"] = [[30, 20], [34, 16]]
	var fist_result: Dictionary = HeroAnims.install(fist_clip, "idle")
	var fist_manifest: Dictionary = VisualConfig.runtime_manifests.get("hero_idle", {})
	check(bool(fist_result.ok) and fist_manifest.get("hand_track", []).size() == 2, "fist track saved with the animation")
	var holder: Node2D = HeroScript.new()
	root.add_child(holder)
	await process_frame
	holder.configure_held_weapon(ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)))
	holder.visual.idle_sprite.frame = 0
	holder._process(0.0)
	var socket_start: Vector2 = holder.weapon_socket.position
	holder.visual.idle_sprite.frame = 1
	holder._process(0.0)
	var moved_by: Vector2 = holder.weapon_socket.position - socket_start
	var step: float = float(VisualConfig.ASSETS.hero.animation_reference_height) / 50.0 * holder.visual.animation_scale
	check(absf(moved_by.x - 4.0 * step) < 0.01 and absf(moved_by.y + 4.0 * step) < 0.01, "the held weapon follows the fist (%s)" % str(moved_by))
	holder.queue_free()
	VisualConfig.runtime_frames.clear()
	VisualConfig.runtime_manifests.clear()
	HeroAnims.animations_root = HeroAnims.ANIMATIONS_ROOT
	HeroAnims.backups_root = ""
	lab.queue_free()
