class_name WeaponStatEdits
extends RefCounted

## The numbers behind Dev Encyclopedia > Weapons.
##
## Reads every published weapon from data/weapons/index.json, keeps unsaved
## edits per weapon, and saves them as the weapon's next revision through
## WeaponPublisher.publish_stats_revision (art, placement, animation and effects
## carry over). The Weapon Lab's draft for the weapon gets the same numbers, so
## the next Lab publish doesn't undo them.

const BalanceData = preload("res://data/balance.gd")
const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const LootRegistration = preload("res://scripts/model/weapon_loot_registration.gd")
const CreatureDrops = preload("res://scripts/model/creature_drops.gd")

const DEFAULT_BASE_DAMAGE: float = BalanceData.WEAPON_DAMAGE
const DEFAULT_BASE_RATE: float = 1.0 / BalanceData.WEAPON_INTERVAL
## The Weapon Lab's drafts are named "lab.<weapon id>".
const LAB_DRAFT_PREFIX := "lab."

## Editable stats, in display order. "percent" stats are shown as 0-200 and
## stored on the weapon as a fraction (an "increased" modifier).
const STAT_KEYS := ["base_damage", "base_rate", "bonus_damage", "attack_speed", "projectile_speed"]
const STAT_DEFS := {
	"base_damage": {"label": "Base damage", "hint": "Damage per hit before bonuses and research.", "min": 0.5, "max": 1000.0, "slider_max": 100.0, "step": 0.5},
	"base_rate": {"label": "Attacks / second", "hint": "Base attack speed before bonuses and research.", "min": 0.05, "max": 20.0, "slider_max": 6.0, "step": 0.01},
	"bonus_damage": {"label": "Bonus damage", "hint": "Flat damage on top of base. Capped at +50% of base.", "min": 0.0, "max": 100.0, "slider_max": 50.0, "step": 0.5, "stat": "attack_damage", "operation": "flat"},
	"attack_speed": {"label": "Attack speed bonus %", "hint": "Increased attacks per second. Capped at +30%.", "min": 0.0, "max": 200.0, "slider_max": 100.0, "step": 1.0, "stat": "attacks_per_second", "operation": "increased", "percent": true},
	"projectile_speed": {"label": "Projectile speed bonus %", "hint": "Saved on the weapon. Shots currently fly at the base speed.", "min": 0.0, "max": 200.0, "slider_max": 100.0, "step": 1.0, "stat": "projectile_speed", "operation": "increased", "percent": true},
}
## Loot drop settings (data/loot/weapon_registrations.json). "weight" is the
## weapon's share of item drops: each of the 9 gear bases counts 1.0.
const DROP_DEFS := {
	"weight": {"label": "Shared-roll weight", "hint": "Used when every creature chance is 0. 1.0 = as common as one gear item.", "min": 0.01, "max": 1000.0, "slider_max": 10.0, "step": 0.01},
	"min_item_level": {"label": "From item level", "min": 1.0, "max": 3.0, "step": 1.0},
	"max_item_level": {"label": "To item level", "min": 1.0, "max": 3.0, "step": 1.0},
}
const BEHAVIORS := [
	["weapon.standard", "Ranged"],
	["weapon.melee", "Melee"],
	["weapon.fan", "Fan"],
	["weapon.lance", "Lance"],
]

var data_root: String
var asset_root: String
var draft_root: String
var loot_path: String
## weapon id -> {"revision": Dictionary, "recipe": Dictionary}
var entries: Dictionary = {}
## weapon id -> {"stats": {key: value}, "behavior_id": String,
## "drop": {enabled, weight, min_item_level, max_item_level}} (unsaved edits)
var pending: Dictionary = {}

func _init(data_root_path: String = Publisher.DEFAULT_DATA_ROOT, asset_root_path: String = Publisher.DEFAULT_ASSET_ROOT, draft_root_path: String = Store.DRAFT_ROOT, loot_path_value: String = LootRegistration.DEFAULT_PATH) -> void:
	data_root = data_root_path
	asset_root = asset_root_path
	draft_root = draft_root_path
	loot_path = loot_path_value
	reload()

