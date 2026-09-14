extends SceneTree

const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")
const CampaignDefinitionsScript = preload("res://data/campaign_definitions.gd")
const CampaignEncountersScript = preload("res://data/campaign_encounters.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const ItemCatalogScript = preload("res://scripts/model/item_catalog.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")
const LoaderScript = preload("res://scripts/model/level_data_loader.gd")

func _init() -> void:
	var catalog: RefCounted = CampaignCatalogScript.new()
	assert(catalog.is_valid())
	var act: Dictionary = catalog.get_act("act_01")
	assert(act["nodes"].size() == 9)
	for legacy_node in CampaignDefinitionsScript.ACTS[0]["nodes"]:
		var node: Dictionary = catalog.get_node("act_01", legacy_node["id"])
		assert(node["display_name"] == legacy_node["display_name"])
		assert(node["type"] == legacy_node["type"])
		assert(node["position"] == legacy_node["position"])
		assert(node["prerequisites"] == legacy_node["prerequisites"])
		if legacy_node.has("well_id"):
			assert(node["well_id"] == legacy_node["well_id"])
		var level: Dictionary = node["level_data"]
		assert(level["rewards"]["mana_on_success"] == float(CampaignEncountersScript.for_node(legacy_node["id"], legacy_node["type"]).get("reward", 0)))
		assert(level["rewards"]["guaranteed_items"][0]["base_id"] == ItemCatalogScript.reward_for("act_01", legacy_node["id"]))
		if legacy_node["type"] == "monster" or legacy_node["type"] == "boss":
			var expected: Array = CampaignEncountersScript.for_node(legacy_node["id"], legacy_node["type"])["waves"]
			var actual: Array = []
			for wave in level["encounter"]["spawning"]["waves"]:
				var kinds: Array = []
				for entry in wave["monsters"]:
					for _index in range(int(entry["count"])):
						kinds.append(entry["monster_id"])
				actual.append(kinds)
			if actual != expected:
				push_error("wave parity mismatch for %s: actual=%s expected=%s" % [legacy_node["id"], str(actual), str(expected)])
				quit(1)
	var boss_level: Dictionary = catalog.get_node("act_01", "act_01_node_09")["level_data"]
	assert(boss_level["boss"] == {"health": 240.0, "attack_interval": 3.0, "attack_damage": 18.0})

	var content: RefCounted = ContentCatalogScript.new()
	for well_id in ["well_1", "well_2", "well_3"]:
		var campaign_well: Dictionary = catalog.get_node("act_01", _node_for_well(well_id))["level_data"]["well"]
		var runtime_well: Dictionary = content.get_well(well_id)
		assert(runtime_well["id"] == campaign_well["id"])
		assert(runtime_well["source_level_id"] == _node_for_well(well_id))
		assert(runtime_well["base_output"] == campaign_well["base_mana_per_second"])
		assert(runtime_well["spawn_interval_factor"] == campaign_well["spawn_interval_multiplier"])
		assert(runtime_well["enemy_damage_factor"] == campaign_well["enemy_damage_factor"])

	var save_state: RefCounted = CampaignStateScript.new()
	save_state.completed_nodes["act_01/act_01_node_01"] = true
	save_state.unlocked_acts["act_01"] = true
	var payload: Dictionary = save_state.to_save_payload()
	var restored: RefCounted = CampaignStateScript.new()
	assert(restored.from_save_payload(payload, catalog))
	assert(restored.completed_nodes.has("act_01/act_01_node_01"))
	assert(restored.node_status("act_01", "act_01_node_02", catalog)["status"] == CampaignStateScript.STATUS_AVAILABLE)

	_write_small_fixture()
	var small_loader: RefCounted = LoaderScript.new()
	assert(small_loader.load("user://ld02-two-node"))
	assert(small_loader.level_ids("act_small").size() == 2)
	var small_catalog: RefCounted = CampaignCatalogScript.new("user://ld02-two-node")
	assert(small_catalog.is_valid())
	assert(small_catalog.node_ids("act_small").size() == 2)
	_cleanup_fixture()
	print("LD02 migration parity checks passed")
	quit(0)

func _node_for_well(well_id: String) -> String:
	return {"well_1": "act_01_node_02", "well_2": "act_01_node_05", "well_3": "act_01_node_08"}[well_id]

func _write_small_fixture() -> void:
	var root := "user://ld02-two-node"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "/acts"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "/levels"))
	_write(root + "/index.json", {"schema_version": 1, "act_files": ["acts/act_small.json"]})
	_write(root + "/acts/act_small.json", {"schema_version": 1, "id": "act_small", "display_name": "Small", "layout_revision": "test", "level_files": ["levels/one.json", "levels/two.json"], "completion_requires": []})
	_write(root + "/levels/one.json", _small_level("one", []))
	_write(root + "/levels/two.json", _small_level("two", ["one"]))

func _small_level(level_id: String, prerequisites: Array) -> Dictionary:
	return {"schema_version": 1, "content_revision": 1, "id": level_id, "act_id": "act_small", "display_name": level_id, "type": "monster", "map": {"position": [0.1, 0.2]}, "requires_completed": prerequisites, "environment_id": "foundry", "encounter": {"mode": "waves", "available_monsters": ["pursuer"], "scaling": {"hp_multiplier": 1, "damage_multiplier": 1, "move_speed_multiplier": 1, "attack_interval_multiplier": 1}, "spawning": {"waves": [{"monsters": [{"monster_id": "pursuer", "count": 1}], "delay_before_seconds": 0}]}}, "completion": {"objective": "clear_waves"}, "rewards": {"mana_on_success": 1, "loot": {"table_id": "foundry_physical_v1", "item_level": 1, "ordinary_drop_chance": 0, "boss_drop_chance": 0}, "guaranteed_items": []}}

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))

func _cleanup_fixture() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ld02-two-node/levels/two.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ld02-two-node/levels/one.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ld02-two-node/acts/act_small.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ld02-two-node/index.json"))
