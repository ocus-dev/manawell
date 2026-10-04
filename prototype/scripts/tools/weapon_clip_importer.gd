extends Control

## The Weapon Lab's clip importer: a full-screen overlay that turns a pose
## sheet (for example one made in ChatGPT), a set of frame images, or a video
## into a weapon attack clip. Steps: open a source, slice the sheet into
## frames, cut every frame out (flat background locally, or Trellis 2 through
## ComfyUI), line the frames up, set timing and which frames start an attack
## and land the hit, then save. The engine lives in weapon_clip_import.gd.

## `target`: "weapon" (this weapon's own animation) or "type" (the default
## for every weapon of its type).
signal saved(clip: Dictionary, target: String)
signal closed
## Hero purpose: the frames become the hero's own idle, walk or attack.
signal hero_saved(clip: Dictionary, animation: String, still_frame: int)

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
	{"id": "body", "label": "Line up the body (walk and idle cycles: the torso stays put)"},
]

## Set by the lab.
var comfy: Node
## "weapon" (an attack animation for weapons) or "hero" (the hero's own
## idle / walk / attack art, see start_hero()).
var purpose := "weapon"
## Weapon purpose: which of the weapon's animations this is: "attack", or a
## looping "idle" / "walk" (no hit frames; see start_pose()).
var clip_animation := "attack"
const POSE_WORDS := {"idle": "standing (idle)", "walk": "walking"}
var hero_target := "walk"
## Hero purpose: the animations the frames can replace ([state, label]).
## States without art fall back in the game (see SideViewActorVisual).
const HERO_STATE_CHOICES := [
	["idle", "Idle (standing)"],
	["walk", "Walk"],
	["attack", "Attack (the normal attack, for weapons without their own)"],
	["dash", "Dash"],
	["hurt", "Hurt (hit reaction)"],
	["death", "Death"],
	["jump", "Jump (rising)"],
	["fall", "Fall"],
	["spawn", "Spawn (entering)"],
	["windup", "Wind-up (before an attack)"],
]
const HERO_STATE_WORDS := {"idle": "standing (idle)", "walk": "walking", "attack": "attacking", "dash": "dashing", "hurt": "getting hit", "death": "dying", "jump": "jumping (rising)", "fall": "falling", "spawn": "arriving", "windup": "winding up an attack"}
## Line-up used when frames are cut out ("feet" unless a hero cycle).
var default_align := "feet"
var still_only := false
var _title: Label
var _hero_box: Control
var _hero_picker: OptionButton
var _still_check: CheckBox
## Hero purpose: the front fist on each frame (frame pixels, or null), so a
## held weapon can ride along with the hand. See mark_fist().
var hand_track: Array = []
var _fist_status: Label
var weapon_id := ""
## The weapon's type label ("Axe"); empty hides "Save as default".
var type_label := ""
## True when editing a type default: saving goes back to the default.
var editing_default := false
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
## Which pose owns each pixel of the strip (shape detection), or empty.
var owners := PackedByteArray()
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
## hero_weapon: where the weapon sits in each cut frame, in that frame's
## pixels: {grip: Vector2 or null, tip: Vector2 or null, behind: bool}.
var track: Array = []
## Next click with the Place weapon tool: "grip" or "tip".
var weapon_step := "grip"
## Reference sheet (the same animation with the weapon drawn in), shown as a
## ghost behind each frame so the grip and far end are easy to click.
var ref_cut: Array = []
var ref_textures: Array = []
var ref_anchors: Array = []
var ref_offsets: Array = []
var ref_scale := 1.0
var show_ref := true
## The weapon being edited in the lab, drawn in the hands as you place it:
## {texture, grip (0-1), tip (px)}.
var preview_weapon: Dictionary = {}
## Front hand: per frame an L8 mask of the hand drawn over the weapon (or
## null), whether the user painted it (so moving the grip won't redo it), and
## the masked picture for drawing.
var front_hand := true
var hand_masks: Array = []
var hand_painted: Array = []
var hand_textures: Array = []
## The masked picture behind each hand texture, kept so brush strokes can
## update just the painted area.
var hand_pictures: Array = []
var _hand_uploads: Dictionary = {}
## Frames Auto-place wasn't sure about (worth a look).
var auto_unsure: Array = []
## Quick setup: two sheets (empty hands + the same poses with the weapon) and
## one button. `advanced` shows every step instead (More options).
var advanced := false
var quick_body_path := ""
var quick_weapon_path := ""
## Frames okayed in the quick check ("Looks right").
var checked: Array = []
## Draw the weapon at one size on every frame (the middle length), so it
## doesn't grow and shrink with ChatGPT's drawings.
var steady_size := false
## Holds from Imp.snappy_holds: wind-up and hit held, the swing itself fast.
var snappy := false
## Blink between the two sheets to check how they line up.
var blink := false
var _blink_time := 0.0
var _blink_ref := false
var quick_busy := false
var _quick_intro: Label
var _quick_body_label: Label
var _quick_weapon_label: Label
var _quick_run_button: Button
var _quick_check: Control
var _quick_frame_label: Label
var _quick_behind: CheckBox
var _quick_blink: CheckBox
var _quick_steady: CheckBox
var _quick_snappy: CheckBox
var _quick_hit_label: Label
var _quick_hit_button: Button
var _quick_save: Control
var _quick_save_default: Button
var _quick_save_weapon: Button
var _quick_more: Button
var _quick_play: Button
var _quick_body_dialog: FileDialog
var _quick_weapon_dialog: FileDialog
## Weapons to pick from for the preview (set by the lab), and the pick.
var preview_options: Array = []
var preview_choice := ""
var _preview_picker: OptionButton
var _tip_cache: Dictionary = {}
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
var _save_default_button: Button
var _tool_group := ButtonGroup.new()
var _weapon_free_check: CheckBox
var _tool_weapon: Button
var _tool_reference: Button
var _ref_dialog: FileDialog
var _ref_status: Label
var _ref_scale_spin: SpinBox
var _show_ref_check: CheckBox
var _behind_check: CheckBox
var _weapon_status: Label
var _weapon_controls: Control
var _front_hand_check: CheckBox
var _tool_hand: Button
var _auto_status: Label
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
## Line-up view zoom and pan (mouse wheel / right-drag; F or Fit resets).
var view_zoom := 1.0
var view_pan := Vector2.ZERO
var _pan_drag := false

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
	if blink and not playing:
		_blink_time += delta
		if _blink_time >= 0.45:
			_blink_time = 0.0
			_blink_ref = not _blink_ref
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
		KEY_F:
			fit_view()
		KEY_ENTER, KEY_KP_ENTER:
			if is_quick() and placed_count() > 0:
				approve_frame()
			else:
				handled = false
		KEY_EQUAL, KEY_KP_ADD:
			zoom_view(1.25, _view.size * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_view(0.8, _view.size * 0.5)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

# ---------- opening sources ----------

## Opens the importer on a new, empty clip for `new_weapon_id`.
func start(new_weapon_id: String, new_hit_seconds: float, new_interval: float, new_purpose: String = "weapon") -> void:
	purpose = new_purpose
	clip_animation = "attack"
	default_align = "feet"
	weapon_id = new_weapon_id
	hit_seconds = new_hit_seconds
	attack_interval = new_interval
	quick_body_path = ""
	quick_weapon_path = ""
	advanced = bool(Imp.load_settings().get("advanced", false))
	_reset()
	visible = true
	_set_status("Open a pose sheet, a set of frames, or a video to begin.")
	_refresh()

## Opens the importer on a new weapon idle or walk: a looping animation of
## the hero holding the weapon (whole hero with the weapon drawn in, or a
## weapon-free sheet with each weapon placed in the hands).
func start_pose(new_weapon_id: String, animation: String, new_interval: float = 1.0) -> void:
	start(new_weapon_id, 0.0, new_interval)
	clip_animation = animation if POSE_WORDS.has(animation) else "idle"
	# Cycles keep the torso still, like the hero's own idle and walk.
	default_align = "body"
	align_mode = default_align
	if _name_edit != null:
		_name_edit.text = clip_animation.capitalize()
	_set_status("Open a sheet of the hero %s with the weapon (side view, facing right), frame images, or a video. For one animation that fits every weapon of a type, use a weapon-free sheet and place the weapon in the hands." % str(POSE_WORDS[clip_animation]))
	_refresh()

func is_pose() -> bool:
	return purpose == "weapon" and clip_animation != "attack"
## Opens the importer for the hero's own art (no weapon in the hands).
## animation: one of HERO_STATE_CHOICES (SideViewVisualConfig.STATES).
func start_hero(animation: String = "walk") -> void:
	start("_hero", 0.0, 1.0, "hero")
	hero_target = animation
	still_only = false
	# Walk and idle cycles keep the torso in place; attacks line up the feet.
	default_align = "body" if ["idle", "walk", "dash"].has(animation) else "feet"
	if _name_edit != null:
		_name_edit.text = "Hero " + animation
	_set_status("Open a sheet of the hero %s (side view, facing right, no weapon: empty hands closed as if gripping), frame images, or a video." % str(HERO_STATE_WORDS.get(animation, animation)))
	_refresh()

## The front fist on `index`. With no fist marked yet (or `track_all`), it is
## found on every frame from there; otherwise only this frame changes.
func mark_fist(index: int, point: Vector2, track_all: bool = false) -> void:
	if cut.is_empty() or index < 0 or index >= cut.size():
		return
	if hand_track.size() != cut.size():
		hand_track = []
		hand_track.resize(cut.size())
	var any := hand_track.any(func(p: Variant) -> bool: return p is Vector2)
	if track_all or not any:
		hand_track = Imp.track_patch(cut, index, point)
		_set_status("Front fist found on all %d frames. Step through them (Q/E) and click to fix any that are off." % cut.size(), GOOD)
	else:
		hand_track[index] = point
		_set_status("Front fist moved on frame %d." % (index + 1), GOOD)
	_refresh()

func fist_count() -> int:
	return hand_track.filter(func(p: Variant) -> bool: return p is Vector2).size()

## Saves the frames as the hero's idle, walk or attack (hero purpose).
func save_hero() -> Dictionary:
	if cut.is_empty():
		_fail("Cut out the frames first.")
		return {}
	mode = "hero"
	_save_project()
	var clip := build_clip()
	if clip.is_empty():
		_fail("Couldn't pack the frames into a sheet.")
		return {}
	hero_saved.emit(clip, hero_target, selected if still_only else -1)
	visible = false
	closed.emit()
	return clip

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
	owners = PackedByteArray()
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
	align_mode = default_align
	track = []
	weapon_step = "grip"
	ref_cut = []
	ref_textures = []
	ref_anchors = []
	ref_offsets = []
	ref_scale = 1.0
	front_hand = true
	hand_masks = []
	hand_painted = []
	hand_textures = []
	hand_pictures = []
	auto_unsure = []
	hand_track = []
	checked = []
	steady_size = false
	snappy = false
	blink = false
	_blink_ref = false
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
	align_mode = default_align
	var layout := Imp.detect_layout(image, 0)
	_apply_layout(layout)
	var guessed := boxes.size()
	step = "slice"
	_refresh()
	if guessed <= 1:
		_set_status("Couldn't tell how many poses are on the sheet (they touch). Set Frames to the number of poses; the cuts move to the emptiest gaps.", AMBER)
	elif not owners.is_empty():
		_set_status("Found %d poses as separate shapes, so overlapping swords and feet won't bleed into the next frame. Press Cut out frames." % guessed, GOOD)
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
	owners = layout.get("owners", PackedByteArray())
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
	if track.size() != cut.size():
		track = []
		for _i in range(cut.size()):
			track.append(_empty_track())
	hand_masks = []
	hand_painted = []
	hand_textures = []
	hand_pictures = []
	auto_unsure = []
	_ensure_hand_arrays()
	realign()
	body_height = Imp.figure_height(cut[0]) if not cut.is_empty() else 0.0
	busy = false
	selected = 0
	step = "align"
	_refresh()
	_set_status(("Cut out %d frames. Check the line-up (Space plays it), erase stray bits, set the frame timing, then save." if purpose == "hero" else "Cut out %d frames. Line them up, erase stray bits, then set timing and the hit frame.") % cut.size(), GOOD)
	return true

## The cutout for frame `index` with the local methods.
func cut_frame_now(index: int, options: Dictionary) -> Image:
	if source_kind == "sheet":
		var local := options.duplicate()
		local["background"] = background
		_add_owners(local, index)
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
	elif image.get_size() == boxes[index].size:
		_add_owners(local, index)
		image = Imp.clear_other_owners(image, boxes[index], local)
	return Imp.filter_pieces(image, local)

func _add_owners(options: Dictionary, index: int) -> void:
	if owners.is_empty() or boxes.size() <= index:
		return
	options["owners"] = owners
	options["owner_strip"] = strip
	options["frame"] = index

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
			var feet := Imp.feet_anchor(cut[index], ground)
			if align_mode == "body":
				feet.x = Imp.body_center_x(cut[index])
			anchors.append(feet)
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
	cut[index].remove_meta("visible_height")
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
	if _quick_play != null:
		_quick_play.set_pressed_no_signal(playing)
	if _view != null:
		_view.queue_redraw()

## Frame shown `time` seconds into the looping combo preview (-1 in the gaps).
func preview_frame_at(time: float) -> int:
	var clip := preview_clip()
	if is_pose():
		return WeaponClip.loop_frame_at(clip, time)
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
		if (name.begins_with("sheet_") or name.begins_with("hand_")) and name.ends_with(".png"):
			DirAccess.remove_absolute(project_dir.path_join(name))
	if (packed.image as Image).save_png(sheet_path) != OK:
		return {}
	# The front hand packs exactly like the body sheet.
	var hand_path := ""
	_ensure_hand_arrays()
	if mode == "hero_weapon" and front_hand and hand_masks.any(func(m: Variant) -> bool: return m != null):
		var hands: Array = []
		for index in range(cut.size()):
			var mask: Variant = hand_masks[index]
			var behind := index < track.size() and bool(track[index].behind)
			if mask == null or behind:
				hands.append(Image.create_empty(cut[index].get_width(), cut[index].get_height(), false, Image.FORMAT_RGBA8))
			else:
				hands.append(Imp.masked(cut[index], mask))
		var hand_packed := Imp.pack(hands, anchors, Imp.MAX_CELL, cut)
		hand_path = project_dir.path_join("hand_%d.png" % Time.get_ticks_msec())
		if hand_packed.is_empty() or (hand_packed.image as Image).save_png(hand_path) != OK:
			hand_path = ""
	var scale := float(packed.scale)
	var cell_track: Array = []
	if mode == "hero_weapon":
		var packed_anchor := Vector2(float(packed.anchor[0]), float(packed.anchor[1]))
		for index in range(cut.size()):
			var entry: Dictionary = track[index] if index < track.size() else _empty_track()
			if not entry.grip is Vector2 or not entry.tip is Vector2:
				cell_track.append(null)
				continue
			var grip: Vector2 = (Vector2(entry.grip) - Vector2(anchors[index])) * scale + packed_anchor
			var along: Vector2 = Vector2(effective_tip(index)) - Vector2(entry.grip)
			cell_track.append({"grip": [grip.x, grip.y], "angle": rad_to_deg(along.angle()), "length": along.length() * scale, "behind": bool(entry.behind)})
	var cell_hands: Array = []
	if purpose == "hero" and hand_track.size() == cut.size() and fist_count() == cut.size():
		var hand_anchor := Vector2(float(packed.anchor[0]), float(packed.anchor[1]))
		for index in range(cut.size()):
			var fist: Vector2 = (Vector2(hand_track[index]) - Vector2(anchors[index])) * float(packed.scale) + hand_anchor
			cell_hands.append([fist.x, fist.y])
	var label := _name_edit.text.strip_edges() if _name_edit != null and not _name_edit.text.strip_edges().is_empty() else ("Attack" if not is_pose() else clip_animation.capitalize())
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
		"track": cell_track,
		"hand_source": hand_path,
		"hand_track": cell_hands,
	})

