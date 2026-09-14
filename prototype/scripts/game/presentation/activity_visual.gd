extends Node2D

const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const ConfigScript = preload("res://scripts/game/presentation/visual_config.gd")
const VisualAssetScript = preload("res://scripts/game/side_view_visual_config.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

# Source-pixel markers on harvester.png, relative to the prepared texture.
# Converted through the same ground-anchor / scale path as the sprite.
const MARKER_SOURCES := {
	"exhaust": Vector2(248.0, 268.0),
	"contact": Vector2(418.0, 688.0),
	"lamp": Vector2(508.0, 348.0),
}

var config: RefCounted = ConfigScript.new()
var controller: Node
var particles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var elapsed := 0.0
var debug_markers := false
var rng := RandomNumberGenerator.new()
var rng_seeded := false
var rear_layer: Node2D
var front_layer: Node2D
var flash_overlay: Node2D
var debug_layer: Node2D
var drill_light: PointLight2D
var light_texture: GradientTexture2D

func _ready() -> void:
	name = "FoundryActivityVisual"
	z_index = 0
	rear_layer = Node2D.new()
	rear_layer.name = "RearActivity"
	rear_layer.z_index = 0
	rear_layer.z_as_relative = true
	rear_layer.draw.connect(_draw_rear)
	add_child(rear_layer)
	front_layer = Node2D.new()
	front_layer.name = "FrontActivity"
	front_layer.z_index = 2
	front_layer.z_as_relative = true
	front_layer.draw.connect(_draw_front)
	add_child(front_layer)
	flash_overlay = Node2D.new()
	flash_overlay.name = "MuzzleOverlay"
	flash_overlay.z_index = 4
	flash_overlay.draw.connect(_draw_flashes)
	add_child(flash_overlay)
	debug_layer = Node2D.new()
	debug_layer.name = "MarkerDebug"
	debug_layer.z_index = 5
	debug_layer.draw.connect(_draw_debug)
	add_child(debug_layer)
	_ensure_light()

func configure(owner: Node, next_config: RefCounted) -> void:
	controller = owner
	config = next_config
	if not rng_seeded and controller != null:
		var seed_variant: Variant = controller.get("scene_seed")
		var seed_value: int = 20260912
		if seed_variant != null:
			seed_value = seed_variant
		rng.seed = seed_value
		rng_seeded = true
	_ensure_light()
	_sync_light()

func reset() -> void:
	particles.clear()
	flashes.clear()
	elapsed = 0.0
	if controller != null:
		var seed_variant: Variant = controller.get("scene_seed")
		var seed_value: int = 20260912
		if seed_variant != null:
			seed_value = seed_variant
		rng.seed = seed_value
		rng_seeded = true
	queue_redraw()
	_redraw_layers()

func particle_count() -> int:
	return particles.size()

func flash_count() -> int:
	return flashes.size()

func light_count() -> int:
	var count := 0
	for node in find_children("*", "Light2D", true, false):
		if node.enabled:
			count += 1
	return count

func marker_positions() -> Dictionary:
	return {
		"exhaust": marker_world("exhaust"),
		"contact": marker_world("contact"),
		"lamp": marker_world("lamp"),
	}

func marker_world(marker_id: String) -> Vector2:
	if controller == null or controller.harvester_visual == null:
		return Vector2.ZERO
	var harvester: Node2D = controller.harvester_visual
	var asset: Dictionary = VisualAssetScript.asset_for("harvester")
	if asset.is_empty() or not MARKER_SOURCES.has(marker_id):
		return harvester.global_position
	var source: Vector2 = MARKER_SOURCES[marker_id]
	var ground: Vector2 = asset["ground_anchor"]
	var applied_scale: float = float(harvester.base_scale) * float(harvester.scale_multiplier)
	var facing: float = float(harvester.facing)
	var local := Vector2(0.0, float(harvester.ground_local_y)) + (source - ground) * Vector2(applied_scale * facing, applied_scale)
	return harvester.global_position + local

func notify_muzzle(kind: String, feet_position: Vector2, facing: int) -> void:
	if config == null or not config.muzzle_flashes_enabled:
		return
	var origin: Vector2 = CombatGeometryScript.muzzle_position(kind, feet_position, facing)
	flashes.append({"position": origin, "remaining": 0.09, "radius": 18.0})
	if flash_overlay != null:
		flash_overlay.queue_redraw()

func notify_shot(kind: String, feet_position: Vector2, facing: int) -> void:
	notify_muzzle(kind, feet_position, facing)

func _process(delta: float) -> void:
	if controller == null or config == null:
		return
	if controller.get("frozen") == true or controller.run_state.paused:
		return
	elapsed += delta
	_emit(delta)
	_advance_particles(delta)
	_advance_flashes(delta)
	_sync_light()
	_redraw_layers()

func _machine_active() -> bool:
	if controller == null:
		return false
	var phase: int = controller.run_state.phase
	return phase == RunStateScript.Phase.EXTRACTING or phase == RunStateScript.Phase.SEALING

func _ensure_light() -> void:
	if light_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([
			Color(1.0, 0.92, 0.72, 1.0),
			Color(1.0, 0.72, 0.38, 0.55),
			Color(1.0, 0.55, 0.2, 0.0),
		])
		light_texture = GradientTexture2D.new()
		light_texture.gradient = gradient
		light_texture.width = 256
		light_texture.height = 256
		light_texture.fill = GradientTexture2D.FILL_RADIAL
		light_texture.fill_from = Vector2(0.5, 0.5)
		light_texture.fill_to = Vector2(0.5, 0.0)
	if drill_light != null:
		return
	drill_light = PointLight2D.new()
	drill_light.name = "DrillPointLight"
	drill_light.texture = light_texture
	drill_light.texture_scale = 2.4
	drill_light.color = Color(1.0, 0.74, 0.42)
	drill_light.energy = 0.7
	drill_light.shadow_enabled = false
	drill_light.range_item_cull_mask = 1
	drill_light.z_index = 1
	add_child(drill_light)

func _sync_light() -> void:
	if drill_light == null:
		return
	var enabled: bool = visible and config != null and bool(config.drill_light_enabled)
	drill_light.enabled = enabled
	drill_light.visible = enabled
	if not enabled:
		return
	var intensity: float = clampf(float(config.intensity), 0.0, 1.5)
	var pulse := 0.62 + 0.38 * sin(elapsed * 2.6) if _machine_active() else 0.42
	drill_light.energy = 0.55 * intensity * pulse
	drill_light.position = marker_world("lamp") if controller != null else Vector2.ZERO
	drill_light.color = Color(1.0, 0.74, 0.42)

func _emit(delta: float) -> void:
	var density: float = maxf(0.0, float(config.particle_density))
	var active := 1.0 if _machine_active() else 0.22
	var budget := mini(64, int(round(28.0 * density)) + 10)
	if config.steam_enabled:
		_emit_kind("steam", delta, 9.0 * density * active, budget)
	if config.dust_enabled:
		_emit_kind("dust", delta, 4.5 * density * (1.0 if _machine_active() else 0.0), budget)
	if config.sparks_enabled:
		_emit_kind("sparks", delta, 6.5 * density * (1.0 if _machine_active() else 0.0), budget)

func _emit_kind(kind: String, delta: float, rate: float, budget: int) -> void:
	if rate <= 0.0 or particles.size() >= budget:
		return
	if rng.randf() > minf(1.0, rate * delta):
		return
	var origin := marker_world("exhaust" if kind == "steam" else "contact")
	var layer := "front"
	var velocity := Vector2.ZERO
	var life := 0.6
	match kind:
		"steam":
			layer = "rear" if rng.randf() < 0.28 else "front"
			origin += Vector2(rng.randf_range(-6.0, 8.0), rng.randf_range(-4.0, 4.0))
			velocity = Vector2(rng.randf_range(-10.0, 16.0), rng.randf_range(-92.0, -48.0))
			life = rng.randf_range(0.85, 1.45)
		"dust":
			origin += Vector2(rng.randf_range(-18.0, 22.0), rng.randf_range(-2.0, 3.0))
			velocity = Vector2(rng.randf_range(-22.0, 28.0), rng.randf_range(-14.0, -2.0))
			life = rng.randf_range(0.45, 0.9)
		"sparks":
			origin += Vector2(rng.randf_range(-4.0, 8.0), rng.randf_range(-3.0, 2.0))
			velocity = Vector2(rng.randf_range(28.0, 96.0), rng.randf_range(-140.0, -36.0))
			life = rng.randf_range(0.18, 0.38)
	particles.append({
		"kind": kind,
		"layer": layer,
		"position": origin,
		"velocity": velocity,
		"life": life,
		"max_life": life,
	})

func _advance_particles(delta: float) -> void:
	var next: Array[Dictionary] = []
	for particle in particles:
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			continue
		var velocity: Vector2 = particle["velocity"]
		match str(particle["kind"]):
			"sparks":
				velocity.y += 260.0 * delta
			"steam":
				velocity.x += rng.randf_range(-12.0, 12.0) * delta
				velocity.y *= 1.0 - 0.12 * delta
			"dust":
				velocity.y += 18.0 * delta
		particle["velocity"] = velocity
		particle["position"] = particle["position"] + velocity * delta
		next.append(particle)
	particles = next

func _advance_flashes(delta: float) -> void:
	var next: Array[Dictionary] = []
	for flash in flashes:
		flash["remaining"] = float(flash["remaining"]) - delta
		if float(flash["remaining"]) > 0.0:
			next.append(flash)
	flashes = next

func _redraw_layers() -> void:
	if rear_layer != null:
		rear_layer.queue_redraw()
	if front_layer != null:
		front_layer.queue_redraw()
	if flash_overlay != null:
		flash_overlay.queue_redraw()
	if debug_layer != null:
		debug_layer.visible = debug_markers
		debug_layer.queue_redraw()

func _draw_rear() -> void:
	if config == null:
		return
	var intensity: float = clampf(float(config.intensity), 0.0, 1.5)
	for particle in particles:
		if str(particle.get("layer", "front")) == "rear":
			_draw_particle(rear_layer, particle, intensity)

func _draw_front() -> void:
	if config == null:
		return
	var intensity: float = clampf(float(config.intensity), 0.0, 1.5)
	if config.lamp_halos_enabled:
		_draw_halo(front_layer, marker_world("lamp"), 22.0, Color(0.55, 0.95, 0.82, 0.22 * intensity))
	if config.drill_light_enabled:
		var pulse := 0.55 + 0.45 * sin(elapsed * 3.2) if _machine_active() else 0.28
		_draw_halo(front_layer, marker_world("lamp"), 36.0, Color(1.0, 0.78, 0.38, 0.16 * intensity * pulse))
	for particle in particles:
		if str(particle.get("layer", "front")) != "rear":
			_draw_particle(front_layer, particle, intensity)

func _draw_flashes() -> void:
	if config == null or not config.muzzle_flashes_enabled or flash_overlay == null:
		return
	var intensity: float = clampf(float(config.intensity), 0.0, 1.5)
	for flash in flashes:
		var alpha := clampf(float(flash["remaining"]) / 0.09, 0.0, 1.0) * 0.7 * intensity
		flash_overlay.draw_circle(flash["position"], float(flash["radius"]), Color(1.0, 0.92, 0.62, alpha * 0.35))
		flash_overlay.draw_circle(flash["position"], float(flash["radius"]) * 0.45, Color(1.0, 0.96, 0.78, alpha))

func _draw_debug() -> void:
	if not debug_markers or debug_layer == null or controller == null:
		return
	var markers := marker_positions()
	_draw_marker(debug_layer, markers["exhaust"], Color(0.45, 0.9, 1.0), "EXHAUST")
	_draw_marker(debug_layer, markers["contact"], Color(1.0, 0.62, 0.22), "CONTACT")
	_draw_marker(debug_layer, markers["lamp"], Color(1.0, 0.88, 0.35), "LAMP")
	if controller.hero != null:
		var muzzle: Vector2 = CombatGeometryScript.muzzle_position("hero", controller.hero.position, controller.hero.last_facing)
		_draw_marker(debug_layer, muzzle, Color(1.0, 1.0, 1.0), "MUZZLE")

func _draw_marker(canvas: Node2D, center: Vector2, color: Color, label: String) -> void:
	canvas.draw_circle(center, 4.0, color)
	canvas.draw_line(center + Vector2(-8.0, 0.0), center + Vector2(8.0, 0.0), color, 1.0)
	canvas.draw_line(center + Vector2(0.0, -8.0), center + Vector2(0.0, 8.0), color, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, center + Vector2(6.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_halo(canvas: Node2D, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center, radius, Color(color, color.a * 0.28))
	canvas.draw_circle(center, radius * 0.55, color)

func _draw_particle(canvas: Node2D, particle: Dictionary, intensity: float) -> void:
	var life_ratio := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
	var position: Vector2 = particle["position"]
	match str(particle["kind"]):
		"steam":
			var radius := lerpf(8.0, 26.0, 1.0 - life_ratio)
			var alpha := 0.34 * life_ratio * intensity
			if str(particle.get("layer", "front")) == "rear":
				alpha *= 0.55
			canvas.draw_circle(position, radius, Color(0.78, 0.86, 0.9, alpha * 0.35))
			canvas.draw_circle(position, radius * 0.62, Color(0.86, 0.91, 0.94, alpha * 0.55))
			canvas.draw_circle(position, radius * 0.32, Color(0.92, 0.95, 0.97, alpha))
		"dust":
			var dust_radius := lerpf(4.0, 9.0, 1.0 - life_ratio)
			canvas.draw_circle(position, dust_radius, Color(0.52, 0.44, 0.32, 0.32 * life_ratio * intensity))
			canvas.draw_circle(position + Vector2(dust_radius * 0.4, 1.0), dust_radius * 0.65, Color(0.46, 0.38, 0.28, 0.2 * life_ratio * intensity))
		"sparks":
			var velocity: Vector2 = particle["velocity"]
			var tail := velocity.normalized() * lerpf(6.0, 14.0, life_ratio) if velocity.length() > 1.0 else Vector2(8.0, 0.0)
			canvas.draw_line(position, position - tail, Color(1.0, 0.72, 0.28, 0.55 * life_ratio * intensity), 1.6)
			canvas.draw_line(position, position - tail * 0.45, Color(1.0, 0.94, 0.7, 0.9 * life_ratio * intensity), 1.0)
			canvas.draw_circle(position, 2.4, Color(1.0, 0.96, 0.78, 0.85 * life_ratio * intensity))
