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
	await _test_boss()
	await _test_failure_retention_and_suspend()
	if failed_checks == 0:
		print("PASS L08 acceptance: well, ordinary loot/equip/reload, boss, failure retention and suspend snapshot")
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
	_check(controller.start_campaign_node("act_01", "act_01_node_01"), "ordinary node did not start")
	_check(not controller.enemies.is_empty(), "ordinary node spawned no enemy")
	var enemy: Node = controller.enemies[0]
	var roll := _find_drop(controller.run_state.run_id, enemy.enemy_id, controller.campaign_node_id, "ordinary", float(controller.resolved_stats.get("drop_bonus", 0.0)), "core.")
	controller.loot_rng_state = int(roll.get("state", 1))
	enemy.take_damage(enemy.health)
	controller.tick(1.0 / 60.0)
	_check(controller.account_state.item_instances.size() == 1, "ordinary kill did not collect one item")
	var instance: Dictionary = controller.account_state.item_instances.values()[0]
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

func _test_boss() -> void:
	var controller := _controller()
	for index in range(1, 9):
		controller.campaign_state.completed_nodes["act_01/act_01_node_%02d" % index] = true
	_check(controller.start_campaign_node("act_01", "act_01_node_09"), "boss node did not start")
	_check(controller.boss_enemy != null, "boss did not spawn")
	var boss: Node = controller.boss_enemy
	var roll := _find_drop(controller.run_state.run_id, boss.enemy_id, controller.campaign_node_id, "boss", float(controller.resolved_stats.get("drop_bonus", 0.0)))
	controller.loot_rng_state = int(roll.get("state", 1))
	boss.take_damage(boss.health)
	controller.tick(1.0 / 60.0)
	_check(controller.account_state.item_instances.size() == 1, "boss kill did not collect one item")
	controller.queue_free()
	await process_frame

func _test_failure_retention_and_suspend() -> void:
	var controller := _controller()
	_check(controller.start_campaign_node("act_01", "act_01_node_01"), "failure node did not start")
	var enemy: Node = controller.enemies[0]
	var roll := _find_drop(controller.run_state.run_id, enemy.enemy_id, controller.campaign_node_id, "ordinary", float(controller.resolved_stats.get("drop_bonus", 0.0)))
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

func _find_drop(run_id: String, enemy_id: int, node_id: String, occurrence_kind: String, drop_bonus: float, required_prefix: String = "") -> Dictionary:
	var state := 1
	for attempt in range(1000):
		var result := Generator.generate({"eligible": true, "occurrence_kind": occurrence_kind, "drop_bonus": drop_bonus, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": run_id, "enemy_id": enemy_id, "node_id": node_id}, state)
		if result.valid and result.generated and (required_prefix.is_empty() or str(result.instance.base_id).begins_with(required_prefix)):
			return {"state": state, "instance": result.instance}
		state += 1
	return {"state": 1, "instance": {}}