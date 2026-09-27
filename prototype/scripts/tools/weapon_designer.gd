class_name WeaponDesigner
extends Control

const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const LootRegistration = preload("res://scripts/model/weapon_loot_registration.gd")
const TestProfile = preload("res://scripts/tools/weapon_test_profile.gd")
const PlacementEditor = preload("res://scripts/tools/weapon_placement_editor.gd")
const GameplayScene: PackedScene = preload("res://scenes/main.tscn")
const ThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const SOURCE_FOLDER_RELATIVE := "art/ui-items/Weapons"

var draft: Dictionary = {}
var fields := {}
var affixes: Array[Dictionary] = []
var validation_label: Label
var job_label: Label
var preview_label: RichTextLabel
var preview_icon: TextureRect
var preview_world: TextureRect
var preview_visual_status: Label
var draft_list: ItemList
var job_list: ItemList
var published_list: ItemList
var published_icon: TextureRect
var published_world: TextureRect
var published_detail: RichTextLabel
var published_status: Label
var test_profile_status: Label
var loot_registration_status: Label
var loot_enabled: CheckButton
var loot_weight: SpinBox
var loot_min_level: SpinBox
var loot_max_level: SpinBox
var loot_registration_weapon_id := ""
var loot_registration_dirty := false
var loading_loot_registration := false
var test_profile: RefCounted
var playtest_controller: Node
var playtest_return_layer: CanvasLayer
var placement_editor: Control
var designer_tabs: TabContainer
var source_path: OptionButton
var description_edit: TextEdit
var add_button: Button
var job_poll_timer: Timer

func _ready() -> void:
	theme = ThemeScript.create()
	draft = Store.default_draft("draft.new_weapon")
	test_profile = TestProfile.new()
	_build()
	_apply_draft_to_controls()
	job_poll_timer = Timer.new()
	job_poll_timer.wait_time = 1.0
	job_poll_timer.timeout.connect(_poll_job_status)
	add_child(job_poll_timer)
	job_poll_timer.start()
	_refresh()

