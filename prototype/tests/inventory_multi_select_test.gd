extends SceneTree

const InventoryPanelScript = preload("res://scripts/ui/inventory_panel.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const UiViewState = preload("res://scripts/ui/ui_view_state.gd")

var account
var panel

func _init() -> void:
	call_deferred("_run")

func _sync() -> void:
	panel.refresh(UiViewState._inventory_view(account))

func _on_salvage(ids: Array) -> void:
	var result: Dictionary = account.salvage_instances(ids)
	_sync()
	panel.show_salvage_result(result)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	account = AccountStateScript.new()
	assert(account.grant_item("core.heavy_breech"))
	assert(account.grant_item("chassis.bulwark"))
	var template: Dictionary = account.item_instances["legacy:core.heavy_breech"]
	var rarities := ["common", "magic", "rare", "epic"]
	for i in range(12):
		var copy: Dictionary = template.duplicate(true)
		copy.instance_id = "test:%02d" % i
		copy.rarity = rarities[i % 4]
		copy.item_level = 1 + i
		account.item_instances[copy.instance_id] = copy
	account.set_instance_locked("test:00", true)
	account.equip_instance("hero_1", "hero", "legacy:chassis.bulwark")
	panel = InventoryPanelScript.new()
	panel.theme = preload("res://scripts/ui/industrial_theme.gd").create()
	root.add_child(panel)
	panel.size = Vector2(1280, 720)
	panel.salvage_requested.connect(_on_salvage)
	_sync()
	await process_frame
	await process_frame

	# Bar is hidden until select mode or a pick.
	assert(not panel.selection_bar.visible and panel.help_label.visible)
	panel.select_toggle.toggled.emit(true)
	assert(panel.select_mode and panel.selection_bar.visible and panel.salvage_button.disabled)

	# Select mode: clicking items toggles them; locked and equipped refuse.
	panel.buttons["test:01"].pressed.emit()
	panel.buttons["test:02"].pressed.emit()
	assert(panel.selection.has("test:01") and panel.selection.has("test:02"))
	assert(panel.buttons["test:01"].text.begins_with("✓"))
	panel.buttons["test:02"].pressed.emit()
	assert(not panel.selection.has("test:02"), "Second click deselects")
	panel.buttons["test:00"].pressed.emit()
	assert(not panel.selection.has("test:00") and panel.result_label.text.contains("Locked"))
	assert(not panel.toggle_selected("legacy:chassis.bulwark"))
	assert(panel.selection_label.text.begins_with("1 selected"))

	# Quick select by rarity skips blocked items and higher rarities.
	panel.clear_selection()
	panel.quick_select.item_selected.emit(2) # Commons
	for id in panel.selection:
		assert(account.item_instances[id].rarity == "common")
	assert(not panel.selection.has("test:00"))
	assert(panel.selection.size() == 3, "Commons test:04 and test:08 plus the legacy breech")
	panel.quick_select.item_selected.emit(1) # All shown
	assert(panel.selection.size() == 12, "All but the locked and equipped items")

	# Range select uses the shown order and skips blocked items.
	panel.clear_selection()
	panel.sort_mode = "name"
	panel._refresh_grid()
	var order: Array[String] = panel._visible_order.duplicate()
	panel.select_range(order[0], order[order.size() - 1])
	assert(panel.selection.size() == 12)

	# Salvage asks first; rare/epic need the extra tick.
	var before_bank: float = account.bank
	panel.request_salvage_selection()
	assert(panel.salvage_dialog.visible)
	assert(panel.valuable_check.visible and panel.salvage_dialog.get_ok_button().disabled)
	panel.salvage_dialog.confirmed.emit()
	assert(account.item_instances.has("test:01"), "Blocked confirm does nothing")
	panel.valuable_check.toggled.emit(true)
	panel.valuable_check.button_pressed = true
	panel.salvage_dialog.confirmed.emit()
	panel.salvage_dialog.hide()
	assert(account.item_instances.size() == 2, "Only the locked and equipped items remain")
	assert(account.item_instances.has("test:00") and account.item_instances.has("legacy:chassis.bulwark"))
	assert(account.bank > before_bank and account.scrap > 0)
	assert(panel.selection.is_empty())
	assert(panel.result_label.visible and panel.result_label.text.begins_with("Salvaged 12 items"))

	# Commons-only salvage skips the valuable tick.
	account.set_instance_locked("test:00", false)
	_sync()
	panel.toggle_selected("test:00")
	panel.request_salvage_selection()
	assert(not panel.valuable_check.visible and not panel.salvage_dialog.get_ok_button().disabled)
	panel.salvage_dialog.confirmed.emit()
	panel.salvage_dialog.hide()
	assert(not account.item_instances.has("test:00"))

	# Leaving select mode clears picks; the bar hides again.
	panel.set_select_mode(false)
	assert(not panel.selection_bar.visible)
	for frame in range(3):
		await process_frame
	assert(panel.get_combined_minimum_size().y <= 720, "Panel fits the viewport")
	panel.queue_free()
	await process_frame
	print("PASS inventory_multi_select_test: select mode, quick and range select, guarded salvage confirm, payout and cleanup")
	quit(0)