func save_clip(target: String = "") -> Dictionary:
	if target.is_empty():
		target = "type" if editing_default else "weapon"
	if cut.is_empty():
		_fail("Cut out the frames first.")
		return {}
	if mode == "hero_weapon" and placed_count() == 0:
		_fail("Place the weapon in the hands on at least one frame first (Place weapon tool: click the hand, then the far end of the weapon).")
		return {}
	if is_pose() and mode == "weapon":
		_fail("An idle or walk shows the hero: pick \"Hero attack (whole hero + weapon)\" or \"Hero body + each weapon's own art\" in step 6.")
		return {}
	_save_project()
	var clip := build_clip()
	if clip.is_empty():
		_fail("Couldn't pack the frames into a sheet.")
		return {}
	saved.emit(clip, target)
	_set_status("Saved.", GOOD)
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
		var frame_entry := {"file": file, "anchor": [Vector2(anchors[index]).x, Vector2(anchors[index]).y]}
		if index < hand_masks.size() and hand_masks[index] is Image:
			var hand_file := "frames/handmask_%03d.png" % index
			(hand_masks[index] as Image).save_png(project_dir.path_join(hand_file))
			frame_entry["hand"] = hand_file
			frame_entry["hand_painted"] = bool(hand_painted[index])
		frames.append(frame_entry)
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
		"track": _track_to_json(),
		"front_hand": front_hand,
		"animation": clip_animation,
		"steady_size": steady_size,
		"snappy": snappy,
		"checked": checked.duplicate(),
		"reference": {"frames": ref_cut.size(), "offsets": ref_offsets.map(func(v: Vector2) -> Array: return [v.x, v.y]), "scale": ref_scale},
	})

## Reopens a saved clip project for editing.
func load_project(dir: String, new_weapon_id: String, new_hit_seconds: float, new_interval: float) -> bool:
	var project := Imp.load_project(dir)
	if project.is_empty():
		return _fail("That clip's importer project wasn't found (%s)." % dir)
	start(new_weapon_id, new_hit_seconds, new_interval)
	clip_animation = str(project.get("animation", "attack"))
	if not ["attack", "idle", "walk"].has(clip_animation):
		clip_animation = "attack"
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
	if source_image != null and not boxes.is_empty():
		var layout := Imp.detect_layout(source_image, boxes.size())
		owners = layout.get("owners", PackedByteArray()) if layout.get("strip") == strip else PackedByteArray()
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
	track = []
	for entry in project.get("track", []):
		track.append(_track_from_json(entry))
	while track.size() < cut.size():
		track.append(_empty_track())
	front_hand = bool(project.get("front_hand", true))
	steady_size = bool(project.get("steady_size", false))
	snappy = bool(project.get("snappy", false))
	checked = []
	for value in project.get("checked", []):
		checked.append(bool(value))
	while checked.size() < cut.size():
		checked.append(false)
	_ensure_hand_arrays()
	var frame_entries: Array = project.get("frames", [])
	for index in range(mini(frame_entries.size(), cut.size())):
		var entry: Dictionary = frame_entries[index]
		if str(entry.get("hand", "")).is_empty():
			continue
		var mask := Image.load_from_file(dir.path_join(str(entry.hand)))
		if mask == null or mask.is_empty():
			continue
		mask.convert(Image.FORMAT_L8)
		hand_masks[index] = mask
		hand_painted[index] = bool(entry.get("hand_painted", false))
		if not hand_painted[index] and track[index].grip is Vector2:
			mask.set_meta("grip", track[index].grip)
		_update_hand_texture(index)
	var reference: Dictionary = project.get("reference", {})
	if FileAccess.file_exists(dir.path_join("reference.png")) and int(reference.get("frames", 0)) > 0:
		_load_reference_frames(dir.path_join("reference.png"))
		ref_scale = float(reference.get("scale", ref_scale))
		var offsets: Array = reference.get("offsets", [])
		for index in range(mini(offsets.size(), ref_offsets.size())):
			ref_offsets[index] = Vector2(float(offsets[index][0]), float(offsets[index][1]))
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

# ---------- weapon in the hands ----------

## The lab's weapons for the preview picker; `choice` is the id to show first.
func set_preview_options(options: Array, choice: String = "") -> void:
	preview_options = options
	var saved := str(Imp.load_settings().get("preview_weapon", ""))
	var pick := choice
	if not saved.is_empty() and (saved == "__bar__" or options.any(func(o: Dictionary) -> bool: return str(o.id) == saved)):
		pick = saved
	choose_preview(pick, false)

