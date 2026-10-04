extends SceneTree

## Weapon idle / walk clips ("pose" clips), the held weapon tilting with the
## arm, and the front fist drawn over the held weapon (hand_atlas.png).

const Clip = preload("res://scripts/model/weapon_clip.gd")
const Types = preload("res://scripts/model/weapon_types.gd")
const HeroScript = preload("res://scripts/game/player.gd")
const Config = preload("res://scripts/game/side_view_visual_config.gd")
const HeroAnimations = preload("res://scripts/model/hero_animations.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")

const TEMP := "user://weapon_poses_test"
const ASSET_TEMP := "res://.weapon_poses_test_assets"
var failures := 0

func _init() -> void:
	_run()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP))
	_test_loop_timing()
	_test_sources_and_library()
	_test_revision_and_catalog()
	await _test_hero_plays_pose_clips()
	await _test_tilt_and_fist()
	_cleanup()
	if failures == 0:
		print("PASS weapon poses: idle/walk clips (sources, type defaults, publishing data), in-hands placement, tilt with the arm, front fist overlay")
		quit(0)
	else:
		print("FAIL weapon poses: %d check(s) failed" % failures)
		quit(1)

## A 2-frame sheet (40x80 cells, columns 2) with a body block and a fist.
func _sheet(name: String) -> String:
	var image := Image.create_empty(80, 80, false, Image.FORMAT_RGBA8)
	for index in range(2):
		image.fill_rect(Rect2i(index * 40 + 12, 20, 16, 58), Color8(200, 40, 40))
	var path := ProjectSettings.globalize_path(TEMP.path_join(name))
	image.save_png(path)
	return path

func _pose_clip(mode: String = "hero_weapon") -> Dictionary:
	var clip := {"label": "Idle", "mode": mode, "source": _sheet("idle.png"), "frame_count": 2, "columns": 2, "cell": [40.0, 80.0], "anchor": [20.0, 78.0], "body_height": 58.0, "frame_ms": [100.0, 200.0]}
	if mode == "hero_weapon":
		clip["track"] = [{"grip": [28.0, 50.0], "angle": -90.0, "length": 30.0, "behind": false}, {"grip": [30.0, 48.0], "angle": -80.0, "length": 30.0, "behind": true}]
	return clip

func _test_loop_timing() -> void:
	var clip := Clip.normalize(_pose_clip())
	check(is_equal_approx(Clip.loop_length(clip), 0.3), "loop length is the sum of the holds")
	check(Clip.loop_frame_at(clip, 0.05) == 0 and Clip.loop_frame_at(clip, 0.15) == 1 and Clip.loop_frame_at(clip, 0.35) == 0, "looping frames follow their holds and wrap")

func _test_sources_and_library() -> void:
	var data_root := TEMP.path_join("data")
	var asset_root := ASSET_TEMP
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(data_root))
	var revision := {"weapon_type": "axe", "behavior_id": "weapon.melee"}
	var library := Types.load_library(data_root)
	check(Types.pose_source(revision, "idle") == "type" and Types.resolve_pose_clip(revision, library, "idle").is_empty(), "no idle anywhere: the hero's own")
	check(not Types.set_default("axe", _pose_clip("weapon"), data_root, asset_root, "idle").ok, "idle defaults must show the hero")
	var saved := Types.set_default("axe", _pose_clip(), data_root, asset_root, "idle")
	check(saved.ok and str(saved.clip.sheet).ends_with("_types/axe/idle/1/clip.png"), "idle default copied into its own folder (%s)" % str(saved.get("error", "")))
	library = Types.load_library(data_root)
	check(not Types.resolve_pose_clip(revision, library, "idle").is_empty() and Types.resolve_pose_clip(revision, library, "walk").is_empty(), "the type's idle plays, walk stays the hero's")
	# An attack default doesn't disturb the poses (and vice versa).
	check(Types.set_default("axe", {"label": "Chop", "mode": "hero", "source": _sheet("chop.png"), "frame_count": 2, "columns": 2, "cell": [40.0, 80.0], "anchor": [20.0, 78.0], "frame_ms": [83.0, 83.0]}, data_root, asset_root).ok, "attack default saved")
	library = Types.load_library(data_root)
	check(not Types.default_clip(library, "axe").is_empty() and not Types.default_pose_clip(library, "axe", "idle").is_empty(), "attack and idle defaults live side by side")
	revision["pose_sources"] = {"idle": "none"}
	check(Types.resolve_pose_clip(revision, library, "idle").is_empty(), "\"none\" keeps the hero's own idle")
	revision["pose_sources"] = {"idle": "own"}
	revision["pose_clips"] = {"idle": _pose_clip("hero")}
	check(str(Types.resolve_pose_clip(revision, library, "idle").mode) == "hero", "own idle wins when chosen")
	check(Types.resolve_pose_clips(revision, library).size() == 1, "resolve_pose_clips lists only the ones that play")
	check(Types.remove_default("axe", data_root, "idle"), "idle default removed")
	library = Types.load_library(data_root)
	check(Types.default_pose_clip(library, "axe", "idle").is_empty() and not Types.default_clip(library, "axe").is_empty(), "removing the idle keeps the attack")

func _test_revision_and_catalog() -> void:
	var draft := {"weapon_id": "pose_test", "label": "Pose test", "pose_sources": {"idle": "own", "walk": "type", "jump": "own"}, "pose_clips": {"idle": _pose_clip()}}
	var revision := Store.revision_for(draft)
	check(revision.pose_sources == {"idle": "own", "walk": "type"}, "only idle/walk sources are published")
	check(str(revision.pose_clips.idle.sheet) == Store.PENDING_EFFECT_SHEET and not str(revision.pose_clips.idle.get("source", "")).is_empty(), "draft pose sheet waits for publishing")
	var published := revision.duplicate(true)
	published.pose_clips.idle.erase("source")
	published.pose_clips.idle["sheet"] = "res://assets/weapons/pose_test/1/idle.png"
	check(Clip.validate(published.pose_clips.idle).valid, "published idle clip is valid")

