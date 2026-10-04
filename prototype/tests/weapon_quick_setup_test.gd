extends SceneTree

## The clip importer's quick setup (two sheets, one button, frame check), the
## ray weapon finder, hit / timing guesses, steady weapon size, and the swing
## trail the game draws between hero_weapon attack frames.

const Imp = preload("res://scripts/tools/weapon_clip_import.gd")
const Clip = preload("res://scripts/model/weapon_clip.gd")
const ImporterScript = preload("res://scripts/tools/weapon_clip_importer.gd")
const Art = preload("res://scripts/tools/weapon_lab_art.gd")
const HeroScript = preload("res://scripts/game/player.gd")

const TEMP := "user://weapon_quick_setup_test"
const BODY := Color8(200, 40, 40)
const LEGS := Color8(60, 60, 70)
const FIST := Color8(40, 40, 50)
const BLADE := Color8(150, 170, 190)
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP))
	Art.repo_root_override = ProjectSettings.globalize_path(TEMP.path_join("repo"))
	_check_finder()
	_check_guesses()
	await _check_quick_setup()
	await _check_swing_trail()
	Art.repo_root_override = ""
	OS.move_to_trash(ProjectSettings.globalize_path(TEMP))
	if failures == 0:
		print("PASS weapon quick setup: ray finder (blade across the body), hit and snappy timing guesses, two-sheet quick setup, frame check, steady size, swing trail")
		quit(0)
	else:
		print("FAIL weapon quick setup: %d check(s) failed" % failures)
		quit(1)

## One hero pose at `x`: body block, legs and a fist in front at (x+40, y).
func _draw_pose(image: Image, x: int, fist_y: int) -> void:
	image.fill_rect(Rect2i(x, 80, 34, 70), BODY)
	image.fill_rect(Rect2i(x + 4, 150, 26, 40), LEGS)
	image.fill_rect(Rect2i(x + 34, fist_y - 6, 12, 12), FIST)

## A blade from the fist toward `direction`, `length` px long, 6 px thick.
func _draw_blade(image: Image, from: Vector2, direction: Vector2, length: float) -> void:
	var d := direction.normalized()
	var n := Vector2(-d.y, d.x)
	for t in range(int(length) * 2):
		for w in range(-6, 7):
			var p := from + d * (t * 0.5) + n * (w * 0.5)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(Vector2i(p), BLADE)

## Three poses: blade up, blade straight forward, blade down across the legs
## (drawn in front of the body). Returns [body sheet, weapon sheet] paths.
func _make_sheets() -> Array:
	var body := Image.create_empty(480, 220, false, Image.FORMAT_RGBA8)
	body.fill(Color8(236, 236, 236))
	var weapon := body.duplicate() as Image
	var poses := [[40, 110, Vector2(0.3, -1.0)], [190, 100, Vector2(1.0, -0.05)], [340, 115, Vector2(-0.35, 1.0)]]
	for pose in poses:
		_draw_pose(body, pose[0], pose[1])
		_draw_pose(weapon, pose[0], pose[1])
	for pose in poses:
		var fist := Vector2(int(pose[0]) + 40, int(pose[1]))
		# The handle stub behind the fist, then the blade beyond it.
		_draw_blade(weapon, fist - Vector2(pose[2]).normalized() * 12.0, pose[2], 12.0)
		_draw_blade(weapon, fist + Vector2(pose[2]).normalized() * 7.0, pose[2], 70.0)
		weapon.fill_rect(Rect2i(int(fist.x) - 6, int(fist.y) - 6, 12, 12), FIST)
	var body_path := ProjectSettings.globalize_path(TEMP.path_join("body.png"))
	var weapon_path := ProjectSettings.globalize_path(TEMP.path_join("with weapon.png"))
	body.save_png(body_path)
	weapon.save_png(weapon_path)
	return [body_path, weapon_path]

