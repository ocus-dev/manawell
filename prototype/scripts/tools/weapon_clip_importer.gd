extends Control

## The Weapon Lab's clip importer: a full-screen overlay that turns a pose
## sheet (for example one made in ChatGPT), a set of frame images, or a video
## into a weapon attack clip. Steps: open a source, slice the sheet into
## frames, cut every frame out (flat background locally, or Trellis 2 through
## ComfyUI), line the frames up, set timing and which frames start an attack
## and land the hit, then save. The engine lives in weapon_clip_import.gd.

signal saved(clip: Dictionary)
signal closed

const Imp = preload("res://scripts/tools/weapon_clip_import.gd")
const WeaponClip = preload("res://scripts/model/weapon_clip.gd")
const Art = preload("res://scripts/tools/weapon_lab_art.gd")

const AMBER := Color("f0a836")
const AMBER_DEEP := Color("b9761c")
const INK := Color("ece6da")
const MUTED := Color("9ba4ac")
const EDGE := Color("434c55")
const GOOD := Color("75d5a5")
const BAD := Color("f09a9a")
const CUT_LINE := Color("ff4fd8")
const STRIP_LINE := Color("63e08f")
const ONION := Color(0.45, 0.85, 1.0, 0.35)
const METHODS := [
	{"id": "solid", "label": "Solid background (local)"},
	{"id": "trellis", "label": "ComfyUI Trellis 2"},
	{"id": "alpha", "label": "Already transparent"},
]
const ALIGN_MODES := [
	{"id": "feet", "label": "Line up the feet (poses drawn in different spots)"},
	{"id": "fixed", "label": "Keep positions (video, or frames from one camera)"},
]

## Set by the lab.
var comfy: Node
var weapon_id := ""
var hit_seconds := 0.0
var attack_interval := 0.6

var project_dir := ""
var source_kind := ""
var source_image: Image
var source_texture: Texture2D
var frame_sources: Array = []
var frame_source_textures: Array = []
var strip := Rect2i()
var boxes: Array = []
var ground_y := -1
var background := Color.WHITE
var cut: Array = []
var cut_textures: Array = []
var anchors: Array = []
var holds: Array = []
var starts: Array = []
var hits: Array = []
var mode := "hero"
var body_height := 0.0
var clip_scale := 1.0
var align_mode := "feet"
var selected := 0
var step := "source"
var tool := "anchor"
var brush := 6.0
var onion := true
var playing := false
var play_time := 0.0
var busy := false
var last_error := ""

var _status: Label
var _view: Control
var _strip_box: HBoxContainer
var _strip_scroll: ScrollContainer
var _count_spin: SpinBox
var _method: OptionButton
var _tolerance: SpinBox
var _holes: CheckBox
var _neighbors: CheckBox
var _min_piece: SpinBox
var _cut_button: Button
var _align_picker: OptionButton
var _tool_anchor: Button
var _tool_erase: Button
var _brush_spin: SpinBox
var _onion_check: CheckBox
var _hold_spin: SpinBox
var _all_hold_spin: SpinBox
var _start_check: CheckBox
var _hit_check: CheckBox
var _frame_label: Label
var _attacks_label: Label
var _play_check: CheckBox
var _mode_picker: OptionButton
var _height_spin: SpinBox
var _scale_spin: SpinBox
var _name_edit: LineEdit
var _save_button: Button
var _box_left: SpinBox
var _box_right: SpinBox
var _fps_spin: SpinBox
var _start_spin: SpinBox
var _max_spin: SpinBox
var _ffmpeg_edit: LineEdit
var _sheet_dialog: FileDialog
var _frames_dialog: FileDialog
var _video_dialog: FileDialog
var _sections: Dictionary = {}
var _loading := false
var _drag := {}
var _union := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	if playing:
		play_time += delta
		_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	var key := event as InputEventKey
	var amount := 10.0 if key.shift_pressed else 1.0
	var handled := true
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			nudge(selected, Vector2(-amount, 0))
		KEY_RIGHT:
			nudge(selected, Vector2(amount, 0))
		KEY_UP:
			nudge(selected, Vector2(0, -amount))
		KEY_DOWN:
			nudge(selected, Vector2(0, amount))
		KEY_COMMA, KEY_Q:
			select_frame(selected - 1)
		KEY_PERIOD, KEY_E:
			select_frame(selected + 1)
		KEY_SPACE:
			set_playing(not playing)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

# ---------- opening sources ----------

## Opens the importer on a new, empty clip for `new_weapon_id`.
func start(new_weapon_id: String, new_hit_seconds: float, new_interval: float) -> void:
	weapon_id = new_weapon_id
	hit_seconds = new_hit_seconds
	attack_interval = new_interval
	_reset()
	visible = true
	_set_status("Open a pose sheet, a set of frames, or a video to begin.")
	_refresh()

func close() -> void:
	set_playing(false)
	visible = false
	closed.emit()

func _reset() -> void:
	project_dir = ""
	source_kind = ""
	source_image = null
	source_texture = null
	frame_sources = []
	frame_source_textures = []
	strip = Rect2i()
	boxes = []
	ground_y = -1
	cut = []
	cut_textures = []
	anchors = []
	holds = []
	starts = []
	hits = []
	selected = 0
	step = "source"
	playing = false
	body_height = 0.0
	clip_scale = 1.0
	mode = "hero"
	align_mode = "feet"
	if _name_edit != null:
		_name_edit.text = "Attack"

func open_sheet(path: String) -> bool:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return _fail("Couldn't open %s as an image." % path.get_file())
	_reset_source()
	project_dir = Imp.new_project_dir(weapon_id, path.get_file().get_basename())
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(project_dir.path_join("source.png"))
	source_kind = "sheet"
	source_image = image
	source_texture = ImageTexture.create_from_image(image)
	align_mode = "feet"
	var layout := Imp.detect_layout(image, 0)
	_apply_layout(layout)
	var guessed := boxes.size()
	step = "slice"
	_refresh()
	if guessed <= 1:
		_set_status("Couldn't tell how many poses are on the sheet (they touch). Set Frames to the number of poses; the cuts move to the emptiest gaps.", AMBER)
	else:
		_set_status("Found %d poses. Check the magenta cuts, then press Cut out frames." % guessed, GOOD)
	return true

func open_frames(paths: Array) -> bool:
	var sorted: Array = []
	for path in paths:
		if Imp.kind_of(str(path)) == "image":
			sorted.append(str(path))
	sorted.sort()
	if sorted.is_empty():
		return _fail("Pick PNG, JPG or WebP frames.")
	if sorted.size() > WeaponClip.MAX_FRAMES:
		sorted = sorted.slice(0, WeaponClip.MAX_FRAMES)
	_reset_source()
	project_dir = Imp.new_project_dir(weapon_id, str(sorted[0]).get_file().get_basename().rstrip("0123456789_- "))
	var copied: Array = []
	for index in range(sorted.size()):
		var image := Image.load_from_file(str(sorted[index]))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		var target := project_dir.path_join("frames").path_join("src_%03d.png" % index)
		image.save_png(target)
		copied.append(target)
	return _use_frame_sources(copied, "frames")