## Re-reads the published weapons. Unsaved edits for weapons that still exist are kept.
func reload() -> void:
	entries.clear()
	var index := _read_json(data_root.path_join(Publisher.INDEX_NAME))
	var weapons: Variant = index.get("weapons", {})
	if weapons is Dictionary:
		for weapon_id in weapons:
			var revision: Variant = weapons[weapon_id]
			if not revision is Dictionary:
				continue
			var recipe := _read_json(data_root.path_join(str(weapon_id)).path_join(str(int(revision.get("revision", 1)))).path_join("recipe.json"))
			entries[str(weapon_id)] = {"revision": revision, "recipe": recipe}
	for weapon_id in pending.keys():
		if not entries.has(weapon_id):
			pending.erase(weapon_id)

## Weapon ids sorted by name.
func ids() -> Array:
	var result: Array = entries.keys()
	result.sort_custom(func(a: String, b: String) -> bool: return label(a).naturalnocasecmp_to(label(b)) < 0)
	return result

func has_weapon(weapon_id: String) -> bool:
	return entries.has(weapon_id)

func revision(weapon_id: String) -> Dictionary:
	return entries.get(weapon_id, {}).get("revision", {})

func recipe(weapon_id: String) -> Dictionary:
	return entries.get(weapon_id, {}).get("recipe", {})

func label(weapon_id: String) -> String:
	return str(revision(weapon_id).get("label", weapon_id))

func description(weapon_id: String) -> String:
	return str(revision(weapon_id).get("description", ""))

func rarity(weapon_id: String) -> String:
	return str(recipe(weapon_id).get("rarity", "common"))

func revision_number(weapon_id: String) -> int:
	return int(revision(weapon_id).get("revision", 0))

func icon_path(weapon_id: String) -> String:
	return str(revision(weapon_id).get("assets", {}).get("icon", ""))

func world_sprite_path(weapon_id: String) -> String:
	return str(revision(weapon_id).get("assets", {}).get("world_sprite", ""))

static func behavior_label(behavior_id: String) -> String:
	for behavior in BEHAVIORS:
		if behavior[0] == behavior_id:
			return behavior[1]
	return behavior_id

# ---------- values ----------

## The saved (published) value of a stat, in display units.
func published_stat(weapon_id: String, key: String) -> float:
	var published := revision(weapon_id)
	var definition: Dictionary = STAT_DEFS[key]
	if key == "base_damage" or key == "base_rate":
		var stats: Variant = published.get("base_stats", null)
		var field := "attack_damage" if key == "base_damage" else "attacks_per_second"
		if stats is Dictionary and stats.has(field):
			return float(stats[field])
		return DEFAULT_BASE_DAMAGE if key == "base_damage" else DEFAULT_BASE_RATE
	var value := 0.0
	for modifier in published.get("base_modifiers", []):
		if modifier is Dictionary and str(modifier.get("stat", "")) == definition["stat"] and str(modifier.get("operation", "")) == definition["operation"]:
			value += float(modifier.get("value", 0.0))
	return value * 100.0 if definition.get("percent", false) else value

func get_stat(weapon_id: String, key: String) -> float:
	var edits: Dictionary = pending.get(weapon_id, {}).get("stats", {})
	if edits.has(key):
		return float(edits[key])
	return published_stat(weapon_id, key)

## Sets a stat (clamped and snapped to its step) and returns the value kept.
func set_stat(weapon_id: String, key: String, value: float) -> float:
	if not has_weapon(weapon_id) or not STAT_DEFS.has(key):
		return 0.0
	var definition: Dictionary = STAT_DEFS[key]
	var clean := clampf(snappedf(value, float(definition["step"])), float(definition["min"]), float(definition["max"]))
	var edit: Dictionary = pending.get(weapon_id, {"stats": {}})
	if not edit.has("stats"):
		edit["stats"] = {}
	edit["stats"][key] = clean
	pending[weapon_id] = edit
	_prune(weapon_id)
	return clean