func _check_finder() -> void:
	# A frame where the blade crosses in front of the body: the old finder
	# only saw the part sticking out.
	var body := Image.create_empty(120, 160, false, Image.FORMAT_RGBA8)
	body.fill_rect(Rect2i(30, 20, 40, 100), BODY)
	body.fill_rect(Rect2i(34, 120, 32, 38), LEGS)
	body.fill_rect(Rect2i(70, 50, 12, 12), FIST)
	var ref := body.duplicate() as Image
	var fist := Vector2(76, 56)
	var down := Vector2(-1.0, 1.4).normalized()
	_draw_blade(ref, fist + down * 7.0, down, 90.0)
	_draw_blade(ref, fist - down * 7.0, -down, 10.0)
	ref.fill_rect(Rect2i(70, 50, 12, 12), FIST)
	var anchor := Imp.feet_anchor(body)
	var found := Imp.find_weapon_ray(body, anchor, ref, Imp.feet_anchor(ref), 1.0, Vector2.ZERO)
	check(bool(found.get("ok", false)), "ray finder finds a blade drawn across the body (%s)" % found.get("error", ""))
	if bool(found.get("ok", false)):
		check(Vector2(found.grip).distance_to(Vector2(76, 56)) <= 9.0, "grip in the fist (%s)" % found.grip)
		check(Vector2(found.tip).distance_to(fist + down * 96.0) <= 8.0, "far end at the blade's tip, past the body (%s)" % found.tip)
	var weapon_only := Imp.find_weapon(body, anchor, body, anchor, 1.0, Vector2.ZERO, Imp.body_palette([body]))
	check(not bool(weapon_only.get("ok", false)), "no weapon in a weapon-free pair")

func _check_guesses() -> void:
	var anchors := [Vector2(50, 100), Vector2(50, 100), Vector2(50, 100), Vector2(50, 100), Vector2(50, 100)]
	# Ready, wind-up back over the head, mid swing, hit forward, follow-through.
	var tips := [Vector2(90, 60), Vector2(0, -10), Vector2(80, 0), Vector2(130, 70), Vector2(110, 90)]
	var track: Array = []
	for tip in tips:
		track.append({"grip": Vector2(60, 60), "tip": tip})
	var hit := Imp.guess_hit(track, anchors)
	check(hit == 2 or hit == 3, "hit guessed after the big forward sweep (%d)" % hit)
	var holds := Imp.snappy_holds(track, anchors, 3, 80.0)
	check(holds[1] > 80.0 and holds[3] > holds[1] and holds[2] < 80.0, "snappy timing: wind-up and hit held, swing fast (%s)" % str(holds))
	check(Imp.guess_hit([], []) == -1 and Imp.snappy_holds(track, anchors, -1, 80.0) == [80.0, 80.0, 80.0, 80.0, 80.0], "no guesses without a track")

func _check_quick_setup() -> void:
	var sheets := _make_sheets()
	var importer: Control = ImporterScript.new()
	root.add_child(importer)
	await process_frame
	importer.start("quick_blade", 0.24, 0.6)
	importer.set_advanced(false)
	check(importer.is_quick() and importer._sections["quick"].visible and not importer._sections["source"].visible, "weapon animations open on the quick setup")
	check(not await importer.quick_run(), "needs both sheets")
	importer.set_quick_sheet("body", sheets[0])
	importer.set_quick_sheet("weapon", sheets[1])
	check(not importer._quick_run_button.disabled, "run button ready once both sheets are picked")
	check(await importer.quick_run(), "quick setup runs (%s)" % importer.last_error)
	check(importer.mode == "hero_weapon" and importer.cut.size() == 3 and importer.ref_cut.size() == 3 and importer.placed_count() == 3, "both sheets cut, lined up, weapon on every frame (%d placed)" % importer.placed_count())
	for index in range(3):
		var fist := Vector2(40 + index * 150 + 40, [110, 100, 115][index])
		var box: Rect2i = importer.boxes[index]
		var grip: Vector2 = Vector2(importer.track[index].grip) + Vector2(box.position)
		check(grip.distance_to(fist) <= 10.0, "frame %d: grip in the fist (%s vs %s)" % [index + 1, grip, fist])
	check(importer.steady_size and importer.snappy and importer.hits.size() == 1, "steady size on, hit guessed, snappy timing")
	check(importer._quick_check.visible and importer._quick_save.visible, "check and save steps showing")
	# Frame check.
	importer.select_frame(0)
	importer.approve_frame()
	check(importer.checked[0] and importer.selected == 1 and importer.checked_count() == 1, "Looks right okays the frame and moves on")
	var before: Dictionary = importer.track[1].duplicate()
	importer.swap_ends(1)
	check(importer.track[1].grip == before.tip and importer.track[1].tip == before.grip, "Swap ends")
	importer.swap_ends(1)
	importer.move_nearest_dot(1, Vector2(before.grip) + Vector2(3, 2))
	check(importer.track[1].grip == Vector2(before.grip) + Vector2(3, 2) and importer.track[1].tip == before.tip, "a click moves the nearer dot")
	var grip_before: Vector2 = importer.track[1].grip
	var tip_before: Vector2 = importer.track[1].tip
	importer.move_weapon(1, Vector2(0, -4))
	check(importer.track[1].grip == grip_before + Vector2(0, -4) and importer.track[1].tip == tip_before + Vector2(0, -4), "dragging the line moves the whole weapon")
	importer.move_weapon(1, Vector2(0, 4))
	importer.approve_frame()
	importer.approve_frame()
	check(importer.checked_count() == 3, "every frame okayed")
	# Steady size: every frame's weapon is drawn at the middle length.
	var length: float = importer.steady_length()
	for index in range(3):
		check(absf(Vector2(importer.effective_tip(index)).distance_to(importer.track[index].grip) - length) < 0.01, "frame %d drawn at the steady length" % (index + 1))
	importer.make_hit(2)
	check(importer.hits == [2], "hit frame moved")
	importer.set_snappy(false)
	check(importer.holds.all(func(ms: float) -> bool: return is_equal_approx(ms, Clip.DEFAULT_FRAME_MS)), "snappy off: even timing")
	importer.set_snappy(true)
	importer.set_blink(true)
	importer._process(0.5)
	check(importer._blink_ref, "blink flips to the sheet with the weapon")
	importer.set_blink(false)
	# Saving keeps one weapon length in the clip and the quick flags in the project.
	var saved_clip: Dictionary = {}
	importer.saved.connect(func(clip: Dictionary, _target: String) -> void: saved_clip.merge(clip))
	importer.type_label = "Sword"
	var result: Dictionary = importer.save_clip("weapon")
	check(not result.is_empty() and saved_clip.has("track"), "quick clip saves (%s)" % importer.last_error)
	if not result.is_empty():
		var lengths: Array = result.track.map(func(entry: Dictionary) -> float: return float(entry.length))
		check(absf(float(lengths.max()) - float(lengths.min())) < 0.01, "saved track has one weapon length (%s)" % str(lengths))
		var project := Imp.load_project(str(result.project))
		check(bool(project.get("steady_size", false)) and bool(project.get("snappy", false)) and project.get("checked", []).size() == 3, "project remembers steady size, timing and the check")
		check(importer.load_project(str(result.project), "quick_blade", 0.24, 0.6) and importer.steady_size and importer.checked_count() == 3, "reopened with its quick settings")
	importer.set_advanced(true)
	check(not importer.is_quick() and importer._sections["align"].visible and not importer._quick_check.visible, "More options shows every step")
	importer.set_advanced(false)
	importer.queue_free()
	await process_frame

