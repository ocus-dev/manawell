extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    controller.execute_loot_command("drop_rate 100")
    assert(controller.start_run())
    print("Operations drop audit: enabled=", controller.loot_enabled)
    var enemy = controller.spawn_enemy(0, 1)
    enemy.take_damage(enemy.health)
    controller.tick(1.0 / 60.0)
    print("Operations drop audit: items=", controller.account_state.item_instances.size())
    assert(controller.account_state.item_instances.size() == 1)
    assert(controller.loot_enabled)
    var item: Dictionary = controller.account_state.item_instances.values()[0]
    assert(item.provenance.node_id == "act_01_node_02")
    assert(controller.campaign_state.completed_nodes.is_empty())
    assert(get_nodes_in_group("loot_drop_visuals").size() == 1)
    controller.queue_free()
    await process_frame
    print("PASS Operations-started well: guaranteed kill drop, source node, visual, no campaign completion")
    quit(0)
