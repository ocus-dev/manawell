extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SalvageScript = preload("res://scripts/model/salvage.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _init() -> void:
	call_deferred("_run")

func _copy(account: RefCounted, source_id: String, new_id: String, rarity: String, level: int) -> String:
	var instance: Dictionary = account.item_instances[source_id].duplicate(true)
	instance.instance_id = new_id
	instance.rarity = rarity
	instance.item_level = level
	account.item_instances[new_id] = instance
	return new_id

func _run() -> void:
	# Yield table: rarity and item level both raise the payout.
	var common := SalvageScript.yield_for({"rarity": "common", "item_level": 1})
	var epic := SalvageScript.yield_for({"rarity": "epic", "item_level": 1})
	var common_high := SalvageScript.yield_for({"rarity": "common", "item_level": 11})
	assert(common.mana == 2.0 and common.scrap == 1)
	assert(epic.mana > common.mana and epic.scrap > common.scrap)
	assert(is_equal_approx(float(common_high.mana), 4.0) and int(common_high.scrap) == 2)
	assert(SalvageScript.describe({"mana": 4.5, "scrap": 3}) == "4.5 mana + 3 scrap")

	var account = AccountStateScript.new()
	assert(account.grant_item("core.heavy_breech"))
	assert(account.grant_item("chassis.bulwark"))
	var weapon := "legacy:core.heavy_breech"
	var chassis := "legacy:chassis.bulwark"
	var extra := _copy(account, weapon, "test:extra", "rare", 5)
	var locked := _copy(account, weapon, "test:locked", "common", 1)
	assert(account.set_instance_locked(locked, true))
	assert(account.equip_instance("hero_1", "hero", chassis))

	# Blockers and preview.
	assert(account.salvage_blocker(locked) == "Locked items cannot be salvaged.")
	assert(account.salvage_blocker(chassis) == "Equipped items cannot be salvaged.")
	assert(account.salvage_blocker(weapon, true) == "Salvage is unavailable during a run.")
	assert(account.salvage_blocker("missing") == "Unknown item.")
	var preview: Dictionary = account.salvage_preview([weapon, extra, locked, chassis, weapon])
	assert(preview.count == 2 and preview.blocked == 2, "Preview counts each id once and skips blocked items")

	# Nothing moves during a run.
	var during: Dictionary = account.salvage_instances([weapon], true)
	assert(during.salvaged.is_empty() and account.item_instances.has(weapon) and account.bank == 0.0)

	# Bulk salvage: eligible items go, blocked ones stay, resources are paid.
	var expected := SalvageScript.total_for([account.item_instances[weapon], account.item_instances[extra]])
	var result: Dictionary = account.salvage_instances([weapon, extra, locked, chassis, "missing", extra])
	assert(result.salvaged.size() == 2, "Two eligible items salvaged")
	assert(result.skipped.size() == 3, "Locked, equipped and unknown are skipped")
	assert(not account.item_instances.has(weapon) and not account.item_instances.has(extra))
	assert(account.item_instances.has(locked) and account.item_instances.has(chassis))
	assert(is_equal_approx(account.bank, float(expected.mana)) and account.scrap == int(expected.scrap))
	assert(is_equal_approx(float(result.mana), float(expected.mana)) and int(result.scrap) == int(expected.scrap))
	# The locked copy still holds the base, so it stays owned.
	assert(account.owned_items.has("core.heavy_breech"))

	# Single-item salvage replaces discard.
	assert(account.set_instance_locked(locked, false))
	assert(account.salvage_instance(locked))
	assert(not account.owned_items.has("core.heavy_breech"), "Last copy gone: base no longer owned")
	assert(not account.salvage_instance(locked))
	assert(not account.inventory_command_error.is_empty())

	# Scrap survives a save round trip and bad values are rejected.
	var payload: Dictionary = account.to_save_payload()
	assert(payload.scrap == account.scrap)
	var json_payload: Dictionary = JSON.parse_string(JSON.stringify(payload))
	assert(AccountStateScript.validate_save_payload(json_payload).valid, str(AccountStateScript.validate_save_payload(json_payload)))
	var restored = AccountStateScript.new()
	restored.from_save_payload(json_payload)
	assert(restored.scrap == account.scrap and is_equal_approx(restored.bank, account.bank))
	var old_save := json_payload.duplicate(true)
	old_save.erase("scrap")
	assert(AccountStateScript.validate_save_payload(old_save).valid, "Saves from before salvage still load")
	restored.from_save_payload(old_save)
	assert(restored.scrap == 0)
	var bad := json_payload.duplicate(true)
	bad.scrap = -1
	assert(not AccountStateScript.validate_save_payload(bad).valid)
	bad.scrap = 1.5
	assert(not AccountStateScript.validate_save_payload(bad).valid)
	print("PASS inventory_salvage_test: yields, blockers, bulk salvage, ownership and scrap persistence")
	quit(0)
