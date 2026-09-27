extends RefCounted

## Weapon art preparation for the Weapon Lab, done in Godot.
##
## Produces the same run folder the Python weapon pipeline
## (tools/weapon_pipeline/pipeline.py) writes under art/weapons/runs/<job_id>/:
## original.png, cropped-source.png, rgba-master.png, world-sprite.png,
## square-icon.png, grip-calibration.json, review-*.png, and a manifest.json
## with sha256 hashes, so WeaponPublisher.publish() accepts it unchanged.
##
## The cutout itself comes from one of:
## - the source's own alpha (already-transparent PNGs),
## - ComfyUI's Trellis 2 background removal (see comfy_cutout.gd),
## - a local "solid background" flood fill for flat-backdrop renders.

const Store = preload("res://scripts/tools/weapon_designer_store.gd")

const SOURCE_FOLDER_RELATIVE := "art/ui-items/Weapons"
const RUNS_FOLDER_RELATIVE := "art/weapons/runs"
const WORLD_HEIGHT := 256
const ICON_SIZE := 256
const ALPHA_THRESHOLD := 8
const OUTPUTS := ["original.png", "cropped-source.png", "rgba-master.png", "world-sprite.png", "square-icon.png", "grip-calibration.json", "review-light.png", "review-dark.png", "review-actual-size.png"]

enum Cutout { AUTO, COMFY, SOLID, TRANSPARENT }

## Tests point these at temporary folders.
static var repo_root_override := ""
static var receipt_root: String = Store.JOB_ROOT

static func repo_root() -> String:
	if not repo_root_override.is_empty():
		return repo_root_override
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()

static func sources_dir() -> String:
	return repo_root().path_join(SOURCE_FOLDER_RELATIVE)

static func runs_dir() -> String:
	return repo_root().path_join(RUNS_FOLDER_RELATIVE)

static func run_dir(job_id: String) -> String:
	return runs_dir().path_join(job_id)

# ---------- sources ----------

## PNG files in art/ui-items/Weapons, as repo-relative paths.
static func list_sources() -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(sources_dir())
	if directory == null:
		return result
	for filename in directory.get_files():
		if filename.to_lower().ends_with(".png"):
			result.append(SOURCE_FOLDER_RELATIVE.path_join(filename))
	result.sort()
	return result

static func absolute_source(relative_or_absolute: String) -> String:
	if relative_or_absolute.is_absolute_path():
		return relative_or_absolute
	return repo_root().path_join(relative_or_absolute)

## Copies an image from anywhere on disk into art/ui-items/Weapons so the
## source is kept with the project. Non-PNG images are converted to PNG.
## Returns {"ok", "path" (repo-relative), "error"}.
static func import_source(absolute_path: String) -> Dictionary:
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return {"ok": false, "error": "Couldn't read %s as an image." % absolute_path.get_file()}
	if DirAccess.make_dir_recursive_absolute(sources_dir()) != OK and not DirAccess.dir_exists_absolute(sources_dir()):
		return {"ok": false, "error": "Couldn't create %s." % SOURCE_FOLDER_RELATIVE}
	var stem := slug(absolute_path.get_file().get_basename())
	if stem.is_empty():
		stem = "weapon"
	var target := sources_dir().path_join(stem + ".png")
	var suffix := 2
	while FileAccess.file_exists(target):
		if absolute_path.get_extension().to_lower() == "png" and FileAccess.get_sha256(target) == FileAccess.get_sha256(absolute_path):
			return {"ok": true, "path": SOURCE_FOLDER_RELATIVE.path_join(target.get_file()), "error": ""}
		target = sources_dir().path_join("%s_%d.png" % [stem, suffix])
		suffix += 1
	var error := OK
	if absolute_path.get_extension().to_lower() == "png":
		error = DirAccess.copy_absolute(absolute_path, target)
	else:
		error = image.save_png(target)
	if error != OK:
		return {"ok": false, "error": "Couldn't copy the image into %s (%s)." % [SOURCE_FOLDER_RELATIVE, error_string(error)]}
	return {"ok": true, "path": SOURCE_FOLDER_RELATIVE.path_join(target.get_file()), "error": ""}

## Lowercase id-safe name: letters, digits and underscores.
static func slug(text: String) -> String:
	var result := ""
	for character in text.strip_edges().to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_").left(60)

static func has_transparency(image: Image) -> bool:
	if image == null or image.is_empty() or not image.detect_alpha():
		return false
	var rgba := image.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var data := rgba.get_data()
	for index in range(3, data.size(), 4):
		if data[index] < 250:
			return true
	return false

# ---------- cutouts ----------

