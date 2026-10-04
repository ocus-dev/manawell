extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _click_across_refresh(button: Button, controller: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event)
	controller._update_hud()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var controller = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	var operations = controller.encounter_hud.operations
	operations.navigation_buttons.inventory.pressed.emit()
	var account = controller.account_state
	assert(account.grant_item("core.heavy_breech"))
	assert(account.grant_item("chassis.bulwark"))
	controller._update_hud()
	for frame in range(12):
		await process_frame
	var panel = operations.inventory_panel
	var details = panel.detail_pane
	var equipment = panel.equipment_pane
	panel.buttons["core.heavy_breech"].pressed.emit()
	for frame in range(3):
		await process_frame
	var id := "legacy:core.heavy_breech"
	var hero_id: String = panel.selected_hero_id
	assert(not details.equip_button.disabled)
	assert(details.preview.text.contains("Attack"))
	var attack_before := float(equipment.stat_values.attack_damage.text)
	var original_button: Button = details.equip_button
	await _click_across_refresh(original_button, controller)
	assert(details.equip_button == original_button)
	assert(account.hero_kits[hero_id].weapon == id, "Real equip click must reach the account")
	assert(equipment.slot_buttons.weapon.icon != null)
	assert(float(equipment.stat_values.attack_damage.text) > attack_before)
	assert(details.preview.text.contains("Already equipped"))
	assert(details.salvage_button.disabled)
	assert(not controller.salvage_inventory_item(id))
	equipment.remove_buttons.weapon.pressed.emit()
	assert(str(account.hero_kits[hero_id].get("weapon", "")).is_empty())
	assert(not details.equip_button.disabled)
	assert(details.preview.text.contains("Attack"))
	details.lock_button.toggled.emit(true)
	assert(account.item_instances[id].locked and details.salvage_button.disabled)
	assert(not controller.salvage_inventory_item(id))
	details.lock_button.toggled.emit(false)
	assert(not account.item_instances[id].locked and not details.salvage_button.disabled)
	var bank_before: float = account.bank
	details.request_salvage()
	assert(panel.salvage_dialog.visible and not panel.salvage_dialog.get_ok_button().disabled)
	panel.salvage_dialog.confirmed.emit()
	panel.salvage_dialog.hide()
	assert(not account.item_instances.has(id))
	assert(account.bank > bank_before and account.scrap > 0, "Salvage pays mana and scrap")
	assert(panel.result_label.text.begins_with("Salvaged 1 item"))
	assert(account.item_instances.has("legacy:chassis.bulwark"))
	assert(panel.selected_id.is_empty())
	controller.queue_free()
	print("PASS equipment flow: real equip click across refresh, account kit, texture, stat comparison, unequip, locked/equipped salvage safeguards, confirmed salvage payout")
	quit(0)