func published_behavior(weapon_id: String) -> String:
	return str(revision(weapon_id).get("behavior_id", "weapon.standard"))

func behavior(weapon_id: String) -> String:
	return str(pending.get(weapon_id, {}).get("behavior_id", published_behavior(weapon_id)))

func set_behavior(weapon_id: String, behavior_id: String) -> void:
	if not has_weapon(weapon_id) or not Catalog.SUPPORTED_BEHAVIOR_IDS.has(behavior_id):
		return
	var edit: Dictionary = pending.get(weapon_id, {"stats": {}})
	edit["behavior_id"] = behavior_id
	pending[weapon_id] = edit
	_prune(weapon_id)

func is_stat_modified(weapon_id: String, key: String) -> bool:
	return absf(get_stat(weapon_id, key) - published_stat(weapon_id, key)) > 0.0001

func is_modified(weapon_id: String) -> bool:
	return pending.has(weapon_id)

func modified_ids() -> Array:
	var result: Array = []
	for weapon_id in ids():
		if pending.has(weapon_id):
			result.append(weapon_id)
	return result

func revert(weapon_id: String) -> void:
	pending.erase(weapon_id)

func revert_all() -> void:
	pending.clear()

## Drops edits that match what's saved, so "edited" marks stay honest.
func _prune(weapon_id: String) -> void:
	var edit: Dictionary = pending.get(weapon_id, {})
	var stats: Dictionary = edit.get("stats", {})
	for key in stats.keys():
		if absf(float(stats[key]) - published_stat(weapon_id, key)) <= 0.0001:
			stats.erase(key)
	if edit.has("behavior_id") and str(edit.behavior_id) == published_behavior(weapon_id):
		edit.erase("behavior_id")
	if edit.has("drop") and _same_drop(edit.drop, published_drop(weapon_id)):
		edit.erase("drop")
	if stats.is_empty() and not edit.has("behavior_id") and not edit.has("drop"):
		pending.erase(weapon_id)

# ---------- loot drops ----------

## The saved loot registration ({enabled, weight, min_item_level, max_item_level}).
func published_drop(weapon_id: String) -> Dictionary:
	var saved: Dictionary = LootRegistration.registration_for(weapon_id, loot_path)
	return {"enabled": bool(saved.get("enabled", false)), "weight": float(saved.get("weight", 1.0)), "min_item_level": int(saved.get("min_item_level", 1)), "max_item_level": int(saved.get("max_item_level", 3)), "chances": CreatureDrops.chances_of(saved)}

func drop(weapon_id: String) -> Dictionary:
	var edit: Dictionary = pending.get(weapon_id, {})
	return edit.drop.duplicate(true) if edit.has("drop") else published_drop(weapon_id)

## Changes one drop setting: "enabled" (bool), "weight", "min_item_level",
## "max_item_level", or "chance:<creature>" (percent per kill, 0-100; see
## CreatureDrops). Item levels stay ordered (moving one pushes the other).
func set_drop(weapon_id: String, key: String, value: Variant) -> void:
	if not has_weapon(weapon_id):
		return
	var current := drop(weapon_id)
	if key == "enabled":
		current.enabled = bool(value)
	elif key == "weight":
		current.weight = clampf(snappedf(float(value), 0.01), float(DROP_DEFS.weight.min), float(DROP_DEFS.weight.max))
	elif key == "min_item_level" or key == "max_item_level":
		var level := clampi(int(value), 1, 3)
		current[key] = level
		if key == "min_item_level" and int(current.max_item_level) < level:
			current.max_item_level = level
		if key == "max_item_level" and int(current.min_item_level) > level:
			current.min_item_level = level
	elif key.begins_with("chance:") and CreatureDrops.keys().has(key.trim_prefix("chance:")):
		current.chances[key.trim_prefix("chance:")] = clampf(snappedf(float(value), 0.01), 0.0, 100.0)
	else:
		return
	var edit: Dictionary = pending.get(weapon_id, {"stats": {}})
	edit["drop"] = current
	pending[weapon_id] = edit
	_prune(weapon_id)

