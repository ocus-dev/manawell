extends SceneTree

## Creature Lab: concept listing, reference prep, prompt versions, a full
## generate -> collect -> install -> encyclopedia round trip against a fake
## ComfyUI (no GPU or network), and the take record that recreates it.
## Everything is written under user://creature_lab_test/.

const Registry = preload("res://scripts/model/creature_registry.gd")
const AnimationScript = preload("res://scripts/model/creature_animation.gd")
const Art = preload("res://scripts/tools/creature_lab_art.gd")
const LabScene = preload("res://scenes/tools/creature_lab.tscn")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const HeroAnimationsScript = preload("res://scripts/model/hero_animations.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

const CREATURE := "spiker_stage_1"

var failures := 0
var temp := ""

## Stands in for comfy_animation_client.gd: records what was submitted and
## "renders" frames by bobbing the uploaded reference up and down.
class FakeComfy extends Node:
	signal status_changed(text: String)
	var base_url := "http://fake-comfy:8188"
	var last_frame_optional := true
	var busy := false
	var uploads: Dictionary = {}
	var graphs: Array = []
	var frames: Array = []
	var fail_next := false
	func set_url(url: String) -> String:
		base_url = url
		return url
	func check_server() -> Dictionary:
		return {"ok": true, "error": "", "h3": true, "trellis": true, "last_frame_optional": last_frame_optional, "missing_models": []}
	func upload(path: String, upload_name: String) -> Dictionary:
		uploads[upload_name] = Image.load_from_file(path)
		return {"ok": true, "error": "", "name": upload_name}
	func run_graph(graph: Dictionary, _token: String, _label: String, on_queued: Callable = Callable()) -> Dictionary:
		graphs.append(graph)
		if on_queued.is_valid():
			on_queued.call("prompt-%d" % graphs.size())
		if fail_next:
			fail_next = false
			return {"ok": false, "error": "ComfyUI reported an error: out of memory"}
		var reference: Image = uploads[str(graph["1"]["inputs"]["image"])]
		var count := int(graph["7"]["inputs"]["length"])
		frames.clear()
		var images: Array = []
		for index in range(count):
			var frame := reference.duplicate() as Image
			frame.convert(Image.FORMAT_RGBA8)
			var lifted := Image.create_empty(frame.get_width(), frame.get_height(), false, Image.FORMAT_RGBA8)
			lifted.fill(Color8(180, 180, 180))
			var dy := -int(round(6.0 * sin(TAU * index / count)))
			lifted.blit_rect(frame, Rect2i(0, maxi(0, -dy), frame.get_width(), frame.get_height() - absi(dy)), Vector2i(0, maxi(0, dy)))
			frames.append(lifted.save_png_to_buffer())
			images.append({"filename": "master_%05d_.png" % index, "subfolder": "x", "type": "output"})
		return {"ok": true, "error": "", "prompt_id": "prompt-%d" % graphs.size(), "history": {"outputs": {"17": {"images": images}}, "status": {"completed": true, "status_str": "success"}}}
	func wait_for(_prompt_id: String, _label: String) -> Dictionary:
		return {"ok": false, "error": "not used"}
	func download(picture: Dictionary) -> Dictionary:
		var index := int(str(picture["filename"]).get_slice("_", 1))
		return {"ok": true, "error": "", "bytes": frames[index]}
	func cut_out(_path: String, _job: String) -> Dictionary:
		return {"ok": false, "error": "not used"}
	func cancel() -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	temp = ProjectSettings.globalize_path("user://creature_lab_test")
	_remove_tree(temp)
	DirAccess.make_dir_recursive_absolute(temp.path_join("art/creatures/enemies/spiker"))
	_make_concept(temp.path_join("art/creatures/enemies/spiker/spiker_stage_1.png"))
	_make_concept(temp.path_join("art/creatures/enemies/spiker/spiker_stage_0.png"))
	Registry.repo_root_override = temp
	Registry.data_root = temp.path_join("data/creatures")
	Registry.stills_root = temp.path_join("stills")
	Registry.reload_index()
	Art.animations_root = temp.path_join("animations")
	HeroAnimationsScript.backups_root = temp.path_join("backups")

	_check_names_and_templates()
	await _check_lab()

	Registry.repo_root_override = ""
	Registry.data_root = Registry.DEFAULT_DATA_ROOT
	Registry.stills_root = Registry.STILLS_ROOT
	Registry.reload_index()
	Registry.clear_art_cache()
	_remove_tree(temp)
	if failures == 0:
		print("PASS creature lab: concepts, reference, prompt versions, generate/install round trip, take record, encyclopedia")
		quit(0)
	else:
		push_error("creature lab checks failed: %d" % failures)
		quit(1)

func _check_names_and_templates() -> void:
	check(Registry.stage_from_name("shell_walker_stage_3") == 3, "stage parsed")
	check(Registry.stage_from_name("gordon_queen") == -1, "no stage")
	check(Registry.id_from_name("Shell Walker stage 2") == "shell_walker_stage_2", "id slug")
	check(Registry.name_from_name("shell_walker_stage_2") == "Shell Walker", "display name")
	check(AnimationScript.frame_count(3.0) == 73, "3 s is 73 H3 frames like workflows.py")
	check(AnimationScript.template("walk", "right").contains("facing right") and AnimationScript.template("walk").contains("walking stride"), "walk template")
	check(Art.sample_indices(73, 24.0, 12.0).size() == 37, "12 fps sampling of 73 frames")
	var families := Registry.list_concepts()
	check(families.size() == 1 and families[0]["files"].size() == 2, "concepts grouped by family")
	check(int(families[0]["files"][0]["stage"]) == 0, "sorted by stage")
	var graph := AnimationScript.graph("p", "a.png", "", 576, 3.0, 7, "x")
	check(not graph.has("2") and not graph["7"]["inputs"].has("last_frame"), "free ending leaves out the last frame")
	check(AnimationScript.graph("p", "a.png", "a.png", 576, 3.0, 7, "x")["7"]["inputs"]["last_frame"] == ["2", 0], "rest ending wires the last frame")

func _check_lab() -> void:
	var lab: Node = LabScene.instantiate()
	lab.resize_window = false
	root.add_child(lab)
	await process_frame
	var fake := FakeComfy.new()
	lab.remove_child(lab.comfy)
	lab.comfy.queue_free()
	lab.comfy = fake
	lab.add_child(fake)
	check(lab.tiles.size() == 2, "both concepts listed")
	lab.select_concept("art/creatures/enemies/spiker/spiker_stage_1.png")
	check(lab.creature_id == CREATURE and not lab.is_saved(), "new concept opens a draft")
	check(lab.generate_button.disabled, "generate needs a reference")

	var prepared: Dictionary = await lab.prepare_reference("solid")
	check(prepared.ok, "reference prepared: %s" % prepared.get("error", ""))
	check(lab.is_saved() and FileAccess.file_exists(lab.reference_path()), "reference saved and creature created")
	var reference := Image.load_from_file(lab.reference_path())
	check(reference.get_size() == Vector2i(576, 576), "576 canvas")
	var still := Image.load_from_file(temp.path_join("stills/%s.png" % CREATURE))
	check(still != null and still.get_pixel(5, 5).a == 0.0, "transparent still")
	check(lab.ground_anchor() == Vector2(288, 495), "default anchor at 86%")
	var box := Art.alpha_bounds(still)
	# The concept's head (its highest point) is on the left; mirrored, the
	# top row of the creature is right of centre.
	var top_sum := 0.0
	var top_count := 0
	for x in range(box.position.x, box.end.x):
		if still.get_pixel(x, box.position.y + 1).a > 0.5:
			top_sum += x
			top_count += 1
	check(top_count > 0 and top_sum / top_count > box.get_center().x, "left-facing concept mirrored to face right")

	# Prompt versions.
	lab.select_state("idle")
	check(lab.prompt_text() == AnimationScript.template("idle", "right").strip_edges(), "idle starts from the template")
	lab.set_prompt_text("A custom idle prompt.")
	var first: Dictionary = lab.save_prompt()
	check(first.ok and first.version == 1 and first.new, "first version saved")
	lab.set_prompt_text("A custom idle prompt, slower.")
	var second: Dictionary = lab.save_prompt()
	check(second.version == 2, "edited text is v2")
	lab.set_prompt_text("A custom idle prompt.")
	var again: Dictionary = lab.save_prompt()
	check(again.version == 1 and not again.new, "same wording reuses v1")
	check(Registry.current_prompt(CREATURE, "idle").get("version") == 1, "v1 current again")

	# Generate a take.
	lab.seed_spin.value = 4242
	lab.seconds_spin.value = 1.0
	var made: Dictionary = await lab.generate()
	check(made.ok, "generate: %s" % made.get("error", ""))
	var take := Registry.load_take(CREATURE, str(made.take_id))
	check(take.get("status") == "complete", "take complete")
	check(int(take.get("seed")) == 4242 and take.get("prompt") == "A custom idle prompt." and int(take.get("prompt_version")) == 1, "take keeps prompt, version and seed")
	check(take.get("graph", {}).get("7", {}).get("inputs", {}).get("prompt") == "A custom idle prompt.", "take keeps the submitted graph")
	check(int(take["graph"]["8"]["inputs"]["noise_seed"]) == 4242, "graph seed")
	check(take.get("comfy", {}).get("prompt_id") == "prompt-1", "prompt id recorded")
	check(take["masters"]["frames"].size() == AnimationScript.frame_count(1.0), "every frame downloaded")
	check(str(take["reference"]["sha256"]) == FileAccess.get_sha256(lab.reference_path()), "reference hash recorded")
	check(take["graph"]["7"]["inputs"].has("last_frame"), "idle ends on the reference")

	# Install it.
	lab.fps_spin.value = 12
	var installed: Dictionary = await lab.install_take()
	check(installed.ok, "install: %s" % installed.get("error", ""))
	var folder := temp.path_join("animations/%s_idle" % CREATURE)
	check(FileAccess.file_exists(folder.path_join("atlas.png")) and FileAccess.file_exists(folder.path_join("animation.tres")), "clip files written")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	check(int(manifest.frame_count) == Art.sample_indices(AnimationScript.frame_count(1.0), 24.0, 12.0).size() and str(manifest.take_id) == str(made.take_id), "manifest names the take")
	var crop: Array = manifest.union_crop
	check(int(crop[3]) >= 495 and int(crop[1]) <= 495 - int(Registry.get_creature(CREATURE)["reference"]["body_height"]), "one union crop around the feet line")
	check(ConfigScript.runtime_frames.has("%s_idle" % CREATURE), "clip plays this run")
	check(str(Registry.get_creature(CREATURE)["states"]["idle"]["take"]) == str(made.take_id), "creature records the installed take")
	check(lab.state_buttons["idle"].text.begins_with("✓"), "idle marked installed")
	var raw := FileAccess.get_file_as_string(Registry.take_path(CREATURE, str(made.take_id)))
	check(raw.contains("\"noise_seed\": 4242") and not raw.contains("4242.0") and not raw.contains("\", 0.0]"), "saved graph keeps integer seeds and links after re-saving")
	check(FileAccess.file_exists(Registry.take_files_dir(CREATURE, str(made.take_id)).path_join("api.json")), "graph exported as api.json")

	# A failed render is recorded too.
	lab.select_state("death")
	check(not lab.rest_check.button_pressed, "death ends free")
	fake.fail_next = true
	var failed: Dictionary = await lab.generate()
	check(not failed.ok and Registry.load_take(CREATURE, str(failed.take_id)).get("status") == "failed", "failed take kept with its error")
	check(not fake.graphs[-1]["7"]["inputs"].has("last_frame"), "death render leaves the end free")

	# Recreate: loading a take's settings puts back its prompt and seed.
	lab.select_state("idle")
	lab.seed_spin.value = 1
	lab.set_prompt_text("something else")
	lab.use_take_settings(str(made.take_id))
	check(int(lab.seed_spin.value) == 4242 and lab.prompt_text() == "A custom idle prompt.", "take settings restored")

	# Encyclopedia.
	lab.archetype_picker.select(1)
	lab._on_field_changed()
	var added: Dictionary = lab.add_to_encyclopedia()
	check(added.ok, "added to encyclopedia")
	check(MonsterStatsScript.monster_ids().has(CREATURE), "listed by MonsterStats")
	check(MonsterStatsScript.archetype(CREATURE) == "breaker", "behaves as a breaker")
	check(is_equal_approx(MonsterStatsScript.default_value(CREATURE, "health"), MonsterStatsScript.default_value("breaker", "health")), "starts from breaker stats")
	MonsterStatsScript.set_stat(CREATURE, "health", 77.0)
	check(is_equal_approx(MonsterStatsScript.get_stat(CREATURE, "health"), 77.0), "own stats are tunable")
	check(MonsterStatsScript.export_map().has(CREATURE), "saved with the other monsters")
	var asset := ConfigScript.asset_for(CREATURE)
	check(not asset.is_empty() and ConfigScript.frames_for(asset, "idle") != null, "visual config builds its art")
	check(ConfigScript.frames_for(asset, "walk") == null, "missing clips fall back")
	lab.open_encyclopedia()
	await process_frame
	check(lab.encyclopedia.is_open() and lab.encyclopedia.tiles.has(CREATURE), "encyclopedia shows the creature")
	check(lab.encyclopedia.selected_id == CREATURE and not lab.encyclopedia.anim_buttons["idle"].disabled, "encyclopedia previews its idle")
	lab.encyclopedia.close()

	# An enemy drawn and tuned as the creature.
	var enemy: Node = EnemyScript.new()
	enemy.monster_override = CREATURE
	enemy.setup(EnemyScript.EnemyKind.BREAKER, 1, 1, null)
	root.add_child(enemy)
	await process_frame
	check(enemy.monster_id() == CREATURE and is_equal_approx(enemy.max_health, 77.0), "enemy uses the creature's stats")
	check(enemy.visual.asset_id == CREATURE, "enemy uses the creature's art")
	enemy.queue_free()

	var removed: Dictionary = lab.remove_from_encyclopedia()
	check(removed.ok and not MonsterStatsScript.monster_ids().has(CREATURE), "removed from the encyclopedia")
	MonsterStatsScript.reset_all()
	ConfigScript.runtime_frames.erase("%s_idle" % CREATURE)
	ConfigScript.runtime_manifests.erase("%s_idle" % CREATURE)
	lab.queue_free()
	await process_frame

## A left-facing blob creature on a flat light background with a dark frame
## line (like the concept sheets): body ellipse, head on the left.
func _make_concept(path: String) -> void:
	var image := Image.create_empty(400, 300, false, Image.FORMAT_RGBA8)
	image.fill(Color8(205, 205, 200))
	for x in range(400):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 299, Color.BLACK)
	for y in range(300):
		for x in range(400):
			var body := pow((x - 210) / 110.0, 2) + pow((y - 170) / 70.0, 2)
			var head := pow((x - 95) / 40.0, 2) + pow((y - 120) / 36.0, 2)
			if body <= 1.0 or head <= 1.0:
				image.set_pixel(x, y, Color8(70, 50, 80))
			elif x > 150 and x < 270 and y > 220 and y < 262 and (x / 20) % 2 == 0:
				image.set_pixel(x, y, Color8(60, 40, 70))
	image.save_png(path)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_directories():
		_remove_tree(path.path_join(name))
	for name in directory.get_files():
		directory.remove(name)
	DirAccess.remove_absolute(path)
