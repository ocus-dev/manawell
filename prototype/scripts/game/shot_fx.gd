class_name ShotFx
extends Node2D

## The gun's shot art (assets/side-view/effects/gun_shot/): a muzzle burst, a
## 3-frame electric bullet and an impact fizzle. Projectiles draw the bullet
## frames; spawn() plays the one-shot burst and fizzle.

const ROOT := "res://assets/side-view/effects/gun_shot/"
const MUZZLE := "muzzle"
const IMPACT := "impact"
const BULLET_FRAMES := ["bullet_1", "bullet_2", "bullet_3"]
## On-screen sizes (pixels): bullet height, muzzle burst height, impact height.
const BULLET_HEIGHT := 30.0
const MUZZLE_HEIGHT := 56.0
const IMPACT_HEIGHT := 48.0

static var _cache: Dictionary = {}

## The imported texture, or the raw PNG if Godot hasn't imported it yet.
static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := ROOT + name + ".png"
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	if result == null:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			result = ImageTexture.create_from_image(image)
	_cache[name] = result
	return result

## Draws `tex` on `canvas` with its right edge (the bullet's tip) at the origin,
## pointing along `aim`, scaled to `height` pixels tall.
static func draw_pointing(canvas: CanvasItem, tex: Texture2D, aim: Vector2, height: float, modulate_color: Color = Color.WHITE, anchor := 1.0) -> void:
	if tex == null:
		return
	var s := height / float(tex.get_height())
	var flip := aim.x < 0.0
	var angle := (-aim).angle() if flip else aim.angle()
	canvas.draw_set_transform(Vector2.ZERO, angle, Vector2(-s if flip else s, s))
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	canvas.draw_texture_rect(tex, Rect2(Vector2(-w * anchor, -h * 0.5), Vector2(w, h)), false, modulate_color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One-shot effect: plays `kind` (MUZZLE or IMPACT) at `at`, fading out.
static func spawn(parent: Node, kind: String, at: Vector2, aim: Vector2, duration := 0.14) -> Node2D:
	if parent == null or texture(kind) == null:
		return null
	var fx: Node2D = (load("res://scripts/game/shot_fx.gd") as GDScript).new()
	fx.kind = kind
	fx.aim = aim if not aim.is_zero_approx() else Vector2.RIGHT
	fx.duration = duration
	fx.position = at
	fx.z_index = 4
	parent.add_child(fx)
	return fx

var kind := MUZZLE
var aim := Vector2.RIGHT
var duration := 0.14
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	var fade := Color(1, 1, 1, 1.0 - t * t)
	if kind == MUZZLE:
		# The burst is centred a little ahead of the muzzle and swells as it fades.
		draw_pointing(self, texture(MUZZLE), aim, MUZZLE_HEIGHT * (0.85 + 0.3 * t), fade, 0.35)
	else:
		draw_pointing(self, texture(IMPACT), aim, IMPACT_HEIGHT, fade, 0.6)
