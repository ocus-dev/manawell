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
	# Poses on AI sheets often overlap in columns (a sword tip under the next
	# pose's foot) but are still separate shapes, so find them as shapes first.
	var figures := detect_figures(mask, width, strip, count)
	if not figures.is_empty():
		return {"strip": strip, "boxes": figures.boxes, "background": background, "ground_y": ground_y, "owners": figures.owners, "mode": "figures"}
	var frames := count if count > 0 else guess_count(strip_columns, left, right)
	var bounds := split_columns(strip_columns, left, right, frames)
	var boxes: Array = []
	for index in range(bounds.size() - 1):
		boxes.append(Rect2i(bounds[index], top, maxi(1, bounds[index + 1] - bounds[index]), strip.size.y))
	return {"strip": strip, "boxes": boxes, "background": background, "ground_y": ground_y, "owners": PackedByteArray(), "mode": "columns"}

## Finds each pose as a separate shape inside `strip`. Big shapes are poses;
## small ones (sparks, slash arcs, dust) join the nearest pose. With `count`
## > 0, shapes that split a pose in two are merged until there are `count`.
## Returns {} when the poses touch (use column cuts instead), otherwise
## {boxes: Array of Rect2i, owners: PackedByteArray} where owners holds, for
## every pixel of the strip, 0 or the 1-based frame that owns it.
static func detect_figures(mask: PackedByteArray, image_width: int, strip: Rect2i, count: int = 0) -> Dictionary:
	var w := strip.size.x
	var h := strip.size.y
	if w <= 0 or h <= 0:
		return {}
	var local := PackedByteArray()
	local.resize(w * h)
	for y in range(h):
		var row := (strip.position.y + y) * image_width + strip.position.x
		for x in range(w):
			local[y * w + x] = mask[row + x]
	var pieces := _components(local, w, h, true)
	if pieces.is_empty():
		return {}
	var largest := 0
	for piece in pieces:
		largest = maxi(largest, int(piece.size))
	# Bounding boxes.
	for piece in pieces:
		var low := Vector2i(w, h)
		var high := Vector2i(-1, -1)
		for pixel in piece.pixels:
			var x := int(pixel) % w
			var y := int(pixel) / w
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
		piece["rect"] = Rect2i(low, high - low + Vector2i.ONE)
	var poses: Array = []
	for index in range(pieces.size()):
		if int(pieces[index].size) >= largest * 0.25:
			poses.append({"pieces": [index], "rect": pieces[index].rect, "size": int(pieces[index].size)})
	poses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.rect as Rect2i).get_center().x < (b.rect as Rect2i).get_center().x)
	# A big shape mostly inside another pose's columns (a detached slash arc)
	# belongs to that pose.
	var merged := true
	while merged and poses.size() > 1:
		merged = false
		for index in range(poses.size()):
			var rect: Rect2i = poses[index].rect
			for other in range(poses.size()):
				if other == index or int(poses[other].size) < int(poses[index].size):
					continue
				var bigger: Rect2i = poses[other].rect
				var overlap := mini(rect.end.x, bigger.end.x) - maxi(rect.position.x, bigger.position.x)
				if overlap >= rect.size.x * 0.6 and int(poses[index].size) < int(poses[other].size) * 0.6:
					_merge_pose(poses, other, index)
					merged = true
					break
			if merged:
				break
	# Too many for the requested count: join the neighbours that overlap most.
	while count > 0 and poses.size() > count:
		var best := 0
		var best_gap := INF
		for index in range(poses.size() - 1):
			var a: Rect2i = poses[index].rect
			var b: Rect2i = poses[index + 1].rect
			var gap := float(b.position.x - a.end.x)
			if gap < best_gap:
				best_gap = gap
				best = index
		_merge_pose(poses, best, best + 1)
	if poses.size() < 2 or (count > 0 and poses.size() != count):
		return {}
	if count <= 0:
		# A shape far wider than the others is several touching poses.
		var widths: Array = []
		for pose in poses:
			widths.append((pose.rect as Rect2i).size.x)
		widths.sort()
		if float(widths[-1]) > float(widths[widths.size() / 2]) * 1.8:
			return {}
	var owners := PackedByteArray()
	owners.resize(w * h)
	var owner_of := {}
	for number in range(poses.size()):
		for index in poses[number].pieces:
			owner_of[int(index)] = number
	# Small shapes join the nearest pose.
	for index in range(pieces.size()):
		if owner_of.has(index):
			continue
		var rect: Rect2i = pieces[index].rect
		var nearest := 0
		var nearest_distance := INF
		for number in range(poses.size()):
			var pose: Rect2i = poses[number].rect
			var dx := maxf(0.0, maxf(float(pose.position.x - rect.end.x), float(rect.position.x - pose.end.x)))
			var dy := maxf(0.0, maxf(float(pose.position.y - rect.end.y), float(rect.position.y - pose.end.y)))
			var distance := dx * dx + dy * dy - float(mini(rect.end.x, pose.end.x) - maxi(rect.position.x, pose.position.x))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = number
		owner_of[index] = nearest
	var boxes: Array = []
	var lows: Array = []
	var highs: Array = []
	for number in range(poses.size()):
		lows.append(w)
		highs.append(0)
	for index in range(pieces.size()):
		var number: int = owner_of[index]
		var rect: Rect2i = pieces[index].rect
		lows[number] = mini(int(lows[number]), rect.position.x)
		highs[number] = maxi(int(highs[number]), rect.end.x)
		for pixel in pieces[index].pixels:
			owners[int(pixel)] = number + 1
	for number in range(poses.size()):
		var left := maxi(0, int(lows[number]) - 4)
		var right := mini(w, int(highs[number]) + 4)
		boxes.append(Rect2i(strip.position.x + left, strip.position.y, right - left, h))
	return {"boxes": boxes, "owners": owners}

