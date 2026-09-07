extends RefCounted
## Shared portrait presentation; existing labels remain the fallback.
const HERO_ONE: Texture2D = preload("res://assets/portraits/hero_1.png")

static func apply(label: Label, hero_id: String) -> void:
	var portrait := label.get_node_or_null("Portrait") as TextureRect
	if portrait == null:
		portrait = TextureRect.new()
		portrait.name = "Portrait"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.texture = HERO_ONE if hero_id == "hero_1" else null
	portrait.visible = portrait.texture != null
	label.self_modulate.a = 0.0 if portrait.visible else 1.0
