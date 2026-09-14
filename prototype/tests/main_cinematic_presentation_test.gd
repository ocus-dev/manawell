extends SceneTree
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    assert(scene.persistence_enabled)
    scene.persistence_enabled = false
    root.add_child(scene)
    await process_frame
    assert(scene.get_node_or_null("FoundryExperimentControls") == null)
    assert(scene.activity_visual.light_count() == 1)
    assert(scene.GROUND_Y == 652.0)
    assert(scene.environment_visual.GROUND_Y == scene.GROUND_Y)
    assert(scene.harvester_visual.position.y + 40.0 == scene.GROUND_Y)
    assert(scene.hero.position.y + 40.0 == scene.GROUND_Y)
    var enemy = scene.spawn_enemy(0, 1)
    assert(enemy.position.y + 40.0 == scene.GROUND_Y)
    assert(scene.shadow_nodes.size() >= 2)
    assert(scene.encounter_hud.light_mask == 0)
    scene.start_run()
    scene.spawn_friendly_projectile(scene.hero.position.x, 1100)
    scene.weapon_projectile_count = 3
    scene.spawn_friendly_volley(scene.hero.position.x, 1100)
    assert(scene.activity_visual.flash_count() == 2)
    scene.set_experiment_paused(true)
    var time: float = scene.activity_visual.elapsed
    var sprite = scene.harvester_visual.idle_sprite
    var frame: int = sprite.frame
    for i in range(10):
        await process_frame
    assert(scene.activity_visual.elapsed == time)
    assert(sprite.frame == frame)
    scene.set_experiment_paused(false)
    scene._clear_transients()
    assert(scene.activity_visual.flash_count() == 0)
    assert(scene.activity_visual.particle_count() == 0)
    scene.queue_free()
    print("PASS main presentation: default persistence, effects, HUD exclusion, both shot paths, pause and cleanup")
    quit()