static func _merge_pose(poses: Array, keep: int, drop: int) -> void:
	var into: Dictionary = poses[keep]
	var from: Dictionary = poses[drop]
	into["pieces"] = into.pieces + from.pieces
	into["rect"] = (into.rect as Rect2i).merge(from.rect)
	into["size"] = int(into.size) + int(from.size)
	poses.remove_at(drop)

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
	return filter_pieces(clear_other_owners(crop, area, options), options)

## With shape detection (options.owners / owner_strip / frame), clears pixels
## that belong to other poses, so overlapping poses don't bleed into each
## other. Neighbour dropping by box edge is then unnecessary.
static func clear_other_owners(crop: Image, area: Rect2i, options: Dictionary) -> Image:
	var owners: Variant = options.get("owners")
	if not owners is PackedByteArray or (owners as PackedByteArray).is_empty():
		return crop
	var strip: Rect2i = options.get("owner_strip", Rect2i())
	var mine := int(options.get("frame", -1)) + 1
	var width := crop.get_width()
	var data := crop.get_data()
	for y in range(area.position.y, area.end.y):
		if y < strip.position.y or y >= strip.end.y:
			continue
		var row := (y - strip.position.y) * strip.size.x
		for x in range(area.position.x, area.end.x):
			if x < strip.position.x or x >= strip.end.x:
				continue
			var owner: int = (owners as PackedByteArray)[row + x - strip.position.x]
			if owner != 0 and owner != mine:
				data[((y - area.position.y) * width + (x - area.position.x)) * 4 + 3] = 0
	options["drop_neighbors"] = false
	return Image.create_from_data(width, crop.get_height(), false, Image.FORMAT_RGBA8, data)

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

## Horizontal centre of the upper body (the top 45% of the figure): the
## torso, which stays put in a walk cycle while the legs swing.
static func body_center_x(image: Image) -> float:
	var bounds := Art.visible_bounds(image)
	if not bounds.has_area():
		return image.get_width() * 0.5
	var bottom := bounds.position.y + maxi(1, int(bounds.size.y * 0.45))
	var total := 0.0
	var weight := 0.0
	for y in range(bounds.position.y, bottom):
		for x in range(bounds.position.x, bounds.end.x):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.03:
				total += (x + 0.5) * alpha
				weight += alpha
	return round(total / weight) if weight > 0.0 else bounds.get_center().x

## Follows a small patch (the front fist) from frame `from` to every other
## frame: each frame searches near the point found in its neighbour for the
## best match (sum of squared differences on alpha-weighted brightness, at
## half resolution). Returns one Vector2 per frame (frame pixels).
static func track_patch(frames: Array, from: int, point: Vector2, radius: int = 18, reach: int = 40) -> Array:
	var small: Array = []
	for image in frames:
		var copy := (image as Image).duplicate() as Image
		copy.convert(Image.FORMAT_RGBA8)
		copy.resize(maxi(1, copy.get_width() / 2), maxi(1, copy.get_height() / 2), Image.INTERPOLATE_BILINEAR)
		small.append(_luma(copy))
	var full: Array = []
	for image in frames:
		var rgba := (image as Image).duplicate() as Image
		rgba.convert(Image.FORMAT_RGBA8)
		full.append(_luma(rgba))
	var r := maxi(2, radius / 2)
	var reach_small := maxi(2, reach / 2)
	var result: Array = []
	result.resize(frames.size())
	result[from] = point
	var template := _patch(small[from], point * 0.5, r)
	var template_full := _patch(full[from], point, radius)
	for direction in [1, -1]:
		var last: Vector2 = point
		var index: int = from + int(direction)
		while index >= 0 and index < frames.size():
			# Coarse search at half size, then a fine one around it at full size.
			var coarse := _best_match(small[index], template, last * 0.5, r, reach_small, 0.05)
			last = _best_match(full[index], template_full, coarse * 2.0, radius, 2, 0.0)
			result[index] = last
			index += int(direction)
	return result

