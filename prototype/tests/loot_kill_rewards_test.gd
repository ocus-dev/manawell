extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Campaign = preload("res://scripts/model/campaign_state.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const Run = preload("res://scripts/model/run_state.gd")
const Snapshot = preload("res://scripts/model/run_snapshot.gd")
const Enemy = preload("res://scripts/game/melee_enemy.gd")

func _init() -> void:
    _test_account_transaction()
    _test_campaign_has_no_fixed_grant()
    _test_snapshot_ledgers()
    _test_deferred_controller_death()
    print("PASS L06 loot transactions: exact collection, duplicate protection, deferred death, retired ledgers, no fixed campaign grants")
    quit(0)

func _input(state: int, enemy_id: int = 7) -> Dictionary:
    return {"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": "run-l06", "enemy_id": enemy_id, "node_id": "act_01_node_09"}

func _test_account_transaction() -> void:
    var state := 1
    var generated := Generator.generate(_input(state), state)
    while generated.valid and not generated.generated and state < 1000:
        state += 1
        generated = Generator.generate(_input(state), state)
    if not generated.valid or not generated.generated:
        push_error("could not produce a deterministic generated item")
        quit(1)
    var account := Account.new()
    if not account.add_monster_instance(generated.instance):
        push_error("monster instance rejected: %s" % account.inventory_command_error)
        quit(1)
    if account.add_monster_instance(generated.instance):
        push_error("duplicate monster instance was accepted")
        quit(1)
    account.record_loot_result("run-l06", [generated.instance.instance_id])
    if account.last_loot_result.get("item_ids", []) != [generated.instance.instance_id]:
        push_error("loot result mismatch: %s" % str(account.last_loot_result))
        quit(1)
    var payload_validation := Account.validate_save_payload(account.to_save_payload())
    if not payload_validation.valid:
        push_error("account payload rejected after collection: %s" % payload_validation.error)
        quit(1)

func _test_campaign_has_no_fixed_grant() -> void:
    var account := Account.new()
    var campaign := Campaign.new()
    assert(campaign.start_node("act_01", "act_01_node_01"))
    var result := {"run_id": "campaign-l06", "phase": Run.Phase.SUCCESS, "payout": 1, "completed_surges": 1}
    assert(campaign.commit_terminal_result(result, account))
    assert(account.item_instances.is_empty())
    assert(account.last_loot_result.item_ids.is_empty())

func _test_snapshot_ledgers() -> void:
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    get_root().add_child(controller)
    assert(controller.start_run())
    controller.loot_enabled = true
    controller.loot_item_level = 1
    controller.loot_retired_ranges.clear()
    controller.loot_retired_ranges.append([1, 2])
    controller.loot_retired_ranges.append([4, 4])
    controller.loot_acquired_item_ids.clear()
    controller.next_enemy_id = 6
    var encoded := Snapshot.encode(controller._capture_snapshot())
    assert(encoded.valid)
    var decoded := Snapshot.decode(encoded.payload)
    assert(decoded.valid)
    assert(decoded.snapshot.loot_state.retired_ranges == [[1, 2], [4, 4]])
    controller.queue_free()

func _test_deferred_controller_death() -> void:
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    get_root().add_child(controller)
    assert(controller.start_run())
    controller.loot_enabled = true
    controller.loot_item_level = 3
    controller.campaign_node_id = "act_01_node_09"
    var enemy: Node = controller.spawn_enemy(0, 1)
    controller.boss_enemy = enemy
    var state := 1
    var preview := Generator.generate({"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": controller.run_state.run_id, "enemy_id": enemy.enemy_id, "node_id": controller.campaign_node_id}, state)
    while preview.valid and not preview.generated and state < 1000:
        state += 1
        preview = Generator.generate({"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": controller.run_state.run_id, "enemy_id": enemy.enemy_id, "node_id": controller.campaign_node_id}, state)
    controller.loot_rng_state = state
    enemy.take_damage(enemy.health)
    assert(enemy.dead and controller.pending_enemy_deaths.size() == 1)
    controller.tick(1.0 / 60.0)
    if not controller.pending_enemy_deaths.is_empty() or controller.account_state.item_instances.size() != 1:
        push_error("deferred death did not collect exactly one item: queue=%d items=%d state=%d" % [controller.pending_enemy_deaths.size(), controller.account_state.item_instances.size(), controller.loot_rng_state])
        quit(1)
    if controller.loot_retired_ranges != [[enemy.enemy_id, enemy.enemy_id]]:
        push_error("unexpected retired ranges: %s" % str(controller.loot_retired_ranges))
        quit(1)
    controller.queue_free()
