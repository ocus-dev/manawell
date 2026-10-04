extends RefCounted

## Image work for the Creature Lab, all in Godot (no Python needed):
##
## - prepare_reference(): the concept cutout placed on the padded square
##   canvas H3 animates from, exactly like tools/animation_pipeline/prepare.py
##   reference(): 70% width / 72% height, bottom-centre ground anchor at 86%,
##   flat (180,180,180) background. Also the transparent still the game draws
##   when a creature has no clip for a state.
## - sample_indices(): prepare.py's frame sampling (nearest frame per output
##   time, no duplicates).
## - install_clip(): cut-out frames -> ONE union crop around the shared ground
##   anchor -> atlas.png + animation.tres + manifest.json in
##   assets/side-view/animations/<creature>_<state>/, the layout every actor
##   uses (see SideViewVisualConfig and HeroAnimations).

const Registry = preload("res://scripts/model/creature_registry.gd")
const AnimationScript = preload("res://scripts/model/creature_animation.gd")
const HeroAnimationsScript = preload("res://scripts/model/hero_animations.gd")
const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const WeaponArt = preload("res://scripts/tools/weapon_lab_art.gd")

const BACKGROUND := Color8(180, 180, 180)
const WIDTH_FILL := 0.70
const HEIGHT_FILL := 0.72
const ANCHOR_HEIGHT := 0.86
const ALPHA_THRESHOLD := 8
const MAX_COLUMNS := 8
const PADDING := 4

## Tests point this somewhere temporary.
static var animations_root := ConfigScript.ANIMATIONS_ROOT

# ---------- cutouts ----------

static func has_transparency(image: Image) -> bool:
	return WeaponArt.has_transparency(image)

## Removes a flat backdrop. Concept sheets often have a thin frame line or a
## screenshot edge, so the backdrop colour is the commonest colour on a ring
## a little inside the border, the band outside that ring is dropped, and the
## fill starts from the ring. clean_cutout() then drops leftover bars.
static func solid_cutout(source: Image, tolerance: float = 38.0) -> Image:
	var image := source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var inset := clampi(roundi(minf(width, height) * 0.02), 1, maxi(1, mini(width, height) / 4))
	# Rings at 2%, 5%, 8% and 11% in: screenshots often have dark bars or a
	# frame around the art, and the inner rings reach past them.
	var ring := PackedInt32Array()
	for fraction in [0.02, 0.05, 0.08, 0.11]:
		var step := clampi(roundi(minf(width, height) * fraction), 1, maxi(1, mini(width, height) / 3))
		for x in range(step, width - step):
			ring.append(step * width + x)
			ring.append((height - 1 - step) * width + x)
		for y in range(step, height - step):
			ring.append(y * width + step)
			ring.append(y * width + width - 1 - step)
	# The most common colour on the rings (colours bucketed 16 levels apart).
	var buckets := {}
	for pixel in ring:
		var key := (data[pixel * 4] >> 4) << 8 | (data[pixel * 4 + 1] >> 4) << 4 | (data[pixel * 4 + 2] >> 4)
		var bucket: Array = buckets.get(key, [0, 0.0, 0.0, 0.0])
		bucket[0] += 1
		bucket[1] += data[pixel * 4]
		bucket[2] += data[pixel * 4 + 1]
		bucket[3] += data[pixel * 4 + 2]
		buckets[key] = bucket
	var best: Array = [0, 0.0, 0.0, 0.0]
	for key in buckets:
		if int(buckets[key][0]) > int(best[0]):
			best = buckets[key]
	var background := Vector3(best[1], best[2], best[3]) / maxf(1.0, float(best[0]))
	var limit := tolerance * tolerance * 3.0
	var visited := PackedByteArray()
	visited.resize(width * height)
	# The band outside the ring goes.
	for y in range(height):
		for x in range(width):
			if x < inset or y < inset or x >= width - inset or y >= height - inset:
				var outside := y * width + x
				visited[outside] = 1
				data[outside * 4 + 3] = 0
	var queue := ring.duplicate()
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
		if x > 0 and visited[pixel - 1] == 0:
			queue.append(pixel - 1)
		if x < width - 1 and visited[pixel + 1] == 0:
			queue.append(pixel + 1)
		if pixel >= width and visited[pixel - width] == 0:
			queue.append(pixel - width)
		if pixel + width < width * height and visited[pixel + width] == 0:
			queue.append(pixel + width)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