static func _luma(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var values := PackedFloat32Array()
	values.resize(width * height)
	for i in range(width * height):
		var alpha := data[i * 4 + 3] / 255.0
		values[i] = (0.3 * data[i * 4] + 0.59 * data[i * 4 + 1] + 0.11 * data[i * 4 + 2]) * alpha + (1.0 - alpha) * 400.0
	return {"w": width, "h": height, "v": values}

static func _patch(luma: Dictionary, center: Vector2, r: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var cx := int(round(center.x))
	var cy := int(round(center.y))
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			out.append(_luma_at(luma, x, y))
	return out

static func _luma_at(luma: Dictionary, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= int(luma.w) or y >= int(luma.h):
		return 400.0
	return (luma.v as PackedFloat32Array)[y * int(luma.w) + x]

static func _best_match(luma: Dictionary, template: PackedFloat32Array, near: Vector2, r: int, reach: int, stay_weight: float = 0.05) -> Vector2:
	var best := INF
	var best_point := near
	var cx := int(round(near.x))
	var cy := int(round(near.y))
	for dy in range(-reach, reach + 1, 1):
		for dx in range(-reach, reach + 1, 1):
			var total := 0.0
			var k := 0
			for y in range(cy + dy - r, cy + dy + r + 1, 2):
				for x in range(cx + dx - r, cx + dx + r + 1, 2):
					var diff := _luma_at(luma, x, y) - template[(y - (cy + dy - r)) * (2 * r + 1) + (x - (cx + dx - r))]
					total += diff * diff
					k += 1
				if total >= best:
					break
			# Prefer staying put when two spots match equally well.
			total += (dx * dx + dy * dy) * stay_weight
			if total < best:
				best = total
				best_point = Vector2(cx + dx, cy + dy)
	return best_point

## Height of the figure (used to scale a hero clip to the in-game hero).
static func figure_height(image: Image) -> float:
	return float(Art.visible_bounds(image).size.y)

# ---------- 4. packing ----------

## Lines frames up on their anchors and packs them into one sheet.
## Returns {image, cell: [w, h], anchor: [x, y], columns, frame_count, scale}.
## `layout`: frames whose bounds decide the cells (defaults to `frames`), so a
## second sheet (like the front-hand overlay) packs exactly like the first.
static func pack(frames: Array, anchors: Array, max_cell: int = MAX_CELL, layout: Array = []) -> Dictionary:
	if frames.is_empty() or frames.size() != anchors.size():
		return {}
	var shapes: Array = layout if layout.size() == frames.size() else frames
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var crops: Array = []
	for index in range(frames.size()):
		var image: Image = shapes[index]
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

# ---------- 5. weapon in the hands: auto-place and front hand ----------

## Colours common on the hero (weapon-free frames), quantized to 16 levels per
## channel. Weapon pixels are the ones that aren't hero colours.
static func body_palette(frames: Array) -> PackedByteArray:
	var counts := PackedInt32Array()
	counts.resize(4096)
	var total := 0
	for frame in frames:
		var image: Image = frame
		var data := image.get_data()
		for pixel in range(image.get_width() * image.get_height()):
			var offset := pixel * 4
			if data[offset + 3] < 128:
				continue
			counts[(data[offset] >> 4) << 8 | (data[offset + 1] >> 4) << 4 | (data[offset + 2] >> 4)] += 1
			total += 1
	var common := PackedByteArray()
	common.resize(4096)
	var limit := maxi(3, int(total * 0.0015))
	for bin in range(4096):
		if counts[bin] >= limit:
			common[bin] = 1
	return common

static func _bin(data: PackedByteArray, offset: int) -> int:
	return (data[offset] >> 4) << 8 | (data[offset + 1] >> 4) << 4 | (data[offset + 2] >> 4)

## Height of the parts of `image` in hero colours (ignores a weapon sticking
## out above the head).
static func palette_height(image: Image, palette: PackedByteArray) -> float:
	var data := image.get_data()
	var width := image.get_width()
	var top := -1
	var bottom := -1
	for y in range(image.get_height()):
		var hits := 0
		for x in range(width):
			var offset := (y * width + x) * 4
			if data[offset + 3] >= 128 and palette[_bin(data, offset)] == 1:
				hits += 1
		if hits >= 2:
			if top < 0:
				top = y
			bottom = y
	return float(bottom - top + 1) if top >= 0 else 0.0

## Alpha > 0.5 mask of `image`, grown by `grow` pixels.
static func solid_mask(image: Image, grow: int = 0) -> PackedByteArray:
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var mask := PackedByteArray()
	mask.resize(width * height)
	for pixel in range(width * height):
		if data[pixel * 4 + 3] >= 128:
			mask[pixel] = 1
	for _step in range(grow):
		var grown := mask.duplicate()
		for y in range(height):
			for x in range(width):
				var pixel := y * width + x
				if mask[pixel] == 1:
					continue
				if (x > 0 and mask[pixel - 1] == 1) or (x < width - 1 and mask[pixel + 1] == 1) or (y > 0 and mask[pixel - width] == 1) or (y < height - 1 and mask[pixel + width] == 1):
					grown[pixel] = 1
		mask = grown
	return mask

## Nudges the reference frame (the same pose with the weapon) onto the body
## frame: the shift (body pixels, within +-`reach`) where their silhouettes
## overlap most. `offset` is the starting shift.
static func align_reference(body: Image, body_anchor: Vector2, ref: Image, ref_anchor: Vector2, ref_scale: float, offset: Vector2 = Vector2.ZERO, reach: int = 16) -> Vector2:
	var step := 3
	var body_mask := solid_mask(body)
	var bw := body.get_width()
	var bh := body.get_height()
	var points: Array = []
	var ref_data := ref.get_data()
	for y in range(0, ref.get_height(), step):
		for x in range(0, ref.get_width(), step):
			if ref_data[(y * ref.get_width() + x) * 4 + 3] >= 128:
				points.append(body_anchor + (Vector2(x, y) - ref_anchor) * ref_scale)
	var best := offset
	var best_score := -1
	for dy in range(-reach, reach + 1, 2):
		for dx in range(-reach, reach + 1, 2):
			var shift := offset + Vector2(dx, dy)
			var score := 0
			for point in points:
				var q: Vector2 = point + shift
				var qx := int(q.x)
				var qy := int(q.y)
				if qx >= 0 and qy >= 0 and qx < bw and qy < bh and body_mask[qy * bw + qx] == 1:
					score += 1
			if score > best_score:
				best_score = score
				best = shift
	return best

## Finds the weapon in the reference frame and where the body frame holds it.
## Everything is in body-frame pixels. Returns {ok, grip, tip, behind, how,
## error}. Tries the ray finder first (handles weapons drawn across the body),
## then the older contact finder.
static func find_weapon(body: Image, body_anchor: Vector2, ref: Image, ref_anchor: Vector2, ref_scale: float, offset: Vector2, palette: PackedByteArray, debug: bool = false) -> Dictionary:
	var found := find_weapon_ray(body, body_anchor, ref, ref_anchor, ref_scale, offset, debug)
	if bool(found.get("ok", false)):
		return found
	var classic := find_weapon_classic(body, body_anchor, ref, ref_anchor, ref_scale, offset, palette, debug)
	classic["how"] = "classic"
	return classic

## The ghost resampled into body-frame space on a canvas that holds both.
## Returns {body: Image, ref: Image, origin: Vector2 (body px of canvas 0,0)}.
static func _shared_canvas(body: Image, body_anchor: Vector2, ref: Image, ref_anchor: Vector2, ref_scale: float, offset: Vector2) -> Dictionary:
	var ref_size := Vector2(ref.get_size()) * ref_scale
	var ref_pos := body_anchor + offset - ref_anchor * ref_scale
	var area := Rect2(Vector2.ZERO, Vector2(body.get_size())).merge(Rect2(ref_pos, ref_size)).grow(4.0)
	var origin := area.position.floor()
	var size := Vector2i((area.end - origin).ceil())
	var body_canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rgba := body
	if body.get_format() != Image.FORMAT_RGBA8:
		rgba = body.duplicate() as Image
		rgba.convert(Image.FORMAT_RGBA8)
	body_canvas.blit_rect(rgba, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i((-origin).round()))
	var scaled := ref.duplicate() as Image
	scaled.convert(Image.FORMAT_RGBA8)
	var scaled_size := Vector2i(maxi(1, int(round(ref_size.x))), maxi(1, int(round(ref_size.y))))
	if scaled_size != scaled.get_size():
		scaled.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
	var ref_canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	ref_canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled_size), Vector2i((ref_pos - origin).round()))
	return {"body": body_canvas, "ref": ref_canvas, "origin": origin}

## Pixels of the ghost that are the weapon: outside the hero, or a colour the
## hero doesn't have anywhere near that spot (so a blade drawn across the legs
## counts, but a hand a pixel or two off doesn't). Thin slivers along the
## outline (the two drawings never match exactly) are dropped.
static func weapon_pixels(body_data: PackedByteArray, ref_data: PackedByteArray, width: int, height: int, body_distance: PackedInt32Array, erode: int = 2, threshold: float = 70.0) -> PackedByteArray:
	var raw := PackedByteArray()
	raw.resize(width * height)
	var limit := int(threshold * threshold)
	for y in range(height):
		for x in range(width):
			var pixel := y * width + x
			var o := pixel * 4
			if ref_data[o + 3] < 128:
				continue
			if body_distance[pixel] > 3:
				raw[pixel] = 1
				continue
			var r := int(ref_data[o])
			var g := int(ref_data[o + 1])
			var b := int(ref_data[o + 2])
			var matched := false
			for dy in [0, -1, 1, -2, 2]:
				var ny: int = y + dy
				if ny < 0 or ny >= height:
					continue
				for dx in [0, -1, 1, -2, 2]:
					var nx: int = x + dx
					if nx < 0 or nx >= width:
						continue
					var q: int = (ny * width + nx) * 4
					if body_data[q + 3] < 128:
						continue
					var dr: int = r - int(body_data[q])
					var dg: int = g - int(body_data[q + 1])
					var db: int = b - int(body_data[q + 2])
					if dr * dr + dg * dg + db * db <= limit:
						matched = true
						break
				if matched:
					break
			if not matched:
				raw[pixel] = 1
	if erode <= 0:
		return raw
	# Open the mask: erode by `erode` (4-connected), then grow back inside raw.
	var outside := PackedByteArray()
	outside.resize(width * height)
	for pixel in range(width * height):
		outside[pixel] = 1 - raw[pixel]
	var inward := _distance_field(outside, width, height, erode + 2)
	var core := PackedByteArray()
	core.resize(width * height)
	for pixel in range(width * height):
		if raw[pixel] == 1 and inward[pixel] > erode:
			core[pixel] = 1
	var grown := _distance_field(core, width, height, erode + 2)
	var result := PackedByteArray()
	result.resize(width * height)
	for pixel in range(width * height):
		if raw[pixel] == 1 and grown[pixel] <= erode:
			result[pixel] = 1
	return result

## Ray finder: the far end is the weapon pixel farthest from the hero; from
## there a ray runs back along the weapon. Where the weapon disappears behind
## the hands (a gap of hero pixels between two stretches of weapon) is the
## grip; otherwise the grip is just inside the hero where the weapon touches
## it. Returns {ok, grip, tip, behind, how ("gap" / "contact"), error}.
static func find_weapon_ray(body: Image, body_anchor: Vector2, ref: Image, ref_anchor: Vector2, ref_scale: float, offset: Vector2, debug: bool = false) -> Dictionary:
	var shared := _shared_canvas(body, body_anchor, ref, ref_anchor, ref_scale, offset)
	var body_canvas: Image = shared.body
	var origin: Vector2 = shared.origin
	var width := body_canvas.get_width()
	var height := body_canvas.get_height()
	var body_data := body_canvas.get_data()
	var ref_data := (shared.ref as Image).get_data()
	var body_mask := PackedByteArray()
	body_mask.resize(width * height)
	for pixel in range(width * height):
		if body_data[pixel * 4 + 3] >= 128:
			body_mask[pixel] = 1
	var figure := float(Art.visible_bounds(body).size.y)
	if figure < 8.0:
		return {"ok": false, "error": "empty frame"}
	var fist := maxf(8.0, figure * 0.07)
	var body_distance := _distance_field(body_mask, width, height, int(figure * 2.0))
	var erode := clampi(int(round(figure * 0.008)), 1, 2)
	var weapon := weapon_pixels(body_data, ref_data, width, height, body_distance, erode)
	var pieces := _components(weapon, width, height, true)
	if pieces.is_empty():
		return {"ok": false, "error": "no weapon found"}
	var largest := 0
	for piece in pieces:
		largest = maxi(largest, int(piece.size))
	if largest < 40:
		return {"ok": false, "error": "weapon too small to find"}
	var keep_size := maxi(30, int(largest * 0.08))
	var mask := PackedByteArray()
	mask.resize(width * height)
	var pixels := PackedInt32Array()
	for piece in pieces:
		if int(piece.size) >= keep_size:
			for pixel in piece.pixels:
				mask[pixel] = 1
			pixels.append_array(piece.pixels)
	# Far end: the weapon pixel farthest from the hero.
	var tip := Vector2.ZERO
	var farthest := -1
	for pixel in pixels:
		if body_distance[pixel] > farthest:
			farthest = body_distance[pixel]
			tip = Vector2(pixel % width, pixel / width)
	# Direction back along the weapon: the ray from the tip through the most
	# weapon pixels (a sample of them), refined by their principal axis.
	var band := maxf(3.0, figure * 0.035)
	var samples: Array = []
	var stride := maxi(1, pixels.size() / 1500)
	for index in range(0, pixels.size(), stride):
		samples.append(Vector2(pixels[index] % width, pixels[index] / width) - tip)
	var best_count := -1
	var direction := Vector2.LEFT
	for step_angle in range(0, 360, 3):
		var d := Vector2.from_angle(deg_to_rad(step_angle))
		var normal := Vector2(-d.y, d.x)
		var count := 0
		for point in samples:
			var p: Vector2 = point
			if p.dot(d) > 0.0 and absf(p.dot(normal)) < band:
				count += 1
		if count > best_count:
			best_count = count
			direction = d
	var in_band: Array = []
	var normal0 := Vector2(-direction.y, direction.x)
	for point in samples:
		var p: Vector2 = point
		if p.dot(direction) > 0.0 and absf(p.dot(normal0)) < band:
			in_band.append(p)
	if in_band.size() >= 10:
		var center := Vector2.ZERO
		for p in in_band:
			center += p
		center /= float(in_band.size())
		var xx := 0.0
		var xy := 0.0
		var yy := 0.0
		for p in in_band:
			var q: Vector2 = p - center
			xx += q.x * q.x
			xy += q.x * q.y
			yy += q.y * q.y
		var axis := Vector2.from_angle(0.5 * atan2(2.0 * xy, xx - yy))
		direction = axis if axis.dot(direction) > 0.0 else -axis
	var side := Vector2(-direction.y, direction.x)
	# Walk the ray: W = weapon, b = hero, . = neither.
	var walk: PackedByteArray = PackedByteArray()
	var reach := int(figure * 1.2)
	for k in range(reach):
		var point := tip + direction * k
		var kind := 0
		for across in [0.0, -2.0, 2.0]:
			if _solid_at(mask, width, height, point + side * across):
				kind = 2
				break
		if kind == 0 and _solid_at(body_mask, width, height, point):
			kind = 1
		walk.append(kind)
	var runs: Array = []
	for k in range(walk.size()):
		if not runs.is_empty() and int(runs[-1][0]) == walk[k]:
			runs[-1][2] = k + 1
		else:
			runs.append([walk[k], k, k + 1])
	var weapon_runs: Array = runs.filter(func(r: Array) -> bool: return int(r[0]) == 2 and int(r[2]) - int(r[1]) >= 2)
	var grip := Vector2.INF
	var how := ""
	for index in range(weapon_runs.size() - 1):
		var gap_start: int = weapon_runs[index][2]
		var gap_end: int = weapon_runs[index + 1][1]
		var gap := gap_end - gap_start
		if gap < fist * 0.4 or gap > fist * 4.0:
			continue
		var on_body := 0
		for k in range(gap_start, gap_end):
			if walk[k] == 1:
				on_body += 1
		if float(on_body) / float(gap) >= 0.6:
			grip = tip + direction * (gap_start + gap_end) * 0.5
			how = "gap"
			break
	if grip == Vector2.INF:
		# Where the weapon touches the hero, just inside the hero.
		var contact := Vector2.ZERO
		var contacts := 0
		var weapon_center := Vector2.ZERO
		for pixel in pixels:
			var point := Vector2(pixel % width, pixel / width)
			weapon_center += point
			if body_distance[pixel] > 0 and body_distance[pixel] <= 3:
				contact += point
				contacts += 1
		weapon_center /= float(pixels.size())
		if contacts < 3:
			return {"ok": false, "error": "the weapon doesn't touch the hero"}
		contact /= float(contacts)
		var entry := _nearest_solid(body_mask, width, height, contact, int(fist * 3.0))
		if entry == Vector2.INF:
			return {"ok": false, "error": "no hand near the weapon"}
		var inward := (entry - weapon_center).normalized()
		var depth := 0.0
		while depth < fist * 1.6 and _solid_at(body_mask, width, height, entry + inward * (depth + 1.0)):
			depth += 1.0
		grip = entry + inward * depth * 0.5
		how = "contact"
	# The far end the game uses: the weapon pixel farthest from the grip, on
	# the tip's side of the hand.
	var toward := (tip - grip).normalized()
	var far := -1.0
	var far_point := tip
	for pixel in pixels:
		var point := Vector2(pixel % width, pixel / width)
		var v := point - grip
		var d2 := v.length_squared()
		if d2 > far and v.normalized().dot(toward) > 0.7:
			far = d2
			far_point = point
	tip = far_point
	var along := (tip - grip).normalized()
	var length := grip.distance_to(tip)
	if length < fist * 1.5:
		return {"ok": false, "error": "weapon too short"}
	# Behind the body: past the hand the weapon line crosses the hero, but the
	# ghost shows the hero (not the weapon) there.
	var crossing := 0
	var seen := 0
	var t := fist * 1.5
	while t < length:
		var probe := grip + along * t
		if _solid_at(body_mask, width, height, probe):
			crossing += 1
			if _solid_at(mask, width, height, probe):
				seen += 1
		t += 1.0
	var behind := crossing >= 8 and float(seen) / float(crossing) < 0.35
	var result := {"ok": true, "grip": (grip + origin).round(), "tip": (tip + origin).round(), "behind": behind, "how": how, "error": ""}
	if debug:
		var debug_weapon: Array = []
		for pixel in pixels:
			debug_weapon.append(Vector2(pixel % width, pixel / width) + origin)
		result["weapon_px"] = debug_weapon
	return result

## Frame where the weapon lands: the one right after the biggest forward
## sweep of the weapon's far end (relative to the feet). -1 without a track.
## `track` entries are {grip, tip} in frame pixels, `anchors` the feet.
static func guess_hit(track: Array, anchors: Array) -> int:
	var best := -1
	var best_score := 0.0
	for index in range(1, mini(track.size(), anchors.size())):
		var before: Dictionary = track[index - 1]
		var after: Dictionary = track[index]
		if not (before.get("tip") is Vector2 and after.get("tip") is Vector2):
			continue
		var move: Vector2 = (Vector2(after.tip) - Vector2(anchors[index])) - (Vector2(before.tip) - Vector2(anchors[index - 1]))
		# Hero art faces right: strikes sweep forward (or down); wind-ups go back.
		var score := move.length() * (1.0 if move.x > 0.0 or move.y > absf(move.x) else 0.35)
		if score > best_score:
			best_score = score
			best = index
	return best

## Frame holds that give a swing weight: a held wind-up, a fast swing, a held
## impact and a short settle. `hit` is the impact frame. Returns ms per frame.
static func snappy_holds(track: Array, anchors: Array, hit: int, base_ms: float = 83.0) -> Array:
	var count := mini(track.size(), anchors.size())
	var holds: Array = []
	for _i in range(count):
		holds.append(base_ms)
	if hit < 0 or hit >= count:
		return holds
	# Wind-up: before the hit, the frame whose far end is farthest from where
	# it lands.
	var windup := -1
	var farthest := -1.0
	var landing: Variant = track[hit].get("tip")
	if landing is Vector2:
		for index in range(hit):
			var tip: Variant = track[index].get("tip")
			if tip is Vector2:
				var d := (Vector2(tip) - Vector2(anchors[index])).distance_to(Vector2(landing) - Vector2(anchors[hit]))
				if d > farthest:
					farthest = d
					windup = index
	for index in range(count):
		var factor := 1.0
		if index == hit:
			factor = 1.6
		elif index == windup:
			factor = 1.5
		elif windup >= 0 and index > windup and index < hit:
			factor = 0.7
		elif index == count - 1 and index > hit:
			factor = 1.2
		holds[index] = roundf(base_ms * factor)
	return holds

## The solid pixel nearest `point` within `radius` (Vector2.INF if none).
static func _nearest_solid(mask: PackedByteArray, width: int, height: int, point: Vector2, radius: int) -> Vector2:
	var cx := int(round(point.x))
	var cy := int(round(point.y))
	var best := Vector2.INF
	var best_d := INF
	for dy in range(-radius, radius + 1):
		var y := cy + dy
		if y < 0 or y >= height:
			continue
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			if x < 0 or x >= width or mask[y * width + x] == 0:
				continue
			var d := float(dx * dx + dy * dy)
			if d < best_d:
				best_d = d
				best = Vector2(x, y)
	return best

## The older finder: grows the clearest weapon piece through pixels outside the
## hero and puts the grip where it touches the hero.
static func find_weapon_classic(body: Image, body_anchor: Vector2, ref: Image, ref_anchor: Vector2, ref_scale: float, offset: Vector2, palette: PackedByteArray, debug: bool = false) -> Dictionary:
	var bw := body.get_width()
	var bh := body.get_height()
	var body_data := body.get_data()
	var near_body := solid_mask(body, 3)
	var body_mask := solid_mask(body)
	var rw := ref.get_width()
	var rh := ref.get_height()
	var ref_data := ref.get_data()
	var candidate := PackedByteArray()
	candidate.resize(rw * rh)
	var loose := PackedByteArray()
	loose.resize(rw * rh)
	var to_body := func(x: float, y: float) -> Vector2:
		return body_anchor + offset + (Vector2(x, y) - ref_anchor) * ref_scale
	# candidate: clearly weapon (not a hero colour, and outside the hero or
	# different from it). loose: anything outside the hero's silhouette, which
	# also catches handles in hero-like colours.
	for y in range(rh):
		for x in range(rw):
			var offset_ref := (y * rw + x) * 4
			if ref_data[offset_ref + 3] < 128:
				continue
			var q: Vector2 = to_body.call(x + 0.5, y + 0.5)
			var qx := int(q.x)
			var qy := int(q.y)
			var inside := qx >= 0 and qy >= 0 and qx < bw and qy < bh
			var outside := not inside or near_body[qy * bw + qx] == 0
			if outside:
				loose[y * rw + x] = 1
			if palette[_bin(ref_data, offset_ref)] == 1:
				continue
			if outside:
				candidate[y * rw + x] = 1
				continue
			if body_mask[qy * bw + qx] == 1:
				var offset_body := (qy * bw + qx) * 4
				var dr := int(ref_data[offset_ref]) - int(body_data[offset_body])
				var dg := int(ref_data[offset_ref + 1]) - int(body_data[offset_body + 1])
				var db := int(ref_data[offset_ref + 2]) - int(body_data[offset_body + 2])
				if dr * dr + dg * dg + db * db > 90 * 90:
					candidate[y * rw + x] = 1
	var pieces := _components(candidate, rw, rh, true)
	if pieces.is_empty():
		return {"ok": false, "error": "no weapon found"}
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.size) > int(b.size))
	var main: Dictionary = pieces[0]
	if int(main.size) < 60:
		return {"ok": false, "error": "weapon too small to find"}
	# Grow the clearest piece (head or blade) through connected pixels outside
	# the hero, which picks up the handle.
	var weapon := PackedByteArray()
	weapon.resize(rw * rh)
	var queue: PackedInt32Array = main.pixels.duplicate()
	for pixel in queue:
		weapon[pixel] = 1
	var head := 0
	while head < queue.size():
		var pixel := queue[head]
		head += 1
		var x := pixel % rw
		var y := pixel / rw
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or ny < 0 or nx >= rw or ny >= rh:
					continue
				var neighbor := ny * rw + nx
				if weapon[neighbor] == 0 and (loose[neighbor] == 1 or candidate[neighbor] == 1):
					weapon[neighbor] = 1
					queue.append(neighbor)
	var all_pixels: PackedInt32Array = queue
	for pixel in all_pixels:
		candidate[pixel] = 1
	# The far end is the weapon pixel farthest from the hero; the grip end is
	# the weapon pixel touching the hero that is farthest from the far end.
	var figure := float(Art.visible_bounds(body).size.y)
	var fist := maxf(8.0, figure * 0.07)
	var distance := _distance_field(body_mask, bw, bh, int(figure))
	var tip := Vector2.ZERO
	var best := -1.0
	var points: Array = []
	var gaps: Array = []
	for pixel in all_pixels:
		var point: Vector2 = to_body.call(pixel % rw + 0.5, pixel / rw + 0.5)
		var gap := _distance_at(distance, bw, bh, point, figure)
		points.append(point)
		gaps.append(gap)
		if gap > best:
			best = gap
			tip = point
	var grip_end := Vector2.ZERO
	best = -1.0
	var nearest := INF
	var nearest_point := Vector2.ZERO
	for index in range(points.size()):
		var gap: float = gaps[index]
		var point: Vector2 = points[index]
		if gap < nearest:
			nearest = gap
			nearest_point = point
		if gap <= fist * 0.5:
			var d := point.distance_to(tip)
			if d > best:
				best = d
				grip_end = point
	if best < 0.0:
		grip_end = nearest_point
	var along := (tip - grip_end).normalized()
	var grip := grip_end
	var t: float = 0.0
	# A fist is a bit wider than the reach used to find the grip end.
	fist *= 1.6
	if _solid_at(body_mask, bw, bh, grip_end):
		# Walk outward through the fist.
		while t < fist and _solid_at(body_mask, bw, bh, grip_end - along * (t + 1.0)):
			t += 1.0
		grip = grip_end - along * t * 0.5
	else:
		# The visible handle stops short of the hero: step in to the fist.
		var found := false
		while t < fist * 1.5:
			if _solid_at(body_mask, bw, bh, grip_end - along * t):
				found = true
				break
			t += 1.0
		if found:
			var start := t
			while t < start + fist and _solid_at(body_mask, bw, bh, grip_end - along * (t + 1.0)):
				t += 1.0
			grip = grip_end - along * (start + t) * 0.5
	# The far end is the weapon pixel farthest from the grip (the same rule
	# the game uses on each weapon's own picture).
	var far := -1.0
	for pixel in all_pixels:
		var point: Vector2 = to_body.call(pixel % rw + 0.5, pixel / rw + 0.5)
		var d := point.distance_squared_to(grip)
		if d > far:
			far = d
			tip = point
	along = (tip - grip).normalized()
	# Behind the body: the weapon line crosses the hero past the hand, but the
	# reference shows the hero (not the weapon) there.
	var crossing := 0
	var weapon_seen := 0
	var length := grip.distance_to(tip)
	t = fist * 1.5
	while t < length:
		var probe := grip + along * t
		if _solid_at(body_mask, bw, bh, probe):
			crossing += 1
			var r: Vector2 = ref_anchor + (probe - body_anchor - offset) / ref_scale
			var rx := int(r.x)
			var ry := int(r.y)
			if rx >= 0 and ry >= 0 and rx < rw and ry < rh and candidate[ry * rw + rx] == 1:
				weapon_seen += 1
		t += 1.0
	var behind := crossing >= 8 and float(weapon_seen) / float(crossing) < 0.35
	var debug_weapon: Array = []
	var debug_main: Array = []
	if debug:
		for pixel in all_pixels:
			debug_weapon.append(to_body.call(pixel % rw + 0.5, pixel / rw + 0.5))
		for pixel in main.pixels:
			debug_main.append(to_body.call(pixel % rw + 0.5, pixel / rw + 0.5))
	return {"ok": true, "grip": grip.round(), "tip": tip.round(), "behind": behind, "error": "", "weapon_px": debug_weapon, "main_px": debug_main}

