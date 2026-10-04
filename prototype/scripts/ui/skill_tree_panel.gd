class_name SkillTreePanel
extends Control

## Full-screen skill tree overlay opened from the Home command center: the
## circuit board on the left (SkillTreeBoard) and a side card on the right
## showing the selected node, its cost and an Unlock button, plus the totals
## of everything powered. Click a node to select it; double-click (or Unlock)
## to power it. Changes go straight to the account and `changed` is emitted so
## Home can save.

signal changed
signal closed

const SkillTreeScript = preload("res://scripts/model/skill_tree.gd")
const SkillTreeBoardScript = preload("res://scripts/ui/skill_tree_board.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")

const TIER_NAMES := {"minor": "Solder pad", "notable": "Chip", "keystone": "Keystone chip"}
const REFUND_CONFIRM_SECONDS: float = 3.0

var account: RefCounted
var board: Control
var scrap_label: Label
var name_label: Label
var meta_label: Label
var effects_label: Label
var cost_label: Label
var status_label: Label
var unlock_button: Button
var progress_label: Label
var totals_label: Label
var refund_button: Button
var close_button: Button
var notice_label: Label
var refund_armed_until: float = -1.0
var clock: float = 0.0

func _ready() -> void:
	name = "SkillTreePanel"
	theme = IndustrialThemeScript.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()

## The account whose skill nodes and Scrap the panel shows and changes.
func setup(new_account: RefCounted) -> void:
	account = new_account
	if is_node_ready():
		_refresh()

