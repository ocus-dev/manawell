extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var icons = preload("res://scripts/ui/item_icons.gd")
    var catalog = preload("res://scripts/model/item_catalog.gd")
    var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui-icons/items/manifest.json"))
    assert(manifest.items.size() == catalog.ITEMS.size())
    for id in catalog.ITEMS:
        var texture: Texture2D = icons.texture(id)
        assert(texture != null and texture.get_size() == Vector2(256, 256))
        assert(icons.texture(id) == texture)
        var im := texture.get_image()
        assert(im.get_pixel(0, 0).a == 0)
        var bounds: Rect2i = im.get_used_rect()
        assert(bounds.size.x > 0 and bounds.size.y > 0)
        assert(bounds.position.x >= 20 and bounds.position.y >= 20)
    assert(icons.texture("missing") == null)
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var panel = controller.encounter_hud.operations.inventory_panel
    for id in catalog.ITEMS:
        assert(controller.account_state.grant_item(id))
    controller.encounter_hud.operations.navigation_buttons["inventory"].emit_signal("pressed")
    controller._update_hud()
    for id in catalog.ITEMS:
        var button = panel.buttons[id]
        assert(button.icon == icons.texture(id))
    for i in range(10):
        await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://../art/ui-items/inventory-preview.png")
    controller.queue_free()
    await process_frame
    print("PASS item icon assets: nine padded transparent textures, cache, inventory bindings, fallback")
    quit(0)