## Distance (pixels, capped at `cap`) from every pixel to the nearest solid one.
static func _distance_field(mask: PackedByteArray, width: int, height: int, cap: int) -> PackedInt32Array:
	var field := PackedInt32Array()
	field.resize(width * height)
	field.fill(cap)
	var queue := PackedInt32Array()
	for pixel in range(width * height):
		if mask[pixel] == 1:
			field[pixel] = 0
			queue.append(pixel)
	var head := 0
	while head < queue.size():
		var pixel := queue[head]
		head += 1
		var next := field[pixel] + 1
		if next >= cap:
			continue
		var x := pixel % width
		var y := pixel / width
		for n in [pixel - 1 if x > 0 else -1, pixel + 1 if x < width - 1 else -1, pixel - width if y > 0 else -1, pixel + width if y < height - 1 else -1]:
			if int(n) >= 0 and field[int(n)] > next:
				field[int(n)] = next
				queue.append(int(n))
	return field

## Distance to the hero at a body-frame point (outside the frame: past the edge).
static func _distance_at(field: PackedInt32Array, width: int, height: int, point: Vector2, cap: float) -> float:
	var x := clampi(int(point.x), 0, width - 1)
	var y := clampi(int(point.y), 0, height - 1)
	var outside := maxf(maxf(-point.x, point.x - width), maxf(-point.y, point.y - height))
	return minf(cap, float(field[y * width + x]) + maxf(0.0, outside))