func open_video(path: String) -> bool:
	var settings := Imp.load_settings()
	var preferred := _ffmpeg_edit.text.strip_edges() if _ffmpeg_edit != null else str(settings.get("ffmpeg", ""))
	var ffmpeg := Imp.find_ffmpeg(preferred)
	if ffmpeg.is_empty():
		return _fail("ffmpeg wasn't found. Install ffmpeg (or point the ffmpeg box at ffmpeg.exe, e.g. the one inside ComfyUI's python_embeded\\Lib\\site-packages\\imageio_ffmpeg\\binaries), or export the video's frames as PNGs and use Open frames...")
	settings["ffmpeg"] = ffmpeg
	Imp.save_settings(settings)
	_reset_source()
	project_dir = Imp.new_project_dir(weapon_id, path.get_file().get_basename())
	_set_status("Reading frames from the video...")
	var result := Imp.extract_video(ffmpeg, path, project_dir.path_join("frames"), _fps_spin.value if _fps_spin != null else 12.0, int(_max_spin.value) if _max_spin != null else 24, _start_spin.value if _start_spin != null else 0.0)
	if not result.ok:
		return _fail(str(result.error))
	return _use_frame_sources(result.paths, "video")

func _use_frame_sources(paths: Array, kind: String) -> bool:
	if paths.is_empty():
		return _fail("No readable frames.")
	source_kind = kind
	frame_sources = paths
	frame_source_textures = []
	for path in paths:
		frame_source_textures.append(ImageTexture.create_from_image(Image.load_from_file(str(path))))
	boxes = []
	align_mode = "fixed"
	step = "slice"
	_refresh()
	_set_status("%d frames loaded. Choose a cutout method and press Cut out frames." % paths.size(), GOOD)
	return true

func _reset_source() -> void:
	var name_text := _name_edit.text if _name_edit != null else "Attack"
	_reset()
	if _name_edit != null:
		_name_edit.text = name_text

func _apply_layout(layout: Dictionary) -> void:
	strip = layout.get("strip", Rect2i())
	boxes = layout.get("boxes", []).duplicate()
	ground_y = int(layout.get("ground_y", -1))
	background = layout.get("background", Color.WHITE)
	selected = 0

## Re-slices the sheet into `count` frames at the emptiest columns.
func set_frame_count(count: int) -> void:
	if source_kind != "sheet" or source_image == null:
		return
	var layout := Imp.detect_layout(source_image, clampi(count, 1, WeaponClip.MAX_FRAMES))
	_apply_layout(layout)
	_refresh()
	_set_status("Split into %d frames. Drag the magenta lines if a cut goes through a pose." % boxes.size())

func auto_detect() -> void:
	if source_kind == "sheet" and source_image != null:
		_apply_layout(Imp.detect_layout(source_image, 0))
		_refresh()

func frame_count() -> int:
	return cut.size() if not cut.is_empty() else (boxes.size() if source_kind == "sheet" else frame_sources.size())

# ---------- cutting out ----------

func cut_options() -> Dictionary:
	return {
		"method": _method_id(),
		"tolerance": _tolerance.value if _tolerance != null else Imp.DEFAULT_TOLERANCE,
		"clear_holes": _holes.button_pressed if _holes != null else true,
		"drop_neighbors": _neighbors.button_pressed if _neighbors != null else true,
		"min_piece": (_min_piece.value / 100.0) if _min_piece != null else Imp.DEFAULT_MIN_PIECE,
	}

## Cuts out every frame. Coroutine (Trellis runs through ComfyUI).
func cut_out() -> bool:
	if busy:
		return false
	if source_kind.is_empty():
		return _fail("Open a source first.")
	var options := cut_options()
	var count := boxes.size() if source_kind == "sheet" else frame_sources.size()
	if count == 0:
		return _fail("Nothing to cut out.")
	busy = true
	_refresh()
	var results: Array = []
	for index in range(count):
		_set_status("Cutting out frame %d of %d..." % [index + 1, count])
		var image: Image = null
		if str(options.method) == "trellis":
			image = await _trellis_frame(index, options)
			if image == null:
				busy = false
				_refresh()
				return false
		else:
			image = cut_frame_now(index, options)
		results.append(image)
		if index % 2 == 1 and is_inside_tree():
			await get_tree().process_frame
	cut = results
	cut_textures = []
	for image in cut:
		cut_textures.append(ImageTexture.create_from_image(image))
	holds = []
	for _i in range(cut.size()):
		holds.append(WeaponClip.DEFAULT_FRAME_MS)
	starts = []
	hits = []
	realign()
	body_height = Imp.figure_height(cut[0]) if not cut.is_empty() else 0.0
	busy = false
	selected = 0
	step = "align"
	_refresh()
	_set_status("Cut out %d frames. Line them up, erase stray bits, then set timing and the hit frame." % cut.size(), GOOD)
	return true

## The cutout for frame `index` with the local methods.
func cut_frame_now(index: int, options: Dictionary) -> Image:
	if source_kind == "sheet":
		var local := options.duplicate()
		local["background"] = background
		return Imp.cut_frame(source_image, boxes[index], local)
	var image := Image.load_from_file(str(frame_sources[index]))
	image.convert(Image.FORMAT_RGBA8)
	var local := options.duplicate()
	local["drop_neighbors"] = false
	return Imp.cut_frame(image, Rect2i(Vector2i.ZERO, image.get_size()), local)

func _trellis_frame(index: int, options: Dictionary) -> Image:
	if comfy == null:
		_fail("ComfyUI isn't available here.")
		return null
	var crop: Image
	if source_kind == "sheet":
		crop = source_image.get_region(boxes[index])
	else:
		crop = Image.load_from_file(str(frame_sources[index]))
	var path := project_dir.path_join("frames").path_join("trellis_in_%03d.png" % index)
	crop.save_png(path)
	var result: Dictionary = await comfy.cut_out(path, "clip-%s-%d-%d" % [Art.slug(weapon_id), Time.get_unix_time_from_system(), index])
	if not bool(result.get("ok", false)):
		_fail("Trellis 2 failed on frame %d: %s" % [index + 1, str(result.get("error", ""))])
		return null
	var image: Image = result.image
	image.convert(Image.FORMAT_RGBA8)
	var local := options.duplicate()
	if source_kind != "sheet":
		local["drop_neighbors"] = false
	return Imp.filter_pieces(image, local)

## Re-cuts one frame (undoes erasing).
func recut_frame(index: int) -> void:
	if index < 0 or index >= cut.size() or _method_id() == "trellis":
		return
	cut[index] = cut_frame_now(index, cut_options())
	cut_textures[index] = ImageTexture.create_from_image(cut[index])
	_after_frames_changed()

