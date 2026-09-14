extends Control

const OPERATIONS_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const HERO_ONE: Texture2D = preload("res://assets/portraits/hero_1.png")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const ContentCatalogScript = preload("res://scripts/model/content_catalog.gd")

var account: RefCounted
var store: RefCounted
var catalog: RefCounted = ContentCatalogScript.new()
var selected_hero_id := ""
var roster_expanded := true
var roster_buttons: Dictionary = {}

@onready var hero_art: TextureRect = $HeroStage/HeroArt
@onready var fallback_art: Control = $HeroStage/FallbackArt
@onready var hero_name: Label = $HeroStage/Identity/HeroName
@onready var hero_status: Label = $HeroStage/Identity/HeroStatus
@onready var roster_panel: PanelContainer = $RosterPanel
@onready var roster_content: VBoxContainer = $RosterPanel/RosterMargin/RosterContent
@onready var roster_grid: GridContainer = $RosterPanel/RosterMargin/RosterContent/RosterScroll/RosterGrid
@onready var collapse_button: Button = $RosterPanel/RosterMargin/RosterContent/RosterHeader/Collapse

func _ready() -> void:
	store = SaveStoreScript.new()
	account = store.load_account()
	selected_hero_id = account.get_active_hero_id()
	if selected_hero_id.is_empty():
		selected_hero_id = "hero_1"
	_build_roster()
	_show_hero(selected_hero_id)
	$RosterPanel/RosterMargin/RosterContent/RosterHeader/Collapse.pressed.connect(toggle_roster)
	$CollapsedHandle.pressed.connect(toggle_roster)
	$RosterPanel/RosterMargin/RosterContent/Operations.pressed.connect(_open_operations)
	$BackButton.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE)
		get_viewport().set_input_as_handled()

func toggle_roster() -> void:
	roster_expanded = not roster_expanded
	var target_width := 360.0 if roster_expanded else 76.0
	roster_content.visible = roster_expanded
	$CollapsedHandle.visible = not roster_expanded
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(roster_panel, "offset_left", -target_width, 0.2)

func _build_roster() -> void:
	for child in roster_grid.get_children():
		child.queue_free()
	roster_buttons.clear()
	var owned_ids: Array[String] = []
	for hero_id in account.roster_heroes.keys():
		owned_ids.append(str(hero_id))
	owned_ids.sort()
	for hero_id in owned_ids:
		var button := Button.new()
		button.name = "Hero_%s" % hero_id
		button.custom_minimum_size = Vector2(142, 142)
		button.tooltip_text = _hero_label(hero_id)
		button.toggle_mode = true
		button.pressed.connect(_select_hero.bind(hero_id))
		var portrait := TextureRect.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture = _portrait_for(hero_id)
		button.add_child(portrait)
		if portrait.texture == null:
			button.text = _initials(_hero_label(hero_id))
			button.add_theme_font_size_override("font_size", 28)
		roster_grid.add_child(button)
		roster_buttons[hero_id] = button
	var future_slot := Button.new()
	future_slot.name = "FutureHeroSlot"
	future_slot.custom_minimum_size = Vector2(142, 142)
	future_slot.text = "+"
	future_slot.disabled = true
	future_slot.tooltip_text = "Additional heroes can join the roster here later."
	future_slot.add_theme_font_size_override("font_size", 42)
	roster_grid.add_child(future_slot)

func _select_hero(hero_id: String) -> void:
	if not account.select_active_hero(hero_id):
		return
	selected_hero_id = hero_id
	_save_selection()
	_show_hero(hero_id)

func _show_hero(hero_id: String) -> void:
	var portrait := _portrait_for(hero_id)
	hero_art.texture = portrait
	hero_art.visible = portrait != null
	fallback_art.visible = portrait == null
	$HeroStage/FallbackArt/Initials.text = _initials(_hero_label(hero_id))
	hero_name.text = _hero_label(hero_id).to_upper()
	hero_status.text = "ACTIVE HERO  ·  READY FOR DEPLOYMENT"
	for id in roster_buttons.keys():
		var button: Button = roster_buttons[id]
		button.button_pressed = id == hero_id

func _save_selection() -> void:
	store.save_envelope({
		"account": account,
		"production_utc_timestamp": store.loaded_production_utc_timestamp,
		"snapshot": store.loaded_snapshot,
		"campaign_state": store.loaded_campaign_state,
	})

func _open_operations() -> void:
	get_tree().change_scene_to_file(OPERATIONS_SCENE)

func _portrait_for(hero_id: String) -> Texture2D:
	return HERO_ONE if hero_id == "hero_1" else null

func _hero_label(hero_id: String) -> String:
	return str(catalog.get_hero(hero_id).get("label", hero_id))

func _initials(label: String) -> String:
	var words := label.split(" ", false)
	return (words[0].left(1) + words[1].left(1)).to_upper() if words.size() > 1 else label.left(2).to_upper()