static func _solid_at(mask: PackedByteArray, width: int, height: int, point: Vector2) -> bool:
	var x := int(point.x)
	var y := int(point.y)
	return x >= 0 and y >= 0 and x < width and y < height and mask[y * width + x] == 1

static func _coverage(mask: PackedByteArray, width: int, height: int, center: Vector2, radius: float) -> int:
	var count := 0
	var r := int(radius)
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if dx * dx + dy * dy <= r * r and _solid_at(mask, width, height, center + Vector2(dx, dy)):
				count += 1
	return count

static func _centroid(pixels: PackedInt32Array, width: int) -> Vector2:
	var sum := Vector2.ZERO
	for pixel in pixels:
		sum += Vector2(pixel % width + 0.5, pixel / width + 0.5)
	return sum / maxf(1.0, float(pixels.size()))

## {center, direction, normal, width} of a pixel set (principal component).
static func _principal_axis(pixels: PackedInt32Array, width: int) -> Dictionary:
	var center := _centroid(pixels, width)
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for pixel in pixels:
		var d := Vector2(pixel % width + 0.5, pixel / width + 0.5) - center
		xx += d.x * d.x
		xy += d.x * d.y
		yy += d.y * d.y
	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	var direction := Vector2.from_angle(angle)
	var normal := Vector2(-direction.y, direction.x)
	var spread := 0.0
	for pixel in pixels:
		spread += absf((Vector2(pixel % width + 0.5, pixel / width + 0.5) - center).dot(normal))
	return {"center": center, "direction": direction, "normal": normal, "width": spread / maxf(1.0, float(pixels.size()))}

