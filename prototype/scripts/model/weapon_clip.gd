class_name WeaponClip
extends RefCounted

## A hand-drawn or generated attack animation attached to a weapon, stored on
## a published revision as "attack_clip". Frames are packed left to right, top
## to bottom in one sheet; every frame is already aligned so the anchor point
## sits at the same pixel in each cell.
##
## Modes:
##   hero    the frames show the whole hero swinging the weapon. While a clip
##           attack plays it replaces the hero's attack animation and the
##           separate held weapon is hidden. anchor = the ground point under
##           the hero's feet.
##   weapon  the frames show only the weapon. They replace the held weapon's
##           picture during the attack. anchor = the grip.
##
## Attacks: one clip can hold a combo. Each attack is a frame range with a hit
## frame; the hero alternates through them attack after attack and starts over
## after a pause. With fit_hit on, each attack is sped up or slowed down so its
## hit frame appears exactly when the game deals melee damage.
##
## Fields:
##   label, mode, sheet (res://, published) / source (absolute path, drafts),
##   frame_count, columns, cell [w, h], anchor [x, y] (pixels in a cell),
##   body_height (hero mode: hero height in the frames, px; used to scale the
##   clip to the hero's in-game height), scale (fine-tune multiplier),
##   frame_ms (hold time of every frame), attacks [{start, end, hit}] (0-based,
##   inclusive), fit_hit, project (absolute path of the importer project, drafts).

const MODES := ["hero", "hero_weapon", "weapon"]
const MODE_LABELS := {"hero": "Hero attack (whole hero + weapon)", "hero_weapon": "Hero body + each weapon's own art", "weapon": "Weapon frames (weapon only)"}
## hero_weapon: the frames show the hero without a weapon, and `track` says
## where the weapon sits in each frame: [{grip: [x, y], angle: degrees
## (grip -> far end, screen space), length: px, behind: bool}] in cell pixels.
## The game draws each weapon's own picture there, so one animation serves
## every weapon of a type. `hand_fit` ({angle, scale}) on a weapon's revision
## fine-tunes how its picture sits in the hands.
const DEFAULT_HAND_FIT := {"angle": 0.0, "scale": 1.0, "flip": false}
const MAX_FRAMES := 64
const MAX_ATTACKS := 4
const DEFAULT_FRAME_MS := 83.0
const MIN_FIT := 0.25
const MAX_FIT := 4.0

const DEFAULT := {
	"label": "Attack clip",
	"mode": "hero",
	"frame_count": 1,
	"columns": 1,
	"cell": [1.0, 1.0],
	"anchor": [0.0, 0.0],
	"body_height": 0.0,
	"scale": 1.0,
	"frame_ms": [],
	"attacks": [],
	"fit_hit": true,
}

static func is_set(clip: Variant) -> bool:
	return clip is Dictionary and not clip.is_empty() and int(clip.get("frame_count", 0)) > 0 and not sheet_path(clip).is_empty()

