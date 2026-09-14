extends "res://scripts/game/encounter_controller.gd"

const ContactShadowScript = preload("res://scripts/game/presentation/contact_shadow.gd")
const ActivityVisualScript = preload("res://scripts/game/presentation/activity_visual.gd")
const FoundryVisualConfigScript = preload("res://scripts/game/presentation/visual_config.gd")

enum ComparisonMode { BASELINE, ENVIRONMENT, EFFECTS, FULL }

@export var cinematic_presentation := true
@export var shadows_enabled := true
@export var scene_seed: int = 20260912
@export var cinematic_backdrop_path := ""
@export var cinematic_lane_path := ""
@export var cinematic_art_approved := false

var comparison_mode: int = ComparisonMode.FULL
var experiment_controls: CanvasLayer
var shadow_nodes: Dictionary = {}
var frozen := false
var controls_visible := true
var debug_markers := false
var visual_config: RefCounted = FoundryVisualConfigScript.new()
var activity_visual: Node2D
var baseline_backdrop: Texture2D
var baseline_lane: Texture2D
var cinematic_backdrop: Texture2D
var cinematic_lane: Texture2D
var placeholder_label: Label

func _ready() -> void:
	persistence_enabled = false
	use_prepared_environment = true
	super._ready()
	loot_rng_state = scene_seed
	if environment_visual != null:
		baseline_backdrop = environment_visual.backdrop_texture
		baseline_lane = environment_visual.lane_texture
	_load_cinematic_textures()
	_exclude_hud_from_lights()
	activity_visual = ActivityVisualScript.new()
	add_child(activity_visual)
	activity_visual.configure(self, visual_config)
	_build_experiment_controls()
	_exclude_hud_from_lights()
	_apply_comparison_mode()
	_refresh_shadows()
	_refresh_activity()
	if run_state.phase == RunStateScript.Phase.READY:
		start_run()
	loot_rng_state = scene_seed

func _process(delta: float) -> void:
	if not frozen:
		super._process(delta)
	_refresh_shadows()
	_refresh_activity()

func _physics_process(delta: float) -> void:
	if frozen or run_state.paused:
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
			call_deferred("restart_experiment")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			controls_visible = not controls_visible
			experiment_controls.get_node("Panel").visible = controls_visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			debug_markers = not debug_markers
			_refresh_activity()
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
	panel.size = Vector2(268.0, 392.0)
	experiment_controls.add_child(panel)
	var title := Label.new()
	title.position = Vector2(16.0, 12.0)
	title.text = "CINEMATIC FOUNDRY / C04"
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)
	var state := Label.new()
	state.name = "State"
	state.position = Vector2(16.0, 38.0)
	state.add_theme_font_size_override("font_size", 13)
	panel.add_child(state)
	placeholder_label = Label.new()
	placeholder_label.name = "Placeholder"
	placeholder_label.position = Vector2(16.0, 58.0)
	placeholder_label.add_theme_font_size_override("font_size", 11)
	placeholder_label.add_theme_color_override("font_color", Color("d7b36a"))
	panel.add_child(placeholder_label)
	var help := Label.new()
	help.position = Vector2(16.0, 78.0)
	help.text = "F1 compare  F2 freeze\nF3 repeat seed  F4 hide\nF5 drill markers"
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
	_add_effect_toggle(panel, "Halos", "LAMP HALOS", "lamp_halos", 148.0)
	_add_effect_toggle(panel, "DrillLight", "DRILL LIGHT", "drill_light", 178.0)
	_add_effect_toggle(panel, "Muzzle", "MUZZLE FLASH", "muzzle_flashes", 208.0)
	_add_effect_toggle(panel, "Steam", "STEAM", "steam", 238.0)
	_add_effect_toggle(panel, "Dust", "DUST", "dust", 268.0)
	_add_effect_toggle(panel, "Sparks", "SPARKS", "sparks", 298.0)

func _add_effect_toggle(panel: Panel, node_name: String, label: String, effect_id: String, y: float) -> void:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.position = Vector2(12.0, y)
	toggle.text = label
	toggle.button_pressed = visual_config.is_effect_enabled(effect_id)
	toggle.toggled.connect(func(value: bool) -> void:
		visual_config.set_effect(effect_id, value)
		_refresh_activity())
	panel.add_child(toggle)

func _toggle_presentation() -> void:
	set_comparison_mode((comparison_mode + 1) % 4)

func set_comparison_mode(mode: int) -> void:
	comparison_mode = mode
	cinematic_presentation = mode != ComparisonMode.BASELINE
	_apply_comparison_mode()

func _toggle_freeze() -> void:
	frozen = not frozen
	_apply_freeze_mode()
	_update_control_state()

func _apply_freeze_mode() -> void:
	var mode := Node.PROCESS_MODE_DISABLED if frozen or run_state.paused else Node.PROCESS_MODE_INHERIT
	if hero != null and hero.visual != null:
		hero.visual.process_mode = mode
	if harvester_visual != null:
		harvester_visual.process_mode = mode
	if activity_visual != null:
		activity_visual.process_mode = mode
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.visual != null:
			enemy.visual.process_mode = mode

func _load_cinematic_textures() -> void:
	if cinematic_backdrop == null and cinematic_backdrop_path != "" and ResourceLoader.exists(cinematic_backdrop_path):
		cinematic_backdrop = load(cinematic_backdrop_path)
	if cinematic_lane == null and cinematic_lane_path != "" and ResourceLoader.exists(cinematic_lane_path):
		cinematic_lane = load(cinematic_lane_path)