## The hand holding the weapon: hero pixels around the grip, connected to it.
## Returns an L8 mask the size of `body` (255 = draw over the weapon).
static func hand_mask(body: Image, grip: Vector2, radius: float = 0.0) -> Image:
	var width := body.get_width()
	var height := body.get_height()
	# Only pixels within `r` of the grip are ever visited, so read alpha
	# straight from the frame instead of building a whole-frame solid mask.
	var rgba := body
	if body.get_format() != Image.FORMAT_RGBA8:
		rgba = body.duplicate() as Image
		rgba.convert(Image.FORMAT_RGBA8)
	var body_data := rgba.get_data()
	var r := radius if radius > 0.0 else maxf(8.0, _visible_height(body) * 0.07)
	var mask := Image.create_empty(width, height, false, Image.FORMAT_L8)
	var start := Vector2i(grip.round())
	# Start from the nearest solid pixel to the grip.
	var best := -1
	var best_distance := INF
	var rr := int(r)
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var x := start.x + dx
			var y := start.y + dy
			if x >= 0 and y >= 0 and x < width and y < height and body_data[(y * width + x) * 4 + 3] >= 128:
				var d := float(dx * dx + dy * dy)
				if d < best_distance:
					best_distance = d
					best = y * width + x
	if best < 0:
		return mask
	var seen := PackedByteArray()
	seen.resize(width * height)
	var queue := PackedInt32Array([best])
	seen[best] = 1
	var head := 0
	var data := mask.get_data()
	while head < queue.size():
		var pixel := queue[head]
		head += 1
		data[pixel] = 255
		var x := pixel % width
		var y := pixel / width
		for n in NEIGHBORS_4:
			var nx: int = x + n.x
			var ny: int = y + n.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var neighbor := ny * width + nx
			if seen[neighbor] == 1 or body_data[neighbor * 4 + 3] < 128:
				continue
			if Vector2(nx, ny).distance_to(grip) > r:
				continue
			seen[neighbor] = 1
			queue.append(neighbor)
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, data)

