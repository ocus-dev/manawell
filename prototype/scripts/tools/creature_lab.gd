extends Node

## Creature Lab: dev tool that turns creature concept art into animated
## monsters in the encyclopedia, through the MiniMax H3 ComfyUI workflow.
##
##   Concept art   art/creatures/enemies/<family>/<name>_stage_<n>.png, listed
##                 by family and evolution stage on the left.
##   1. CREATURE   name, behavior (which built-in monster it fights like),
##                 which way the art faces, in-game height, description.
##   2. REFERENCE  cut the concept out (locally or with Trellis 2) and place
##                 it on the 576 px H3 canvas (same framing as
##                 tools/animation_pipeline/prepare.py). Click to set the feet.
##   3. ANIMATIONS per state (idle, walk, attack, wind-up, hurt, death, spawn):
##                 edit the prompt, generate on ComfyUI, review takes, install
##                 one as the game clip assets/side-view/animations/<id>_<state>/.
##   4. ENCYCLOPEDIA add the creature to the Monster Encyclopedia, with stats
##                 starting from its behavior's monster.
##
## Every prompt version and every generation (prompt, seed, length, models,
## the exact API graph, server, ComfyUI prompt id, frame hashes) is saved in
## data/creatures/ (see CreatureRegistry), so any take can be recreated.

const Registry = preload("res://scripts/model/creature_registry.gd")
const AnimationScript = preload("res://scripts/model/creature_animation.gd")
const Art = preload("res://scripts/tools/creature_lab_art.gd")
const ClientScript = preload("res://scripts/tools/comfy_animation_client.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const EncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const LAB_CANVAS := Vector2i(1600, 900)
const LAB_WINDOW := Vector2i(1920, 1040)

const AMBER := Color("f0a836")
const AMBER_DEEP := Color("b9761c")
const INK := Color("ece6da")
const MUTED := Color("9ba4ac")
const PLATE := Color("20252a")
const PLATE_2 := Color("2a3036")
const EDGE := Color("434c55")
const GOOD := Color("75d5a5")
const BAD := Color("f09a9a")

const CUTOUTS := [
	["auto", "Auto"],
	["solid", "Flat background (local)"],
	["comfy", "ComfyUI Trellis 2"],
	["transparent", "PNG transparency"],
]
const FRAME_CUTOUTS := [
	["solid", "Grey background (local)"],
	["comfy", "Trellis 2 per frame"],
]
const STATE_TIPS := {
	"idle": "Loops while standing still.",
	"walk": "Loops while moving; in place, no travel.",
	"attack": "Plays once per attack.",
	"windup": "Telegraph before an attack (ranged monsters use it before each shot).",
	"hurt": "Plays when hit. Without it the monster flashes red.",
	"death": "Plays once when killed. Without it the body fades and sinks.",
	"spawn": "Plays when it appears. Without it the monster fades in.",
}

## Tests turn this off (no window resizing).
var resize_window := true

var ui: CanvasLayer
var root: Control
var comfy: Node
var encyclopedia: CanvasLayer

var families: Array = []
var concept_path := ""
var creature_id := ""
var record: Dictionary = {}
var state := "idle"
var takes: Array = []
var selected_take := ""
var busy := false
var _loading := false
## check_comfy() succeeded for the current URL (so last_frame_optional is known).
var _checked_url := ""

var _thumbs: Dictionary = {}
var _preview_frames: Array = []
var _preview_fps := 12.0
var _preview_time := 0.0

# widgets
var comfy_url: LineEdit
var comfy_status: Label
var tile_list: VBoxContainer
var tile_group := ButtonGroup.new()
var tiles: Dictionary = {}
var page: Control
var empty_page: Label
var page_title: Label
var page_meta: Label
var concept_preview: TextureRect
var name_edit: LineEdit
var id_label: Label
var archetype_picker: OptionButton
var facing_picker: OptionButton
var height_spin: SpinBox
var desc_edit: TextEdit
var cutout_picker: OptionButton
var tolerance_spin: SpinBox
var prepare_button: Button
var reference_preview: TextureRect
var anchor_overlay: Control
var reference_status: Label
var state_buttons: Dictionary = {}
var state_tip: Label
var version_picker: OptionButton
var prompt_edit: TextEdit
var prompt_note: Label
var seed_spin: SpinBox
var seconds_spin: SpinBox
var steps_spin: SpinBox
var rest_check: CheckBox
var generate_button: Button
var stop_button: Button
var gen_status: Label
var take_list: ItemList
var take_preview: TextureRect
var take_info: Label
var use_take_button: Button
var collect_button: Button
var fps_spin: SpinBox
var start_spin: SpinBox
var end_spin: SpinBox
var frame_cutout_picker: OptionButton
var frame_tolerance_spin: SpinBox
var install_button: Button
var installed_preview: TextureRect
var encyclopedia_status: Label
var add_button: Button
var remove_button: Button
var status_label: Label

var _saved_canvas := Vector2i.ZERO
var _saved_window := Vector2i.ZERO
var _saved_window_position := Vector2i.ZERO
var _saved_aspect := Window.CONTENT_SCALE_ASPECT_KEEP

func _ready() -> void:
	_enlarge_window()
	comfy = ClientScript.new()
	comfy.name = "ComfyAnimation"
	add_child(comfy)
	comfy.status_changed.connect(func(text: String) -> void: _set_gen_status(text))
	_build()
	comfy_url.text = comfy.base_url
	reload_concepts()
	if not families.is_empty():
		select_concept(str(families[0]["files"][0]["path"]))
	else:
		_show_page(false)

func _process(delta: float) -> void:
	if _preview_frames.is_empty() or take_preview == null:
		pass
	else:
		_preview_time += delta
		var index := int(_preview_time * _preview_fps) % _preview_frames.size()
		take_preview.texture = _preview_frames[index]
	if installed_preview != null and not creature_id.is_empty():
		var frames := _installed_frames()
		if frames != null:
			var animation := StringName(state)
			var count := frames.get_frame_count(animation) if frames.has_animation(animation) else 0
			if count > 0:
				var fps := maxf(1.0, frames.get_animation_speed(animation))
				installed_preview.texture = frames.get_frame_texture(animation, int(_preview_time * fps) % count)

func _unhandled_input(event: InputEvent) -> void:
	if encyclopedia != null and encyclopedia.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return_to_title()
		get_viewport().set_input_as_handled()

func return_to_title() -> void:
	if comfy != null:
		comfy.cancel()
	_restore_window()
	get_tree().change_scene_to_file(TITLE_SCENE)

# ---------- concepts ----------

func reload_concepts() -> void:
	families = Registry.list_concepts()
	_render_tiles()

func concept_entry(path: String) -> Dictionary:
	for family in families:
		for file in family["files"]:
			if str(file["path"]) == path:
				return file
	return {}

## Opens a concept image's page, creating its draft record if it's new.
func select_concept(path: String) -> void:
	var entry := concept_entry(path)
	if entry.is_empty():
		return
	concept_path = path
	creature_id = str(entry["id"])
	if Registry.has(creature_id):
		record = Registry.get_creature(creature_id)
	else:
		record = {
			"id": creature_id,
			"name": str(entry["name"]),
			"family": str(entry["family"]),
			"stage": int(entry["stage"]),
			"concept": path,
			"archetype": _guess_archetype(str(entry["family"])),
			"facing": "left",
			"display_height": 0.0,
			"desc": "",
			"states": {},
			"in_encyclopedia": false,
		}
		record["display_height"] = float(Registry.ARCHETYPES[record["archetype"]]["display_height"])
	for key in Registry.STATES:
		Art.register_unimported_clip(creature_id, key)
	_sync_tiles()
	_show_page(true)
	_apply_record_to_controls()
	select_state(state)

func _guess_archetype(family: String) -> String:
	var lower := family.to_lower()
	if lower.contains("breaker") or lower.contains("brute") or lower.contains("queen"):
		return "breaker"
	if lower.contains("spit") or lower.contains("ranged") or lower.contains("gunner"):
		return "ranged"
	return "pursuer"

func is_saved() -> bool:
	return Registry.has(creature_id)

## Writes the record (creating the creature in data/creatures/index.json).
func save_record() -> Dictionary:
	if creature_id.is_empty():
		return {"ok": false, "error": "Pick a concept first."}
	record["concept"] = concept_path
	var concept_abs := Registry.repo_root().path_join(concept_path)
	if FileAccess.file_exists(concept_abs):
		record["concept_sha256"] = FileAccess.get_sha256(concept_abs)
	var result := Registry.put_creature(creature_id, record)
	if result.ok:
		record = Registry.get_creature(creature_id)
		Registry.clear_art_cache()
		_sync_tiles()
	return result

func _on_field_changed() -> void:
	if _loading or creature_id.is_empty():
		return
	record["name"] = name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else str(record.get("name", creature_id))
	record["archetype"] = str(archetype_picker.get_item_metadata(archetype_picker.selected))
	var new_facing := "right" if facing_picker.selected == 1 else "left"
	var facing_changed := new_facing != str(record.get("facing", "left"))
	record["facing"] = new_facing
	record["display_height"] = height_spin.value
	record["desc"] = desc_edit.text.strip_edges()
	save_record()
	_refresh_meta()
	if facing_changed and not record.get("reference", {}).is_empty():
		_set_reference_status("The facing changed: prepare the reference again so the creature faces right in the game.", BAD)
	if bool(record.get("in_encyclopedia", false)):
		_refresh_encyclopedia()

# ---------- reference ----------

func cutout_method() -> String:
	return str(cutout_picker.get_item_metadata(cutout_picker.selected))

func concept_image() -> Image:
	var image := Image.load_from_file(Registry.repo_root().path_join(concept_path))
	return image if image != null and not image.is_empty() else null

## Cuts the concept out and places it on the H3 canvas (mirrored so it faces
## right, the way every actor's art is drawn). Returns {"ok", "error"}.
func prepare_reference(method: String = "") -> Dictionary:
	if busy:
		return {"ok": false, "error": "Busy."}
	var chosen := method if not method.is_empty() else cutout_method()
	var source := concept_image()
	if source == null:
		return _reference_fail("Couldn't read %s." % concept_path)
	busy = true
	_update_buttons()
	_set_reference_status("Cutting out the concept...", MUTED)
	await get_tree().process_frame
	var cutout: Image = null
	if chosen == "transparent" or (chosen == "auto" and Art.has_transparency(source)):
		cutout = source.duplicate() as Image
		cutout.convert(Image.FORMAT_RGBA8)
		chosen = "transparent"
	elif chosen == "comfy":
		var temp := ProjectSettings.globalize_path("user://creature_lab_concept.png")
		source.save_png(temp)
		comfy.set_url(comfy_url.text)
		var cut: Dictionary = await comfy.cut_out(temp, creature_id)
		if not cut.ok:
			busy = false
			_update_buttons()
			return _reference_fail(str(cut.error))
		cutout = cut.image
	else:
		cutout = Art.solid_cutout(source, tolerance_spin.value)
		chosen = "solid"
	await get_tree().process_frame
	cutout = Art.clean_cutout(cutout)
	if str(record.get("facing", "left")) == "left":
		cutout = Art.flipped(cutout)
	var prepared := Art.prepare_reference(cutout)
	if not prepared.ok:
		busy = false
		_update_buttons()
		return _reference_fail(str(prepared.error))
	var saved := Art.save_reference(creature_id, prepared, cutout, {"concept": concept_path, "cutout": chosen, "mirrored": str(record.get("facing", "left")) == "left"})
	busy = false
	_update_buttons()
	if not saved.ok:
		return _reference_fail(str(saved.error))
	var info: Dictionary = saved.info
	record["reference"] = {
		"dir": Registry.REFERENCES_RELATIVE.path_join(creature_id),
		"canvas": info["canvas"],
		"ground_anchor": info["ground_anchor"],
		"body_height": info["body_height"],
		"visible_bounds": info["visible_bounds"],
		"still": info["still"],
		"sha256": info["reference_sha256"],
		"cutout": chosen,
		"mirrored": info.get("mirrored", false),
	}
	var stored := save_record()
	if not stored.ok:
		return _reference_fail(str(stored.error))
	_refresh_reference()
	_set_reference_status("Reference ready (%s cutout). Check the feet line; click the picture to move it." % chosen, GOOD)
	_update_buttons()
	return {"ok": true, "error": ""}

func reference_path() -> String:
	return Registry.reference_dir(creature_id).path_join("reference.png")

func has_reference() -> bool:
	return not record.get("reference", {}).is_empty() and FileAccess.file_exists(reference_path())

func ground_anchor() -> Vector2:
	var values: Array = record.get("reference", {}).get("ground_anchor", [288, 495])
	return Vector2(float(values[0]), float(values[1]))

## Moves the feet line (canvas pixels). Installed clips keep the old one until
## they're installed again.
func set_ground_anchor(anchor: Vector2) -> void:
	if not has_reference():
		return
	var reference: Dictionary = record["reference"]
	var size: Array = reference.get("canvas", [576, 576])
	reference["ground_anchor"] = [clampi(roundi(anchor.x), 0, int(size[0])), clampi(roundi(anchor.y), 0, int(size[1]))]
	record["reference"] = reference
	save_record()
	var json_path := Registry.reference_dir(creature_id).path_join("reference.json")
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path)) if FileAccess.file_exists(json_path) else null
	if info is Dictionary:
		info["ground_anchor"] = reference["ground_anchor"]
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(info, "\t") + "\n")
			file.close()
	anchor_overlay.queue_redraw()
	var installed: Array = record.get("states", {}).keys()
	_set_reference_status("Feet line at y %d.%s" % [int(reference["ground_anchor"][1]), " Install %s again to use it." % ", ".join(installed) if not installed.is_empty() else ""], MUTED)