## Removes a flat backdrop by flood-filling from the image border.
## Pixels within `tolerance` (0-255 per channel, max distance) of the border
## colour that are connected to the border become transparent.
static func solid_background_cutout(source: Image, tolerance: float = 38.0) -> Image:
	var image := source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var background := _border_color(data, width, height)
	var limit := tolerance * tolerance * 3.0
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	for x in range(width):
		queue.append(x)
		queue.append((height - 1) * width + x)
	for y in range(height):
		queue.append(y * width)
		queue.append(y * width + width - 1)
	var head := 0
	while head < queue.size():
		var pixel := queue[head]
		head += 1
		if visited[pixel] != 0:
			continue
		visited[pixel] = 1
		var offset := pixel * 4
		var dr := float(data[offset]) - background.x
		var dg := float(data[offset + 1]) - background.y
		var db := float(data[offset + 2]) - background.z
		if dr * dr + dg * dg + db * db > limit:
			continue
		data[offset + 3] = 0
		var x := pixel % width
		var y := pixel / width
		if x > 0 and visited[pixel - 1] == 0:
			queue.append(pixel - 1)
		if x < width - 1 and visited[pixel + 1] == 0:
			queue.append(pixel + 1)
		if y > 0 and visited[pixel - width] == 0:
			queue.append(pixel - width)
		if y < height - 1 and visited[pixel + width] == 0:
			queue.append(pixel + width)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

static func _border_color(data: PackedByteArray, width: int, height: int) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for pixel in [0, width - 1, (height - 1) * width, height * width - 1, width / 2, (height - 1) * width + width / 2, (height / 2) * width, (height / 2) * width + width - 1]:
		var offset: int = int(pixel) * 4
		sum += Vector3(data[offset], data[offset + 1], data[offset + 2])
		count += 1
	return sum / float(count)

## Bounding box of pixels with alpha above ALPHA_THRESHOLD (matches the Python pipeline).
static func visible_bounds(image: Image) -> Rect2i:
	var rgba := image.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var width := rgba.get_width()
	var height := rgba.get_height()
	var data := rgba.get_data()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		var row := y * width * 4
		for x in range(width):
			if data[row + x * 4 + 3] > ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# ---------- preparation ----------

static func new_job_id() -> String:
	var base := "job_%s" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var job_id := base
	var suffix := 2
	while DirAccess.dir_exists_absolute(run_dir(job_id)):
		job_id = "%s_%d" % [base, suffix]
		suffix += 1
	return job_id

