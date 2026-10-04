class_name SkillTree
extends RefCounted

## The mech skill tree, laid out like a circuit board: the mech type is the
## chip in the middle and six branches run out from it like traces. Each
## branch is the same shape (see BRANCH_TEMPLATE): three nodes straight out to
## a keystone at the edge, with a fork of two nodes splitting off the second.
##
## A node can be powered (unlocked) once the node it hangs off is powered (the
## core always is). Powering costs Scrap; refunding returns all of it.
##
## Board coordinates: the core sits at (0, 0); one unit is one pixel of the
## painted board (assets/ui/skill_tree/skill_board_plate.png, 1134x779) before
## it is scaled to fit its panel. Node positions are the painted chip spots.
##
## Effects use HeroStatResolver's stat names ("increased" = percent, "flat" =
## added) so they can be summed into hero stats; `scrap_yield` adds to salvage.
## They are not applied in combat yet (see stat_totals()).

const CORE_ID := "core"

## The chip in the middle. Only the basic frame exists for now; each later mech
## type can bring its own core (and later its own branches).
const MECH_TYPES := {
	"basic": {"name": "MK-I Basic Frame", "code": "MK-I", "subtitle": "BASIC FRAME"},
}
const DEFAULT_MECH_TYPE := "basic"

## Branch directions in degrees (0 = right, 90 = down, Godot's y-down canvas).
## `side` mirrors the fork so neighbouring branches don't all lean one way.
const BRANCHES: Array[Dictionary] = [
	{"id": "weapons", "name": "WEAPONS", "angle": 300.0, "side": 1.0},
	{"id": "reactor", "name": "REACTOR", "angle": 0.0, "side": -1.0},
	{"id": "drill", "name": "DRILL", "angle": 60.0, "side": 1.0},
	{"id": "salvage", "name": "SALVAGE", "angle": 120.0, "side": -1.0},
	{"id": "mobility", "name": "MOBILITY", "angle": 180.0, "side": 1.0},
	{"id": "armor", "name": "ARMOR", "angle": 240.0, "side": -1.0},
]

## Shape of every branch: the node each one hangs off, its tier and its Scrap
## cost.
const BRANCH_TEMPLATE: Array[Dictionary] = [
	{"key": "1", "parent": "", "tier": "minor", "cost": 3},
	{"key": "2", "parent": "1", "tier": "minor", "cost": 5},
	{"key": "3", "parent": "2", "tier": "notable", "cost": 10},
	{"key": "f1", "parent": "2", "tier": "minor", "cost": 6},
	{"key": "f2", "parent": "f1", "tier": "notable", "cost": 14},
	{"key": "k", "parent": "3", "tier": "keystone", "cost": 30},
]

## The painted board: its size, where the core chip's centre is, and where
## every node sits, all in the painting's pixels. Positions are stored relative
## to ART_CORE (see _build).
const ART_SIZE := Vector2(1134, 779)
const ART_CORE := Vector2(548, 414)
const ART_POSITIONS := {
	"armor": {"1": Vector2(495, 319), "2": Vector2(461, 265), "3": Vector2(425, 207), "f1": Vector2(386.5, 265), "f2": Vector2(330, 223), "k": Vector2(375, 129)},
	"weapons": {"1": Vector2(600.5, 319), "2": Vector2(634.5, 265), "3": Vector2(670, 208), "f1": Vector2(708.5, 265), "f2": Vector2(765, 224), "k": Vector2(720, 129)},
	"mobility": {"1": Vector2(436, 416), "2": Vector2(365, 416), "3": Vector2(289, 421), "f1": Vector2(325, 363.5), "f2": Vector2(253.5, 334), "k": Vector2(207.5, 421)},
	"reactor": {"1": Vector2(659.5, 416.5), "2": Vector2(730.5, 416.5), "3": Vector2(806.5, 421), "f1": Vector2(769, 363), "f2": Vector2(835, 334), "k": Vector2(886.5, 421)},
	"salvage": {"1": Vector2(495, 509), "2": Vector2(461, 561.5), "3": Vector2(375, 583.5), "f1": Vector2(441, 600), "f2": Vector2(425, 651), "k": Vector2(336, 656)},
	"drill": {"1": Vector2(600.5, 509), "2": Vector2(634.5, 561.5), "3": Vector2(715, 583.5), "f1": Vector2(655, 600), "f2": Vector2(670, 651), "k": Vector2(759, 656)},
}
## Where each branch's first trace leaves the core chip (painting pixels).
const ART_CORE_EXITS := {
	"armor": Vector2(505, 336), "weapons": Vector2(591, 336), "mobility": Vector2(472, 416),
	"reactor": Vector2(624, 416), "salvage": Vector2(505, 492), "drill": Vector2(591, 492),
}
## Where each branch's "n/6" count is printed, under its painted name
## (left end of the text baseline, painting pixels).
const ART_COUNT_POSITIONS := {
	"armor": Vector2(292, 151), "weapons": Vector2(780, 151), "mobility": Vector2(178, 492),
	"reactor": Vector2(890, 492), "salvage": Vector2(291, 603), "drill": Vector2(784, 604),
}