func _build() -> void:
	var tabs := TabContainer.new()
	designer_tabs = tabs
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)
	var page := MarginContainer.new()
	page.name = "Authoring"
	for edge in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + edge, 16)
	tabs.add_child(page)
	tabs.set_tab_title(0, "AUTHOR")
	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 12)
	page.add_child(workspace)
	var toolbar := HBoxContainer.new()
	toolbar.name = "AuthoringToolbar"
	toolbar.add_theme_constant_override("separation", 8)
	workspace.add_child(toolbar)
	var title := _heading("WEAPON AUTHORING", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	var save := Button.new()
	save.text = "Save draft"
	save.pressed.connect(_save_draft)
	toolbar.add_child(save)
	var prepare := Button.new()
	prepare.text = "Prepare art"
	prepare.pressed.connect(_start_job)
	toolbar.add_child(prepare)
	add_button = Button.new()
	add_button.text = "Add to game"
	add_button.disabled = true
	add_button.pressed.connect(_publish)
	toolbar.add_child(add_button)
	var body := HSplitContainer.new()
	body.name = "AuthoringBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 760
	workspace.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var editor := GridContainer.new()
	editor.name = "EditorGrid"
	editor.columns = 2
	editor.add_theme_constant_override("h_separation", 12)
	editor.add_theme_constant_override("v_separation", 12)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(editor)
	var identity := _section("SOURCE & IDENTITY")
	editor.add_child(identity)
	identity.add_child(_label("SOURCE IMAGE"))
	source_path = OptionButton.new()
	identity.add_child(source_path)
	_populate_source_options()
	source_path.item_selected.connect(func(index: int):
		draft.art.source = str(source_path.get_item_metadata(index))
		_refresh())
	var crop_grid := GridContainer.new()
	crop_grid.columns = 4
	crop_grid.add_theme_constant_override("h_separation", 8)
	identity.add_child(crop_grid)
	_compact_spin(crop_grid, "X", "crop_x", 0, 10000, 1)
	_compact_spin(crop_grid, "Y", "crop_y", 0, 10000, 1)
	_compact_spin(crop_grid, "W", "crop_w", 0, 10000, 1)
	_compact_spin(crop_grid, "H", "crop_h", 0, 10000, 1)
	_line(identity, "Weapon ID", "weapon_id")
	_line(identity, "Weapon name", "label")
	description_edit = TextEdit.new()
	description_edit.placeholder_text = "Plain-text description"
	description_edit.custom_minimum_size.y = 64
	description_edit.text_changed.connect(func(): draft.description = description_edit.text; _refresh())
	identity.add_child(_label("DESCRIPTION"))
	identity.add_child(description_edit)
	_option(identity, "Supported behavior", "behavior_id", Catalog.SUPPORTED_BEHAVIOR_IDS)
	var tuning := _section("COMBAT & ITEM")
	editor.add_child(tuning)
	_stat_control(tuning, "attack_damage", "Attack damage", "flat", 0.0)
	_stat_control(tuning, "attacks_per_second", "Attacks / sec", "increased", 0.0)
	_stat_control(tuning, "projectile_speed", "Projectile speed", "increased", 0.0)
	_option(tuning, "Rarity", "rarity", ["common", "magic", "rare", "epic"])
	_spin(tuning, "Item level", "item_level", 1, 99, 1)
	tuning.add_child(_heading("EXPLICIT AFFIXES", 13))
	for index in range(3):
		_affix_control(tuning, index)
	var placement := _section("PLACEMENT")
	editor.add_child(placement)
	_spin(placement, "Grip X", "grip_x", 0.0, 1.0, 0.01)
	_spin(placement, "Grip Y", "grip_y", 0.0, 1.0, 0.01)
	_spin(placement, "World scale", "world_scale", 0.1, 4.0, 0.05)
	_option(placement, "Facing", "facing", ["right", "left"])
	var status := _section("VALIDATION")
	editor.add_child(status)
	validation_label = _label("")
	status.add_child(validation_label)
	var side := VBoxContainer.new()
	side.name = "PreviewSidebar"
	side.custom_minimum_size.x = 390
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	side.add_child(_heading("PREVIEW", 20))
	var visual_row := HBoxContainer.new()
	visual_row.add_theme_constant_override("separation", 8)
	side.add_child(visual_row)
	preview_icon = _preview_image("ICON")
	preview_world = _preview_image("WORLD SPRITE")
	visual_row.add_child(preview_icon)
	visual_row.add_child(preview_world)
	preview_visual_status = _label("Prepare art to generate a visual preview.", 11)
	preview_visual_status.modulate = Color("9ab0bc")
	side.add_child(preview_visual_status)
	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.custom_minimum_size.y = 150
	side.add_child(preview_label)
	var library_tabs := TabContainer.new()
	library_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(library_tabs)
	var drafts_page := VBoxContainer.new()
	drafts_page.name = "Drafts"
	library_tabs.add_child(drafts_page)
	draft_list = ItemList.new()
	draft_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drafts_page.add_child(draft_list)
	var reopen := Button.new()
	reopen.text = "Reopen selected draft"
	reopen.pressed.connect(_reopen_draft)
	drafts_page.add_child(reopen)
	var jobs_page := VBoxContainer.new()
	jobs_page.name = "Jobs"
	library_tabs.add_child(jobs_page)
	job_list = ItemList.new()
	job_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jobs_page.add_child(job_list)
	var resume := Button.new()
	resume.text = "Resume selected job"
	resume.pressed.connect(_resume_job)
	jobs_page.add_child(resume)
	job_label = _label("No running job selected.")
	job_label.custom_minimum_size.y = 42
	jobs_page.add_child(job_label)
	_build_published_tab(tabs)

func _build_published_tab(tabs: TabContainer) -> void:
	var page := MarginContainer.new()
	page.name = "PublishedItems"
	for edge in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + edge, 18)
	tabs.add_child(page)
	tabs.set_tab_title(1, "PUBLISHED ITEMS")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	page.add_child(columns)
	var list_column := VBoxContainer.new()
	list_column.custom_minimum_size.x = 300
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(list_column)
	list_column.add_child(_heading("IN-GAME CATALOG", 20))
	list_column.add_child(_label("Published weapons available to the game.", 12))
	published_list = ItemList.new()
	published_list.name = "PublishedWeaponList"
	published_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	published_list.item_selected.connect(_select_published_weapon)
	list_column.add_child(published_list)
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size.x = 420
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_column)
	detail_column.add_child(_heading("ITEM DETAILS", 20))
	var visual_row := HBoxContainer.new()
	visual_row.add_theme_constant_override("separation", 8)
	detail_column.add_child(visual_row)
	published_icon = _preview_image("PUBLISHED ICON")
	published_world = _preview_image("PUBLISHED WORLD SPRITE")
	visual_row.add_child(published_icon)
	visual_row.add_child(published_world)
	published_status = _label("Select a published item.", 11)
	published_status.modulate = Color("9ab0bc")
	detail_column.add_child(published_status)
	published_detail = RichTextLabel.new()
	published_detail.bbcode_enabled = true
	published_detail.fit_content = false
	published_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	published_detail.custom_minimum_size.y = 150
	detail_column.add_child(published_detail)
	detail_column.add_child(_heading("PRODUCTION LOOT REGISTRATION", 13))
	loot_enabled = CheckButton.new()
	loot_enabled.name = "EnableFoundryLoot"
	loot_enabled.text = "Enable in foundry_physical_v1"
	loot_enabled.toggled.connect(func(_enabled: bool): _mark_loot_registration_dirty())
	detail_column.add_child(loot_enabled)
	var registration_fields := HBoxContainer.new()
	registration_fields.add_theme_constant_override("separation", 8)
	detail_column.add_child(registration_fields)
	loot_weight = _registration_spin(1.0, 0.1, 1000.0, 0.1, "Loot weight")
	loot_weight.value_changed.connect(func(_value: float): _mark_loot_registration_dirty())
	registration_fields.add_child(_registration_field("Weight", loot_weight))
	loot_min_level = _registration_spin(1.0, 1.0, 3.0, 1.0, "Eligible item level min")
	loot_min_level.value_changed.connect(func(_value: float): _mark_loot_registration_dirty())
	registration_fields.add_child(_registration_field("Min level", loot_min_level))
	loot_max_level = _registration_spin(3.0, 1.0, 3.0, 1.0, "Eligible item level max")
	loot_max_level.value_changed.connect(func(_value: float): _mark_loot_registration_dirty())
	registration_fields.add_child(_registration_field("Max level", loot_max_level))
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_column.add_child(action_row)
	var save_registration := Button.new()
	save_registration.name = "SaveLootRegistration"
	save_registration.text = "Save Loot Registration"
	save_registration.tooltip_text = "Persists the explicit opt-in loot registration without touching the player save."
	save_registration.pressed.connect(_save_loot_registration)
	save_registration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(save_registration)
	loot_registration_status = _label("Publication alone does not enable drops.", 11)
	loot_registration_status.modulate = Color("9ab0bc")
	detail_column.add_child(loot_registration_status)
	var acquire := Button.new()
	acquire.name = "AcquireTestWeapon"
	acquire.text = "Acquire in test profile"
	acquire.tooltip_text = "Creates a disposable instance without changing the player's save."
	acquire.pressed.connect(_acquire_selected_for_test)
	acquire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(acquire)
	var playtest := Button.new()
	playtest.name = "PlaytestSelectedWeapon"
	playtest.text = "Playtest selected weapon"
	playtest.tooltip_text = "Launches a disposable encounter with this weapon equipped; the live save is never opened or changed."
	playtest.pressed.connect(_launch_selected_playtest)
	playtest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(playtest)
	test_profile_status = _label("Test acquisitions are isolated from the player profile.", 11)
	test_profile_status.modulate = Color("9ab0bc")
	detail_column.add_child(test_profile_status)

