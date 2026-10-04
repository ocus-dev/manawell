class_name Salvage
extends RefCounted

## Salvage turns inventory items into resources: banked mana (spendable now)
## and scrap (a stored material for future crafting). Tune the tables here.

## Mana paid for a level 1 item of each rarity.
const MANA_BY_RARITY := {"common": 2.0, "magic": 5.0, "rare": 12.0, "epic": 30.0}
## Scrap paid for a level 1 item of each rarity.
const SCRAP_BY_RARITY := {"common": 1, "magic": 3, "rare": 8, "epic": 20}
## Each item level above 1 adds this share of the base payout.
const LEVEL_BONUS := 0.1
## Item rarities that ask for an extra confirmation before salvage.
const VALUABLE_RARITIES := ["rare", "epic"]

static func level_factor(item_level: int) -> float:
	return 1.0 + LEVEL_BONUS * float(maxi(0, item_level - 1))

## What one item pays: {"mana": float, "scrap": int}.
static func yield_for(instance: Dictionary) -> Dictionary:
	var rarity := str(instance.get("rarity", "common"))
	var factor := level_factor(int(instance.get("item_level", 1)))
	var mana: float = float(MANA_BY_RARITY.get(rarity, MANA_BY_RARITY.common)) * factor
	var scrap: int = int(round(float(SCRAP_BY_RARITY.get(rarity, SCRAP_BY_RARITY.common)) * factor))
	return {"mana": snappedf(mana, 0.01), "scrap": scrap}

## Combined payout for several items.
static func total_for(instances: Array) -> Dictionary:
	var mana := 0.0
	var scrap := 0
	for instance in instances:
		var value := yield_for(instance)
		mana += float(value.mana)
		scrap += int(value.scrap)
	return {"mana": snappedf(mana, 0.01), "scrap": scrap, "count": instances.size()}

static func is_valuable(instance: Dictionary) -> bool:
	return VALUABLE_RARITIES.has(str(instance.get("rarity", "common")))

static func describe(total: Dictionary) -> String:
	return "%s mana + %d scrap" % [_number(float(total.get("mana", 0.0))), int(total.get("scrap", 0))]

static func _number(value: float) -> String:
	var text := "%.2f" % value
	return text.trim_suffix("0").trim_suffix("0").trim_suffix(".")
