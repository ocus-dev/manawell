class_name HomeArea
extends Node2D

## Home: the main city. For now just a walkable area: the hero runs back and
## forth on the floor. No drill, no monsters, no saving. Opened from the map's
## "Home" button; Esc (or Back to map) returns to the map page.
##
## The base is wider than the screen: SECTION_COUNT screens side by side with a
## camera following the hero, so you can walk right to explore. The backdrop is
## one continuous scene in two layers, both made from the original home art
## (see art/side-view/environment/home_backdrop/make_layers.py):
## - the far sky + mountains (one long panorama, sun only at the start) scroll
##   slowly behind (parallax), just enough to reach the end of the base;
## - the treeline, barrier wall and tarmac scroll with the hero: the original
##   screen first, then a mirrored/plain tile pair repeated, so every join is
##   pixel-continuous. It is cut cleanly along the top of the runway and its
##   wall, so everything above (trees, fog) comes only from the sky layer.
## The command center stands in the first section and
## each copy after it holds one building from BUILDINGS (hangar, power core,
## comms tower, defense turret); the last copy is still open ground.
##
## Clicking the command center opens the mech skill tree (SkillTreePanel), the
## only place it can be changed. Home loads the saved profile for that and
## saves it again after each change (keeping the rest of the save as loaded).

