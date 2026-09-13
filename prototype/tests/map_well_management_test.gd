extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    var operations = controller.encounter_hud.operations
    assert(operations.body.visible)
    assert(operations.expedition_panel.is_visible_in_tree())
    operations._show_page("map")
    assert(not operations.body.visible)
    var popup = operations.well_popup
    for node in operations.view_state.campaign.nodes:
        if node.type == "well":
            operations.campaign_map.select_node(node.id)
            assert(popup.visible)
            assert(popup.well_id == node.well_id)
            popup.hide()
            operations.campaign_map.manage_button.pressed.emit()
            assert(popup.visible)
    var well := {"id": "well_1", "label": "Test well", "available": true, "commissioned": true, "passive_rate_per_minute": 2.5, "guard": {"id": "hero_a"}}
    var heroes := [{"id": "hero_a", "label": "Guard A", "available_for_guard": false}, {"id": "hero_b", "label": "Guard B", "available_for_guard": true}]
    popup.configure(well, heroes)
    assert(popup.income.text == "150.0 mana / hour")
    assert(popup.guard.selected == 1)
    var events: Array = []
    popup.hero_selected.connect(func(id: String, target: String): events.append([id, target]))
    popup.guard.item_selected.emit(2)
    assert(events.back() == ["hero_b", "well_1"])
    well.guard.id = "hero_b"
    popup.configure(well, heroes)
    assert(popup.guard.selected == 2)
    well.available = false
    popup.configure(well, heroes)
    assert(popup.guard.disabled)
    operations._show_page("operations")
    assert(not popup.visible)
    assert(operations.body.visible)
    controller.queue_free()
    print("PASS well popup: node and button opening, hourly income, guard selection, live refresh, unavailable state and Operations layout")
    quit(0)
