extends RefCounted

## Engine behind the Weapon Lab's clip importer: turns a sprite sheet (for
## example a ChatGPT pose sheet), a folder of frames, or a video into one
## packed, aligned attack-clip sheet (see scripts/model/weapon_clip.gd).
##
##   1. Slice   detect_layout() finds the row of poses on a sheet (skipping
##              labels, borders and the ground line) and splits it into frame
##              boxes at the emptiest columns.
##   2. Cut out cut_frame() removes a flat background locally; frames cut out
##              by Trellis 2 go through filter_pieces() only. Both drop bits
##              that belong to neighbouring poses and stray annotation arrows.
##   3. Align   feet_anchor() finds the ground point under each pose, so poses
##              drawn at different spots on a sheet line up.
##   4. Pack    pack() lines every frame up on its anchor and packs one sheet.
##
## Work lives in art/weapons/clips/<weapon id>/<clip>/ (source copy, cut
## frames, project.json, sheet.png); publishing copies sheet.png into the
## weapon's revision assets.

const Art = preload("res://scripts/tools/weapon_lab_art.gd")

const CLIPS_RELATIVE := "art/weapons/clips"
const SETTINGS_PATH := "user://weapon_clip_settings.json"
const MAX_CELL := 512
const MAX_COLUMNS := 8
const DEFAULT_TOLERANCE := 38.0
const DEFAULT_MIN_PIECE := 0.03
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const VIDEO_EXTENSIONS := ["mp4", "webm", "mov", "gif", "mkv", "avi", "m4v"]

# ---------- folders and settings ----------

static func clips_dir(weapon_id: String) -> String:
	var folder := Art.slug(weapon_id)
	return Art.repo_root().path_join(CLIPS_RELATIVE).path_join(folder if not folder.is_empty() else "unsorted")

static func new_project_dir(weapon_id: String, name: String) -> String:
	var base := Art.slug(name)
	if base.is_empty():
		base = "clip"
	var parent := clips_dir(weapon_id)
	var path := parent.path_join(base)
	var suffix := 2
	while DirAccess.dir_exists_absolute(path):
		path = parent.path_join("%s_%d" % [base, suffix])
		suffix += 1
	DirAccess.make_dir_recursive_absolute(path.path_join("frames"))
	return path

static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	return parsed if parsed is Dictionary else {}

static func save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings, "\t"))