## Shows `id`'s art in the hands ("__bar__" = a plain bar).
func choose_preview(id: String, remember: bool = true) -> void:
	preview_weapon = {}
	preview_choice = "__bar__"
	for option in preview_options:
		if str(option.id) == id or (id.is_empty() and preview_weapon.is_empty() and id != "__bar__"):
			var texture: Texture2D = option.texture
			var key := "%d|%s|%s" % [texture.get_instance_id(), str(option.grip), str(option.get("fit", {}).get("tip", ""))]
			if not _tip_cache.has(key):
				_tip_cache[key] = WeaponClip.resolve_tip(texture.get_image(), option.grip, option.get("fit", {}))
			preview_weapon = {"texture": texture, "grip": option.grip, "tip": _tip_cache[key], "fit": option.get("fit", {})}
			preview_choice = str(option.id)
			break
	if remember:
		var settings := Imp.load_settings()
		settings["preview_weapon"] = preview_choice
		Imp.save_settings(settings)
	_refresh_preview_picker()
	if _view != null:
		_view.queue_redraw()

func _refresh_preview_picker() -> void:
	if _preview_picker == null:
		return
	var was := _loading
	_loading = true
	_preview_picker.clear()
	for option in preview_options:
		_preview_picker.add_item(str(option.label))
		_preview_picker.set_item_metadata(_preview_picker.item_count - 1, str(option.id))
		if str(option.id) == preview_choice:
			_preview_picker.select(_preview_picker.item_count - 1)
	_preview_picker.add_item("Plain bar")
	_preview_picker.set_item_metadata(_preview_picker.item_count - 1, "__bar__")
	if preview_choice == "__bar__":
		_preview_picker.select(_preview_picker.item_count - 1)
	_loading = was

# ---------- auto-place and front hand ----------

func _ensure_hand_arrays() -> void:
	while hand_masks.size() < cut.size():
		hand_masks.append(null)
		hand_painted.append(false)
		hand_textures.append(null)
	while hand_pictures.size() < hand_masks.size():
		hand_pictures.append(null)
	if hand_masks.size() > cut.size():
		hand_masks.resize(cut.size())
		hand_painted.resize(cut.size())
		hand_textures.resize(cut.size())
		hand_pictures.resize(cut.size())

## Finds the weapon in the ghost and places it in the hands on `frames`
## (default: every frame), lines the ghost up, marks "behind the body", and
## makes the front hand. Needs the sheet with the weapon loaded.
func auto_place(frames: Array = []) -> int:
	if not _auto_ready():
		return 0
	var targets: Array = frames if not frames.is_empty() else range(cut.size())
	var palette := Imp.body_palette(cut)
	auto_unsure = auto_unsure.filter(func(i: int) -> bool: return not targets.has(i))
	var placed := 0
	for index in targets:
		if _auto_place_frame(index, palette):
			placed += 1
	_finish_auto_place(placed, targets.size())
	return placed

func _auto_ready() -> bool:
	if cut.is_empty() or ref_cut.size() != cut.size():
		_fail("Load the sheet with the weapon first (Sheet with weapon...), then Auto-place.")
		return false
	if mode != "hero_weapon":
		set_weapon_free(true)
	_ensure_hand_arrays()
	return true

## Lines the ghost up on frame `index` and places the weapon there.
func _auto_place_frame(index: int, palette: PackedByteArray) -> bool:
	var body: Image = cut[index]
	var offset := Imp.align_reference(body, anchors[index], ref_cut[index], ref_anchors[index], ref_scale, ref_offsets[index])
	ref_offsets[index] = offset
	var found := Imp.find_weapon(body, anchors[index], ref_cut[index], ref_anchors[index], ref_scale, offset, palette)
	if not bool(found.get("ok", false)):
		auto_unsure.append(index)
		return false
	track[index] = {"grip": found.grip, "tip": found.tip, "behind": bool(found.behind)}
	var length := Vector2(found.grip).distance_to(found.tip)
	var figure := Imp.figure_height(body)
	# Short weapons, a "hand" down at the legs, or the old finder's guess
	# usually mean a miss.
	if length < figure * 0.25 or float(found.grip.y) > Vector2(anchors[index]).y - figure * 0.28 or str(found.get("how", "")) == "classic":
		auto_unsure.append(index)
	hand_painted[index] = false
	_auto_hand(index)
	return true

func _finish_auto_place(placed: int, total: int) -> void:
	# A weapon is one size: a frame whose weapon is much longer or shorter
	# than the rest probably found something else.
	var lengths: Array = []
	for entry in track:
		if entry.grip is Vector2 and entry.tip is Vector2:
			lengths.append(Vector2(entry.grip).distance_to(entry.tip))
	if lengths.size() >= 3:
		lengths.sort()
		var middle: float = lengths[lengths.size() / 2]
		for index in range(track.size()):
			var entry: Dictionary = track[index]
			if entry.grip is Vector2 and entry.tip is Vector2:
				var ratio := Vector2(entry.grip).distance_to(entry.tip) / maxf(1.0, middle)
				if (ratio < 0.6 or ratio > 1.6) and not auto_unsure.has(index):
					auto_unsure.append(index)
	auto_unsure.sort()
	front_hand = true
	_after_track_changed()
	_refresh()
	var message := "Auto-placed the weapon on %d of %d frames." % [placed, total]
	if not auto_unsure.is_empty():
		message += " Check frame%s %s: drag the green (hand) and orange (far end) dots if they're off." % ["" if auto_unsure.size() == 1 else "s", ", ".join(auto_unsure.map(func(i: int) -> String: return str(i + 1)))]
	else:
		message += " Step through the frames (Q/E) and drag any dot that's off."
	_set_status(message, GOOD if auto_unsure.is_empty() else AMBER)

# ---------- quick setup ----------

## Quick setup is the default for weapon animations; More options shows
## every step (slicing, cut-out settings, the hand brush, ...).
func is_quick() -> bool:
	return purpose == "weapon" and not advanced

func set_advanced(on: bool) -> void:
	advanced = on
	var settings := Imp.load_settings()
	settings["advanced"] = on
	Imp.save_settings(settings)
	_refresh()

## `which`: "body" (the empty-hands sheet) or "weapon" (the same poses with
## the weapon drawn in).
func set_quick_sheet(which: String, path: String) -> void:
	if which == "body":
		quick_body_path = path
	else:
		quick_weapon_path = path
	if not path.is_empty():
		var settings := Imp.load_settings()
		settings["last_dir"] = path.get_base_dir()
		Imp.save_settings(settings)
	_refresh()
	if quick_body_path.is_empty():
		_set_status("Now pick the sheet with empty hands (1).")
	elif quick_weapon_path.is_empty():
		_set_status("Now pick the same poses with the weapon (2).")
	else:
		_set_status("Both sheets picked. Press \"Line up & place the weapon\".", GOOD)

## Quick setup in one go: cuts out the empty-hands sheet, loads the sheet with
## the weapon as the ghost, lines each pair of frames up, places the weapon in
## the hands on every frame, keeps it one size, and guesses the hit frame and a
## snappy timing. Coroutine.
func quick_run() -> bool:
	if quick_busy or busy:
		return false
	if quick_body_path.is_empty() or quick_weapon_path.is_empty():
		return _fail("Pick both sheets first: the poses with empty hands (1) and the same poses with the weapon (2).")
	quick_busy = true
	var body_path := quick_body_path
	var weapon_path := quick_weapon_path
	_set_status("Finding the poses on the empty-hands sheet...")
	if is_inside_tree():
		await get_tree().process_frame
	var opened := open_sheet(body_path)
	quick_body_path = body_path
	quick_weapon_path = weapon_path
	if not opened:
		return _quick_stop()
	if boxes.size() <= 1:
		_fail("Couldn't find separate poses on the empty-hands sheet (they touch). Open More options and set the number of frames.")
		return _quick_stop()
	if not await cut_out():
		return _quick_stop()
	set_weapon_free(true)
	_set_status("Lining up the sheet with the weapon...")
	if is_inside_tree():
		await get_tree().process_frame
	if not open_reference(weapon_path):
		last_error += " Both sheets need the same poses in the same order."
		_set_status(last_error, BAD)
		return _quick_stop()
	if not _auto_ready():
		return _quick_stop()
	var palette := Imp.body_palette(cut)
	auto_unsure = []
	var placed := 0
	for index in range(cut.size()):
		_set_status("Finding the weapon on frame %d of %d..." % [index + 1, cut.size()])
		if is_inside_tree():
			await get_tree().process_frame
		if _auto_place_frame(index, palette):
			placed += 1
	steady_size = true
	if not is_pose():
		var hit := Imp.guess_hit(track, anchors)
		if hit >= 0:
			starts = []
			hits = [hit]
			snappy = true
			holds = Imp.snappy_holds(track, anchors, hit, WeaponClip.DEFAULT_FRAME_MS)
	checked = []
	for _i in range(cut.size()):
		checked.append(false)
	_finish_auto_place(placed, cut.size())
	tool = "weapon"
	quick_busy = false
	select_frame(int(auto_unsure[0]) if not auto_unsure.is_empty() else 0)
	_refresh()
	var message := "Weapon placed on %d of %d frames. Step through them: if the green dot is in the fist and the orange dot on the far end of the gold weapon, press Looks right (Enter)." % [placed, cut.size()]
	if not auto_unsure.is_empty():
		message = "Weapon placed on %d of %d frames. Frame%s %s marked ? need a look: drag the dots onto the gold weapon, then press Looks right (Enter)." % [placed, cut.size(), "" if auto_unsure.size() == 1 else "s", ", ".join(auto_unsure.map(func(i: int) -> String: return str(i + 1)))]
	_set_status(message, GOOD if auto_unsure.is_empty() else AMBER)
	return true

func _quick_stop() -> bool:
	quick_busy = false
	busy = false
	_refresh()
	return false

## "Looks right": marks the frame checked and moves on to the next one that
## isn't (frames marked ? first).
func approve_frame() -> void:
	if cut.is_empty():
		return
	while checked.size() < cut.size():
		checked.append(false)
	var approved := selected
	checked[approved] = true
	auto_unsure.erase(approved)
	var next := -1
	for offset in range(1, cut.size() + 1):
		var index := (selected + offset) % cut.size()
		if not bool(checked[index]):
			next = index
			break
	if next < 0:
		_refresh_strip_labels()
		_refresh_frame_controls()
		_set_status("Every frame checked. Press Play (Space) to watch it, then save.", GOOD)
		return
	select_frame(next)
	_set_status("Frame %d okayed. Now frame %d%s." % [approved + 1, selected + 1, " (marked ?: check it closely)" if auto_unsure.has(selected) else ""], GOOD)

func checked_count() -> int:
	return checked.filter(func(c: Variant) -> bool: return bool(c)).size()

## Swaps the hand and far-end dots (for a weapon found back to front).
func swap_ends(index: int) -> void:
	if index < 0 or index >= track.size():
		return
	var entry: Dictionary = track[index]
	if not (entry.grip is Vector2 and entry.tip is Vector2):
		return
	track[index] = {"grip": entry.tip, "tip": entry.grip, "behind": bool(entry.behind)}
	_after_track_changed()

