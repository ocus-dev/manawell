class_name CampaignMap
extends Control

const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const CampaignCatalogScript = preload("res://scripts/model/campaign_catalog.gd")

signal node_selected(act_id: String, node_id: String)
signal node_activate(act_id: String, node_id: String)
signal manage_well_requested(well_id: String)

var map_rect := Rect2(16.0, 56.0, 760.0, 500.0)
const PANEL_WIDTH := 300.0
const HIT_RADIUS := 22.0
const NODE_RADIUS := 14.0

var view_state: Dictionary = {}
var map_texture: Texture2D
var catalog: RefCounted = CampaignCatalogScript.new()
var selected_node_id: String = ""
var focus_index: int = 0
var node_buttons: Array[Dictionary] = []
var image_rect := Rect2()
var details: PanelContainer
var details_content: VBoxContainer
var detail_title: Label
var detail_status: Label
var detail_reason: Label
var detail_well: Label
var activate_button: Button
var map_title: Label
var map_subtitle: Label
var manage_button: Button

func _ready() -> void:
	theme = IndustrialThemeScript.create()
	var image := Image.load_from_file("res://assets/world_map/master.png")
	if image != null and not image.is_empty():
		map_texture = ImageTexture.create_from_image(image)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_update_transform()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_transform()
		queue_redraw()

func configure(next_state: Dictionary) -> void:
	view_state = next_state.duplicate(true)
	var campaign: Dictionary = view_state.get("campaign", {})
	var act_id: String = str(campaign.get("active_act_id", catalog.first_act_id()))
	var nodes: Array = campaign.get("nodes", [])
	if nodes.is_empty() and catalog.has_act(act_id):
		nodes = catalog.get_act(act_id).get("nodes", [])
	if selected_node_id.is_empty() or _find_node(nodes, selected_node_id).is_empty():
		selected_node_id = str(nodes[0].get("id", "")) if not nodes.is_empty() else ""
	focus_index = clampi(focus_index, 0, maxi(0, nodes.size() - 1))
	_refresh_details()
	queue_redraw()

func refresh(next_state: Dictionary) -> void:
	configure(next_state)

func map_content_rect() -> Rect2:
	return image_rect

func normalized_to_map(position: Vector2) -> Vector2:
	return image_rect.position + Vector2(position.x * image_rect.size.x, position.y * image_rect.size.y)

func select_node(node_id: String) -> bool:
	var campaign: Dictionary = view_state.get("campaign", {})
	var node: Dictionary = _find_node(campaign.get("nodes", []), node_id)
	if node.is_empty():
		return false
	selected_node_id = node_id
	for index in campaign.get("nodes", []).size():
		if str(campaign["nodes"][index].get("id", "")) == node_id:
			focus_index = index
	_refresh_details()
	queue_redraw()
	node_selected.emit(str(campaign.get("act_id", "act_01")), node_id)
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local: Vector2 = event.position
		for item in node_buttons:
			if local.distance_to(item["position"]) <= HIT_RADIUS:
				select_node(item["id"])
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and item["status"] != "locked":
					node_activate.emit(item["act_id"], item["id"])
				accept_event()
				return
	if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN:
				_move_focus(1)
				accept_event()
			elif event.keycode == KEY_LEFT or event.keycode == KEY_UP:
				_move_focus(-1)
				accept_event()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				if not selected_node_id.is_empty():
					node_activate.emit(str(view_state.get("campaign", {}).get("act_id", "act_01")), selected_node_id)
				accept_event()

func _move_focus(delta: int) -> void:
	var nodes: Array = view_state.get("campaign", {}).get("nodes", [])
	if nodes.is_empty():
		return
	focus_index = posmod(focus_index + delta, nodes.size())
	select_node(str(nodes[focus_index].get("id", "")))
	grab_focus()

func _build() -> void:
	map_title = Label.new()
	map_title.position = Vector2(18, 10)
	map_title.add_theme_font_size_override("font_size", 22)
	add_child(map_title)
	map_subtitle = Label.new()
	map_subtitle.position = Vector2(20, 36)
	map_subtitle.add_theme_font_size_override("font_size", 13)
	map_subtitle.add_theme_color_override("font_color", Color("a8b7b8"))
	add_child(map_subtitle)
	details = PanelContainer.new()
	details.name = "SelectedLevelPanel"
	details.add_theme_stylebox_override("panel", _panel_style())
	add_child(details)
	details_content = VBoxContainer.new()
	details_content.add_theme_constant_override("separation", 7)
	details.add_child(details_content)
	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 18)
	details_content.add_child(detail_title)
	detail_status = Label.new()
	details_content.add_child(detail_status)
	detail_reason = Label.new()
	detail_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_content.add_child(detail_reason)
	detail_well = Label.new()
	detail_well.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_content.add_child(detail_well)
	activate_button = Button.new()
	activate_button.text = "START / REVISIT"
	activate_button.tooltip_text = "Encounter routing arrives in M06."
	activate_button.disabled = true
	activate_button.focus_mode = Control.FOCUS_NONE
	activate_button.pressed.connect(func(): node_activate.emit(str(view_state.get("campaign", {}).get("act_id", "act_01")), selected_node_id))
	details_content.add_child(activate_button)