func _check_swing_trail() -> void:
	# A two-frame hero_weapon clip: the weapon points up, then forward.
	var sheet := Image.create_empty(80, 80, false, Image.FORMAT_RGBA8)
	for index in range(2):
		sheet.fill_rect(Rect2i(index * 40 + 12, 20, 16, 58), BODY)
	var path := ProjectSettings.globalize_path(TEMP.path_join("trail.png"))
	sheet.save_png(path)
	var clip := {"label": "Swing", "mode": "hero_weapon", "source": path, "frame_count": 2, "columns": 2, "cell": [40.0, 80.0], "anchor": [20.0, 78.0], "body_height": 58.0, "frame_ms": [100.0, 100.0], "attacks": [{"start": 0, "end": 1, "hit": 1}], "track": [{"grip": [28.0, 50.0], "angle": -90.0, "length": 30.0, "behind": false}, {"grip": [30.0, 48.0], "angle": 0.0, "length": 30.0, "behind": false}]}
	var hero: Node2D = HeroScript.new()
	root.add_child(hero)
	await process_frame
	var weapon := Image.create_empty(20, 80, false, Image.FORMAT_RGBA8)
	weapon.fill_rect(Rect2i(8, 0, 4, 80), Color.WHITE)
	hero.configure_held_weapon(ImageTexture.create_from_image(weapon), Vector2(0.5, 0.9))
	hero.configure_attack_clip(clip, 0.1, 0.6)
	hero.visual.play_attack()
	hero._process(0.0)
	check(hero._hand_placed and hero.swing_trail_count() == 0, "first frame: weapon in the hands, no trail yet")
	hero.visual.advance_attack_clip(0.15)
	hero._process(0.0)
	check(hero.visual.clip_frame == 1 and hero.swing_trail_count() == SwingTrailSteps(hero), "a big turn between frames leaves a trail (%d)" % hero.swing_trail_count())
	hero._process(0.2)
	check(hero.swing_trail_count() == 0, "the trail fades out")
	hero.swing_trail_enabled = false
	hero.visual.stop_attack_clip(false)
	hero.visual.play_attack()
	hero._process(0.0)
	hero.visual.advance_attack_clip(0.15)
	hero._process(0.0)
	check(hero.swing_trail_count() == 0, "trail can be switched off")
	hero.queue_free()
	await process_frame

func SwingTrailSteps(hero: Node) -> int:
	return int(hero.SWING_TRAIL_STEPS)
