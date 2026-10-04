extends Control

## Parked for later (not opened by the game right now): the Hero Roster screen.
const HERO_HUB_SCENE := "res://scenes/hero_hub.tscn"
const OPERATIONS_SCENE := "res://scenes/main.tscn"
const GameFlowScript = preload("res://scripts/model/game_flow.gd")
const SAVE_PATH := "user://account_save.json"
const BACKUP_PATH := "user://account_save.bak"
const MONSTER_TEST_ARENA_SCENE := "res://scenes/tools/monster_test_arena.tscn"
const WEAPON_LAB_SCENE := "res://scenes/tools/weapon_lab.tscn"
const CREATURE_LAB_SCENE := "res://scenes/tools/creature_lab.tscn"
const MonsterEncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const MenuStyleScript = preload("res://scripts/ui/title_menu_style.gd")

@onready var menu: VBoxContainer = $Menu
@onready var play_button: Button = $Menu/Play
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var new_game_confirmation: ConfirmationDialog = $NewGameConfirmation

var monster_encyclopedia: CanvasLayer

func _ready() -> void:
	# One save profile: PLAY loads it, or starts the tutorial on first launch.
	play_button.pressed.connect(play)
	$SettingsPanel/Settings/ResetProgress.pressed.connect(_request_reset)
	$Menu/Settings.pressed.connect(_show_settings)
	$Menu/Quit.pressed.connect(get_tree().quit)
	$SettingsPanel/Settings/Fullscreen.toggled.connect(_set_fullscreen)
	$SettingsPanel/Settings/Back.pressed.connect(_hide_settings)
	new_game_confirmation.confirmed.connect(_start_new_game)
	_style_new_game_dialog()
	$SettingsPanel/Settings/Fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_add_dev_tools()
	# Readable menu: dark button plates with light text, amber + ▶ when
	# selected, and the dev tools grouped under a divider.
	MenuStyleScript.apply(self, "plates")
	MenuStyleScript.style_settings(self)
	_explain_embedded_fullscreen()
	play_button.grab_focus()
	# Coming back from a spawn preview: reopen the spawn editor on that level.
	if not GameFlowScript.reopen_spawn_editor_level.is_empty() and monster_encyclopedia != null:
		var level_id := GameFlowScript.reopen_spawn_editor_level
		GameFlowScript.reopen_spawn_editor_level = ""
		monster_encyclopedia.open_spawn_editor.call_deferred(level_id)

## Debug builds only: DEV ENCYCLOPEDIA (and F9) for tuning monster stats, and
## MONSTER ARENA for watching those stats hit an invincible dummy, WEAPON LAB
## for importing weapon art and testing weapons, and CREATURE LAB for turning
## creature concept art into animated encyclopedia monsters.
func _add_dev_tools() -> void:
	if not OS.is_debug_build():
		return
	monster_encyclopedia = MonsterEncyclopediaScript.new()
	monster_encyclopedia.name = "MonsterEncyclopedia"
	add_child(monster_encyclopedia)
	monster_encyclopedia.closed.connect(func() -> void: $Menu/DevEncyclopedia.grab_focus())
	# Grow the menu downward so the extra entries don't slide up under the logo.
	menu.grow_vertical = Control.GROW_DIRECTION_END
	_add_dev_button("DevEncyclopedia", "D E V   E N C Y C L O P E D I A", open_monster_encyclopedia)
	_add_dev_button("MonsterTestArena", "M O N S T E R   A R E N A", open_monster_test_arena)
	_add_dev_button("CreatureLab", "C R E A T U R E   L A B", open_creature_lab)
	_add_dev_button("WeaponLab", "W E A P O N   L A B", open_weapon_lab)

