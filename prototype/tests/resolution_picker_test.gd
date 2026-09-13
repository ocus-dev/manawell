extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        print("SKIP resolution picker: requires a native window to verify display modes")
        quit()
        return
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var picker = controller.encounter_hud.settings_panel.resolution_selector
    for mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN]:
        root.mode = mode
        for i in range(3):
            await process_frame
        picker.item_selected.emit(0)
        for i in range(8):
            await process_frame
        assert(root.mode == Window.MODE_WINDOWED)
        assert(root.size == Vector2i(1024, 576), str(root.size))
        assert(picker.selected == 0)
        picker.item_selected.emit(1)
        for i in range(8):
            await process_frame
        assert(root.size == Vector2i(1280, 720), str(root.size))
        assert(picker.selected == 1)
    controller.set_resolution(0, 0)
    assert(root.size == Vector2i(1280, 720))
    print("PASS resolution picker: windowed, maximized, fullscreen, repeated selection and synchronization")
    controller.queue_free()
    quit()