## Moves whichever dot is nearer `point` there (quick check clicks).
func move_nearest_dot(index: int, point: Vector2) -> void:
	if index < 0 or index >= track.size():
		return
	var entry: Dictionary = track[index]
	if not (entry.grip is Vector2 and entry.tip is Vector2):
		weapon_click(point)
		return
	var key := "grip" if point.distance_to(entry.grip) <= point.distance_to(entry.tip) else "tip"
	track[index][key] = point
	_after_track_changed()

## Moves both dots of `index` by `delta` (frame pixels), keeping the angle.
func move_weapon(index: int, delta: Vector2, rebuild: bool = true) -> void:
	if index < 0 or index >= track.size():
		return
	var entry: Dictionary = track[index]
	if not (entry.grip is Vector2 and entry.tip is Vector2):
		return
	track[index]["grip"] = Vector2(entry.grip) + delta
	track[index]["tip"] = Vector2(entry.tip) + delta
	if rebuild:
		_after_track_changed()
	elif _view != null:
		_view.queue_redraw()

func set_steady_size(on: bool) -> void:
	steady_size = on
	if _view != null:
		_view.queue_redraw()

## Snappy timing on: held wind-up and hit, fast swing; off: every frame the same.
func set_snappy(on: bool) -> void:
	snappy = on
	var hit := -1
	for attack in current_attacks():
		hit = int(attack.hit)
		break
	if on and hit >= 0:
		holds = Imp.snappy_holds(track, anchors, hit, WeaponClip.DEFAULT_FRAME_MS)
	else:
		for index in range(holds.size()):
			holds[index] = WeaponClip.DEFAULT_FRAME_MS
	_refresh_frame_controls()

## Makes `index` the hit frame of a one-attack clip (and re-times it).
func make_hit(index: int) -> void:
	if index < 0 or index >= cut.size():
		return
	starts = []
	hits = [index]
	if snappy:
		holds = Imp.snappy_holds(track, anchors, index, WeaponClip.DEFAULT_FRAME_MS)
	_refresh_frame_controls()

func set_blink(on: bool) -> void:
	blink = on
	if _quick_blink != null:
		_quick_blink.set_pressed_no_signal(on)
	_blink_ref = false
	_blink_time = 0.0
	if _view != null:
		_view.queue_redraw()

## Length every frame's weapon is drawn at when steady_size is on (the middle
## of the placed lengths; 0 with nothing placed).
func steady_length() -> float:
	var lengths: Array = []
	for entry in track:
		if entry.grip is Vector2 and entry.tip is Vector2:
			lengths.append(Vector2(entry.grip).distance_to(entry.tip))
	if lengths.is_empty():
		return 0.0
	lengths.sort()
	return float(lengths[lengths.size() / 2])

## Where the weapon's far end is drawn on `index` (the dot, or at the steady
## length along it).
func effective_tip(index: int) -> Variant:
	if index < 0 or index >= track.size():
		return null
	var entry: Dictionary = track[index]
	if not (entry.grip is Vector2 and entry.tip is Vector2) or not steady_size:
		return entry.tip
	var length := steady_length()
	var along: Vector2 = Vector2(entry.tip) - Vector2(entry.grip)
	if length <= 0.0 or along.length() < 0.001:
		return entry.tip
	return Vector2(entry.grip) + along.normalized() * length

func _popup_quick(dialog: FileDialog) -> void:
	var last := str(Imp.load_settings().get("last_dir", ""))
	if not last.is_empty() and DirAccess.dir_exists_absolute(last):
		dialog.current_dir = last
	dialog.popup_centered_ratio(0.7)

## Rebuilds the front hand of `index` around its grip.
func _auto_hand(index: int) -> void:
	_ensure_hand_arrays()
	var entry: Dictionary = track[index]
	if not entry.grip is Vector2:
		hand_masks[index] = null
	else:
		hand_masks[index] = Imp.hand_mask(cut[index], entry.grip)
		hand_masks[index].set_meta("grip", entry.grip)
	_update_hand_texture(index)

func _update_hand_texture(index: int) -> void:
	var mask: Variant = hand_masks[index]
	if mask == null:
		hand_textures[index] = null
		hand_pictures[index] = null
		return
	var picture := Imp.masked(cut[index], mask)
	hand_pictures[index] = picture
	_hand_uploads.erase(index)
	if hand_textures[index] is ImageTexture and (hand_textures[index] as ImageTexture).get_size() == Vector2(picture.get_size()):
		(hand_textures[index] as ImageTexture).update(picture)
	else:
		hand_textures[index] = ImageTexture.create_from_image(picture)

## Paints (or with `erase`, removes) the front hand of `index` at `point`.
func paint_hand(index: int, point: Vector2, erase: bool = false) -> void:
	_ensure_hand_arrays()
	if index < 0 or index >= cut.size():
		return
	if hand_masks[index] == null:
		hand_masks[index] = Image.create_empty(cut[index].get_width(), cut[index].get_height(), false, Image.FORMAT_L8)
	Imp.paint_mask(hand_masks[index], point, brush, 0 if erase else 255)
	hand_painted[index] = true
	var picture: Variant = hand_pictures[index]
	if picture is Image and hand_textures[index] is ImageTexture:
		# Only the brush footprint changed: redo those pixels, and upload the
		# texture once this frame however many mouse events arrive.
		var r := int(ceil(brush)) + 1
		Imp.remask_region(picture, cut[index], hand_masks[index], Rect2i(Vector2i(point) - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1)))
		if _hand_uploads.is_empty():
			_flush_hand_uploads.call_deferred()
		_hand_uploads[index] = true
	else:
		_update_hand_texture(index)
		if _view != null:
			_view.queue_redraw()

func _flush_hand_uploads() -> void:
	for index in _hand_uploads.keys():
		if index < hand_textures.size() and hand_textures[index] is ImageTexture and hand_pictures[index] is Image:
			(hand_textures[index] as ImageTexture).update(hand_pictures[index])
	_hand_uploads.clear()
	if _view != null:
		_view.queue_redraw()

func reset_hand(index: int) -> void:
	if index < 0 or index >= cut.size():
		return
	_ensure_hand_arrays()
	hand_painted[index] = false
	_auto_hand(index)
	if _view != null:
		_view.queue_redraw()

func set_front_hand(on: bool) -> void:
	front_hand = on
	if _view != null:
		_view.queue_redraw()

func _empty_track() -> Dictionary:
	return {"grip": null, "tip": null, "behind": false}

func _track_to_json() -> Array:
	var result: Array = []
	for entry in track:
		result.append({"grip": [entry.grip.x, entry.grip.y] if entry.grip is Vector2 else null, "tip": [entry.tip.x, entry.tip.y] if entry.tip is Vector2 else null, "behind": bool(entry.behind)})
	return result

func _track_from_json(entry: Variant) -> Dictionary:
	var result := _empty_track()
	if entry is Dictionary:
		for key in ["grip", "tip"]:
			if entry.get(key) is Array and entry[key].size() == 2:
				result[key] = Vector2(float(entry[key][0]), float(entry[key][1]))
		result["behind"] = bool(entry.get("behind", false))
	return result

## Frames with both the grip and the far end placed.
func placed_count() -> int:
	var count := 0
	for entry in track:
		if entry.grip is Vector2 and entry.tip is Vector2:
			count += 1
	return count

## "This sheet has no weapon": the game draws each weapon's own picture.
func set_weapon_free(on: bool) -> void:
	mode = "hero_weapon" if on else "hero"
	if on and track.size() != cut.size():
		track = []
		for _i in range(cut.size()):
			track.append(_empty_track())
	_union = _compute_union()
	if on and selected < track.size():
		tool = "weapon"
		weapon_step = "grip" if not (track[selected].grip is Vector2) else "tip"
	_refresh()

func set_grip(index: int, point: Vector2) -> void:
	if index >= 0 and index < track.size():
		track[index]["grip"] = point
		_after_track_changed()

func set_tip(index: int, point: Vector2) -> void:
	if index >= 0 and index < track.size():
		track[index]["tip"] = point
		_after_track_changed()

func set_behind(index: int, on: bool) -> void:
	if index >= 0 and index < track.size():
		track[index]["behind"] = on
		_after_track_changed()

func copy_previous_track(index: int) -> void:
	if index <= 0 or index >= track.size():
		return
	# Keep the weapon where it was relative to the feet.
	var shift: Vector2 = Vector2(anchors[index]) - Vector2(anchors[index - 1])
	var previous: Dictionary = track[index - 1]
	track[index] = {"grip": previous.grip + shift if previous.grip is Vector2 else null, "tip": previous.tip + shift if previous.tip is Vector2 else null, "behind": bool(previous.behind)}
	_after_track_changed()

func clear_track(index: int) -> void:
	if index >= 0 and index < track.size():
		track[index] = _empty_track()
		weapon_step = "grip"
		_after_track_changed()

## One click of the Place weapon tool: the hand first, then the far end;
## after the far end it moves on to the next frame.
func weapon_click(point: Vector2) -> void:
	if selected >= track.size():
		return
	if weapon_step == "grip" or not (track[selected].grip is Vector2):
		track[selected]["grip"] = point
		track[selected]["tip"] = null
		weapon_step = "tip"
		_set_status("Frame %d: now click the far end of the weapon (the tip of the head or blade)." % (selected + 1))
	else:
		track[selected]["tip"] = point
		weapon_step = "grip"
		if selected < track.size() - 1:
			selected += 1
			_set_status("Weapon placed. Frame %d: click the hand gripping the weapon." % (selected + 1), GOOD)
		else:
			_set_status("Weapon placed on %d of %d frames. Press Space to play it." % [placed_count(), track.size()], GOOD)
	_after_track_changed()

func _after_track_changed() -> void:
	_ensure_hand_arrays()
	for index in range(mini(track.size(), cut.size())):
		var entry: Dictionary = track[index]
		var grip: Variant = entry.grip
		var key: Variant = hand_masks[index].get_meta("grip") if hand_masks[index] is Image and hand_masks[index].has_meta("grip") else null
		if not bool(hand_painted[index]) and grip != key:
			if grip is Vector2:
				hand_masks[index] = Imp.hand_mask(cut[index], grip)
				hand_masks[index].set_meta("grip", grip)
			else:
				hand_masks[index] = null
			_update_hand_texture(index)
	if _view != null:
		_view.queue_redraw()
	_refresh_frame_controls()

