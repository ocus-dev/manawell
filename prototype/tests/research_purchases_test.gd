extends SceneTree

const AccountScript = preload("res://scripts/model/account_state.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

func _init() -> void:
	var account: RefCounted = AccountScript.new()
	account.bank = 250.0
	assert(TestCheckScript.check(account.purchase_research("weapon.damage", 0, 40), "first rank purchase"))
	assert(TestCheckScript.check(account.research_ranks["weapon.damage"] == 1 and is_equal_approx(account.bank, 210.0), "rank and debit"))
	assert(TestCheckScript.check(not account.purchase_research("weapon.damage", 0, 90), "stale command rejected"))
	var blocked: RefCounted = AccountScript.new()
	blocked.bank = 100.0
	assert(TestCheckScript.check(not blocked.purchase_research("weapon.shots", 0, 100), "prerequisite rejects"))
	assert(TestCheckScript.check(account.purchase_research("weapon.shots", 0, 100), "splitter purchase"))
	assert(TestCheckScript.check(account.equip_research_choice("weapon.fan"), "fan equipment"))
	assert(TestCheckScript.check(not account.equip_research_choice("weapon.fan", true), "active equipment lock"))
	var payload: Dictionary = account.to_save_payload()
	assert(TestCheckScript.check(AccountScript.validate_save_payload(payload).valid, "research save validates"))
	var restored: RefCounted = AccountScript.new()
	restored.from_save_payload(payload)
	assert(TestCheckScript.check(restored.research_ranks.get("weapon.damage", 0) == 1 and restored.equipped_weapon_mode_id == "weapon.fan", "research save reload"))
	var legacy: Dictionary = payload.duplicate(true)
	legacy.erase("research_ranks")
	legacy.erase("equipped_weapon_mode_id")
	legacy["owned_upgrades"] = ["damage_1", "pump_1", "spread_1"]
	var migrated: RefCounted = AccountScript.new()
	migrated.from_save_payload(legacy)
	assert(TestCheckScript.check(migrated.research_ranks.get("weapon.damage", 0) == 1 and migrated.equipped_weapon_mode_id == "weapon.fan", "legacy migration"))
	print("research_purchases: atomic=verified prerequisites=verified stale=verified save=verified legacy=verified")
	quit()