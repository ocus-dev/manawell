extends SceneTree

var selected_hero := "hero_1"
var selected_item := ""
var removed: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var pane = preload("res://scripts/ui/inventory_equipment_pane.gd").new()
	root.add_child(pane)
	pane.size = Vector2(250, 480)
	var weapon := {"instance_id": "test:weapon", "base_id": "core.heavy_breech", "label": "Heavy Breech", "category": "weapon", "implicit_modifiers": [{"stat": "attack_damage", "operation": "flat", "value": 3.0}], "explicit_modifiers": []}
	var chassis := {"instance_id": "test:chassis", "base_id": "chassis.bulwark", "label": "Bulwark", "category": "hero", "implicit_modifiers": [{"stat": "max_health", "operation": "flat", "value": 10.0}], "explicit_modifiers": []}
	var state := {"heroes": [{"id": "hero_1", "label": "One", "kit": {"weapon": "test:weapon"}}, {"id": "hero_2", "label": "Two", "kit": {"hero": "test:chassis"}}], "mutation_allowed": true, "hero_resolver": {"instances": {"test:weapon": weapon, "test:chassis": chassis}, "ranks": {"weapon.shots": 1}, "weapon_mode_id": "weapon.fan"}}
	var records := [weapon, chassis]
	pane.hero_selected.connect(func(id: String): selected_hero = id)
	pane.item_selected.connect(func(id: String): selected_item = id)
	pane.unequip_requested.connect(func(id: String, slot: String): removed = [id, slot])
	pane.refresh(state, records, selected_hero, weapon)
	await process_frame
	assert(pane.get_combined_minimum_size().y <= 480.0, "Equipment pane must fit the 720p layout")
	var original_button: Button = pane.slot_buttons.weapon
	assert(original_button.icon != null and original_button.text.contains("Heavy Breech"))
	original_button.pressed.emit()
	assert(selected_item == "test:weapon")
	assert(pane.mode_label.text == "Fan · 3 projectiles")
	# Fan mode must change displayed damage, not silently use standard weapon mode.
	var fan_damage := float(pane.stat_values.attack_damage.text)
	state.hero_resolver.weapon_mode_id = "weapon.standard"
	pane.refresh(state, records, selected_hero, weapon)
	assert(float(pane.stat_values.attack_damage.text) > fan_damage)
	state.mutation_allowed = false
	pane.refresh(state, records, selected_hero, weapon)
	assert(pane.remove_buttons.weapon.disabled)
	assert(not pane.slot_buttons.weapon.disabled, "Inspection remains available while mutations are locked")
	state.mutation_allowed = true
	pane.refresh(state, records, selected_hero, weapon)
	pane.remove_buttons.weapon.pressed.emit()
	assert(removed == ["hero_1", "weapon"])
	var first_health := float(pane.stat_values.max_health.text)
	pane.hero_select.item_selected.emit(1)
	assert(selected_hero == "hero_2")
	for frame in range(3):
		pane.refresh(state, records, selected_hero, chassis)
		await process_frame
	assert(pane.hero_select.selected == 1)
	assert(pane.slot_buttons.weapon == original_button)
	assert(pane.slot_buttons.weapon.disabled and not pane.slot_buttons.hero.disabled)
	assert(float(pane.stat_values.max_health.text) > first_health)
	pane.slot_buttons.hero.pressed.emit()
	assert(selected_item == "test:chassis")
	pane.remove_buttons.hero.pressed.emit()
	assert(removed == ["hero_2", "hero"])
	pane.queue_free()
	print("PASS equipment pane: two hero kits, persistent controls and selection, item art, inspection, mutation lock, weapon mode stats, bounded layout")
	quit(0)