# ---------- aligning ----------

func realign(new_mode: String = "") -> void:
	if not new_mode.is_empty():
		align_mode = new_mode
	anchors = []
	if cut.is_empty():
		return
	if mode == "weapon" and align_mode == "fixed":
		var grip := Vector2(cut[0].get_width() * 0.5, cut[0].get_height() * 0.5)
		for _image in cut:
			anchors.append(grip)
	elif align_mode == "fixed":
		var first := Imp.feet_anchor(cut[0])
		for _image in cut:
			anchors.append(first)
	else:
		for index in range(cut.size()):
			var ground := float(ground_y - boxes[index].position.y) if source_kind == "sheet" and ground_y >= 0 and index < boxes.size() else -1.0
			anchors.append(Imp.feet_anchor(cut[index], ground))
	_after_frames_changed()

func nudge(index: int, delta: Vector2) -> void:
	if index < 0 or index >= anchors.size():
		return
	# Moving the frame right means its anchor moves left in its own pixels.
	anchors[index] = Vector2(anchors[index]) - delta
	_after_frames_changed()

func set_frame_anchor(index: int, point: Vector2) -> void:
	if index < 0 or index >= anchors.size():
		return
	anchors[index] = point.round()
	_after_frames_changed()

func anchor_to_all(index: int) -> void:
	if index < 0 or index >= anchors.size():
		return
	for other in range(anchors.size()):
		anchors[other] = anchors[index]
	_after_frames_changed()

func erase_at(index: int, point: Vector2, radius: float) -> void:
	if index < 0 or index >= cut.size():
		return
	Imp.erase_circle(cut[index], point, radius)
	(cut_textures[index] as ImageTexture).update(cut[index])
	if _view != null:
		_view.queue_redraw()

func _after_frames_changed() -> void:
	_union = _compute_union()
	if _view != null:
		_view.queue_redraw()
	_refresh_frame_controls()

# ---------- timing and attacks ----------

func set_hold(index: int, ms: float) -> void:
	if index >= 0 and index < holds.size():
		holds[index] = clampf(ms, 16.0, 2000.0)
		_refresh_attacks()

func set_all_holds(ms: float) -> void:
	for index in range(holds.size()):
		holds[index] = clampf(ms, 16.0, 2000.0)
	_refresh_frame_controls()

func set_attack_start(index: int, on: bool) -> void:
	if index <= 0:
		return
	starts.erase(index)
	if on:
		starts.append(index)
		starts.sort()
	_refresh_frame_controls()

## Marks `index` as its attack's hit frame (one hit per attack).
func set_hit(index: int, on: bool) -> void:
	for attack in current_attacks():
		if index >= int(attack.start) and index <= int(attack.end):
			for frame in range(int(attack.start), int(attack.end) + 1):
				hits.erase(frame)
	if on:
		hits.append(index)
	_refresh_frame_controls()

func current_attacks() -> Array:
	return WeaponClip.attacks_from_marks(maxi(1, cut.size()), starts, hits)

## The clip as it would be saved, pointing at the loose frames (for previews).
func preview_clip() -> Dictionary:
	return WeaponClip.normalize({"mode": mode, "frame_count": maxi(1, cut.size()), "frame_ms": holds, "attacks": current_attacks(), "fit_hit": true})

func set_playing(on: bool) -> void:
	playing = on and not cut.is_empty()
	play_time = 0.0
	if _play_check != null and _play_check.button_pressed != playing:
		_play_check.set_pressed_no_signal(playing)
	if _view != null:
		_view.queue_redraw()

## Frame shown `time` seconds into the looping combo preview (-1 in the gaps).
func preview_frame_at(time: float) -> int:
	var clip := preview_clip()
	var lines: Array = []
	var total := 0.0
	for index in range(current_attacks().size()):
		var line := WeaponClip.timeline(clip, index, hit_seconds)
		lines.append(line)
		total += float(line.length) + 0.2
	if total <= 0.0:
		return -1
	var t := fmod(time, total)
	for line in lines:
		if t < float(line.length):
			return WeaponClip.frame_at(line, t)
		t -= float(line.length) + 0.2
		if t < 0.0:
			return -1
	return -1

# ---------- saving ----------

## Packs the frames into one sheet and returns the attack_clip entry.
func build_clip() -> Dictionary:
	if cut.is_empty() or anchors.size() != cut.size():
		return {}
	var packed := Imp.pack(cut, anchors)
	if packed.is_empty():
		return {}
	var sheet_path := project_dir.path_join("sheet.png")
	if FileAccess.file_exists(sheet_path):
		DirAccess.remove_absolute(sheet_path)
	# A fresh file name each save keeps the lab's texture cache honest.
	sheet_path = project_dir.path_join("sheet_%d.png" % Time.get_ticks_msec())
	for name in DirAccess.get_files_at(project_dir):
		if name.begins_with("sheet_") and name.ends_with(".png"):
			DirAccess.remove_absolute(project_dir.path_join(name))
	if (packed.image as Image).save_png(sheet_path) != OK:
		return {}
	var scale := float(packed.scale)
	var label := _name_edit.text.strip_edges() if _name_edit != null and not _name_edit.text.strip_edges().is_empty() else "Attack"
	return WeaponClip.normalize({
		"label": label,
		"mode": mode,
		"source": sheet_path,
		"project": project_dir,
		"frame_count": int(packed.frame_count),
		"columns": int(packed.columns),
		"cell": packed.cell,
		"anchor": packed.anchor,
		"body_height": body_height * scale,
		"scale": clip_scale,
		"frame_ms": holds.duplicate(),
		"attacks": current_attacks(),
		"fit_hit": true,
	})

func save_clip() -> Dictionary:
	if cut.is_empty():
		_fail("Cut out the frames first.")
		return {}
	_save_project()
	var clip := build_clip()
	if clip.is_empty():
		_fail("Couldn't pack the frames into a sheet.")
		return {}
	saved.emit(clip)
	_set_status("Saved the clip to the weapon.", GOOD)
	visible = false
	closed.emit()
	return clip

func _save_project() -> void:
	if project_dir.is_empty():
		return
	var frames: Array = []
	for index in range(cut.size()):
		var file := "frames/cut_%03d.png" % index
		(cut[index] as Image).save_png(project_dir.path_join(file))
		frames.append({"file": file, "anchor": [Vector2(anchors[index]).x, Vector2(anchors[index]).y]})
	var box_list: Array = []
	for box in boxes:
		var rect: Rect2i = box
		box_list.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var source_list: Array = []
	for path in frame_sources:
		source_list.append(str(path).get_file())
	Imp.save_project(project_dir, {
		"schema_version": 1,
		"source_kind": source_kind,
		"frame_sources": source_list,
		"boxes": box_list,
		"strip": [strip.position.x, strip.position.y, strip.size.x, strip.size.y],
		"ground_y": ground_y,
		"background": background.to_html(false),
		"cut": cut_options(),
		"align_mode": align_mode,
		"frames": frames,
		"frame_ms": holds.duplicate(),
		"starts": starts.duplicate(),
		"hits": hits.duplicate(),
		"mode": mode,
		"body_height": body_height,
		"scale": clip_scale,
		"label": _name_edit.text if _name_edit != null else "Attack",
	})

