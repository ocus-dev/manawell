extends SceneTree

## Runs Creature Lab work unattended from a job list, so a batch of creatures
## can be prepared, generated on ComfyUI and installed without clicking
## through the lab. Uses the lab itself (scripts/tools/creature_lab.gd), so
## every prompt, take and install lands in data/creatures/ exactly as if it
## were done by hand.
##
##   Godot_console --headless --path prototype --script res://tools/creature_batch.gd -- jobs=art/creatures/review/jobs.json
##
## jobs.json: {"comfy_url": "...", "jobs": [ ... ]}, run in order. Job types:
##   {"type": "prepare", "concept": "art/creatures/enemies/x/x_stage_0.png",
##    "name", "archetype", "facing", "display_height", "desc", "cutout", "tolerance"}
##   {"type": "generate", "id", "state", "seed", "seconds", "prompt" | "prompt_extra", "rest"}
##   {"type": "install", "id", "state", "take", "fps", "start", "end", "cutout", "tolerance"}
##   {"type": "encyclopedia", "id"}
## Progress: art/creatures/review/status.json (rewritten after every job) and
## a review sheet per reference, take and install in art/creatures/review/.

const LabScene = preload("res://scenes/tools/creature_lab.tscn")
const Registry = preload("res://scripts/model/creature_registry.gd")
const AnimationScript = preload("res://scripts/model/creature_animation.gd")
const Art = preload("res://scripts/tools/creature_lab_art.gd")

const REVIEW_RELATIVE := "art/creatures/review"
const SHEET_CELL := 160
const SHEET_COLUMNS := 10

