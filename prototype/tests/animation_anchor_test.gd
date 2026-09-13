extends SceneTree

const Visual = preload("res://scripts/game/side_view_actor_visual.gd")
const Config = preload("res://scripts/game/side_view_visual_config.gd")

func _init() -> void:
    var visual := Visual.new()
    root.add_child(visual)
    for actor_id in ["hero", "breaker", "pursuer", "ranged", "harvester"]:
        assert(visual.configure(actor_id, 23.0))
        var asset := Config.asset_for(actor_id)
        for multiplier in [1.0, 1.25, 0.75]:
            visual.set_scale_multiplier(multiplier)
            for direction in [-1, 1]:
                for repeat in range(30):
                    visual.set_facing(direction)
                for clip in [visual.idle_sprite, visual.walk_sprite, visual.attack_sprite]:
                    if clip.sprite_frames == null:
                        continue
                    var expected_scale: float = float(asset["initial_visible_height"]) / float(asset["animation_reference_height"]) * multiplier
                    assert(is_equal_approx(clip.scale.y, expected_scale), "Scale accumulated")
                    assert(is_equal_approx(clip.scale.x, expected_scale * direction))
                    var motion: String = String(clip.animation)
                    var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/side-view/animations/%s_%s/manifest.json" % [actor_id, motion]))
                    var crop: Array = m["union_crop"]
                    var cell: Array = m["cell_size"]
                    var pivot: Vector2 = asset["animation_source_anchor"] - Vector2(crop[0], crop[1])
                    var half := Vector2(cell[0], cell[1]) * 0.5
                    assert((clip.position + (pivot - half) * clip.scale - Vector2(0, 23)).length() < 0.001, "Ground pivot moved")
                    var original_position: Vector2 = clip.position
                    for frame in range(clip.sprite_frames.get_frame_count(clip.animation)):
                        clip.frame = frame
                        assert(clip.position == original_position, "Frame-dependent ground snapping")
                    # All imported clips start at the same reference pose (within one source pixel).
                    var first_box: Array = m["frame_metrics"][0]["bbox"]
                    var first_height := float(first_box[3] - first_box[1]) * expected_scale
                    assert(absf(first_height - float(asset["initial_visible_height"]) * multiplier) < 0.6)
                    var foot_y: float = clip.position.y + (float(first_box[3]) - half.y) * clip.scale.y
                    assert(absf(foot_y - 23.0) < 0.6, "Reference feet float")
                    clip.frame = 0
                var static_anchor: Vector2 = asset["ground_anchor"]
                assert((visual.sprite.position + (static_anchor - visual.sprite.texture.get_size() * 0.5) * visual.sprite.scale - Vector2(0, 23)).length() < 0.001)
        visual.set_locomotion(true)
        assert(visual.walk_sprite.visible or visual.idle_sprite.visible)
        visual.play_attack()
        visual.set_locomotion(false)
        visual._on_attack_animation_finished()
        assert(visual.idle_sprite.visible)
    visual.free()
    print("PASS: all actors/clips, reference heights/feet, fixed frame pivots, repeated facing/scaling, reconfigure and fallback")
    quit(0)
