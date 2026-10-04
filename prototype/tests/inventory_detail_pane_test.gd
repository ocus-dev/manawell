extends SceneTree

const Pane = preload("res://scripts/ui/inventory_detail_pane.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
var equipped: Array = []
var salvaged: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pane := Pane.new()
	pane.theme = preload("res://scripts/ui/industrial_theme.gd").create()
	root.add_child(pane)
	pane.size = Vector2(290, 480)
	var item := {"instance_id": "test:one", "base_id": "core.heavy_breech", "label": "Heavy Breech", "rarity": "common", "item_level": 1, "implicit_modifiers": Definitions.PRODUCTION_BASES["core.heavy_breech"].implicits.duplicate(true), "explicit_modifiers": [], "locked": false}
	var state := {"heroes": [{"id": "hero_one", "label": "Breaker", "kit": {}}], "hero_resolver": {"instances": {"test:one": item}, "weapon_mode_id": "weapon.standard"}, "mutation_allowed": true}
	pane.equip_requested.connect(func(hero, slot, id): equipped.append([hero, slot, id]))
	pane.salvage_requested.connect(func(id): salvaged.append(id))
	pane.refresh(state, [item], "hero_one", item)
	var button_id := pane.equip_button.get_instance_id()
	assert(pane.detail.text.contains("+2 Attack"))
	assert(pane.preview.text.contains("Attack"))
	var standard_preview := pane.preview.text
	state.hero_resolver.weapon_mode_id = "weapon.fan"
	state.hero_resolver.ranks = {"weapon.shots": 1}
	pane.refresh(state, [item], "hero_one", item)
	assert(pane.preview.text != standard_preview, "Comparison must preserve selected weapon mode")
	pane.equip_button.pressed.emit()
	assert(equipped == [["hero_one", "weapon", "test:one"]])
	pane.refresh(state, [item], "hero_one", item)
	assert(pane.equip_button.get_instance_id() == button_id)
	var epic := item.duplicate(true)
	epic.rarity = "epic"
	epic.explicit_modifiers = [{"affix_id": "affix.payload", "value": 2}, {"affix_id": "affix.tempo", "value": 0.05}, {"affix_id": "affix.hunter", "value": 0.08}]
	pane.refresh(state, [epic], "hero_one", epic)
	await process_frame
	await process_frame
	assert(pane.get_combined_minimum_size().y <= 480, "Epic details must fit fixed-height pane")
	pane.refresh(state, [item], "hero_one", item)
	assert(pane.status.text == "Salvage value: 2 mana + 1 scrap.", pane.status.text)
	pane.request_salvage()
	assert(salvaged == ["test:one"])
	var second := item.duplicate(true)
	second.instance_id = "test:two"
	second.locked = true
	pane.refresh(state, [item, second], "hero_one", second)
	pane.request_salvage()
	assert(salvaged.size() == 1, "Locked items cannot be salvaged")
	second.locked = false
	second.equipped_hero_id = "hero_two"
	pane.refresh(state, [second], "hero_one", second)
	assert(pane.equip_button.disabled and pane.salvage_button.disabled)
	assert(pane.status.text.contains("Unequip there first"))
	state.mutation_allowed = false
	pane.refresh(state, [item], "hero_one", item)
	assert(pane.equip_button.disabled and pane.lock_button.disabled and pane.salvage_button.disabled)
	pane.refresh(state, [], "hero_one", {})
	assert(pane.preview.text.is_empty())
	assert(pane.item_title.text == "Select an item")
	pane.queue_free()
	await process_frame
	print("PASS inventory_detail_pane_test: rolls, comparisons, stable actions, guards and salvage target")
	quit()