## Reopens a saved clip project for editing.
func load_project(dir: String, new_weapon_id: String, new_hit_seconds: float, new_interval: float) -> bool:
	var project := Imp.load_project(dir)
	if project.is_empty():
		return _fail("That clip's importer project wasn't found (%s)." % dir)
	start(new_weapon_id, new_hit_seconds, new_interval)
	project_dir = dir
	source_kind = str(project.get("source_kind", "sheet"))
	if source_kind == "sheet":
		source_image = Image.load_from_file(dir.path_join("source.png"))
		if source_image != null and not source_image.is_empty():
			source_image.convert(Image.FORMAT_RGBA8)
			source_texture = ImageTexture.create_from_image(source_image)
	else:
		for name in project.get("frame_sources", []):
			frame_sources.append(dir.path_join("frames").path_join(str(name)))
			frame_source_textures.append(ImageTexture.create_from_image(Image.load_from_file(frame_sources[-1])))
	for entry in project.get("boxes", []):
		boxes.append(Rect2i(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[3])))
	var strip_entry: Array = project.get("strip", [0, 0, 0, 0])
	strip = Rect2i(int(strip_entry[0]), int(strip_entry[1]), int(strip_entry[2]), int(strip_entry[3]))
	ground_y = int(project.get("ground_y", -1))
	background = Color.html(str(project.get("background", "ffffff")))
	for entry in project.get("frames", []):
		var image := Image.load_from_file(dir.path_join(str(entry.get("file", ""))))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		cut.append(image)
		cut_textures.append(ImageTexture.create_from_image(image))
		var anchor: Array = entry.get("anchor", [0, 0])
		anchors.append(Vector2(float(anchor[0]), float(anchor[1])))
	for value in project.get("frame_ms", []):
		holds.append(float(value))
	while holds.size() < cut.size():
		holds.append(WeaponClip.DEFAULT_FRAME_MS)
	for value in project.get("starts", []):
		starts.append(int(value))
	for value in project.get("hits", []):
		hits.append(int(value))
	mode = str(project.get("mode", "hero"))
	align_mode = str(project.get("align_mode", "feet"))
	body_height = float(project.get("body_height", 0.0))
	clip_scale = float(project.get("scale", 1.0))
	if _name_edit != null:
		_name_edit.text = str(project.get("label", "Attack"))
	var options: Dictionary = project.get("cut", {})
	_loading = true
	if _tolerance != null:
		_tolerance.value = float(options.get("tolerance", Imp.DEFAULT_TOLERANCE))
		_holes.button_pressed = bool(options.get("clear_holes", true))
		_neighbors.button_pressed = bool(options.get("drop_neighbors", true))
		_min_piece.value = float(options.get("min_piece", Imp.DEFAULT_MIN_PIECE)) * 100.0
		for index in range(METHODS.size()):
			if METHODS[index].id == str(options.get("method", "solid")):
				_method.select(index)
	_loading = false
	step = "align" if not cut.is_empty() else "slice"
	_union = _compute_union()
	_refresh()
	_set_status("Editing %s. Save to update the weapon's clip." % dir.get_file(), GOOD)
	return true

# ---------- view ----------

func select_frame(index: int) -> void:
	var count := frame_count()
	if count == 0:
		return
	selected = posmod(index, count)
	_refresh_frame_controls()
	_view.queue_redraw()

func _source_transform() -> Dictionary:
	var rect := Rect2(Vector2.ZERO, _view.size)
	var size := Vector2(source_image.get_size()) if source_image != null else Vector2.ONE
	var s := minf((rect.size.x - 24.0) / size.x, (rect.size.y - 24.0) / size.y)
	var origin := (rect.size - size * s) * 0.5
	return {"scale": s, "origin": origin}

func _compute_union() -> Rect2:
	if cut.is_empty() or anchors.size() != cut.size():
		return Rect2()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index in range(cut.size()):
		var size := Vector2((cut[index] as Image).get_size())
		var anchor: Vector2 = anchors[index]
		low = Vector2(minf(low.x, -anchor.x), minf(low.y, -anchor.y))
		high = Vector2(maxf(high.x, size.x - anchor.x), maxf(high.y, size.y - anchor.y))
	return Rect2(low, high - low)

## Where the shared anchor sits in the view and the view's zoom.
func _align_transform() -> Dictionary:
	var rect := Rect2(Vector2.ZERO, _view.size)
	if not _union.has_area():
		return {"scale": 1.0, "pivot": rect.size * 0.5}
	var room := rect.size - Vector2(40.0, 70.0)
	var s := minf(room.x / _union.size.x, room.y / _union.size.y)
	var pivot := Vector2(20.0, 20.0) + (room - _union.size * s) * 0.5 - _union.position * s
	return {"scale": s, "pivot": pivot}

func _draw_view() -> void:
	var rect := Rect2(Vector2.ZERO, _view.size)
	_view.draw_rect(rect, Color("101316"), true)
	if step == "align" and not cut.is_empty():
		_draw_align()
	elif source_kind == "sheet" and source_texture != null:
		_draw_slice()
	elif not frame_source_textures.is_empty():
		_draw_frame_sources()
	else:
		var font := ThemeDB.fallback_font
		_view.draw_string(font, Vector2(24, rect.size.y * 0.5), "Open a pose sheet, frames, or a video (right panel, step 1).", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)