static func save_project(project_dir: String, project: Dictionary) -> bool:
	var file := FileAccess.open(project_dir.path_join("project.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(project, "\t"))
	return true

static func load_project(project_dir: String) -> Dictionary:
	var path := project_dir.path_join("project.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func kind_of(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if IMAGE_EXTENSIONS.has(extension):
		return "image"
	if VIDEO_EXTENSIONS.has(extension):
		return "video"
	return ""

# ---------- 1. slicing ----------

## The sheet's background: the most common colour in `rect` (or the whole
## image), so dark screenshot borders and frames don't fool it.
static func background_color(image: Image, rect: Rect2i = Rect2i()) -> Color:
	var area := rect if rect.has_area() else Rect2i(Vector2i.ZERO, image.get_size())
	var step := maxi(1, int(sqrt(float(area.size.x * area.size.y) / 40000.0)))
	var bins := {}
	for y in range(area.position.y, area.end.y, step):
		for x in range(area.position.x, area.end.x, step):
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var key := (int(color.r8) >> 3) << 10 | (int(color.g8) >> 3) << 5 | (int(color.b8) >> 3)
			var entry: Array = bins.get(key, [0, 0.0, 0.0, 0.0])
			entry[0] += 1
			entry[1] += color.r
			entry[2] += color.g
			entry[3] += color.b
			bins[key] = entry
	var best: Array = [0, 1.0, 1.0, 1.0]
	for key in bins:
		if int(bins[key][0]) > int(best[0]):
			best = bins[key]
	if int(best[0]) == 0:
		return Color.WHITE
	return Color(float(best[1]) / best[0], float(best[2]) / best[0], float(best[3]) / best[0])

## 1 for pixels that differ from `background` by more than `tolerance`
## (0-255 RGB distance) or are transparent-ish on an image with alpha.
static func ink_mask(image: Image, background: Color, tolerance: float = DEFAULT_TOLERANCE) -> PackedByteArray:
	var rgba := image.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var data := rgba.get_data()
	var count := rgba.get_width() * rgba.get_height()
	var mask := PackedByteArray()
	mask.resize(count)
	var br := background.r * 255.0
	var bg := background.g * 255.0
	var bb := background.b * 255.0
	var limit := tolerance * tolerance
	for pixel in range(count):
		var offset := pixel * 4
		if data[offset + 3] < 128:
			continue
		var dr := float(data[offset]) - br
		var dg := float(data[offset + 1]) - bg
		var db := float(data[offset + 2]) - bb
		if dr * dr + dg * dg + db * db > limit:
			mask[pixel] = 1
	return mask

## Finds the row of poses on a sheet and splits it into `count` frame boxes
## (count <= 0: guess from empty gaps). Returns {strip: Rect2i, boxes:
## Array of Rect2i, background: Color, ground_y: int (-1 if no ground line)}.
static func detect_layout(image: Image, count: int = 0, tolerance: float = DEFAULT_TOLERANCE) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var background := background_color(image)
	var mask := ink_mask(image, background, tolerance)
	# Borders (screenshot edges, panel frames) are columns/rows that are almost all ink.
	var column_ink := PackedInt32Array()
	column_ink.resize(width)
	for y in range(height):
		var row := y * width
		for x in range(width):
			column_ink[x] += mask[row + x]
	var border_column := PackedByteArray()
	border_column.resize(width)
	var open_columns := 0
	for x in range(width):
		if column_ink[x] > int(height * 0.9):
			border_column[x] = 1
		else:
			open_columns += 1
	var row_ink := PackedInt32Array()
	row_ink.resize(height)
	var border_row := PackedByteArray()
	border_row.resize(height)
	for y in range(height):
		var row := y * width
		var total := 0
		for x in range(width):
			if border_column[x] == 0:
				total += mask[row + x]
		row_ink[y] = total
		if total > int(open_columns * 0.85):
			border_row[y] = 1
	# The tallest band of inked rows is the pose row; small gaps are allowed.
	var threshold := maxi(2, int(open_columns * 0.004))
	var best := Vector2i(0, height)
	var best_height := -1
	var band_start := -1
	var last_ink := -10
	for y in range(height + 1):
		var inked := y < height and border_row[y] == 0 and row_ink[y] > threshold
		if inked:
			if band_start < 0 or y - last_ink > 3:
				if band_start >= 0 and last_ink - band_start + 1 > best_height:
					best_height = last_ink - band_start + 1
					best = Vector2i(band_start, last_ink + 1)
				band_start = y
			last_ink = y
		elif y == height and band_start >= 0 and last_ink - band_start + 1 > best_height:
			best_height = last_ink - band_start + 1
			best = Vector2i(band_start, last_ink + 1)
	var top := best.x
	var bottom := best.y
	var ground_y := -1
	for y in range(bottom, mini(height, bottom + 4)):
		if border_row[y] == 1:
			ground_y = y
			break
	# Horizontal extent: the widest run of non-border columns, trimmed to ink.
	var strip_columns := PackedInt32Array()
	strip_columns.resize(width)
	for y in range(top, bottom):
		var row := y * width
		for x in range(width):
			strip_columns[x] += mask[row + x]
	var run := Vector2i(0, width)
	var run_width := -1
	var start := -1
	for x in range(width + 1):
		var open := x < width and border_column[x] == 0
		if open and start < 0:
			start = x
		elif not open and start >= 0:
			if x - start > run_width:
				run_width = x - start
				run = Vector2i(start, x)
			start = -1
	var left := run.y
	var right := run.x
	for x in range(run.x, run.y):
		if strip_columns[x] > 0:
			left = mini(left, x)
			right = maxi(right, x + 1)
	if right <= left:
		left = run.x
		right = run.y
	var strip := Rect2i(left, top, right - left, maxi(1, bottom - top))
	var frames := count if count > 0 else guess_count(strip_columns, left, right)
	var bounds := split_columns(strip_columns, left, right, frames)
	var boxes: Array = []
	for index in range(bounds.size() - 1):
		boxes.append(Rect2i(bounds[index], top, maxi(1, bounds[index + 1] - bounds[index]), strip.size.y))
	return {"strip": strip, "boxes": boxes, "background": background, "ground_y": ground_y}

## Counts poses separated by empty columns; tiny slivers join a neighbour.
static func guess_count(columns: PackedInt32Array, left: int, right: int) -> int:
	var segments: Array = []
	var start := -1
	for x in range(left, right + 1):
		var inked := x < right and columns[x] > 1
		if inked and start < 0:
			start = x
		elif not inked and start >= 0:
			segments.append(x - start)
			start = -1
	if segments.is_empty():
		return 1
	var sorted := segments.duplicate()
	sorted.sort()
	var median: int = sorted[sorted.size() / 2]
	var count := 0
	for width in segments:
		if int(width) >= median * 0.35:
			count += 1
	return clampi(count, 1, 64)

## Splits [left, right) into `count` parts, moving each cut to the emptiest
## column near the even split.
static func split_columns(columns: PackedInt32Array, left: int, right: int, count: int) -> Array:
	var frames := maxi(1, count)
	var width := float(right - left) / frames
	var bounds: Array = [left]
	for index in range(1, frames):
		var center := int(round(left + index * width))
		var reach := int(width * 0.3)
		var best := center
		var best_score := INF
		for x in range(maxi(int(bounds[-1]) + 1, center - reach), mini(right - 1, center + reach) + 1):
			var score := float(columns[x]) + absf(x - center) * 0.05
			if score < best_score:
				best_score = score
				best = x
		bounds.append(best)
	bounds.append(right)
	return bounds

## Even boxes over a whole image: `count` frames in `columns` columns.
static func grid_boxes(size: Vector2i, count: int, columns: int) -> Array:
	var frames := maxi(1, count)
	var across := clampi(columns, 1, frames)
	var rows := int(ceil(float(frames) / across))
	var cell := Vector2i(size.x / across, size.y / rows)
	var boxes: Array = []
	for index in range(frames):
		boxes.append(Rect2i(Vector2i(index % across * cell.x, index / across * cell.y), cell))
	return boxes

# ---------- 2. cutting out ----------

## Cuts out `rect` of `image`.
## options: method ("solid" | "alpha"), tolerance, background (Color, optional),
## clear_holes (bool), drop_neighbors (bool), min_piece (0-1 of the main piece).
static func cut_frame(image: Image, rect: Rect2i, options: Dictionary = {}) -> Image:
	var area := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size())) if rect.has_area() else Rect2i(Vector2i.ZERO, image.get_size())
	var crop := image.get_region(area)
	crop.convert(Image.FORMAT_RGBA8)
	if str(options.get("method", "solid")) == "solid":
		var background: Color = options.get("background", background_color(crop)) if options.get("background") is Color else background_color(crop)
		crop = remove_background(crop, background, float(options.get("tolerance", DEFAULT_TOLERANCE)), bool(options.get("clear_holes", true)))
	return filter_pieces(crop, options)

## Makes pixels close to `background` transparent: every such region touching
## the edge, plus enclosed pockets (gaps between arms and legs) when clear_holes.
static func remove_background(source: Image, background: Color, tolerance: float, clear_holes: bool = true) -> Image:
	var image := source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var count := width * height
	var near := PackedByteArray()
	near.resize(count)
	var br := background.r * 255.0
	var bg := background.g * 255.0
	var bb := background.b * 255.0
	var limit := tolerance * tolerance
	for pixel in range(count):
		var offset := pixel * 4
		var dr := float(data[offset]) - br
		var dg := float(data[offset + 1]) - bg
		var db := float(data[offset + 2]) - bb
		if data[offset + 3] < 128 or dr * dr + dg * dg + db * db <= limit:
			near[pixel] = 1
	var hole_minimum := maxi(40, int(count * 0.0012))
	var labels := _components(near, width, height, false)
	for component in labels:
		var clear: bool = component.touches_edge or (clear_holes and int(component.size) >= hole_minimum)
		if not clear:
			continue
		for pixel in component.pixels:
			data[int(pixel) * 4 + 3] = 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

## Keeps the largest piece plus any other piece at least `min_piece` of its
## size; with drop_neighbors, pieces touching the left or right edge (bits of
## the next pose over) are dropped too.
static func filter_pieces(source: Image, options: Dictionary = {}) -> Image:
	var image := source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var solid := PackedByteArray()
	solid.resize(width * height)
	for pixel in range(width * height):
		if data[pixel * 4 + 3] > Art.ALPHA_THRESHOLD:
			solid[pixel] = 1
	var pieces := _components(solid, width, height, true)
	if pieces.is_empty():
		return image
	var main := 0
	for index in range(pieces.size()):
		if int(pieces[index].size) > int(pieces[main].size):
			main = index
	var minimum := float(options.get("min_piece", DEFAULT_MIN_PIECE)) * float(pieces[main].size)
	var drop_neighbors := bool(options.get("drop_neighbors", true))
	for index in range(pieces.size()):
		if index == main:
			continue
		var piece: Dictionary = pieces[index]
		var keep := float(piece.size) >= minimum and not (drop_neighbors and bool(piece.touches_side))
		if keep:
			continue
		for pixel in piece.pixels:
			data[int(pixel) * 4 + 3] = 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

## Connected regions of 1s in `mask`: [{size, pixels, touches_edge, touches_side}].
static func _components(mask: PackedByteArray, width: int, height: int, diagonal: bool) -> Array:
	var seen := PackedByteArray()
	seen.resize(width * height)
	var result: Array = []
	var queue := PackedInt32Array()
	for seed in range(width * height):
		if mask[seed] == 0 or seen[seed] == 1:
			continue
		queue.clear()
		queue.append(seed)
		seen[seed] = 1
		var head := 0
		var touches_edge := false
		var touches_side := false
		while head < queue.size():
			var pixel := queue[head]
			head += 1
			var x := pixel % width
			var y := pixel / width
			if x == 0 or x == width - 1:
				touches_side = true
				touches_edge = true
			if y == 0 or y == height - 1:
				touches_edge = true
			for dy in [-1, 0, 1]:
				var ny: int = y + dy
				if ny < 0 or ny >= height:
					continue
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if not diagonal and dx != 0 and dy != 0:
						continue
					var nx: int = x + dx
					if nx < 0 or nx >= width:
						continue
					var neighbor: int = ny * width + nx
					if mask[neighbor] == 1 and seen[neighbor] == 0:
						seen[neighbor] = 1
						queue.append(neighbor)
		result.append({"size": queue.size(), "pixels": queue.duplicate(), "touches_edge": touches_edge, "touches_side": touches_side})
	return result

## Paints a transparent circle into `image` (the importer's eraser).
static func erase_circle(image: Image, center: Vector2, radius: float) -> void:
	var r := int(ceil(radius))
	for y in range(int(center.y) - r, int(center.y) + r + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(int(center.x) - r, int(center.x) + r + 1):
			if x < 0 or x >= image.get_width():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

# ---------- 3. aligning ----------

## The ground point under a pose: x is the middle of the lowest tenth of the
## figure (the feet), y is `ground_y` when the sheet had a ground line,
## otherwise the bottom of the figure.
static func feet_anchor(image: Image, ground_y: float = -1.0) -> Vector2:
	var bounds := Art.visible_bounds(image)
	if not bounds.has_area():
		return Vector2(image.get_width() * 0.5, image.get_height())
	var band := maxi(2, int(bounds.size.y * 0.1))
	var total := 0.0
	var weight := 0.0
	for y in range(bounds.end.y - band, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.03:
				total += (x + 0.5) * alpha
				weight += alpha
	var feet_x: float = total / weight if weight > 0.0 else bounds.get_center().x
	return Vector2(round(feet_x), ground_y if ground_y >= 0.0 else float(bounds.end.y))

## Height of the figure (used to scale a hero clip to the in-game hero).
static func figure_height(image: Image) -> float:
	return float(Art.visible_bounds(image).size.y)

# ---------- 4. packing ----------

## Lines frames up on their anchors and packs them into one sheet.
## Returns {image, cell: [w, h], anchor: [x, y], columns, frame_count, scale}.
static func pack(frames: Array, anchors: Array, max_cell: int = MAX_CELL) -> Dictionary:
	if frames.is_empty() or frames.size() != anchors.size():
		return {}
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var crops: Array = []
	for index in range(frames.size()):
		var image: Image = frames[index]
		var bounds := Art.visible_bounds(image)
		if not bounds.has_area():
			bounds = Rect2i(Vector2i(anchors[index]), Vector2i.ONE)
		crops.append(bounds)
		var anchor: Vector2 = anchors[index]
		low = Vector2(minf(low.x, bounds.position.x - anchor.x), minf(low.y, bounds.position.y - anchor.y))
		high = Vector2(maxf(high.x, bounds.end.x - anchor.x), maxf(high.y, bounds.end.y - anchor.y))
	var pad := 2.0
	low -= Vector2(pad, pad)
	high += Vector2(pad, pad)
	var full := Vector2i(int(ceil(high.x - low.x)), int(ceil(high.y - low.y)))
	var scale := minf(1.0, float(max_cell) / float(maxi(full.x, full.y)))
	var cell := Vector2i(maxi(1, int(round(full.x * scale))), maxi(1, int(round(full.y * scale))))
	var columns := mini(frames.size(), MAX_COLUMNS)
	var rows := int(ceil(float(frames.size()) / columns))
	var sheet := Image.create_empty(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	for index in range(frames.size()):
		var image: Image = frames[index]
		var rgba := image.duplicate() as Image
		rgba.convert(Image.FORMAT_RGBA8)
		var bounds: Rect2i = crops[index]
		var anchor: Vector2 = anchors[index]
		var canvas := Image.create_empty(full.x, full.y, false, Image.FORMAT_RGBA8)
		var at := Vector2i(int(round(bounds.position.x - anchor.x - low.x)), int(round(bounds.position.y - anchor.y - low.y)))
		canvas.blit_rect(rgba, bounds, at)
		if cell != full:
			canvas.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(canvas, Rect2i(Vector2i.ZERO, cell), Vector2i(index % columns * cell.x, index / columns * cell.y))
	return {"image": sheet, "cell": [cell.x, cell.y], "anchor": [-low.x * scale, -low.y * scale], "columns": columns, "frame_count": frames.size(), "scale": scale}

# ---------- video ----------

## Returns a working ffmpeg command ("" if none): `preferred`, then PATH.
static func find_ffmpeg(preferred: String = "") -> String:
	for candidate in [preferred, "ffmpeg", "ffmpeg.exe"]:
		if str(candidate).is_empty():
			continue
		var output: Array = []
		if OS.execute(str(candidate), ["-hide_banner", "-version"], output, true) == 0:
			return str(candidate)
	return ""

## Extracts frames from a video with ffmpeg into `out_dir`.
## Returns {ok, paths, error}.
static func extract_video(ffmpeg: String, video: String, out_dir: String, fps: float, max_frames: int, start_seconds: float = 0.0, max_height: int = MAX_CELL) -> Dictionary:
	if ffmpeg.is_empty():
		return {"ok": false, "paths": [], "error": "ffmpeg wasn't found. Install it or point the importer at ffmpeg.exe."}
	DirAccess.make_dir_recursive_absolute(out_dir)
	var arguments := PackedStringArray(["-hide_banner", "-loglevel", "error", "-y"])
	if start_seconds > 0.0:
		arguments.append_array(["-ss", "%.3f" % start_seconds])
	arguments.append_array(["-i", video, "-vf", "fps=%s,scale=-2:'min(%d,ih)'" % [str(snappedf(fps, 0.01)), max_height], "-frames:v", str(maxi(1, max_frames)), out_dir.path_join("video_%03d.png")])
	var output: Array = []
	var code := OS.execute(ffmpeg, arguments, output, true)
	var paths: Array = []
	for name in DirAccess.get_files_at(out_dir):
		if name.begins_with("video_") and name.ends_with(".png"):
			paths.append(out_dir.path_join(name))
	paths.sort()
	if code != 0 or paths.is_empty():
		return {"ok": false, "paths": paths, "error": "ffmpeg couldn't read the video (exit %d). %s" % [code, str(output).strip_edges().right(300)]}
	return {"ok": true, "paths": paths, "error": ""}