## A cut-out animation frame on the flat grey H3 canvas: no frame line there,
## so the plain border flood fill is enough (and faster).
static func frame_cutout(frame: Image, tolerance: float = 30.0) -> Image:
	return WeaponArt.solid_background_cutout(frame, tolerance)

## Keeps only the biggest connected opaque piece plus pieces at least
## `keep_fraction` of its size (drops UI bits, labels, stray specks).
static func keep_main_piece(image: Image, keep_fraction: float = 0.08) -> Image:
	var rgba := image.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var width := rgba.get_width()
	var height := rgba.get_height()
	var data := rgba.get_data()
	var labels := PackedInt32Array()
	labels.resize(width * height)
	var sizes: Array[int] = [0]
	## Per piece: which image sides it reaches (bit 1 left, 2 right, 4 top, 8 bottom).
	var sides: Array[int] = [0]
	var margin := maxi(2, roundi(minf(width, height) * 0.03))
	var queue := PackedInt32Array()
	for start in range(width * height):
		if labels[start] != 0 or data[start * 4 + 3] <= ALPHA_THRESHOLD:
			continue
		var label := sizes.size()
		var count := 0
		var touched := 0
		queue.clear()
		queue.append(start)
		labels[start] = label
		var head := 0
		while head < queue.size():
			var pixel := queue[head]
			head += 1
			count += 1
			var x := pixel % width
			var y := pixel / width
			if x < margin:
				touched |= 1
			if x >= width - margin:
				touched |= 2
			if y < margin:
				touched |= 4
			if y >= height - margin:
				touched |= 8
			for neighbour in [pixel - 1 if x > 0 else -1, pixel + 1 if x < width - 1 else -1, pixel - width, pixel + width]:
				if neighbour < 0 or neighbour >= width * height or labels[neighbour] != 0 or data[neighbour * 4 + 3] <= ALPHA_THRESHOLD:
					continue
				labels[neighbour] = label
				queue.append(neighbour)
		sizes.append(count)
		sides.append(touched)
	if sizes.size() <= 2:
		return rgba
	# Frames and screenshot bars run along three or four sides: never the
	# creature (unless nothing else is left).
	var keep: Array[bool] = [false]
	var biggest := 0
	for label in range(1, sizes.size()):
		var bits := sides[label]
		var edges := (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1) + ((bits >> 3) & 1)
		keep.append(edges < 3)
		if keep[label]:
			biggest = maxi(biggest, sizes[label])
	if biggest == 0:
		return rgba
	var minimum := int(biggest * keep_fraction)
	for pixel in range(width * height):
		var label := labels[pixel]
		if label != 0 and (not keep[label] or sizes[label] < minimum):
			data[pixel * 4 + 3] = 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

