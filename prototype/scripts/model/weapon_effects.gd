class_name WeaponEffects
extends RefCounted

## Flipbook effects attached to a weapon (slash trails, sparks, glows, muzzle
## flashes). Stored on a published revision as "effects": an array of up to
## MAX_EFFECTS entries. Each effect is a sprite sheet played once when the
## attack reaches its trigger point.
##
## Effect fields:
##   label        name shown in the Weapon Lab
##   sheet        res:// path of the sprite sheet (published revisions)
##   source       absolute path of the sheet (drafts, before publishing)
##   frame_count  frames in the sheet, read left to right, top to bottom
##   columns      frames per row (frame_count for a single strip)
##   fps          playback speed
##   trigger      "windup" | "strike" | "hit" | "strike_end" | "custom"
##   at           fraction of the swing for "custom" (0-1)
##   anchor       [x, y] normalized point on the weapon image (0,0 top-left)
##   follow       true: rides on the weapon. false: stays where it spawned
##   align        true: turns with the weapon. false: stays upright
##   size         on-screen size in pixels of the frame's longer side
##   rotation     extra rotation in degrees
##   offset       [x, y] extra pixels (x along the facing)
##   additive     true: glowing add blend. false: normal alpha
##   opacity      0-1

const MAX_EFFECTS := 4
const TRIGGERS := ["windup", "strike", "hit", "strike_end", "custom"]
const TRIGGER_LABELS := {
	"windup": "Wind-up starts",
	"strike": "Strike starts",
	"hit": "Hit lands (melee) / shot fires (ranged)",
	"strike_end": "Strike ends",
	"custom": "Custom point in the swing",
}

const DEFAULT := {
	"label": "Effect",
	"frame_count": 8,
	"columns": 8,
	"fps": 24.0,
	"trigger": "hit",
	"at": 0.5,
	"anchor": [0.9, 0.5],
	"follow": false,
	"align": true,
	"size": 96.0,
	"rotation": 0.0,
	"offset": [0.0, 0.0],
	"additive": true,
	"opacity": 1.0,
}

const LIMITS := {
	"frame_count": [1, 64],
	"columns": [1, 64],
	"fps": [1.0, 60.0],
	"at": [0.0, 1.0],
	"size": [4.0, 1024.0],
	"rotation": [-360.0, 360.0],
	"opacity": [0.0, 1.0],
}

## Fills missing fields from DEFAULT and clamps into range.
static func normalize(effect: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if effect is Dictionary:
		for key in effect:
			result[key] = effect[key] if not (effect[key] is Array or effect[key] is Dictionary) else effect[key].duplicate(true)
	for key in LIMITS:
		var limits: Array = LIMITS[key]
		var value := float(result.get(key, DEFAULT[key])) if _is_number(result.get(key)) else float(DEFAULT[key])
		value = clampf(value, float(limits[0]), float(limits[1]))
		result[key] = int(value) if key in ["frame_count", "columns"] else value
	result["columns"] = mini(int(result.columns), int(result.frame_count))
	if not TRIGGERS.has(str(result.trigger)):
		result["trigger"] = "hit"
	for key in ["anchor", "offset"]:
		var pair: Variant = result.get(key)
		if not pair is Array or pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
			result[key] = DEFAULT[key].duplicate()
	result["anchor"] = [clampf(float(result.anchor[0]), 0.0, 1.0), clampf(float(result.anchor[1]), 0.0, 1.0)]
	result["offset"] = [clampf(float(result.offset[0]), -256.0, 256.0), clampf(float(result.offset[1]), -256.0, 256.0)]
	for key in ["follow", "align", "additive"]:
		result[key] = bool(result.get(key, DEFAULT[key]))
	result["label"] = str(result.get("label", "Effect")).left(40)
	return result

static func validate(effects: Variant) -> Dictionary:
	if not effects is Array:
		return {"valid": false, "error": "effects must be an array"}
	if effects.size() > MAX_EFFECTS:
		return {"valid": false, "error": "at most %d effects per weapon" % MAX_EFFECTS}
	for index in range(effects.size()):
		var effect: Variant = effects[index]
		if not effect is Dictionary:
			return {"valid": false, "error": "effect %d must be an object" % index}
		var sheet := str(effect.get("sheet", ""))
		if not sheet.begins_with("res://") or sheet.contains("..") or sheet.contains("\\"):
			return {"valid": false, "error": "effect %d sheet must be a repository-local res:// path" % index}
		if not TRIGGERS.has(str(effect.get("trigger", ""))):
			return {"valid": false, "error": "effect %d trigger is not supported" % index}
		for key in LIMITS:
			if effect.has(key) and (not _is_number(effect[key]) or float(effect[key]) < float(LIMITS[key][0]) or float(effect[key]) > float(LIMITS[key][1])):
				return {"valid": false, "error": "effect %d %s is out of range" % [index, key]}
		for key in ["anchor", "offset"]:
			if effect.has(key):
				var pair: Variant = effect[key]
				if not pair is Array or pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
					return {"valid": false, "error": "effect %d %s must be [x, y]" % [index, key]}
	return {"valid": true}

## Seconds after the attack starts when the effect fires.
## `hit_seconds` is when melee damage lands (0 for ranged: the shot fires at once).
static func trigger_seconds(effect: Dictionary, swing: Dictionary, duration: float, hit_seconds: float) -> float:
	var windup_time := float(swing.get("windup_time", 0.25))
	var strike_time := float(swing.get("strike_time", 0.6))
	match str(effect.get("trigger", "hit")):
		"windup":
			return 0.0
		"strike":
			return windup_time * duration
		"strike_end":
			return strike_time * duration
		"custom":
			return clampf(float(effect.get("at", 0.5)), 0.0, 1.0) * duration
	return maxf(0.0, hit_seconds)

static func play_length(effect: Dictionary) -> float:
	return float(effect.get("frame_count", 8)) / maxf(1.0, float(effect.get("fps", 24.0)))

## The region of `frame` inside a sheet of `sheet_size`.
static func frame_rect(effect: Dictionary, sheet_size: Vector2, frame: int) -> Rect2:
	var count := maxi(1, int(effect.get("frame_count", 1)))
	var columns := clampi(int(effect.get("columns", count)), 1, count)
	var rows := int(ceil(float(count) / float(columns)))
	var cell := Vector2(sheet_size.x / columns, sheet_size.y / rows)
	var index := clampi(frame, 0, count - 1)
	return Rect2(Vector2(index % columns, index / columns) * cell, cell)

## Loads a sheet from a res:// or absolute path, working even before Godot has
## imported a freshly published file.
static func load_sheet(path: String) -> Texture2D:
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

static func sheet_path(effect: Dictionary) -> String:
	var source := str(effect.get("source", ""))
	return source if not source.is_empty() else str(effect.get("sheet", ""))

static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