func _exclude_hud_from_lights() -> void:
	var hud_layer := get_node_or_null("EncounterLayer")
	if hud_layer != null:
		_set_light_mask_recursive(hud_layer, 0)
	if experiment_controls != null:
		_set_light_mask_recursive(experiment_controls, 0)
	if loot_dev_console != null:
		_set_light_mask_recursive(loot_dev_console, 0)
	if environment_visual != null:
		environment_visual.light_mask = 1
	if harvester_visual != null:
		_set_light_mask_recursive(harvester_visual, 1)
	if hero != null:
		_set_light_mask_recursive(hero, 1)

func _set_light_mask_recursive(node: Node, mask: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = mask
	for child in node.get_children():
		_set_light_mask_recursive(child, mask)

func _comparison_uses_cinematic_environment() -> bool:
	return comparison_mode == ComparisonMode.ENVIRONMENT or comparison_mode == ComparisonMode.FULL

func _comparison_uses_effects() -> bool:
	return comparison_mode == ComparisonMode.EFFECTS or comparison_mode == ComparisonMode.FULL

func _comparison_label() -> String:
	match comparison_mode:
		ComparisonMode.BASELINE:
			return "BASELINE"
		ComparisonMode.ENVIRONMENT:
			return "ENVIRONMENT"
		ComparisonMode.EFFECTS:
			return "EFFECTS"
		_:
			return "FULL"

func _apply_comparison_mode() -> void:
	_refresh_presentation()
	_refresh_shadows()
	_refresh_activity()

func _refresh_presentation() -> void:
	if environment_visual == null:
		return
	environment_visual.use_prepared_layers = true
	var use_cinematic := _comparison_uses_cinematic_environment() and cinematic_backdrop != null and cinematic_lane != null and cinematic_art_approved
	environment_visual.backdrop_texture = cinematic_backdrop if use_cinematic else baseline_backdrop
	environment_visual.lane_texture = cinematic_lane if use_cinematic else baseline_lane
	environment_visual.queue_redraw()
	_update_control_state()

func _update_control_state() -> void:
	if experiment_controls == null:
		return
	var state: Label = experiment_controls.get_node("Panel/State")
	state.text = "%s  /  %s  /  seed %d" % [_comparison_label(), "FROZEN" if frozen else "LIVE", scene_seed]
	if placeholder_label != null:
		if cinematic_art_approved and cinematic_backdrop != null:
			placeholder_label.text = ""
		elif cinematic_backdrop != null:
			placeholder_label.text = "Unapproved art loaded (REVIEW A)"
		else:
			placeholder_label.text = "Prepared baseline (REVIEW A pending)"

func restart_experiment() -> Node:
	var packed: PackedScene = load("res://scenes/experiments/cinematic_foundry.tscn")
	var next: Node = packed.instantiate()
	next.scene_seed = scene_seed
	next.cinematic_presentation = cinematic_presentation
	next.shadows_enabled = shadows_enabled
	next.comparison_mode = comparison_mode
	next.cinematic_backdrop_path = cinematic_backdrop_path
	next.cinematic_lane_path = cinematic_lane_path
	next.cinematic_art_approved = cinematic_art_approved
	next.cinematic_backdrop = cinematic_backdrop
	next.cinematic_lane = cinematic_lane
	next.debug_markers = debug_markers
	next.visual_config = visual_config.copy()
	var parent := get_parent()
	var index := get_index()
	parent.add_child(next)
	parent.move_child(next, index)
	queue_free()
	return next

func retry() -> void:
	super.retry()
	if activity_visual != null:
		activity_visual.reset()
	_refresh_activity()

func spawn_friendly_projectile(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	super.spawn_friendly_projectile(origin_x, target_x, target_enemy)
	_notify_hero_shot()

func spawn_friendly_volley(origin_x: float, target_x: float, target_enemy: Node = null) -> void:
	super.spawn_friendly_volley(origin_x, target_x, target_enemy)
	_notify_hero_shot()

func spawn_hostile_projectile(origin_x: float, target_x: float, damage: float, source_enemy: Node = null, target_y: float = INF) -> void:
	super.spawn_hostile_projectile(origin_x, target_x, damage, source_enemy, target_y)
	if activity_visual != null and source_enemy != null:
		activity_visual.notify_shot("ranged", source_enemy.position, -source_enemy.side)

func _notify_hero_shot() -> void:
	if activity_visual != null and hero != null:
		activity_visual.notify_shot("hero", hero.position, hero.last_facing)

func set_experiment_paused(should_pause: bool) -> void:
	super.set_experiment_paused(should_pause)
	_apply_freeze_mode()

func activity_node_count() -> int:
	return get_children().filter(func(child: Node) -> bool: return child.name == "FoundryActivityVisual").size()

func _refresh_activity() -> void:
	if activity_visual == null:
		return
	activity_visual.visible = _comparison_uses_effects()
	activity_visual.debug_markers = debug_markers
	activity_visual.configure(self, visual_config)
	activity_visual.queue_redraw()

func _refresh_shadows() -> void:
	var targets: Array[Node2D] = []
	if hero != null:
		targets.append(hero)
	if harvester_visual != null:
		targets.append(harvester_visual)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			targets.append(enemy)
	var show_shadow := shadows_enabled and _comparison_uses_effects()
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
		shadow.enabled = show_shadow
		shadow.visible = show_shadow
	for key in shadow_nodes.keys():
		var shadow: Node2D = shadow_nodes[key]
		var target_is_dead: bool = is_instance_valid(shadow.target) and "dead" in shadow.target and bool(shadow.target.get("dead"))
		if not is_instance_valid(shadow.target) or shadow.target.is_queued_for_deletion() or target_is_dead:
			shadow.queue_free()
			shadow_nodes.erase(key)