func _draw_slice() -> void:
	var t := _source_transform()
	var s: float = t.scale
	var o: Vector2 = t.origin
	var size := Vector2(source_image.get_size())
	_view.draw_texture_rect(source_texture, Rect2(o, size * s), false)
	var font := ThemeDB.fallback_font
	for index in range(boxes.size()):
		var box: Rect2i = boxes[index]
		var view_box := Rect2(o + Vector2(box.position) * s, Vector2(box.size) * s)
		var color := AMBER if index == selected else Color(1, 1, 1, 0.35)
		_view.draw_rect(view_box, Color(color, 0.08) if index == selected else Color(0, 0, 0, 0), true)
		_view.draw_rect(view_box, color, false, 2.0 if index == selected else 1.0)
		_view.draw_string(font, view_box.position + Vector2(5, 16), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	for x in _edge_positions():
		var vx := o.x + float(x) * s
		_view.draw_line(Vector2(vx, o.y + strip.position.y * s), Vector2(vx, o.y + strip.end.y * s), CUT_LINE, 2.0)
	for y in [strip.position.y, strip.end.y]:
		var vy := o.y + float(y) * s
		_view.draw_line(Vector2(o.x + strip.position.x * s - 8, vy), Vector2(o.x + strip.end.x * s + 8, vy), STRIP_LINE, 2.0)

func _draw_frame_sources() -> void:
	var rect := Rect2(Vector2.ZERO, _view.size)
	var count := frame_source_textures.size()
	var columns := mini(count, 8)
	var rows := int(ceil(float(count) / columns))
	var cell := Vector2((rect.size.x - 20) / columns, (rect.size.y - 20) / rows)
	var font := ThemeDB.fallback_font
	for index in range(count):
		var texture: Texture2D = frame_source_textures[index]
		var box := Rect2(Vector2(10, 10) + Vector2(index % columns, index / columns) * cell, cell - Vector2(6, 6))
		var size := Vector2(texture.get_size())
		var fit := minf(box.size.x / size.x, box.size.y / size.y)
		_view.draw_texture_rect(texture, Rect2(box.position + (box.size - size * fit) * 0.5, size * fit), false)
		_view.draw_rect(box, AMBER if index == selected else EDGE, false, 1.0)
		_view.draw_string(font, box.position + Vector2(4, 14), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)

func _draw_align() -> void:
	var rect := Rect2(Vector2.ZERO, _view.size)
	var t := _align_transform()
	var s: float = t.scale
	var pivot: Vector2 = t.pivot
	# Checker so transparent areas read clearly.
	var tile := 16.0
	for y in range(int(rect.size.y / tile) + 1):
		for x in range(int(rect.size.x / tile) + 1):
			if (x + y) % 2 == 0:
				_view.draw_rect(Rect2(Vector2(x, y) * tile, Vector2(tile, tile)), Color("171b1f"), true)
	var shown := selected
	if playing:
		shown = preview_frame_at(play_time)
	if not playing and onion and selected > 0:
		_draw_cut_frame(selected - 1, pivot, s, ONION)
	if shown >= 0:
		_draw_cut_frame(shown, pivot, s, Color.WHITE)
	# Anchor crosshair: the ground line (hero) or grip (weapon).
	_view.draw_line(Vector2(0, pivot.y), Vector2(rect.size.x, pivot.y), Color(STRIP_LINE, 0.7), 1.0)
	_view.draw_line(Vector2(pivot.x, pivot.y - 18), Vector2(pivot.x, pivot.y + 18), Color(STRIP_LINE, 0.9), 2.0)
	_view.draw_rect(Rect2(0, rect.size.y - 30, rect.size.x, 30), Color("101316"), true)
	var font := ThemeDB.fallback_font
	var caption := "frame %d / %d" % [shown + 1, cut.size()] if shown >= 0 else ""
	if playing:
		caption = "playing the combo  " + caption
	elif tool == "erase":
		caption += "   eraser: drag to erase stray bits"
	else:
		caption += "   drag to move the frame, click to put that point on the %s" % ("ground mark" if mode == "hero" else "grip mark")
	_view.draw_string(font, Vector2(12, rect.size.y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	if not playing and hits.has(selected):
		_view.draw_string(font, Vector2(12, 22), "HIT FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BAD)

func _draw_cut_frame(index: int, pivot: Vector2, s: float, tint: Color) -> void:
	if index < 0 or index >= cut_textures.size():
		return
	var texture: Texture2D = cut_textures[index]
	var anchor: Vector2 = anchors[index]
	_view.draw_texture_rect(texture, Rect2(pivot - anchor * s, Vector2(texture.get_size()) * s), false, tint)

func _edge_positions() -> Array:
	var edges: Array = []
	for box in boxes:
		var rect: Rect2i = box
		for x in [rect.position.x, rect.end.x]:
			if not edges.has(x):
				edges.append(x)
	return edges

func _on_view_input(event: InputEvent) -> void:
	if step == "align" and not cut.is_empty():
		_align_input(event)
	elif source_kind == "sheet" and source_image != null:
		_slice_input(event)
	elif event is InputEventMouseButton and event.pressed and not frame_source_textures.is_empty():
		pass

func _slice_input(event: InputEvent) -> void:
	var t := _source_transform()
	var s: float = t.scale
	var o: Vector2 = t.origin
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if not button.pressed:
			_drag = {}
			return
		var point := (button.position - o) / s
		for y in [strip.position.y, strip.end.y]:
			if absf(button.position.y - (o.y + float(y) * s)) < 7.0:
				_drag = {"kind": "strip", "edge": "top" if y == strip.position.y else "bottom"}
				return
		for x in _edge_positions():
			if absf(button.position.x - (o.x + float(x) * s)) < 7.0 and point.y >= strip.position.y - 4 and point.y <= strip.end.y + 4:
				_drag = {"kind": "cut", "x": int(x)}
				return
		for index in range(boxes.size()):
			if Rect2(boxes[index]).has_point(point):
				select_frame(index)
				return
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var point := ((event as InputEventMouseMotion).position - o) / s
		if str(_drag.kind) == "cut":
			move_cut(int(_drag.x), int(round(point.x)))
			_drag["x"] = clampi(int(round(point.x)), 0, source_image.get_width())
		else:
			move_strip(str(_drag.edge), int(round(point.y)))

## Moves every box edge sitting at `from_x` to `to_x`.
func move_cut(from_x: int, to_x: int) -> void:
	var x := clampi(to_x, 0, source_image.get_width())
	for index in range(boxes.size()):
		var box: Rect2i = boxes[index]
		var left := box.position.x
		var right := box.end.x
		if left == from_x:
			left = mini(x, right - 4)
		if right == from_x:
			right = maxi(x, left + 4)
		boxes[index] = Rect2i(left, box.position.y, right - left, box.size.y)
	_view.queue_redraw()
	_refresh_frame_controls()

func move_strip(edge: String, y: int) -> void:
	var top := strip.position.y
	var bottom := strip.end.y
	if edge == "top":
		top = clampi(y, 0, bottom - 8)
	else:
		bottom = clampi(y, top + 8, source_image.get_height())
		ground_y = bottom
	strip = Rect2i(strip.position.x, top, strip.size.x, bottom - top)
	for index in range(boxes.size()):
		var box: Rect2i = boxes[index]
		boxes[index] = Rect2i(box.position.x, top, box.size.x, bottom - top)
	_view.queue_redraw()

## Sets the selected box's own left/right edge (boxes may overlap).
func set_box_edges(index: int, left: int, right: int) -> void:
	if index < 0 or index >= boxes.size():
		return
	var box: Rect2i = boxes[index]
	var l := clampi(left, 0, source_image.get_width() - 4)
	var r := clampi(right, l + 4, source_image.get_width())
	boxes[index] = Rect2i(l, box.position.y, r - l, box.size.y)
	_view.queue_redraw()

func _align_input(event: InputEvent) -> void:
	var t := _align_transform()
	var s: float = t.scale
	var pivot: Vector2 = t.pivot
	if playing:
		return
	var frame_origin := pivot - Vector2(anchors[selected]) * s
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_drag = {"start": button.position, "last": button.position, "moved": false}
			if tool == "erase":
				erase_at(selected, (button.position - frame_origin) / s, brush)
		else:
			if tool == "anchor" and not _drag.is_empty() and not bool(_drag.moved):
				set_frame_anchor(selected, (button.position - frame_origin) / s)
			_drag = {}
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var motion := event as InputEventMouseMotion
		if tool == "erase":
			erase_at(selected, (motion.position - frame_origin) / s, brush)
			return
		if motion.position.distance_to(_drag.start) > 3.0:
			_drag["moved"] = true
		if bool(_drag.moved):
			var delta: Vector2 = (motion.position - Vector2(_drag.last)) / s
			anchors[selected] = Vector2(anchors[selected]) - delta
			_drag["last"] = motion.position
			_view.queue_redraw()
			_refresh_frame_controls()

# ---------- UI ----------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", _box(Color("15191c"), AMBER_DEEP, 1, 6, 12))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "CLIP IMPORTER"
	title.add_theme_color_override("font_color", AMBER)
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	header.add_child(_status)
	var close_button := _button("Close")
	close_button.tooltip_text = "Close without changing the weapon's clip (Esc)."
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_view = Control.new()
	_view.name = "ClipView"
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(400, 300)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(func() -> void: _view.queue_redraw())
	left.add_child(_view)
	_strip_scroll = ScrollContainer.new()
	_strip_scroll.custom_minimum_size = Vector2(0, 112)
	_strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_strip_scroll)
	_strip_box = HBoxContainer.new()
	_strip_box.add_theme_constant_override("separation", 4)
	_strip_scroll.add_child(_strip_box)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(390, 0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side_scroll.add_child(side)
	side.add_child(_build_source_section())
	side.add_child(_build_slice_section())
	side.add_child(_build_cut_section())
	side.add_child(_build_align_section())
	side.add_child(_build_timing_section())
	side.add_child(_build_save_section())
	_sheet_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open a pose sheet", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_sheet_dialog.file_selected.connect(func(path: String) -> void: open_sheet(path))
	_frames_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILES, "Open frames (one image per frame)", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_frames_dialog.files_selected.connect(func(paths: PackedStringArray) -> void: open_frames(Array(paths)))
	_video_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open a video", PackedStringArray(["*.mp4, *.webm, *.mov, *.gif, *.mkv, *.avi, *.m4v ; Videos"]))
	_video_dialog.file_selected.connect(func(path: String) -> void: open_video(path))

func _build_source_section() -> Control:
	var section := _section("1  SOURCE", "source")
	var body: VBoxContainer = section.get_meta("body")
	body.add_child(_note("A pose sheet (all frames on one image, like a ChatGPT animation sheet), separate frame images, or a video. Poses should face right."))
	var row := HBoxContainer.new()
	body.add_child(row)
	var sheet_button := _button("Pose sheet...")
	sheet_button.tooltip_text = "One image with every pose in a row. Labels, borders and the ground line are ignored."
	sheet_button.pressed.connect(func() -> void: _sheet_dialog.popup_centered_ratio(0.7))
	row.add_child(sheet_button)
	var frames_button := _button("Frames...")
	frames_button.tooltip_text = "Several images, one per frame, played in file-name order."
	frames_button.pressed.connect(func() -> void: _frames_dialog.popup_centered_ratio(0.7))
	row.add_child(frames_button)
	var video_button := _button("Video...")
	video_button.tooltip_text = "MP4, WebM, MOV or GIF. Needs ffmpeg (see below)."
	video_button.pressed.connect(func() -> void: _video_dialog.popup_centered_ratio(0.7))
	row.add_child(video_button)
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	_fps_spin = _spin(1, 60, 1)
	_fps_spin.value = 12
	_fps_spin.tooltip_text = "Frames taken per second of video. 10-15 is plenty for a game attack."
	_add_grid(grid, "Video fps", _fps_spin)
	_max_spin = _spin(1, WeaponClip.MAX_FRAMES, 1)
	_max_spin.value = 24
	_max_spin.tooltip_text = "Stop after this many frames."
	_add_grid(grid, "Max frames", _max_spin)
	_start_spin = _spin(0, 600, 0.1)
	_start_spin.tooltip_text = "Skip this many seconds at the start of the video."
	_add_grid(grid, "Start at (s)", _start_spin)
	_ffmpeg_edit = LineEdit.new()
	_ffmpeg_edit.placeholder_text = "ffmpeg"
	_ffmpeg_edit.text = str(Imp.load_settings().get("ffmpeg", ""))
	_ffmpeg_edit.tooltip_text = "ffmpeg command or full path to ffmpeg.exe. Leave empty to use the one on PATH."
	_ffmpeg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_labeled("ffmpeg", _ffmpeg_edit))
	return section

func _build_slice_section() -> Control:
	var section := _section("2  SLICE", "slice")
	var body: VBoxContainer = section.get_meta("body")
	body.add_child(_note("Magenta lines are the cuts between frames; green lines are the top and bottom of the pose row. Drag them in the picture. Click a box to select it."))
	var row := HBoxContainer.new()
	body.add_child(row)
	_count_spin = _spin(1, WeaponClip.MAX_FRAMES, 1)
	_count_spin.value = 8
	_count_spin.tooltip_text = "How many poses are on the sheet. Changing it re-slices at the emptiest gaps."
	_count_spin.value_changed.connect(func(value: float) -> void:
		if not _loading:
			set_frame_count(int(value)))
	row.add_child(_labeled("Frames", _count_spin))
	var detect := _button("Auto-detect")
	detect.tooltip_text = "Find the pose row and count poses separated by empty space."
	detect.pressed.connect(auto_detect)
	row.add_child(detect)
	var edges := HBoxContainer.new()
	body.add_child(edges)
	_box_left = _spin(0, 16384, 1)
	_box_left.tooltip_text = "Left edge of the selected frame's box. Boxes may overlap when poses do."
	_box_right = _spin(0, 16384, 1)
	_box_right.tooltip_text = "Right edge of the selected frame's box."
	for spin in [_box_left, _box_right]:
		(spin as SpinBox).value_changed.connect(func(_value: float) -> void:
			if not _loading:
				set_box_edges(selected, int(_box_left.value), int(_box_right.value)))
	edges.add_child(_labeled("Box left", _box_left))
	edges.add_child(_labeled("right", _box_right))
	return section

func _build_cut_section() -> Control:
	var section := _section("3  CUT OUT", "cut")
	var body: VBoxContainer = section.get_meta("body")
	_method = OptionButton.new()
	for method in METHODS:
		_method.add_item(str(method.label))
	_method.tooltip_text = "Solid background works for flat backdrops like ChatGPT sheets and needs no ComfyUI. Trellis 2 handles busy backgrounds (one ComfyUI job per frame)."
	body.add_child(_labeled("Method", _method))
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	_tolerance = _spin(1, 160, 1)
	_tolerance.value = Imp.DEFAULT_TOLERANCE
	_tolerance.tooltip_text = "How different from the background a pixel must be to count as the figure. Raise it if a halo is left, lower it if light parts (like slash glows) disappear."
	_add_grid(grid, "Tolerance", _tolerance)
	_min_piece = _spin(0, 100, 0.5)
	_min_piece.value = Imp.DEFAULT_MIN_PIECE * 100.0
	_min_piece.suffix = "%"
	_min_piece.tooltip_text = "Loose pieces smaller than this share of the main figure are removed (dust, motion arrows). 0 keeps everything."
	_add_grid(grid, "Min piece", _min_piece)
	_holes = CheckBox.new()
	_holes.text = "Clear background in gaps"
	_holes.button_pressed = true
	_holes.tooltip_text = "Also removes background showing through gaps, like between the arms and the axe handle."
	body.add_child(_holes)
	_neighbors = CheckBox.new()
	_neighbors.text = "Drop bits of neighbouring poses"
	_neighbors.button_pressed = true
	_neighbors.tooltip_text = "Removes loose pieces touching the left or right edge of a box: the tip of the next pose's weapon, for example."
	body.add_child(_neighbors)
	_cut_button = _button("Cut out frames")
	_amber(_cut_button)
	_cut_button.pressed.connect(func() -> void: cut_out())
	body.add_child(_cut_button)
	return section

func _build_align_section() -> Control:
	var section := _section("4  LINE UP & CLEAN", "align")
	var body: VBoxContainer = section.get_meta("body")
	body.add_child(_note("The green mark is the ground point under the hero (weapon mode: the grip). Each frame is placed so that point lines up. The blue ghost is the previous frame. Arrow keys nudge (Shift = 10 px), Q/E step frames, Space plays."))
	_align_picker = OptionButton.new()
	for entry in ALIGN_MODES:
		_align_picker.add_item(str(entry.label))
	_align_picker.item_selected.connect(func(index: int) -> void:
		if not _loading:
			realign(str(ALIGN_MODES[index].id)))
	body.add_child(_align_picker)
	var tools := HBoxContainer.new()
	body.add_child(tools)
	var group := ButtonGroup.new()
	_tool_anchor = _button("Move / anchor")
	_tool_anchor.toggle_mode = true
	_tool_anchor.button_group = group
	_tool_anchor.button_pressed = true
	_tool_anchor.pressed.connect(func() -> void:
		tool = "anchor"
		_view.queue_redraw())
	tools.add_child(_tool_anchor)
	_tool_erase = _button("Eraser")
	_tool_erase.toggle_mode = true
	_tool_erase.button_group = group
	_tool_erase.tooltip_text = "Paint away stray bits, like a neighbouring pose's weapon."
	_tool_erase.pressed.connect(func() -> void:
		tool = "erase"
		_view.queue_redraw())
	tools.add_child(_tool_erase)
	_brush_spin = _spin(1, 80, 1)
	_brush_spin.value = brush
	_brush_spin.tooltip_text = "Eraser size in source pixels."
	_brush_spin.value_changed.connect(func(value: float) -> void: brush = value)
	tools.add_child(_labeled("Size", _brush_spin))
	var row := HBoxContainer.new()
	body.add_child(row)
	_onion_check = CheckBox.new()
	_onion_check.text = "Ghost of previous frame"
	_onion_check.button_pressed = true
	_onion_check.toggled.connect(func(on: bool) -> void:
		onion = on
		_view.queue_redraw())
	row.add_child(_onion_check)
	var row2 := HBoxContainer.new()
	body.add_child(row2)
	var back_button := _button("Back to slicing")
	back_button.tooltip_text = "Change the source, the cuts or the cutout settings. Cutting out again replaces these frames."
	back_button.pressed.connect(func() -> void:
		step = "slice"
		set_playing(false)
		_refresh())
	row2.add_child(back_button)
	var all_button := _button("Use this spot for all")
	all_button.tooltip_text = "Copy this frame's anchor to every frame (videos and weapon-only frames)."
	all_button.pressed.connect(func() -> void: anchor_to_all(selected))
	row2.add_child(all_button)
	var reset_button := _button("Re-cut frame")
	reset_button.tooltip_text = "Cut this frame out again (undoes erasing)."
	reset_button.pressed.connect(func() -> void: recut_frame(selected))
	row2.add_child(reset_button)
	return section

func _build_timing_section() -> Control:
	var section := _section("5  TIMING & ATTACKS", "timing")
	var body: VBoxContainer = section.get_meta("body")
	body.add_child(_note("Mark the frame where the weapon connects as the hit frame. For a combo, tick \"Starts a new attack\" on the first frame of each later attack: the hero alternates between them. Each attack is sped up or slowed so its hit frame appears exactly when the game deals damage."))
	_frame_label = Label.new()
	_frame_label.add_theme_color_override("font_color", AMBER)
	body.add_child(_frame_label)
	var row := HBoxContainer.new()
	body.add_child(row)
	_hold_spin = _spin(16, 2000, 1)
	_hold_spin.suffix = "ms"
	_hold_spin.tooltip_text = "How long this frame stays on screen before any fitting to the hit time. Hold key poses (wind-up, impact) longer."
	_hold_spin.value_changed.connect(func(value: float) -> void:
		if not _loading:
			set_hold(selected, value))
	row.add_child(_labeled("Hold", _hold_spin))
	_all_hold_spin = _spin(16, 2000, 1)
	_all_hold_spin.suffix = "ms"
	_all_hold_spin.value = WeaponClip.DEFAULT_FRAME_MS
	var all_button := _button("Set all")
	all_button.pressed.connect(func() -> void: set_all_holds(_all_hold_spin.value))
	var row_all := HBoxContainer.new()
	body.add_child(row_all)
	row_all.add_child(_labeled("All frames", _all_hold_spin))
	row_all.add_child(all_button)
	_start_check = CheckBox.new()
	_start_check.text = "Starts a new attack (combo)"
	_start_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_attack_start(selected, on))
	body.add_child(_start_check)
	_hit_check = CheckBox.new()
	_hit_check.text = "Hit frame (damage lands here)"
	_hit_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_hit(selected, on))
	body.add_child(_hit_check)
	_attacks_label = Label.new()
	_attacks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attacks_label.add_theme_font_size_override("font_size", 12)
	_attacks_label.add_theme_color_override("font_color", MUTED)
	body.add_child(_attacks_label)
	_play_check = CheckBox.new()
	_play_check.text = "Play preview (Space)"
	_play_check.toggled.connect(func(on: bool) -> void: set_playing(on))
	body.add_child(_play_check)
	return section

func _build_save_section() -> Control:
	var section := _section("6  USE AS", "save")
	var body: VBoxContainer = section.get_meta("body")
	_mode_picker = OptionButton.new()
	for id in WeaponClip.MODES:
		_mode_picker.add_item(str(WeaponClip.MODE_LABELS[id]))
	_mode_picker.tooltip_text = "Hero attack: the frames show the whole hero and replace its attack animation (the held weapon hides while it plays). Weapon frames: the frames show only the weapon and replace its picture during the swing."
	_mode_picker.item_selected.connect(func(index: int) -> void:
		mode = str(WeaponClip.MODES[index])
		_refresh_frame_controls()
		_view.queue_redraw())
	body.add_child(_mode_picker)
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	_height_spin = _spin(0, 8192, 1)
	_height_spin.suffix = "px"
	_height_spin.tooltip_text = "How tall the hero stands in the frames (measured from frame 1). The clip is scaled so this matches the hero's height in the game."
	_height_spin.value_changed.connect(func(value: float) -> void:
		if not _loading:
			body_height = value)
	_add_grid(grid, "Hero height", _height_spin)
	_scale_spin = _spin(0.1, 8, 0.05)
	_scale_spin.value = 1.0
	_scale_spin.tooltip_text = "Extra size multiplier in the game."
	_scale_spin.value_changed.connect(func(value: float) -> void:
		if not _loading:
			clip_scale = value)
	_add_grid(grid, "Scale", _scale_spin)
	_name_edit = LineEdit.new()
	_name_edit.text = "Attack"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_labeled("Name", _name_edit))
	_save_button = _button("Save clip to weapon")
	_amber(_save_button)
	_save_button.pressed.connect(func() -> void: save_clip())
	body.add_child(_save_button)
	return section