## keep_main_piece() for big images: the pieces are found on a copy at most
## `work_size` px across, then the full-size alpha is masked with the result.
static func clean_cutout(image: Image, work_size: int = 512) -> Image:
	var full := image.duplicate() as Image
	full.convert(Image.FORMAT_RGBA8)
	var factor := minf(1.0, float(work_size) / maxf(full.get_width(), full.get_height()))
	if is_equal_approx(factor, 1.0):
		return keep_main_piece(full)
	var small := full.duplicate() as Image
	small.resize(maxi(1, roundi(full.get_width() * factor)), maxi(1, roundi(full.get_height() * factor)), Image.INTERPOLATE_BILINEAR)
	var kept := keep_main_piece(small)
	var mask := Image.create_empty(kept.get_width(), kept.get_height(), false, Image.FORMAT_L8)
	var kept_data := kept.get_data()
	var mask_data := PackedByteArray()
	mask_data.resize(kept.get_width() * kept.get_height())
	for pixel in range(mask_data.size()):
		mask_data[pixel] = 255 if kept_data[pixel * 4 + 3] > ALPHA_THRESHOLD else 0
	mask = Image.create_from_data(kept.get_width(), kept.get_height(), false, Image.FORMAT_L8, mask_data)
	# Grow the kept area by a pixel of the small copy so edges survive.
	mask.resize(full.get_width(), full.get_height(), Image.INTERPOLATE_BILINEAR)
	var big_mask := mask.get_data()
	var data := full.get_data()
	for pixel in range(big_mask.size()):
		if big_mask[pixel] == 0:
			data[pixel * 4 + 3] = 0
	return Image.create_from_data(full.get_width(), full.get_height(), false, Image.FORMAT_RGBA8, data)

## Box of pixels with alpha above ALPHA_THRESHOLD (Rect2i() when empty).
static func alpha_bounds(image: Image) -> Rect2i:
	return WeaponArt.visible_bounds(image)

static func flipped(image: Image) -> Image:
	var copy := image.duplicate() as Image
	copy.flip_x()
	return copy

# ---------- reference ----------

## Places a transparent cutout on the H3 canvas. Returns
## {"ok", "error", "reference": Image (RGB on grey), "still": Image (RGBA,
##  same canvas, transparent), "info": Dictionary (reference.json)}.
static func prepare_reference(cutout: Image, size: int = AnimationScript.DEFAULT_SIZE) -> Dictionary:
	if size < 256 or size % 32 != 0:
		return _fail("The canvas must be at least 256 and a multiple of 32.")
	var rgba := cutout.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var box := alpha_bounds(rgba)
	if box.size.x <= 1 or box.size.y <= 1:
		return _fail("The cutout is empty. Try another cutout method.")
	if box.size == rgba.get_size():
		return _fail("The cutout is fully opaque, so the background wasn't removed. Try another cutout method.")
	var crop := rgba.get_region(box)
	var scale := minf(size * WIDTH_FILL / crop.get_width(), size * HEIGHT_FILL / crop.get_height())
	var resized_size := Vector2i(maxi(1, roundi(crop.get_width() * scale)), maxi(1, roundi(crop.get_height() * scale)))
	crop.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_LANCZOS)
	var anchor := Vector2i(size / 2, roundi(size * ANCHOR_HEIGHT))
	var paste := Vector2i(anchor.x - resized_size.x / 2, anchor.y - resized_size.y)
	var still := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	still.blit_rect(crop, Rect2i(Vector2i.ZERO, resized_size), paste)
	var reference := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	reference.fill(BACKGROUND)
	reference.blend_rect(crop, Rect2i(Vector2i.ZERO, resized_size), paste)
	reference.convert(Image.FORMAT_RGB8)
	var bounds := alpha_bounds(still)
	var info := {
		"canvas": [size, size],
		"source_crop": [box.position.x, box.position.y, box.end.x, box.end.y],
		"uniform_scale": scale,
		"paste": [paste.x, paste.y],
		"ground_anchor": [anchor.x, anchor.y],
		"body_height": float(bounds.size.y),
		"visible_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"background": [180, 180, 180],
		"note": "Same framing as tools/animation_pipeline/prepare.py reference(). The anchor is the visible bottom centre; adjust it in the lab if the feet sit elsewhere.",
	}
	return {"ok": true, "error": "", "reference": reference, "still": still, "info": info}