const HeroScript = preload("res://scripts/game/player.gd")
const CommandCenterAnimScript = preload("res://scripts/game/command_center_anim.gd")
const ContactShadowScript = preload("res://scripts/game/presentation/contact_shadow.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const GameFlowScript = preload("res://scripts/model/game_flow.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SkillTreePanelScript = preload("res://scripts/ui/skill_tree_panel.gd")
## The command center brightens this much while the mouse is over it.
const COMMAND_CENTER_HOVER_MODULATE := Color(1.18, 1.18, 1.18)

const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const BACKDROP_PATH := "res://assets/side-view/environment/home_city.png"
const SKY_PATH := "res://assets/side-view/environment/home_sky_far.png"
const GROUND_START_PATH := "res://assets/side-view/environment/home_ground_start.png"
const GROUND_TILE_PATH := "res://assets/side-view/environment/home_ground_tile.png"
## The layers are in the backdrop's source pixels (1672 wide); this maps them to
## the 1280x720 canvas, same as the original backdrop.
const BACKDROP_SCALE: float = 1280.0 / 1672.0
## The EDF command center, cut out of its own art and stood in the middle of
## the tarmac. Width and base line are in the 1280x720 logical canvas; the tint
## warms its daylight art to match the sunset backdrop.
const COMMAND_CENTER_PATH := "res://assets/side-view/environment/home_command_center.png"
const COMMAND_CENTER_WIDTH: float = 820.0
const COMMAND_CENTER_BASE_Y: float = 400.0
const COMMAND_CENTER_TINT := Color(1.0, 0.92, 0.84)
const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_STEP: float = 1.0 / 60.0
## The original section plus 5 copies of it to the right.
const SECTION_COUNT: int = 6
const SECTION_WIDTH: float = 1280.0
## How far in from either end of the base the hero stops (same as the arena).
const EDGE_MARGIN: float = 96.0
## The hero walks this many times faster in Home than in combat.
const HOME_WALK_SPEED_MULTIPLIER: float = 2.0
## Camera catch-up speed (higher = snappier).
const CAMERA_SMOOTHING_SPEED: float = 6.0
## One building per copied section, cut out of its own art and stood on the
## same base line as the command center (centred in its section). `width` is
## the draw width in the 1280x720 canvas; the height follows the art. They share
## the command center's warm tint so their daylight art sits in the sunset.
const BUILDINGS: Array[Dictionary] = [
	{"id": "comms_tower", "path": "res://assets/side-view/environment/home_comms_tower.png", "section": 3, "width": 758.0},
	{"id": "power_core", "path": "res://assets/side-view/environment/home_power_core.png", "section": 2, "width": 751.0},
	{"id": "hangar", "path": "res://assets/side-view/environment/home_hangar.png", "section": 1, "width": 760.0},
	{"id": "defense_turret", "path": "res://assets/side-view/environment/home_defense_turret.png", "section": 4, "width": 767.0},
]

var backdrop_texture: Texture2D
var sky_texture: Texture2D
var ground_start_texture: Texture2D
var ground_tile_texture: Texture2D
## Draws the far sky behind everything; moved each frame for parallax.
var sky_layer: Node2D
var command_center_texture: Texture2D
## Textures for BUILDINGS, same order (null when an image is missing).
var building_textures: Array[Texture2D] = []
## Draws the building (with its tower crew and moving parts) when present.
var command_center_anim: Node2D
var hero: Node2D
var camera: Camera2D
var shadow: Node2D
var hud: CanvasLayer
var back_button: Button
var move_left_held := false
var move_right_held := false
var jump_held := false
var pending_jump := false
var leaving := false
## Off in tests: Home then starts from a fresh account and never writes saves.
var persistence_enabled := true
var save_store: RefCounted
var account: RefCounted
var skill_panel: Control
var command_center_hovered := false
var hover_prompt: Label
## The command center art's pixels, for clicking only on the building itself.
var command_center_image: Image

func _ready() -> void:
	_load_account()
	backdrop_texture = _load_texture(BACKDROP_PATH)
	sky_texture = _load_texture(SKY_PATH)
	ground_start_texture = _load_texture(GROUND_START_PATH)
	ground_tile_texture = _load_texture(GROUND_TILE_PATH)
	if has_continuous_backdrop():
		sky_layer = Node2D.new()
		sky_layer.name = "SkyLayer"
		sky_layer.z_index = -1
		sky_layer.draw.connect(_draw_sky)
		add_child(sky_layer)
	command_center_texture = _load_texture(COMMAND_CENTER_PATH)
	if command_center_texture != null:
		command_center_image = command_center_texture.get_image()
		if command_center_image != null and command_center_image.is_compressed():
			command_center_image.decompress()
	for building in BUILDINGS:
		building_textures.append(_load_texture(str(building["path"])))
	if command_center_texture != null:
		var anim: Node2D = CommandCenterAnimScript.new()
		anim.name = "CommandCenterAnim"
		anim.z_index = 1
		add_child(anim)
		anim.configure(command_center_rect(), Vector2(command_center_texture.get_size()), COMMAND_CENTER_TINT, command_center_texture)
		command_center_anim = anim
	hero = HeroScript.new()
	hero.name = "Hero"
	hero.z_index = 2
	add_child(hero)
	hero.configure_hero(GameFlowScript.home_hero_id)
	hero.reset_motion()
	hero.left_bound = EDGE_MARGIN
	hero.right_bound = world_width() - EDGE_MARGIN
	hero.walk_speed_multiplier = HOME_WALK_SPEED_MULTIPLIER
	hero.position.x = LOGICAL_SIZE.x * 0.5
	shadow = ContactShadowScript.new()
	shadow.name = "HeroShadow"
	shadow.track(hero)
	add_child(shadow)
	_build_camera()
	_build_hud()
	_update_sky_parallax()
	queue_redraw()

## Total walkable width: every section side by side.
static func world_width() -> float:
	return SECTION_WIDTH * float(SECTION_COUNT)

## Where section `index` (0 = the original) is drawn.
static func section_rect(index: int) -> Rect2:
	return Rect2(Vector2(SECTION_WIDTH * float(index), 0.0), LOGICAL_SIZE)

## Follows the hero sideways; the limits keep the view inside the base.
func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "HomeCamera"
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_width())
	camera.limit_bottom = int(LOGICAL_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	add_child(camera)
	camera.make_current()
	_update_camera()
	camera.reset_smoothing()

func _update_camera() -> void:
	if camera == null or hero == null:
		return
	camera.position = Vector2(hero.position.x, LOGICAL_SIZE.y * 0.5)

## True when the layered (continuous) backdrop art is all present.
func has_continuous_backdrop() -> bool:
	return sky_texture != null and ground_start_texture != null and ground_tile_texture != null

## Left edge of what the camera shows, in world space.
func view_left() -> float:
	if camera == null or not camera.is_inside_tree():
		return 0.0
	return clampf(camera.get_screen_center_position().x - LOGICAL_SIZE.x * 0.5, 0.0, maxf(0.0, world_width() - LOGICAL_SIZE.x))

func sky_size() -> Vector2:
	if sky_texture == null:
		return Vector2.ZERO
	return Vector2(sky_texture.get_size()) * BACKDROP_SCALE

## How fast the sky moves compared to the ground (0 = fixed, 1 = with the
## ground): just enough that the panorama's right end arrives with the base's.
func sky_parallax() -> float:
	var travel := world_width() - LOGICAL_SIZE.x
	if travel <= 0.0:
		return 0.0
	return clampf((sky_size().x - LOGICAL_SIZE.x) / travel, 0.0, 1.0)

## Where the sky panorama starts (world x) for a given view.
func sky_offset_for(left: float) -> float:
	return left * (1.0 - sky_parallax())

func _update_sky_parallax() -> void:
	if sky_layer != null:
		sky_layer.position.x = sky_offset_for(view_left())

func _draw_sky() -> void:
	sky_layer.draw_texture_rect(sky_texture, Rect2(Vector2.ZERO, sky_size()), false)

## The ground pieces in world space: the original screen, then the tile pair
## repeated to the end of the base. Each is anchored to the bottom of the view.
func ground_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not has_continuous_backdrop():
		return rects
	var start_size := Vector2(ground_start_texture.get_size()) * BACKDROP_SCALE
	rects.append(Rect2(Vector2(0.0, LOGICAL_SIZE.y - start_size.y), start_size))
	var tile_size := Vector2(ground_tile_texture.get_size()) * BACKDROP_SCALE
	var x := start_size.x
	while x < world_width():
		rects.append(Rect2(Vector2(x, LOGICAL_SIZE.y - tile_size.y), tile_size))
		x += tile_size.x
	return rects

func _draw_ground() -> void:
	var rects := ground_rects()
	for index in rects.size():
		var rect: Rect2 = rects[index]
		# One extra pixel hides any hairline gap between pieces (the joins are
		# mirror-continuous, so the overlap doesn't show).
		rect.size.x += 1.0
		draw_texture_rect(ground_start_texture if index == 0 else ground_tile_texture, rect, false)

## The imported texture when Godot has imported the PNG; otherwise the raw file
## (a freshly added PNG isn't imported until the editor has seen it).
func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_warning("Home art missing: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

## Where the command center is drawn: centred, standing on its base line.
func command_center_rect() -> Rect2:
	if command_center_texture == null:
		return Rect2()
	var texture_size := Vector2(command_center_texture.get_width(), command_center_texture.get_height())
	var draw_size := Vector2(COMMAND_CENTER_WIDTH, COMMAND_CENTER_WIDTH * texture_size.y / texture_size.x)
	return Rect2(Vector2(LOGICAL_SIZE.x * 0.5 - draw_size.x * 0.5, COMMAND_CENTER_BASE_Y - draw_size.y), draw_size)

func _draw_command_center() -> void:
	var rect := command_center_rect()
	if rect.size == Vector2.ZERO:
		return
	_draw_ground_shadow(rect)
	if command_center_anim == null:
		draw_texture_rect(command_center_texture, rect, false, COMMAND_CENTER_TINT)

## Where building `index` of BUILDINGS is drawn: centred in its section,
## standing on the command center's base line.
func building_rect(index: int) -> Rect2:
	if index < 0 or index >= building_textures.size() or building_textures[index] == null:
		return Rect2()
	var texture := building_textures[index]
	var building: Dictionary = BUILDINGS[index]
	var width := float(building["width"])
	var draw_size := Vector2(width, width * float(texture.get_height()) / float(texture.get_width()))
	var center_x := section_rect(int(building["section"])).get_center().x
	return Rect2(Vector2(center_x - draw_size.x * 0.5, COMMAND_CENTER_BASE_Y - draw_size.y), draw_size)

func _draw_buildings() -> void:
	for index in BUILDINGS.size():
		var rect := building_rect(index)
		if rect.size == Vector2.ZERO:
			continue
		_draw_ground_shadow(rect)
		draw_texture_rect(building_textures[index], rect, false, COMMAND_CENTER_TINT)

## Soft ground shadow along a building's base.
func _draw_ground_shadow(rect: Rect2) -> void:
	for layer in 4:
		var grow := 6.0 * layer
		var points := PackedVector2Array()
		for index in 32:
			var angle := TAU * float(index) / 32.0
			points.append(Vector2(rect.get_center().x + cos(angle) * (rect.size.x * 0.5 + grow), COMMAND_CENTER_BASE_Y + 1.0 + sin(angle) * (10.0 + grow * 0.5)))
		draw_colored_polygon(points, Color(0.04, 0.03, 0.02, 0.16))

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HomeHud"
	add_child(hud)
	var root := Control.new()
	root.name = "HomeHudRoot"
	root.theme = IndustrialThemeScript.create()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var title := Label.new()
	title.name = "Title"
	title.text = "HOME"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f1eee4"))
	title.add_theme_color_override("font_outline_color", Color("10161b"))
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "A / D or arrows to move   ·   Space to jump   ·   Click the command center for the skill tree   ·   Esc to go back to the map"
	hint.position = Vector2(22, 50)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("e6e0cf"))
	hint.add_theme_color_override("font_outline_color", Color("10161b"))
	hint.add_theme_constant_override("outline_size", 4)
	root.add_child(hint)
	back_button = Button.new()
	back_button.name = "BackToMap"
	back_button.text = "Back to map"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back_button.offset_left = -176.0
	back_button.offset_top = 14.0
	back_button.offset_right = -20.0
	back_button.offset_bottom = 50.0
	back_button.pressed.connect(return_to_map)
	root.add_child(back_button)
	hover_prompt = Label.new()
	hover_prompt.name = "CommandCenterPrompt"
	hover_prompt.text = "COMMAND CENTER  ·  Click to open the skill tree"
	hover_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hover_prompt.offset_left = -260.0
	hover_prompt.offset_right = 260.0
	hover_prompt.offset_top = 84.0
	hover_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hover_prompt.add_theme_font_size_override("font_size", 16)
	hover_prompt.add_theme_color_override("font_color", Color("8ed9df"))
	hover_prompt.add_theme_color_override("font_outline_color", Color("10161b"))
	hover_prompt.add_theme_constant_override("outline_size", 6)
	hover_prompt.visible = false
	root.add_child(hover_prompt)
	skill_panel = SkillTreePanelScript.new()
	skill_panel.visible = false
	root.add_child(skill_panel)
	skill_panel.setup(account)
	skill_panel.changed.connect(_on_skill_tree_changed)

# --- Skill tree (opened from the command center) -----------------------------

## Loads the saved profile so the skill tree shows its nodes and Scrap.
func _load_account() -> void:
	if persistence_enabled:
		save_store = SaveStoreScript.new()
		account = save_store.load_account()
	else:
		account = AccountStateScript.new()

func is_skill_tree_open() -> bool:
	return skill_panel != null and skill_panel.visible

func open_skill_tree() -> void:
	if skill_panel == null or leaving:
		return
	move_left_held = false
	move_right_held = false
	jump_held = false
	pending_jump = false
	_set_command_center_hovered(false)
	skill_panel.open()

func close_skill_tree() -> void:
	if is_skill_tree_open():
		skill_panel.close()

## True when a world point is on the command center building (its painted
## pixels, not the empty sky around it).
func is_on_command_center(world: Vector2) -> bool:
	var rect := command_center_rect()
	if rect.size == Vector2.ZERO or not rect.has_point(world):
		return false
	if command_center_image == null or command_center_image.is_empty():
		return true
	var uv := (world - rect.position) / rect.size
	var pixel := Vector2i(clampi(int(uv.x * command_center_image.get_width()), 0, command_center_image.get_width() - 1), clampi(int(uv.y * command_center_image.get_height()), 0, command_center_image.get_height() - 1))
	return command_center_image.get_pixelv(pixel).a > 0.1

## A click in the world: opens the skill tree when it lands on the command
## center. Returns true when it did.
func click_world(world: Vector2) -> bool:
	if is_skill_tree_open() or not is_on_command_center(world):
		return false
	open_skill_tree()
	return true

func _set_command_center_hovered(hovered: bool) -> void:
	if hovered == command_center_hovered:
		return
	command_center_hovered = hovered
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)
	if hover_prompt != null:
		hover_prompt.visible = hovered
	if command_center_anim != null:
		command_center_anim.modulate = COMMAND_CENTER_HOVER_MODULATE if hovered else Color.WHITE