func _refresh() -> void:
	if _view == null:
		return
	_loading = true
	var has_cut := not cut.is_empty()
	var aligning := step == "align" and has_cut
	_sections["source"].visible = not aligning
	_sections["slice"].visible = source_kind == "sheet" and not aligning
	_sections["cut"].visible = not source_kind.is_empty() and not aligning
	_sections["align"].visible = has_cut
	_sections["timing"].visible = has_cut
	_sections["save"].visible = has_cut
	_count_spin.value = maxi(1, boxes.size())
	_cut_button.disabled = busy or source_kind.is_empty()
	_cut_button.text = "Cutting out..." if busy else ("Cut out frames again" if has_cut else "Cut out frames")
	_save_button.disabled = busy or not has_cut
	for index in range(ALIGN_MODES.size()):
		if ALIGN_MODES[index].id == align_mode:
			_align_picker.select(index)
	_mode_picker.select(maxi(0, WeaponClip.MODES.find(mode)))
	_height_spin.value = body_height
	_scale_spin.value = clip_scale
	_loading = false
	_rebuild_strip()
	_refresh_frame_controls()
	_view.queue_redraw()

func _refresh_frame_controls() -> void:
	if _view == null:
		return
	_loading = true
	if source_kind == "sheet" and selected < boxes.size():
		var box: Rect2i = boxes[selected]
		_box_left.value = box.position.x
		_box_right.value = box.end.x
	if not cut.is_empty() and selected < cut.size():
		_frame_label.text = "Frame %d of %d" % [selected + 1, cut.size()]
		_hold_spin.value = float(holds[selected]) if selected < holds.size() else WeaponClip.DEFAULT_FRAME_MS
		_start_check.disabled = selected == 0
		_start_check.button_pressed = selected == 0 or starts.has(selected)
		_hit_check.button_pressed = _is_hit(selected)
	_loading = false
	_refresh_attacks()
	_refresh_strip_labels()

