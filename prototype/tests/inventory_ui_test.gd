extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var operations = controller.encounter_hud.operations
    operations.navigation_buttons["inventory"].emit_signal("pressed")
    await process_frame
    var panel = operations.inventory_panel
    assert(panel.visible and panel.state.owned_count == 0)
    for i in [0, 1, 2, 3, 4]:
        controller.account_state.grant_item(preload("res://scripts/model/item_catalog.gd").REWARDS[i])
    controller._update_hud()
    for i in range(12):
        await process_frame
    var item: Button = panel.buttons["core.heavy_breech"]
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.position = item.get_global_rect().get_center()
    click.pressed = true
    root.push_input(click)
    controller._update_hud()
    await process_frame
    click = click.duplicate()
    click.pressed = false
    root.push_input(click)
    await process_frame
    assert(panel.selected_id == "core.heavy_breech")
    assert(not controller.account_state.new_items.has("core.heavy_breech"))
    assert(panel.state.new_count == 4)
    panel.filters["harvester"].emit_signal("pressed")
    assert(not panel.buttons["core.heavy_breech"].visible)
    assert(panel.buttons["module.high_volume"].visible)
    panel.filters["all"].emit_signal("pressed")
    panel._inspect("core.heavy_breech")
    assert(operations.inventory_panel == panel)
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://../work/reviews/inventory-screen.png")
    controller.queue_free()
    print("PASS inventory UI: empty/populated states, real click across refresh, new badges, filters and persistent controls")
    quit(0)