## Loads the same animation with the weapon drawn in, as a ghost to click on.
func open_reference(path: String) -> bool:
	if cut.is_empty():
		return _fail("Cut out the weapon-free frames first, then load the sheet with the weapon.")
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return _fail("Couldn't open %s as an image." % path.get_file())
	image.convert(Image.FORMAT_RGBA8)
	if not project_dir.is_empty():
		image.save_png(project_dir.path_join("reference.png"))
	if not _load_reference_frames_from_image(image):
		return false
	if mode != "hero_weapon":
		set_weapon_free(true)
	_after_frames_changed()
	_refresh()
	_set_status("Reference loaded: it shows as a ghost behind each frame. Click the hand, then the far end of its weapon.", GOOD)
	return true

func _load_reference_frames(path: String) -> bool:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	image.convert(Image.FORMAT_RGBA8)
	return _load_reference_frames_from_image(image)

func _load_reference_frames_from_image(image: Image) -> bool:
	var layout := Imp.detect_layout(image, cut.size())
	var boxes_found: Array = layout.get("boxes", [])
	if boxes_found.size() != cut.size():
		return _fail("The reference sheet has %d poses but this animation has %d frames." % [boxes_found.size(), cut.size()])
	ref_cut = []
	ref_textures = []
	ref_anchors = []
	ref_offsets = []
	var ground := int(layout.get("ground_y", -1))
	for index in range(boxes_found.size()):
		var box: Rect2i = boxes_found[index]
		var options := cut_options()
		options["method"] = "solid"
		options["background"] = layout.background
		options["owners"] = layout.get("owners", PackedByteArray())
		options["owner_strip"] = layout.strip
		options["frame"] = index
		var frame := Imp.cut_frame(image, box, options)
		ref_cut.append(frame)
		ref_textures.append(ImageTexture.create_from_image(frame))
		ref_anchors.append(Imp.feet_anchor(frame, float(ground - box.position.y) if ground >= 0 else -1.0))
		ref_offsets.append(Vector2.ZERO)
	# ChatGPT edits come back at a slightly different size: match the heights
	# of the hero (not the weapon) across frames.
	var palette := Imp.body_palette(cut)
	var ratios: Array = []
	for index in range(cut.size()):
		var ref_height := Imp.palette_height(ref_cut[index], palette)
		var body_height_px := Imp.palette_height(cut[index], palette)
		if ref_height > 0.0 and body_height_px > 0.0:
			ratios.append(body_height_px / ref_height)
	ratios.sort()
	ref_scale = clampf(float(ratios[ratios.size() / 2]), 0.3, 3.0) if not ratios.is_empty() else 1.0
	return true

func nudge_reference(index: int, delta: Vector2, all_frames: bool = false) -> void:
	for other in range(ref_offsets.size()):
		if other == index or all_frames:
			ref_offsets[other] = Vector2(ref_offsets[other]) + delta
	if _view != null:
		_view.queue_redraw()

# ---------- view ----------

func select_frame(index: int) -> void:
	var count := frame_count()
	if count == 0:
		return
	selected = posmod(index, count)
	if selected < track.size():
		weapon_step = "tip" if track[selected].grip is Vector2 and not (track[selected].tip is Vector2) else "grip"
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
		# Keep the ghost (and its raised weapon) in view too.
		if mode == "hero_weapon" and index < ref_cut.size():
			var ghost_low: Vector2 = Vector2(ref_offsets[index]) - Vector2(ref_anchors[index]) * ref_scale
			var ghost_high: Vector2 = ghost_low + Vector2((ref_cut[index] as Image).get_size()) * ref_scale
			low = Vector2(minf(low.x, ghost_low.x), minf(low.y, ghost_low.y))
			high = Vector2(maxf(high.x, ghost_high.x), maxf(high.y, ghost_high.y))
	return Rect2(low, high - low)

## Where the shared anchor sits in the view and the view's zoom.
func _fit_transform() -> Dictionary:
	var rect := Rect2(Vector2.ZERO, _view.size)
	if not _union.has_area():
		return {"scale": 1.0, "pivot": rect.size * 0.5}
	var room := rect.size - Vector2(40.0, 70.0)
	var s := minf(room.x / _union.size.x, room.y / _union.size.y)
	var pivot := Vector2(20.0, 20.0) + (room - _union.size * s) * 0.5 - _union.position * s
	return {"scale": s, "pivot": pivot}

## The fitted view with the user's zoom and pan on top.
func _align_transform() -> Dictionary:
	var fit := _fit_transform()
	var center := _view.size * 0.5
	return {"scale": float(fit.scale) * view_zoom, "pivot": center + (Vector2(fit.pivot) - center) * view_zoom + view_pan}

## Zooms by `factor` keeping the point under `at` (view pixels) still.
func zoom_view(factor: float, at: Vector2) -> void:
	var before := _align_transform()
	var new_zoom := clampf(view_zoom * factor, 0.2, 8.0)
	var applied := new_zoom / view_zoom
	var target: Vector2 = at - (at - Vector2(before.pivot)) * applied
	view_zoom = new_zoom
	var fit := _fit_transform()
	var center := _view.size * 0.5
	view_pan = target - (center + (Vector2(fit.pivot) - center) * view_zoom)
	_view.queue_redraw()

