class_name CampaignState
extends RefCounted

const RunStateScript = preload("res://scripts/model/run_state.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")

const STATUS_LOCKED := "locked"
const STATUS_AVAILABLE := "available"
const STATUS_COMPLETED := "completed"

var completed_nodes: Dictionary = {}
var unlocked_acts: Dictionary = {}
var active_act_id: String = ""
var active_node_id: String = ""
var committed_terminal_ids: Dictionary = {}
var all_levels_enabled := false

func _init() -> void:
	var catalog: RefCounted = CampaignCatalogScript.new()
	if not catalog.first_act_id().is_empty():
		unlocked_acts[catalog.first_act_id()] = true

func to_save_payload() -> Dictionary:
	var completed: Array[String] = []
	for key in completed_nodes.keys():
		completed.append(str(key))
	completed.sort()
	var acts: Array[String] = []
	for key in unlocked_acts.keys():
		acts.append(str(key))
	acts.sort()
	var commits: Array[String] = []
	for key in committed_terminal_ids.keys():
		commits.append(str(key))
	commits.sort()
	return {"completed_nodes": completed, "unlocked_acts": acts, "active_act_id": active_act_id, "active_node_id": active_node_id, "committed_terminal_ids": commits}

static func validate_save_payload(payload: Dictionary, catalog: RefCounted = null) -> Dictionary:
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	if not definitions.is_valid():
		return {"valid": false, "error": definitions.validation_error}
	for field in ["completed_nodes", "unlocked_acts", "committed_terminal_ids"]:
		if payload.has(field) and not payload[field] is Array:
			return {"valid": false, "error": "%s must be an array" % field}
	for key in payload.get("completed_nodes", []):
		if not key is String or not _valid_node_key(str(key), definitions):
			return {"valid": false, "error": "completed node identity is invalid"}
	for act_id in payload.get("unlocked_acts", []):
		if not act_id is String or not definitions.has_act(act_id):
			return {"valid": false, "error": "unlocked act identity is invalid"}
	for run_id in payload.get("committed_terminal_ids", []):
		if not run_id is String or run_id.is_empty():
			return {"valid": false, "error": "terminal commit identity is invalid"}
	for field in ["active_act_id", "active_node_id"]:
		if payload.has(field) and not payload[field] is String:
			return {"valid": false, "error": "%s must be a string" % field}
	var active_act := str(payload.get("active_act_id", ""))
	var active_node := str(payload.get("active_node_id", ""))
	if (active_act.is_empty()) != (active_node.is_empty()) or (not active_act.is_empty() and (not definitions.has_act(active_act) or definitions.get_node(active_act, active_node).is_empty())):
		return {"valid": false, "error": "active campaign node identity is invalid"}
	return {"valid": true}

func from_save_payload(payload: Dictionary, catalog: RefCounted = null) -> bool:
	var validation := validate_save_payload(payload, catalog)
	if not validation["valid"]:
		return false
	completed_nodes.clear()
	for key in payload.get("completed_nodes", []):
		completed_nodes[key] = true
	unlocked_acts.clear()
	for act_id in payload.get("unlocked_acts", []):
		unlocked_acts[act_id] = true
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	if unlocked_acts.is_empty() and not definitions.first_act_id().is_empty():
		unlocked_acts[definitions.first_act_id()] = true
	active_act_id = str(payload.get("active_act_id", ""))
	active_node_id = str(payload.get("active_node_id", ""))
	committed_terminal_ids.clear()
	for run_id in payload.get("committed_terminal_ids", []):
		committed_terminal_ids[run_id] = true
	return true

func start_node(act_id: String, node_id: String, catalog: RefCounted = null) -> bool:
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	if node_status(act_id, node_id, definitions)["status"] == STATUS_LOCKED:
		return false
	active_act_id = act_id
	active_node_id = node_id
	return true

func clear_active_node() -> void:
	active_act_id = ""
	active_node_id = ""

func node_status(act_id: String, node_id: String, catalog: RefCounted = null) -> Dictionary:
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	var node: Dictionary = definitions.get_node(act_id, node_id)
	if node.is_empty() or not unlocked_acts.has(act_id):
		return {"status": STATUS_LOCKED, "reason": "Act or level is not authored."}
	if all_levels_enabled:
		return {"status": STATUS_AVAILABLE, "reason": "Development level access enabled."}
	var key := _node_key(act_id, node_id)
	if completed_nodes.has(key):
		return {"status": STATUS_COMPLETED, "reason": "Completed levels remain revisitable."}
	for prerequisite in node.get("prerequisites", []):
		if not completed_nodes.has(_node_key(act_id, str(prerequisite))):
			return {"status": STATUS_LOCKED, "reason": "Requires %s." % str(prerequisite)}
	return {"status": STATUS_AVAILABLE, "reason": "Ready to launch."}

