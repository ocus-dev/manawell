extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Campaign = preload("res://scripts/model/campaign_state.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const Run = preload("res://scripts/model/run_state.gd")
const Snapshot = preload("res://scripts/model/run_snapshot.gd")
const Enemy = preload("res://scripts/game/melee_enemy.gd")

func _init() -> void:
    _test_account_transaction()
    _test_campaign_delivers_authored_grant()
    _test_snapshot_ledgers()
    _test_deferred_controller_death()
    print("PASS loot transactions: exact collection, duplicate protection, deferred death, snapshot loot state, authored campaign grants")
    quit(0)

func _input(state: int, enemy_id: int = 7) -> Dictionary:
    return {"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": "run-l06", "enemy_id": enemy_id, "node_id": "act_01_node_08"}

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

func _test_campaign_delivers_authored_grant() -> void:
    var account := Account.new()
    var campaign := Campaign.new()
    campaign.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
    assert(campaign.start_node("act_01", "act_01_node_01"))
    var result := {"run_id": "campaign-l06", "phase": Run.Phase.SUCCESS, "payout": 1, "completed_surges": 1}
    assert(campaign.commit_terminal_result(result, account))
    assert(account.item_instances.size() == 1)
    assert(account.reward_entitlements.size() == 1)
    assert(account.reward_entitlements.has("act_01_node_01.first_clear.heavy_breech"))
    assert(account.reward_entitlements["act_01_node_01.first_clear.heavy_breech"].delivered_item_ids.size() == 1)

func _test_snapshot_ledgers() -> void:
    # The loot RNG state and collected item ids survive a snapshot round trip.
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    get_root().add_child(controller)
    assert(controller.start_run())
    controller.loot_enabled = true
    controller.loot_item_level = 1
    controller.loot_rng_state = 4242
    controller.loot_acquired_item_ids.clear()
    controller.loot_acquired_item_ids.append("monster.test.1")
    var encoded := Snapshot.encode(controller._capture_snapshot())
    assert(encoded.valid)
    var decoded := Snapshot.decode(encoded.payload)
    assert(decoded.valid)
    assert(int(decoded.snapshot.loot_state.rng_state) == 4242)
    assert(decoded.snapshot.loot_state.acquired_item_ids == ["monster.test.1"])
    controller.queue_free()

## The same roll input the controller builds in _roll_enemy_reward.
func _roll_input(controller: Node, enemy: Node) -> Dictionary:
    var node_id := str(controller.frozen_level_definition.get("id", controller.campaign_state.active_node_id))
    if node_id.is_empty():
        node_id = controller.selected_well_id
    return {"eligible": true, "occurrence_kind": "boss" if str(controller.frozen_level_definition.get("type", "")) == "boss" else "ordinary", "drop_bonus": 0.0, "item_level": controller.loot_item_level, "inventory_count": controller.account_state.item_instances.size(), "inventory_capacity": Account.INVENTORY_CAPACITY, "run_id": controller.run_state.run_id, "enemy_id": int(enemy.enemy_id), "node_id": node_id, "published_pool": controller.frozen_loot_registration.get("pool", []).duplicate(true)}

func _test_deferred_controller_death() -> void:
    # A kill is queued, then collected exactly once on the next tick.
    var controller: Node = load("res://scenes/main.tscn").instantiate()
    controller.persistence_enabled = false
    controller.development_drop_percent = -1.0
    get_root().add_child(controller)
    assert(controller.start_run())
    controller.loot_enabled = true
    controller.loot_item_level = 1
    var enemy: Node = controller.spawn_enemy(0, 1)
    var state := 1
    var preview := Generator.generate(_roll_input(controller, enemy), state)
    while preview.valid and not preview.generated and state < 5000:
        state += 1
        preview = Generator.generate(_roll_input(controller, enemy), state)
    assert(preview.valid and preview.generated, "no seed produced a drop")
    controller.loot_rng_state = state
    var items_before: int = controller.account_state.item_instances.size()
    enemy.take_damage(enemy.health)
    assert(enemy.dead and controller.pending_enemy_deaths.size() == 1)
    controller.tick(1.0 / 60.0)
    if not controller.pending_enemy_deaths.is_empty() or controller.account_state.item_instances.size() != items_before + 1:
        push_error("deferred death did not collect exactly one item: queue=%d items=%d" % [controller.pending_enemy_deaths.size(), controller.account_state.item_instances.size() - items_before])
        quit(1)
    assert(controller.loot_acquired_item_ids.size() == 1)
    controller.queue_free()