func _reference_fail(message: String) -> Dictionary:
	_set_reference_status(message, BAD)
	return {"ok": false, "error": message}

# ---------- prompts ----------

func select_state(new_state: String) -> void:
	if not Registry.STATES.has(new_state):
		return
	state = new_state
	for key in state_buttons:
		state_buttons[key].set_pressed_no_signal(key == state)
	state_tip.text = "%s  %s" % [new_state.capitalize(), STATE_TIPS.get(new_state, "")]
	_loading = true
	var current := Registry.current_prompt(creature_id, state)
	prompt_edit.text = str(current.get("text", template_text()))
	rest_check.button_pressed = AnimationScript.RETURNS_TO_REST.has(state)
	var latest: Dictionary = {}
	var listed := Registry.list_takes(creature_id, state)
	if not listed.is_empty():
		latest = listed[0]
	seed_spin.value = float(latest.get("seed", AnimationScript.DEFAULT_SEED))
	seconds_spin.value = float(latest.get("seconds", AnimationScript.DEFAULT_SECONDS))
	steps_spin.value = float(latest.get("steps", AnimationScript.DEFAULT_STEPS))
	_loading = false
	_refresh_versions()
	reload_takes()
	_refresh_state_buttons()

func template_text() -> String:
	# The reference is mirrored to face right, so prompts always say right.
	return AnimationScript.template(state, "right")

func prompt_text() -> String:
	return prompt_edit.text.strip_edges()

func set_prompt_text(text: String) -> void:
	prompt_edit.text = text
	_on_prompt_edited()

## Saves the editor's text as the state's current prompt (a new version when
## the wording is new). Returns CreatureRegistry.save_prompt()'s result.
func save_prompt(note: String = "") -> Dictionary:
	if not is_saved():
		var stored := save_record()
		if not stored.ok:
			return {"ok": false, "error": stored.error, "version": 0}
	var result := Registry.save_prompt(creature_id, state, prompt_text(), note)
	if result.ok:
		_refresh_versions()
		_set_status("Prompt v%d %s for %s." % [result.version, "saved" if result.new else "is current again", state])
	return result

func reset_prompt_to_template() -> void:
	set_prompt_text(template_text())

func _on_prompt_edited() -> void:
	if _loading:
		return
	_refresh_prompt_note()

func _on_version_picked(index: int) -> void:
	var number := int(version_picker.get_item_metadata(index))
	if number <= 0:
		return
	for version in Registry.prompt_versions(creature_id, state):
		if int(version.get("version", 0)) == number:
			_loading = true
			prompt_edit.text = str(version.get("text", ""))
			_loading = false
	_refresh_prompt_note()