func _add_dev_button(node_name: String, label: String, action: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(230, 48)
	button.text = label
	button.add_theme_color_override("font_color", Color(0.16, 0.1, 0.02, 1))
	button.pressed.connect(action)
	menu.add_child(button)
	menu.move_child(button, $Menu/Quit.get_index())

func open_monster_encyclopedia() -> void:
	if monster_encyclopedia != null:
		monster_encyclopedia.open()

func open_monster_test_arena() -> void:
	get_tree().change_scene_to_file(MONSTER_TEST_ARENA_SCENE)

func open_weapon_lab() -> void:
	get_tree().change_scene_to_file(WEAPON_LAB_SCENE)

func open_creature_lab() -> void:
	get_tree().change_scene_to_file(CREATURE_LAB_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()

func _start_game() -> void:
	get_tree().change_scene_to_file(OPERATIONS_SCENE)

## True once a profile exists (the backup counts if the main file is damaged).
func has_profile() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

func play() -> void:
	if has_profile():
		GameFlowScript.play_requested = true
		_start_game()
	else:
		_start_new_game()

## Settings > Reset progress: erase the profile (after confirming) and start
## over from the tutorial.
func _request_reset() -> void:
	if not has_profile():
		_start_new_game()
		return
	new_game_confirmation.popup_centered()
	# Safer default: Enter/Space cancels unless the player picks the red button.
	new_game_confirmation.get_cancel_button().grab_focus()

## Makes the "replace your save?" dialog easy to read: large light text on a
## dark panel, a clear title bar, a red destructive button and a plain Cancel.
func _style_new_game_dialog() -> void:
	var dialog := new_game_confirmation
	dialog.title = "Reset progress?"
	dialog.dialog_text = "This erases your character's progress and starts over from the tutorial."
	dialog.ok_button_text = "Erase and start over"
	dialog.cancel_button_text = "Keep my progress"
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(520, 0)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("141a20")
	body.set_content_margin_all(24)
	dialog.add_theme_stylebox_override("panel", body)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1d252d")
	frame.border_color = MenuStyleScript.AMBER
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	frame.expand_margin_left = 2
	frame.expand_margin_right = 2
	frame.expand_margin_bottom = 2
	frame.expand_margin_top = 40
	dialog.add_theme_stylebox_override("embedded_border", frame)
	dialog.add_theme_stylebox_override("embedded_unfocused_border", frame)
	dialog.add_theme_font_size_override("title_font_size", 22)
	dialog.add_theme_color_override("title_color", MenuStyleScript.INK)
	dialog.add_theme_constant_override("title_height", 40)
	dialog.add_theme_constant_override("buttons_separation", 16)
	var label := dialog.get_label()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", MenuStyleScript.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_dialog_button(dialog.get_ok_button(), Color("8f2f28"), Color("e06a5c"))
	_style_dialog_button(dialog.get_cancel_button(), Color("2a333c"), Color("6c7a86"))

func _style_dialog_button(button: Button, fill: Color, border: Color) -> void:
	button.custom_minimum_size = Vector2(200, 48)
	button.add_theme_font_size_override("font_size", 18)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, Color.WHITE)
	var states := {"normal": fill, "hover": fill.lightened(0.15), "pressed": fill.darkened(0.2), "focus": fill}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state]
		box.border_color = Color.WHITE if state == "focus" else border
		box.set_border_width_all(3 if state == "focus" else 2)
		box.set_corner_radius_all(6)
		box.set_content_margin_all(10)
		button.add_theme_stylebox_override(state, box)

func _start_new_game() -> void:
	var store := preload("res://scripts/model/save_store.gd").new()
	if not store.clear_save():
		push_warning(store.last_error)
	GameFlowScript.start_tutorial = true
	_start_game()

func _show_settings() -> void:
	menu.visible = false
	settings_panel.visible = true
	$SettingsPanel/Settings/Fullscreen.grab_focus()

func _hide_settings() -> void:
	settings_panel.visible = false
	menu.visible = true
	$Menu/Settings.grab_focus()

## Inside the editor's Game tab the window can't go fullscreen (Godot only
## allows windowed mode there), so the toggle is turned off with a note.
func is_embedded_in_editor() -> bool:
	return Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor"))

func _explain_embedded_fullscreen() -> void:
	if not is_embedded_in_editor():
		return
	var toggle: CheckButton = $SettingsPanel/Settings/Fullscreen
	toggle.disabled = true
	toggle.tooltip_text = "Not available inside the editor's Game tab."
	var note := Label.new()
	note.name = "FullscreenNote"
	note.text = "Fullscreen isn't available while the game runs inside the editor's Game tab. Use the tab's Stretch to Fit button, or untick Embed Game on Next Play to run in its own window."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(280, 0)
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("d9cfbd"))
	$SettingsPanel/Settings.add_child(note)
	$SettingsPanel/Settings.move_child(note, toggle.get_index() + 1)

func _set_fullscreen(enabled: bool) -> void:
	if is_embedded_in_editor():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