## What each node is called and does, per branch and template key.
const NODE_CONTENT := {
	"weapons": {
		"1": {"name": "Barrel Polish", "effects": [["attack_damage", "increased", 0.04]]},
		"2": {"name": "Tuned Firing Pins", "effects": [["attack_damage", "increased", 0.04]]},
		"3": {"name": "Overcharged Barrels", "code": "OVR", "effects": [["attack_damage", "increased", 0.10]]},
		"f1": {"name": "Magnetic Feed", "effects": [["projectile_speed", "increased", 0.06]]},
		"f2": {"name": "Rail Accelerator", "code": "RAIL", "effects": [["projectile_speed", "increased", 0.12]]},
		"k": {"name": "Twin-Linked Arms", "code": "TWN", "effects": [["attack_damage", "increased", 0.15]]},
	},
	"reactor": {
		"1": {"name": "Clean Coolant", "effects": [["attacks_per_second", "increased", 0.03]]},
		"2": {"name": "Pressure Valves", "effects": [["attacks_per_second", "increased", 0.03]]},
		"3": {"name": "Hot Loop", "code": "HOT", "effects": [["attacks_per_second", "increased", 0.08]]},
		"f1": {"name": "Repair Nanites", "effects": [["health_regen", "flat", 0.005]]},
		"f2": {"name": "Coolant Recycler", "code": "RCY", "effects": [["health_regen", "flat", 0.01]]},
		"k": {"name": "Fusion Heart", "code": "FSN", "effects": [["attacks_per_second", "increased", 0.10]]},
	},
	"drill": {
		"1": {"name": "Sharpened Teeth", "effects": [["mining_bonus", "flat", 0.02]]},
		"2": {"name": "Torque Gearing", "effects": [["mining_bonus", "flat", 0.02]]},
		"3": {"name": "Diamond Bit", "code": "DMD", "effects": [["mining_bonus", "flat", 0.05]]},
		"f1": {"name": "Heat Shielding", "effects": [["resistance.fire", "flat", 0.05]]},
		"f2": {"name": "Hazmat Seals", "code": "HAZ", "effects": [["resistance.toxin", "flat", 0.10]]},
		"k": {"name": "Deep Core Tap", "code": "DCT", "effects": [["mining_bonus", "flat", 0.08]]},
	},
	"salvage": {
		"1": {"name": "Sensor Sweep", "effects": [["drop_bonus", "flat", 0.02]]},
		"2": {"name": "Loot Scanner", "effects": [["drop_bonus", "flat", 0.02]]},
		"3": {"name": "Magnet Sweep", "code": "MAG", "effects": [["drop_bonus", "flat", 0.05]]},
		"f1": {"name": "Cutting Torch", "effects": [["scrap_yield", "increased", 0.10]]},
		"f2": {"name": "Recycler Rig", "code": "RIG", "effects": [["scrap_yield", "increased", 0.20]]},
		"k": {"name": "Scavenger Protocol", "code": "SCV", "effects": [["drop_bonus", "flat", 0.08]]},
	},
	"mobility": {
		"1": {"name": "Greased Joints", "effects": [["move_speed", "increased", 0.03]]},
		"2": {"name": "Servo Upgrade", "effects": [["move_speed", "increased", 0.03]]},
		"3": {"name": "Servo Overdrive", "code": "SRV", "effects": [["move_speed", "increased", 0.06]]},
		"f1": {"name": "Grounding Strap", "effects": [["resistance.shock", "flat", 0.05]]},
		"f2": {"name": "Faraday Shell", "code": "FAR", "effects": [["resistance.shock", "flat", 0.10]]},
		"k": {"name": "Afterburner Legs", "code": "AFT", "effects": [["move_speed", "increased", 0.08]]},
	},
	"armor": {
		"1": {"name": "Bolted Plates", "effects": [["max_health", "flat", 10.0]]},
		"2": {"name": "Welded Seams", "effects": [["max_health", "flat", 10.0]]},
		"3": {"name": "Reinforced Chassis", "code": "RNF", "effects": [["max_health", "increased", 0.08]]},
		"f1": {"name": "Composite Layer", "effects": [["armor", "flat", 5.0]]},
		"f2": {"name": "Ablative Plating", "code": "ABL", "effects": [["armor", "flat", 12.0]]},
		"k": {"name": "Bastion Frame", "code": "BST", "effects": [["max_health", "increased", 0.15], ["armor", "flat", 10.0]]},
	},
}