var lab: Node
var results: Array = []
var review_dir := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var jobs_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("jobs="):
			jobs_path = argument.trim_prefix("jobs=")
	if jobs_path.is_empty():
		push_error("Usage: -- jobs=<path to jobs.json, repo-relative or absolute>")
		quit(2)
		return
	if not jobs_path.is_absolute_path():
		jobs_path = Registry.repo_root().path_join(jobs_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	if not parsed is Dictionary or not parsed.get("jobs") is Array:
		push_error("Couldn't read jobs from %s" % jobs_path)
		quit(2)
		return
	review_dir = Registry.repo_root().path_join(REVIEW_RELATIVE)
	DirAccess.make_dir_recursive_absolute(review_dir)
	lab = LabScene.instantiate()
	lab.resize_window = false
	root.add_child(lab)
	await process_frame
	lab.comfy_url.text = str(parsed.get("comfy_url", "http://192.168.1.102:8188"))
	lab.comfy.poll_interval = 3.0
	var check: Dictionary = await lab.check_comfy()
	_record({"type": "check", "ok": check.ok, "error": check.error, "server": lab.comfy.base_url, "last_frame_optional": check.get("last_frame_optional", false), "trellis": check.get("trellis", false)})
	var jobs: Array = parsed.jobs
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		print("[%d/%d] %s %s %s" % [index + 1, jobs.size(), job.get("type", ""), job.get("id", job.get("concept", "")), job.get("state", "")])
		var started := Time.get_ticks_msec()
		var result: Dictionary = {}
		match str(job.get("type", "")):
			"prepare":
				result = await _prepare(job)
			"generate":
				result = await _generate(job)
			"install":
				result = await _install(job)
			"encyclopedia":
				result = _encyclopedia(job)
			_:
				result = {"ok": false, "error": "unknown job type"}
		result["job"] = job
		result["seconds_taken"] = (Time.get_ticks_msec() - started) / 1000.0
		_record(result)
		print("    -> %s %s" % ["OK" if result.get("ok", false) else "FAILED", result.get("error", result.get("take", ""))])
	_record({"type": "done", "ok": true})
	print("Batch finished: %d jobs." % jobs.size())
	quit(0)

# ---------- jobs ----------

func _select(creature_id: String) -> bool:
	for family in lab.families:
		for file in family.files:
			if str(file.id) == creature_id:
				lab.select_concept(str(file.path))
				return true
	return false

func _prepare(job: Dictionary) -> Dictionary:
	var path := str(job.get("concept", ""))
	if lab.concept_entry(path).is_empty():
		lab.reload_concepts()
	if lab.concept_entry(path).is_empty():
		return {"ok": false, "error": "no concept %s" % path}
	lab.select_concept(path)
	lab._loading = true
	if job.has("name"):
		lab.name_edit.text = str(job.name)
	if job.has("archetype"):
		for index in range(lab.archetype_picker.item_count):
			if str(lab.archetype_picker.get_item_metadata(index)) == str(job.archetype):
				lab.archetype_picker.select(index)
	if job.has("facing"):
		lab.facing_picker.select(1 if str(job.facing) == "right" else 0)
	if job.has("display_height"):
		lab.height_spin.value = float(job.display_height)
	if job.has("desc"):
		lab.desc_edit.text = str(job.desc)
	if job.has("tolerance"):
		lab.tolerance_spin.value = float(job.tolerance)
	lab._loading = false
	lab._on_field_changed()
	var prepared: Dictionary = await lab.prepare_reference(str(job.get("cutout", "auto")))
	if not prepared.ok:
		return {"ok": false, "error": prepared.error, "id": lab.creature_id}
	var reference := Image.load_from_file(lab.reference_path())
	var sheet_path := review_dir.path_join("%s__reference.png" % lab.creature_id)
	_with_anchor_line(reference, lab.ground_anchor()).save_png(sheet_path)
	return {"ok": true, "id": lab.creature_id, "sheet": sheet_path.get_file(), "body_height": lab.record.reference.body_height}

func _generate(job: Dictionary) -> Dictionary:
	var creature_id := str(job.get("id", ""))
	if not _select(creature_id):
		return {"ok": false, "error": "unknown creature %s" % creature_id}
	lab.select_state(str(job.get("state", "idle")))
	var prompt := str(job.get("prompt", ""))
	if prompt.is_empty():
		prompt = lab.template_text()
		if job.has("prompt_extra"):
			prompt += " " + str(job.prompt_extra)
	lab.set_prompt_text(prompt)
	if job.has("seed"):
		lab.seed_spin.value = float(job.seed)
	if job.has("seconds"):
		lab.seconds_spin.value = float(job.seconds)
	if job.has("rest"):
		lab.rest_check.button_pressed = bool(job.rest)
	var made: Dictionary = await lab.generate()
	if not made.ok:
		return {"ok": false, "error": made.error, "id": creature_id, "take": made.get("take_id", "")}
	var take := Registry.load_take(creature_id, str(made.take_id))
	var folder := Registry.take_files_dir(creature_id, str(made.take_id)).path_join("masters")
	var images: Array = []
	var frames: Array = take.get("masters", {}).get("frames", [])
	for index in Art.sample_indices(frames.size(), AnimationScript.SOURCE_FPS, 12.0):
		images.append(Image.load_from_file(folder.path_join(str(frames[index].file))))
	var sheet_path := review_dir.path_join("%s__%s__%s.png" % [creature_id, lab.state, made.take_id])
	_sheet(images).save_png(sheet_path)
	return {"ok": true, "id": creature_id, "state": lab.state, "take": made.take_id, "frames": frames.size(), "sheet": sheet_path.get_file(), "seed": int(take.get("seed", 0)), "prompt_version": int(take.get("prompt_version", 0))}

func _install(job: Dictionary) -> Dictionary:
	var creature_id := str(job.get("id", ""))
	if not _select(creature_id):
		return {"ok": false, "error": "unknown creature %s" % creature_id}
	lab.select_state(str(job.get("state", "idle")))
	var take_id := str(job.get("take", ""))
	lab.select_take(take_id)
	if lab.current_take().is_empty():
		return {"ok": false, "error": "no take %s" % take_id}
	lab.fps_spin.value = float(job.get("fps", 12))
	var frames: int = lab.current_take().get("masters", {}).get("frames", []).size()
	lab.start_spin.value = float(job.get("start", 0))
	lab.end_spin.value = float(job.get("end", frames))
	for index in range(lab.frame_cutout_picker.item_count):
		if str(lab.frame_cutout_picker.get_item_metadata(index)) == str(job.get("cutout", "solid")):
			lab.frame_cutout_picker.select(index)
	lab.frame_tolerance_spin.value = float(job.get("tolerance", 30))
	var installed: Dictionary = await lab.install_take(take_id)
	if not installed.ok:
		return {"ok": false, "error": installed.error, "id": creature_id}
	var folder := ProjectSettings.globalize_path(Art.animations_root.path_join("%s_%s" % [creature_id, lab.state]))
	var atlas := Image.load_from_file(folder.path_join("atlas.png"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	var cell: Array = manifest.cell_size
	var cells: Array = []
	for index in range(int(manifest.frame_count)):
		var columns := int(manifest.columns)
		var piece := atlas.get_region(Rect2i(index % columns * int(cell[0]), index / columns * int(cell[1]), int(cell[0]), int(cell[1])))
		var backed := Image.create_empty(piece.get_width(), piece.get_height(), false, Image.FORMAT_RGBA8)
		backed.fill(Color8(40, 46, 60))
		backed.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i.ZERO)
		cells.append(backed)
	var sheet_path := review_dir.path_join("%s__%s__installed.png" % [creature_id, lab.state])
	_sheet(cells).save_png(sheet_path)
	return {"ok": true, "id": creature_id, "state": lab.state, "take": take_id, "frames": int(manifest.frame_count), "sheet": sheet_path.get_file()}

func _encyclopedia(job: Dictionary) -> Dictionary:
	var creature_id := str(job.get("id", ""))
	if not _select(creature_id):
		return {"ok": false, "error": "unknown creature %s" % creature_id}
	return lab.add_to_encyclopedia()

# ---------- review sheets ----------

## Frames in a grid, each scaled into a SHEET_CELL square.
func _sheet(images: Array) -> Image:
	var count := maxi(1, images.size())
	var columns := mini(count, SHEET_COLUMNS)
	var rows := int(ceil(float(count) / columns))
	var sheet := Image.create_empty(columns * SHEET_CELL, rows * SHEET_CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(20, 22, 26))
	for index in range(images.size()):
		var image: Image = images[index]
		if image == null or image.is_empty():
			continue
		var copy := image.duplicate() as Image
		copy.convert(Image.FORMAT_RGBA8)
		var scale := float(SHEET_CELL - 4) / maxf(copy.get_width(), copy.get_height())
		copy.resize(maxi(1, roundi(copy.get_width() * scale)), maxi(1, roundi(copy.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		var origin := Vector2i(index % columns * SHEET_CELL + (SHEET_CELL - copy.get_width()) / 2, index / columns * SHEET_CELL + (SHEET_CELL - copy.get_height()) / 2)
		sheet.blend_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), origin)
	return sheet

func _with_anchor_line(reference: Image, anchor: Vector2) -> Image:
	var copy := reference.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	var y := clampi(roundi(anchor.y), 0, copy.get_height() - 1)
	for x in range(copy.get_width()):
		copy.set_pixel(x, y, Color(0.3, 1.0, 0.5))
	return copy

func _record(result: Dictionary) -> void:
	result["at"] = Time.get_datetime_string_from_system()
	results.append(result)
	var file := FileAccess.open(review_dir.path_join("status.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "\t") + "\n")
		file.close()
