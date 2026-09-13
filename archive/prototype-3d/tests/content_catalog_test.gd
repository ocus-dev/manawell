extends SceneTree

const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")

func _init() -> void:
	var catalog: RefCounted = ContentCatalogScript.new()
	catalog.define_well("test_well", {"label": "Test Well", "base_output": 9.0, "spawn_interval_factor": 1.0, "enemy_damage_factor": 1.0})
	catalog.define_hero("test_hero", {"label": "Test Hero"})
	catalog.define_upgrade("test_upgrade", {"cost": 7, "label": "Test Upgrade", "effect": "Test effect"})
	assert(catalog.has_well("test_well"))
	assert(catalog.get_well("test_well")["base_output"] == 9.0)
	assert(catalog.well_ids().has("test_well"))
	assert(catalog.hero_ids().has("test_hero"))
	assert(catalog.upgrade_ids().has("test_upgrade"))
	var payload := {
		"bank": 0.0,
		"credited_run_ids": [],
		"owned_upgrades": ["test_upgrade"],
		"unlocked_wells": ["test_well"],
		"commissioned_wells": ["test_well"],
		"roster_heroes": ["test_hero"],
		"hero_assignments": {"hero_1": {"role": "active", "well_id": ""}, "test_hero": {"role": "reserve", "well_id": ""}},
		"well_loadouts": {"test_well": "standard"},
	}
	assert(AccountStateScript.validate_save_payload(payload, catalog)["valid"])
	assert(not AccountStateScript.validate_save_payload(payload)["valid"])
	quit(0)
