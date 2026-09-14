# Weapon contract (W01)

The JSON schemas and `weapon-example.json` freeze the authoring boundary for W02-W05. Godot runtime validation is authoritative because it supplies field paths and diagnostic codes.

## Identity and revisions

`weapon_id` is the stable authored identity. `revision` is an immutable art and definition revision, starting at 1. A recipe selects both values; an acquired instance must retain that selection when later cards materialize it. `recipe_id` identifies the authored rarity/item-level/affix choice and is not an owned instance ID. `instance_id` remains unique per acquisition.

Recipes map to instances by copying `weapon_id`, `revision`, `rarity`, `item_level`, and the explicit modifiers. Provenance is copied or extended with the recipe/draft source; image pixels never infer behavior, stats, rarity, or description.

## Coordinates and assets

Asset references are repository-local `res://` paths and may not contain `..` or backslashes. A revision requires an icon and world sprite. Image pixels use a top-left origin. `pivot.grip` is normalized `[0,1]`, with x increasing right and y increasing down; `facing` is an explicit right/left presentation choice. The loader can check references with `check_assets=true`.

Supported behavior IDs are currently `weapon.standard`, `weapon.fan`, and `weapon.lance`, matching existing runtime research modes. This contract does not add a new behavior or balance value.

## Compatibility and diagnostics

Legacy built-in items remain in `item_catalog.gd` and are exposed by `WeaponCatalog.legacy_catalog()`. Existing descriptions and icon paths are available through the new lookup helpers without changing account, loot, or gameplay migration. Existing instances with no `revision` field retain their old base definition meaning; `WeaponCatalog.instance_revision()` reports `0` and `is_legacy_instance()` identifies them. Future save migration must preserve that interpretation rather than guessing a published revision.

`WeaponCatalog` returns `{valid, diagnostics}` on success/failure. A failure also has `error`; each diagnostic includes `path`, stable `code`, and precise `message`. Publication entries reject duplicate IDs; revisions reject missing assets, path escapes, nonfinite modifier values and unsupported behaviors; recipes reject invalid rarity/counts and tiers above item level.

Unresolved by design: W02 must define how a prepared world sprite is represented when it is not an imported Godot resource, and W04 must define the atomic publication/index write protocol. Neither is implied by this schema.
