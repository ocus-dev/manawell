extends SceneTree

const Generator = preload("res://scripts/model/loot_generator.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var generated := _generated_instance(1)
	var first_id := str(generated.instance_id)
	var second := generated.duplicate(true)
	second.instance_id = "loot:l07:duplicate"
	second.provenance.enemy_id = 2
	assert(controller.account_state.add_monster_instance(generated))
	assert(controller.account_state.add_monster_instance(second))
	controller._update_hud()
	await process_frame
	var panel = controller.encounter_hud.operations.inventory_panel
	assert(panel.buttons.has(first_id) and panel.buttons.has(second.instance_id))
	var first_button = panel.buttons[first_id]
	panel._inspect(first_id)
	assert(panel.selected_id == first_id)
	controller._update_hud()
	await process_frame
	assert(panel.buttons[first_id] == first_button)
	panel._inspect(second.instance_id)
	assert(panel.selected_id == second.instance_id)
	panel.filters["weapon"].emit_signal("pressed")
	assert(panel.category == "weapon")
	panel.sort_select.select(1)
	panel.sort_select.emit_signal("item_selected", 1)
	assert(panel.sort_mode == "name")
	var hero_id := str(panel.selected_hero_id)
	var slot := str(Definitions.PRODUCTION_BASES[str(second.base_id)].slot)
	assert(controller.equip_inventory_item(hero_id, slot, second.instance_id))
	assert(controller.account_state.hero_kits[hero_id][slot] == second.instance_id)
	assert(not controller.discard_inventory_item(second.instance_id, str(Definitions.PRODUCTION_BASES[str(second.base_id)].label)))
	assert(controller.lock_inventory_item(first_id, true))
	assert(not controller.discard_inventory_item(first_id, str(Definitions.PRODUCTION_BASES[str(generated.base_id)].label)))
	assert(controller.lock_inventory_item(first_id, false))
	assert(controller.discard_inventory_item(first_id, str(Definitions.PRODUCTION_BASES[str(generated.base_id)].label)))
	for index in range(99):
		var filler := generated.duplicate(true)
		filler.instance_id = "loot:l07:fill:%03d" % index
		filler.provenance.enemy_id = 100 + index
		assert(controller.account_state.add_monster_instance(filler))
	controller._update_hud()
	await process_frame
	assert(controller.account_state.item_instances.size() == 100)
	assert(panel.summary.text.contains("100 / 100"))
	controller.queue_free()
	print("PASS L07 inventory: duplicate instances, retained controls, filters/sort, equip, lock/discard confirmation and capacity")
	quit(0)

func _generated_instance(seed: int) -> Dictionary:
	var state := seed
	var input := {"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": "l07", "enemy_id": 1, "node_id": "act_01_node_09"}
	for attempt in range(1000):
		var result := Generator.generate(input, state)
		if result.valid and result.generated:
			return result.instance
		state += 1
	push_error("L07 fixture could not generate an item")
	return {}