func is_drop_modified(weapon_id: String) -> bool:
	return pending.get(weapon_id, {}).has("drop")

## Every published weapon's drop settings, with unsaved edits applied.
func drop_table() -> Dictionary:
	var table := {}
	for weapon_id in entries:
		table[weapon_id] = drop(weapon_id)
	return table

## Unsaved drop settings as loot registrations, for a running level.
func loot_overrides() -> Dictionary:
	var overrides := {}
	for weapon_id in pending:
		if pending[weapon_id].has("drop"):
			var value: Dictionary = pending[weapon_id].drop
			overrides[weapon_id] = {"weapon_id": weapon_id, "enabled": value.enabled, "weight": value.weight, "min_item_level": value.min_item_level, "max_item_level": value.max_item_level, "revision": revision_number(weapon_id), "monster_chances": value.chances.duplicate()}
	return overrides

static func _same_drop(left: Dictionary, right: Dictionary) -> bool:
	if bool(left.enabled) != bool(right.enabled) or absf(float(left.weight) - float(right.weight)) >= 0.0001 or int(left.min_item_level) != int(right.min_item_level) or int(left.max_item_level) != int(right.max_item_level):
		return false
	for key in CreatureDrops.keys():
		if absf(float(left.get("chances", {}).get(key, 0.0)) - float(right.get("chances", {}).get(key, 0.0))) >= 0.0001:
			return false
	return true

## True when the weapon drops per creature (any chance above 0) instead of
## through the shared item roll.
func is_per_creature(weapon_id: String) -> bool:
	return CreatureDrops.is_per_creature({"monster_chances": drop(weapon_id).chances})

# ---------- what the game sees ----------

## base_stats, base_modifiers and behavior_id with the current values, ready
## for the revision (and for the running game). Modifiers this page doesn't
## edit are kept as they are.
func revision_patch(weapon_id: String) -> Dictionary:
	var modifiers: Array = []
	for modifier in revision(weapon_id).get("base_modifiers", []):
		if modifier is Dictionary:
			modifiers.append(modifier.duplicate(true))
	for key in ["bonus_damage", "attack_speed", "projectile_speed"]:
		var definition: Dictionary = STAT_DEFS[key]
		var value := get_stat(weapon_id, key)
		if definition.get("percent", false):
			value = snappedf(value / 100.0, 0.0001)
		modifiers = _with_modifier(modifiers, str(definition["stat"]), str(definition["operation"]), value)
	return {
		"base_stats": {"attack_damage": get_stat(weapon_id, "base_damage"), "attacks_per_second": get_stat(weapon_id, "base_rate")},
		"base_modifiers": modifiers,
		"behavior_id": behavior(weapon_id),
	}

## Same rule as the Weapon Lab: the bonus-damage entry always stays (at 0),
## other bonuses are removed when they're 0.
static func _with_modifier(modifiers: Array, stat: String, operation: String, value: float) -> Array:
	for index in range(modifiers.size()):
		if str(modifiers[index].get("stat", "")) == stat and str(modifiers[index].get("operation", "")) == operation:
			if is_zero_approx(value) and stat != "attack_damage":
				modifiers.remove_at(index)
			else:
				modifiers[index]["value"] = value
			return modifiers
	if is_zero_approx(value) and stat != "attack_damage":
		return modifiers
	var family := "designer.base." + stat
	for modifier in modifiers:
		if str(modifier.get("family", "")) == family:
			family += "." + operation
	modifiers.append({"stat": stat, "operation": operation, "family": family, "value": value})
	return modifiers