## How each stat reads in the UI. `percent`: flat values are fractions shown
## as percentages (0.05 -> +5%).
const STAT_LABELS := {
	"attack_damage": {"label": "attack damage", "percent": false},
	"attacks_per_second": {"label": "attack speed", "percent": false},
	"projectile_speed": {"label": "projectile speed", "percent": false},
	"max_health": {"label": "max health", "percent": false},
	"armor": {"label": "armor", "percent": false},
	"move_speed": {"label": "move speed", "percent": false},
	"health_regen": {"label": "health regen per second", "percent": true},
	"mining_bonus": {"label": "drill output", "percent": true},
	"drop_bonus": {"label": "item find", "percent": true},
	"scrap_yield": {"label": "salvage scrap", "percent": false},
	"resistance.fire": {"label": "fire resistance", "percent": true},
	"resistance.shock": {"label": "shock resistance", "percent": true},
	"resistance.toxin": {"label": "toxin resistance", "percent": true},
}

static var _nodes: Dictionary = {}
static var _order: Array[String] = []

## Every node by id (built once from BRANCHES x BRANCH_TEMPLATE).
static func nodes() -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _nodes

## Node ids in branch order (stable, for drawing and tests).
static func node_ids() -> Array[String]:
	if _nodes.is_empty():
		_build()
	return _order

static func has_skill(node_id: String) -> bool:
	return nodes().has(node_id)

static func node_def(node_id: String) -> Dictionary:
	return nodes().get(node_id, {})

static func get_branch(branch_id: String) -> Dictionary:
	for branch in BRANCHES:
		if branch.id == branch_id:
			return branch
	return {}

static func mech_type(mech_id: String = DEFAULT_MECH_TYPE) -> Dictionary:
	return MECH_TYPES.get(mech_id, MECH_TYPES[DEFAULT_MECH_TYPE])

static func _build() -> void:
	_nodes = {}
	_order = []
	for branch in BRANCHES:
		var content: Dictionary = NODE_CONTENT[branch.id]
		var spots: Dictionary = ART_POSITIONS[branch.id]
		for shape in BRANCH_TEMPLATE:
			var node_id := "%s_%s" % [branch.id, shape.key]
			var parent_id := CORE_ID if str(shape.parent).is_empty() else "%s_%s" % [branch.id, shape.parent]
			var info: Dictionary = content[shape.key]
			var effects: Array[Dictionary] = []
			for effect in info.effects:
				effects.append({"stat": str(effect[0]), "operation": str(effect[1]), "value": float(effect[2])})
			var spot: Vector2 = spots[shape.key]
			var position: Vector2 = spot - ART_CORE
			_nodes[node_id] = {
				"id": node_id,
				"branch": str(branch.id),
				"name": str(info.name),
				"code": str(info.get("code", "")),
				"tier": str(shape.tier),
				"parent": parent_id,
				"cost": int(shape.cost),
				"effects": effects,
				"position": position,
			}
			_order.append(node_id)