func _is_hit(index: int) -> bool:
	for attack in current_attacks():
		if int(attack.hit) == index:
			return true
	return false

func _refresh_attacks() -> void:
	if _attacks_label == null or cut.is_empty():
		return
	var clip := preview_clip()
	var lines: Array = []
	var attacks := current_attacks()
	for index in range(attacks.size()):
		var line := WeaponClip.timeline(clip, index, hit_seconds)
		var text := "Attack %d: %s" % [index + 1, WeaponClip.describe_attack(clip, index, hit_seconds)]
		if float(line.length) > attack_interval + 0.001:
			text += "  - longer than the %.2f s between attacks, so the next attack cuts it off" % attack_interval
		lines.append(text)
	if hit_seconds <= 0.0:
		lines.append("Ranged weapon: clips play at their own speed and the shot fires as the attack starts.")
	_attacks_label.text = "\n".join(lines)

func _rebuild_strip() -> void:
	for child in _strip_box.get_children():
		child.queue_free()
	var textures: Array = cut_textures if not cut_textures.is_empty() else frame_source_textures
	for index in range(textures.size()):
		var button := Button.new()
		button.icon = textures[index]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(76, 100)
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(func() -> void: select_frame(index))
		_strip_box.add_child(button)
	_refresh_strip_labels()

