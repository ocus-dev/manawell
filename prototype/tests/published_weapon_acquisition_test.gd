extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const ItemCatalogScript = preload("res://scripts/model/item_catalog.gd")
const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")
const HeroStatResolverScript = preload("res://scripts/model/hero_stat_resolver.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const WeaponTestProfileScript = preload("res://scripts/tools/weapon_test_profile.gd")

const LIVE_PATH := "res://../work/.published_weapon_test.json"
const TEMP_PATH := "res://../work/.published_weapon_test.json.tmp"
const BACKUP_PATH := "res://../work/.published_weapon_test.json.bak"

func _init() -> void:
	_cleanup()
	var production: RefCounted = AccountStateScript.new()
	var profile: RefCounted = WeaponTestProfileScript.new()
	assert(production.published_weapons.has("new_weapon"), "published weapon index should be discoverable")
	assert(ItemCatalogScript.has_item("new_weapon"), "published weapon should be visible to the item catalog")
	var first: Dictionary = profile.acquire("light blade")
	assert(first.valid, str(first.get("error", "first acquisition failed")))
	var second: Dictionary = profile.acquire("light blade")
	assert(second.valid, str(second.get("error", "second acquisition failed")))
	assert(first.instance_id != second.instance_id, "each test acquisition must have a unique instance ID")
	assert(production.item_instances.is_empty(), "test acquisition must not mutate the production profile")
	var instance: Dictionary = first.instance
	assert(instance.base_id == "light blade")
	assert(instance.weapon_id == "light blade")
	assert(int(instance.revision) == 1)
	assert(instance.provenance.kind == "designer")
	assert(ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.runtime_bases(), ItemDefinitionsScript.PRODUCTION_AFFIXES).valid)
	assert(profile.equip("hero_1", first.instance_id))
	assert(profile.account.hero_kits["hero_1"].weapon == first.instance_id)
	var before: Dictionary = HeroStatResolverScript.resolve({}, {}, {"weapon": ""}).stats
	var after: Dictionary = HeroStatResolverScript.resolve({}, profile.account.item_instances, profile.account.hero_kits["hero_1"]).stats
	assert(float(after.attack_damage) > float(before.attack_damage), "equipped authored modifiers should affect resolved stats")
	assert(profile.unequip("hero_1"))
	assert(str(profile.account.hero_kits["hero_1"].weapon).is_empty())
	assert(profile.account.grant_item("core.heavy_breech"), profile.account.inventory_command_error)
	assert(not profile.account.item_instances["legacy:core.heavy_breech"].has("revision"), "legacy instances retain their old identity")
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(profile.account), store.last_error)
	var restored: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH).load_account()
	assert(restored.item_instances.size() == 3, "save/reload must preserve authored and legacy instances")
	assert(restored.item_instances.has(first.instance_id))
	assert(restored.item_instances[first.instance_id].recipe_id == first.instance.recipe_id)
	assert(restored.item_instances.has("legacy:core.heavy_breech"), "legacy instance remains usable after reload")
	for index in range(97):
		profile.account.item_instances["filler:%d" % index] = {}
	assert(not profile.account.grant_published_weapon("light blade"), "full inventory must reject test acquisition")
	assert(profile.account.inventory_command_error.contains("full"))
	_cleanup()
	print("PASS published weapon acquisition: isolated profile, unique instances, revision identity, stats, save/reload, and capacity")
	quit(0)

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, LIVE_PATH + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
