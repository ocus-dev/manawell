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
    controller.account_state.grant_item("core.heavy_breech")
    controller._update_hud()
    controller.set_process(false)
    controller.set_physics_process(false)
    for connection in panel.item_inspected.get_connections():
        panel.item_inspected.disconnect(connection.callable)
    var state: Dictionary = panel.state.duplicate(true)
    var template: Dictionary = {}
    for item in state.items:
        if not item.instances.is_empty():
            template = item.instances[0].duplicate(true)
            item.instances.clear()
    assert(not template.is_empty())
    for i in range(100):
        var record := template.duplicate(true)
        record.instance_id = "test:%04d" % i
        record.rarity = ["common", "magic", "rare", "epic"][i % 4]
        record.item_level = 1 + i % 9
        state.items[0].instances.append(record)
    state.stored_count = 100
    panel.refresh(state)
    for i in range(12):
        await process_frame
    print("GEOMETRY panel=", panel.get_global_rect(), " equipment=", panel.equipment_pane.get_combined_minimum_size(), " detail=", panel.detail_pane.get_combined_minimum_size(), " scroll=", panel.grid_scroll.get_global_rect())
    assert(panel.grid.get_child_count() >= 100)
    assert(panel.get_global_rect().end.y <= 720.5, "Inventory extends below viewport")
    assert(panel.detail_pane.get_global_rect().end.x <= 1280.5, "Details extend past viewport")
    print("GRID ", panel.grid.size, " cols=", panel.grid.columns, " max=", panel.grid_scroll.get_v_scroll_bar().max_value, " page=", panel.grid_scroll.get_v_scroll_bar().page)
    assert(panel.grid.size.y > panel.grid_scroll.size.y)
    var item: Button = panel.buttons["test:0099"]
    var pressed := InputEventMouseButton.new()
    pressed.button_index = MOUSE_BUTTON_LEFT
    pressed.position = item.get_global_rect().get_center()
    pressed.pressed = true
    root.push_input(pressed)
    panel.refresh(state)
    await process_frame
    var released := pressed.duplicate()
    released.pressed = false
    root.push_input(released)
    await process_frame
    assert(panel.selected_id == "test:0099", "Click survives intervening refresh")
    panel._filter("harvester")
    assert(panel.selected_id == "test:0099", "Filtering preserves selection")
    assert(not item.visible)
    panel._filter("all")
    panel.search.grab_focus()
    panel.search.text = "Breech"
    panel.search.text_changed.emit("Breech")
    panel.refresh(panel.state)
    assert(panel.search.has_focus())
    panel.search.text_changed.emit("no matching item")
    assert(panel.empty_label.visible)
    panel.search.text = ""
    panel.search.text_changed.emit("")
    panel.sort_mode = "level"
    panel._refresh_grid()
    var first: Button
    for child in panel.grid.get_children():
        if child.visible:
            first = child
            break
    assert(first.text.ends_with("Lv 9"))
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://../work/reviews/inventory-workspace.png")
    controller.queue_free()
    print("PASS inventory workspace: 100-item bounded layout, click across refresh, persistent selection and focus, search and sorting")
    quit(0)




