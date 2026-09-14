extends SceneTree
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var scene = load("res://scenes/experiments/cinematic_foundry.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.shadows_enabled = false
    for i in range(3):
        await process_frame
    var shadow = scene.shadow_nodes[str(scene.hero.get_instance_id())]
    print("Shadows disabled, actual visible: ", shadow.visible)
    var frame = scene.harvester_visual.idle_sprite.frame
    scene._toggle_freeze()
    for i in range(45):
        await process_frame
    print("Frozen drill animation frame before/after: ", frame, " / ", scene.harvester_visual.idle_sprite.frame)
    print("Configured seed / actual loot seed: ", scene.scene_seed, " / ", scene.loot_rng_state)
    scene.queue_free()
    quit()
