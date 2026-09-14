class_name CampaignEncounters
extends RefCounted

# LEGACY MIGRATION DATA: LD02 authors parity values in prototype/data/campaign.
const MONSTER_CONFIGS: Dictionary = {
	"act_01_node_01": {"kind": "monster", "waves": [["pursuer", "pursuer"], ["breaker"]], "reward": 3},
	"act_01_node_03": {"kind": "monster", "waves": [["pursuer", "ranged"], ["breaker", "pursuer"]], "reward": 4},
	"act_01_node_04": {"kind": "monster", "waves": [["breaker"], ["ranged", "pursuer"], ["breaker"]], "reward": 5},
	"act_01_node_06": {"kind": "monster", "waves": [["pursuer", "ranged", "pursuer"], ["breaker", "ranged"]], "reward": 6},
	"act_01_node_07": {"kind": "monster", "waves": [["breaker", "breaker"], ["ranged", "pursuer", "ranged"]], "reward": 7},
}

const BOSS_CONFIG: Dictionary = {
	"kind": "boss",
	"waves": [["boss"]],
	"reward": 12,
	"boss_health": 240.0,
	"boss_attack_interval": 3.0,
	"boss_attack_damage": 18.0,
}

static func for_node(node_id: String, node_type: String) -> Dictionary:
	if node_type == "boss":
		return BOSS_CONFIG.duplicate(true)
	return MONSTER_CONFIGS.get(node_id, {}).duplicate(true)

static func enemy_kind_id(kind: String) -> int:
	if kind == "breaker":
		return 1
	if kind == "ranged":
		return 2
	return 0

static func validate_all(node_ids: Array[String]) -> Dictionary:
	for node_id in node_ids:
		if not MONSTER_CONFIGS.has(node_id) and node_id != "act_01_node_09":
			return {"valid": false, "error": "missing encounter configuration: %s" % node_id}
	return {"valid": true}