func _refresh() -> void:
	if validation_label == null:
		return
	var result := Store.validate_authored(draft)
	validation_label.text = "VALID" if result.valid else _diagnostic_text(result)
	validation_label.add_theme_color_override("font_color", Color("75d5a5") if result.valid else Color("f09a9a"))
	preview_label.text = _preview_text()
	_refresh_visual_preview()
	_refresh_published_items()
	draft_list.clear()
	for draft_id in Store.list_drafts():
		draft_list.add_item(draft_id)
	job_list.clear()
	for job_id in Store.list_job_receipts():
		job_list.add_item(job_id)
	_update_job_indicator()
	if add_button != null:
		add_button.disabled = not _preparation_complete(str(draft.get("art", {}).get("job_id", "")))

func _poll_job_status() -> void:
	_refresh()

func _update_job_indicator() -> void:
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if job_id.is_empty():
		job_label.text = "No preparation job selected."
		return
	var manifest := _load_preparation_manifest(job_id)
	if not manifest.is_empty():
		var status := str(manifest.get("status", "unknown"))
		var progress := _manifest_progress(manifest)
		var failure := str(manifest.get("error", ""))
		job_label.text = "Job %s: %s, %.0f%%%s" % [job_id, status, progress * 100.0, "\nError: " + failure if not failure.is_empty() else ""]
		return
	var receipt := Store.load_job_receipt(job_id)
	job_label.text = "Job %s: %s" % [job_id, receipt.get("status", "unknown")]

func _manifest_progress(manifest: Dictionary) -> float:
	if str(manifest.get("status", "")) == "complete":
		return 1.0
	var stages: Dictionary = manifest.get("stages", {})
	var progress := 0.0
	for stage in ["snapshot", "cutout", "prepare", "review"]:
		if str(stages.get(stage, {}).get("status", "")) == "complete":
			progress = {"snapshot": 0.15, "cutout": 0.45, "prepare": 0.75, "review": 1.0}[stage]
	return progress

func _preparation_complete(job_id: String) -> bool:
	if job_id.is_empty():
		return false
	var manifest := _load_preparation_manifest(job_id)
	return str(manifest.get("status", "")) == "complete"

func _load_preparation_manifest(job_id: String) -> Dictionary:
	if job_id.is_empty() or job_id.contains("/") or job_id.contains("\\") or job_id.contains(".."):
		return {}
	var path := ProjectSettings.globalize_path("res://../art/weapons/runs/%s/manifest.json" % job_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}

