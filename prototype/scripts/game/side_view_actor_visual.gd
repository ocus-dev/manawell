class_name SideViewActorVisual
extends Node2D

const ConfigScript = preload("res://scripts/game/side_view_visual_config.gd")

var asset_id := ""
var ground_local_y := 40.0
var facing := 1
var scale_multiplier := 1.0
var base_scale := 1.0
var sprite: Sprite2D

func _ready() -> void:

    sprite = Sprite2D.new()
    sprite.name = "Sprite"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(sprite)

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
    sprite.position.y = ground_local_y + (sprite.texture.get_height() * 0.5 - float(asset["ground_anchor"].y)) * base_scale
    _apply_visual_transform()
    return true

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

func visible_top_local_y() -> float:
    var asset := ConfigScript.asset_for(asset_id)
    if asset.is_empty():
        return ground_local_y
    var visible_bounds: Rect2 = asset["visible_bounds"]
    return ground_local_y + (visible_bounds.position.y - float(asset["ground_anchor"].y)) * base_scale * scale_multiplier

func ground_anchor_local() -> Vector2:
    return Vector2(0.0, ground_local_y)