## The weapon's in-game numbers with the current values (no research, no
## upgrades), worked out by HeroStatResolver like the Weapon Lab does.
func resolved(weapon_id: String) -> Dictionary:
	var patch := revision_patch(weapon_id)
	var instance := {
		"instance_id": "encyclopedia-preview",
		"base_id": "core.heavy_breech",
		"rarity": rarity(weapon_id),
		"item_level": int(recipe(weapon_id).get("item_level", 1)),
		"implicit_modifiers": patch.base_modifiers,
		"explicit_modifiers": recipe(weapon_id).get("explicit_modifiers", []).duplicate(true),
		"base_stats": patch.base_stats,
	}
	var result := Resolver.resolve({}, {"encyclopedia-preview": instance}, {"weapon": "encyclopedia-preview"})
	var stats: Dictionary = result.get("stats", {})
	var damage := float(stats.get("attack_damage", BalanceData.WEAPON_DAMAGE))
	var rate := float(stats.get("attacks_per_second", DEFAULT_BASE_RATE))
	var base_damage := float(patch.base_stats.attack_damage)
	var capped: Array = []
	if base_damage + get_stat(weapon_id, "bonus_damage") > base_damage * Resolver.CAPS.attack_damage + 0.001:
		capped.append("damage")
	if get_stat(weapon_id, "attack_speed") / 100.0 > Resolver.CAPS.attacks_per_second - 1.0 + 0.0001:
		capped.append("attack speed")
	return {"attack_damage": damage, "attacks_per_second": rate, "attack_interval": 1.0 / rate if rate > 0.0 else 0.0, "dps": damage * rate, "capped": capped}

# ---------- saving ----------

## Publishes every edited weapon as its next revision. Returns
## {"ok", "saved": [ids], "errors": {id: message}}.
func save() -> Dictionary:
	var saved: Array = []
	var errors := {}
	for weapon_id in modified_ids():
		var result := save_weapon(weapon_id)
		if result.get("valid", false):
			saved.append(weapon_id)
		else:
			errors[weapon_id] = str(result.get("error", "could not save"))
	return {"ok": errors.is_empty(), "saved": saved, "errors": errors}

func save_weapon(weapon_id: String) -> Dictionary:
	if not is_modified(weapon_id):
		return {"valid": true, "unchanged": true}
	var edit: Dictionary = pending[weapon_id]
	var wanted_drop := drop(weapon_id)
	var result := {"valid": true}
	if not edit.get("stats", {}).is_empty() or edit.has("behavior_id"):
		var patch := revision_patch(weapon_id)
		result = Publisher.publish_stats_revision(weapon_id, patch, data_root, asset_root)
		if not result.get("valid", false):
			return result
		_sync_lab_draft(weapon_id, patch)
		edit.erase("stats")
		edit.erase("behavior_id")
		reload()
	# Drop settings, and the loot table's note of the current revision.
	var registered: bool = bool(published_drop(weapon_id).enabled) or int(LootRegistration.registration_for(weapon_id, loot_path).get("revision", 0)) != 0
	if edit.has("drop") or registered:
		var loot := LootRegistration.update_weapon(weapon_id, revision(weapon_id), bool(wanted_drop.enabled), float(wanted_drop.weight), int(wanted_drop.min_item_level), int(wanted_drop.max_item_level), loot_path, LootRegistration.TABLE_ID, data_root, wanted_drop.chances)
		if not loot.get("valid", false):
			pending[weapon_id] = edit
			return loot
	pending.erase(weapon_id)
	return result

## Gives the Weapon Lab's draft for this weapon the same numbers, so a later
## Lab publish carries them instead of the old ones.
func _sync_lab_draft(weapon_id: String, patch: Dictionary) -> void:
	var draft := Store.load_draft(LAB_DRAFT_PREFIX + weapon_id, draft_root)
	if draft.is_empty():
		return
	draft["base_stats"] = patch.base_stats.duplicate(true)
	draft["base_modifiers"] = patch.base_modifiers.duplicate(true)
	draft["behavior_id"] = patch.behavior_id
	Store.save_draft(draft, draft_root)

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}