## Writes reference.png / reference.json / cutout.png under
## art/creatures/references/<id>/ and the still under assets/side-view/creatures/.
static func save_reference(creature_id: String, prepared: Dictionary, cutout: Image, extra: Dictionary = {}) -> Dictionary:
	var folder := Registry.reference_dir(creature_id)
	DirAccess.make_dir_recursive_absolute(folder)
	var reference: Image = prepared.reference
	var still: Image = prepared.still
	if reference.save_png(folder.path_join("reference.png")) != OK:
		return _fail("Couldn't write %s." % folder.path_join("reference.png"))
	cutout.save_png(folder.path_join("cutout.png"))
	var still_res := Registry.still_path(creature_id)
	var still_abs := ProjectSettings.globalize_path(still_res) if still_res.begins_with("res://") else still_res
	DirAccess.make_dir_recursive_absolute(still_abs.get_base_dir())
	if still.save_png(still_abs) != OK:
		return _fail("Couldn't write %s." % still_abs)
	var info: Dictionary = prepared.info.duplicate(true)
	for key in extra:
		info[key] = extra[key]
	info["reference_sha256"] = FileAccess.get_sha256(folder.path_join("reference.png"))
	info["still"] = still_res
	info["prepared_at"] = Time.get_datetime_string_from_system()
	var file := FileAccess.open(folder.path_join("reference.json"), FileAccess.WRITE)
	if file == null:
		return _fail("Couldn't write reference.json.")
	file.store_string(JSON.stringify(info, "\t") + "\n")
	file.close()
	return {"ok": true, "error": "", "info": info, "path": folder.path_join("reference.png")}

## Moves the ground anchor (feet line) of a prepared reference.
static func with_anchor(info: Dictionary, anchor: Vector2) -> Dictionary:
	var copy := info.duplicate(true)
	copy["ground_anchor"] = [roundi(anchor.x), roundi(anchor.y)]
	return copy

# ---------- sampling ----------

## prepare.py sample_indices(): nearest source frame to each output time.
static func sample_indices(count: int, source_fps: float, target_fps: float, start: int = 0, end: int = -1) -> Array:
	var last := count if end < 0 else end
	if source_fps <= 0.0 or target_fps <= 0.0 or target_fps > source_fps or start < 0 or start >= last or last > count:
		return []
	var picked := {}
	var duration := float(last - start) / source_fps
	var time := 0.0
	var step := 1.0 / target_fps
	while time < duration - 0.0000001:
		picked[mini(last - 1, start + roundi(time * source_fps))] = true
		time += step
	var result := picked.keys()
	result.sort()
	return result

# ---------- install ----------