func _preview_text() -> String:
	var instance := {"instance_id": "designer-preview", "base_id": "core.heavy_breech", "rarity": "common", "item_level": int(draft.get("item_level", 1)), "implicit_modifiers": draft.get("base_modifiers", []).duplicate(true), "explicit_modifiers": draft.get("explicit_modifiers", []).duplicate(true)}
	var resolved := Resolver.resolve({}, {"designer-preview": instance}, {"weapon": "designer-preview"})
	return "[b]%s[/b]\n%s\n\nAttack: %.2f\nAttacks / sec: %.2f\nProjectile speed: %.2f\n\nIcon: %s\nEquipped-stat preview uses HeroStatResolver." % [draft.get("label", "New weapon"), draft.get("description", ""), resolved.stats.attack_damage, resolved.stats.attacks_per_second, resolved.stats.projectile_speed, str(draft.get("art", {}).get("icon", "prepared icon pending"))]

func _preview_image(caption: String) -> TextureRect:
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(148, 116)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.tooltip_text = caption
	return image

func _refresh_visual_preview() -> void:
	if preview_icon == null:
		return
	var icon_path := ""
	var world_path := ""
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if not job_id.is_empty():
		var run_root := ProjectSettings.globalize_path("res://../art/weapons/runs/%s" % job_id)
		if FileAccess.file_exists(run_root.path_join("square-icon.png")):
			icon_path = run_root.path_join("square-icon.png")
		if FileAccess.file_exists(run_root.path_join("world-sprite.png")):
			world_path = run_root.path_join("world-sprite.png")
	if icon_path.is_empty() or world_path.is_empty():
		var published := _published_assets(str(draft.get("weapon_id", "")))
		if icon_path.is_empty():
			icon_path = str(published.get("icon", ""))
		if world_path.is_empty():
			world_path = str(published.get("world_sprite", ""))
	preview_icon.texture = _load_preview_texture(icon_path)
	preview_world.texture = _load_preview_texture(world_path)
	var has_visual := preview_icon.texture != null or preview_world.texture != null
	preview_visual_status.text = "Prepared art preview" if has_visual else "Prepare art to generate a visual preview."

func _published_assets(weapon_id: String) -> Dictionary:
	return _published_entry(weapon_id).get("assets", {})

func _published_index() -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://data/weapons/index.json"), FileAccess.READ)
	if file == null:
		return {}
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}

func _published_entry(weapon_id: String) -> Dictionary:
	if weapon_id.is_empty():
		return {}
	var index := _published_index()
	return index.get("weapons", {}).get(weapon_id, {})

func _refresh_published_items() -> void:
	if published_list == null:
		return
	var selected_id := ""
	if not published_list.get_selected_items().is_empty():
		selected_id = str(published_list.get_item_metadata(published_list.get_selected_items()[0]))
	published_list.clear()
	var weapons: Dictionary = _published_index().get("weapons", {})
	var ids: Array[String] = []
	for weapon_id in weapons:
		ids.append(str(weapon_id))
	ids.sort()
	for weapon_id in ids:
		var entry: Dictionary = weapons[weapon_id]
		var index := published_list.item_count
		published_list.add_item("%s  ·  r%d" % [str(entry.get("label", weapon_id)), int(entry.get("revision", 0))])
		published_list.set_item_metadata(index, weapon_id)
	if ids.is_empty():
		published_status.text = "No published weapons yet. Use AUTHOR to add one to the game."
		published_icon.texture = null
		published_world.texture = null
		published_detail.text = ""
		return
	var selected_index := ids.find(selected_id)
	selected_index = 0 if selected_index < 0 else selected_index
	published_list.select(selected_index)
	_select_published_weapon(selected_index)

func _select_published_weapon(index: int) -> void:
	if published_list == null or index < 0 or index >= published_list.item_count:
		return
	var weapon_id := str(published_list.get_item_metadata(index))
	var entry := _published_entry(weapon_id)
	var assets: Dictionary = entry.get("assets", {})
	published_icon.texture = _load_preview_texture(str(assets.get("icon", "")))
	published_world.texture = _load_preview_texture(str(assets.get("world_sprite", "")))
	published_status.text = "Published item · %s · revision %d" % [weapon_id, int(entry.get("revision", 0))]
	var lines: Array[String] = ["[b]%s[/b]" % str(entry.get("label", weapon_id)), str(entry.get("description", "")), "", "ID: %s" % weapon_id, "Revision: %d" % int(entry.get("revision", 0)), "Behavior: %s" % str(entry.get("behavior_id", ""))]
	for modifier in entry.get("base_modifiers", []):
		lines.append("Base: %s %s" % [str(modifier.get("stat", "")), _format_modifier_value(modifier)])
	var pivot: Dictionary = entry.get("pivot", {})
	lines.append("Grip: %.2f, %.2f · Facing: %s" % [float(pivot.get("grip", [0.5, 0.75])[0]), float(pivot.get("grip", [0.5, 0.75])[1]), str(pivot.get("facing", "right"))])
	published_detail.text = "\n".join(lines)
	# The job poll rebuilds this list every second. Preserve an in-progress edit when
	# that refresh re-selects the same weapon instead of restoring the disk value.
	if weapon_id != loot_registration_weapon_id or not loot_registration_dirty:
		_load_loot_registration(weapon_id)