const NEIGHBORS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Visible height of a frame, measured once per frame image (kept as metadata).
static func _visible_height(body: Image) -> float:
	if body.has_meta("visible_height"):
		return float(body.get_meta("visible_height"))
	var height := float(Art.visible_bounds(body).size.y)
	body.set_meta("visible_height", height)
	return height

## Redoes `masked` for just `rect` of an existing masked picture (after a
## brush stroke), instead of the whole frame.
static func remask_region(picture: Image, body: Image, mask: Image, rect: Rect2i) -> void:
	var area := rect.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if mask.get_pixel(x, y).r >= 0.5:
				picture.set_pixel(x, y, body.get_pixel(x, y))
			else:
				var color := body.get_pixel(x, y)
				color.a = 0.0
				picture.set_pixel(x, y, color)

## `body` with only the pixels under `mask` (the hand drawn over the weapon).
static func masked(body: Image, mask: Image) -> Image:
	var result := body.duplicate() as Image
	result.convert(Image.FORMAT_RGBA8)
	var data := result.get_data()
	var mask_data := mask.get_data()
	for pixel in range(result.get_width() * result.get_height()):
		if mask_data[pixel] < 128:
			data[pixel * 4 + 3] = 0
	return Image.create_from_data(result.get_width(), result.get_height(), false, Image.FORMAT_RGBA8, data)

## Paints (value 255) or erases (0) a circle in an L8 mask.
static func paint_mask(mask: Image, center: Vector2, radius: float, value: int) -> void:
	var r := int(ceil(radius))
	for y in range(int(center.y) - r, int(center.y) + r + 1):
		if y < 0 or y >= mask.get_height():
			continue
		for x in range(int(center.x) - r, int(center.x) + r + 1):
			if x < 0 or x >= mask.get_width():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				mask.set_pixel(x, y, Color8(value, value, value))

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