# ---------- generation ----------

## Submits the prompt to ComfyUI as a new take, waits for the render and
## downloads every frame. Returns {"ok", "error", "take_id"}.
func generate() -> Dictionary:
	if busy:
		return {"ok": false, "error": "Busy.", "take_id": ""}
	if not has_reference():
		return _gen_fail("Prepare the reference first (section 2).")
	if prompt_text().is_empty():
		return _gen_fail("Write a prompt first.")
	var saved_prompt := save_prompt()
	if not saved_prompt.ok:
		return _gen_fail(str(saved_prompt.error))
	if not rest_check.button_pressed and _checked_url != comfy.set_url(comfy_url.text):
		# Whether H3 may end freely depends on the installed node.
		await check_comfy()
	busy = true
	_update_buttons()
	comfy.set_url(comfy_url.text)
	var take_id := Registry.new_take_id(state)
	var size := int(record.get("reference", {}).get("canvas", [AnimationScript.DEFAULT_SIZE])[0])
	var take := {
		"format_version": Registry.FORMAT_VERSION,
		"take_id": take_id,
		"creature": creature_id,
		"state": state,
		"status": "uploading",
		"prompt_version": int(saved_prompt.version),
		"prompt": prompt_text(),
		"seed": int(seed_spin.value),
		"seconds": seconds_spin.value,
		"steps": int(steps_spin.value),
		"size": size,
		"frames_requested": AnimationScript.frame_count(seconds_spin.value),
		"source_fps": AnimationScript.SOURCE_FPS,
		"end_on_reference": rest_check.button_pressed,
		"models": {"unet": AnimationScript.UNET, "clip": AnimationScript.CLIP, "video_vae": AnimationScript.VIDEO_VAE, "audio_vae": AnimationScript.AUDIO_VAE, "sampler": AnimationScript.SAMPLER, "scheduler": AnimationScript.SCHEDULER},
		"reference": {"path": Registry.REFERENCES_RELATIVE.path_join(creature_id).path_join("reference.png"), "sha256": FileAccess.get_sha256(reference_path()), "ground_anchor": record["reference"]["ground_anchor"]},
		"comfy": {"server": comfy.base_url},
		"created_at": Time.get_datetime_string_from_system(),
	}
	Registry.save_take(creature_id, take)
	reload_takes(take_id)
	var reference_hash := str(take["reference"]["sha256"])
	var uploaded: Dictionary = await comfy.upload(reference_path(), "telos-creature-%s-%s.png" % [creature_id, reference_hash.left(12)])
	if not uploaded.ok:
		return _take_failed(take, str(uploaded.error))
	var last := str(uploaded.name) if rest_check.button_pressed or not comfy.last_frame_optional else ""
	take["end_on_reference"] = not last.is_empty()
	var prefix := "Telos/Creatures/%s/%s" % [creature_id, take_id]
	var graph := AnimationScript.graph(prompt_text(), str(uploaded.name), last, size, seconds_spin.value, int(seed_spin.value), prefix, int(steps_spin.value))
	take["graph"] = graph
	take["comfy"]["upload_name"] = str(uploaded.name)
	take["comfy"]["output_prefix"] = prefix
	take["status"] = "queued"
	Registry.save_take(creature_id, take)
	# The graph on its own too, to load or queue in ComfyUI directly.
	var take_files := Registry.take_files_dir(creature_id, take_id)
	DirAccess.make_dir_recursive_absolute(take_files)
	var api_file := FileAccess.open(take_files.path_join("api.json"), FileAccess.WRITE)
	if api_file != null:
		api_file.store_string(JSON.stringify(graph, "\t") + "\n")
		api_file.close()
	var on_queued := func(prompt_id: String) -> void:
		take["comfy"]["prompt_id"] = prompt_id
		take["status"] = "rendering"
		Registry.save_take(creature_id, take)
	var done: Dictionary = await comfy.run_graph(graph, "creature:%s:%s" % [creature_id, take_id], "H3 %s render" % state, on_queued)
	if not done.ok:
		if done.get("cancelled", false):
			take["status"] = "rendering"
			Registry.save_take(creature_id, take)
			busy = false
			_update_buttons()
			reload_takes(take_id)
			return {"ok": false, "error": str(done.error), "take_id": take_id}
		return _take_failed(take, str(done.error))
	return await _collect(take, done.history)

## For a take whose render was left running: waits for it and downloads.
func collect_take(take_id: String) -> Dictionary:
	if busy:
		return {"ok": false, "error": "Busy.", "take_id": take_id}
	var take := Registry.load_take(creature_id, take_id)
	var prompt_id := str(take.get("comfy", {}).get("prompt_id", ""))
	if prompt_id.is_empty():
		return _gen_fail("This take never reached ComfyUI; generate again.")
	busy = true
	_update_buttons()
	comfy.set_url(str(take.get("comfy", {}).get("server", comfy_url.text)))
	var done: Dictionary = await comfy.wait_for(prompt_id, "H3 %s render" % str(take.get("state", "")))
	if not done.ok:
		busy = false
		_update_buttons()
		if not done.get("cancelled", false):
			return _take_failed(take, str(done.error))
		return {"ok": false, "error": str(done.error), "take_id": take_id}
	return await _collect(take, done.history)

func _collect(take: Dictionary, history: Dictionary) -> Dictionary:
	var take_id := str(take["take_id"])
	var images: Array = ClientScript.output_images(history, AnimationScript.FRAMES_NODE)
	if images.is_empty():
		return _take_failed(take, "ComfyUI finished but saved no frames (node %s)." % AnimationScript.FRAMES_NODE)
	var folder := Registry.take_files_dir(creature_id, take_id).path_join("masters")
	DirAccess.make_dir_recursive_absolute(folder)
	take["status"] = "downloading"
	take["comfy"]["outputs"] = history.get("outputs", {})
	Registry.save_take(creature_id, take)
	var rows: Array = []
	for index in range(images.size()):
		_set_gen_status("Downloading frame %d of %d..." % [index + 1, images.size()])
		var fetched: Dictionary = await comfy.download(images[index])
		if not fetched.ok:
			return _take_failed(take, str(fetched.error))
		var path := folder.path_join("frame_%04d.png" % index)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return _take_failed(take, "Couldn't write %s." % path)
		file.store_buffer(fetched.bytes)
		file.close()
		rows.append({"file": "frame_%04d.png" % index, "sha256": FileAccess.get_sha256(path)})
	take["masters"] = {"dir": Registry.TAKES_RELATIVE.path_join(creature_id).path_join(take_id).path_join("masters"), "fps": AnimationScript.SOURCE_FPS, "frames": rows}
	take["status"] = "complete"
	take["completed_at"] = Time.get_datetime_string_from_system()
	Registry.save_take(creature_id, take)
	busy = false
	_update_buttons()
	reload_takes(take_id)
	_set_gen_status("Take %s: %d frames. Review it on the right, then install it." % [take_id, rows.size()], GOOD)
	return {"ok": true, "error": "", "take_id": take_id}

func stop_waiting() -> void:
	comfy.cancel()

func _take_failed(take: Dictionary, message: String) -> Dictionary:
	take["status"] = "failed"
	take["error"] = message
	Registry.save_take(creature_id, take)
	busy = false
	_update_buttons()
	reload_takes(str(take.get("take_id", "")))
	return _gen_fail(message, str(take.get("take_id", "")))

func _gen_fail(message: String, take_id: String = "") -> Dictionary:
	_set_gen_status(message, BAD)
	return {"ok": false, "error": message, "take_id": take_id}

# ---------- takes ----------

func reload_takes(select: String = "") -> void:
	takes = Registry.list_takes(creature_id, state) if not creature_id.is_empty() else []
	take_list.clear()
	var installed_take := str(record.get("states", {}).get(state, {}).get("take", ""))
	for take in takes:
		var take_id := str(take.get("take_id", ""))
		var line := "v%d · seed %d · %.1fs · %s%s" % [int(take.get("prompt_version", 0)), int(take.get("seed", 0)), float(take.get("seconds", 0.0)), str(take.get("status", "?")), "  ★ in game" if take_id == installed_take else ""]
		var row := take_list.add_item(line)
		take_list.set_item_metadata(row, take_id)
		take_list.set_item_tooltip(row, "%s\n%s" % [take_id, str(take.get("prompt", "")).left(400)])
		if str(take.get("status", "")) == "failed":
			take_list.set_item_custom_fg_color(row, BAD)
	var target := select if not select.is_empty() else (installed_take if not installed_take.is_empty() else (str(takes[0].get("take_id", "")) if not takes.is_empty() else ""))
	select_take(target)

