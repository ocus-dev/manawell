class_name SideViewActorVisual
extends Node2D

const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

var asset_id := ""
var ground_local_y := 40.0
var facing := 1
var scale_multiplier := 1.0
var base_scale := 1.0
var sprite: Sprite2D
var idle_sprite: AnimatedSprite2D
var walk_sprite: AnimatedSprite2D
var attack_sprite: AnimatedSprite2D
var moving := false
var animation_offsets := {}
var animation_scale := 1.0
var animation_source_anchor := Vector2.ZERO
var static_offset := Vector2.ZERO

## Hero-mode weapon attack clip (WeaponClip). While set, play_attack() plays
## the clip's next combo attack instead of the baked attack animation.
var attack_clip: Dictionary = {}
var attack_clip_texture: Texture2D
var clip_sprite: Sprite2D
var clip_hit_seconds := 0.0
var clip_combo_window := 1.0
var clip_attack_index := 0
var clip_line: Dictionary = {}
var clip_elapsed := 0.0
var clip_since_start := INF
var clip_playing := false
var clip_frame := -1
var clip_attacks_played := 0

signal attack_started
signal attack_finished

func _ready() -> void:
    if sprite != null:
        return
    sprite = Sprite2D.new()
    sprite.name = "Sprite"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(sprite)
    idle_sprite = AnimatedSprite2D.new()
    idle_sprite.name = "IdleSprite"
    idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    idle_sprite.visible = false
    add_child(idle_sprite)
    walk_sprite = AnimatedSprite2D.new()
    walk_sprite.name = "WalkSprite"
    walk_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    walk_sprite.visible = false
    add_child(walk_sprite)
    attack_sprite = AnimatedSprite2D.new()
    attack_sprite.name = "AttackSprite"
    attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    attack_sprite.visible = false
    attack_sprite.animation_finished.connect(_on_attack_animation_finished)
    add_child(attack_sprite)
    clip_sprite = Sprite2D.new()
    clip_sprite.name = "ClipSprite"
    clip_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    clip_sprite.region_enabled = true
    clip_sprite.visible = false
    add_child(clip_sprite)

func configure(new_asset_id: String, local_ground_y: float = 40.0) -> bool:
    if sprite == null:
        _ready()
    var asset := ConfigScript.asset_for(new_asset_id)
    if asset.is_empty():
        return false
    asset_id = new_asset_id
    ground_local_y = local_ground_y
    var visible_bounds: Rect2 = asset["visible_bounds"]
    base_scale = float(asset["initial_visible_height"]) / visible_bounds.size.y
    sprite.texture = asset["texture"]
    static_offset = Vector2(sprite.texture.get_size()) * 0.5 - Vector2(asset["ground_anchor"])
    # All clips use the same prepared source canvas and reference-pose calibration.
    # Clip union bounds describe the space needed for motion, not the actor's size.
    animation_scale = float(asset["initial_visible_height"]) / float(asset["animation_reference_height"])
    animation_source_anchor = asset["animation_source_anchor"]
    animation_offsets.clear()
    var animation_folder: String = asset.get("animation_folder", "")
    _configure_animation_sprite(idle_sprite, asset.get("idle_frames"), "idle", animation_folder + "_idle")
    _configure_animation_sprite(walk_sprite, asset.get("walk_frames"), "walk", animation_folder + "_walk")
    _configure_animation_sprite(attack_sprite, asset.get("attack_frames"), "attack", animation_folder + "_attack")
    _show_locomotion_sprite()
    _apply_visual_transform()
    return true

func _configure_animation_sprite(animation_sprite: AnimatedSprite2D, frames: Variant, animation_name: String, manifest_folder: String) -> void:
    animation_sprite.stop()
    animation_sprite.sprite_frames = null
    animation_sprite.visible = false
    if frames == null:
        return
    animation_sprite.sprite_frames = frames
    animation_sprite.animation = StringName(animation_name)
    var manifest := JSON.parse_string(FileAccess.get_file_as_string("res://assets/side-view/animations/%s/manifest.json" % manifest_folder)) as Dictionary
    var cell: Array = manifest.get("cell_size", [0.0, 0.0])
    var crop: Array = manifest["union_crop"]
    var anchor := animation_source_anchor - Vector2(float(crop[0]), float(crop[1]))
    animation_offsets[animation_sprite] = Vector2(float(cell[0]), float(cell[1])) * 0.5 - anchor

func _show_locomotion_sprite() -> void:
    if clip_sprite != null:
        clip_sprite.visible = false
    idle_sprite.visible = false
    walk_sprite.visible = false
    attack_sprite.visible = false
    var locomotion_sprite := walk_sprite if moving else idle_sprite
    if locomotion_sprite.sprite_frames == null:
        locomotion_sprite = idle_sprite if moving else walk_sprite
    sprite.visible = locomotion_sprite.sprite_frames == null
    if not sprite.visible:
        locomotion_sprite.visible = true
        if not locomotion_sprite.is_playing():
            locomotion_sprite.play()

func set_locomotion(is_moving: bool) -> void:
    moving = is_moving
    if attack_sprite.visible or clip_playing:
        return
    _show_locomotion_sprite()

func play_attack() -> void:
    if has_attack_clip():
        _play_clip_attack()
        return
    if attack_sprite == null or attack_sprite.sprite_frames == null:
        return
    if attack_sprite.visible and attack_sprite.is_playing():
        return
    sprite.visible = false
    idle_sprite.visible = false
    walk_sprite.visible = false
    attack_sprite.visible = true
    attack_sprite.frame = 0
    attack_sprite.play(&"attack")
    attack_started.emit()

