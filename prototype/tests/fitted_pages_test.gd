extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var operations = controller.encounter_hud.operations
    operations.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    for dimensions in [Vector2(1280, 720), Vector2(1024, 576), Vector2(1920, 1080)]:
        operations.size = dimensions
        for page_id in ["operations", "map", "research"]:
            operations._show_page(page_id)
            for group in ["harvester", "weapons"]:
                operations.research_panel._select_group(group)
                for i in range(12):
                    await process_frame
                var fit = operations.fitted_pages[page_id]
                var page: Control = fit.page
                var bounds := page.get_global_rect()
                assert(bounds.end.y <= operations.get_global_rect().end.y + 1, "%s bottom %s" % [page_id, bounds])
                assert(bounds.end.x <= operations.get_global_rect().end.x + 1, "%s right %s" % [page_id, bounds])
                assert(page.size.y >= page.get_combined_minimum_size().y)
                assert(not operations.operations_scroll.get_v_scroll_bar().visible)
                assert(page.scale.x > 0.55, "Controls scaled excessively")
    controller.queue_free()
    print("PASS fitted pages: Operations, Map, both research tabs at 1024, 1280 and 1920 widths; no scrolling or clipping")
    quit()
