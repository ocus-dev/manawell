extends SceneTree

const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")

const DRAFT := {
    "schema_version": 1,
    "draft_id": "draft.heavy_breech",
    "weapon_id": "core.heavy_breech",
    "label": "Heavy Breech",
    "description": "A reinforced weapon chamber recovered from the foundry approach.",
    "behavior_id": "weapon.standard",
    "base_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "implicit.core.heavy_breech.attack_damage", "value": 2}]
}
const REVISION := {
    "schema_version": 1,
    "weapon_id": "core.heavy_breech",
    "revision": 1,
    "label": "Heavy Breech",
    "description": "A reinforced weapon chamber recovered from the foundry approach.",
    "behavior_id": "weapon.standard",
    "base_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "implicit.core.heavy_breech.attack_damage", "value": 2}],
    "assets": {"icon": "res://assets/ui-icons/items/core.heavy_breech.png", "world_sprite": "res://assets/ui-icons/items/core.heavy_breech.png"},
    "pivot": {"coordinate_space": "normalized", "origin": "top_left", "grip": [0.5, 0.75], "facing": "right"}
}
const RECIPE := {
    "schema_version": 1,
    "recipe_id": "recipe.heavy_breech.common",
    "weapon_id": "core.heavy_breech",
    "revision": 1,
    "rarity": "common",
    "item_level": 1,
    "explicit_modifiers": [],
    "provenance": {"kind": "designer", "source_id": "draft.heavy_breech", "run_id": ""}
}

func _init() -> void:
    assert(Catalog.validate_draft_recipe(DRAFT, REVISION, RECIPE, true).valid)
    assert(Catalog.has_weapon("core.heavy_breech"))
    assert(Catalog.description_for("core.heavy_breech").contains("reinforced"))
    assert(Catalog.icon_path_for("core.heavy_breech").ends_with("core.heavy_breech.png"))
    _assert_code(Catalog.validate_publication_entries([REVISION, REVISION.duplicate(true)], true), "DUPLICATE_ID")

    var invalid := REVISION.duplicate(true)
    invalid.assets.icon = "res://../outside.png"
    _assert_code(Catalog.validate_revision(invalid), "PATH_ESCAPE")
    invalid = REVISION.duplicate(true)
    invalid.assets.icon = "res://assets/ui-icons/items/missing.png"
    _assert_code(Catalog.validate_revision(invalid, true), "MISSING_ASSET")
    invalid = DRAFT.duplicate(true)
    invalid.base_modifiers[0].value = INF
    _assert_code(Catalog.validate_draft(invalid), "INVALID_MODIFIER")
    invalid = DRAFT.duplicate(true)
    invalid.behavior_id = "weapon.teleporter"
    _assert_code(Catalog.validate_draft(invalid), "UNSUPPORTED_BEHAVIOR")

    invalid = RECIPE.duplicate(true)
    invalid.rarity = "legendary"
    _assert_code(Catalog.validate_recipe(invalid, REVISION), "INVALID_RARITY")
    invalid = RECIPE.duplicate(true)
    invalid.rarity = "magic"
    _assert_code(Catalog.validate_recipe(invalid, REVISION), "INVALID_AFFIX_COUNT")
    invalid = RECIPE.duplicate(true)
    invalid.rarity = "magic"
    invalid.item_level = 1
    invalid.explicit_modifiers = [{"affix_id": "affix.payload", "tier": 2, "value": 2}]
    _assert_code(Catalog.validate_recipe(invalid, REVISION), "ILLEGAL_TIER_LEVEL")

    var legacy_instance := {"base_id": "core.heavy_breech", "rarity": "common", "item_level": 1}
    assert(Catalog.is_legacy_instance(legacy_instance))
    assert(Catalog.instance_revision(legacy_instance) == 0)
    assert(Definitions.RARITY_MODIFIER_COUNTS.common == 0)
    print("PASS weapon catalog: contract, adapter, asset/path, behavior, recipe, and legacy diagnostics")
    quit(0)

func _assert_code(result: Dictionary, code: String) -> void:
    assert(not result.valid)
    assert(result.diagnostics.size() == 1)
    assert(result.diagnostics[0].code == code)
