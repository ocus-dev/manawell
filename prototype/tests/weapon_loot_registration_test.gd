extends SceneTree

const Registration = preload("res://scripts/model/weapon_loot_registration.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const TEST_PATH := "res://data/loot/weapon_registrations_test.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var index := _read("res://data/weapons/index.json")
	assert(not index.get("weapons", {}).is_empty(), "published weapon fixture is required")
	var ids: Array = index.weapons.keys()
	ids.sort()
	var weapon_id := str(ids[0])
	var definition: Dictionary = index.weapons[weapon_id]
	var revision := int(definition.revision)
	var recipe := _read("res://data/weapons/%s/%d/recipe.json" % [weapon_id, revision])

	var disabled := Registration.update_weapon(weapon_id, definition, false, 1000.0, 2, 3, TEST_PATH)
	assert(disabled.valid)
	assert(Registration.snapshot_for(Registration.TABLE_ID, 2, TEST_PATH).pool.is_empty(), "publication alone/disabled registration must not drop")

	var enabled := Registration.update_weapon(weapon_id, definition, true, 1000.0, 2, 3, TEST_PATH)
	assert(enabled.valid)
	assert(Registration.snapshot_for(Registration.TABLE_ID, 1, TEST_PATH).pool.is_empty(), "level eligibility must be enforced")
	var frozen := Registration.snapshot_for(Registration.TABLE_ID, 2, TEST_PATH)
	assert(frozen.pool.size() == 1 and frozen.pool[0].weapon_id == weapon_id)

	var generated := {}
	for seed in range(1, 500):
		generated = Generator.generate({"eligible": true, "occurrence_kind": "ordinary", "drop_bonus": 0.0, "item_level": 2, "inventory_count": 0, "inventory_capacity": 100, "run_id": "designer-loot-test", "enemy_id": seed, "node_id": "act_01_node_05", "development_drop_percent": 100.0, "published_pool": frozen.pool}, seed)
		if generated.get("generated", false) and str(generated.get("instance", {}).get("base_id", "")) == weapon_id:
			break
	assert(generated.get("generated", false) and generated.instance.base_id == weapon_id, "weighted published recipe must be selectable")
	assert(generated.instance.revision == revision)
	assert(generated.instance.recipe_id == recipe.recipe_id)
	assert(generated.instance.rarity == recipe.rarity)
	assert(generated.instance.item_level == recipe.item_level)
	assert(generated.instance.explicit_modifiers == recipe.explicit_modifiers)
	assert(generated.instance.provenance.kind == "monster")

	var account := AccountStateScript.new()
	var before := account.item_instances.size()
	assert(account.add_monster_instance(generated.instance), "published drop must enter inventory through the normal monster boundary")
	assert(account.item_instances.size() == before + 1)
	var frozen_copy: Dictionary = frozen.duplicate(true)
	Registration.update_weapon(weapon_id, definition, false, 1.0, 1, 1, TEST_PATH)
	assert(frozen_copy.pool.size() == 1, "active-run pool must remain frozen after registration changes")
	_cleanup()
	print("PASS weapon loot registration: explicit opt-in, level gates, weight selection, exact recipe, inventory grant, and frozen pool")
	quit(0)

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	assert(file != null, "missing fixture: %s" % path)
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
