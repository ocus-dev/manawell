extends SceneTree

## A weapon's type decides melee vs ranged: picking a sword makes it melee,
## picking a gun makes it ranged, and the lab warns when they disagree.

const WeaponTypesScript = preload("res://scripts/model/weapon_types.gd")
const Readiness = preload("res://scripts/model/weapon_readiness.gd")

func _init() -> void:
	for type_id in ["sword", "axe", "hammer", "spear", "dagger", "club"]:
		assert(WeaponTypesScript.default_behavior(type_id) == "weapon.melee", type_id)
	for type_id in ["gun", "bow"]:
		assert(WeaponTypesScript.default_behavior(type_id) == "weapon.standard", type_id)
	assert(WeaponTypesScript.default_behavior("staff") == "" and WeaponTypesScript.default_behavior("") == "")
	assert(WeaponTypesScript.behavior_mismatch("sword", "weapon.standard"))
	assert(WeaponTypesScript.behavior_mismatch("sword", "weapon.fan"))
	assert(not WeaponTypesScript.behavior_mismatch("sword", "weapon.melee"))
	assert(WeaponTypesScript.behavior_mismatch("gun", "weapon.melee"))
	assert(not WeaponTypesScript.behavior_mismatch("gun", "weapon.lance"))
	assert(not WeaponTypesScript.behavior_mismatch("staff", "weapon.standard"))
	var info := {"has_art": true, "weapon_type": "sword", "type_label": "Sword", "behavior_id": "weapon.standard", "clip_source": "type", "clip": {}, "grip": [0.4, 0.7], "hand_offset": [1.0, 1.0], "published": 1}
	var type_item := _type_item(Readiness.check(info))
	assert(type_item.status == "warn" and str(type_item.text).contains("Melee"), str(type_item))
	info["behavior_id"] = "weapon.melee"
	assert(_type_item(Readiness.check(info)).status == "ok")
	# Every published sword/axe/... in the game is melee, every gun ranged.
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/index.json"))
	for weapon_id in index.get("weapons", {}):
		var revision: Dictionary = index.weapons[weapon_id]
		assert(not WeaponTypesScript.behavior_mismatch(str(revision.get("weapon_type", "")), str(revision.get("behavior_id", ""))), "%s: %s set to %s" % [weapon_id, revision.get("weapon_type"), revision.get("behavior_id")])
	print("PASS: weapon type picks melee/ranged behavior; mismatches warn")
	quit(0)

func _type_item(result: Dictionary) -> Dictionary:
	for item in result.items:
		if item.key == "type":
			return item
	return {}
