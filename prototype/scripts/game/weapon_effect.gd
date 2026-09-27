extends Node2D

## One playing weapon effect: a sprite-sheet flipbook played once, then freed.
## Spawned by SideViewHero when an attack reaches the effect's trigger point.

const WeaponEffectsScript = preload("res://scripts/model/weapon_effects.gd")

var effect: Dictionary = {}
var sprite: Sprite2D
var elapsed := 0.0
var length := 0.1
var sheet_size := Vector2.ONE

## `size_scale` converts the effect's on-screen size into this node's local
## space (the inverse of the parent's scale when riding on the weapon).
func setup(new_effect: Dictionary, texture: Texture2D, size_scale: Vector2 = Vector2.ONE) -> void:
	effect = WeaponEffectsScript.normalize(new_effect)
	sprite = Sprite2D.new()
	sprite.name = "Frame"
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sheet_size = Vector2(texture.get_size()) if texture != null else Vector2.ONE
	var cell: Rect2 = WeaponEffectsScript.frame_rect(effect, sheet_size, 0)
	sprite.region_rect = cell
	var fit := float(effect.size) / maxf(1.0, maxf(cell.size.x, cell.size.y))
	sprite.scale = Vector2(fit, fit) * size_scale
	sprite.modulate = Color(1, 1, 1, float(effect.opacity))
	if bool(effect.additive):
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = blend
	add_child(sprite)
	length = WeaponEffectsScript.play_length(effect)

func frame_index() -> int:
	return clampi(int(elapsed * float(effect.get("fps", 24.0))), 0, int(effect.get("frame_count", 1)) - 1)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if elapsed >= length:
		queue_free()
		return
	if sprite != null:
		sprite.region_rect = WeaponEffectsScript.frame_rect(effect, sheet_size, frame_index())
