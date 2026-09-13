extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const Session = preload("res://scripts/model/session_persistence.gd")
const SpyStore = preload("res://tests/spy_save_store.gd")

func _instance(instance_id: String, base_id: String, implicit: Array) -> Dictionary:
    return {"schema_version": 1, "instance_id": instance_id, "base_id": base_id, "rarity": "common", "item_level": 1, "implicit_modifiers": implicit.duplicate(true), "explicit_modifiers": [], "generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": false, "locked": false}

func _init() -> void:
    assert(Definitions.validate_catalog(Definitions.PRODUCTION_BASES, Definitions.PRODUCTION_AFFIXES).valid)
    var account := Account.new()
    assert(account.add_transitional_item("core.heavy_breech", "", ""))
    assert(account.add_transitional_item("core.heavy_breech", "", "") == false)
    var duplicate := _instance("legacy:core.heavy_breech-copy", "core.heavy_breech", Definitions.PRODUCTION_BASES["core.heavy_breech"].implicits)
    account.item_instances[duplicate.instance_id] = duplicate
    account.roster_heroes["hero_2"] = true
    account.hero_kits["hero_1"] = {"weapon": "legacy:core.heavy_breech", "hero": "", "harvester": ""}
    assert(account.equip_instance("hero_1", "weapon", duplicate.instance_id))
    assert(not account.equip_instance("hero_2", "weapon", duplicate.instance_id))
    assert(not account.discard_instance(duplicate.instance_id, "Heavy Breech"))
    assert(account.unequip_instance("hero_1", "weapon"))
    assert(account.discard_instance(duplicate.instance_id, "Heavy Breech"))
    assert(account.set_instance_locked("legacy:core.heavy_breech", true))
    assert(not account.discard_instance("legacy:core.heavy_breech", "Heavy Breech"))
    assert(account.set_instance_locked("legacy:core.heavy_breech", false))
    assert(not account.equip_instance("hero_1", "hero", "legacy:core.heavy_breech"))
    assert(account.equip_instance("hero_1", "weapon", "legacy:core.heavy_breech"))
    assert(not account.discard_instance("legacy:core.heavy_breech", "Heavy Breech"))
    var payload := account.to_save_payload()
    assert(Account.validate_save_payload(payload).valid)
    var restored := Account.new()
    restored.from_save_payload(JSON.parse_string(JSON.stringify(payload)))
    assert(restored.item_instances.has("legacy:core.heavy_breech"))
    assert(restored.hero_kits["hero_1"]["weapon"] == "legacy:core.heavy_breech")
    var dangling := payload.duplicate(true)
    dangling.hero_kits.hero_1.weapon = "missing"
    assert(not Account.validate_save_payload(dangling).valid)
    var old_payload := payload.duplicate(true)
    old_payload.erase("item_instances")
    old_payload.erase("hero_kits")
    old_payload.erase("inventory_migration_version")
    var migrated := Account.new()
    migrated.from_save_payload(old_payload)
    var migrated_count := migrated.item_instances.size()
    migrated.from_save_payload(old_payload)
    assert(migrated.item_instances.size() == migrated_count)
    var spy := SpyStore.new(account)
    spy.fail_next_saves = 1
    var session := Session.new(spy, account, Callable(), Callable())
    account.bank = 10
    assert(not session.save())
    account.bank = 20
    assert(session.retry_pending_save())
    assert(float(spy.saved_envelopes[0].account_payload.bank) == 10.0)
    print("PASS loot persistence: production tables, duplicate instances, kit legality, lock/discard, migration, and immutable retry")
    quit(0)
