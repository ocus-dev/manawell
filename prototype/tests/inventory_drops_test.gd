extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Campaign = preload("res://scripts/model/campaign_state.gd")
const Items = preload("res://scripts/model/item_catalog.gd")
const Store = preload("res://scripts/model/save_store.gd")
const Session = preload("res://scripts/model/session_persistence.gd")
const Run = preload("res://scripts/model/run_state.gd")
const BASE := "res://../work/reviews/inventory-test-profile"

func _init() -> void:
    var account := Account.new()
    var campaign := Campaign.new()
    # Every authored Act 1 level (the act has been trimmed from 9 to 8 before).
    var levels := _act_level_count()
    var catalog = preload("res://scripts/model/campaign_catalog.gd").new()
    var farm_payouts := 0
    for i in range(levels):
        # In map order (the tutorial, Sector B, comes first).
        var id: String = catalog.node_ids("act_01")[i]
        assert(campaign.start_node("act_01", id))
        var result := {"run_id": "inventory-%d" % i, "phase": Run.Phase.FAILED, "payout": 10, "completed_surges": 1}
        assert(not campaign.commit_terminal_result(result, account))
        assert(account.item_instances.size() == i)
        # Well levels also need a completed surge before they count as cleared.
        if str(catalog.get_node("act_01", id).level_data.get("type", "")) == "well":
            # A harvest before the first surge is a farming run: paid, no item, no clear.
            var farming := {"run_id": "inventory-farm-%d" % i, "phase": Run.Phase.SUCCESS, "payout": 10, "completed_surges": 0}
            assert(campaign.commit_terminal_result(farming, account))
            assert(account.item_instances.size() == i)
            farm_payouts += 1
            assert(campaign.start_node("act_01", id))
        result.phase = Run.Phase.SUCCESS
        assert(campaign.commit_terminal_result(result, account))
        assert(account.item_instances.size() == i + 1)
        assert(account.item_reward_ids.size() == i + 1)
        assert(not campaign.commit_terminal_result(result, account))
    assert(account.bank == (levels + farm_payouts) * 10)
    assert(campaign.start_node("act_01", "act_01_node_01"))
    assert(campaign.commit_terminal_result({"run_id": "inventory-replay", "phase": Run.Phase.SUCCESS, "payout": 10}, account))
    assert(account.item_instances.size() == levels)
    assert(account.item_reward_ids.size() == levels)
    var first_instance_id := "reward:act_01_node_01.first_clear.heavy_breech:0"
    print("LD05 replay instances=", account.item_instances.keys())
    assert(account.item_instances.has(first_instance_id))
    assert(account.reward_entitlements.has("act_01_node_01.first_clear.heavy_breech"))
    assert(account.reward_entitlements["act_01_node_01.first_clear.heavy_breech"].delivered_item_ids == [first_instance_id])
    assert(account.inspect_item(first_instance_id))
    assert(not account.inspect_item(first_instance_id))
    assert(account.new_items.has(Items.REWARDS[0]))
    var payload := account.to_save_payload()
    assert(Account.validate_save_payload(payload).valid)
    var invalid := payload.duplicate(true)
    invalid.owned_items.append(Items.REWARDS[0])
    invalid.owned_items.append(Items.REWARDS[0])
    assert(not Account.validate_save_payload(invalid).valid)
    invalid = payload.duplicate(true)
    invalid.new_items.append("unknown")
    assert(not Account.validate_save_payload(invalid).valid)
    var legacy := payload.duplicate(true)
    legacy.owned_items = []
    legacy.new_items = []
    legacy.inventory_migration_version = 0
    for key in ["item_reward_ids", "item_reward_run_id", "reward_entitlements", "item_instances"]:
        legacy.erase(key)
    assert(Account.validate_save_payload(legacy).valid)
    var restored := Account.new()
    restored.from_save_payload(legacy)
    assert(not restored.owned_items.has(Items.REWARDS[0]))
    assert(restored.reconcile_item_rewards(campaign.completed_nodes))
    assert(not restored.reconcile_item_rewards(campaign.completed_nodes))
    assert(restored.bank == account.bank)
    for suffix in [".json", ".tmp", ".bak", ".json.recovery"]:
        if FileAccess.file_exists(BASE + suffix):
            DirAccess.remove_absolute(BASE + suffix)
    var store := Store.new(BASE + ".json", BASE + ".tmp", BASE + ".bak")
    assert(store.save_envelope({"account": account, "campaign_state": campaign.to_save_payload()}))
    var session := Session.new(Store.new(BASE + ".json", BASE + ".tmp", BASE + ".bak"), Account.new(), Callable(), Callable(), Campaign.new())
    var loaded = session.load_account()
    assert(loaded.item_instances.size() == levels and loaded.new_items.size() == levels)
    assert(loaded.bank == (levels + farm_payouts + 1) * 10)
    var spy := preload("res://tests/spy_save_store.gd").new(account)
    spy.fail_next_saves = 1
    var retry_session := Session.new(spy, account, Callable(), Callable(), campaign)
    assert(not retry_session.save())
    assert(retry_session.has_pending_save())
    assert(retry_session.retry_pending_save())
    assert(not retry_session.has_pending_save())
    assert(account.item_instances.size() == levels and account.new_items.size() == levels)
    assert(account.bank == (levels + farm_payouts + 1) * 10 and spy.saved_envelopes.size() == 1)
    restored.from_save_payload(legacy)
    assert(restored.reconcile_item_rewards(campaign.completed_nodes))
    assert(store.save_envelope({"account": restored, "campaign_state": campaign.to_save_payload()}))
    session = Session.new(Store.new(BASE + ".json", BASE + ".tmp", BASE + ".bak"), Account.new(), Callable(), Callable(), Campaign.new())
    loaded = session.load_account()
    assert(loaded.owned_items.has(Items.REWARDS[0]) and loaded.new_items.has(Items.REWARDS[0]))
    assert(not session.has_pending_save())
    for suffix in [".json", ".tmp", ".bak", ".json.recovery"]:
        if FileAccess.file_exists(BASE + suffix):
            DirAccess.remove_absolute(BASE + suffix)
    print("PASS inventory drops: nine clears, failures, commissioning, duplicate commits, replay, inspect, validation, legacy reconciliation, disk persistence, failed-save retry")
    quit(0)

func _act_level_count() -> int:
    var catalog = preload("res://scripts/model/campaign_catalog.gd").new()
    var count := 0
    while not catalog.get_node("act_01", "act_01_node_%02d" % (count + 1)).is_empty():
        count += 1
    return count
