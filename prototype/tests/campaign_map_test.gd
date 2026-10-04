extends SceneTree

const CampaignMapScript = preload("res://scripts/ui/campaign_map.gd")
const UiViewStateScript = preload("res://scripts/ui/ui_view_state.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")
const CampaignStateScript = preload("res://scripts/model/campaign_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var map: Control = CampaignMapScript.new()
	get_root().add_child(map)
	var account: RefCounted = AccountStateScript.new()
	var run_state: RefCounted = RunStateScript.new()
	var campaign_state: RefCounted = CampaignStateScript.new()
	var view_state: Dictionary = UiViewStateScript.build(account, run_state, "well_1", {}, {}, campaign_state)
	map.size = Vector2(1280.0, 720.0)
	map.configure(view_state)
	var first: Vector2 = map.normalized_to_map(Vector2(0.1, 0.79))
	assert(map.map_content_rect().has_point(first))
	# The start of the path (bottom-left) is the tutorial, the first level.
	await process_frame
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = first
	map._gui_input(click)
	assert(map.selected_node_id == "act_01_node_02", "the first spot on the map is Sector B (Tutorial)")
	assert(map.select_node("act_01_node_01"))
	assert(map.selected_node_id == "act_01_node_01")
	assert(map.details_content.get_child_count() == 7)
	assert(map.detail_progress.text.begins_with("To progress: reach surge"), "card shows how to progress")
	map.configure(view_state)
	assert(map.details_content.get_child_count() == 7)
	map.size = Vector2(1920.0, 1080.0)
	map.configure(view_state)
	assert(map.map_content_rect().has_point(map.normalized_to_map(Vector2(0.74, 0.18))))
	map.size = Vector2(720.0, 540.0)
	map.configure(view_state)
	assert(map.map_content_rect().has_point(map.normalized_to_map(Vector2(0.68, 0.36))))
	var selection_result: bool = map.select_node("act_01_node_08")
	assert(selection_result)
	assert(map.selected_node_id == "act_01_node_08")
	map.queue_free()
	print("Campaign map checks passed")
	quit(0)
