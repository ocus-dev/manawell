class_name WeaponTestProfile
extends RefCounted

## Disposable account boundary used by the designer's acquire/test action.
## It never receives a SaveStore and therefore cannot mutate the production profile.
const AccountStateScript = preload("res://scripts/model/account_state.gd")

var account: RefCounted

func _init() -> void:
	account = AccountStateScript.new()

func acquire(weapon_id: String) -> Dictionary:
	var before := {}
	for instance_id in account.item_instances.keys():
		before[str(instance_id)] = true
	if not account.grant_published_weapon(weapon_id):
		return {"valid": false, "error": account.inventory_command_error}
	var added: Array[String] = []
	for instance_id in account.item_instances.keys():
		var instance: Dictionary = account.item_instances[instance_id]
		if str(instance.get("base_id", "")) == weapon_id and not before.has(str(instance_id)):
			added.append(str(instance_id))
	if added.is_empty():
		return {"valid": false, "error": "published weapon acquisition produced no instance"}
	var instance_id := added[0]
	return {"valid": true, "instance_id": instance_id, "instance": account.item_instances[instance_id].duplicate(true)}

func equip(hero_id: String, instance_id: String) -> bool:
	return account.equip_instance(hero_id, "weapon", instance_id)

func unequip(hero_id: String) -> bool:
	return account.unequip_instance(hero_id, "weapon")