func _update_transform() -> void:
	var available := size - Vector2(PANEL_WIDTH + 44.0, 78.0)
	var map_size := Vector2(maxf(420.0, available.x), maxf(360.0, available.y))
	if size.x < 920.0:
		map_size = Vector2(maxf(360.0, size.x - 32.0), maxf(320.0, size.y * 0.58))
	map_rect.position = Vector2(16.0, 56.0)
	map_rect.size = map_size
	var texture_size := Vector2(2048.0, 1152.0)
	if map_texture != null:
		texture_size = Vector2(map_texture.get_width(), map_texture.get_height())
	var scale := minf(map_rect.size.x / texture_size.x, map_rect.size.y / texture_size.y)
	var contained := texture_size * scale
	image_rect = Rect2(map_rect.position + (map_rect.size - contained) * 0.5, contained)
	if details != null:
		if size.x >= 920.0:
			details.position = Vector2(map_rect.end.x + 12.0, map_rect.position.y)
			details.size = Vector2(PANEL_WIDTH, minf(260.0, map_rect.size.y))
		else:
			details.position = Vector2(16.0, map_rect.end.y + 10.0)
			details.size = Vector2(maxf(320.0, size.x - 32.0), 210.0)

func _refresh_details() -> void:
	if details_content == null:
		return
	if manage_button == null:
		manage_button = Button.new()
		manage_button.text = "Manage well ↓"
		manage_button.pressed.connect(func():
			var selected := _find_node(view_state.get("campaign", {}).get("nodes", []), selected_node_id)
			if selected.get("type", "") == "well":
				manage_well_requested.emit(str(selected.get("well_id", ""))))
		details_content.add_child(manage_button)
	var campaign: Dictionary = view_state.get("campaign", {})
	var node: Dictionary = _find_node(campaign.get("nodes", []), selected_node_id)
	manage_button.visible = node.get("type", "") == "well"
	if node.is_empty():
		detail_title.text = ""
		detail_status.text = ""
		detail_reason.text = ""
		detail_well.text = ""
		activate_button.disabled = true
		return
	var status: Dictionary = campaign.get("statuses", {}).get(selected_node_id, {"status": "locked", "reason": "No campaign state."})
	var status_id: String = str(status.get("status", "locked"))
	var type_label: String = str(node.get("type", "level")).to_upper()
	detail_title.text = "%s  /  %s" % [str(node.get("display_name", selected_node_id)), type_label]
	detail_status.text = "STATUS  %s" % status_id.to_upper()
	detail_reason.text = str(status.get("reason", ""))
	detail_well.text = ""
	if node.get("type", "") == "well":
		var well: Dictionary = campaign.get("wells", {}).get(str(node.get("well_id", "")), {})
		detail_well.text = "Well: %s\nRate: %.1f/hour  Guard: %s" % [str(well.get("indicator", "idle")).to_upper(), float(well.get("rate_per_minute", 0.0)) * 60.0, str(well.get("guard_label", "Unstaffed"))]
	activate_button.disabled = status_id == "locked"
	activate_button.text = "START / REVISIT"

func _draw() -> void:
	draw_rect(map_rect, Color("10161b"), true)
	if map_texture != null:
		draw_texture_rect(map_texture, image_rect, false)
	node_buttons.clear()
	var campaign: Dictionary = view_state.get("campaign", {})
	var nodes: Array = campaign.get("nodes", [])
	var paths: Array = campaign.get("paths", [])
	for path in paths:
		var points: PackedVector2Array = PackedVector2Array()
		for point in path.get("points", []):
			points.append(normalized_to_map(Vector2(float(point[0]), float(point[1]))))
		if points.size() > 1:
			draw_polyline(points, Color("d8b34b", 0.70), 3.0, true)
	for node in nodes:
		var position := normalized_to_map(Vector2(float(node["position"][0]), float(node["position"][1])))
		var status: Dictionary = campaign.get("statuses", {}).get(str(node["id"]), {})
		var status_id := str(status.get("status", "locked"))
		var color := Color("d8b34b") if status_id == "available" else Color("66d9c4") if status_id == "completed" else Color("88939a")
		if node["type"] == "boss":
			draw_circle(position, NODE_RADIUS + 4.0, Color("d86b5c", 0.35))
			draw_arc(position, NODE_RADIUS + 7.0, 0.0, TAU, 24, color, 3.0)
		else:
			draw_circle(position, NODE_RADIUS, Color("182027"))
			draw_arc(position, NODE_RADIUS, 0.0, TAU, 20, color, 3.0)
		if node["type"] == "well":
			draw_circle(position, 5.0, Color("66d9c4") if bool(campaign.get("wells", {}).get(str(node.get("well_id", "")), {}).get("commissioned", false)) else Color("d8b34b"))
		elif node["type"] == "boss":
			draw_string(ThemeDB.fallback_font, position + Vector2(-5, 6), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		else:
			draw_string(ThemeDB.fallback_font, position + Vector2(-5, 6), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		if status_id == "completed":
			draw_string(ThemeDB.fallback_font, position + Vector2(11, -9), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f1eee4"))
		elif status_id == "locked":
			draw_string(ThemeDB.fallback_font, position + Vector2(10, 5), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f1eee4"))
		var status_color := Color("d8b34b") if status_id == "available" else Color("66d9c4") if status_id == "completed" else Color("a8b7b8")
		draw_string(ThemeDB.fallback_font, position + Vector2(20, 4), status_id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, status_color)
		if str(node["id"]) == selected_node_id:
			draw_arc(position, NODE_RADIUS + 9.0, 0.0, TAU, 24, Color("8ed9df"), 3.0)
		node_buttons.append({"id": str(node["id"]), "act_id": str(campaign.get("act_id", "act_01")), "position": position, "status": status_id})

func _find_node(nodes: Array, node_id: String) -> Dictionary:
	for node in nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182027", 0.96)
	style.border_color = Color("596a72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	return style