func _hero() -> Node2D:
	var hero: Node2D = HeroScript.new()
	root.add_child(hero)
	return hero

func _weapon_texture() -> Texture2D:
	var image := Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(8, 0, 4, 80), Color.WHITE)
	return ImageTexture.create_from_image(image)

func _test_hero_plays_pose_clips() -> void:
	var hero := _hero()
	await process_frame
	hero.configure_held_weapon(_weapon_texture(), Vector2(0.5, 0.9))
	hero.configure_pose_clips({"idle": _pose_clip()})
	hero.visual.set_locomotion(false)
	check(hero.visual.is_pose_showing() and hero.visual.pose_state == "idle", "standing shows the weapon's idle")
	check(not hero.visual.idle_sprite.visible, "the hero's own idle art is hidden")
	hero._process(0.01)
	check(hero._hand_placed, "the idle places the weapon in the hands")
	var first: Transform2D = hero.hand_placed_transform()
	hero.visual.advance_pose(0.12)
	hero._process(0.0)
	check(hero.visual.pose_frame == 1 and hero.weapon_socket.z_index == 0, "next frame: weapon behind the body as the track says")
	check(not hero.hand_placed_transform().is_equal_approx(first), "the weapon moves with the frames")
	hero.visual.set_locomotion(true)
	check(not hero.visual.is_pose_showing() and hero.visual.walk_sprite.visible, "no weapon walk: the hero's own walk plays")
	hero._process(0.0)
	check(not hero._hand_placed, "walking: the weapon rides in the fist again")
	hero.visual.set_locomotion(false)
	hero.visual.play_attack()
	check(not hero.visual.is_pose_showing(), "attacking hides the idle")
	hero.visual.stop_attack_clip(false)
	hero.visual._on_attack_animation_finished()
	check(hero.visual.is_pose_showing(), "idle comes back after the attack")
	# Hero-mode idle: the weapon is part of the frames, so the held one hides.
	hero.configure_pose_clips({"idle": _pose_clip("hero")})
	hero._process(0.0)
	check(hero.held_weapon.self_modulate.a == 0.0, "whole-hero idle hides the held weapon")
	hero.configure_pose_clips({})
	hero._process(0.0)
	check(not hero.visual.is_pose_showing() and hero.held_weapon.self_modulate.a == 1.0, "clearing the poses brings back the hero's art")
	hero.queue_free()
	await process_frame

func _test_tilt_and_fist() -> void:
	# A walk whose fist swings forward and back, with a fist overlay atlas.
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"walk")
	var atlas_image := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0.8, 0.2, 0.2))
	var atlas := ImageTexture.create_from_image(atlas_image)
	for index in range(2):
		var piece := AtlasTexture.new()
		piece.atlas = atlas
		piece.region = Rect2(index * 32, 0, 32, 32)
		frames.add_frame(&"walk", piece)
	Config.runtime_frames["hero_walk"] = frames
	Config.runtime_manifests["hero_walk"] = {"cell_size": [32, 32], "union_crop": [272, 470, 304, 502], "hand_track": [[30.0, -200.0], [-30.0, -200.0]]}
	Config.runtime_hand_atlases["hero_walk"] = atlas
	var hero := _hero()
	await process_frame
	hero.configure_held_weapon(_weapon_texture(), Vector2(0.5, 0.9))
	hero.visual.set_locomotion(true)
	hero.visual.walk_sprite.stop()
	hero.visual.walk_sprite.frame = 0
	var forward: float = hero.visual.hand_follow_tilt()
	hero.visual.walk_sprite.frame = 1
	var back: float = hero.visual.hand_follow_tilt()
	check(forward < 0.0 and back > 0.0 and absf(forward) <= 15.0, "weapon tilts with the arm swing (%.1f, %.1f)" % [forward, back])
	hero._process(0.0)
	check(is_equal_approx(hero.held_weapon_tilt_degrees, back) and absf(rad_to_deg(hero.held_weapon.rotation) - back) < 0.01, "the held weapon turns by the tilt")
	hero.visual.set_facing(-1)
	check(is_equal_approx(hero.visual.hand_follow_tilt(), -back), "facing left mirrors the tilt")
	check(hero.visual.fist_sprite.visible and hero.visual.fist_sprite.region_rect == Rect2(32, 0, 32, 32), "front fist drawn over the weapon on the frame showing")
	hero.clear_held_weapon()
	hero._process(0.0)
	check(not hero.visual.fist_sprite.visible, "no weapon, no fist overlay")
	hero.queue_free()
	Config.runtime_frames.erase("hero_walk")
	Config.runtime_manifests.erase("hero_walk")
	Config.runtime_hand_atlases.erase("hero_walk")
	await process_frame
	# The fist overlay is cut out around the tracked fist.
	var sheet := Image.create_empty(40, 40, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(10, 5, 20, 30), Color(0.8, 0.2, 0.2))
	var cut := HeroAnimations.hand_atlas_image(sheet, [[0.0, -10.0]], 1, Vector2i(40, 40), 268.0, 476.0, Vector2(288, 496), 100.0)
	check(cut != null and cut.get_pixel(20, 10).a > 0.5 and cut.get_pixel(20, 33).a < 0.5, "hand atlas keeps the fist, drops the rest of the body")

func _cleanup() -> void:
	OS.move_to_trash(ProjectSettings.globalize_path(TEMP))
	OS.move_to_trash(ProjectSettings.globalize_path(ASSET_TEMP))
