class_name HeroAnimations
extends RefCounted

## Installs a hero animation (idle, walk or attack) made in the clip importer
## as the game's own hero art: assets/side-view/animations/hero_<name>/ gets a
## new atlas.png, animation.tres and manifest.json in the same layout as the
## existing ones, so SideViewActorVisual plays it with no other changes.
##
## Frames are scaled so the hero stands ASSET.animation_reference_height tall
## and placed with the feet on ASSET.animation_source_anchor, the calibration
## every hero clip shares. The previous files are copied to
## art/side-view/backups/<folder>_<time>/ first.
##
## Godot imports the new atlas.png the next time the editor has focus. Until
## then (the same run) the new frames play from runtime textures registered
## with SideViewVisualConfig.runtime_frames.

const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

const ANIMATIONS := ["idle", "walk", "attack"]
const LOOPS := {"idle": true, "walk": true, "attack": false}
const ANIMATIONS_ROOT := "res://assets/side-view/animations"
const BACKUPS_RELATIVE := "art/side-view/backups"
const MAX_COLUMNS := 8

## Tests point these somewhere temporary.
static var animations_root := ANIMATIONS_ROOT
static var backups_root := ""

static func folder_for(animation: String, asset_id: String = "hero") -> String:
	return "%s_%s" % [asset_id, animation]

static func folder_path(animation: String, asset_id: String = "hero") -> String:
	return animations_root.path_join(folder_for(animation, asset_id))