func _process(delta: float) -> void:
	clock += delta
	if refund_armed_until > 0.0 and clock > refund_armed_until:
		refund_armed_until = -1.0
		_refresh()

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 20.0
	frame.offset_top = 20.0
	frame.offset_right = -20.0
	frame.offset_bottom = -20.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("0d1215")
	frame_style.border_color = Color("3e6a70")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(6)
	frame_style.set_content_margin_all(12)
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)
	board = SkillTreeBoardScript.new()
	board.name = "Board"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.node_selected.connect(_on_node_selected)
	board.node_activated.connect(unlock)
	row.add_child(board)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	side.add_child(_label("SKILL TREE", 24, Color("8ed9df")))
	side.add_child(_label("Mech core: %s" % SkillTreeScript.mech_type().name, 13, Color("b9c3c7")))
	scrap_label = _label("", 16, Color("f0c06a"))
	scrap_label.name = "Scrap"
	side.add_child(scrap_label)
	side.add_child(HSeparator.new())
	name_label = _label("", 20, Color("f1eee4"))
	name_label.name = "NodeName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(name_label)
	meta_label = _label("", 12, Color("8c939d"))
	side.add_child(meta_label)
	effects_label = _label("", 15, Color("bff6ff"))
	effects_label.name = "Effects"
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(effects_label)
	cost_label = _label("", 14, Color("f0c06a"))
	side.add_child(cost_label)
	status_label = _label("", 13, Color("e6a07a"))
	status_label.name = "Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status_label)
	unlock_button = Button.new()
	unlock_button.name = "Unlock"
	unlock_button.focus_mode = Control.FOCUS_NONE
	unlock_button.pressed.connect(func() -> void: unlock(board.selected_id))
	side.add_child(unlock_button)
	side.add_child(HSeparator.new())
	progress_label = _label("", 14, Color("f1eee4"))
	progress_label.name = "Progress"
	side.add_child(progress_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	totals_label = _label("", 13, Color("b9c3c7"))
	totals_label.name = "Totals"
	totals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	totals_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(totals_label)
	notice_label = _label("", 12, Color("e6a07a"))
	notice_label.name = "Notice"
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(notice_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	side.add_child(buttons)
	refund_button = Button.new()
	refund_button.name = "Refund"
	refund_button.focus_mode = Control.FOCUS_NONE
	refund_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refund_button.pressed.connect(_on_refund_pressed)
	buttons.add_child(refund_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "Close (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	buttons.add_child(close_button)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _unlocked() -> Dictionary:
	return account.skill_nodes if account != null else {}

func _scrap() -> int:
	return int(account.scrap) if account != null else 0

## Powers a node if the account can pay for it. Returns true when it did.
func unlock(node_id: String) -> bool:
	if account == null or node_id.is_empty() or node_id == SkillTreeScript.CORE_ID:
		return false
	if not account.unlock_skill_node(node_id):
		_refresh()
		return false
	refund_armed_until = -1.0
	changed.emit()
	_refresh()
	return true

## Refund needs two clicks within a few seconds so it isn't hit by accident.
func _on_refund_pressed() -> void:
	if refund_armed_until < 0.0:
		refund_armed_until = clock + REFUND_CONFIRM_SECONDS
		_refresh()
		return
	refund_all()

func refund_all() -> int:
	refund_armed_until = -1.0
	if account == null or account.skill_nodes.is_empty():
		_refresh()
		return 0
	var refund: int = account.refund_skill_nodes()
	changed.emit()
	_refresh()
	return refund

func close() -> void:
	refund_armed_until = -1.0
	visible = false
	closed.emit()

func open() -> void:
	visible = true
	if board.selected_id.is_empty():
		board.select(SkillTreeScript.CORE_ID)
	_refresh()

## Shown under the totals (e.g. a save that didn't go through).
func set_notice(text: String) -> void:
	if notice_label != null:
		notice_label.text = text

func _on_node_selected(_node_id: String) -> void:
	refund_armed_until = -1.0
	_refresh()

func _refresh() -> void:
	if board == null:
		return
	var unlocked := _unlocked()
	var scrap := _scrap()
	board.set_state(unlocked, scrap)
	scrap_label.text = "Scrap: %d" % scrap
	var selected: String = board.selected_id
	if selected.is_empty() or selected == SkillTreeScript.CORE_ID:
		_show_core()
	else:
		_show_node(selected, unlocked, scrap)
	var total := SkillTreeScript.node_ids().size()
	progress_label.text = "Powered: %d / %d nodes" % [unlocked.size(), total]
	var totals := SkillTreeScript.stat_totals(unlocked)
	var lines: Array[String] = []
	var keys: Array = totals.keys()
	keys.sort()
	for key in keys:
		lines.append("• " + SkillTreeScript.describe_total(str(key), float(totals[key])))
	totals_label.text = "No nodes powered yet." if lines.is_empty() else "\n".join(lines)
	var spent := SkillTreeScript.spent_scrap(unlocked)
	refund_button.disabled = unlocked.is_empty()
	refund_button.text = ("Confirm refund (+%d)" % spent) if refund_armed_until > 0.0 else "Refund all"

func _show_core() -> void:
	var mech: Dictionary = SkillTreeScript.mech_type()
	name_label.text = str(mech.name)
	meta_label.text = "Mech core · always powered"
	effects_label.text = "The heart of the board. Power flows out from here along six branches."
	cost_label.text = ""
	status_label.text = "Click a node to inspect it. Double-click or press Unlock to power it with Scrap."
	unlock_button.visible = false

func _show_node(node_id: String, unlocked: Dictionary, scrap: int) -> void:
	var node: Dictionary = SkillTreeScript.node_def(node_id)
	var branch: Dictionary = SkillTreeScript.get_branch(str(node.branch))
	name_label.text = str(node.name)
	meta_label.text = "%s · %s" % [str(branch.get("name", "")).capitalize(), TIER_NAMES.get(str(node.tier), "")]
	var effect_lines: Array[String] = []
	for effect in node.effects:
		effect_lines.append(SkillTreeScript.describe_effect(effect))
	effects_label.text = "\n".join(effect_lines)
	cost_label.text = "Cost: %d Scrap" % int(node.cost)
	unlock_button.visible = true
	if unlocked.has(node_id):
		status_label.text = "Powered."
		unlock_button.text = "Powered"
		unlock_button.disabled = true
		return
	var blocker := SkillTreeScript.unlock_blocker(unlocked, scrap, node_id)
	status_label.text = blocker
	unlock_button.text = "Unlock (%d Scrap)" % int(node.cost)
	unlock_button.disabled = not blocker.is_empty()