func _refresh_strip_labels() -> void:
	if _strip_box == null:
		return
	var attacks := current_attacks()
	for index in range(_strip_box.get_child_count()):
		var button := _strip_box.get_child(index) as Button
		var tags := str(index + 1)
		if not cut.is_empty():
			for number in range(attacks.size()):
				if int(attacks[number].start) == index and attacks.size() > 1:
					tags += " A%d" % (number + 1)
				if int(attacks[number].hit) == index:
					tags += " HIT"
		button.text = tags
		button.add_theme_color_override("font_color", AMBER if index == selected else INK)

func _method_id() -> String:
	return str(METHODS[maxi(0, _method.selected)].id) if _method != null else "solid"

func _fail(message: String) -> bool:
	last_error = message
	_set_status(message, BAD)
	return false

func _set_status(text: String, color: Color = MUTED) -> void:
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", color)

# ---------- widgets ----------

func _section(title: String, key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 1, 4, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", AMBER)
	column.add_child(heading)
	panel.set_meta("body", column)
	_sections[key] = panel
	return panel

func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(340, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _labeled(caption: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	row.add_child(control)
	return row

func _add_grid(grid: GridContainer, caption: String, control: Control) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	grid.add_child(label)
	grid.add_child(control)

func _spin(minimum: float, maximum: float, step_size: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_size
	spin.custom_minimum_size = Vector2(86, 0)
	return spin

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	return button

func _amber(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(AMBER_DEEP, AMBER, 1, 3, 6))
	button.add_theme_stylebox_override("hover", _box(AMBER, Color("f7bb58"), 1, 3, 6))
	button.add_theme_color_override("font_color", Color("15181b"))
	button.add_theme_color_override("font_hover_color", Color("15181b"))

func _box(fill: Color, border: Color, border_width: int, radius: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

func _file_dialog(file_mode: int, title: String, filters: PackedStringArray) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = file_mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = title
	dialog.filters = filters
	add_child(dialog)
	return dialog