## Packs cut-out canvas frames (all the reference's size) into the game clip
## <creature>_<state>. anchor/reference_height come from the creature's
## reference. Returns {"ok", "error", "frames": SpriteFrames, "folder",
## "manifest"}.
static func install_clip(creature_id: String, state: String, frames: Array, anchor: Vector2, reference_height: float, display_height: float, fps: float, extra: Dictionary = {}) -> Dictionary:
	if frames.is_empty():
		return _fail("No frames to install.")
	var canvas: Vector2i = (frames[0] as Image).get_size()
	var union := Rect2i()
	var have := false
	for frame in frames:
		if (frame as Image).get_size() != canvas:
			return _fail("Every frame must share the reference canvas.")
		var box := alpha_bounds(frame)
		if box.size == Vector2i.ZERO:
			continue
		union = box if not have else union.merge(box)
		have = true
	if not have:
		return _fail("Every frame came out empty; check the cutout.")
	var anchor_i := Vector2i(roundi(anchor.x), roundi(anchor.y))
	union = union.expand(anchor_i).expand(anchor_i + Vector2i.ONE).grow(PADDING)
	union = union.intersection(Rect2i(Vector2i.ZERO, canvas))
	var cell := union.size
	var count := frames.size()
	var columns := mini(count, MAX_COLUMNS)
	var rows := int(ceil(float(count) / columns))
	var atlas := Image.create_empty(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	for index in range(count):
		var frame: Image = frames[index]
		frame.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(frame, union, Vector2i(index % columns * cell.x, index / columns * cell.y))
	var folder := "%s_%s" % [creature_id, state]
	var directory := animations_root.path_join(folder)
	var absolute := ProjectSettings.globalize_path(directory)
	HeroAnimationsScript._backup(directory, folder)
	DirAccess.make_dir_recursive_absolute(absolute)
	if atlas.save_png(absolute.path_join("atlas.png")) != OK:
		return _fail("Couldn't write %s." % directory.path_join("atlas.png"))
	var durations: Array = []
	for index in range(count):
		durations.append(1.0)
	var manifest := {
		"union_crop": [union.position.x, union.position.y, union.end.x, union.end.y],
		"cell_size": [cell.x, cell.y],
		"ground_anchor": [anchor.x - union.position.x, anchor.y - union.position.y],
		"recommended_scale": display_height / maxf(1.0, reference_height),
		"frame_count": count,
		"columns": columns,
		"playback_fps": fps,
		"frame_durations": durations,
		"motion": state,
		"loop_requested": ConfigScript.loops(state),
		"damage_event": null,
		"review_required": true,
		"source": "creature lab",
		"creature": creature_id,
		"installed_at": Time.get_datetime_string_from_system(),
	}
	for key in extra:
		manifest[key] = extra[key]
	var manifest_file := FileAccess.open(absolute.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		return _fail("Couldn't write the manifest in %s." % directory)
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	var tres := HeroAnimationsScript._tres_text(directory, state, count, columns, cell, fps, durations)
	var tres_file := FileAccess.open(absolute.path_join("animation.tres"), FileAccess.WRITE)
	if tres_file == null:
		return _fail("Couldn't write the animation in %s." % directory)
	tres_file.store_string(tres)
	tres_file.close()
	var sprite_frames := HeroAnimationsScript.runtime_frames(atlas, state, count, columns, cell, fps, durations)
	ConfigScript.runtime_frames[folder] = sprite_frames
	ConfigScript.runtime_manifests[folder] = manifest
	ConfigScript.clear_disk_cache()
	Registry.clear_art_cache()
	return {"ok": true, "error": "", "frames": sprite_frames, "folder": directory, "manifest": manifest}

## Clips written by an earlier run that Godot hasn't imported yet (the editor
## imports new files when it gets focus): plays them straight from atlas.png
## + manifest.json, like install_clip() does for the run that made them.
static func register_unimported_clip(creature_id: String, state: String) -> bool:
	var folder := "%s_%s" % [creature_id, state]
	if ConfigScript.runtime_frames.has(folder):
		return true
	var directory := animations_root.path_join(folder)
	var absolute := ProjectSettings.globalize_path(directory)
	var atlas_res := directory.path_join("atlas.png")
	if not FileAccess.file_exists(absolute.path_join("manifest.json")) or (atlas_res.begins_with("res://") and ResourceLoader.exists(atlas_res)):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute.path_join("manifest.json")))
	var atlas := Image.load_from_file(absolute.path_join("atlas.png"))
	if not manifest is Dictionary or atlas == null or atlas.is_empty():
		return false
	var cell: Array = manifest.get("cell_size", [0, 0])
	var count := int(manifest.get("frame_count", 0))
	if count <= 0:
		return false
	var durations: Array = manifest.get("frame_durations", [])
	while durations.size() < count:
		durations.append(1.0)
	ConfigScript.runtime_frames[folder] = HeroAnimationsScript.runtime_frames(atlas, state, count, maxi(1, int(manifest.get("columns", 1))), Vector2i(int(cell[0]), int(cell[1])), float(manifest.get("playback_fps", 12.0)), durations)
	ConfigScript.runtime_manifests[folder] = manifest
	return true

## True when <creature>_<state> has a clip (installed this run or on disk).
static func has_clip(creature_id: String, state: String) -> bool:
	var folder := "%s_%s" % [creature_id, state]
	if ConfigScript.runtime_frames.has(folder):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(animations_root.path_join(folder).path_join("manifest.json")))

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
