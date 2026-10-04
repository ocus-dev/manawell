extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const Run = preload("res://scripts/model/run_state.gd")

var failed_checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_well()
	await _test_monster_collect_equip_reload()
	await _test_failure_retention_and_suspend()
	if failed_checks == 0:
		print("PASS L08 acceptance: well, ordinary loot/equip/reload, failure retention and suspend snapshot")
		quit(0)
	else:
		push_error("L08 acceptance failed checks: %d" % failed_checks)
		quit(1)

func _check(condition: Variant, message: String) -> bool:
	if condition == true:
		return true
	failed_checks += 1
	push_error("L08: " + message)
	return false

func _controller() -> Node:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	return controller

func _test_well() -> void:
	var controller := _controller()
	_check(controller.start_run(), "well did not start")
	controller.tick(1.0)
	_check(controller.run_state.tank_base > 0.0, "well produced no tank value")
	_check(controller.request_harvest(), "well harvest request failed")
	controller.tick(2.0)
	_check(controller.run_state.phase == Run.Phase.SUCCESS, "well did not succeed")
	_check(controller.account_state.bank > 0.0, "well reward was not retained")
	controller.queue_free()
	await process_frame

func _test_monster_collect_equip_reload() -> void:
	var controller := _controller()
	controller.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	_check(controller.start_campaign_node("act_01", "act_01_node_01"), "ordinary node did not start")
	controller.loot_enabled = true
	var enemy: Node = controller.spawn_enemy(0, 1)
	var items_before: Dictionary = controller.account_state.item_instances.duplicate()
	var roll := _find_drop(controller, enemy, "core.")
	_check(not roll.instance.is_empty(), "no seed dropped a weapon core")
	controller.loot_rng_state = int(roll.get("state", 1))
	enemy.take_damage(enemy.health)
	controller.tick(1.0 / 60.0)
	_check(controller.account_state.item_instances.size() == items_before.size() + 1, "ordinary kill did not collect one item")
	var instance: Dictionary = {}
	for instance_id in controller.account_state.item_instances.keys():
		if not items_before.has(instance_id):
			instance = controller.account_state.item_instances[instance_id]
	var payload := instance.duplicate(true)
	var hero_id: String = controller.account_state.get_active_hero_id()
	var slot := str(Definitions.PRODUCTION_BASES[str(instance.base_id)].slot)
	var hero_kit: Dictionary = controller.account_state.hero_kits.get(hero_id, {"weapon": "", "hero": "", "harvester": ""})
	var before := Resolver.resolve(controller.account_state.research_ranks, controller.account_state.item_instances, hero_kit)
	_check(controller.account_state.equip_instance(hero_id, slot, str(instance.instance_id)), "collected item could not be equipped")
	var after := Resolver.resolve(controller.account_state.research_ranks, controller.account_state.item_instances, controller.account_state.hero_kits.get(hero_id, hero_kit))
	_check(before.stats != after.stats or before.harvest != after.harvest, "equipping item changed no effective stat")
	var restored := Account.new()
	restored.from_save_payload(controller.account_state.to_save_payload())
	_check(restored.item_instances[str(instance.instance_id)] == payload, "reloaded item payload changed")
	controller.queue_free()
	await process_frame

func _test_failure_retention_and_suspend() -> void:
	var controller := _controller()
	controller.campaign_state.completed_nodes["act_01/act_01_node_02"] = true # tutorial done
	_check(controller.start_campaign_node("act_01", "act_01_node_01"), "failure node did not start")
	controller.loot_enabled = true
	var enemy: Node = controller.spawn_enemy(0, 1)
	var roll := _find_drop(controller, enemy)
	controller.loot_rng_state = int(roll.get("state", 1))
	enemy.take_damage(enemy.health)
	controller.tick(1.0 / 60.0)
	var collected: int = controller.account_state.item_instances.size()
	controller.run_state.apply_damage(Run.DamageTarget.HERO, 100000.0)
	controller.tick(1.0 / 60.0)
	_check(controller.run_state.phase == Run.Phase.FAILED, "run did not fail")
	_check(controller.account_state.item_instances.size() == collected, "failed run lost collected item")
	controller.retry()
	_check(controller.run_state.phase != Run.Phase.FAILED, "failed run did not retry")
	controller.toggle_pause()
	_check(controller.run_state.paused, "retry did not pause")
	var snapshot: Dictionary = controller._capture_snapshot()
	_check(snapshot.loot_state.acquired_item_ids is Array, "snapshot omitted acquired item IDs")
	_check(snapshot.run_state.paused, "snapshot omitted paused state")
	controller.queue_free()
	await process_frame

## A loot RNG seed that makes this enemy drop an item, using the same roll
## input the controller builds in _roll_enemy_reward.
func _find_drop(controller: Node, enemy: Node, required_prefix: String = "") -> Dictionary:
	var node_id := str(controller.frozen_level_definition.get("id", controller.campaign_state.active_node_id))
	if node_id.is_empty():
		node_id = controller.selected_well_id
	var roll_input := {"eligible": true, "occurrence_kind": "boss" if str(controller.frozen_level_definition.get("type", "")) == "boss" else "ordinary", "drop_bonus": 0.0, "item_level": controller.loot_item_level, "inventory_count": controller.account_state.item_instances.size(), "inventory_capacity": Account.INVENTORY_CAPACITY, "run_id": controller.run_state.run_id, "enemy_id": int(enemy.enemy_id), "node_id": node_id, "published_pool": controller.frozen_loot_registration.get("pool", []).duplicate(true)}
	for state in range(1, 20000):
		var result := Generator.generate(roll_input, state)
		if result.valid and result.generated and (required_prefix.is_empty() or str(result.instance.base_id).begins_with(required_prefix)):
			return {"state": state, "instance": result.instance}
	return {"state": 1, "instance": {}}
