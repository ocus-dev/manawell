class_name ResearchCatalog
extends RefCounted

const TRACKS: Dictionary = {
	"harvest.amount": {"label": "Pump displacement", "group": "harvester", "max_rank": 3, "ranks": [
		{"cost": 60, "effect": "+25% base mana per cycle"}, {"cost": 120, "effect": "+25% base mana per cycle"}, {"cost": 240, "effect": "+25% base mana per cycle"}
	]},
	"harvest.cadence": {"label": "Pump cadence", "group": "harvester", "max_rank": 3, "ranks": [
		{"cost": 50, "effect": "+15% cycles/sec"}, {"cost": 110, "effect": "+15% cycles/sec"}, {"cost": 220, "effect": "+15% cycles/sec"}
	]},
	"weapon.damage": {"label": "Payload", "group": "weapons", "max_rank": 3, "ranks": [
		{"cost": 40, "effect": "+5 damage/projectile"}, {"cost": 90, "effect": "+5 damage/projectile"}, {"cost": 180, "effect": "+5 damage/projectile"}
	]},
	"weapon.rate": {"label": "Autoloader", "group": "weapons", "max_rank": 3, "ranks": [
		{"cost": 50, "effect": "+15% attacks/sec"}, {"cost": 110, "effect": "+15% attacks/sec"}, {"cost": 220, "effect": "+15% attacks/sec"}
	]},
	"weapon.shots": {"label": "Splitter", "group": "weapons", "max_rank": 2, "ranks": [
		{"cost": 100, "effect": "Unlock 3-shot fan"}, {"cost": 180, "effect": "Unlock 5-shot fan"}
	], "prerequisite": {"track": "weapon.damage", "rank": 1}},
	"weapon.velocity": {"label": "Accelerator", "group": "weapons", "max_rank": 3, "ranks": [
		{"cost": 45, "effect": "+25% projectile speed"}, {"cost": 100, "effect": "+25% projectile speed"}, {"cost": 200, "effect": "+25% projectile speed"}
	]},
}

const UNLOCKS: Dictionary = {
	"harvest.rapid_seal": {"label": "Rapid Seal", "group": "harvester", "cost": 140, "prerequisite": {"track": "harvest.cadence", "rank": 2}, "effect": "-20% sealing duration"},
	"harvest.deep_draw": {"label": "Deep Draw", "group": "harvester", "cost": 160, "prerequisite": {"track": "harvest.amount", "rank": 2}, "effect": "x1.25 active output; x1.15 pressure"},
	"weapon.lance": {"label": "Lance", "group": "weapons", "cost": 180, "prerequisites": [{"track": "weapon.damage", "rank": 2}, {"track": "weapon.velocity", "rank": 2}], "effect": "Pierces one additional enemy; -15% attack rate"},
}

static func all_ids() -> Array[String]:
	var result: Array[String] = []
	result.append_array(TRACKS.keys())
	result.append_array(UNLOCKS.keys())
	result.sort()
	return result

static func validate() -> Dictionary:
	for track_id in TRACKS:
		var definition: Dictionary = TRACKS[track_id]
		var ranks: Array = definition.get("ranks", [])
		if int(definition.get("max_rank", -1)) != ranks.size() or ranks.is_empty():
			return {"valid": false, "error": "%s rank bounds are invalid" % track_id}
		for rank in ranks:
			if not (rank is Dictionary) or int(rank.get("cost", 0)) <= 0:
				return {"valid": false, "error": "%s has an invalid rank" % track_id}
			var prerequisite: Dictionary = definition.get("prerequisite", {})
			if not prerequisite.is_empty() and (not TRACKS.has(prerequisite.get("track", "")) or int(prerequisite.get("rank", 0)) < 1):
				return {"valid": false, "error": "%s prerequisite is invalid" % track_id}
	for unlock_id in UNLOCKS:
		var unlock: Dictionary = UNLOCKS[unlock_id]
		if int(unlock.get("cost", 0)) <= 0:
			return {"valid": false, "error": "%s cost is invalid" % unlock_id}
		for prerequisite in unlock.get("prerequisites", [unlock.get("prerequisite", {})]):
			if not prerequisite.is_empty() and (not TRACKS.has(prerequisite.get("track", "")) or int(prerequisite.get("rank", 0)) < 1):
				return {"valid": false, "error": "%s prerequisite is invalid" % unlock_id}
	return {"valid": true}