func _on_attack_animation_finished() -> void:
    _show_locomotion_sprite()
    attack_finished.emit()

# ---------- weapon attack clip (hero mode) ----------

## `hit_seconds`: when the game deals damage (0 for ranged). `combo_window`:
## an attack starting later than this after the previous one restarts the combo.
func set_attack_clip(clip: Dictionary, texture: Texture2D, hit_seconds: float = 0.0, combo_window: float = 1.0) -> void:
    if sprite == null:
        _ready()
    stop_attack_clip(false)
    attack_clip = WeaponClipScript.normalize(clip) if not clip.is_empty() and texture != null else {}
    attack_clip_texture = texture if not attack_clip.is_empty() else null
    clip_hit_seconds = maxf(0.0, hit_seconds)
    clip_combo_window = maxf(0.1, combo_window)
    clip_attack_index = 0
    clip_since_start = INF
    clip_sprite.texture = attack_clip_texture
    _apply_visual_transform()

func clear_attack_clip() -> void:
    set_attack_clip({}, null)

func has_attack_clip() -> bool:
    return not attack_clip.is_empty() and attack_clip_texture != null and clip_sprite != null

func _play_clip_attack() -> void:
    if clip_since_start > clip_combo_window:
        clip_attack_index = 0
    clip_line = WeaponClipScript.timeline(attack_clip, clip_attack_index, clip_hit_seconds)
    clip_attack_index = (clip_attack_index + 1) % WeaponClipScript.attack_ranges(attack_clip).size()
    clip_elapsed = 0.0
    clip_since_start = 0.0
    clip_playing = true
    clip_attacks_played += 1
    sprite.visible = false
    idle_sprite.visible = false
    walk_sprite.visible = false
    attack_sprite.visible = false
    attack_sprite.stop()
    clip_sprite.visible = true
    _show_clip_frame(WeaponClipScript.frame_at(clip_line, 0.0))
    attack_started.emit()

func _process(delta: float) -> void:
    advance_attack_clip(delta)

func advance_attack_clip(delta: float) -> void:
    clip_since_start += maxf(0.0, delta)
    if not clip_playing:
        return
    clip_elapsed += maxf(0.0, delta)
    var frame := WeaponClipScript.frame_at(clip_line, clip_elapsed)
    if frame < 0:
        stop_attack_clip(true)
        return
    _show_clip_frame(frame)

func _show_clip_frame(frame: int) -> void:
    clip_frame = frame
    if frame >= 0:
        clip_sprite.region_rect = WeaponClipScript.frame_rect(attack_clip, frame)

## Stops a playing clip attack and shows idle/walk again.
func stop_attack_clip(emit_finished: bool = false) -> void:
    if not clip_playing:
        return
    clip_playing = false
    clip_frame = -1
    _show_locomotion_sprite()
    if emit_finished:
        attack_finished.emit()

func clip_hides_weapon() -> bool:
    return clip_playing

func set_facing(new_facing: int) -> void:
    facing = -1 if new_facing < 0 else 1
    _apply_visual_transform()

func set_scale_multiplier(new_multiplier: float) -> void:
    scale_multiplier = maxf(0.25, new_multiplier) if is_finite(new_multiplier) else 1.0
    _apply_visual_transform()

func _apply_visual_transform() -> void:
    if sprite == null:
        return
    var applied_scale := base_scale * scale_multiplier
    sprite.scale = Vector2(applied_scale * facing, applied_scale)
    sprite.position = Vector2(0.0, ground_local_y) + static_offset * sprite.scale
    for animation_sprite in [idle_sprite, walk_sprite, attack_sprite]:
        if animation_offsets.has(animation_sprite):
            var clip_scale := animation_scale * scale_multiplier
            animation_sprite.scale = Vector2(clip_scale * facing, clip_scale)
            # Mirror/resize around the ground pivot, including asymmetric crop offsets.
            animation_sprite.position = Vector2(0.0, ground_local_y) + Vector2(animation_offsets[animation_sprite]) * animation_sprite.scale
    if clip_sprite != null and not attack_clip.is_empty():
        var asset := ConfigScript.asset_for(asset_id)
        var height := float(asset.get("initial_visible_height", 80.0)) if not asset.is_empty() else 80.0
        var clip_scale := WeaponClipScript.hero_scale(attack_clip, height) * scale_multiplier
        clip_sprite.scale = Vector2(clip_scale * facing, clip_scale)
        var cell: Array = attack_clip.cell
        var anchor: Array = attack_clip.anchor
        # Put the clip's ground anchor on the actor's ground point.
        var from_center := Vector2(float(anchor[0]) - float(cell[0]) * 0.5, float(anchor[1]) - float(cell[1]) * 0.5)
        clip_sprite.position = Vector2(0.0, ground_local_y) - from_center * clip_sprite.scale

func visible_top_local_y() -> float:
    var asset := ConfigScript.asset_for(asset_id)
    if asset.is_empty():
        return ground_local_y
    var visible_bounds: Rect2 = asset["visible_bounds"]
    return ground_local_y + (visible_bounds.position.y - float(asset["ground_anchor"].y)) * base_scale * scale_multiplier

func ground_anchor_local() -> Vector2:
    return Vector2(0.0, ground_local_y)
