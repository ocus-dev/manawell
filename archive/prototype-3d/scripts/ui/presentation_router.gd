extends Control

const PausePanelScript = preload("res://scripts/ui/pause_panel.gd")
const ResultPanelScript = preload("res://scripts/ui/result_panel.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")

signal resume_requested
signal settings_requested
signal abandon_requested
signal return_requested
signal retry_requested

var pause_panel
var result_panel
var mode: String = "hidden"

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	_build()

func configure(view_state: Dictionary) -> void:
	if pause_panel == null:
		_build()
	pause_panel.configure(view_state.get("combat", {}))
	result_panel.configure(view_state.get("results", {}))

func show_pause(view_data: Dictionary) -> void:
	if pause_panel == null:
		_build()
	pause_panel.configure(view_data)
	mode = "pause"
	mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = true
	result_panel.visible = false
	pause_panel.get_node("PauseContent/Resume").grab_focus()

func show_results(view_data: Dictionary) -> void:
	if result_panel == null:
		_build()
	result_panel.configure(view_data)
	mode = "results"
	mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	result_panel.visible = true
	result_panel.get_node("ResultContent/ReturnToOperations").grab_focus()

func hide_overlays() -> void:
	mode = "hidden"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.visible = false
	result_panel.visible = false

func _build() -> void:
	if pause_panel != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel = PausePanelScript.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-180, -125)
	pause_panel.resume_requested.connect(_on_resume_requested)
	pause_panel.settings_requested.connect(settings_requested.emit)
	pause_panel.abandon_requested.connect(abandon_requested.emit)
	add_child(pause_panel)
	result_panel = ResultPanelScript.new()
	result_panel.name = "ResultPanel"
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.position = Vector2(-190, -145)
	result_panel.return_requested.connect(_on_return_requested)
	result_panel.retry_requested.connect(_on_retry_requested)
	add_child(result_panel)
	hide_overlays()

func _on_resume_requested() -> void:
	hide_overlays()
	resume_requested.emit()

func _on_return_requested() -> void:
	hide_overlays()
	return_requested.emit()

func _on_retry_requested() -> void:
	hide_overlays()
	retry_requested.emit()
