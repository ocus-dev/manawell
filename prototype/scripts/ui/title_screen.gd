extends Control

const HERO_HUB_SCENE := "res://scenes/hero_hub.tscn"
const SAVE_PATH := "user://account_save.json"
const BACKUP_PATH := "user://account_save.bak"

@onready var menu: VBoxContainer = $Menu
@onready var continue_button: Button = $Menu/Continue
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var new_game_confirmation: ConfirmationDialog = $NewGameConfirmation

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
	continue_button.grab_focus() if not continue_button.disabled else $Menu/NewGame.grab_focus()

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