func select_take(take_id: String) -> void:
	selected_take = take_id
	for row in range(take_list.item_count):
		if str(take_list.get_item_metadata(row)) == take_id:
			take_list.select(row)
	var take := current_take()
	_preview_frames.clear()
	take_preview.texture = null
	if take.is_empty():
		take_info.text = "No takes for %s yet. Generate one." % state
	else:
		var frames: Array = take.get("masters", {}).get("frames", [])
		end_spin.max_value = maxf(1, frames.size())
		start_spin.max_value = maxf(0, frames.size() - 1)
		end_spin.value = frames.size()
		start_spin.value = 0
		var installs: Array = take.get("installs", [])
		if not installs.is_empty():
			var last_install: Dictionary = installs[-1]
			fps_spin.value = float(last_install.get("fps", 12.0))
			start_spin.value = float(last_install.get("start", 0))
			end_spin.value = float(last_install.get("end", frames.size()))
		take_info.text = "%s\nPrompt v%d · seed %d · %.1f s · %d steps · %s\n%s%s" % [
			take_id, int(take.get("prompt_version", 0)), int(take.get("seed", 0)), float(take.get("seconds", 0.0)), int(take.get("steps", 0)),
			"%d frames" % frames.size() if not frames.is_empty() else str(take.get("status", "")),
			("ComfyUI prompt %s\n" % take.get("comfy", {}).get("prompt_id", "")) if not str(take.get("comfy", {}).get("prompt_id", "")).is_empty() else "",
			("Error: %s" % take.get("error", "")) if str(take.get("status", "")) == "failed" else "",
		]
		_load_preview(take)
	_update_buttons()

func current_take() -> Dictionary:
	for take in takes:
		if str(take.get("take_id", "")) == selected_take:
			return take
	return {}

func _load_preview(take: Dictionary) -> void:
	var frames: Array = take.get("masters", {}).get("frames", [])
	if frames.is_empty():
		return
	var folder := Registry.take_files_dir(creature_id, str(take["take_id"])).path_join("masters")
	var picks := Art.sample_indices(frames.size(), AnimationScript.SOURCE_FPS, 12.0)
	for index in picks:
		var image := Image.load_from_file(folder.path_join(str(frames[index]["file"])))
		if image != null and not image.is_empty():
			image.resize(maxi(1, image.get_width() / 2), maxi(1, image.get_height() / 2), Image.INTERPOLATE_BILINEAR)
			_preview_frames.append(ImageTexture.create_from_image(image))
	_preview_fps = 12.0
	_preview_time = 0.0

## Loads a take's prompt and settings into the editors, to tweak or re-run it.
func use_take_settings(take_id: String = "") -> void:
	var take := current_take() if take_id.is_empty() else Registry.load_take(creature_id, take_id)
	if take.is_empty():
		return
	_loading = true
	prompt_edit.text = str(take.get("prompt", ""))
	seed_spin.value = float(take.get("seed", AnimationScript.DEFAULT_SEED))
	seconds_spin.value = float(take.get("seconds", AnimationScript.DEFAULT_SECONDS))
	steps_spin.value = float(take.get("steps", AnimationScript.DEFAULT_STEPS))
	rest_check.button_pressed = bool(take.get("end_on_reference", true))
	_loading = false
	_refresh_prompt_note()
	_set_status("Loaded the settings of %s. Generate to recreate it." % str(take.get("take_id", "")))

# ---------- install ----------

## Cuts out the take's frames and installs them as the game clip
## <id>_<state>. Returns {"ok", "error"}.
func install_take(take_id: String = "") -> Dictionary:
	if busy:
		return {"ok": false, "error": "Busy."}
	var take := current_take() if take_id.is_empty() else Registry.load_take(creature_id, take_id)
	var frames: Array = take.get("masters", {}).get("frames", [])
	if frames.is_empty():
		return _gen_fail("This take has no frames to install.")
	if not has_reference():
		return _gen_fail("Prepare the reference first.")
	var fps := fps_spin.value
	var start := int(start_spin.value)
	var end := int(end_spin.value)
	var picks := Art.sample_indices(frames.size(), float(take.get("source_fps", AnimationScript.SOURCE_FPS)), fps, start, end)
	if picks.is_empty():
		return _gen_fail("Pick a valid frame range (start before end, fps up to 24).")
	var method := str(frame_cutout_picker.get_item_metadata(frame_cutout_picker.selected))
	var tolerance := frame_tolerance_spin.value
	var take_dir := Registry.take_files_dir(creature_id, str(take["take_id"]))
	var cut_dir := take_dir.path_join("cut_%s" % (method if method == "comfy" else "solid_%d" % int(tolerance)))
	DirAccess.make_dir_recursive_absolute(cut_dir)
	busy = true
	_update_buttons()
	comfy.set_url(comfy_url.text)
	var images: Array = []
	for n in range(picks.size()):
		var index := int(picks[n])
		var cut_path := cut_dir.path_join("frame_%04d.png" % index)
		var image: Image = null
		if FileAccess.file_exists(cut_path):
			image = Image.load_from_file(cut_path)
		if image == null or image.is_empty():
			_set_gen_status("Cutting out frame %d of %d..." % [n + 1, picks.size()])
			await get_tree().process_frame
			var master_path := take_dir.path_join("masters").path_join(str(frames[index]["file"]))
			if method == "comfy":
				var cut: Dictionary = await comfy.cut_out(master_path, "%s-%s-%04d" % [creature_id, take["take_id"], index])
				if not cut.ok:
					busy = false
					_update_buttons()
					return _gen_fail(str(cut.error))
				image = cut.image
			else:
				var master := Image.load_from_file(master_path)
				if master == null or master.is_empty():
					busy = false
					_update_buttons()
					return _gen_fail("Couldn't read %s." % master_path)
				image = Art.frame_cutout(master, tolerance)
			image.save_png(cut_path)
		images.append(image)
	_set_gen_status("Packing %d frames..." % images.size())
	await get_tree().process_frame
	var reference: Dictionary = record["reference"]
	var result := Art.install_clip(creature_id, state, images, ground_anchor(), float(reference.get("body_height", 1.0)), height_spin.value, fps, {
		"take_id": str(take["take_id"]),
		"prompt_version": int(take.get("prompt_version", 0)),
		"seed": int(take.get("seed", 0)),
		"source_indices": picks,
		"source_fps": float(take.get("source_fps", AnimationScript.SOURCE_FPS)),
		"frame_cutout": method,
	})
	busy = false
	if not result.ok:
		_update_buttons()
		return _gen_fail(str(result.error))
	var states: Dictionary = record.get("states", {})
	states[state] = {"take": str(take["take_id"]), "prompt_version": int(take.get("prompt_version", 0)), "fps": fps, "frames": images.size(), "installed_at": Time.get_datetime_string_from_system()}
	record["states"] = states
	save_record()
	var installs: Array = take.get("installs", [])
	installs.append({"at": Time.get_datetime_string_from_system(), "fps": fps, "start": start, "end": end, "frame_cutout": method, "tolerance": tolerance, "folder": result.folder})
	take["installs"] = installs
	Registry.save_take(creature_id, take)
	reload_takes(str(take["take_id"]))
	_refresh_state_buttons()
	_refresh_encyclopedia()
	_set_gen_status("Installed %d frames as %s_%s. %s" % [images.size(), creature_id, state, "The encyclopedia shows it now." if bool(record.get("in_encyclopedia", false)) else "Add the creature to the encyclopedia in section 4."], GOOD)
	return {"ok": true, "error": ""}

func _installed_frames() -> SpriteFrames:
	if not has_reference():
		return null
	var asset := ConfigScript.asset_for(creature_id)
	if asset.is_empty():
		return null
	return ConfigScript.frames_for(asset, state)

# ---------- encyclopedia ----------