## The board position of a node id (the core is at the origin).
static func position_of(node_id: String) -> Vector2:
	if node_id == CORE_ID:
		return Vector2.ZERO
	return node_def(node_id).get("position", Vector2.ZERO)

## Where a branch's first trace leaves the core (board units).
static func core_exit_of(branch_id: String) -> Vector2:
	return ART_CORE_EXITS.get(branch_id, ART_CORE) - ART_CORE

## Where a branch's "n/6" count is printed (board units, text baseline).
static func count_position_of(branch_id: String) -> Vector2:
	return ART_COUNT_POSITIONS.get(branch_id, ART_CORE) - ART_CORE

static func is_powered(unlocked: Dictionary, node_id: String) -> bool:
	return node_id == CORE_ID or unlocked.has(node_id)

## "" when the node can be powered now, otherwise why not.
static func unlock_blocker(unlocked: Dictionary, scrap: int, node_id: String) -> String:
	if not has_skill(node_id):
		return "Unknown node."
	if unlocked.has(node_id):
		return "Already powered."
	var node := node_def(node_id)
	if not is_powered(unlocked, str(node.parent)):
		return "Power the node before it first."
	if scrap < int(node.cost):
		return "Needs %d Scrap." % int(node.cost)
	return ""

static func can_unlock(unlocked: Dictionary, scrap: int, node_id: String) -> bool:
	return unlock_blocker(unlocked, scrap, node_id).is_empty()

## Locked but its parent is powered: the next nodes the player can reach.
static func is_reachable(unlocked: Dictionary, node_id: String) -> bool:
	return has_skill(node_id) and not unlocked.has(node_id) and is_powered(unlocked, str(node_def(node_id).parent))

## Scrap paid for all powered nodes (what a full refund gives back).
static func spent_scrap(unlocked: Dictionary) -> int:
	var total := 0
	for node_id in unlocked.keys():
		if has_skill(str(node_id)):
			total += int(node_def(str(node_id)).cost)
	return total

static func total_cost() -> int:
	var total := 0
	for node_id in node_ids():
		total += int(node_def(node_id).cost)
	return total

## Drops ids that are unknown or cut off from the core (their parent isn't
## powered), so a hand-edited or older save can't leave floating nodes.
static func sanitize(unlocked: Dictionary) -> Dictionary:
	var clean := {}
	var changed := true
	while changed:
		changed = false
		for node_id in unlocked.keys():
			var id := str(node_id)
			if clean.has(id) or not has_skill(id):
				continue
			if is_powered(clean, str(node_def(id).parent)):
				clean[id] = true
				changed = true
	return clean

## Sum of every powered node's effects as {"<stat>_<operation>": value}, the
## same keys HeroStatResolver totals equipment into. Not applied in combat yet.
static func stat_totals(unlocked: Dictionary) -> Dictionary:
	var totals := {}
	for node_id in node_ids():
		if not unlocked.has(node_id):
			continue
		for effect in node_def(node_id).effects:
			var key := "%s_%s" % [effect.stat, effect.operation]
			totals[key] = float(totals.get(key, 0.0)) + float(effect.value)
	return totals

## One effect as UI text, e.g. "+4% attack damage" or "+10 max health".
static func describe_effect(effect: Dictionary) -> String:
	var stat := str(effect.get("stat", ""))
	var value := float(effect.get("value", 0.0))
	var info: Dictionary = STAT_LABELS.get(stat, {"label": stat, "percent": false})
	if str(effect.get("operation", "")) == "increased" or bool(info.percent):
		return "+%s%% %s" % [_trim(value * 100.0), info.label]
	return "+%s %s" % [_trim(value), info.label]

## A summed total (see stat_totals) as UI text.
static func describe_total(key: String, value: float) -> String:
	var split := key.rfind("_")
	return describe_effect({"stat": key.substr(0, split), "operation": key.substr(split + 1), "value": value})

static func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.1f" % value).trim_suffix("0").trim_suffix(".")