## Writes a complete preparation run.
## `source_path`: the original image (absolute or repo-relative).
## `cutout`: the RGBA cutout at the source's size, or null to use the source's own alpha.
## `mode`: "transparent", "comfy" or "solid" (recorded in the manifest).
## Returns {"ok", "job_id", "dir", "error", "world_size"}.
static func prepare(source_path: String, cutout: Image, mode: String, grip: Vector2 = Vector2(0.5, 0.75), job_id: String = "", extra: Dictionary = {}) -> Dictionary:
	var source_abs := absolute_source(source_path)
	if not FileAccess.file_exists(source_abs):
		return _fail("Source image not found: %s" % source_path)
	var original := Image.load_from_file(source_abs)
	if original == null or original.is_empty():
		return _fail("Couldn't read the source image.")
	if job_id.is_empty():
		job_id = new_job_id()
	if job_id.contains("/") or job_id.contains("\\") or job_id.contains(".."):
		return _fail("Unsafe job id.")
	var directory := run_dir(job_id)
	if DirAccess.make_dir_recursive_absolute(directory) != OK and not DirAccess.dir_exists_absolute(directory):
		return _fail("Couldn't create %s." % directory)
	var stages := {}
	# snapshot
	if source_abs.get_extension().to_lower() == "png":
		if DirAccess.copy_absolute(source_abs, directory.path_join("original.png")) != OK:
			return _fail("Couldn't copy the source into the run folder.")
	else:
		original.save_png(directory.path_join("original.png"))
	stages["snapshot"] = _stage(directory, ["original.png"])
	# cutout
	var master := original.duplicate() as Image
	master.convert(Image.FORMAT_RGBA8)
	var cutout_source := ""
	if cutout != null:
		var cut := cutout.duplicate() as Image
		cut.convert(Image.FORMAT_RGBA8)
		if cut.get_size() != master.get_size():
			cut.resize(master.get_width(), master.get_height(), Image.INTERPOLATE_BILINEAR)
		cutout_source = "comfy-cutout.png" if mode == "comfy" else "lab-cutout.png"
		cut.save_png(directory.path_join(cutout_source))
		master = cut
	var bounds := visible_bounds(master)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return _fail("The cutout has no visible pixels. Try a different cutout method.")
	var cropped := master.get_region(bounds)
	cropped.save_png(directory.path_join("cropped-source.png"))
	master.save_png(directory.path_join("rgba-master.png"))
	var cutout_outputs := ["cropped-source.png", "rgba-master.png"]
	if not cutout_source.is_empty():
		cutout_outputs.append(cutout_source)
	stages["cutout"] = _stage(directory, cutout_outputs)
	# prepare
	var world := cropped.duplicate() as Image
	var scale := float(WORLD_HEIGHT) / float(cropped.get_height())
	world.resize(maxi(1, roundi(cropped.get_width() * scale)), WORLD_HEIGHT, Image.INTERPOLATE_LANCZOS)
	world.save_png(directory.path_join("world-sprite.png"))
	var icon := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var fit := cropped.duplicate() as Image
	var fit_limit := roundi(ICON_SIZE * 0.9)
	if fit.get_width() > fit_limit or fit.get_height() > fit_limit:
		var fit_scale := minf(float(fit_limit) / fit.get_width(), float(fit_limit) / fit.get_height())
		fit.resize(maxi(1, roundi(fit.get_width() * fit_scale)), maxi(1, roundi(fit.get_height() * fit_scale)), Image.INTERPOLATE_LANCZOS)
	icon.blend_rect(fit, Rect2i(Vector2i.ZERO, fit.get_size()), Vector2i((ICON_SIZE - fit.get_width()) / 2, (ICON_SIZE - fit.get_height()) / 2))
	icon.save_png(directory.path_join("square-icon.png"))
	_write_json(directory.path_join("grip-calibration.json"), {
		"coordinate_system": "top-left pixels; normalized values are relative to cropped-source",
		"pivot_normalized": [grip.x, grip.y],
		"pivot_pixels": [grip.x * cropped.get_width(), grip.y * cropped.get_height()],
		"source_size": [cropped.get_width(), cropped.get_height()],
		"world_size": [world.get_width(), world.get_height()],
	})
	stages["prepare"] = _stage(directory, ["world-sprite.png", "square-icon.png", "grip-calibration.json"])
	# review
	for pair in [["review-light.png", Color8(232, 232, 226)], ["review-dark.png", Color8(30, 38, 42)]]:
		var canvas := Image.create_empty(world.get_width(), world.get_height(), false, Image.FORMAT_RGBA8)
		canvas.fill(pair[1])
		canvas.blend_rect(world, Rect2i(Vector2i.ZERO, world.get_size()), Vector2i.ZERO)
		canvas.convert(Image.FORMAT_RGB8)
		canvas.save_png(directory.path_join(str(pair[0])))
	world.save_png(directory.path_join("review-actual-size.png"))
	stages["review"] = _stage(directory, ["review-light.png", "review-dark.png", "review-actual-size.png"])
	# manifest
	var settings := {"cutout": "comfy" if mode == "comfy" else "transparent", "lab_cutout": mode, "mask": null, "crop": null, "world_height": WORLD_HEIGHT, "icon_size": ICON_SIZE, "pivot": [grip.x, grip.y], "source_sha256": FileAccess.get_sha256(source_abs), "mask_sha256": null}
	var outputs := {}
	for name in OUTPUTS:
		outputs[name] = FileAccess.get_sha256(directory.path_join(name))
	var manifest := {
		"version": 1,
		"job_id": job_id,
		"kind": "weapon-concept-preparation",
		"prepared_by": "weapon_lab",
		"source": source_abs,
		"settings": settings,
		"settings_hash": JSON.stringify(settings, "", true).sha256_text(),
		"status": "complete",
		"stages": stages,
		"outputs": outputs,
		"gpu_work": extra.get("gpu_work", {"submitted": false, "prompt_id": null, "reconciliation": "not-required"}),
	}
	if not cutout_source.is_empty():
		manifest["cutout_source"] = cutout_source
	if extra.has("history"):
		_write_json(directory.path_join("cutout-history.json"), extra["history"])
	if not _write_json(directory.path_join("manifest.json"), manifest):
		return _fail("Couldn't write the run manifest.")
	_append_progress(directory, {"event": "job_complete", "progress": 1.0, "prepared_by": "weapon_lab", "cutout": mode})
	Store.save_job_receipt({"job_id": job_id, "draft_id": str(extra.get("draft_id", "")), "status": "complete", "stage": "review", "progress": 1.0, "failure": "", "source": source_path, "created_at": Time.get_datetime_string_from_system(true)}, receipt_root)
	return {"ok": true, "job_id": job_id, "dir": directory, "error": "", "world_size": world.get_size()}

static func load_manifest(job_id: String) -> Dictionary:
	if job_id.is_empty() or job_id.contains("/") or job_id.contains("\\") or job_id.contains(".."):
		return {}
	var path := run_dir(job_id).path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func is_complete(job_id: String) -> bool:
	var manifest := load_manifest(job_id)
	if str(manifest.get("status", "")) != "complete":
		return false
	for name in ["world-sprite.png", "square-icon.png"]:
		var path := run_dir(job_id).path_join(name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(manifest.get("outputs", {}).get(name, "")):
			return false
	return true

## Loads a PNG from an absolute or res:// path without the import system, so
## freshly written files show up immediately.
static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var file_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(file_path):
		return null
	var image := Image.load_from_file(file_path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null

static func _stage(directory: String, names: Array) -> Dictionary:
	var outputs := {}
	for name in names:
		outputs[name] = FileAccess.get_sha256(directory.path_join(str(name)))
	return {"status": "complete", "outputs": outputs}

static func _append_progress(directory: String, record: Dictionary) -> void:
	var path := directory.path_join("progress.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	record["time"] = Time.get_datetime_string_from_system(true)
	file.store_line(JSON.stringify(record, "", true))
	file.close()

static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "job_id": "", "dir": "", "error": message}