## Lists the creature in the Monster Encyclopedia (stats start from its
## behavior's monster). Returns {"ok", "error"}.
func add_to_encyclopedia() -> Dictionary:
	if not has_reference():
		return _encyclopedia_fail("Prepare the reference first; the encyclopedia needs the creature's picture.")
	record["in_encyclopedia"] = true
	var result := save_record()
	if not result.ok:
		return _encyclopedia_fail(str(result.error))
	MonsterStatsScript._ensure_row(creature_id)
	_refresh_encyclopedia()
	_set_status("%s is in the encyclopedia. Tune its stats there and Save to game data." % str(record.get("name", creature_id)))
	return {"ok": true, "error": ""}

func remove_from_encyclopedia() -> Dictionary:
	record["in_encyclopedia"] = false
	var result := save_record()
	_refresh_encyclopedia()
	return result

func open_encyclopedia() -> void:
	if encyclopedia == null:
		encyclopedia = EncyclopediaScript.new()
		encyclopedia.name = "MonsterEncyclopedia"
		add_child(encyclopedia)
	encyclopedia.open()
	if bool(record.get("in_encyclopedia", false)):
		encyclopedia.select_monster(creature_id)

func _encyclopedia_fail(message: String) -> Dictionary:
	encyclopedia_status.text = message
	encyclopedia_status.add_theme_color_override("font_color", BAD)
	return {"ok": false, "error": message}

# ---------- server ----------

func check_comfy() -> Dictionary:
	comfy.set_url(comfy_url.text)
	comfy_url.text = comfy.base_url
	comfy_status.text = "Checking..."
	comfy_status.add_theme_color_override("font_color", MUTED)
	var result: Dictionary = await comfy.check_server()
	_checked_url = comfy.base_url if result.ok else ""
	if result.ok:
		comfy_status.text = "Ready: H3%s%s" % [" + Trellis 2" if result.trellis else " (no Trellis 2: use local cutouts)", "" if result.last_frame_optional else ", end frame required"]
		comfy_status.add_theme_color_override("font_color", GOOD)
	else:
		comfy_status.text = str(result.error)
		comfy_status.add_theme_color_override("font_color", BAD)
	return result

# ---------- refresh ----------

func _apply_record_to_controls() -> void:
	_loading = true
	page_title.text = str(record.get("name", creature_id))
	name_edit.text = str(record.get("name", ""))
	id_label.text = creature_id
	for index in range(archetype_picker.item_count):
		if str(archetype_picker.get_item_metadata(index)) == str(record.get("archetype", "pursuer")):
			archetype_picker.select(index)
	facing_picker.select(1 if str(record.get("facing", "left")) == "right" else 0)
	height_spin.value = float(record.get("display_height", 58.0))
	desc_edit.text = str(record.get("desc", ""))
	concept_preview.texture = _thumb(concept_path, 360)
	_loading = false
	_refresh_meta()
	_refresh_reference()
	_refresh_encyclopedia()
	_set_reference_status("Reference ready. Click the picture to move the feet line." if has_reference() else "No reference yet: choose a cutout and press Prepare reference.", MUTED)

func _refresh_meta() -> void:
	page_title.text = str(record.get("name", creature_id))
	page_meta.text = "%s  ·  family %s  ·  %s  ·  %s" % [concept_path, str(record.get("family", "")), Registry.stage_label(int(record.get("stage", -1))), "saved in data/creatures" if is_saved() else "not saved yet"]

func _refresh_reference() -> void:
	reference_preview.texture = Registry.load_texture(reference_path()) if has_reference() else null
	anchor_overlay.queue_redraw()

func _refresh_versions() -> void:
	version_picker.clear()
	var versions := Registry.prompt_versions(creature_id, state) if is_saved() else []
	var current := int(Registry.current_prompt(creature_id, state).get("version", 0)) if is_saved() else 0
	if versions.is_empty():
		version_picker.add_item("No saved versions")
		version_picker.set_item_metadata(0, 0)
		version_picker.disabled = true
	else:
		version_picker.disabled = false
		for index in range(versions.size() - 1, -1, -1):
			var version: Dictionary = versions[index]
			var number := int(version.get("version", 0))
			version_picker.add_item("v%d%s  %s" % [number, " (current)" if number == current else "", str(version.get("created_at", "")).replace("T", " ")])
			version_picker.set_item_metadata(version_picker.item_count - 1, number)
			if number == current:
				version_picker.select(version_picker.item_count - 1)
	_refresh_prompt_note()

func _refresh_prompt_note() -> void:
	var current := Registry.current_prompt(creature_id, state) if is_saved() else {}
	var text := prompt_text()
	if text == template_text().strip_edges() and current.is_empty():
		prompt_note.text = "Starting template for %s. Edit it freely; it's saved as v1 when you generate." % state
	elif not current.is_empty() and text == str(current.get("text", "")):
		prompt_note.text = "v%d, the current prompt for %s." % [int(current.get("version", 0)), state]
	else:
		var same := 0
		for version in Registry.prompt_versions(creature_id, state) if is_saved() else []:
			if str(version.get("text", "")) == text:
				same = int(version.get("version", 0))
		prompt_note.text = "Same as v%d (generating makes it current)." % same if same > 0 else "Edited: saved as a new version when you generate (or press Save)."

func _refresh_state_buttons() -> void:
	for key in state_buttons:
		var installed := Art.has_clip(creature_id, key) if not creature_id.is_empty() else false
		var count := Registry.list_takes(creature_id, key).size() if is_saved() else 0
		state_buttons[key].text = "%s%s%s" % ["✓ " if installed else "", key.capitalize(), "  (%d)" % count if count > 0 else ""]
		state_buttons[key].tooltip_text = "%s%s" % [STATE_TIPS.get(key, ""), "\nInstalled in the game." if installed else ""]

func _refresh_encyclopedia() -> void:
	if encyclopedia_status == null:
		return
	var listed := bool(record.get("in_encyclopedia", false)) and is_saved()
	var clips: Array = []
	for key in Registry.STATES:
		if Art.has_clip(creature_id, key):
			clips.append(key)
	encyclopedia_status.add_theme_color_override("font_color", GOOD if listed else MUTED)
	if listed:
		encyclopedia_status.text = "In the encyclopedia as \"%s\" (%s). Clips: %s." % [MonsterStatsScript.monster(creature_id).get("name", creature_id), Registry.ARCHETYPES[record.get("archetype", "pursuer")]["label"], ", ".join(clips) if not clips.is_empty() else "none yet (shows the still picture)"]
	else:
		encyclopedia_status.text = "Not in the encyclopedia yet.%s" % ("" if has_reference() else " Prepare the reference first.")
	add_button.text = "Update encyclopedia entry" if listed else "Add to encyclopedia"
	remove_button.visible = listed
	_update_buttons()

func _update_buttons() -> void:
	if prepare_button == null:
		return
	var take := current_take()
	var has_frames: bool = not take.get("masters", {}).get("frames", []).is_empty()
	prepare_button.disabled = busy or creature_id.is_empty()
	generate_button.disabled = busy or not has_reference()
	stop_button.disabled = not busy
	install_button.disabled = busy or not has_frames
	install_button.text = "Install as %s" % state
	use_take_button.disabled = take.is_empty()
	collect_button.visible = not take.is_empty() and not has_frames and ["rendering", "queued", "downloading"].has(str(take.get("status", "")))
	collect_button.disabled = busy
	add_button.disabled = busy or not has_reference()

func _set_status(text: String, color: Color = MUTED) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)

func _set_gen_status(text: String, color: Color = MUTED) -> void:
	if gen_status != null:
		gen_status.text = text
		gen_status.add_theme_color_override("font_color", color)

func _set_reference_status(text: String, color: Color = MUTED) -> void:
	if reference_status != null:
		reference_status.text = text
		reference_status.add_theme_color_override("font_color", color)

func _show_page(on: bool) -> void:
	page.visible = on
	empty_page.visible = not on

# ---------- tiles ----------