func fit_view() -> void:
	view_zoom = 1.0
	view_pan = Vector2.ZERO
	if _view != null:
		_view.queue_redraw()

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
	# Blink: alternate the empty-hands frame and the frame with the weapon.
	var ghost_phase := blink and _blink_ref and not playing and mode == "hero_weapon" and selected < ref_textures.size()
	if ghost_phase:
		_draw_reference(selected, pivot, s, Color.WHITE)
		_view.draw_line(Vector2(0, pivot.y), Vector2(rect.size.x, pivot.y), Color(STRIP_LINE, 0.7), 1.0)
		_view.draw_rect(Rect2(0, rect.size.y - 30, rect.size.x, 30), Color("101316"), true)
		_view.draw_string(ThemeDB.fallback_font, Vector2(12, rect.size.y - 12), "frame %d / %d   blinking: the sheet WITH the weapon" % [selected + 1, cut.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
		return
	if not playing and onion and selected > 0 and not is_quick():
		_draw_cut_frame(selected - 1, pivot, s, ONION)
	if not playing and show_ref and mode == "hero_weapon":
		_draw_reference(selected, pivot, s)
	if shown >= 0 and mode == "hero_weapon":
		_draw_weapon(shown, pivot, s, true)
	if shown >= 0:
		_draw_cut_frame(shown, pivot, s, Color.WHITE)
	if shown >= 0 and purpose == "hero" and shown < hand_track.size() and hand_track[shown] is Vector2:
		var fist: Vector2 = pivot + (Vector2(hand_track[shown]) - Vector2(anchors[shown])) * s
		_view.draw_arc(fist, 9.0, 0.0, TAU, 24, AMBER, 2.0, true)
		_view.draw_circle(fist, 2.5, AMBER)
	if shown >= 0 and mode == "hero_weapon":
		_draw_weapon(shown, pivot, s, false)
		_draw_hand(shown, pivot, s)
		if not playing:
			_draw_track_handles(shown, pivot, s)
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
	elif tool == "weapon" and is_quick() and selected < track.size() and track[selected].grip is Vector2 and track[selected].tip is Vector2:
		caption += "   green dot = fist, orange dot = far end of the gold weapon. Drag a dot, or drag the line to move the whole weapon."
	elif tool == "weapon":
		caption += "   place weapon: click the %s" % ("hand gripping it" if weapon_step == "grip" else "far end of the weapon")
	elif tool == "reference":
		caption += "   drag the ghost to line it up with this frame"
	elif tool == "hand":
		caption += "   front hand: paint the fist that wraps the weapon (Shift: erase)"
	else:
		caption += "   drag to move the frame, click to put that point on the %s" % ("ground mark" if mode == "hero" else "grip mark")
	_view.draw_string(font, Vector2(12, rect.size.y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	if not playing and hits.has(selected):
		_view.draw_string(font, Vector2(12, 22), "HIT FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BAD)

func _frame_origin(index: int, pivot: Vector2, s: float) -> Vector2:
	return pivot - Vector2(anchors[index]) * s

func _draw_reference(index: int, pivot: Vector2, s: float, tint: Color = Color(1.0, 0.85, 0.55, 0.45)) -> void:
	if index < 0 or index >= ref_textures.size():
		return
	var texture: Texture2D = ref_textures[index]
	var scale := s * ref_scale
	var origin := pivot + Vector2(ref_offsets[index]) * s - Vector2(ref_anchors[index]) * scale
	_view.draw_texture_rect(texture, Rect2(origin, Vector2(texture.get_size()) * scale), false, tint)

## The lab's weapon (or a stand-in bar) in the hands of frame `index`.
func _draw_weapon(index: int, pivot: Vector2, s: float, behind_pass: bool) -> void:
	if index < 0 or index >= track.size():
		return
	var entry: Dictionary = track[index]
	if bool(entry.behind) != behind_pass or not (entry.grip is Vector2) or not (entry.tip is Vector2):
		return
	var origin := _frame_origin(index, pivot, s)
	var grip: Vector2 = entry.grip
	var tip: Vector2 = effective_tip(index)
	var texture: Texture2D = preview_weapon.get("texture")
	if texture == null:
		_view.draw_line(origin + grip * s, origin + tip * s, Color("c9d3dc"), maxf(3.0, 6.0 * s))
		return
	var along := tip - grip
	var clip := {"track": [{"grip": [grip.x, grip.y], "angle": rad_to_deg(along.angle()), "length": along.length(), "behind": false}]}
	var placed := WeaponClip.hand_transform(clip, 0, Vector2(texture.get_size()), preview_weapon.get("grip", Vector2(0.5, 0.75)), preview_weapon.get("tip", Vector2.ZERO), preview_weapon.get("fit", {}))
	var view := Transform2D(0.0, Vector2(s, s), 0.0, origin) * placed
	_view.draw_set_transform_matrix(view)
	_view.draw_texture(texture, -Vector2(texture.get_size()) * 0.5)
	_view.draw_set_transform_matrix(Transform2D.IDENTITY)

## The gripping hand, drawn over the weapon (front frames only).
func _draw_hand(index: int, pivot: Vector2, s: float) -> void:
	if not front_hand or index < 0 or index >= hand_textures.size() or hand_textures[index] == null:
		return
	if index < track.size() and bool(track[index].behind):
		return
	var texture: Texture2D = hand_textures[index]
	var origin := _frame_origin(index, pivot, s)
	_view.draw_texture_rect(texture, Rect2(origin, Vector2(texture.get_size()) * s), false)
	if tool == "hand" and not playing:
		# Tint the hand so it's clear what's painted.
		_view.draw_texture_rect(texture, Rect2(origin, Vector2(texture.get_size()) * s), false, Color(0.3, 0.9, 1.0, 0.45))

func _draw_track_handles(index: int, pivot: Vector2, s: float) -> void:
	if index < 0 or index >= track.size():
		return
	var entry: Dictionary = track[index]
	var origin := _frame_origin(index, pivot, s)
	if entry.grip is Vector2 and entry.tip is Vector2:
		_view.draw_line(origin + Vector2(entry.grip) * s, origin + Vector2(entry.tip) * s, Color(AMBER, 0.8), 1.5)
	if entry.grip is Vector2:
		_view.draw_circle(origin + Vector2(entry.grip) * s, 6.0, Color(STRIP_LINE, 0.9))
	if entry.tip is Vector2:
		_view.draw_circle(origin + Vector2(entry.tip) * s, 6.0, Color(AMBER, 0.9))

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
		# Wheel zooms, right- or middle-drag moves the view.
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_view(1.15, button.position)
				return
			if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_view(1.0 / 1.15, button.position)
				return
			if button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
				_pan_drag = button.pressed
				return
		if event is InputEventMouseMotion and _pan_drag:
			view_pan += (event as InputEventMouseMotion).relative
			_view.queue_redraw()
			return
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
	owners = PackedByteArray()
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
	if tool == "fist":
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var click := event as InputEventMouseButton
			mark_fist(selected, (click.position - frame_origin) / s, click.shift_pressed)
		return
	if tool == "weapon" or tool == "reference":
		_weapon_input(event, frame_origin, s)
		return
	if tool == "hand":
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var button := event as InputEventMouseButton
			_drag = {"painting": true} if button.pressed else {}
			if button.pressed:
				paint_hand(selected, (button.position - frame_origin) / s, button.shift_pressed)
		elif event is InputEventMouseMotion and not _drag.is_empty():
			var motion := event as InputEventMouseMotion
			paint_hand(selected, (motion.position - frame_origin) / s, motion.shift_pressed)
		return
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

func _weapon_input(event: InputEvent, frame_origin: Vector2, s: float) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if not button.pressed:
			if tool == "weapon" and not _drag.is_empty() and not bool(_drag.moved) and str(_drag.get("handle", "")) == "":
				if is_quick():
					move_nearest_dot(selected, (button.position - frame_origin) / s)
				else:
					weapon_click((button.position - frame_origin) / s)
			var dragged_handle: bool = not _drag.is_empty() and str(_drag.get("handle", "")) != "" and bool(_drag.get("moved", false))
			_drag = {}
			if dragged_handle:
				# The automatic hand follows the grip once, on release.
				_after_track_changed()
			return
		_drag = {"start": button.position, "last": button.position, "moved": false, "handle": ""}
		if tool == "weapon" and selected < track.size():
			for key in ["grip", "tip"]:
				var point: Variant = track[selected][key]
				if point is Vector2 and button.position.distance_to(frame_origin + Vector2(point) * s) < (14.0 if is_quick() else 9.0):
					_drag["handle"] = key
			# Quick check: grabbing the line between the dots moves the whole weapon.
			var entry: Dictionary = track[selected]
			if str(_drag.handle) == "" and is_quick() and entry.grip is Vector2 and entry.tip is Vector2:
				var a: Vector2 = frame_origin + Vector2(entry.grip) * s
				var b: Vector2 = frame_origin + Vector2(entry.tip) * s
				var closest := Geometry2D.get_closest_point_to_segment(button.position, a, b)
				if closest.distance_to(button.position) < 9.0:
					_drag["handle"] = "both"
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var motion := event as InputEventMouseMotion
		if motion.position.distance_to(_drag.start) > 3.0:
			_drag["moved"] = true
		var delta: Vector2 = (motion.position - Vector2(_drag.last)) / s
		_drag["last"] = motion.position
		if tool == "reference" and bool(_drag.moved):
			nudge_reference(selected, delta, motion.shift_pressed)
		elif tool == "weapon" and str(_drag.handle) == "both":
			move_weapon(selected, delta, false)
		elif tool == "weapon" and str(_drag.handle) != "":
			track[selected][str(_drag.handle)] = Vector2(track[selected][str(_drag.handle)]) + delta
			# Just move the dot while dragging; rebuilding the hand is heavy.
			if _view != null:
				_view.queue_redraw()

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
	_title = title
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
	var zoom_row := HBoxContainer.new()
	left.add_child(zoom_row)
	var zoom_out := _button("-")
	zoom_out.tooltip_text = "Zoom out (mouse wheel, or -)"
	zoom_out.pressed.connect(func() -> void: zoom_view(0.8, _view.size * 0.5))
	zoom_row.add_child(zoom_out)
	var zoom_in := _button("+")
	zoom_in.tooltip_text = "Zoom in (mouse wheel, or +)"
	zoom_in.pressed.connect(func() -> void: zoom_view(1.25, _view.size * 0.5))
	zoom_row.add_child(zoom_in)
	var fit_button := _button("Fit")
	fit_button.tooltip_text = "Show the whole frame, ghost and weapon (F)"
	fit_button.pressed.connect(fit_view)
	zoom_row.add_child(fit_button)
	var zoom_hint := Label.new()
	zoom_hint.text = "Mouse wheel zooms, right-drag moves the view, F fits."
	zoom_hint.add_theme_font_size_override("font_size", 12)
	zoom_hint.add_theme_color_override("font_color", MUTED)
	zoom_row.add_child(zoom_hint)
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
	side.add_child(_build_quick_section())
	side.add_child(_build_source_section())
	side.add_child(_build_slice_section())
	side.add_child(_build_cut_section())
	side.add_child(_build_align_section())
	side.add_child(_build_weapon_section())
	side.add_child(_build_timing_section())
	side.add_child(_build_save_section())
	_sheet_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open a pose sheet", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_sheet_dialog.file_selected.connect(func(path: String) -> void: open_sheet(path))
	_frames_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILES, "Open frames (one image per frame)", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_frames_dialog.files_selected.connect(func(paths: PackedStringArray) -> void: open_frames(Array(paths)))
	_video_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open a video", PackedStringArray(["*.mp4, *.webm, *.mov, *.gif, *.mkv, *.avi, *.m4v ; Videos"]))
	_video_dialog.file_selected.connect(func(path: String) -> void: open_video(path))
	_ref_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Open the same animation with the weapon drawn in", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_ref_dialog.file_selected.connect(func(path: String) -> void: open_reference(path))
	_quick_body_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "1  The poses with EMPTY hands (no weapon)", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_quick_body_dialog.file_selected.connect(func(path: String) -> void: set_quick_sheet("body", path))
	_quick_weapon_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "2  The same poses WITH the weapon", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]))
	_quick_weapon_dialog.file_selected.connect(func(path: String) -> void: set_quick_sheet("weapon", path))

func _build_quick_section() -> Control:
	var section := _section("QUICK SETUP: TWO SHEETS", "quick")
	var body: VBoxContainer = section.get_meta("body")
	_quick_intro = _note("")
	body.add_child(_quick_intro)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	body.add_child(grid)
	var body_button := _button("1  Empty-hands sheet...")
	body_button.name = "QuickBodySheet"
	body_button.tooltip_text = "The poses with closed, empty fists: no weapon anywhere."
	body_button.pressed.connect(func() -> void: _popup_quick(_quick_body_dialog))
	grid.add_child(body_button)
	_quick_body_label = _file_label()
	grid.add_child(_quick_body_label)
	var weapon_button := _button("2  Same poses with the weapon...")
	weapon_button.name = "QuickWeaponSheet"
	weapon_button.tooltip_text = "The original sheet the empty-hands one was edited from: same poses, same order, weapon in the hands."
	weapon_button.pressed.connect(func() -> void: _popup_quick(_quick_weapon_dialog))
	grid.add_child(weapon_button)
	_quick_weapon_label = _file_label()
	grid.add_child(_quick_weapon_label)
	_quick_run_button = _button("3  Line up & place the weapon")
	_quick_run_button.name = "QuickRun"
	_amber(_quick_run_button)
	_quick_run_button.tooltip_text = "Cuts both sheets out, lines each pair of frames up by the feet and body, finds the weapon and puts it in the fists on every frame, then guesses the hit frame and timing."
	_quick_run_button.pressed.connect(func() -> void: quick_run())
	body.add_child(_quick_run_button)
	# 4: check each frame.
	_quick_check = VBoxContainer.new()
	_quick_check.add_theme_constant_override("separation", 6)
	body.add_child(_quick_check)
	_quick_check.add_child(_small_heading("4  CHECK EACH FRAME"))
	_quick_frame_label = Label.new()
	_quick_frame_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_frame_label.custom_minimum_size = Vector2(340, 0)
	_quick_frame_label.add_theme_font_size_override("font_size", 13)
	_quick_check.add_child(_quick_frame_label)
	_quick_check.add_child(_note("Gold = the sheet with the weapon. The green dot belongs in the fist, the orange dot on the far end of the gold weapon. Drag a dot (or click near it) to move it; drag the line between them to move the whole weapon."))
	var nav := HBoxContainer.new()
	_quick_check.add_child(nav)
	var previous := _button("< Previous")
	previous.tooltip_text = "Previous frame (Q)"
	previous.pressed.connect(func() -> void: select_frame(selected - 1))
	nav.add_child(previous)
	var looks := _button("Looks right >")
	looks.name = "QuickLooksRight"
	_amber(looks)
	looks.tooltip_text = "This frame is fine: mark it and go to the next one (Enter)."
	looks.pressed.connect(approve_frame)
	nav.add_child(looks)
	var fixes := HBoxContainer.new()
	_quick_check.add_child(fixes)
	var swap := _button("Swap ends")
	swap.tooltip_text = "The weapon came out back to front: swap the green and orange dots."
	swap.pressed.connect(func() -> void: swap_ends(selected))
	fixes.add_child(swap)
	var same := _button("Same as previous")
	same.tooltip_text = "Copy the previous frame's weapon (kept the same distance from the feet)."
	same.pressed.connect(func() -> void: copy_previous_track(selected))
	fixes.add_child(same)
	var again := _button("Find again")
	again.tooltip_text = "Run the automatic placement on this frame again."
	again.pressed.connect(func() -> void: auto_place([selected]))
	fixes.add_child(again)
	var toggles := HBoxContainer.new()
	_quick_check.add_child(toggles)
	_quick_behind = CheckBox.new()
	_quick_behind.text = "Behind the body"
	_quick_behind.tooltip_text = "Draw the weapon behind the hero on this frame (raised behind the head, for example)."
	_quick_behind.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_behind(selected, on))
	toggles.add_child(_quick_behind)
	_quick_blink = CheckBox.new()
	_quick_blink.text = "Blink the two sheets"
	_quick_blink.tooltip_text = "Flip between the empty-hands frame and the frame with the weapon to see how well they line up."
	_quick_blink.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_blink(on))
	toggles.add_child(_quick_blink)
	var hit_row := HBoxContainer.new()
	_quick_check.add_child(hit_row)
	_quick_hit_label = Label.new()
	_quick_hit_label.add_theme_font_size_override("font_size", 13)
	_quick_hit_label.add_theme_color_override("font_color", MUTED)
	hit_row.add_child(_quick_hit_label)
	_quick_hit_button = _button("Make this the hit frame")
	_quick_hit_button.tooltip_text = "The frame where the weapon connects: damage lands as it shows."
	_quick_hit_button.pressed.connect(func() -> void: make_hit(selected))
	hit_row.add_child(_quick_hit_button)
	var smooth := HBoxContainer.new()
	_quick_check.add_child(smooth)
	_quick_steady = CheckBox.new()
	_quick_steady.text = "Same weapon size every frame"
	_quick_steady.tooltip_text = "ChatGPT draws the weapon a little bigger or smaller from pose to pose. On: every frame uses the middle size, so the weapon doesn't pulse."
	_quick_steady.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_steady_size(on))
	smooth.add_child(_quick_steady)
	_quick_snappy = CheckBox.new()
	_quick_snappy.text = "Snappy timing"
	_quick_snappy.tooltip_text = "Holds the wind-up and the hit a little longer and rushes the swing between them, so the attack feels heavier. Off: every frame the same length."
	_quick_snappy.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_snappy(on))
	smooth.add_child(_quick_snappy)
	_quick_play = _button("Play (Space)")
	_quick_play.toggle_mode = true
	_quick_play.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_playing(on))
	_quick_check.add_child(_quick_play)
	# 5: save.
	_quick_save = VBoxContainer.new()
	_quick_save.add_theme_constant_override("separation", 6)
	body.add_child(_quick_save)
	_quick_save.add_child(_small_heading("5  SAVE"))
	_quick_save_default = _button("Save as the type default")
	_quick_save_default.name = "QuickSaveDefault"
	_amber(_quick_save_default)
	_quick_save_default.pressed.connect(func() -> void: save_clip("type"))
	_quick_save.add_child(_quick_save_default)
	_quick_save_weapon = _button("Save for this weapon only")
	_quick_save_weapon.pressed.connect(func() -> void: save_clip("weapon"))
	_quick_save.add_child(_quick_save_weapon)
	_quick_more = _button("More options: slicing, cut-out, timing, hand brush")
	_quick_more.name = "QuickMore"
	_quick_more.toggle_mode = true
	_quick_more.flat = true
	_quick_more.add_theme_color_override("font_color", MUTED)
	_quick_more.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_advanced(on))
	body.add_child(_quick_more)
	return section

