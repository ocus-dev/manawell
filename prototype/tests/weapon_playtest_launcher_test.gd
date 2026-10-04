extends SceneTree

const DesignerScene: PackedScene = preload("res://scenes/tools/weapon_designer.tscn")
const GameplayScene: PackedScene = preload("res://scenes/main.tscn")
const TestProfileScript = preload("res://scripts/tools/weapon_test_profile.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SpySaveStoreScript = preload("res://tests/spy_save_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var designer: Control = DesignerScene.instantiate()
	root.add_child(designer)
	for _frame in range(8):
		await process_frame
	var published_list: ItemList = designer.find_child("PublishedWeaponList", true, false)
	var launch_button: Button = designer.find_child("PlaytestSelectedWeapon", true, false)
	assert(published_list != null and launch_button != null, "published playtest action should be present")
	var test_weapon := str(_published_weapon().id)
	var selected_index := _index_for(published_list, test_weapon)
	assert(selected_index >= 0, "published test weapon should be listed")
	var live_account: RefCounted = AccountStateScript.new()
	var live_save_sentinel: Dictionary = live_account.to_save_payload()
	published_list.select(selected_index)
	designer.call("_select_published_weapon", selected_index)
	var loot_enabled: CheckButton = designer.find_child("EnableFoundryLoot", true, false)
	assert(loot_enabled != null, "published loot opt-in should be present")
	var edited_loot_state := not loot_enabled.button_pressed
	loot_enabled.button_pressed = edited_loot_state
	designer.call("_refresh")
	assert(loot_enabled.button_pressed == edited_loot_state, "background refresh must preserve unsaved loot registration edits")
	launch_button.pressed.emit()
	for _frame in range(8):
		await process_frame
	var controller: Node = designer.get("playtest_controller")
	var profile: RefCounted = designer.get("test_profile")
	assert(controller != null and is_instance_valid(controller), "playtest should create a gameplay controller")
	var account: RefCounted = profile.get("account")
	var instance_id := str(account.get("hero_kits").get("hero_1", {}).get("weapon", ""))
	assert(not instance_id.is_empty(), "selected weapon should be equipped on the temporary hero")
	assert(str(account.get("item_instances").get(instance_id, {}).get("base_id", "")) == test_weapon, "selected weapon should be acquired")
	assert(not bool(controller.get("persistence_enabled")), "playtest must disable persistence")
	assert(live_account.to_save_payload() == live_save_sentinel, "live profile sentinel must remain unchanged")
	var spy := SpySaveStoreScript.new(account)
	controller.set("save_store", spy)
	assert(bool(controller.call("_save_account")), "disabled persistence should accept save requests")
	assert(spy.save_count == 0, "playtest must not write through SaveStore")

	var melee_profile: RefCounted = TestProfileScript.new()
	var melee_publication: Dictionary = melee_profile.get("account").get("published_weapons")[test_weapon].duplicate(true)
	melee_publication["revision"]["behavior_id"] = "weapon.melee"
	melee_profile.get("account").get("published_weapons")[test_weapon] = melee_publication
	var melee_acquisition: Dictionary = melee_profile.acquire_and_equip(test_weapon)
	assert(bool(melee_acquisition.get("valid", false)), "melee fixture should acquire and equip")
	var melee_controller: Node = GameplayScene.instantiate()
	melee_controller.set("persistence_enabled", false)
	melee_controller.set("account_state", melee_profile.get("account"))
	root.add_child(melee_controller)
	assert(bool(melee_controller.call("start_run")), "melee fixture should start")
	assert(str(melee_controller.get("weapon_behavior_id")) == "weapon.melee", "published melee behavior should select melee dispatch")
	melee_controller.queue_free()
	designer.call("_close_playtest")
	await process_frame
	assert(designer.get("designer_tabs").visible, "close playtest should return to the designer")
	assert(not is_instance_valid(designer.get("playtest_controller")), "close playtest should discard the gameplay controller")
	designer.queue_free()
	await process_frame
	print("PASS weapon playtest launcher: selected acquisition/equip, melee dispatch, and zero SaveStore writes")
	quit(0)

func _index_for(list: ItemList, weapon_id: String) -> int:
	for index in list.item_count:
		if str(list.get_item_metadata(index)) == weapon_id:
			return index
	return -1

## Any weapon currently in the game (the tests used to rely on "light blade",
## which has since been removed in the Weapon Lab).
func _published_weapon() -> Dictionary:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/index.json"))
	var weapons: Dictionary = index.get("weapons", {}) if index is Dictionary else {}
	var ids: Array = weapons.keys()
	ids.sort()
	assert(not ids.is_empty(), "at least one weapon must be published")
	return {"id": str(ids[0]), "revision": int(weapons[ids[0]].get("revision", 1))}