## Returns the campaign node that should drive the Operations briefing.
## Nodes are authored in progression order. An explicitly active node wins;
## otherwise use the first available node after the furthest completed node.
func furthest_progression_node(catalog: RefCounted = null) -> Dictionary:
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	var act_id: String = active_act_id if not active_act_id.is_empty() and definitions.has_act(active_act_id) else definitions.first_act_id()
	if act_id.is_empty():
		return {}
	var act: Dictionary = definitions.get_act(act_id)
	var nodes: Array = act.get("nodes", [])
	if nodes.is_empty():
		return {}
	if not active_node_id.is_empty():
		var active_node: Dictionary = definitions.get_node(act_id, active_node_id)
		if not active_node.is_empty() and node_status(act_id, active_node_id, definitions)["status"] != STATUS_LOCKED:
			return active_node
	var furthest_completed_index := -1
	for index in nodes.size():
		var node_id := str(nodes[index].get("id", ""))
		if node_status(act_id, node_id, definitions)["status"] == STATUS_COMPLETED:
			furthest_completed_index = index
	for index in range(furthest_completed_index + 1, nodes.size()):
		var candidate_id := str(nodes[index].get("id", ""))
		if node_status(act_id, candidate_id, definitions)["status"] == STATUS_AVAILABLE:
			return nodes[index].duplicate(true)
	if furthest_completed_index >= 0:
		return nodes[furthest_completed_index].duplicate(true)
	for node in nodes:
		if node_status(act_id, str(node.get("id", "")), definitions)["status"] == STATUS_AVAILABLE:
			return node.duplicate(true)
	return nodes[0].duplicate(true)

func well_status(well_id: String, account: RefCounted, active_well_id: String = "") -> Dictionary:
	var commissioned: bool = account.is_well_commissioned(well_id)
	var guard_id: String = account.get_guard_for_well(well_id)
	var active: bool = active_well_id == well_id
	var guarded: bool = not guard_id.is_empty()
	var producing: bool = commissioned and guarded and not active
	return {"commissioned": commissioned, "guarded": guarded, "producing": producing, "active": active, "idle": commissioned and not guarded and not active, "guard_id": guard_id}

func commit_terminal_result(result: Dictionary, account: RefCounted, catalog: RefCounted = null) -> bool:
	var definitions: RefCounted = CampaignCatalogScript.new() if catalog == null else catalog
	if result.get("phase", -1) != RunStateScript.Phase.SUCCESS or active_act_id.is_empty() or active_node_id.is_empty():
		return false
	var run_id: String = str(result.get("run_id", ""))
	if run_id.is_empty() or committed_terminal_ids.has(run_id) or not definitions.has_act(active_act_id):
		return false
	var node: Dictionary = definitions.get_node(active_act_id, active_node_id)
	if node.is_empty() or node_status(active_act_id, active_node_id, definitions)["status"] == STATUS_LOCKED:
		return false
	var well_id: String = str(node.get("well_id", ""))
	var surge_count: int = int(result.get("completed_surges", 0))
	if node["type"] == "well" and surge_count < 1:
		return false
	if not account.complete_campaign_run(result, run_id, active_node_id, node.get("level_data", {}), well_id, surge_count):
		return false
	if node["type"] == "well" and not account.is_well_commissioned(well_id):
		return false
	completed_nodes[_node_key(active_act_id, active_node_id)] = true
	committed_terminal_ids[run_id] = true
	if node["type"] == "boss":
		var next_act: String = definitions.next_act_id(active_act_id)
		if not next_act.is_empty():
			unlocked_acts[next_act] = true
	clear_active_node()
	return true

static func _node_key(act_id: String, node_id: String) -> String:
	return "%s/%s" % [act_id, node_id]

static func _valid_node_key(key: String, catalog: RefCounted) -> bool:
	var separator := key.find("/")
	return separator > 0 and not catalog.get_node(key.substr(0, separator), key.substr(separator + 1)).is_empty()
