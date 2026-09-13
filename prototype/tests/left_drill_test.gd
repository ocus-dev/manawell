extends SceneTree
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.persistence_enabled = false
    root.add_child(game)
    assert(game.harvester_visual.position.x == 160.0)
    assert(game.harvester_visual.scale_multiplier == 1.4)
    for kind in range(3):
        var enemy = game.spawn_enemy(kind, -1)
        assert(enemy.position.x == 1240.0)
        assert(enemy.side == 1)
    for warning in game.pending_entry_warnings:
        assert(warning.side == 1)
    game.queue_free()
    print("PASS left drill: enlarged visual, right-only spawning and entry warnings")
    quit()
