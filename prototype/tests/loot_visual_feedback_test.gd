extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var controller = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    root.add_child(controller)
    assert(controller.start_run())
    controller.set_process(false)
    controller.set_physics_process(false)
    controller.loot_enabled = true
    controller.campaign_node_id = "act_01_node_01"
    var enemy = controller.spawn_enemy(0, 1)
    enemy.position = controller.hero.position + Vector2(160, 0)
    var generator = preload("res://scripts/model/loot_generator.gd")
    var seed := 1
    while seed < 10000:
        var preview = generator.generate({"eligible": true, "occurrence_kind": "ordinary", "drop_bonus": 0.0, "item_level": 1, "inventory_count": 0, "inventory_capacity": 100, "run_id": controller.run_state.run_id, "enemy_id": enemy.enemy_id, "node_id": controller.campaign_node_id}, seed)
        if preview.valid and preview.generated:
            break
        seed += 1
    assert(seed < 10000)
    controller.loot_rng_state = seed
    enemy.take_damage(enemy.health)
    controller._process_enemy_deaths()
    var effects = get_nodes_in_group("loot_drop_visuals")
    assert(effects.size() == 1)
    assert(controller.account_state.item_instances.size() == 1)
    assert(controller.run_state.phase == preload("res://scripts/model/run_state.gd").Phase.EXTRACTING)
    var effect = effects[0]
    effect.set_process(false)
    effect.advance(0.2)
    assert(effect.position.y < effect.origin.y)
    controller.run_state.paused = true
    var elapsed: float = effect.elapsed
    effect._process(0.3)
    assert(effect.elapsed == elapsed)
    controller.run_state.paused = false
    controller._process_enemy_deaths()
    assert(get_nodes_in_group("loot_drop_visuals").size() == 1)
    # Include the other silhouettes in the visual fixture, without awarding items.
    for i in range(3):
        var extra = preload("res://scripts/game/loot_drop_visual.gd").new()
        extra.setup(controller, controller.hero.position + Vector2(320 + 160 * i, 0), {"base_id": ["core.heavy_breech", "chassis.bulwark", "module.bracing"][i], "rarity": ["common", "rare", "epic"][i]})
        controller.add_child(extra)
        extra.set_process(false)
        extra.advance(0.2)
    controller._update_hud()
    for i in range(5):
        await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://../work/reviews/loot-placeholders.png")
    effect.advance(1.0)
    assert(effect.caption.text.begins_with("Collected"))
    assert(controller.account_state.item_instances.size() == 1)
    effect.advance(1.0)
    assert(effect.is_queued_for_deletion())
    controller._clear_transients()
    for child in controller.get_children():
        if child.is_in_group("loot_drop_visuals"):
            assert(child.is_queued_for_deletion())
    controller.queue_free()
    await process_frame
    print("PASS loot feedback: ordinary kill awards before level end, one effect, rarity silhouettes, pause, flight/collection and no duplicate grants")
    quit(0)
