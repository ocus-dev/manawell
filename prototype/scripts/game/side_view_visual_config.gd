class_name SideViewVisualConfig
extends RefCounted

const HERO_EMITTER_LOCAL := Vector2(38.0, -17.0)
const RANGED_EMITTER_LOCAL := Vector2(30.0, -44.0)

const ASSETS := {
    "hero": {
        "texture": preload("res://assets/side-view/hero.png"),
        "idle_frames": preload("res://assets/side-view/animations/hero_idle/animation.tres"),
        "walk_frames": preload("res://assets/side-view/animations/hero_walk/animation.tres"),
        "attack_frames": preload("res://assets/side-view/animations/hero_attack/animation.tres"),
        "animation_folder": "hero",
        "animation_reference_height": 416.0,
        "animation_source_anchor": Vector2(288.0, 496.0),
        "visible_bounds": Rect2(4.0, 4.0, 585.0, 919.0),
        "ground_anchor": Vector2(296.0, 922.0),
        "initial_visible_height": 80.0,
    },
    "harvester": {
        "texture": preload("res://assets/side-view/harvester.png"),
        "idle_frames": preload("res://assets/side-view/animations/harvester_idle/animation.tres"),
        "animation_folder": "harvester",
        "animation_reference_height": 557.0,
        "animation_source_anchor": Vector2(384.0, 638.0),
        "visible_bounds": Rect2(4.0, 4.0, 811.0, 695.0),
        "ground_anchor": Vector2(408.0, 697.0),
        "initial_visible_height": 190.0,
    },
    "pursuer": {
        "texture": preload("res://assets/side-view/pursuer.png"),
        "idle_frames": preload("res://assets/side-view/animations/pursuer_idle/animation.tres"),
        "walk_frames": preload("res://assets/side-view/animations/pursuer_walk/animation.tres"),
        "attack_frames": preload("res://assets/side-view/animations/pursuer_attack/animation.tres"),
        "animation_folder": "pursuer",
        "animation_reference_height": 227.0,
        "animation_source_anchor": Vector2(288.0, 496.0),
        "visible_bounds": Rect2(4.0, 4.0, 964.0, 538.0),
        "ground_anchor": Vector2(485.0, 541.0),
        "initial_visible_height": 58.0,
    },
    "breaker": {
        "texture": preload("res://assets/side-view/breaker.png"),
        "idle_frames": preload("res://assets/side-view/animations/breaker_idle/animation.tres"),
        "walk_frames": preload("res://assets/side-view/animations/breaker_walk/animation.tres"),
        "attack_frames": preload("res://assets/side-view/animations/breaker_attack/animation.tres"),
        "animation_folder": "breaker",
        "animation_reference_height": 416.0,
        "animation_source_anchor": Vector2(288.0, 496.0),
        "visible_bounds": Rect2(4.0, 3.0, 879.0, 903.0),
        "ground_anchor": Vector2(443.0, 905.0),
        "initial_visible_height": 112.0,
    },
    "ranged": {
        "texture": preload("res://assets/side-view/ranged.png"),
        "idle_frames": preload("res://assets/side-view/animations/ranged_idle/animation.tres"),
        "walk_frames": preload("res://assets/side-view/animations/ranged_walk/animation.tres"),
        "attack_frames": preload("res://assets/side-view/animations/ranged_attack/animation.tres"),
        "animation_folder": "ranged",
        "animation_reference_height": 417.0,
        "animation_source_anchor": Vector2(288.0, 496.0),
        "visible_bounds": Rect2(4.0, 3.0, 793.0, 910.0),
        "ground_anchor": Vector2(399.0, 912.0),
        "initial_visible_height": 90.0,
    },
}

static func asset_for(asset_id: String) -> Dictionary:
	if asset_id == "hero_2":
		# Hero 2 ships in stages: the static cutout can be played immediately,
		# while its locomotion/attack clips arrive later. Prefer the distinct
		# static asset whenever it exists; only fall back to hero 1 when no
		# hero-2 art has been installed at all.
		if _hero_2_static_available():
			return _hero_2_static_asset()
		if _hero_2_animation_assets_available():
			return _hero_2_animation_asset()
		return ASSETS["hero"]
	if not ASSETS.has(asset_id):
		return {}
	return ASSETS[asset_id]

static func _hero_2_static_available() -> bool:
	return ResourceLoader.exists("res://assets/side-view/hero_2.png")

static func _hero_2_animation_assets_available() -> bool:
	for path in [
		"res://assets/side-view/hero_2.png",
		"res://assets/side-view/animations/hero_2_idle/animation.tres",
		"res://assets/side-view/animations/hero_2_walk/animation.tres",
		"res://assets/side-view/animations/hero_2_attack/animation.tres",
	]:
		if not ResourceLoader.exists(path):
			return false
	return true

static func _hero_2_animation_asset() -> Dictionary:
	return {
		"texture": load("res://assets/side-view/hero_2.png"),
		"idle_frames": load("res://assets/side-view/animations/hero_2_idle/animation.tres"),
		"walk_frames": load("res://assets/side-view/animations/hero_2_walk/animation.tres"),
		"attack_frames": load("res://assets/side-view/animations/hero_2_attack/animation.tres"),
		"animation_folder": "hero_2",
		"animation_reference_height": 416.0,
		"animation_source_anchor": Vector2(288.0, 496.0),
		"visible_bounds": Rect2(4.0, 4.0, 585.0, 919.0),
		"ground_anchor": Vector2(296.0, 922.0),
		"initial_visible_height": 80.0,
	}

static func _hero_2_static_asset() -> Dictionary:
	var texture := load("res://assets/side-view/hero_2.png") as Texture2D
	var size := texture.get_size()
	var bounds := Rect2(Vector2.ZERO, size)
	var image := texture.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0.0 and used.size.y > 0.0:
			bounds = Rect2(used)
	var anchor := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y)
	return {
		"texture": texture,
		"idle_frames": null,
		"walk_frames": null,
		"attack_frames": null,
		"animation_folder": "hero_2",
		"animation_reference_height": bounds.size.y,
		"animation_source_anchor": anchor,
		"visible_bounds": bounds,
		"ground_anchor": anchor,
		"initial_visible_height": 80.0,
	}

static func enemy_asset(enemy_kind: int) -> String:
	if enemy_kind == 1:
		return "breaker"
	if enemy_kind == 2:
		return "ranged"
	return "pursuer"
