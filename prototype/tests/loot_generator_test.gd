extends SceneTree

const Generator = preload("res://scripts/model/loot_generator.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

func _input() -> Dictionary:
    return {"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "inventory_count": 0, "inventory_capacity": 100, "run_id": "run-05", "enemy_id": 7, "node_id": "act_01_node_09"}

func _init() -> void:
    var input := _input()
    var first := Generator.generate(input, 123456789)
    var repeated := Generator.generate(input, 123456789)
    assert(first.valid and first.generated)
    assert(JSON.stringify(first) == JSON.stringify(repeated))
    assert(first.instance.provenance.kind == "monster")
    assert(first.instance.item_level == 3)
    assert(first.instance.explicit_modifiers.size() == int(Definitions.RARITY_MODIFIER_COUNTS[first.instance.rarity]))
    assert(Definitions.new().validate_instance(first.instance, Definitions.PRODUCTION_BASES, Definitions.PRODUCTION_AFFIXES).valid)
    var next := Generator.generate(input, first.rng_state)
    var resumed := Generator.generate(input, first.rng_state)
    assert(JSON.stringify(next) == JSON.stringify(resumed))

    var ineligible := Generator.generate({"eligible": false, "item_level": 1}, 77)
    assert(ineligible.valid and not ineligible.generated and ineligible.reason == "ineligible" and ineligible.rng_state == 77)
    var full := Generator.generate({"eligible": true, "item_level": 1, "inventory_count": 100, "inventory_capacity": 100}, 77)
    assert(full.valid and not full.generated and full.reason == "capacity" and full.rng_state == 77)

    assert(Generator._occurrence_threshold("ordinary", 0.20) == 240)
    assert(Generator._occurrence_threshold("boss", 0.50) == 3000)
    assert(Generator._rarity_for_roll(0) == "common")
    assert(Generator._rarity_for_roll(5999) == "common")
    assert(Generator._rarity_for_roll(6000) == "magic")
    assert(Generator._rarity_for_roll(8999) == "magic")
    assert(Generator._rarity_for_roll(9000) == "rare")
    assert(Generator._rarity_for_roll(9899) == "rare")
    assert(Generator._rarity_for_roll(9900) == "epic")
    assert(Generator._rarity_for_roll(9999) == "epic")

    var state := 1
    var seen_families := {}
    var generated_count := 0
    for index in 1000:
        var result := Generator.generate({"eligible": true, "occurrence_kind": "boss", "drop_bonus": 0.50, "item_level": 3, "run_id": "simulation", "enemy_id": index + 1, "node_id": "act_01_node_09"}, state)
        if not result.valid:
            push_error("invalid roll at index %d state %d: %s" % [index, state, str(result)])
            quit(1)
        state = result.rng_state
        if result.generated:
            generated_count += 1
            var families := {}
            for modifier in result.instance.explicit_modifiers:
                var affix: Dictionary = Definitions.PRODUCTION_AFFIXES[modifier.affix_id]
                assert(not families.has(affix.family))
                families[affix.family] = true
                assert(int(modifier.tier) == 3)
                var tier_range: Dictionary = affix.tiers[3]
                assert(float(modifier.value) >= float(tier_range.min) and float(modifier.value) <= float(tier_range.max))
            seen_families[result.instance.base_id] = true
    assert(generated_count > 0)
    assert(seen_families.size() > 1)
    print("PASS loot generator: deterministic state, resume, no-roll paths, schema, rarity counts and bounds; generated=", generated_count)
    quit(0)