func _file_label() -> Label:
	var label := Label.new()
	label.text = "not picked"
	label.clip_text = true
	label.custom_minimum_size = Vector2(120, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _small_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", AMBER)
	return label

## Quick panel state (part of _refresh).
func _refresh_quick() -> void:
	if _quick_run_button == null:
		return
	var what := ("the %s" % clip_animation) if is_pose() else "the attack"
	_quick_intro.text = "Make %s in ChatGPT twice: once holding the weapon, then the same sheet edited so the fists are empty. Pick both and press 3: the tool cuts them out, lines them up and puts the weapon in the hands on every frame. (One sheet with the weapon drawn in? Use More options.)" % what
	for pair in [[_quick_body_label, quick_body_path], [_quick_weapon_label, quick_weapon_path]]:
		var label: Label = pair[0]
		var path: String = pair[1]
		label.text = path.get_file() if not path.is_empty() else ("from the saved project" if not cut.is_empty() else "not picked")
		label.add_theme_color_override("font_color", GOOD if not path.is_empty() else MUTED)
	_quick_run_button.disabled = quick_busy or busy or quick_body_path.is_empty() or quick_weapon_path.is_empty()
	_quick_run_button.text = "Working..." if quick_busy else ("3  Line up & place the weapon" if placed_count() == 0 else "3  Start over with these sheets")
	var placing := mode == "hero_weapon" and not cut.is_empty() and placed_count() > 0
	_quick_check.visible = placing and not quick_busy and not advanced
	_quick_save.visible = placing and not quick_busy and not advanced
	_quick_steady.button_pressed = steady_size
	_quick_snappy.button_pressed = snappy
	_quick_snappy.visible = not is_pose()
	_quick_blink.button_pressed = blink
	_quick_play.set_pressed_no_signal(playing)
	_quick_more.button_pressed = advanced
	_quick_more.text = ("Fewer options (back to the quick setup)" if advanced else "More options: slicing, cut-out, timing, hand brush")
	_quick_save_default.visible = not type_label.is_empty()
	_quick_save_default.text = ("Save as the %s %s (all %s weapons)" % [type_label, clip_animation, type_label.to_lower()]) if is_pose() else ("Save as the %s default (all %s weapons)" % [type_label, type_label.to_lower()])
	_quick_save_weapon.visible = not editing_default
	_quick_save_weapon.text = "Save for this weapon only" if not is_pose() else "Save as this weapon's %s" % clip_animation
	_refresh_quick_frame()

func _refresh_quick_frame() -> void:
	if _quick_frame_label == null or cut.is_empty() or selected >= track.size():
		return
	var entry: Dictionary = track[selected]
	var state := "the tool isn't sure about this one: check it closely." if auto_unsure.has(selected) else "looks placed."
	if selected < checked.size() and bool(checked[selected]):
		state = "okayed."
	elif not (entry.grip is Vector2 and entry.tip is Vector2):
		state = "no weapon yet: click the fist, then the far end of the gold weapon."
	_quick_frame_label.text = "Frame %d of %d: %s   (%d of %d okayed)" % [selected + 1, cut.size(), state, checked_count(), cut.size()]
	_quick_frame_label.add_theme_color_override("font_color", BAD if auto_unsure.has(selected) else INK)
	_quick_behind.set_pressed_no_signal(bool(entry.behind))
	var hit := -1
	for attack in current_attacks():
		hit = int(attack.hit)
		break
	_quick_hit_label.text = "Hit frame: %d" % (hit + 1) if hit >= 0 else "Hit frame: none"
	_quick_hit_label.visible = not is_pose()
	_quick_hit_button.visible = not is_pose()
	_quick_hit_button.disabled = hit == selected

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
	var group := _tool_group
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

func _build_weapon_section() -> Control:
	var section := _section("WEAPON IN THE HANDS", "weapon")
	var body: VBoxContainer = section.get_meta("body")
	_weapon_free_check = CheckBox.new()
	_weapon_free_check.text = "This sheet has no weapon: draw each weapon's own art in the hands"
	_weapon_free_check.tooltip_text = "For weapon-free animations. You mark where the hands hold the weapon in each frame, and every weapon that uses this animation shows its own picture there."
	_weapon_free_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_weapon_free(on))
	body.add_child(_weapon_free_check)
	_weapon_controls = VBoxContainer.new()
	body.add_child(_weapon_controls)
	_weapon_controls.add_child(_note("1. Load the same animation with the weapon drawn in: it shows as a faint ghost. 2. With Place weapon, click the hand gripping the weapon, then the far end of the weapon (tip of the head or blade). It moves on to the next frame by itself. Drag the green and amber dots to adjust."))
	var ref_row := HBoxContainer.new()
	_weapon_controls.add_child(ref_row)
	var ref_button := _button("Sheet with weapon...")
	ref_button.tooltip_text = "The original sheet (with the weapon) the weapon-free one was made from."
	ref_button.pressed.connect(func() -> void: _ref_dialog.popup_centered_ratio(0.7))
	ref_row.add_child(ref_button)
	_show_ref_check = CheckBox.new()
	_show_ref_check.text = "Show ghost"
	_show_ref_check.button_pressed = true
	_show_ref_check.toggled.connect(func(on: bool) -> void:
		show_ref = on
		_view.queue_redraw())
	ref_row.add_child(_show_ref_check)
	_ref_scale_spin = _spin(0.2, 5.0, 0.01)
	_ref_scale_spin.tooltip_text = "Size of the ghost. Matched to the weapon-free frames automatically."
	_ref_scale_spin.value_changed.connect(func(value: float) -> void:
		if not _loading:
			ref_scale = value
			_view.queue_redraw())
	ref_row.add_child(_labeled("Ghost size", _ref_scale_spin))
	_ref_status = Label.new()
	_ref_status.add_theme_font_size_override("font_size", 12)
	_ref_status.add_theme_color_override("font_color", MUTED)
	_weapon_controls.add_child(_ref_status)
	var auto_row := HBoxContainer.new()
	_weapon_controls.add_child(auto_row)
	var auto_button := _button("Auto-place all frames")
	_amber(auto_button)
	auto_button.tooltip_text = "Compares the two sheets to find the weapon: puts the grip in the fist, the far end at the tip, marks frames where it's behind the body, and makes the front hand. Then check each frame."
	auto_button.pressed.connect(func() -> void: auto_place())
	auto_row.add_child(auto_button)
	var auto_one := _button("This frame")
	auto_one.tooltip_text = "Auto-place just the selected frame again."
	auto_one.pressed.connect(func() -> void: auto_place([selected]))
	auto_row.add_child(auto_one)
	_auto_status = Label.new()
	_auto_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto_status.custom_minimum_size = Vector2(340, 0)
	_auto_status.add_theme_font_size_override("font_size", 12)
	_auto_status.add_theme_color_override("font_color", AMBER)
	_weapon_controls.add_child(_auto_status)
	var tools := HBoxContainer.new()
	_weapon_controls.add_child(tools)
	_tool_weapon = _button("Place weapon")
	_tool_weapon.toggle_mode = true
	_tool_weapon.button_group = _tool_group
	_tool_weapon.pressed.connect(func() -> void:
		tool = "weapon"
		_view.queue_redraw())
	tools.add_child(_tool_weapon)
	_tool_reference = _button("Move ghost")
	_tool_reference.toggle_mode = true
	_tool_reference.button_group = _tool_group
	_tool_reference.tooltip_text = "Drag the ghost to line it up with this frame. Hold Shift to move it on every frame."
	_tool_reference.pressed.connect(func() -> void:
		tool = "reference"
		_view.queue_redraw())
	tools.add_child(_tool_reference)
	var row := HBoxContainer.new()
	_weapon_controls.add_child(row)
	_behind_check = CheckBox.new()
	_behind_check.text = "Behind the body"
	_behind_check.tooltip_text = "Draw the weapon behind the hero in this frame (for example raised behind the head)."
	_behind_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_behind(selected, on))
	row.add_child(_behind_check)
	var copy_button := _button("Same as previous")
	copy_button.pressed.connect(func() -> void: copy_previous_track(selected))
	row.add_child(copy_button)
	var clear_button := _button("Clear")
	clear_button.pressed.connect(func() -> void: clear_track(selected))
	row.add_child(clear_button)
	var hand_row := HBoxContainer.new()
	_weapon_controls.add_child(hand_row)
	_front_hand_check = CheckBox.new()
	_front_hand_check.text = "Front hand over the weapon"
	_front_hand_check.button_pressed = true
	_front_hand_check.tooltip_text = "Draws the fist that grips the weapon on top of it, so the fingers wrap the handle and the rest of the body stays behind."
	_front_hand_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			set_front_hand(on))
	hand_row.add_child(_front_hand_check)
	_tool_hand = _button("Hand brush")
	_tool_hand.toggle_mode = true
	_tool_hand.button_group = _tool_group
	_tool_hand.tooltip_text = "Paint the parts of the hero drawn over the weapon on this frame. Hold Shift to erase. Brush size is the eraser Size above."
	_tool_hand.pressed.connect(func() -> void:
		tool = "hand"
		_view.queue_redraw())
	hand_row.add_child(_tool_hand)
	var reset_hand_button := _button("Auto hand")
	reset_hand_button.tooltip_text = "Redo this frame's front hand around the grip."
	reset_hand_button.pressed.connect(func() -> void: reset_hand(selected))
	hand_row.add_child(reset_hand_button)
	var preview_row := HBoxContainer.new()
	_weapon_controls.add_child(preview_row)
	_preview_picker = OptionButton.new()
	_preview_picker.tooltip_text = "Only a preview while you place it. In the game every weapon using this animation shows its own art."
	_preview_picker.item_selected.connect(func(index: int) -> void:
		if not _loading:
			choose_preview(str(_preview_picker.get_item_metadata(index))))
	preview_row.add_child(_labeled("Preview with", _preview_picker))
	_weapon_controls.add_child(_note("The preview weapon is only for checking the fit: in the game each weapon that uses this animation shows its own art, with its grip (from its Placement section) in the hand."))
	_weapon_status = Label.new()
	_weapon_status.add_theme_font_size_override("font_size", 12)
	_weapon_status.add_theme_color_override("font_color", AMBER)
	_weapon_controls.add_child(_weapon_status)
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
		if _loading:
			return
		var picked := str(WeaponClip.MODES[index])
		if picked == "hero_weapon":
			set_weapon_free(true)
		else:
			mode = picked
			if tool == "weapon" or tool == "reference":
				tool = "anchor"
			_refresh())
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
	_save_default_button = _button("Save as type default")
	_amber(_save_default_button)
	_save_default_button.tooltip_text = "Every weapon of this type that uses its type's default plays this animation."
	_save_default_button.pressed.connect(func() -> void: save_clip("type"))
	body.add_child(_save_default_button)
	_save_button = _button("Save for this weapon only")
	_save_button.pressed.connect(func() -> void:
		if purpose == "hero":
			save_hero()
		else:
			save_clip("weapon"))
	body.add_child(_save_button)
	# Hero purpose: which of the hero's animations these frames replace.
	var hero_box := VBoxContainer.new()
	_hero_box = hero_box
	body.add_child(hero_box)
	body.move_child(hero_box, 1)
	_hero_picker = OptionButton.new()
	for pair in HERO_STATE_CHOICES:
		_hero_picker.add_item(str(pair[1]))
		_hero_picker.set_item_metadata(_hero_picker.item_count - 1, pair[0])
	_hero_picker.item_selected.connect(func(index: int) -> void:
		if not _loading:
			hero_target = str(_hero_picker.get_item_metadata(index))
			_refresh())
	hero_box.add_child(_labeled("Hero's", _hero_picker))
	_still_check = CheckBox.new()
	_still_check.text = "Only the selected frame (a still pose)"
	_still_check.tooltip_text = "Use just the frame selected in the strip, e.g. a standing frame from a walk sheet as the idle."
	_still_check.toggled.connect(func(on: bool) -> void:
		if not _loading:
			still_only = on
			_refresh())
	hero_box.add_child(_still_check)
	var fist_row := HBoxContainer.new()
	hero_box.add_child(fist_row)
	var fist_button := _button("Mark the front fist")
	fist_button.name = "MarkFist"
	fist_button.tooltip_text = "Then click the front fist in the view. The first click finds it on every frame; later clicks fix just that frame (Shift+click finds it on every frame again from there). Held weapons follow it in the game."
	fist_button.pressed.connect(func() -> void:
		tool = "fist"
		step = "align"
		_set_status("Click the front fist (the hand that holds the weapon) in the view.", AMBER)
		_refresh())
	fist_row.add_child(fist_button)
	_fist_status = Label.new()
	_fist_status.add_theme_font_size_override("font_size", 12)
	_fist_status.add_theme_color_override("font_color", MUTED)
	fist_row.add_child(_fist_status)
	hero_box.add_child(_note("Replaces the hero's art everywhere in the game. The old files are backed up in art/side-view/backups/. Hero height (frame 1) sets the size, and the feet line up with the old art. Keep the hands empty: weapons are drawn into them."))
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
	_sections["weapon"].visible = aligning and purpose != "hero"
	var hero := purpose == "hero"
	var looping := hero or is_pose()
	if _title != null:
		_title.text = "HERO ANIMATION IMPORTER" if hero else ("WEAPON %s IMPORTER" % clip_animation.to_upper() if is_pose() else "CLIP IMPORTER")
	_start_check.visible = not looping
	_hit_check.visible = not looping
	_attacks_label.visible = not looping
	_hero_box.visible = hero
	_mode_picker.visible = not hero
	for index in range(_hero_picker.item_count):
		if str(_hero_picker.get_item_metadata(index)) == hero_target:
			_hero_picker.select(index)
	_still_check.button_pressed = still_only
	_fist_status.text = ("fist on %d/%d frames" % [fist_count(), cut.size()]) if not cut.is_empty() else ""
	_weapon_free_check.button_pressed = mode == "hero_weapon"
	_weapon_controls.visible = mode == "hero_weapon"
	_front_hand_check.button_pressed = front_hand
	_auto_status.text = "" if auto_unsure.is_empty() else "Worth a look: frame%s %s." % ["" if auto_unsure.size() == 1 else "s", ", ".join(auto_unsure.map(func(i: int) -> String: return str(i + 1)))]
	_ref_scale_spin.value = ref_scale
	_ref_status.text = "Ghost: %d frames loaded." % ref_cut.size() if not ref_cut.is_empty() else "No ghost loaded (optional, but it makes the far end easy to find)."
	match tool:
		"weapon":
			_tool_weapon.button_pressed = true
		"reference":
			_tool_reference.button_pressed = true
		"hand":
			_tool_hand.button_pressed = true
		"erase":
			_tool_erase.button_pressed = true
		_:
			_tool_anchor.button_pressed = true
	_sections["save"].visible = has_cut
	_count_spin.value = maxi(1, boxes.size())
	_cut_button.disabled = busy or source_kind.is_empty()
	_cut_button.text = "Cutting out..." if busy else ("Cut out frames again" if has_cut else "Cut out frames")
	_save_button.disabled = busy or not has_cut
	_save_default_button.disabled = busy or not has_cut
	_save_default_button.visible = not type_label.is_empty()
	_save_default_button.text = "Save as the %s default (all %s weapons)" % [type_label, type_label.to_lower()]
	if is_pose():
		_save_default_button.text = "Save as the %s %s (all %s weapons)" % [type_label, clip_animation, type_label.to_lower()]
	if editing_default:
		_save_button.visible = false
	else:
		_save_button.visible = true
	if hero:
		_save_default_button.visible = false
		_save_button.text = ("Save the selected frame as the hero's %s" % hero_target) if still_only else "Save as the hero's %s" % hero_target
		_amber(_save_button)
	else:
		_save_button.text = "Save for this weapon only" if not is_pose() else "Save as this weapon's %s" % clip_animation
		for style in ["normal", "hover"]:
			_save_button.remove_theme_stylebox_override(style)
		for color in ["font_color", "font_hover_color"]:
			_save_button.remove_theme_color_override(color)
	for index in range(ALIGN_MODES.size()):
		if ALIGN_MODES[index].id == align_mode:
			_align_picker.select(index)
	_mode_picker.select(maxi(0, WeaponClip.MODES.find(mode)))
	_height_spin.value = body_height
	_scale_spin.value = clip_scale
	_sections["quick"].visible = purpose == "weapon"
	if is_quick():
		for key in ["source", "slice", "cut", "align", "weapon", "timing", "save"]:
			_sections[key].visible = false
	_refresh_quick()
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
		if _behind_check != null and selected < track.size():
			_behind_check.button_pressed = bool(track[selected].behind)
			var entry: Dictionary = track[selected]
			var here := "placed" if entry.grip is Vector2 and entry.tip is Vector2 else ("click the far end" if entry.grip is Vector2 else "click the hand")
			_weapon_status.text = "Frame %d: %s.   Weapon placed on %d of %d frames." % [selected + 1, here, placed_count(), track.size()]
	_refresh_quick_frame()
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
		_strip_box.remove_child(child)
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
		if not cut.is_empty() and purpose != "hero":
			for number in range(attacks.size()):
				if int(attacks[number].start) == index and attacks.size() > 1:
					tags += " A%d" % (number + 1)
				if int(attacks[number].hit) == index:
					tags += " HIT"
		var looked := index < checked.size() and bool(checked[index])
		if is_quick() and mode == "hero_weapon" and index < track.size():
			if looked:
				tags += " ok"
			elif auto_unsure.has(index) or not (track[index].grip is Vector2 and track[index].tip is Vector2):
				tags += " ?"
		button.text = tags
		var color := INK
		if is_quick() and looked:
			color = GOOD
		elif is_quick() and auto_unsure.has(index):
			color = BAD
		button.add_theme_color_override("font_color", AMBER if index == selected else color)

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
