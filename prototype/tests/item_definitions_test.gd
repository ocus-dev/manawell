extends SceneTree

const Definitions = preload("res://scripts/model/item_definitions.gd")

# Test-only affixes. Production ranges and pools belong to D02.
const TEST_AFFIXES := {
    "affix.damage": {"id": "affix.damage", "stat": "attack_damage", "operation": "flat", "family": "offense", "eligible_slots": ["weapon"], "min_tier": 1, "max_tier": 3},
    "affix.speed": {"id": "affix.speed", "stat": "attacks_per_second", "operation": "increased", "family": "tempo", "eligible_slots": ["weapon"], "min_tier": 1, "max_tier": 3},
    "affix.health": {"id": "affix.health", "stat": "max_health", "operation": "flat", "family": "vitality", "eligible_slots": ["hero"], "min_tier": 1, "max_tier": 2},
    "affix.armor": {"id": "affix.armor", "stat": "armor", "operation": "flat", "family": "guard", "eligible_slots": ["hero"], "min_tier": 1, "max_tier": 2},
}
const TEST_CATALOG := {
    "base.rivet_cannon": {"id": "base.rivet_cannon", "label": "Rivet Cannon", "slot": "weapon", "implicits": [{"stat": "attack_damage", "operation": "flat", "family": "base_damage", "value": 2}]},
    "base.survey_frame": {"id": "base.survey_frame", "label": "Survey Frame", "slot": "hero", "implicits": [{"stat": "max_health", "operation": "flat", "family": "base_health", "value": 10}]},
}
const TEST_METADATA := {"generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": false, "locked": false}
const COMMON_INSTANCE := {"schema_version": 1, "instance_id": "inst-rivet-common-001", "base_id": "base.rivet_cannon", "rarity": "common", "item_level": 1, "implicit_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "base_damage", "value": 2}], "explicit_modifiers": [], "generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": false, "locked": false}
const RARE_INSTANCE_A := {"schema_version": 1, "instance_id": "inst-rivet-rare-001", "base_id": "base.rivet_cannon", "rarity": "rare", "item_level": 2, "implicit_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "base_damage", "value": 2}], "explicit_modifiers": [{"affix_id": "affix.damage", "tier": 1, "value": 3}, {"affix_id": "affix.speed", "tier": 2, "value": 0.15}], "generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": false, "locked": false}
const RARE_INSTANCE_B := {"schema_version": 1, "instance_id": "inst-rivet-rare-002", "base_id": "base.rivet_cannon", "rarity": "rare", "item_level": 2, "implicit_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "base_damage", "value": 2}], "explicit_modifiers": [{"affix_id": "affix.damage", "tier": 1, "value": 5}, {"affix_id": "affix.speed", "tier": 1, "value": 0.05}], "generation_version": "loot-v1", "provenance": {"kind": "legacy", "run_id": "", "enemy_id": 0, "node_id": ""}, "inspected": false, "locked": false}

func _init() -> void:
    assert(Definitions.validate_catalog(TEST_CATALOG, TEST_AFFIXES).valid)
    assert(not Definitions.validate_catalog({}, {"broken": {}}).valid)
    var decoded = JSON.parse_string(Definitions.serialize_instance(RARE_INSTANCE_A))
    assert(Definitions.validate_instance(decoded, TEST_CATALOG, TEST_AFFIXES).valid)
    assert(Definitions.validate_instance(COMMON_INSTANCE, TEST_CATALOG, TEST_AFFIXES).valid)
    assert(Definitions.validate_instance(RARE_INSTANCE_A, TEST_CATALOG, TEST_AFFIXES).valid)
    assert(Definitions.validate_instance(RARE_INSTANCE_B, TEST_CATALOG, TEST_AFFIXES).valid)
    assert(Definitions.validate_instances([RARE_INSTANCE_A, RARE_INSTANCE_B], TEST_CATALOG, TEST_AFFIXES).valid)
    assert(Definitions.serialize_instance(COMMON_INSTANCE) == "{\"base_id\":\"base.rivet_cannon\",\"explicit_modifiers\":[],\"generation_version\":\"loot-v1\",\"implicit_modifiers\":[{\"family\":\"base_damage\",\"operation\":\"flat\",\"stat\":\"attack_damage\",\"value\":2}],\"inspected\":false,\"instance_id\":\"inst-rivet-common-001\",\"item_level\":1,\"locked\":false,\"provenance\":{\"enemy_id\":0,\"kind\":\"legacy\",\"node_id\":\"\",\"run_id\":\"\"},\"rarity\":\"common\",\"schema_version\":1}")

    var invalid := RARE_INSTANCE_A.duplicate(true)
    invalid.schema_version = 2
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.item_level = 1.5
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    var fractional_health := COMMON_INSTANCE.duplicate(true)
    fractional_health.base_id = "base.survey_frame"
    fractional_health.implicit_modifiers = TEST_CATALOG["base.survey_frame"].implicits.duplicate(true)
    fractional_health.rarity = "magic"
    fractional_health.explicit_modifiers = [{"affix_id": "affix.health", "tier": 1, "value": 3}]
    assert(Definitions.validate_instance(fractional_health, TEST_CATALOG, TEST_AFFIXES).valid)
    fractional_health.explicit_modifiers[0].value = 3.5
    assert(not Definitions.validate_instance(fractional_health, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.base_id = "base.unknown"
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.instance_id = "base.rivet_cannon"
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.rarity = "legendary"
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.item_level = 0
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.explicit_modifiers[0].value = INF
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.explicit_modifiers[0].affix_id = "affix.unknown"
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.explicit_modifiers[1].affix_id = "affix.damage"
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.explicit_modifiers[0].tier = 3
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.base_id = "base.survey_frame"
    invalid.explicit_modifiers[0].affix_id = "affix.health"
    invalid.explicit_modifiers[0].value = 3.5
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    invalid = RARE_INSTANCE_A.duplicate(true)
    invalid.explicit_modifiers.resize(1)
    assert(not Definitions.validate_instance(invalid, TEST_CATALOG, TEST_AFFIXES).valid)
    assert(not Definitions.validate_instances([RARE_INSTANCE_A, RARE_INSTANCE_A], TEST_CATALOG, TEST_AFFIXES).valid)
    print("PASS item definitions: catalog, rarity counts, stable serialization, duplicate bases, and negative validators")
    quit(0)