## Fills missing values and clamps everything into range. Keeps extra keys
## (source, sheet, project).
static func normalize(clip: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if clip is Dictionary:
		for key in clip:
			result[key] = clip[key].duplicate(true) if (clip[key] is Array or clip[key] is Dictionary) else clip[key]
	if not MODES.has(str(result.mode)):
		result["mode"] = "hero"
	var count := clampi(int(_num(result.frame_count, 1.0)), 1, MAX_FRAMES)
	result["frame_count"] = count
	result["columns"] = clampi(int(_num(result.columns, count)), 1, count)
	result["cell"] = _pair(result.cell, Vector2(1, 1), 1.0, 4096.0)
	result["anchor"] = _pair(result.anchor, Vector2.ZERO, -4096.0, 8192.0)
	result["body_height"] = clampf(_num(result.body_height, 0.0), 0.0, 8192.0)
	result["scale"] = clampf(_num(result.scale, 1.0), 0.1, 8.0)
	result["fit_hit"] = bool(result.get("fit_hit", true))
	result["label"] = str(result.get("label", "Attack clip")).left(40)
	var holds: Array = []
	var raw_holds: Variant = result.get("frame_ms", [])
	for index in range(count):
		var value: float = DEFAULT_FRAME_MS
		if raw_holds is Array and index < raw_holds.size():
			value = _num(raw_holds[index], DEFAULT_FRAME_MS)
		holds.append(clampf(value, 16.0, 2000.0))
	result["frame_ms"] = holds
	result["attacks"] = attack_ranges(result)
	if str(result.mode) == "hero_weapon":
		result["track"] = normalize_track(result.get("track", []), count)
	else:
		result.erase("track")
	return result

## The clip's attacks as [{start, end, hit}], clamped to its frames. A clip
## with none plays all frames as one attack with the hit in the middle.
static func attack_ranges(clip: Dictionary) -> Array:
	var count := clampi(int(_num(clip.get("frame_count", 1), 1.0)), 1, MAX_FRAMES)
	var result: Array = []
	var raw: Variant = clip.get("attacks", [])
	if raw is Array:
		for entry in raw:
			if not entry is Dictionary or result.size() >= MAX_ATTACKS:
				continue
			var start := clampi(int(_num(entry.get("start", 0), 0.0)), 0, count - 1)
			var end := clampi(int(_num(entry.get("end", count - 1), count - 1)), start, count - 1)
			var hit := clampi(int(_num(entry.get("hit", start), start)), start, end)
			result.append({"start": start, "end": end, "hit": hit})
	if result.is_empty():
		result.append({"start": 0, "end": count - 1, "hit": (count - 1) / 2})
	return result

## Builds attacks from per-frame marks: `starts` are frames that begin a new
## attack (frame 0 always does), `hits` are hit frames.
static func attacks_from_marks(frame_count: int, starts: Array, hits: Array) -> Array:
	var begins: Array = [0]
	for value in starts:
		var frame := int(value)
		if frame > 0 and frame < frame_count and not begins.has(frame):
			begins.append(frame)
	begins.sort()
	var result: Array = []
	for index in range(mini(begins.size(), MAX_ATTACKS)):
		var start: int = begins[index]
		var end: int = (int(begins[index + 1]) - 1) if index + 1 < begins.size() else frame_count - 1
		if index == MAX_ATTACKS - 1:
			end = frame_count - 1
		var hit := -1
		for value in hits:
			if int(value) >= start and int(value) <= end:
				hit = int(value)
				break
		if hit < 0:
			hit = start + (end - start) / 2
		result.append({"start": start, "end": end, "hit": hit})
	return result

static func validate(clip: Variant) -> Dictionary:
	if not clip is Dictionary:
		return {"valid": false, "error": "attack_clip must be an object"}
	if clip.is_empty():
		return {"valid": true}
	var sheet := str(clip.get("sheet", ""))
	if not sheet.begins_with("res://") or sheet.contains("..") or sheet.contains("\\"):
		return {"valid": false, "error": "attack_clip sheet must be a repository-local res:// path"}
	if not MODES.has(str(clip.get("mode", ""))):
		return {"valid": false, "error": "attack_clip mode must be hero or weapon"}
	var count: Variant = clip.get("frame_count")
	if not _is_number(count) or int(count) < 1 or int(count) > MAX_FRAMES:
		return {"valid": false, "error": "attack_clip frame_count must be 1-%d" % MAX_FRAMES}
	for key in ["cell", "anchor"]:
		var pair: Variant = clip.get(key)
		if not pair is Array or pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
			return {"valid": false, "error": "attack_clip %s must be [x, y]" % key}
	var holds: Variant = clip.get("frame_ms", [])
	if not holds is Array or holds.size() != int(count):
		return {"valid": false, "error": "attack_clip needs one frame_ms entry per frame"}
	for value in holds:
		if not _is_number(value) or float(value) < 16.0 or float(value) > 2000.0:
			return {"valid": false, "error": "attack_clip frame_ms values must be 16-2000"}
	if clip.has("hand_sheet"):
		var hand := str(clip.hand_sheet)
		if not hand.begins_with("res://") or hand.contains("..") or hand.contains("\\"):
			return {"valid": false, "error": "attack_clip hand_sheet must be a repository-local res:// path"}
	if str(clip.get("mode", "")) == "hero_weapon":
		var track: Variant = clip.get("track")
		if not track is Array or track.size() != int(count):
			return {"valid": false, "error": "attack_clip needs a weapon position for every frame"}
		for entry in track:
			if not entry is Dictionary or not _is_number(entry.get("angle")) or not _is_number(entry.get("length")) or float(entry.length) <= 0.0:
				return {"valid": false, "error": "attack_clip weapon positions need an angle and a length"}
			var grip: Variant = entry.get("grip")
			if not grip is Array or grip.size() != 2 or not _is_number(grip[0]) or not _is_number(grip[1]):
				return {"valid": false, "error": "attack_clip weapon positions need a grip [x, y]"}
	var attacks: Variant = clip.get("attacks", [])
	if not attacks is Array or attacks.size() > MAX_ATTACKS:
		return {"valid": false, "error": "attack_clip allows up to %d attacks" % MAX_ATTACKS}
	for entry in attacks:
		if not entry is Dictionary:
			return {"valid": false, "error": "attack_clip attacks must be objects"}
		var start := int(entry.get("start", -1))
		var end := int(entry.get("end", -1))
		var hit := int(entry.get("hit", -1))
		if start < 0 or end >= int(count) or start > end or hit < start or hit > end:
			return {"valid": false, "error": "attack_clip attack frames are out of range"}
	return {"valid": true}

## When each frame of `attack_index` starts. `hit_seconds` is when the game
## deals damage (0 for ranged). Returns {frames, starts, length, fit, hit_time}.
static func timeline(clip: Dictionary, attack_index: int, hit_seconds: float) -> Dictionary:
	var ranges := attack_ranges(clip)
	var attack: Dictionary = ranges[posmod(attack_index, ranges.size())]
	var holds: Array = clip.get("frame_ms", [])
	var pre := 0.0
	for frame in range(int(attack.start), int(attack.hit)):
		pre += _hold(holds, frame)
	var fit := 1.0
	if bool(clip.get("fit_hit", true)) and hit_seconds > 0.0 and pre > 0.0:
		fit = clampf(hit_seconds / pre, MIN_FIT, MAX_FIT)
	var frames: Array = []
	var starts: Array = []
	var time := 0.0
	var hit_time := 0.0
	for frame in range(int(attack.start), int(attack.end) + 1):
		if frame == int(attack.hit):
			hit_time = time
		frames.append(frame)
		starts.append(time)
		# Only the lead-up is stretched or squeezed; from the hit on, frames
		# play at their own pace so the follow-through keeps its snap.
		time += _hold(holds, frame) * (fit if frame < int(attack.hit) else 1.0)
	return {"frames": frames, "starts": starts, "length": time, "fit": fit, "hit_time": hit_time, "attack": attack}

## The frame showing `time` seconds into a timeline, or -1 once it has ended.
static func frame_at(line: Dictionary, time: float) -> int:
	if time >= float(line.get("length", 0.0)) or time < 0.0:
		return -1
	var starts: Array = line.starts
	var frames: Array = line.frames
	var result: int = frames[0]
	for index in range(starts.size()):
		if float(starts[index]) <= time + 0.000001:
			result = frames[index]
	return result

## Looping animations (a weapon's idle or walk): the frame showing `time`
## seconds in, cycling through every frame at its own hold.
static func loop_length(clip: Dictionary) -> float:
	var holds: Array = clip.get("frame_ms", [])
	var total := 0.0
	for frame in range(maxi(1, int(clip.get("frame_count", 1)))):
		total += _hold(holds, frame)
	return maxf(0.016, total)

static func loop_frame_at(clip: Dictionary, time: float) -> int:
	var holds: Array = clip.get("frame_ms", [])
	var count := maxi(1, int(clip.get("frame_count", 1)))
	var t := fposmod(time, loop_length(clip))
	for frame in range(count):
		t -= _hold(holds, frame)
		if t < 0.0:
			return frame
	return count - 1

static func frame_rect(clip: Dictionary, frame: int) -> Rect2:
	var cell: Array = clip.get("cell", [1.0, 1.0])
	var columns := maxi(1, int(clip.get("columns", 1)))
	var index := clampi(frame, 0, maxi(0, int(clip.get("frame_count", 1)) - 1))
	return Rect2(Vector2(index % columns * float(cell[0]), index / columns * float(cell[1])), Vector2(float(cell[0]), float(cell[1])))

## The front-hand overlay (the gripping hand, drawn over the weapon), packed
## exactly like the main sheet. "" if the clip has none.
static func hand_path(clip: Variant) -> String:
	if not clip is Dictionary:
		return ""
	var source := str(clip.get("hand_source", ""))
	return source if not source.is_empty() else str(clip.get("hand_sheet", ""))

static func load_hand(clip: Variant) -> Texture2D:
	var path := hand_path(clip)
	if path.is_empty():
		return null
	return load_sheet({"source": path})

static func sheet_path(clip: Variant) -> String:
	if not clip is Dictionary:
		return ""
	var source := str(clip.get("source", ""))
	return source if not source.is_empty() else str(clip.get("sheet", ""))

## Loads the clip's sheet from a res:// or absolute path (works before Godot
## has imported a freshly written file).
static func load_sheet(clip: Variant) -> Texture2D:
	var path := sheet_path(clip)
	if path.is_empty():
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var file_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(file_path):
		return null
	var image := Image.load_from_file(file_path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null

## Game pixels per clip pixel for hero mode, given the hero's in-game height.
static func hero_scale(clip: Dictionary, hero_visible_height: float) -> float:
	var cell: Array = clip.get("cell", [1.0, 1.0])
	var body := float(clip.get("body_height", 0.0))
	if body <= 0.0:
		body = float(cell[1])
	return hero_visible_height / maxf(1.0, body) * float(clip.get("scale", 1.0))

## Human-readable timing for one attack, e.g. "frames 1-5, hit on 4 at 0.40 s (x1.20)".
static func describe_attack(clip: Dictionary, attack_index: int, hit_seconds: float) -> String:
	var line := timeline(clip, attack_index, hit_seconds)
	var attack: Dictionary = line.attack
	var text := "frames %d-%d, hit on %d at %.2f s, ends %.2f s" % [int(attack.start) + 1, int(attack.end) + 1, int(attack.hit) + 1, float(line.hit_time), float(line.length)]
	if not is_equal_approx(float(line.fit), 1.0):
		text += " (lead-up played at x%.2f speed)" % (1.0 / float(line.fit))
	return text

static func _hold(holds: Array, frame: int) -> float:
	if frame >= 0 and frame < holds.size() and _is_number(holds[frame]):
		return float(holds[frame]) / 1000.0
	return DEFAULT_FRAME_MS / 1000.0

static func _pair(value: Variant, fallback: Vector2, low: float, high: float) -> Array:
	if value is Array and value.size() == 2 and _is_number(value[0]) and _is_number(value[1]):
		return [clampf(float(value[0]), low, high), clampf(float(value[1]), low, high)]
	return [fallback.x, fallback.y]

static func _num(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback

static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

# ---------- weapon in the hands (hero_weapon) ----------

## One entry per frame; frames without a position copy the one before (or
## after, for the first frames).
static func normalize_track(track: Variant, count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		var entry: Variant = track[index] if track is Array and index < track.size() else null
		if entry is Dictionary and entry.get("grip") is Array and entry.grip.size() == 2 and _is_number(entry.get("angle")) and _is_number(entry.get("length")) and float(entry.length) > 0.0:
			entries.append({"grip": [float(entry.grip[0]), float(entry.grip[1])], "angle": fposmod(float(entry.angle) + 180.0, 360.0) - 180.0, "length": clampf(float(entry.length), 1.0, 8192.0), "behind": bool(entry.get("behind", false))})
		else:
			entries.append(null)
	for index in range(count):
		if entries[index] == null and index > 0 and entries[index - 1] != null:
			entries[index] = entries[index - 1].duplicate(true)
	for index in range(count - 1, -1, -1):
		if entries[index] == null and index < count - 1 and entries[index + 1] != null:
			entries[index] = entries[index + 1].duplicate(true)
	for index in range(count):
		if entries[index] == null:
			entries[index] = {"grip": [0.0, 0.0], "angle": -90.0, "length": 1.0, "behind": false}
	return entries

static func has_track(clip: Dictionary) -> bool:
	return str(clip.get("mode", "")) == "hero_weapon" and clip.get("track") is Array and not clip.track.is_empty()

static func normalize_hand_fit(fit: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT_HAND_FIT.duplicate()
	if fit is Dictionary:
		if _is_number(fit.get("angle")):
			result["angle"] = clampf(float(fit.angle), -180.0, 180.0)
		if _is_number(fit.get("scale")):
			result["scale"] = clampf(float(fit.scale), 0.1, 5.0)
		result["flip"] = bool(fit.get("flip", false))
		var tip: Variant = fit.get("tip")
		if tip is Array and tip.size() == 2 and _is_number(tip[0]) and _is_number(tip[1]):
			result["tip"] = [clampf(float(tip[0]), 0.0, 1.0), clampf(float(tip[1]), 0.0, 1.0)]
	return result

## The weapon picture's far end in pixels: the one set in the lab (hand_fit.tip,
## normalized) or, if none, the opaque pixel farthest from the grip.
static func resolve_tip(image: Image, grip: Vector2, fit: Variant) -> Vector2:
	var values := normalize_hand_fit(fit)
	if values.has("tip") and image != null and not image.is_empty():
		return Vector2(float(values.tip[0]), float(values.tip[1])) * Vector2(image.get_size())
	return weapon_tip(image, grip)

static func is_default_hand_fit(fit: Variant) -> bool:
	var values := normalize_hand_fit(fit)
	return is_zero_approx(float(values.angle)) and is_equal_approx(float(values.scale), 1.0) and not bool(values.flip) and not values.has("tip")

static func validate_hand_fit(fit: Variant) -> Dictionary:
	if not fit is Dictionary:
		return {"valid": false, "error": "hand_fit must be an object"}
	for key in fit:
		if key == "tip":
			var tip: Variant = fit[key]
			if not tip is Array or tip.size() != 2 or not _is_number(tip[0]) or not _is_number(tip[1]) or float(tip[0]) < 0.0 or float(tip[0]) > 1.0 or float(tip[1]) < 0.0 or float(tip[1]) > 1.0:
				return {"valid": false, "error": "hand_fit tip must be [x, y] between 0 and 1"}
			continue
		if not DEFAULT_HAND_FIT.has(key) or (key == "flip" and not fit[key] is bool) or (key != "flip" and not _is_number(fit[key])):
			return {"valid": false, "error": "hand_fit takes angle and scale numbers, a flip true/false and a tip [x, y]"}
	if float(fit.get("scale", 1.0)) < 0.1 or float(fit.get("scale", 1.0)) > 5.0 or absf(float(fit.get("angle", 0.0))) > 180.0:
		return {"valid": false, "error": "hand_fit is out of range"}
	return {"valid": true}

## The far end of a weapon picture: the opaque pixel farthest from its grip.
## `grip` is normalized (0-1). Returns pixels in the image.
static func weapon_tip(image: Image, grip: Vector2) -> Vector2:
	if image == null or image.is_empty():
		return Vector2.ZERO
	var source := image
	if source.is_compressed():
		source = image.duplicate() as Image
		source.decompress()
	var size := Vector2(source.get_size())
	var grip_px := grip * size
	var best := grip_px + Vector2(0, -1)
	var best_distance := -1.0
	var step := maxi(1, int(maxf(size.x, size.y) / 128.0))
	for y in range(0, source.get_height(), step):
		for x in range(0, source.get_width(), step):
			if source.get_pixel(x, y).a < 0.5:
				continue
			var distance := grip_px.distance_squared_to(Vector2(x + 0.5, y + 0.5))
			if distance > best_distance:
				best_distance = distance
				best = Vector2(x + 0.5, y + 0.5)
	return best

## Where a weapon picture goes in `frame`: maps the picture's centred local
## pixels to cell pixels. `weapon_size` is the picture size, `grip` its
## normalized grip, `tip` its far end in pixels (weapon_tip()).
static func hand_transform(clip: Dictionary, frame: int, weapon_size: Vector2, grip: Vector2, tip: Vector2, fit: Dictionary = DEFAULT_HAND_FIT) -> Transform2D:
	var track: Array = clip.get("track", [])
	if track.is_empty() or weapon_size.x <= 0.0:
		return Transform2D()
	var entry: Dictionary = track[clampi(frame, 0, track.size() - 1)]
	var hand_fit := normalize_hand_fit(fit)
	var grip_px := grip * weapon_size
	var axis := tip - grip_px
	if axis.length() < 1.0:
		axis = Vector2(0, -weapon_size.y * 0.5)
	var scale := float(entry.length) / axis.length() * float(hand_fit.scale)
	var rotation := deg_to_rad(float(entry.angle) + float(hand_fit.angle)) - axis.angle()
	var grip_local := grip_px - weapon_size * 0.5
	var origin := Vector2(float(entry.grip[0]), float(entry.grip[1])) - (grip_local * scale).rotated(rotation)
	var placed := Transform2D(rotation, Vector2(scale, scale), 0.0, origin)
	if bool(hand_fit.flip):
		# Mirror the picture across its own grip-to-tip line (blade on the other side).
		var u := axis.normalized()
		var mirror := Transform2D(Vector2(2.0 * u.x * u.x - 1.0, 2.0 * u.x * u.y), Vector2(2.0 * u.x * u.y, 2.0 * u.y * u.y - 1.0), Vector2.ZERO)
		mirror.origin = grip_local - mirror.basis_xform(grip_local)
		placed = placed * mirror
	return placed
