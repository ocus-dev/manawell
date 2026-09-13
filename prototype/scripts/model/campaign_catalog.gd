class_name CampaignCatalog
extends RefCounted

const CampaignDefinitionsScript = preload("res://data/campaign_definitions.gd")

var acts: Dictionary = {}
var act_order: Array[String] = []
var validation_error: String = ""

func _init() -> void:
	for act in CampaignDefinitionsScript.ACTS:
		var act_copy: Dictionary = act.duplicate(true)
		var act_id: String = str(act_copy.get("id", ""))
		if acts.has(act_id):
			validation_error = "duplicate act ID: %s" % act_id
		else:
			acts[act_id] = act_copy
			act_order.append(act_id)
	for act_id in act_order:
		var result := validate_act(acts[act_id])
		if not result["valid"]:
			validation_error = result["error"]
			break

func is_valid() -> bool:
	return validation_error.is_empty()

func has_act(act_id: String) -> bool:
	return acts.has(act_id)

func get_act(act_id: String) -> Dictionary:
	return acts.get(act_id, {}).duplicate(true)

func first_act_id() -> String:
	return act_order[0] if not act_order.is_empty() else ""

func next_act_id(act_id: String) -> String:
	var index := act_order.find(act_id)
	return act_order[index + 1] if index >= 0 and index + 1 < act_order.size() else ""

func get_node(act_id: String, node_id: String) -> Dictionary:
	var act: Dictionary = acts.get(act_id, {})
	for node: Dictionary in act.get("nodes", []):
		if node.get("id", "") == node_id:
			return node.duplicate(true)
	return {}

func node_ids(act_id: String) -> Array[String]:
	var result: Array[String] = []
	for node: Dictionary in acts.get(act_id, {}).get("nodes", []):
		result.append(str(node.get("id", "")))
	return result

static func validate_act(act: Dictionary) -> Dictionary:
	for field in ["id", "nodes"]:
		if not act.has(field):
			return {"valid": false, "error": "act missing %s" % field}
	if not act["id"] is String or str(act["id"]).is_empty() or not act["nodes"] is Array:
		return {"valid": false, "error": "act identity or nodes are invalid"}
	var ids: Dictionary = {}
	var well_count := 0
	var monster_count := 0
	var boss_count := 0
	for node: Dictionary in act["nodes"]:
		if not node is Dictionary:
			return {"valid": false, "error": "node must be an object"}
		for field in ["id", "type", "position", "prerequisites", "encounter_key"]:
			if not node.has(field):
				return {"valid": false, "error": "node missing %s" % field}
		var node_id := str(node["id"])
		if node_id.is_empty() or ids.has(node_id):
			return {"valid": false, "error": "node IDs must be unique and non-empty"}
		ids[node_id] = true
		if not ["monster", "well", "boss"].has(node["type"]):
			return {"valid": false, "error": "node type is invalid"}
		if not node["position"] is Array or node["position"].size() != 2 or not _normalized(node["position"][0]) or not _normalized(node["position"][1]):
			return {"valid": false, "error": "node position must be normalized"}
		if not node["prerequisites"] is Array or not node["encounter_key"] is String or str(node["encounter_key"]).is_empty():
			return {"valid": false, "error": "node prerequisites or encounter key is invalid"}
		for prerequisite in node["prerequisites"]:
			if not prerequisite is String:
				return {"valid": false, "error": "prerequisite IDs must be strings"}
		if node["type"] == "well":
			well_count += 1
			if not node.has("well_id") or not node["well_id"] is String or str(node["well_id"]).is_empty():
				return {"valid": false, "error": "well node needs a well ID"}
		elif node["type"] == "monster":
			monster_count += 1
		else:
			boss_count += 1
	if act["nodes"].size() != 9 or well_count != 3 or monster_count != 5 or boss_count != 1:
		return {"valid": false, "error": "act must contain 9 nodes: 3 wells, 5 monsters, 1 boss"}
	var boss: Dictionary = {}
	for node: Dictionary in act["nodes"]:
		for prerequisite in node["prerequisites"]:
			if not ids.has(prerequisite):
				return {"valid": false, "error": "missing prerequisite reference: %s" % prerequisite}
		if node["type"] == "boss":
			boss = node
	if boss.is_empty() or boss["prerequisites"].size() != 8:
		return {"valid": false, "error": "boss must require all eight previous nodes"}
	for prerequisite in boss["prerequisites"]:
		if not ids.has(prerequisite) or prerequisite == boss["id"]:
			return {"valid": false, "error": "boss prerequisite is invalid"}
	if _has_cycle(act["nodes"], ids):
		return {"valid": false, "error": "act prerequisites contain a cycle"}
	var reachable: Dictionary = {}
	var frontier: Array[String] = []
	for node: Dictionary in act["nodes"]:
		if node["prerequisites"].is_empty():
			frontier.append(node["id"])
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		if reachable.has(current):
			continue
		reachable[current] = true
		for node in act["nodes"]:
			if current in node["prerequisites"]:
				frontier.append(node["id"])
	if reachable.size() != ids.size():
		return {"valid": false, "error": "act contains disconnected nodes"}
	return {"valid": true}

static func _has_cycle(nodes: Array, ids: Dictionary) -> bool:
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for node in nodes:
		if _visit(str(node["id"]), nodes, visiting, visited):
			return true
	return false

static func _visit(node_id: String, nodes: Array, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(node_id):
		return true
	if visited.has(node_id):
		return false
	visiting[node_id] = true
	for node in nodes:
		if str(node["id"]) == node_id:
			for prerequisite in node["prerequisites"]:
				if _visit(str(prerequisite), nodes, visiting, visited):
					return true
			break
	visiting.erase(node_id)
	visited[node_id] = true
	return false

static func _normalized(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1.0