func _render_tiles() -> void:
	for child in tile_list.get_children():
		tile_list.remove_child(child)
		child.queue_free()
	tiles.clear()
	if families.is_empty():
		var empty := Label.new()
		empty.text = "No concept art yet. Put images in %s/<family>/ (name them <creature>_stage_<n>.png) and press Rescan." % Registry.CONCEPTS_RELATIVE
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", MUTED)
		tile_list.add_child(empty)
		return
	for family in families:
		var heading := Label.new()
		heading.text = str(family["family"]).to_upper()
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", AMBER)
		tile_list.add_child(heading)
		for file in family["files"]:
			var tile := _build_tile(file)
			tiles[str(file["path"])] = tile
			tile_list.add_child(tile)
	_sync_tiles()

func _build_tile(file: Dictionary) -> Button:
	var tile := Button.new()
	tile.name = "Tile_" + str(file["id"])
	tile.toggle_mode = true
	tile.button_group = tile_group
	tile.custom_minimum_size = Vector2(0, 64)
	tile.tooltip_text = str(file["path"])
	tile.pressed.connect(select_concept.bind(str(file["path"])))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _thumb(str(file["path"]), 96)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.name = "Title"
	title.text = str(file["name"])
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", MUTED)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(sub)
	return tile

func _sync_tiles() -> void:
	for path in tiles:
		var tile: Button = tiles[path]
		var entry := concept_entry(path)
		var id := str(entry.get("id", ""))
		var saved := Registry.get_creature(id)
		var clips := 0
		for key in Registry.STATES:
			if Art.has_clip(id, key):
				clips += 1
		var parts: Array = [Registry.stage_label(int(entry.get("stage", -1)))]
		if bool(saved.get("in_encyclopedia", false)):
			parts.append("in encyclopedia")
		elif not saved.is_empty():
			parts.append("in progress")
		if clips > 0:
			parts.append("%d clip%s" % [clips, "" if clips == 1 else "s"])
		tile.find_child("Sub", true, false).text = " · ".join(parts)
		if not saved.is_empty():
			tile.find_child("Title", true, false).text = str(saved.get("name", entry.get("name", id)))
		tile.set_pressed_no_signal(path == concept_path)

func _thumb(path: String, size: int) -> Texture2D:
	var key := "%s@%d" % [path, size]
	if _thumbs.has(key):
		return _thumbs[key]
	var image := Image.load_from_file(Registry.repo_root().path_join(path))
	if image == null or image.is_empty():
		return null
	var factor := float(size) / maxf(image.get_width(), image.get_height())
	if factor < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_BILINEAR)
	var texture := ImageTexture.create_from_image(image)
	_thumbs[key] = texture
	return texture

# ---------- build ----------

func _build() -> void:
	ui = CanvasLayer.new()
	ui.name = "LabUI"
	add_child(ui)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	ui.add_child(root)
	var background := ColorRect.new()
	background.color = Color("15181b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var book := PanelContainer.new()
	book.name = "Book"
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.offset_left = 16
	book.offset_top = 16
	book.offset_right = -16
	book.offset_bottom = -16
	book.add_theme_stylebox_override("panel", _box(PLATE, EDGE, 1, 6, 0))
	root.add_child(book)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	book.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	body.add_child(_build_index())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	empty_page = Label.new()
	empty_page.text = "Pick a concept on the left."
	empty_page.add_theme_color_override("font_color", MUTED)
	stack.add_child(empty_page)
	page = _build_page()
	stack.add_child(page)
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 10, [0, 1, 0, 0]))
	status_label = Label.new()
	status_label.name = "Status"
	status_label.text = "Generated takes, prompts and settings are saved in data/creatures/ so every clip can be recreated."
	status_label.add_theme_color_override("font_color", MUTED)
	footer.add_child(status_label)
	column.add_child(footer)

func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 12, [0, 0, 0, 1]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var title := Label.new()
	title.text = "CREATURE LAB"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", AMBER)
	row.add_child(title)
	var tag := Label.new()
	tag.text = "DEV TOOL · MiniMax H3"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var label := Label.new()
	label.text = "ComfyUI"
	label.add_theme_color_override("font_color", MUTED)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	comfy_url = LineEdit.new()
	comfy_url.name = "ComfyUrl"
	comfy_url.custom_minimum_size = Vector2(220, 0)
	comfy_url.tooltip_text = "The ComfyUI server that renders H3 animations (start it with --listen to reach it over the network)."
	comfy_url.text_submitted.connect(func(_text: String) -> void: check_comfy())
	row.add_child(comfy_url)
	var check := _button("Check")
	check.name = "CheckComfy"
	check.pressed.connect(func() -> void: check_comfy())
	row.add_child(check)
	comfy_status = Label.new()
	comfy_status.name = "ComfyStatus"
	comfy_status.custom_minimum_size = Vector2(200, 0)
	comfy_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comfy_status.add_theme_font_size_override("font_size", 12)
	comfy_status.add_theme_color_override("font_color", MUTED)
	comfy_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	comfy_status.text = "Press Check to test the server."
	row.add_child(comfy_status)
	var book := _button("Encyclopedia", true)
	book.name = "OpenEncyclopedia"
	book.pressed.connect(open_encyclopedia)
	row.add_child(book)
	var back := _button("Back to title  (Esc)")
	back.name = "Back"
	back.pressed.connect(return_to_title)
	row.add_child(back)
	return bar

func _build_index() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 0, 0, 12, [0, 0, 1, 0]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var heading := Label.new()
	heading.text = "Concept art"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var rescan := _button("Rescan", true)
	rescan.name = "Rescan"
	rescan.tooltip_text = "Look for new images in %s." % Registry.CONCEPTS_RELATIVE
	rescan.pressed.connect(func() -> void:
		reload_concepts()
		_set_status("Found %d concept images." % tiles.size()))
	row.add_child(rescan)
	var open := _button("Folder", true)
	open.tooltip_text = "Open %s in your file browser." % Registry.CONCEPTS_RELATIVE
	open.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(Registry.concepts_dir())
		OS.shell_open(Registry.concepts_dir()))
	row.add_child(open)
	var hint := Label.new()
	hint.text = "%s/<family>/<name>_stage_<n>.png" % Registry.CONCEPTS_RELATIVE
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	tile_list = VBoxContainer.new()
	tile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_list.add_theme_constant_override("separation", 4)
	scroll.add_child(tile_list)
	return panel

func _build_page() -> Control:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	page_title = Label.new()
	page_title.add_theme_font_size_override("font_size", 24)
	column.add_child(page_title)
	page_meta = Label.new()
	page_meta.clip_text = true
	page_meta.add_theme_font_size_override("font_size", 12)
	page_meta.add_theme_color_override("font_color", MUTED)
	column.add_child(page_meta)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	top.add_child(_build_creature_section())
	top.add_child(_build_reference_section())
	top.add_child(_build_encyclopedia_section())
	column.add_child(_build_animation_section())
	return margin

func _build_creature_section() -> Control:
	var section := _section("1  CREATURE")
	var body: VBoxContainer = section.get_meta("body")
	concept_preview = TextureRect.new()
	concept_preview.custom_minimum_size = Vector2(0, 120)
	concept_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	concept_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(concept_preview)
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.text_submitted.connect(func(_text: String) -> void: _on_field_changed())
	name_edit.focus_exited.connect(_on_field_changed)
	body.add_child(_field("Name", name_edit))
	id_label = Label.new()
	id_label.add_theme_color_override("font_color", MUTED)
	body.add_child(_field("Id", id_label))
	archetype_picker = _picker()
	archetype_picker.name = "Archetype"
	for key in Registry.ARCHETYPE_ORDER:
		archetype_picker.add_item(str(Registry.ARCHETYPES[key]["label"]))
		archetype_picker.set_item_metadata(archetype_picker.item_count - 1, key)
	archetype_picker.tooltip_text = "Which built-in monster's behavior and starting stats it uses."
	archetype_picker.item_selected.connect(func(_index: int) -> void: _on_field_changed())
	body.add_child(_field("Behaves as", archetype_picker))
	facing_picker = _picker()
	facing_picker.name = "Facing"
	facing_picker.add_item("Left (mirrored)")
	facing_picker.add_item("Right")
	facing_picker.tooltip_text = "Which way the creature faces in the concept. Game art faces right, so left-facing art is mirrored when the reference is prepared."
	facing_picker.item_selected.connect(func(_index: int) -> void: _on_field_changed())
	body.add_child(_field("Concept faces", facing_picker))
	height_spin = _spin(20, 400, 1)
	height_spin.name = "DisplayHeight"
	height_spin.tooltip_text = "How tall it stands in the game, in pixels at 1280x720 (pursuer 58, ranged 90, breaker 112). Monsters are then drawn 1.2x."
	height_spin.value_changed.connect(func(_value: float) -> void: _on_field_changed())
	body.add_child(_field("Height", height_spin))
	desc_edit = TextEdit.new()
	desc_edit.name = "Description"
	desc_edit.custom_minimum_size = Vector2(0, 52)
	desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	desc_edit.placeholder_text = "Encyclopedia description"
	desc_edit.focus_exited.connect(_on_field_changed)
	body.add_child(desc_edit)
	return section

