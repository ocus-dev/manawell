extends SceneTree

const AccountStateScript = preload("res://scripts/model/account_state.gd")
const ItemCatalogScript = preload("res://scripts/model/item_catalog.gd")
const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")

func _init() -> void:
	var account: RefCounted = AccountStateScript.new()
	assert(account.published_weapons.has("new_weapon"), "published weapon index should be discoverable")
	assert(ItemCatalogScript.has_item("new_weapon"), "published weapon should be visible to the item catalog")
	assert(account.grant_published_weapon("new_weapon"), account.inventory_command_error)
	var instance_id := "designer:new_weapon:1"
	assert(account.item_instances.has(instance_id), "published weapon instance should be stored")
	var instance: Dictionary = account.item_instances[instance_id]
	assert(instance.base_id == "new_weapon")
	assert(instance.provenance.kind == "designer")
	assert(ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.runtime_bases(), ItemDefinitionsScript.PRODUCTION_AFFIXES).valid)
	assert(account.equip_instance("hero_1", "weapon", instance_id), account.inventory_command_error)
	assert(account.hero_kits["hero_1"].weapon == instance_id)
	assert(not account.grant_published_weapon("new_weapon"), "duplicate acquisition should be rejected")
	print("PASS published weapon acquisition: registration, instance creation, validation, inventory, and equip")
	quit(0)
