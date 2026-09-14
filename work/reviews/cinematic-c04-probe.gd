extends SceneTree
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var scene = load("res://scenes/experiments/cinematic_foundry.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.set_physics_process(false)
    print("Cinematic assets assigned: ", scene.cinematic_backdrop != null, " / ", scene.cinematic_lane != null)
    print("Actual Light2D nodes: ", scene.find_children("*", "Light2D", true, false).size())
    print("Activity/drill draw order: ", scene.activity_visual.z_index, " / ", scene.harvester_visual.z_index)
    scene.activity_visual.reset()
    scene.weapon_projectile_count = 3
    scene.spawn_friendly_volley(scene.hero.position.x, 1100.0)
    print("Volley muzzle flashes: ", scene.activity_visual.flash_count())
    scene.spawn_friendly_projectile(scene.hero.position.x, 1100.0)
    print("After single shot muzzle flashes: ", scene.activity_visual.flash_count())
    scene.queue_free()
    quit()