func _process(_delta: float) -> void:
	_update_sky_parallax()
	if is_skill_tree_open() or leaving:
		_set_command_center_hovered(false)
		return
	_set_command_center_hovered(is_on_command_center(get_global_mouse_position()))

func _on_skill_tree_changed() -> void:
	skill_panel.set_notice("" if save_account() else "Couldn't save: %s" % str(save_store.last_error))

## Writes the profile back with the skill tree change. Everything else in the
## save (production time, campaign progress) is written back as it was loaded.
func save_account() -> bool:
	if not persistence_enabled or save_store == null:
		return true
	return save_store.save_envelope({
		"account": account,
		"production_utc_timestamp": save_store.loaded_production_utc_timestamp,
		"snapshot": save_store.loaded_snapshot,
		"campaign_state": save_store.loaded_campaign_state,
	})

func _unhandled_input(event: InputEvent) -> void:
	if is_skill_tree_open():
		# The tree is modal: Esc closes it, movement keys are ignored.
		if event.is_action_pressed("pause_game"):
			close_skill_tree()
			get_viewport().set_input_as_handled()
		elif event.is_action("move_left") or event.is_action("move_right") or event.is_action("jump"):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click_world(make_input_local(event).position):
			get_viewport().set_input_as_handled()
		return
	if event.is_action("move_left"):
		move_left_held = event.is_pressed()
	elif event.is_action("move_right"):
		move_right_held = event.is_pressed()
	elif event.is_action("jump"):
		jump_held = event.is_pressed()
		if event.is_pressed() and not event.is_echo():
			pending_jump = true
	elif event.is_action_pressed("pause_game"):
		return_to_map()
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		move_left_held = false
		move_right_held = false
		jump_held = false
		pending_jump = false