func _load_loot_registration(weapon_id: String) -> void:
	var registration := LootRegistration.registration_for(weapon_id)
	loading_loot_registration = true
	loot_enabled.button_pressed = bool(registration.get("enabled", false))
	loot_weight.value = float(registration.get("weight", 1.0))
	loot_min_level.value = float(registration.get("min_item_level", 1))
	loot_max_level.value = float(registration.get("max_item_level", 3))
	loading_loot_registration = false
	loot_registration_weapon_id = weapon_id
	loot_registration_dirty = false
	loot_registration_status.text = "Drops ENABLED · weight %.1f · levels %d-%d" % [loot_weight.value, int(loot_min_level.value), int(loot_max_level.value)] if loot_enabled.button_pressed else "Publication alone does not enable drops."
	loot_registration_status.modulate = Color("75d5a5") if loot_enabled.button_pressed else Color("9ab0bc")

func _mark_loot_registration_dirty() -> void:
	if loading_loot_registration or loot_registration_weapon_id.is_empty():
		return
	loot_registration_dirty = true
	loot_registration_status.text = "Unsaved loot registration changes."
	loot_registration_status.modulate = Color("e5bd73")

func _registration_spin(value: float, minimum: float, maximum: float, step: float, label_text: String) -> SpinBox:
	var spin := _spin_box(value, minimum, maximum, step)
	spin.name = label_text.replace(" ", "")
	spin.tooltip_text = label_text
	return spin

func _registration_field(label_text: String, control: Control) -> Control:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(control)
	return field

