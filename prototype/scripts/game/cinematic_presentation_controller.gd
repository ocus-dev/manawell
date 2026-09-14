extends "res://scripts/game/encounter_controller.gd"

const ContactShadowScript = preload("res://scripts/game/presentation/contact_shadow.gd")
const ActivityVisualScript = preload("res://scripts/game/presentation/activity_visual.gd")
const FoundryVisualConfigScript = preload("res://scripts/game/presentation/visual_config.gd")
const LoadoutDataScript = preload("res://scripts/model/loadout.gd")

var presentation_config: RefCounted = FoundryVisualConfigScript.new()
var activity_visual: Node2D
var shadow_nodes: Dictionary = {}

func _ready() -> void:
	super._ready()
	if selected_well_id.is_empty():
		selected_well_id = "well_1"
	if selected_loadout_id.is_empty():
		selected_loadout_id = LoadoutDataScript.STANDARD
	activity_visual = ActivityVisualScript.new()
	add_child(activity_visual)
	activity_visual.configure(self, presentation_config)
	_set_presentation_light_masks()
	_refresh_presentation_shadows()

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_presentation_shadows()
	_sync_animation_pause()

func _set_presentation_light_masks() -> void:
	if environment_visual != null:
		environment_visual.light_mask = 1
	if harvester_visual != null:
		_set_light_mask_recursive(harvester_visual, 1)
	if hero != null:
		_set_light_mask_recursive(hero, 1)
	if encounter_hud != null:
		_set_light_mask_recursive(encounter_hud, 0)
	if loot_dev_console != null:
		_set_light_mask_recursive(loot_dev_console, 0)

func _set_light_mask_recursive(node: Node, mask: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = mask
	for child in node.get_children():
		_set_light_mask_recursive(child, mask)

func _refresh_presentation_shadows() -> void:
	var targets: Array[Node2D] = []
	if hero != null:
		targets.append(hero)
	if harvester_visual != null:
		targets.append(harvester_visual)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dead:
			targets.append(enemy)
	for target in targets:
		var key := str(target.get_instance_id())
		var shadow: Node2D = shadow_nodes.get(key)
		if shadow == null:
			shadow = ContactShadowScript.new()
			if target == harvester_visual:
				shadow.width = 64.0
				shadow.height = 12.0
			shadow.track(target)
			add_child(shadow)
			shadow_nodes[key] = shadow
		shadow.enabled = true
		shadow.visible = true
	for key in shadow_nodes.keys():
		var shadow: Node2D = shadow_nodes[key]
		var target_is_dead: bool = is_instance_valid(shadow.target) and "dead" in shadow.target and bool(shadow.target.get("dead"))
		if not is_instance_valid(shadow.target) or shadow.target.is_queued_for_deletion() or target_is_dead:
			shadow.queue_free()
			shadow_nodes.erase(key)

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for shadow in shadow_nodes.values():
			if is_instance_valid(shadow):
				shadow.queue_free()

func _sync_animation_pause() -> void:
	var mode := Node.PROCESS_MODE_DISABLED if run_state.paused else Node.PROCESS_MODE_INHERIT
	if hero != null and hero.visual != null:
		hero.visual.process_mode = mode
	if harvester_visual != null:
		harvester_visual.process_mode = mode
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.visual != null:
			enemy.visual.process_mode = mode

func set_experiment_paused(should_pause: bool) -> void:
	super.set_experiment_paused(should_pause)
	_sync_animation_pause()

func _clear_transients() -> void:
	super._clear_transients()
	if activity_visual != null:
		activity_visual.reset()
