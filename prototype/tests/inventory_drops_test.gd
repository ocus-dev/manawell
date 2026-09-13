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
    for i in range(9):
        var id := "act_01_node_%02d" % (i + 1)
        assert(campaign.start_node("act_01", id))
        var result := {"run_id": "inventory-%d" % i, "phase": Run.Phase.FAILED, "payout": 10, "completed_surges": 1}
        assert(not campaign.commit_terminal_result(result, account))
        assert(account.owned_items.is_empty())
        if i in [1, 4, 7]:
            result.phase = Run.Phase.SUCCESS
            result.completed_surges = 0
            assert(not campaign.commit_terminal_result(result, account))
            result.completed_surges = 1
        result.phase = Run.Phase.SUCCESS
        assert(campaign.commit_terminal_result(result, account))
        assert(account.item_instances.is_empty())
        assert(account.item_reward_ids.is_empty())
        assert(not campaign.commit_terminal_result(result, account))
    assert(account.bank == 90)
    assert(campaign.start_node("act_01", "act_01_node_01"))
    assert(campaign.commit_terminal_result({"run_id": "inventory-replay", "phase": Run.Phase.SUCCESS, "payout": 10}, account))
    assert(account.owned_items.is_empty() and account.item_reward_ids.is_empty())
    assert(not account.inspect_item(Items.REWARDS[0]))
    assert(not account.inspect_item(Items.REWARDS[0]))
    assert(not account.new_items.has(Items.REWARDS[0]))
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
    for key in ["item_reward_ids", "item_reward_run_id"]:
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
    assert(loaded.owned_items.is_empty() and loaded.new_items.is_empty())
    assert(loaded.bank == 100)
    var spy := preload("res://tests/spy_save_store.gd").new(account)
    spy.fail_next_saves = 1
    var retry_session := Session.new(spy, account, Callable(), Callable(), campaign)
    assert(not retry_session.save())
    assert(retry_session.has_pending_save())
    assert(retry_session.retry_pending_save())
    assert(not retry_session.has_pending_save())
    assert(account.owned_items.is_empty() and account.new_items.is_empty())
    assert(account.bank == 100 and spy.saved_envelopes.size() == 1)
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