func _physics_process(_delta: float) -> void:
	step(FIXED_STEP)

## One movement step: walk left/right and jump on the floor.
func step(delta: float) -> void:
	if hero == null:
		return
	var signed_input := (1.0 if move_right_held else 0.0) - (1.0 if move_left_held else 0.0)
	if is_skill_tree_open():
		signed_input = 0.0
		pending_jump = false
	var jump_pressed := pending_jump
	pending_jump = false
	hero.simulate_motion(delta, signed_input, 0, false, jump_pressed, jump_held, false)
	_update_camera()

func return_to_map() -> void:
	if leaving:
		return
	leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	GameFlowScript.return_to_map = true
	get_tree().change_scene_to_file(MAIN_SCENE)

func _draw() -> void:
	if has_continuous_backdrop():
		_draw_ground()
		_draw_command_center()
		_draw_buildings()
	elif backdrop_texture != null:
		for index in SECTION_COUNT:
			draw_texture_rect(backdrop_texture, section_rect(index), false)
		_draw_command_center()
		_draw_buildings()
	else:
		draw_rect(Rect2(0.0, 0.0, world_width(), LOGICAL_SIZE.y), Color("1a232a"), true)
		draw_rect(Rect2(0.0, ArenaLayoutScript.FLOOR_TOP_Y, world_width(), LOGICAL_SIZE.y - ArenaLayoutScript.FLOOR_TOP_Y), Color("6b5a3a"), true)
