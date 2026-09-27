extends Control

const HERO_HUB_SCENE := "res://scenes/hero_hub.tscn"
const SAVE_PATH := "user://account_save.json"
const BACKUP_PATH := "user://account_save.bak"
const MONSTER_TEST_ARENA_SCENE := "res://scenes/tools/monster_test_arena.tscn"
const WEAPON_LAB_SCENE := "res://scenes/tools/weapon_lab.tscn"
const MonsterEncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")

@onready var menu: VBoxContainer = $Menu
@onready var continue_button: Button = $Menu/Continue
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var new_game_confirmation: ConfirmationDialog = $NewGameConfirmation

var monster_encyclopedia: CanvasLayer

func _ready() -> void:
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(BACKUP_PATH)
	$Menu/Continue.pressed.connect(_start_game)
	$Menu/NewGame.pressed.connect(_request_new_game)
	$Menu/Settings.pressed.connect(_show_settings)
	$Menu/Quit.pressed.connect(get_tree().quit)
	$SettingsPanel/Settings/Fullscreen.toggled.connect(_set_fullscreen)
	$SettingsPanel/Settings/Back.pressed.connect(_hide_settings)
	new_game_confirmation.confirmed.connect(_start_new_game)
	$SettingsPanel/Settings/Fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_add_dev_tools()
	if continue_button.disabled:
		$Menu/NewGame.grab_focus()
	else:
		continue_button.grab_focus()

## Debug builds only: DEV ENCYCLOPEDIA (and F9) for tuning monster stats, and
## MONSTER ARENA for watching those stats hit an invincible dummy, and WEAPON LAB
## for importing weapon art and testing weapons.
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()

func _start_game() -> void:
	get_tree().change_scene_to_file(HERO_HUB_SCENE)

func _request_new_game() -> void:
	if continue_button.disabled:
		_start_game()
		return
	new_game_confirmation.popup_centered()

func _start_new_game() -> void:
	var store := preload("res://scripts/model/save_store.gd").new()
	if not store.clear_save():
		push_warning(store.last_error)
	_start_game()

func _show_settings() -> void:
	menu.visible = false
	settings_panel.visible = true
	$SettingsPanel/Settings/Fullscreen.grab_focus()

func _hide_settings() -> void:
	settings_panel.visible = false
	menu.visible = true
	$Menu/Settings.grab_focus()

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
