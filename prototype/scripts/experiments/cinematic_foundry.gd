extends "res://scripts/game/encounter_controller.gd"

const ContactShadowScript = preload("res://scripts/experiments/cinematic_foundry/contact_shadow.gd")

@export var cinematic_presentation := true
@export var shadows_enabled := true
@export var scene_seed: int = 20260912

var experiment_controls: CanvasLayer
var shadow_nodes: Dictionary = {}
var frozen := false
var controls_visible := true

func _ready() -> void:
	persistence_enabled = false
	use_prepared_environment = cinematic_presentation
	super._ready()
	loot_rng_state = scene_seed
	_build_experiment_controls()
	_refresh_presentation()
	_refresh_shadows()
	if run_state.phase == RunStateScript.Phase.READY:
		start_run()

func _process(delta: float) -> void:
	if not frozen:
		super._process(delta)
	_refresh_shadows()

func _physics_process(delta: float) -> void:
	if frozen:
		return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_toggle_presentation()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			_toggle_freeze()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			retry()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			controls_visible = not controls_visible
			experiment_controls.get_node("Panel").visible = controls_visible
			get_viewport().set_input_as_handled()
	if not frozen:
		super._unhandled_input(event)

func _build_experiment_controls() -> void:
	experiment_controls = CanvasLayer.new()
	experiment_controls.name = "FoundryExperimentControls"
	add_child(experiment_controls)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(32.0, 154.0)
	panel.size = Vector2(268.0, 162.0)
	experiment_controls.add_child(panel)
	var title := Label.new()
	title.position = Vector2(16.0, 12.0)
	title.text = "CINEMATIC FOUNDRY / C01"
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)
	var state := Label.new()
	state.name = "State"
	state.position = Vector2(16.0, 38.0)
	state.add_theme_font_size_override("font_size", 13)
	panel.add_child(state)
	var help := Label.new()
	help.position = Vector2(16.0, 72.0)
	help.text = "F1 presentation  F2 freeze\nF3 repeat seed  F4 hide controls"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("a7bcc0"))
	panel.add_child(help)
	var shadows := CheckButton.new()
	shadows.name = "Shadows"
	shadows.position = Vector2(12.0, 118.0)
	shadows.text = "CONTACT SHADOWS"
	shadows.button_pressed = shadows_enabled
	shadows.toggled.connect(func(value: bool) -> void:
		shadows_enabled = value
		_refresh_shadows())
	panel.add_child(shadows)

func _toggle_presentation() -> void:
	cinematic_presentation = not cinematic_presentation
	_refresh_presentation()

func _toggle_freeze() -> void:
	frozen = not frozen
	_update_control_state()

func _refresh_presentation() -> void:
	if environment_visual == null:
		return
	environment_visual.use_prepared_layers = cinematic_presentation
	environment_visual.queue_redraw()
	_update_control_state()

func _update_control_state() -> void:
	if experiment_controls == null:
		return
	var state: Label = experiment_controls.get_node("Panel/State")
	state.text = "%s  /  %s  /  seed %d" % ["CINEMATIC" if cinematic_presentation else "BASELINE", "FROZEN" if frozen else "LIVE", scene_seed]

func _refresh_shadows() -> void:
	var targets: Array[Node2D] = []
	if hero != null:
		targets.append(hero)
	if harvester_visual != null:
		targets.append(harvester_visual)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			targets.append(enemy)
	for target in targets:
		var shadow_key := str(target.get_instance_id())
		var shadow: Node2D = shadow_nodes.get(shadow_key)
		if shadow == null:
			shadow = ContactShadowScript.new()
			if target == harvester_visual:
				shadow.width = 64.0
				shadow.height = 12.0
			shadow.track(target)
			add_child(shadow)
			shadow_nodes[shadow_key] = shadow
		shadow.visible = shadows_enabled
	for key in shadow_nodes.keys():
		var shadow: Node2D = shadow_nodes[key]
		var target_is_dead: bool = is_instance_valid(shadow.target) and "dead" in shadow.target and bool(shadow.target.get("dead"))
		if not is_instance_valid(shadow.target) or shadow.target.is_queued_for_deletion() or target_is_dead:
			shadow.queue_free()
			shadow_nodes.erase(key)