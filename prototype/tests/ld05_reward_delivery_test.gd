extends SceneTree

const Account = preload("res://scripts/model/account_state.gd")
const Campaign = preload("res://scripts/model/campaign_state.gd")
const Catalog = preload("res://scripts/model/campaign_catalog.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const Run = preload("res://scripts/model/run_state.gd")
const Items = preload("res://scripts/model/item_catalog.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _init() -> void:
	_test_authored_level_and_guaranteed_generation()
	_test_pending_partial_delivery_and_reload()
	_test_replay_and_nine_migrated_rewards()
	print("PASS LD05 reward delivery: authored levels, guaranteed RNG bypass, common/rare, pending capacity, partial claim, reload idempotency, nine mappings")
	quit(0)

func _test_authored_level_and_guaranteed_generation() -> void:
	var account := Account.new()
	var custom_level := {"rewards": {"guaranteed_items": [{"reward_id": "reordered.first_clear", "trigger": "first_clear", "base_id": "core.heavy_breech", "item_level": 3, "rarity": "common", "quantity": 1}]}}
	var result := _success("ld05-authored", 0)
	assert(account.complete_campaign_run(result, result.run_id, "reordered_node_01", custom_level))
	var instance: Dictionary = account.item_instances["reward:reordered.first_clear:0"]
	assert(int(instance.item_level) == 3)
	assert(instance.rarity == "common")
	assert(instance.provenance.kind == "campaign")
	assert(Definitions.new().validate_instance(instance, Definitions.PRODUCTION_BASES, Definitions.PRODUCTION_AFFIXES).valid)
	assert(account.reward_entitlements["reordered.first_clear"].delivered_item_ids == [instance.instance_id])
	var rare := _generated_campaign_item("rare-test", "module.fast_cycle", "rare", 2)
	assert(rare.valid and rare.generated)
	assert(rare.instance.rarity == "rare" and int(rare.instance.item_level) == 2)
	assert(rare.instance.explicit_modifiers.size() == 2)
	var ordinary := Generator.generate({"eligible": true, "occurrence_kind": "ordinary", "drop_bonus": 0.0, "item_level": 1, "run_id": "ordinary", "enemy_id": 1, "node_id": "reordered_node_01", "inventory_count": 0, "inventory_capacity": 100}, 1)
	assert(ordinary.valid)
	assert(ordinary.rng_state != Generator.seed_for("reordered.first_clear:0"))

func _test_pending_partial_delivery_and_reload() -> void:
	var account := Account.new()
	for index in range(Account.INVENTORY_CAPACITY):
		assert(account.add_campaign_instance(_generated_campaign_item("filler-%03d" % index, "core.accelerator", "common", 1).instance))
	var level := {"rewards": {"guaranteed_items": [{"reward_id": "quantity.first_clear", "trigger": "first_clear", "base_id": "module.bracing", "item_level": 2, "rarity": "rare", "quantity": 2}]}}
	var result := _success("ld05-capacity", 0)
	assert(account.complete_campaign_run(result, result.run_id, "node_reordered_07", level))
	assert(account.pending_rewards.size() == 2)
	assert(account.reward_entitlements["quantity.first_clear"].delivered_item_ids.is_empty())
	var payload := account.to_save_payload()
	assert(Account.validate_save_payload(payload).valid)
	var restored := Account.new()
	restored.from_save_payload(payload)
	assert(restored.pending_rewards.size() == 2)
	assert(restored.complete_campaign_run(result, result.run_id, "node_reordered_07", level) == false)
	var discarded_id := str(restored.item_instances.keys()[0])
	var discarded_base := str(restored.item_instances[discarded_id].base_id)
	assert(restored.discard_instance(discarded_id, str(Definitions.PRODUCTION_BASES[discarded_base].label)))
	assert(restored.claim_pending_rewards() == 1)
	assert(restored.pending_rewards.size() == 1)
	for item_id in restored.item_instances.keys():
		if restored.item_instances[item_id].base_id == "core.accelerator":
			assert(restored.discard_instance(item_id, str(Definitions.PRODUCTION_BASES["core.accelerator"].label)))
			break
	var second_payload := restored.to_save_payload()
	var reloaded := Account.new()
	reloaded.from_save_payload(second_payload)
	assert(reloaded.claim_pending_rewards() == 1)
	assert(reloaded.pending_rewards.is_empty())
	assert(reloaded.item_instances.has("reward:quantity.first_clear:0"))
	assert(reloaded.item_instances.has("reward:quantity.first_clear:1"))
	assert(reloaded.reward_entitlements["quantity.first_clear"].delivered_item_ids.size() == 2)
	assert(reloaded.claim_pending_rewards() == 0)

func _test_replay_and_nine_migrated_rewards() -> void:
	var account := Account.new()
	var campaign := Campaign.new()
	var catalog := Catalog.new()
	assert(catalog.is_valid())
	for index in range(9):
		var node_id := "act_01_node_%02d" % (index + 1)
		assert(campaign.start_node("act_01", node_id, catalog))
		var result := _success("ld05-nine-%02d" % index, 1)
		assert(campaign.commit_terminal_result(result, account, catalog))
		assert(not campaign.commit_terminal_result(result, account, catalog))
	assert(account.reward_entitlements.size() == 9)
	assert(account.item_instances.size() == 9)
	for index in range(9):
		var node_id := "act_01_node_%02d" % (index + 1)
		var authored_level: Dictionary = catalog.get_node("act_01", node_id).level_data
		var authored_reward: Dictionary = authored_level.rewards.guaranteed_items[0]
		var reward_id := str(authored_reward.reward_id)
		assert(reward_id.begins_with(node_id + ".first_clear."))
		assert(account.reward_entitlements.has(reward_id), "missing migrated reward for %s" % node_id)
		var instance_id := str(account.reward_entitlements[reward_id].item_ids[0])
		var instance: Dictionary = account.item_instances[instance_id]
		assert(instance.base_id == authored_reward.base_id)
		assert(int(instance.item_level) == int(authored_reward.item_level))
		assert(instance.rarity == authored_reward.rarity)
	var payload := account.to_save_payload()
	var restored := Account.new()
	restored.from_save_payload(payload)
	assert(restored.item_instances.size() == 9)
	assert(restored.reward_entitlements.size() == 9)
	assert(restored.claim_pending_rewards() == 0)

func _success(run_id: String, completed_surges: int) -> Dictionary:
	return {"run_id": run_id, "phase": Run.Phase.SUCCESS, "payout": 0, "completed_surges": completed_surges}

func _generated_campaign_item(identity: String, base_id: String, rarity: String, item_level: int) -> Dictionary:
	var reward_id := "fixture.%s" % identity
	var instance_id := "reward:%s:0" % reward_id
	return Generator.generate_guaranteed({"reward_id": reward_id, "instance_id": instance_id, "base_id": base_id, "rarity": rarity, "item_level": item_level, "run_id": "fixture-run", "node_id": identity}, Generator.seed_for(instance_id))