## clip: a clip from the importer (a packed sheet with cell, anchor,
## body_height, frame_ms). still_frame >= 0 keeps only that frame (a still idle).
## Returns {ok, error, frames: SpriteFrames, frame_count, folder}.
static func install(clip: Dictionary, animation: String, still_frame: int = -1, asset_id: String = "hero") -> Dictionary:
	if not ANIMATIONS.has(animation):
		return _fail("Pick idle, walk or attack.")
	if not WeaponClipScript.is_set(clip):
		return _fail("There's no animation to install.")
	var normalized := WeaponClipScript.normalize(clip)
	var sheet_path := WeaponClipScript.sheet_path(clip)
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(sheet_path) if sheet_path.begins_with("res://") else sheet_path)
	if sheet == null or sheet.is_empty():
		return _fail("Couldn't read the animation sheet (%s)." % sheet_path)
	sheet.convert(Image.FORMAT_RGBA8)
	var asset: Dictionary = ConfigScript.ASSETS.get(asset_id, {})
	if asset.is_empty():
		return _fail("Unknown actor \"%s\"." % asset_id)
	var reference_height := float(asset.animation_reference_height)
	var source_anchor: Vector2 = asset.animation_source_anchor
	var cell: Array = normalized.cell
	var anchor: Array = normalized.anchor
	var count := int(normalized.frame_count)
	var indices: Array = range(count) if still_frame < 0 else [clampi(still_frame, 0, count - 1)]
	# How tall the hero stands in the cells (frame 1 if the clip doesn't say).
	var body := float(normalized.get("body_height", 0.0))
	if body <= 1.0:
		var first := sheet.get_region(Rect2i(WeaponClipScript.frame_rect(normalized, int(indices[0]))))
		body = float(first.get_used_rect().size.y)
	if body <= 1.0:
		return _fail("Couldn't measure the hero's height in the frames.")
	var scale := reference_height / body
	var out_cell := Vector2i(maxi(1, roundi(float(cell[0]) * scale)), maxi(1, roundi(float(cell[1]) * scale)))
	var out_anchor := Vector2(float(anchor[0]), float(anchor[1])) * scale
	var columns := mini(indices.size(), MAX_COLUMNS)
	var rows := int(ceil(float(indices.size()) / columns))
	var atlas := Image.create_empty(out_cell.x * columns, out_cell.y * rows, false, Image.FORMAT_RGBA8)
	for slot in range(indices.size()):
		var region := sheet.get_region(Rect2i(WeaponClipScript.frame_rect(normalized, int(indices[slot]))))
		region.resize(out_cell.x, out_cell.y, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(region, Rect2i(Vector2i.ZERO, out_cell), Vector2i(slot % columns * out_cell.x, slot / columns * out_cell.y))
	# Frame timing: speed from the typical hold, per-frame durations relative to it.
	var holds: Array = []
	for index in indices:
		var ms_list: Array = normalized.get("frame_ms", [])
		holds.append(float(ms_list[int(index)]) if int(index) < ms_list.size() else float(WeaponClipScript.DEFAULT_FRAME_MS))
	var sorted := holds.duplicate()
	sorted.sort()
	var typical := maxf(16.0, float(sorted[(sorted.size() - 1) / 2]))
	var speed := 1000.0 / typical
	var durations: Array = holds.map(func(ms: float) -> float: return snappedf(ms / typical, 0.01))
	var crop_left := roundi(source_anchor.x - out_anchor.x)
	var crop_top := roundi(source_anchor.y - out_anchor.y)
	var folder := folder_for(animation, asset_id)
	var directory := folder_path(animation, asset_id)
	var atlas_path := directory.path_join("atlas.png")
	_backup(directory, folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if atlas.save_png(ProjectSettings.globalize_path(atlas_path)) != OK:
		return _fail("Couldn't write %s." % atlas_path)
	var manifest := {
		"union_crop": [crop_left, crop_top, crop_left + out_cell.x, crop_top + out_cell.y],
		"cell_size": [out_cell.x, out_cell.y],
		"ground_anchor": [out_anchor.x, out_anchor.y],
		"recommended_scale": float(asset.initial_visible_height) / reference_height,
		"frame_count": indices.size(),
		"columns": columns,
		"playback_fps": speed,
		"frame_durations": durations,
		"motion": animation,
		"loop_requested": bool(LOOPS[animation]),
		"source": "hero animation importer",
		"source_sheet": sheet_path,
		"source_frames": indices,
		"installed_at": Time.get_datetime_string_from_system(),
	}
	var manifest_file := FileAccess.open(ProjectSettings.globalize_path(directory.path_join("manifest.json")), FileAccess.WRITE)
	if manifest_file == null:
		return _fail("Couldn't write the manifest in %s." % directory)
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	var tres := _tres_text(directory, animation, indices.size(), columns, out_cell, speed, durations)
	var tres_file := FileAccess.open(ProjectSettings.globalize_path(directory.path_join("animation.tres")), FileAccess.WRITE)
	if tres_file == null:
		return _fail("Couldn't write the animation in %s." % directory)
	tres_file.store_string(tres)
	tres_file.close()
	var frames := runtime_frames(atlas, animation, indices.size(), columns, out_cell, speed, durations)
	ConfigScript.runtime_frames[folder] = frames
	ConfigScript.runtime_manifests[folder] = manifest
	return {"ok": true, "error": "", "frames": frames, "frame_count": indices.size(), "folder": directory}

## SpriteFrames built straight from the image, for the run the art was made in.
static func runtime_frames(atlas: Image, animation: String, count: int, columns: int, cell: Vector2i, speed: float, durations: Array) -> SpriteFrames:
	var texture := ImageTexture.create_from_image(atlas)
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(StringName(animation))
	frames.set_animation_loop(StringName(animation), bool(LOOPS[animation]))
	frames.set_animation_speed(StringName(animation), speed)
	for index in range(count):
		var piece := AtlasTexture.new()
		piece.atlas = texture
		piece.region = Rect2(index % columns * cell.x, index / columns * cell.y, cell.x, cell.y)
		frames.add_frame(StringName(animation), piece, float(durations[index]))
	return frames

## The same SpriteFrames as a .tres the editor imports, in the existing layout.
static func _tres_text(directory: String, animation: String, count: int, columns: int, cell: Vector2i, speed: float, durations: Array) -> String:
	var atlas_path := directory.path_join("atlas.png")
	var atlas_uid := _import_uid(atlas_path)
	var own_uid := _tres_uid(directory.path_join("animation.tres"))
	var lines: Array = []
	lines.append("[gd_resource type=\"SpriteFrames\" load_steps=%d format=3%s]" % [count + 2, (" uid=\"%s\"" % own_uid) if not own_uid.is_empty() else ""])
	lines.append("")
	lines.append("[ext_resource type=\"Texture2D\"%s path=\"%s\" id=\"1\"]" % [(" uid=\"%s\"" % atlas_uid) if not atlas_uid.is_empty() else "", atlas_path])
	lines.append("")
	for index in range(count):
		lines.append("[sub_resource type=\"AtlasTexture\" id=\"Frame_%d\"]" % index)
		lines.append("atlas = ExtResource(\"1\")")
		lines.append("region = Rect2(%d, %d, %d, %d)" % [index % columns * cell.x, index / columns * cell.y, cell.x, cell.y])
		lines.append("")
	lines.append("[resource]")
	var entries: Array = []
	for index in range(count):
		entries.append("{\n\"duration\": %s,\n\"texture\": SubResource(\"Frame_%d\")\n}" % [str(float(durations[index])), index])
	lines.append("animations = [{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %s\n}]" % [", ".join(entries), "true" if bool(LOOPS[animation]) else "false", animation, str(snappedf(speed, 0.001))])
	lines.append("")
	return "\n".join(lines)

## Keeps the uid Godot already gave the atlas, so nothing that points at it breaks.
static func _import_uid(atlas_path: String) -> String:
	var import_path := ProjectSettings.globalize_path(atlas_path + ".import")
	if not FileAccess.file_exists(import_path):
		return ""
	for line in FileAccess.get_file_as_string(import_path).split("\n"):
		if line.begins_with("uid="):
			return line.trim_prefix("uid=").strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""

static func _tres_uid(tres_path: String) -> String:
	var path := ProjectSettings.globalize_path(tres_path)
	if not FileAccess.file_exists(path):
		return ""
	var header := FileAccess.get_file_as_string(path).get_slice("\n", 0)
	var at := header.find("uid=\"")
	if at < 0:
		return ""
	var rest := header.substr(at + 5)
	return rest.substr(0, rest.find("\""))

static func _backup(directory: String, folder: String) -> void:
	var source := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(source):
		return
	var root := backups_root if not backups_root.is_empty() else ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(BACKUPS_RELATIVE)
	var target := root.path_join("%s_%s" % [folder, Time.get_datetime_string_from_system().replace(":", "").replace("-", "")])
	DirAccess.make_dir_recursive_absolute(target)
	for name in ["atlas.png", "animation.tres", "manifest.json"]:
		if FileAccess.file_exists(source.path_join(name)):
			DirAccess.copy_absolute(source.path_join(name), target.path_join(name))

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "frames": null, "frame_count": 0, "folder": ""}