func _build_reference_section() -> Control:
	var section := _section("2  REFERENCE")
	var body: VBoxContainer = section.get_meta("body")
	cutout_picker = _picker()
	cutout_picker.name = "CutoutMethod"
	cutout_picker.tooltip_text = "Auto: the PNG's own transparency if it has some, else the flat background. Flat background works offline on plain backdrops (a thin frame line is fine). Trellis 2 runs on ComfyUI for busy backgrounds."
	for pair in CUTOUTS:
		cutout_picker.add_item(str(pair[1]))
		cutout_picker.set_item_metadata(cutout_picker.item_count - 1, pair[0])
	body.add_child(_field("Cutout", cutout_picker))
	var row := HBoxContainer.new()
	body.add_child(row)
	tolerance_spin = _spin(4, 120, 1)
	tolerance_spin.value = 38
	tolerance_spin.tooltip_text = "Flat background: raise it if a halo of backdrop is left, lower it if the creature gets holes."
	row.add_child(_field("Tolerance", tolerance_spin))
	prepare_button = _button("Prepare reference")
	prepare_button.name = "PrepareReference"
	_amber(prepare_button)
	prepare_button.pressed.connect(func() -> void: prepare_reference())
	row.add_child(prepare_button)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("2b3238"), EDGE, 1, 3, 4))
	body.add_child(frame)
	reference_preview = TextureRect.new()
	reference_preview.name = "ReferencePreview"
	reference_preview.custom_minimum_size = Vector2(220, 220)
	reference_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	reference_preview.tooltip_text = "The 576 px H3 canvas. Click to put the feet line (green) where the creature stands."
	reference_preview.gui_input.connect(_on_reference_input)
	frame.add_child(reference_preview)
	anchor_overlay = Control.new()
	anchor_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_overlay.draw.connect(_draw_anchor)
	reference_preview.add_child(anchor_overlay)
	reference_status = Label.new()
	reference_status.custom_minimum_size = Vector2(200, 0)
	reference_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reference_status.add_theme_font_size_override("font_size", 12)
	body.add_child(reference_status)
	return section

func _build_encyclopedia_section() -> Control:
	var section := _section("4  ENCYCLOPEDIA")
	section.custom_minimum_size = Vector2(220, 0)
	section.size_flags_horizontal = Control.SIZE_FILL
	var body: VBoxContainer = section.get_meta("body")
	encyclopedia_status = Label.new()
	encyclopedia_status.name = "EncyclopediaStatus"
	encyclopedia_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encyclopedia_status.custom_minimum_size = Vector2(200, 0)
	body.add_child(encyclopedia_status)
	add_button = _button("Add to encyclopedia")
	add_button.name = "AddToEncyclopedia"
	_amber(add_button)
	add_button.pressed.connect(func() -> void: add_to_encyclopedia())
	body.add_child(add_button)
	var open := _button("Open in encyclopedia", true)
	open.pressed.connect(open_encyclopedia)
	body.add_child(open)
	remove_button = _button("Remove from encyclopedia", true)
	remove_button.pressed.connect(func() -> void: remove_from_encyclopedia())
	body.add_child(remove_button)
	var note := Label.new()
	note.text = "Stats start from its behavior's monster. Tune them in the encyclopedia and press Save to game data there."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(200, 0)
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", MUTED)
	body.add_child(note)
	return section

func _build_animation_section() -> Control:
	var section := _section("3  ANIMATIONS")
	var body: VBoxContainer = section.get_meta("body")
	var states := HBoxContainer.new()
	states.add_theme_constant_override("separation", 6)
	body.add_child(states)
	var group := ButtonGroup.new()
	for key in Registry.STATES:
		var button := _button(key.capitalize(), true)
		button.name = "State_" + key
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(select_state.bind(key))
		state_buttons[key] = button
		states.add_child(button)
	state_tip = Label.new()
	state_tip.add_theme_font_size_override("font_size", 12)
	state_tip.add_theme_color_override("font_color", MUTED)
	body.add_child(state_tip)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	body.add_child(split)
	# Left: the prompt and render settings.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var prompt_row := HBoxContainer.new()
	left.add_child(prompt_row)
	var prompt_label := Label.new()
	prompt_label.text = "Prompt"
	prompt_row.add_child(prompt_label)
	version_picker = _picker()
	version_picker.name = "PromptVersions"
	version_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_picker.tooltip_text = "Every version of this prompt is kept in data/creatures/<id>/prompts.json. Pick one to load it."
	version_picker.item_selected.connect(_on_version_picked)
	prompt_row.add_child(version_picker)
	var save := _button("Save", true)
	save.name = "SavePrompt"
	save.tooltip_text = "Save the text as this state's current prompt (a new version if it's new)."
	save.pressed.connect(func() -> void: save_prompt())
	prompt_row.add_child(save)
	var reset := _button("Template", true)
	reset.tooltip_text = "Replace the text with the starting template for this state."
	reset.pressed.connect(reset_prompt_to_template)
	prompt_row.add_child(reset)
	prompt_edit = TextEdit.new()
	prompt_edit.name = "PromptEdit"
	prompt_edit.custom_minimum_size = Vector2(0, 190)
	prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_edit.text_changed.connect(_on_prompt_edited)
	left.add_child(prompt_edit)
	prompt_note = Label.new()
	prompt_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_note.add_theme_font_size_override("font_size", 12)
	prompt_note.add_theme_color_override("font_color", MUTED)
	left.add_child(prompt_note)
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 10)
	left.add_child(settings)
	seed_spin = _spin(0, AnimationScript.MAX_SEED, 1)
	seed_spin.name = "Seed"
	seed_spin.custom_minimum_size = Vector2(170, 0)
	seed_spin.tooltip_text = "Same prompt + seed + length + reference = the same take."
	settings.add_child(_field("Seed", seed_spin))
	var dice := _button("New seed", true)
	dice.pressed.connect(func() -> void: seed_spin.value = AnimationScript.random_seed())
	settings.add_child(dice)
	seconds_spin = _spin(0.5, 15.0, 0.25)
	seconds_spin.name = "Seconds"
	seconds_spin.tooltip_text = "Clip length. H3 renders 17k+5 frames at 24 fps (3 s = 73 frames)."
	settings.add_child(_field("Seconds", seconds_spin))
	steps_spin = _spin(4, 60, 1)
	steps_spin.name = "Steps"
	settings.add_child(_field("Steps", steps_spin))
	rest_check = CheckBox.new()
	rest_check.name = "EndOnReference"
	rest_check.text = "End on the reference pose"
	rest_check.tooltip_text = "Gives H3 the reference as the last frame too, so the clip returns to rest (loops, attacks, hurt). Untick for death, wind-up and spawn, which end somewhere else (needs an H3 node that allows an empty last frame)."
	left.add_child(rest_check)
	var actions := HBoxContainer.new()
	left.add_child(actions)
	generate_button = _button("Generate take")
	generate_button.name = "Generate"
	_amber(generate_button)
	generate_button.pressed.connect(func() -> void: generate())
	actions.add_child(generate_button)
	stop_button = _button("Stop waiting", true)
	stop_button.tooltip_text = "Stop waiting for ComfyUI. The render keeps going there; select the take later and press Collect frames."
	stop_button.pressed.connect(stop_waiting)
	actions.add_child(stop_button)
	gen_status = Label.new()
	gen_status.name = "GenStatus"
	gen_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gen_status.add_theme_font_size_override("font_size", 12)
	left.add_child(gen_status)
	# Middle: takes.
	var middle := VBoxContainer.new()
	middle.custom_minimum_size = Vector2(330, 0)
	split.add_child(middle)
	var takes_label := Label.new()
	takes_label.text = "Takes"
	middle.add_child(takes_label)
	take_list = ItemList.new()
	take_list.name = "Takes"
	take_list.custom_minimum_size = Vector2(330, 150)
	take_list.item_selected.connect(func(index: int) -> void: select_take(str(take_list.get_item_metadata(index))))
	middle.add_child(take_list)
	take_info = Label.new()
	take_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	take_info.custom_minimum_size = Vector2(330, 0)
	take_info.add_theme_font_size_override("font_size", 12)
	take_info.add_theme_color_override("font_color", MUTED)
	middle.add_child(take_info)
	var take_actions := HBoxContainer.new()
	middle.add_child(take_actions)
	use_take_button = _button("Use its prompt & seed", true)
	use_take_button.tooltip_text = "Load this take's prompt, seed, length and steps to tweak or recreate it."
	use_take_button.pressed.connect(func() -> void: use_take_settings())
	take_actions.add_child(use_take_button)
	collect_button = _button("Collect frames")
	collect_button.tooltip_text = "Wait for this take's render on ComfyUI and download it."
	collect_button.pressed.connect(func() -> void: collect_take(selected_take))
	take_actions.add_child(collect_button)
	var install_grid := GridContainer.new()
	install_grid.columns = 3
	middle.add_child(install_grid)
	fps_spin = _spin(4, 24, 1)
	fps_spin.value = 12
	fps_spin.tooltip_text = "Playback frames per second (frames are picked from the 24 fps render)."
	install_grid.add_child(_field("FPS", fps_spin, 40))
	start_spin = _spin(0, 400, 1)
	start_spin.tooltip_text = "First render frame to use."
	install_grid.add_child(_field("From", start_spin, 40))
	end_spin = _spin(1, 400, 1)
	end_spin.tooltip_text = "Render frames before this one are used (trim a held or bad ending)."
	install_grid.add_child(_field("To", end_spin, 30))
	frame_cutout_picker = _picker()
	for pair in FRAME_CUTOUTS:
		frame_cutout_picker.add_item(str(pair[1]))
		frame_cutout_picker.set_item_metadata(frame_cutout_picker.item_count - 1, pair[0])
	middle.add_child(_field("Frame cutout", frame_cutout_picker))
	frame_tolerance_spin = _spin(4, 120, 1)
	frame_tolerance_spin.value = 30
	frame_tolerance_spin.tooltip_text = "Grey background tolerance for the frames."
	middle.add_child(_field("Tolerance", frame_tolerance_spin))
	install_button = _button("Install")
	install_button.name = "Install"
	_amber(install_button)
	install_button.pressed.connect(func() -> void: install_take())
	middle.add_child(install_button)
	# Right: previews.
	var right := VBoxContainer.new()
	split.add_child(right)
	take_preview = _preview(right, "Selected take (render, 12 fps)")
	installed_preview = _preview(right, "In the game now (cut out)")
	return section