func _spin_box(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin

func _save_loot_registration() -> void:
	var weapon_id := _playtest_weapon_id()
	if weapon_id.is_empty():
		loot_registration_status.text = "Select a published weapon first."
		return
	var result := LootRegistration.update_weapon(weapon_id, _published_entry(weapon_id), loot_enabled.button_pressed, float(loot_weight.value), int(loot_min_level.value), int(loot_max_level.value))
	if not result.get("valid", false):
		loot_registration_status.text = "Registration rejected: %s" % str(result.get("error", "invalid registration"))
		loot_registration_status.modulate = Color("f09a9a")
		return
	loot_registration_weapon_id = weapon_id
	loot_registration_dirty = false
	loot_registration_status.text = "Registration saved · %s · revision %d" % ["enabled" if loot_enabled.button_pressed else "disabled", int(result.document.get("registration_revision", 0))]
	loot_registration_status.modulate = Color("75d5a5")

func _acquire_selected_for_test() -> void:
	if published_list == null or published_list.get_selected_items().is_empty():
		test_profile_status.text = "Select a published weapon first."
		return
	var index := published_list.get_selected_items()[0]
	var weapon_id := str(published_list.get_item_metadata(index))
	var result: Dictionary = test_profile.acquire(weapon_id)
	if not result.get("valid", false):
		test_profile_status.text = "Test acquisition failed: %s" % str(result.get("error", "unknown error"))
		test_profile_status.add_theme_color_override("font_color", Color("f09a9a"))
		return
	test_profile_status.text = "Test profile acquired %s\n%s" % [weapon_id, str(result.get("instance_id", ""))]
	test_profile_status.add_theme_color_override("font_color", Color("75d5a5"))

func _launch_selected_playtest() -> void:
	if published_list == null or published_list.get_selected_items().is_empty():
		test_profile_status.text = "Select a published weapon first."
		return
	if is_instance_valid(playtest_controller):
		test_profile_status.text = "Close the current playtest before launching another."
		return
	var index := published_list.get_selected_items()[0]
	var weapon_id := str(published_list.get_item_metadata(index))
	test_profile = TestProfile.new()
	var result: Dictionary = test_profile.acquire_and_equip(weapon_id)
	if not result.get("valid", false):
		test_profile_status.text = "Playtest setup failed: %s" % str(result.get("error", "unknown error"))
		test_profile_status.add_theme_color_override("font_color", Color("f09a9a"))
		return
	var controller: Node = GameplayScene.instantiate()
	controller.name = "WeaponPlaytest"
	controller.set("persistence_enabled", false)
	controller.set("account_state", test_profile.account)
	designer_tabs.visible = false
	add_child(controller)
	playtest_controller = controller
	if not bool(controller.call("start_run")):
		_close_playtest()
		test_profile_status.text = "Playtest could not start."
		test_profile_status.add_theme_color_override("font_color", Color("f09a9a"))
		return
	var return_layer := CanvasLayer.new()
	return_layer.name = "PlaytestReturnLayer"
	return_layer.layer = 100
	var close_button := Button.new()
	close_button.name = "ClosePlaytest"
	close_button.text = "Close playtest"
	close_button.tooltip_text = "Return to the weapon designer."
	close_button.position = Vector2(18.0, 18.0)
	close_button.pressed.connect(_close_playtest)
	return_layer.add_child(close_button)
	add_child(return_layer)
	playtest_return_layer = return_layer
	placement_editor = PlacementEditor.new()
	placement_editor.name = "WeaponPlacementEditor"
	placement_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placement_editor.save_requested.connect(_save_playtest_placement)
	return_layer.add_child(placement_editor)
	placement_editor.configure(controller, weapon_id, _published_entry(weapon_id))
	test_profile_status.text = "Playtesting %s in an isolated profile." % weapon_id
	test_profile_status.add_theme_color_override("font_color", Color("75d5a5"))

func _close_playtest() -> void:
	if is_instance_valid(playtest_controller):
		playtest_controller.queue_free()
	playtest_controller = null
	if is_instance_valid(playtest_return_layer):
		playtest_return_layer.queue_free()
	playtest_return_layer = null
	if designer_tabs != null:
		designer_tabs.visible = true
	test_profile = TestProfile.new()
	placement_editor = null

func _save_playtest_placement(pivot: Dictionary) -> void:
	if not is_instance_valid(playtest_controller) or not is_instance_valid(placement_editor):
		return
	var weapon_id := _playtest_weapon_id()
	var result: Dictionary = Publisher.publish_placement_revision(weapon_id, pivot)
	if not result.get("valid", false):
		placement_editor.set_status("Placement rejected: %s" % str(result.get("error", "invalid placement")), true)
		return
	var refreshed_profile: RefCounted = TestProfile.new()
	var acquisition: Dictionary = refreshed_profile.acquire_and_equip(weapon_id)
	if not acquisition.get("valid", false):
		placement_editor.set_status("Saved revision, but isolated reload failed: %s" % str(acquisition.get("error", "unknown error")), true)
		return
	test_profile = refreshed_profile
	playtest_controller.set("account_state", test_profile.account)
	playtest_controller.call("_configure_weapon_loadout", "hero_1")
	placement_editor.set_placement(result.get("revision", {}))
	placement_editor.set_status("Saved immutable revision %d; playtest reloaded it." % int(result.get("revision", {}).get("revision", 0)))
	_refresh()

func _playtest_weapon_id() -> String:
	if published_list != null and not published_list.get_selected_items().is_empty():
		return str(published_list.get_item_metadata(published_list.get_selected_items()[0]))
	return ""

func _format_modifier_value(modifier: Dictionary) -> String:
	var value := float(modifier.get("value", 0.0))
	return "+%.2f" % value

func _load_preview_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var file_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(file_path):
		return null
	var image := Image.load_from_file(file_path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null

func _save_draft() -> void:
	_sync_art()
	var result := Store.save_draft(draft)
	validation_label.text = "Draft saved." if result.valid else _diagnostic_text(result)
	_refresh()

func _reopen_draft() -> void:
	if draft_list.get_selected_items().is_empty():
		return
	var reopened := Store.load_draft(draft_list.get_item_text(draft_list.get_selected_items()[0]))
	if reopened.is_empty():
		return
	draft = reopened
	_apply_draft_to_controls()
	validation_label.text = "Draft reopened."
	_refresh()

func _start_job() -> void:
	_sync_art()
	var job_id := "job_%s" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var source := _selected_source()
	if source.is_empty():
		job_label.text = "Select a PNG source image before preparing art."
		return
	var receipt := {"job_id": job_id, "draft_id": draft.draft_id, "status": "starting", "stage": "snapshot", "progress": 0.0, "failure": "", "source": source, "created_at": Time.get_datetime_string_from_system(true)}
	draft.art.job_id = job_id
	if not Store.save_job_receipt(receipt).valid:
		job_label.text = "Could not save the job receipt."
		return
	var runner := ProjectSettings.globalize_path("res://../weapon.ps1")
	if not FileAccess.file_exists(runner):
		receipt.status = "blocked"
		receipt.failure = "weapon.ps1 is unavailable; the saved receipt can be resumed after the service is restored."
		Store.save_job_receipt(receipt)
		job_label.text = receipt.failure
		_refresh()
		return
	var process_args := PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", runner, "start", "--job-id", job_id, "--source", source, "--root", ProjectSettings.globalize_path("res://../art/weapons/runs")])
	var cutout_mode := _cutout_mode_for_source(source)
	process_args.append("--cutout")
	process_args.append(cutout_mode)
	if cutout_mode == "comfy":
		var comfy_url := _asset_pipeline_comfy_url()
		if comfy_url.is_empty():
			receipt.status = "blocked"
			receipt.failure = "Opaque source requires ComfyUI cutout, but tools/asset_pipeline/config.json has no concept_url."
			Store.save_job_receipt(receipt)
			job_label.text = receipt.failure
			_refresh()
			return
		process_args.append("--comfy-url")
		process_args.append(comfy_url)
	var process_id := OS.create_process("powershell", process_args)
	receipt.status = "running" if process_id > 0 else "blocked"
	receipt.failure = "" if process_id > 0 else "worker could not be launched"
	Store.save_job_receipt(receipt)
	job_label.text = "Job %s: %s using %s cutout. The editor remains responsive; reopen to resume." % [job_id, receipt.status, "ComfyUI" if cutout_mode == "comfy" else "existing alpha"]
	_refresh()

func _cutout_mode_for_source(source: String) -> String:
	var path := ProjectSettings.globalize_path("res://../" + source)
	if not FileAccess.file_exists(path):
		return "comfy"
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return "comfy"
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.999:
				return "transparent"
	return "comfy"

func _asset_pipeline_comfy_url() -> String:
	var path := ProjectSettings.globalize_path("res://../tools/asset_pipeline/config.json")
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return str(value.get("concept_url", "")) if value is Dictionary else ""

func _publish() -> void:
	_sync_art()
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if not _preparation_complete(job_id):
		validation_label.text = "A completed preparation job is required before publication."
		return
	var result := Publisher.publish(draft, ProjectSettings.globalize_path("res://../art/weapons/runs"), job_id)
	validation_label.text = "Published %s." % draft.get("weapon_id", "weapon") if result.valid and result.get("committed", false) else ("Already published." if result.valid else _diagnostic_text(result))
	_refresh()

func _resume_job() -> void:
	if job_list.get_selected_items().is_empty():
		return
	var job_id := job_list.get_item_text(job_list.get_selected_items()[0])
	var receipt := Store.load_job_receipt(job_id)
	var runner := ProjectSettings.globalize_path("res://../weapon.ps1")
	if receipt.get("status", "") in ["running", "starting", "interrupted", "blocked"] and FileAccess.file_exists(runner):
		var process_args := PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", runner, "resume", "--job-id", job_id, "--root", ProjectSettings.globalize_path("res://../art/weapons/runs")])
		var manifest := _load_preparation_manifest(job_id)
		if str(manifest.get("settings", {}).get("cutout", "")) == "comfy":
			var comfy_url := _asset_pipeline_comfy_url()
			if comfy_url.is_empty():
				job_label.text = "Cannot resume %s: tools/asset_pipeline/config.json has no concept_url." % job_id
				return
			process_args.append("--comfy-url")
			process_args.append(comfy_url)
		var process_id := OS.create_process("powershell", process_args)
		if process_id > 0:
			receipt.status = "running"
			receipt.failure = ""
			Store.save_job_receipt(receipt)
	job_label.text = "Job %s: %s, stage %s, %.0f%%\n%s" % [job_id, receipt.get("status", "unknown"), receipt.get("stage", "unknown"), float(receipt.get("progress", 0.0)) * 100.0, receipt.get("failure", "No failure details.")]

func _sync_art() -> void:
	draft.art.source = _selected_source()
	draft.art.crop = [_spin_value("crop_x", 0.0), _spin_value("crop_y", 0.0), _spin_value("crop_w", 0.0), _spin_value("crop_h", 0.0)]
	draft.art.grip = [_spin_value("grip_x", 0.5), _spin_value("grip_y", 0.75)]
	draft.art.world_scale = _spin_value("world_scale", 1.0)

func _spin_value(key: String, fallback: float) -> float:
	var control: Variant = fields.get(key)
	return float(control.value) if control is SpinBox else fallback

func _apply_draft_to_controls() -> void:
	if source_path == null:
		return
	_select_source(str(draft.get("art", {}).get("source", "")))
	description_edit.text = str(draft.get("description", ""))
	for key in ["weapon_id", "label"]:
		var line: LineEdit = fields.get(key)
		if line != null:
			line.text = str(draft.get(key, ""))
	for key in ["crop_x", "crop_y", "crop_w", "crop_h"]:
		var crop_index := ["crop_x", "crop_y", "crop_w", "crop_h"].find(key)
		var spin: SpinBox = fields.get(key)
		if spin != null:
			spin.value = float(draft.get("art", {}).get("crop", [0, 0, 0, 0])[crop_index])
	for key in ["grip_x", "grip_y", "world_scale"]:
		var spin: SpinBox = fields.get(key)
		if spin != null:
			var source_value = draft.get("art", {}).get("grip", [0.5, 0.75])[0 if key == "grip_x" else 1] if key != "world_scale" else draft.get("art", {}).get("world_scale", 1.0)
			spin.value = float(source_value)
	for key in ["behavior_id", "rarity", "facing"]:
		var option: OptionButton = fields.get(key)
		if option != null:
			for index in range(option.item_count):
				if option.get_item_text(index) == str(draft.get(key, draft.get("art", {}).get(key, ""))):
					option.select(index)
	for index in range(mini(affixes.size(), draft.get("explicit_modifiers", []).size())):
		var modifier: Dictionary = draft.explicit_modifiers[index]
		var record: Dictionary = affixes[index]
		var option: OptionButton = record.option
		for option_index in range(option.item_count):
			if option.get_item_text(option_index) == str(modifier.get("affix_id", "")):
				option.select(option_index)
		record.tier.value = int(modifier.get("tier", 1))
		record.value.value = float(modifier.get("value", 0.0))

func _populate_source_options() -> void:
	source_path.clear()
	var files: Array[String] = []
	var directory := DirAccess.open(ProjectSettings.globalize_path("res://../" + SOURCE_FOLDER_RELATIVE))
	if directory != null:
		directory.list_dir_begin()
		var filename := directory.get_next()
		while not filename.is_empty():
			if not directory.current_is_dir() and filename.to_lower().ends_with(".png"):
				files.append(filename)
			filename = directory.get_next()
		directory.list_dir_end()
	files.sort()
	for filename in files:
		var index := source_path.item_count
		source_path.add_item(filename)
		source_path.set_item_metadata(index, SOURCE_FOLDER_RELATIVE.path_join(filename))
	if files.is_empty():
		source_path.add_item("No PNG files found in Weapons folder")
		source_path.set_item_disabled(0, true)
	else:
		source_path.select(0)

func _select_source(path: String) -> void:
	for index in range(source_path.item_count):
		if str(source_path.get_item_metadata(index)) == path:
			source_path.select(index)
			return
	if source_path.item_count > 0 and not source_path.is_item_disabled(0):
		source_path.select(0)

func _selected_source() -> String:
	var index := source_path.selected
	if index < 0 or source_path.is_item_disabled(index):
		return ""
	return str(source_path.get_item_metadata(index))

func _stat_control(parent: Control, key: String, title: String, operation: String, initial: float) -> void:
	var spin := _spin(parent, title, key, -100.0, 100.0, 0.01)
	spin.value = initial
	spin.value_changed.connect(func(value: float):
		for modifier in draft.base_modifiers:
			if modifier.get("stat") == key:
				modifier.value = value
				modifier.operation = operation
				_refresh()
				return
		draft.base_modifiers.append({"stat": key, "operation": operation, "family": "designer.base." + key, "value": value})
		_refresh())

func _affix_control(parent: Control, _index: int) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var option := OptionButton.new()
	option.add_item("(empty)")
	for affix_id in Definitions.PRODUCTION_AFFIXES:
		option.add_item(affix_id)
	row.add_child(option)
	var tier := SpinBox.new()
	tier.min_value = 1; tier.max_value = 3; tier.step = 1; tier.value = 1
	row.add_child(tier)
	var value := SpinBox.new()
	value.min_value = 0; value.max_value = 100; value.step = 0.01; value.value = 1
	row.add_child(value)
	var record := {"option": option, "tier": tier, "value": value}
	affixes.append(record)
	option.item_selected.connect(func(_selected: int): _sync_affixes(); _refresh())
	tier.value_changed.connect(func(_v: float): _sync_affixes(); _refresh())
	value.value_changed.connect(func(_v: float): _sync_affixes(); _refresh())

func _sync_affixes() -> void:
	var selected: Array = []
	for record in affixes:
		var option: OptionButton = record.option
		if option.selected > 0:
			selected.append({"affix_id": option.get_item_text(option.selected), "tier": int(record.tier.value), "value": float(record.value.value)})
	draft.explicit_modifiers = selected

func _section(title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(_heading(title, 14))
	return section

func _field_row(parent: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var caption := _label(title.to_upper(), 11)
	caption.custom_minimum_size.x = 128
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	return row

func _line(parent: Control, title: String, key: String) -> LineEdit:
	var row := _field_row(parent, title)
	var line := LineEdit.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	fields[key] = line
	line.text_changed.connect(func(value: String): draft[key] = value; _refresh())
	return line

func _option(parent: Control, title: String, key: String, values: Array) -> OptionButton:
	var row := _field_row(parent, title)
	var option := OptionButton.new()
	for value in values:
		option.add_item(value)
	option.select(maxi(0, values.find(draft.get(key, values[0]))))
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	fields[key] = option
	option.item_selected.connect(func(index: int): draft[key] = option.get_item_text(index); _refresh())
	return option

func _spin(parent: Control, title: String, key: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var row := _field_row(parent, title)
	var spin := SpinBox.new()
	spin.min_value = minimum; spin.max_value = maximum; spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	fields[key] = spin
	spin.value_changed.connect(func(value: float): draft[key] = value; _refresh())
	return spin

func _compact_spin(parent: Control, title: String, key: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var caption := _label(title, 11)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(caption)
	var spin := SpinBox.new()
	spin.min_value = minimum; spin.max_value = maximum; spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	fields[key] = spin
	spin.value_changed.connect(func(value: float): draft[key] = value; _refresh())
	return spin

func _heading(text: String, size: int) -> Label:
	var result := _label(text, size)
	result.add_theme_color_override("font_color", Color("8fd8d2"))
	return result

func _label(text: String, size: int = 12) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _diagnostic_text(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	if diagnostics.is_empty():
		return str(result.get("error", "Invalid authoring data"))
	var diagnostic: Dictionary = diagnostics[0]
	return "%s: %s" % [diagnostic.get("path", "field"), diagnostic.get("message", "invalid value")]
