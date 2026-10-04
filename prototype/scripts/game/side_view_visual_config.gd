class_name SideViewVisualConfig
extends RefCounted

## The gun barrel's end while firing (gun attack clip, hit frame).
const HERO_EMITTER_LOCAL := Vector2(55.0, -17.0)
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
        # The drill (2026-10-02 art, front view, 1233x1133). Its idle clip is
        # the auger turning and boring down (half-resolution frames, so the
        # clip's reference height and anchor are half the still sprite's).
        "texture": preload("res://assets/side-view/harvester.png"),
        "idle_frames": preload("res://assets/side-view/animations/harvester_idle/animation.tres"),
        "animation_folder": "harvester",
        "animation_reference_height": 562.5,
        "animation_source_anchor": Vector2(308.0, 561.5),
        "visible_bounds": Rect2(4.0, 4.0, 1225.0, 1125.0),
        "ground_anchor": Vector2(616.0, 1123.0),
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

## Every animation state an actor can have (see SideViewActorVisual). Each
## one's clip lives in ANIMATIONS_ROOT/<animation_folder>_<state>/ as
## animation.tres + atlas.png + manifest.json. idle/walk/attack are preloaded
## in ASSETS; the others are found on disk the first time they're asked for,
## so adding a folder (e.g. pursuer_hurt/) is all it takes.
const STATES := ["idle", "walk", "attack", "windup", "hurt", "dash", "jump", "fall", "death", "spawn"]
## Looping states; the rest play once.
const LOOPING_STATES := ["idle", "walk", "dash", "fall"]
const ANIMATIONS_ROOT := "res://assets/side-view/animations"

## Animations installed while the game runs (the Weapon Lab's hero animation
## importer), keyed by folder ("hero_walk"): SpriteFrames and their manifest.
## They replace the preloaded ones until the editor has imported the new files.
static var runtime_frames := {}
static var runtime_manifests := {}
## Front-fist overlays installed this run, keyed by folder (Texture2D).
static var runtime_hand_atlases := {}
## hand_atlas.png found on disk, keyed by folder (Texture2D or null).
static var _hand_atlases := {}
## Clips found on disk, keyed by folder (SpriteFrames, or null when absent).
static var _disk_frames := {}

## How big actors are drawn, relative to the height each one's art was
## calibrated at (ASSETS initial_visible_height). Heroes (the mechs) and every
## monster, including ones added later, get these unless listed otherwise.
## Presentation only: hurtboxes in data/combat_geometry.gd are unchanged.
## The hero's held weapon scales with it (SideViewHero.display_scale()).
const HERO_DISPLAY_SCALE := 1.5
const MONSTER_DISPLAY_SCALE := 1.2
const HERO_ASSET_IDS := ["hero", "hero_2"]
## Not a hero or a monster: drawn at its calibrated size.
const UNSCALED_ASSET_IDS := ["harvester"]

static func display_scale(asset_id: String) -> float:
	if HERO_ASSET_IDS.has(asset_id):
		return HERO_DISPLAY_SCALE
	if UNSCALED_ASSET_IDS.has(asset_id):
		return 1.0
	return MONSTER_DISPLAY_SCALE

## Sized copies of assets, keyed by id: [source dictionary, sized copy].
static var _sized_cache := {}

static func _sized(asset_id: String, asset: Dictionary) -> Dictionary:
	var scale := display_scale(asset_id)
	if asset.is_empty() or is_equal_approx(scale, 1.0):
		return asset
	var cached: Array = _sized_cache.get(asset_id, [])
	if not cached.is_empty() and is_same(cached[0], asset):
		return cached[1]
	var sized := asset.duplicate()
	sized["art_visible_height"] = float(asset["initial_visible_height"])
	sized["initial_visible_height"] = float(asset["initial_visible_height"]) * scale
	_sized_cache[asset_id] = [asset, sized]
	return sized

static func asset_for(asset_id: String) -> Dictionary:
	var asset := _sized(asset_id, _asset_for(asset_id))
	if runtime_frames.is_empty() or asset.is_empty():
		return asset
	var folder := str(asset.get("animation_folder", ""))
	var result := asset.duplicate()
	for animation in STATES:
		var key := "%s_%s" % [folder, animation]
		if runtime_frames.has(key):
			result["%s_frames" % animation] = runtime_frames[key]
	return result

static func loops(state: String) -> bool:
	return LOOPING_STATES.has(state)

## The clip for one state of an asset (from asset_for), or null.
static func frames_for(asset: Dictionary, state: String) -> SpriteFrames:
	var key := "%s_frames" % state
	if asset.get(key) is SpriteFrames:
		return asset[key]
	var folder := "%s_%s" % [str(asset.get("animation_folder", "")), state]
	if runtime_frames.has(folder):
		return runtime_frames[folder]
	# idle/walk/attack are listed explicitly; null there means "none".
	if asset.has(key) or str(asset.get("animation_folder", "")).is_empty():
		return null
	if not _disk_frames.has(folder):
		var path := ANIMATIONS_ROOT.path_join(folder).path_join("animation.tres")
		_disk_frames[folder] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	return _disk_frames[folder]

## A clip's manifest (installed this run, or from disk), {} when missing.
static func manifest_for(folder: String) -> Dictionary:
	var manifest: Dictionary = runtime_manifests.get(folder, {})
	if not manifest.is_empty():
		return manifest
	var path := ANIMATIONS_ROOT.path_join(folder).path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## The front fist cut out of every frame of a clip, laid out exactly like its
## atlas.png (hand_atlas.png next to it; see HeroAnimations.build_hand_atlas).
## Drawn over a held weapon so the fingers close around the handle. null when
## the clip has none.
static func hand_atlas_for(folder: String) -> Texture2D:
	if runtime_hand_atlases.has(folder):
		return runtime_hand_atlases[folder]
	if not _hand_atlases.has(folder):
		var path := ANIMATIONS_ROOT.path_join(folder).path_join("hand_atlas.png")
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		if texture == null and FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
		_hand_atlases[folder] = texture
	return _hand_atlases[folder]

## Forgets clips looked up on disk (after installing or deleting one).
static func clear_disk_cache() -> void:
	_disk_frames.clear()
	_hand_atlases.clear()

static func _asset_for(asset_id: String) -> Dictionary:
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

## Measuring the still sprite reads the texture back from the GPU, and asset
## lookups happen every tick, so the result is kept.
static var _hero_2_static_cache: Dictionary = {}

static func _hero_2_static_asset() -> Dictionary:
	if not _hero_2_static_cache.is_empty():
		return _hero_2_static_cache
	_hero_2_static_cache = _measure_hero_2_static_asset()
	return _hero_2_static_cache

static func _measure_hero_2_static_asset() -> Dictionary:
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