func _preview(parent: Control, caption: String) -> TextureRect:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("2b3238"), EDGE, 1, 3, 4))
	parent.add_child(frame)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(230, 200)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(image)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	return image

# ---------- reference anchor ----------

func _preview_rect() -> Rect2:
	var texture := reference_preview.texture
	if texture == null:
		return Rect2()
	var box := reference_preview.size
	var image := texture.get_size()
	var scale := minf(box.x / image.x, box.y / image.y)
	var drawn := image * scale
	return Rect2((box - drawn) * 0.5, drawn)

func _on_reference_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var rect := _preview_rect()
	if rect.size.x <= 0.0 or not rect.has_point(event.position):
		return
	var texture_size := reference_preview.texture.get_size()
	var point: Vector2 = (event.position - rect.position) / rect.size * texture_size
	set_ground_anchor(Vector2(ground_anchor().x, point.y))

func _draw_anchor() -> void:
	var rect := _preview_rect()
	if rect.size.x <= 0.0 or not has_reference():
		return
	var texture_size := reference_preview.texture.get_size()
	var point := rect.position + ground_anchor() / texture_size * rect.size
	anchor_overlay.draw_line(Vector2(rect.position.x, point.y), Vector2(rect.end.x, point.y), Color(GOOD, 0.85), 1.5)
	anchor_overlay.draw_circle(point, 4.0, GOOD)

# ---------- widgets ----------

func _section(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 1, 4, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", AMBER)
	column.add_child(heading)
	panel.set_meta("body", column)
	return panel

func _field(caption: String, control: Control, label_width: float = 84.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(label_width, 0)
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _picker() -> OptionButton:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.custom_minimum_size = Vector2(120, 0)
	return picker

func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.custom_minimum_size = Vector2(90, 0)
	return spin

func _button(text: String, ghost: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	if ghost:
		button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0), EDGE))
	return button

func _amber(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(AMBER_DEEP, AMBER))
	button.add_theme_stylebox_override("hover", _button_box(AMBER, Color("f7bb58")))
	button.add_theme_color_override("font_color", Color("15181b"))
	button.add_theme_color_override("font_hover_color", Color("15181b"))

func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _box(fill, border, 1, 3, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _theme() -> Theme:
	var theme: Theme = IndustrialThemeScript.create()
	theme.default_font_size = 15
	for type_name in ["Label", "Button", "LineEdit", "OptionButton", "PanelContainer", "CheckBox", "TextEdit", "ItemList"]:
		theme.set_font_size("font_size", type_name, 15)
	var button := _button_box(Color("26313a"), Color("50606b"))
	theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate()
	hover.bg_color = Color("34434d")
	hover.border_color = AMBER
	theme.set_stylebox("hover", "Button", hover)
	var pressed := button.duplicate()
	pressed.bg_color = Color("3a3322")
	pressed.border_color = AMBER
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_color("font_pressed_color", "Button", INK)
	var disabled := button.duplicate()
	disabled.bg_color = Color("1b2026")
	disabled.border_color = Color("323942")
	theme.set_stylebox("disabled", "Button", disabled)
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(style_name, "OptionButton", theme.get_stylebox(style_name, "Button"))
	var field := _box(Color("15181b"), EDGE, 1, 3, 0)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), AMBER, 2, 3, 0))
	theme.set_stylebox("normal", "TextEdit", field)
	theme.set_stylebox("focus", "TextEdit", _box(Color(0, 0, 0, 0), AMBER, 2, 3, 0))
	theme.set_stylebox("panel", "ItemList", field)
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "CheckBox", INK)
	return theme

func _box(fill: Color, border: Color, border_width: int, radius: int, padding: float, borders: Array = []) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	if borders.size() == 4:
		style.border_width_left = int(borders[0]) * maxi(1, border_width)
		style.border_width_top = int(borders[1]) * maxi(1, border_width)
		style.border_width_right = int(borders[2]) * maxi(1, border_width)
		style.border_width_bottom = int(borders[3]) * maxi(1, border_width)
	else:
		style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

# ---------- bigger window while in the lab ----------

func _enlarge_window() -> void:
	var window := get_window()
	if window == null or not resize_window:
		return
	_saved_canvas = window.content_scale_size
	_saved_aspect = window.content_scale_aspect
	_saved_window = window.size
	_saved_window_position = window.position
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = LAB_CANVAS
	if DisplayServer.get_name() == "headless" or window.mode != Window.MODE_WINDOWED:
		return
	if Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor"):
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var target := Vector2i(mini(LAB_WINDOW.x, int(usable.size.x * 0.96)), mini(LAB_WINDOW.y, int(usable.size.y * 0.92)))
	if target.x > window.size.x or target.y > window.size.y:
		window.size = Vector2i(maxi(target.x, window.size.x), maxi(target.y, window.size.y))
		window.position = usable.position + (usable.size - window.size) / 2

func _restore_window() -> void:
	var window := get_window()
	if window == null or not resize_window or _saved_canvas == Vector2i.ZERO:
		return
	window.content_scale_size = _saved_canvas
	window.content_scale_aspect = _saved_aspect
	if DisplayServer.get_name() != "headless" and window.mode == Window.MODE_WINDOWED and window.size != _saved_window:
		window.size = _saved_window
		window.position = _saved_window_position
	_saved_canvas = Vector2i.ZERO

func _exit_tree() -> void:
	_restore_window()
