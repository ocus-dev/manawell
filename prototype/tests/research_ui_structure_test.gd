extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    controller.account_state.bank = 500
    controller._update_hud()
    await process_frame
    var operations = controller.encounter_hud.operations
    operations.navigation_buttons["research"].emit_signal("pressed")
    await process_frame
    await process_frame
    for i in range(10):
        await process_frame
    var panel = operations.research_panel
    assert(panel.track_buttons.size() == 6)
    panel.track_buttons["harvest.amount"].emit_signal("pressed")
    assert(int(controller.account_state.research_ranks.get("harvest.amount", 0)) == 0, "Inspect must not buy")
    var purchase: Button = panel.buy
    assert(not purchase.disabled)
    var before: float = controller.account_state.bank
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.position = purchase.get_global_rect().get_center()
    click.pressed = true
    root.push_input(click)
    # Reproduce the original failure: several state refreshes between down and up.
    for i in range(4):
        controller._update_hud()
        await process_frame
    assert(operations.research_panel == panel and panel.buy == purchase)
    click = click.duplicate()
    click.pressed = false
    root.push_input(click)
    await process_frame
    assert(int(controller.account_state.research_ranks.get("harvest.amount", 0)) == 1, "Real mouse click must purchase")
    assert(is_equal_approx(controller.account_state.bank, before - 60))
    assert(panel.selected_id == "harvest.amount")
    panel._select_group("weapons")
    assert(panel.equipment_buttons["weapon.fan"].disabled)
    panel.track_buttons["weapon.shots"].emit_signal("pressed")
    assert(panel.buy.disabled and "Requires" in panel.reason.text)
    controller.account_state.bank = 0
    controller._update_hud()
    panel.track_buttons["weapon.damage"].emit_signal("pressed")
    assert(panel.buy.disabled and "Need" in panel.reason.text)
    if DisplayServer.get_name() != "headless":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://../work/reviews/research-weapons.png")
    controller.queue_free()
    print("PASS research UI: real click across refresh, exact debit, inspect, persistent selection, prerequisite and affordability feedback")
    quit(0)
