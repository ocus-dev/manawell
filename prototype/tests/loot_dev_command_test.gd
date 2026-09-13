extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    controller.execute_loot_command("drop_rate 100")
    assert(controller.development_drop_percent == 100)
    controller.execute_loot_command("drop_rate 101")
    assert(controller.development_drop_percent == 100)
    controller.execute_loot_command("drop_rate nonsense")
    assert(controller.development_drop_percent == 100)
    var generator = preload("res://scripts/model/loot_generator.gd")
    var input := {"eligible": true, "occurrence_kind": "ordinary", "item_level": 1, "run_id": "test", "enemy_id": 1, "node_id": "act_01_node_01", "development_drop_percent": 100.0}
    for seed in range(1, 30):
        assert(generator.generate(input, seed).generated)
    input.development_drop_percent = 0
    assert(not generator.generate(input, 1).generated)
    input.development_drop_percent = 100
    input.inventory_count = 100
    assert(generator.generate(input, 1).reason == "capacity")
    controller.execute_loot_command("drop_rate reset")
    assert(controller.development_drop_percent == -1)
    var key := InputEventKey.new()
    key.keycode = KEY_F8
    key.pressed = true
    controller.loot_dev_console._input(key)
    assert(controller.run_state.paused and controller.loot_dev_console.panel.visible)
    controller.loot_dev_console._input(key)
    assert(not controller.loot_dev_console.panel.visible)
    controller.queue_free()
    await process_frame
    print("PASS loot development command: percentages, validation, reset, capacity, F8 pause toggle")
    quit(0)
