extends SceneTree

const Generator = preload("res://scripts/model/loot_generator.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

const KILLS := 100000

func _init() -> void:
    var ordinary := _run_scenario("ordinary", 0.0, 0x13579BDF)
    var boss := _run_scenario("boss", 0.50, 0x2468ACE1)
    print(JSON.stringify({"kills": KILLS, "ordinary": ordinary, "boss": boss}))
    quit(0)

func _run_scenario(kind: String, drop_bonus: float, initial_state: int) -> Dictionary:
    var state := initial_state
    var drops := 0
    var rarities := {"common": 0, "magic": 0, "rare": 0, "epic": 0}
    var bases := {}
    var slots := {"weapon": 0, "hero": 0, "harvester": 0}
    var build_inputs := {}
    for index in KILLS:
        var result := Generator.generate({
            "eligible": true,
            "occurrence_kind": kind,
            "drop_bonus": drop_bonus,
            "item_level": 3,
            "inventory_count": 0,
            "inventory_capacity": 100,
            "run_id": "l05-simulation",
            "enemy_id": index + 1,
            "node_id": "act_01_node_09",
        }, state)
        if not result.valid:
            push_error("invalid result at %d: %s" % [index, str(result)])
            quit(1)
        state = result.rng_state
        if not result.generated:
            continue
        drops += 1
        var instance: Dictionary = result.instance
        var rarity := str(instance.rarity)
        var base_id := str(instance.base_id)
        var slot := str(Definitions.PRODUCTION_BASES[base_id].slot)
        rarities[rarity] += 1
        bases[base_id] = int(bases.get(base_id, 0)) + 1
        slots[slot] += 1
        var key := "%s/%s" % [slot, rarity]
        if not build_inputs.has(key):
            build_inputs[key] = {
                "base_id": base_id,
                "rarity": rarity,
                "item_level": int(instance.item_level),
                "explicit_modifiers": instance.explicit_modifiers,
            }
    return {
        "seed": initial_state,
        "threshold": Generator._occurrence_threshold(kind, drop_bonus),
        "drops": drops,
        "rarities": rarities,
        "bases": bases,
        "slots": slots,
        "build_inputs": build_inputs,
        "final_rng_state": state,
    }
