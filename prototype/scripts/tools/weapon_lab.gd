extends Node

## Weapon Lab: dev tool for bringing ComfyUI / ChatGPT weapon art into the game.
##
## One page per weapon, like the Monster Encyclopedia:
##   1. ART      pick or import a source image, cut it out (Trellis 2 through
##               ComfyUI, a local solid-background removal, or the PNG's own
##               transparency) and prepare the world sprite and icon.
##   2. DETAILS  name, description, behavior and stat bonuses, with the
##               resolved in-game numbers.
##   3. PLACEMENT grip, scale, rotation, hand offset, facing. Click the sprite
##               to set the grip; fine-tune in the arena.
##   Test in arena: the weapon test arena (the Monster Test Arena with the hero
##               holding this weapon). Placement edits there come back here.
##   Add to game: publishes a new weapon, or the next revision of a published
##               one, through WeaponPublisher (immutable revisions + index).
##
## Work in progress is saved as a designer draft (data/designer/drafts/lab.<id>.json).
## Preparation runs go to art/weapons/runs/<job_id>/ in the Python pipeline's format.

const Art = preload("res://scripts/tools/weapon_lab_art.gd")
const ComfyScript = preload("res://scripts/tools/comfy_cutout.gd")
const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const LootRegistration = preload("res://scripts/model/weapon_loot_registration.gd")
const ArenaScript = preload("res://scripts/tools/weapon_test_arena.gd")
const WeaponSwing = preload("res://scripts/model/weapon_swing.gd")
const WeaponEffects = preload("res://scripts/model/weapon_effects.gd")
const EffectsPanelScript = preload("res://scripts/tools/weapon_lab_effects.gd")
const WeaponClip = preload("res://scripts/model/weapon_clip.gd")
const ClipImporterScript = preload("res://scripts/tools/weapon_clip_importer.gd")
const MELEE_STRIKE_FRACTION := 0.4
const SWING_TIPS := {
	"duration": "Total length of the swing in seconds. Keep it at or under the time between attacks (1 / attacks per second).",
	"windup_angle": "How far the weapon cocks back before the strike (the chamber or raise). Negative is back/up; heavy weapons go further.",
	"strike_angle": "Where the strike ends. The travel from wind-up to strike is the arc of the cut; include follow-through past the hit.",
	"settle_angle": "Pose the weapon returns to during recovery. 0 is the resting pose.",
	"windup_time": "When the wind-up ends, as a fraction of the duration (0.24 of 0.5 s = 0.12 s of wind-up).",
	"strike_time": "When the strike ends, as a fraction of the duration. The time between wind-up end and strike end is the fast part.",
	"windup_push": "Pixels the weapon moves along the facing during the wind-up. Negative pulls it back toward the hero.",
	"strike_push": "Pixels the weapon moves forward on the strike, like stepping into the cut.",
	"strike_lift": "Pixels the weapon rises on the strike. Negative drops it, like a chop driving down.",
	"snap": "Speed shape of the strike. Positive (up to 1): fast start that eases out, a whip. Negative (down to -1): slow start that speeds up into the hit, heavy and gravity-driven. 0: steady.",
}
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")
const BalanceData = preload("res://data/balance.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"
## The global weapon baseline every weapon used before per-weapon base stats.
const DEFAULT_BASE_DAMAGE: float = BalanceData.WEAPON_DAMAGE
const DEFAULT_BASE_RATE: float = 1.0 / BalanceData.WEAPON_INTERVAL
const DRAFT_PREFIX := "lab."
const NEW_ID := "__new__"

const AMBER := Color("f0a836")
const AMBER_DEEP := Color("b9761c")
const INK := Color("ece6da")
const MUTED := Color("9ba4ac")
const PLATE := Color("20252a")
const PLATE_2 := Color("2a3036")
const EDGE := Color("434c55")
const GOOD := Color("75d5a5")
const BAD := Color("f09a9a")

const BEHAVIORS := [
	["weapon.standard", "Ranged (shoots the nearest monster)"],
	["weapon.melee", "Melee (swings at a monster in reach)"],
	["weapon.fan", "Fan (ranged; spread comes from research)"],
	["weapon.lance", "Lance (ranged; pierce comes from research)"],
]
const CUTOUT_METHODS := [
	["auto", "Auto: keep transparency, else Trellis 2"],
	["comfy", "ComfyUI Trellis 2 (remove background)"],
	["solid", "Solid background (no ComfyUI)"],
	["transparent", "Already transparent (use PNG alpha)"],
]

## Where the lab reads and writes. Tests point these at temporary folders.
var data_root: String = Publisher.DEFAULT_DATA_ROOT
var asset_root: String = Publisher.DEFAULT_ASSET_ROOT
var draft_root: String = Store.DRAFT_ROOT
var loot_path: String = LootRegistration.DEFAULT_PATH

var ui: CanvasLayer
var root: Control
var comfy: Node
var arena: Node

var entries: Array[Dictionary] = []
var selected_id := ""
var draft: Dictionary = {}
var published_revision := 0
var busy := false
## The selected weapon was removed from the game (retired in the index).
var selected_removed := false
var show_removed := false
var _loading := false
var _dirty := false

# widgets
var count_label: Label
var search: LineEdit
var tile_list: VBoxContainer
var tile_group := ButtonGroup.new()
var tiles: Dictionary = {}
var page_title: Label
var page_meta: Label
var source_picker: OptionButton
var source_preview: TextureRect
var method_picker: OptionButton
var tolerance_spin: SpinBox
var tolerance_row: Control
var comfy_url: LineEdit
var comfy_status: Label
var prepare_button: Button
var cancel_button: Button
var art_status: Label
var world_preview: TextureRect
var icon_preview: TextureRect
var name_edit: LineEdit
var id_edit: LineEdit
var description_edit: TextEdit
var behavior_picker: OptionButton
var base_damage_spin: SpinBox
var base_rate_spin: SpinBox
var base_dps_label: Label
var damage_spin: SpinBox
var rate_spin: SpinBox
var speed_spin: SpinBox
var resolved_label: Label
var placement_spins: Dictionary = {}
var facing_picker: OptionButton
var loot_check: CheckBox
var loot_weight: SpinBox
var status_label: Label
var publish_button: Button
var test_button: Button
var import_dialog: FileDialog
var swing_preset: OptionButton
var swing_spins: Dictionary = {}
var swing_preview: Control
var swing_note: Label
var effects_panel: VBoxContainer
var _effect_textures: Dictionary = {}
var clip_importer: Control
var clip_preview: Control
var clip_summary: Label
var clip_edit_button: Button
var clip_remove_button: Button
var clip_time := 0.0
var _clip_textures: Dictionary = {}
var swing_why: Label
var swing_speed_button: Button
var swing_time := 0.0
var swing_texture: Texture2D
var remove_button: Button
var remove_dialog: ConfirmationDialog
var discard_draft_button: Button
var removed_check: CheckBox

func _ready() -> void:
	comfy = ComfyScript.new()
	comfy.name = "ComfyCutout"
	add_child(comfy)
	comfy.status_changed.connect(func(text: String) -> void: _set_art_status(text))
	_build()
	comfy_url.text = comfy.base_url
	reload_entries()
	if entries.is_empty():
		new_weapon()
	else:
		select_entry(str(entries[0]["id"]))

func _process(delta: float) -> void:
	if swing_preview == null or arena != null or not ui.visible:
		return
	swing_time += delta
	swing_preview.queue_redraw()
	if clip_preview != null and (clip_importer == null or not clip_importer.visible):
		clip_time += delta
		clip_preview.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if arena != null or (clip_importer != null and clip_importer.visible):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if import_dialog != null and import_dialog.visible:
			return
		return_to_title()
		get_viewport().set_input_as_handled()

func return_to_title() -> void:
	if _dirty and not draft.is_empty():
		save_draft()
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(TITLE_SCENE)

# ---------- entries ----------

## Published weapons plus Weapon Lab drafts, merged by weapon id.
func reload_entries() -> void:
	entries.clear()
	var seen := {}
	var weapons: Dictionary = published_index().get("weapons", {})
	for weapon_id in weapons:
		var revision: Dictionary = weapons[weapon_id]
		entries.append({"id": str(weapon_id), "label": str(revision.get("label", weapon_id)), "revision": int(revision.get("revision", 0)), "icon": str(revision.get("assets", {}).get("icon", "")), "draft": false})
		seen[str(weapon_id)] = entries.size() - 1
	for draft_id in Store.list_drafts(draft_root):
		if not str(draft_id).begins_with(DRAFT_PREFIX):
			continue
		var saved := Store.load_draft(str(draft_id), draft_root)
		var weapon_id := str(saved.get("weapon_id", ""))
		if weapon_id.is_empty():
			continue
		var icon := ""
		var job_id := str(saved.get("art", {}).get("job_id", ""))
		if Art.is_complete(job_id):
			icon = Art.run_dir(job_id).path_join("square-icon.png")
		if seen.has(weapon_id):
			entries[seen[weapon_id]]["draft"] = true
			if not icon.is_empty():
				entries[seen[weapon_id]]["icon"] = icon
		else:
			entries.append({"id": weapon_id, "label": str(saved.get("label", weapon_id)), "revision": 0, "icon": icon, "draft": true})
			seen[weapon_id] = entries.size() - 1
	if show_removed:
		var retired := retired_index()
		for weapon_id in retired:
			if seen.has(str(weapon_id)):
				continue
			var revision: Dictionary = retired[weapon_id]
			entries.append({"id": str(weapon_id), "label": str(revision.get("label", weapon_id)), "revision": int(revision.get("revision", 0)), "icon": str(revision.get("assets", {}).get("icon", "")), "draft": false, "removed": true})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["label"]).to_lower() < str(b["label"]).to_lower())
	_render_tiles()

## Weapons taken out of the game with Remove (kept on disk, restorable).
func retired_index() -> Dictionary:
	var retired: Variant = published_index().get("retired", {})
	return retired if retired is Dictionary else {}

func published_index() -> Dictionary:
	var path := ProjectSettings.globalize_path(data_root.path_join(Publisher.INDEX_NAME))
	if not FileAccess.file_exists(path):
		return {"schema_version": 1, "weapons": {}}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {"schema_version": 1, "weapons": {}}

func published_entry(weapon_id: String) -> Dictionary:
	return published_index().get("weapons", {}).get(weapon_id, {})

func select_entry(weapon_id: String) -> void:
	if _dirty and not draft.is_empty() and str(draft.get("weapon_id", "")) != weapon_id:
		save_draft()
	selected_id = weapon_id
	var saved := Store.load_draft(DRAFT_PREFIX + weapon_id, draft_root)
	var published := published_entry(weapon_id)
	published_revision = int(published.get("revision", 0))
	var retired: Dictionary = retired_index().get(weapon_id, {})
	selected_removed = published.is_empty() and not retired.is_empty()
	if not saved.is_empty():
		draft = saved
	elif not published.is_empty():
		draft = draft_from_published(weapon_id, published)
	elif selected_removed:
		draft = draft_from_published(weapon_id, retired)
	else:
		draft = _new_draft("")
	_dirty = false
	_sync_tiles()
	_apply_draft_to_controls()
	_set_status(_idle_status())

func new_weapon() -> void:
	if _dirty and not draft.is_empty():
		save_draft()
	selected_id = NEW_ID
	published_revision = 0
	selected_removed = false
	draft = _new_draft("")
	var sources := Art.list_sources()
	if not sources.is_empty():
		draft["art"]["source"] = sources[0]
	_dirty = false
	_sync_tiles()
	_apply_draft_to_controls()
	name_edit.grab_focus()
	_set_status("New weapon. Pick or import its image, cut it out, then give it a name.")

func _new_draft(weapon_id: String) -> Dictionary:
	var fresh := Store.default_draft(DRAFT_PREFIX + (weapon_id if not weapon_id.is_empty() else "new"))
	fresh["weapon_id"] = weapon_id
	fresh["label"] = ""
	fresh["description"] = ""
	fresh["lab"] = {"cutout_method": "auto", "tolerance": 38.0}
	fresh["base_stats"] = default_base_stats()
	return fresh

static func default_base_stats() -> Dictionary:
	return {"attack_damage": DEFAULT_BASE_DAMAGE, "attacks_per_second": DEFAULT_BASE_RATE}

## A weapon's base stats, filling in the global baseline for anything unset.
static func base_stats_of(source: Dictionary) -> Dictionary:
	var result := {"attack_damage": DEFAULT_BASE_DAMAGE, "attacks_per_second": DEFAULT_BASE_RATE}
	var stats: Variant = source.get("base_stats", null)
	if stats is Dictionary:
		for key in result:
			if stats.has(key):
				result[key] = float(stats[key])
	return result

func draft_from_published(weapon_id: String, published: Dictionary) -> Dictionary:
	var result := Store.default_draft(DRAFT_PREFIX + weapon_id)
	result["weapon_id"] = weapon_id
	result["label"] = str(published.get("label", weapon_id))
	result["description"] = str(published.get("description", ""))
	result["behavior_id"] = str(published.get("behavior_id", "weapon.standard"))
	result["base_modifiers"] = published.get("base_modifiers", []).duplicate(true)
	result["base_stats"] = base_stats_of(published)
	result["swing"] = published.get("swing", {}).duplicate(true) if published.get("swing") is Dictionary else {}
	result["effects"] = published.get("effects", []).duplicate(true) if published.get("effects") is Array else []
	result["attack_clip"] = published.get("attack_clip", {}).duplicate(true) if published.get("attack_clip") is Dictionary else {}
	var recipe_path := ProjectSettings.globalize_path(data_root.path_join(weapon_id).path_join(str(int(published.get("revision", 1)))).path_join("recipe.json"))
	if FileAccess.file_exists(recipe_path):
		var recipe = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
		if recipe is Dictionary:
			result["rarity"] = str(recipe.get("rarity", "common"))
			result["item_level"] = int(recipe.get("item_level", 1))
			result["explicit_modifiers"] = recipe.get("explicit_modifiers", []).duplicate(true)
	var pivot: Dictionary = published.get("pivot", {})
	var art: Dictionary = result["art"]
	art["grip"] = pivot.get("grip", [0.5, 0.75]).duplicate()
	art["facing"] = str(pivot.get("facing", "right"))
	art["world_scale"] = float(pivot.get("world_scale", 1.0))
	art["rotation_degrees"] = float(pivot.get("rotation_degrees", 0.0))
	art["hand_offset"] = pivot.get("hand_offset", [0.0, 0.0]).duplicate()
	var job_id := str(published.get("source_hashes", {}).get("job_id", ""))
	art["job_id"] = job_id if Art.is_complete(job_id) else ""
	var manifest := Art.load_manifest(job_id)
	art["source"] = _repo_relative(str(manifest.get("source", "")))
	result["lab"] = {"cutout_method": "auto", "tolerance": 38.0}
	return result

static func _repo_relative(path: String) -> String:
	var normalized := path.replace("\\", "/")
	var marker := "/" + Art.SOURCE_FOLDER_RELATIVE + "/"
	var at := normalized.find(marker)
	if at >= 0:
		return normalized.substr(at + 1)
	return normalized

func is_published() -> bool:
	return published_revision > 0

# ---------- saving ----------

func save_draft() -> Dictionary:
	_sync_from_controls()
	var weapon_id := str(draft.get("weapon_id", ""))
	if weapon_id.is_empty():
		return {"valid": false, "error": "Give the weapon a name first."}
	draft["draft_id"] = DRAFT_PREFIX + weapon_id
	if str(draft.get("label", "")).is_empty():
		draft["label"] = weapon_id
	if str(draft.get("description", "")).is_empty():
		draft["description"] = "No description yet."
	var result := Store.save_draft(draft, draft_root)
	if result.get("valid", false):
		_dirty = false
		var was_new := selected_id == NEW_ID or selected_id != weapon_id
		selected_id = weapon_id
		if was_new:
			reload_entries()
		_sync_tiles()
	return result

func _on_save_pressed() -> void:
	var result := save_draft()
	if result.get("valid", false):
		_set_status("Draft saved. It isn't in the game until you add it.", GOOD)
	else:
		_set_status(_error_text(result), BAD)

# ---------- art ----------

func selected_source() -> String:
	return str(draft.get("art", {}).get("source", ""))

func set_source(relative_path: String) -> void:
	draft["art"]["source"] = relative_path
	_mark_dirty()
	_refresh_source_preview()

func cutout_method() -> String:
	return str(CUTOUT_METHODS[maxi(0, method_picker.selected)][0])

func open_import_dialog() -> void:
	import_dialog.popup_centered_ratio(0.7)

func import_image(absolute_path: String) -> void:
	var result := Art.import_source(absolute_path)
	if not result.ok:
		_set_status(str(result.error), BAD)
		return
	_populate_sources()
	set_source(str(result.path))
	_select_source_in_picker(str(result.path))
	if str(draft.get("label", "")).is_empty():
		name_edit.text = absolute_path.get_file().get_basename().replace("_", " ").capitalize()
		_on_name_changed(name_edit.text)
	_set_status("Imported %s into %s. Next: Cut out & prepare." % [absolute_path.get_file(), Art.SOURCE_FOLDER_RELATIVE], GOOD)

## Cuts the source out with the chosen method and writes a preparation run.
func prepare_art() -> void:
	if busy:
		return
	var source := selected_source()
	if source.is_empty() or not FileAccess.file_exists(Art.absolute_source(source)):
		_set_art_status("Pick or import a source image first.", BAD)
		return
	var source_abs := Art.absolute_source(source)
	var image := Image.load_from_file(source_abs)
	if image == null or image.is_empty():
		_set_art_status("Couldn't read the source image.", BAD)
		return
	var method := cutout_method()
	if method == "auto":
		method = "transparent" if Art.has_transparency(image) else "comfy"
	busy = true
	_update_buttons()
	var job_id := Art.new_job_id()
	var cutout: Image = null
	var extra := {"draft_id": DRAFT_PREFIX + str(draft.get("weapon_id", "new"))}
	if method == "comfy":
		comfy.set_url(comfy_url.text)
		comfy_url.text = comfy.base_url
		var result: Dictionary = await comfy.cut_out(source_abs, job_id)
		if not result.get("ok", false):
			busy = false
			_update_buttons()
			_set_art_status(str(result.get("error", "Cutout failed.")) + "\nTip: 'Solid background' works without ComfyUI for flat backdrops.", BAD)
			return
		cutout = result["image"]
		extra["history"] = result.get("history", {})
		extra["gpu_work"] = result.get("gpu_work", {})
	elif method == "solid":
		_set_art_status("Removing the background...")
		await get_tree().process_frame
		cutout = Art.solid_background_cutout(image, float(tolerance_spin.value))
	elif method == "transparent" and not Art.has_transparency(image):
		busy = false
		_update_buttons()
		_set_art_status("This image has no transparency. Use Trellis 2 or Solid background.", BAD)
		return
	_set_art_status("Preparing the world sprite and icon...")
	await get_tree().process_frame
	var grip := Vector2(float(draft["art"]["grip"][0]), float(draft["art"]["grip"][1]))
	var prepared := Art.prepare(source, cutout, method, grip, job_id, extra)
	busy = false
	_update_buttons()
	if not prepared.ok:
		_set_art_status(str(prepared.error), BAD)
		return
	draft["art"]["job_id"] = str(prepared.job_id)
	draft["lab"]["cutout_method"] = cutout_method()
	_mark_dirty()
	if not str(draft.get("weapon_id", "")).is_empty():
		save_draft()
	_refresh_art_previews()
	_set_art_status("Prepared (%s cutout) as %s." % [{"comfy": "Trellis 2", "solid": "solid background", "transparent": "PNG alpha"}[method], prepared.job_id], GOOD)
	_set_status(_idle_status())

func check_comfy() -> void:
	comfy.set_url(comfy_url.text)
	comfy_url.text = comfy.base_url
	comfy_status.text = "Checking..."
	comfy_status.add_theme_color_override("font_color", MUTED)
	var result: Dictionary = await comfy.check_server()
	comfy_status.text = "Connected, Trellis 2 ready." if result.ok else str(result.error)
	comfy_status.add_theme_color_override("font_color", GOOD if result.ok else BAD)

## Texture of the world sprite the weapon would use right now.
func current_world_texture() -> Texture2D:
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if Art.is_complete(job_id):
		return Art.load_texture(Art.run_dir(job_id).path_join("world-sprite.png"))
	if is_published():
		return Art.load_texture(str(published_entry(str(draft.weapon_id)).get("assets", {}).get("world_sprite", "")))
	return null

func current_icon_texture() -> Texture2D:
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if Art.is_complete(job_id):
		return Art.load_texture(Art.run_dir(job_id).path_join("square-icon.png"))
	if is_published():
		return Art.load_texture(str(published_entry(str(draft.weapon_id)).get("assets", {}).get("icon", "")))
	return null

# ---------- stats ----------

func modifier_value(stat: String) -> float:
	for modifier in draft.get("base_modifiers", []):
		if str(modifier.get("stat", "")) == stat:
			return float(modifier.get("value", 0.0))
	return 0.0

func set_modifier(stat: String, operation: String, value: float) -> void:
	var modifiers: Array = draft.get("base_modifiers", [])
	for index in range(modifiers.size()):
		if str(modifiers[index].get("stat", "")) == stat:
			if is_zero_approx(value) and stat != "attack_damage":
				modifiers.remove_at(index)
			else:
				modifiers[index]["value"] = value
				modifiers[index]["operation"] = operation
			draft["base_modifiers"] = modifiers
			return
	if is_zero_approx(value) and stat != "attack_damage":
		return
	modifiers.append({"stat": stat, "operation": operation, "family": "designer.base." + stat, "value": value})
	draft["base_modifiers"] = modifiers

## The weapon's numbers in game, from HeroStatResolver (no research, no upgrades).
func resolved_stats() -> Dictionary:
	var instance := {"instance_id": "lab-preview", "base_id": "core.heavy_breech", "rarity": "common", "item_level": int(draft.get("item_level", 1)), "implicit_modifiers": draft.get("base_modifiers", []).duplicate(true), "explicit_modifiers": draft.get("explicit_modifiers", []).duplicate(true), "base_stats": base_stats_of(draft)}
	var resolved := Resolver.resolve({}, {"lab-preview": instance}, {"weapon": "lab-preview"})
	var stats: Dictionary = resolved.get("stats", {})
	return {"attack_damage": float(stats.get("attack_damage", BalanceData.WEAPON_DAMAGE)), "attacks_per_second": float(stats.get("attacks_per_second", 1.0 / BalanceData.WEAPON_INTERVAL)), "attack_interval": float(stats.get("attack_interval", BalanceData.WEAPON_INTERVAL)), "projectile_speed": BalanceData.WEAPON_PROJECTILE_SPEED}

func current_pivot() -> Dictionary:
	var art: Dictionary = draft.get("art", {})
	return {"coordinate_space": "normalized", "origin": "top_left", "grip": art.get("grip", [0.5, 0.75]).duplicate(), "facing": str(art.get("facing", "right")), "world_scale": float(art.get("world_scale", 1.0)), "rotation_degrees": float(art.get("rotation_degrees", 0.0)), "hand_offset": art.get("hand_offset", [0.0, 0.0]).duplicate()}

func apply_pivot(pivot: Dictionary) -> void:
	var art: Dictionary = draft["art"]
	art["grip"] = pivot.get("grip", [0.5, 0.75]).duplicate()
	art["facing"] = str(pivot.get("facing", "right"))
	art["world_scale"] = float(pivot.get("world_scale", 1.0))
	art["rotation_degrees"] = float(pivot.get("rotation_degrees", 0.0))
	art["hand_offset"] = pivot.get("hand_offset", [0.0, 0.0]).duplicate()
	_mark_dirty()

# ---------- arena ----------

func open_arena() -> void:
	if arena != null:
		return
	_sync_from_controls()
	arena = ArenaScript.new()
	arena.name = "WeaponTestArena"
	arena.exit_requested.connect(close_arena)
	arena.placement_changed.connect(func(pivot: Dictionary) -> void: apply_pivot(pivot))
	arena.swing_changed.connect(func(swing: Dictionary) -> void: apply_swing(swing))
	add_child(arena)
	var label := str(draft.get("label", ""))
	arena.configure_weapon(label if not label.is_empty() else "Unnamed weapon", current_world_texture(), current_pivot(), str(draft.get("behavior_id", "weapon.standard")), resolved_stats(), current_swing_for_game(), current_effects(), current_clip())
	ui.visible = false
	if current_world_texture() == null:
		arena._set_status("No prepared art yet: the hero is testing the stats with an empty hand.")

func close_arena() -> void:
	if arena == null:
		return
	apply_pivot(arena.current_pivot())
	apply_swing(arena.current_swing())
	arena.queue_free()
	arena = null
	Engine.time_scale = 1.0
	ui.visible = true
	_apply_placement_controls()
	_apply_swing_controls(draft.get("swing", {}))
	if effects_panel != null:
		effects_panel.set_effects(draft.get("effects", []) if draft.get("effects") is Array else [], str(draft.get("weapon_id", "")))
	_refresh_art_previews()
	_set_status("Back from the arena. Placement and swing changes are in the draft; add to game to publish them.")

# ---------- publishing ----------

## Adds a new weapon, or publishes the next revision of a published one.
func publish() -> Dictionary:
	_sync_from_controls()
	var weapon_id := str(draft.get("weapon_id", ""))
	if weapon_id.is_empty() or str(draft.get("label", "")).is_empty():
		return _publish_result(false, "Give the weapon a name first.")
	if not is_published() and not published_entry(weapon_id).is_empty():
		return _publish_result(false, "A published weapon already uses the id \"%s\". Pick another id." % weapon_id)
	if not is_published() and retired_index().has(weapon_id):
		return _publish_result(false, "The id \"%s\" belongs to a removed weapon. Tick Show removed to restore it, or pick another id." % weapon_id)
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if not Art.is_complete(job_id):
		if is_published():
			job_id = _prepare_from_published(weapon_id)
			if job_id.is_empty():
				return _publish_result(false, "Couldn't reuse the published art. Prepare the art again.")
			draft["art"]["job_id"] = job_id
		else:
			return _publish_result(false, "Cut out & prepare the art first (step 1).")
	if str(draft.get("description", "")).is_empty():
		draft["description"] = "No description yet."
	if is_published() and not has_changes_from_published():
		return _publish_result(false, "Nothing changed since revision %d." % published_revision)
	draft["revision"] = published_revision + 1
	draft["draft_id"] = DRAFT_PREFIX + weapon_id
	var result := Publisher.publish(draft, Art.runs_dir(), job_id, data_root, asset_root)
	if not result.get("valid", false):
		draft.erase("revision")
		return _publish_result(false, "Not published: " + _error_text(result))
	draft.erase("revision")
	published_revision = int(published_entry(weapon_id).get("revision", published_revision + 1))
	# Point the draft's effects at the published sheets instead of the draft files.
	var published_effects: Variant = published_entry(weapon_id).get("effects", [])
	draft["effects"] = published_effects.duplicate(true) if published_effects is Array else []
	if effects_panel != null:
		effects_panel.set_effects(draft["effects"], weapon_id)
	# Same for the attack clip; keep the importer project so it can be edited.
	var project := str(current_clip().get("project", ""))
	var published_clip: Variant = published_entry(weapon_id).get("attack_clip", {})
	draft["attack_clip"] = published_clip.duplicate(true) if published_clip is Dictionary else {}
	if not project.is_empty() and not draft.attack_clip.is_empty():
		draft.attack_clip["project"] = project
	_update_loot_after_publish(weapon_id)
	save_draft()
	reload_entries()
	selected_id = weapon_id
	_sync_tiles()
	_apply_draft_to_controls()
	return _publish_result(true, "%s is in the game as revision %d. Loot drops: %s." % [draft.label, published_revision, "on" if loot_check.button_pressed else "off (turn on below to let it drop)"])

func has_changes_from_published() -> bool:
	var current := published_entry(str(draft.weapon_id))
	if current.is_empty():
		return true
	var candidate := Store.revision_for(draft)
	for key in ["label", "description", "behavior_id"]:
		if str(candidate[key]) != str(current.get(key, "")):
			return true
	if not Publisher._values_equal(candidate.base_modifiers, current.get("base_modifiers", [])):
		return true
	var candidate_base := base_stats_of(candidate)
	var current_base := base_stats_of(current)
	for key in candidate_base:
		# Spin boxes round to 0.01, so 1.67 matches the 1/0.6 default.
		if absf(float(candidate_base[key]) - float(current_base[key])) > 0.006:
			return true
	var current_pivot_value: Dictionary = current.get("pivot", {}).duplicate(true)
	for key in ["world_scale", "rotation_degrees", "hand_offset"]:
		if not current_pivot_value.has(key):
			current_pivot_value[key] = {"world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}[key]
	if not Publisher._values_equal(candidate.pivot, current_pivot_value):
		return true
	if not _swings_equal(draft.get("swing", {}), current.get("swing", {})):
		return true
	if not _effects_equal(draft.get("effects", []), current.get("effects", [])):
		return true
	if not _clips_equal(draft.get("attack_clip", {}), current.get("attack_clip", {})):
		return true
	return str(draft.art.job_id) != str(current.get("source_hashes", {}).get("job_id", ""))

## Effects count as changed if any uses a new (draft) sheet or any setting differs.
static func _effects_equal(a: Variant, b: Variant) -> bool:
	var left: Array = a if a is Array else []
	var right: Array = b if b is Array else []
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if not str(left[index].get("source", "")).is_empty():
			return false
		var l := WeaponEffects.normalize(left[index])
		var r := WeaponEffects.normalize(right[index])
		for key in WeaponEffects.DEFAULT:
			if not Publisher._values_equal(l[key], r[key]):
				return false
		if str(l.get("sheet", "")) != str(r.get("sheet", "")):
			return false
	return true

## A clip counts as changed if it uses a new (draft) sheet or any setting differs.
static func _clips_equal(a: Variant, b: Variant) -> bool:
	var left_set := WeaponClip.is_set(a)
	var right_set := WeaponClip.is_set(b)
	if left_set != right_set:
		return false
	if not left_set:
		return true
	if not str(a.get("source", "")).is_empty():
		return false
	var l := WeaponClip.normalize(a)
	var r := WeaponClip.normalize(b)
	for key in WeaponClip.DEFAULT:
		if not Publisher._values_equal(l[key], r[key]):
			return false
	return str(l.get("sheet", "")) == str(r.get("sheet", ""))

static func _swings_equal(a: Variant, b: Variant) -> bool:
	var left := WeaponSwing.normalize(a if a is Dictionary and not a.is_empty() else WeaponSwing.DEFAULT)
	var right := WeaponSwing.normalize(b if b is Dictionary and not b.is_empty() else WeaponSwing.DEFAULT)
	for key in WeaponSwing.ORDER:
		if absf(float(left[key]) - float(right[key])) > 0.001:
			return false
	return true

func _prepare_from_published(weapon_id: String) -> String:
	var assets: Dictionary = published_entry(weapon_id).get("assets", {})
	var world := ProjectSettings.globalize_path(str(assets.get("world_sprite", "")))
	if not FileAccess.file_exists(world):
		return ""
	var grip: Array = draft["art"]["grip"]
	var prepared := Art.prepare(world, null, "transparent", Vector2(float(grip[0]), float(grip[1])), "", {"draft_id": DRAFT_PREFIX + weapon_id})
	return str(prepared.job_id) if prepared.ok else ""

func _update_loot_after_publish(weapon_id: String) -> void:
	var registration := LootRegistration.registration_for(weapon_id, loot_path)
	var wants := loot_check.button_pressed
	if not wants and not bool(registration.get("enabled", false)):
		return
	LootRegistration.update_weapon(weapon_id, published_entry(weapon_id), wants, float(loot_weight.value), int(registration.get("min_item_level", 1)), int(registration.get("max_item_level", 3)), loot_path)

## Saves the loot toggle for a published weapon right away.
func save_loot_setting() -> void:
	if _loading or not is_published():
		return
	var weapon_id := str(draft.weapon_id)
	var registration := LootRegistration.registration_for(weapon_id, loot_path)
	var result := LootRegistration.update_weapon(weapon_id, published_entry(weapon_id), loot_check.button_pressed, float(loot_weight.value), int(registration.get("min_item_level", 1)), int(registration.get("max_item_level", 3)), loot_path)
	if result.get("valid", false):
		_set_status("Loot drops %s for %s (weight %.1f)." % ["enabled" if loot_check.button_pressed else "disabled", draft.label, loot_weight.value], GOOD)
	else:
		_set_status("Loot setting not saved: %s" % str(result.get("error", "")), BAD)

func _on_publish_pressed() -> void:
	if is_removed():
		restore_weapon()
	else:
		publish()

# ---------- removing ----------

func is_removed() -> bool:
	return selected_removed

func has_saved_draft(weapon_id: String) -> bool:
	return not weapon_id.is_empty() and not Store.load_draft(DRAFT_PREFIX + weapon_id, draft_root).is_empty()

## Opens the confirmation for the Remove button.
func request_remove() -> void:
	var weapon_id := str(draft.get("weapon_id", ""))
	var label := str(draft.get("label", weapon_id))
	if label.is_empty():
		label = "this weapon"
	discard_draft_button.visible = false
	if is_published():
		remove_dialog.title = "Remove weapon from the game"
		remove_dialog.dialog_text = "Remove \"%s\" from the game?\n\nIt stops appearing here and in loot drops. Players who already own one keep it.\nNothing is deleted from disk: tick Show removed to restore it later." % label
		remove_dialog.ok_button_text = "Remove from game"
		discard_draft_button.visible = has_saved_draft(weapon_id)
	else:
		remove_dialog.title = "Delete weapon draft"
		remove_dialog.dialog_text = "Delete the draft \"%s\"?\n\nIt was never added to the game. Its source image and prepared art stay on disk." % label
		remove_dialog.ok_button_text = "Delete draft"
	remove_dialog.popup_centered()

## Removes the selected weapon: retires a published weapon (and its lab
## draft), or deletes an unpublished draft.
func remove_weapon() -> Dictionary:
	var weapon_id := str(draft.get("weapon_id", ""))
	var label := str(draft.get("label", weapon_id))
	var message := ""
	if is_published():
		var registration := LootRegistration.registration_for(weapon_id, loot_path)
		if bool(registration.get("enabled", false)):
			LootRegistration.update_weapon(weapon_id, published_entry(weapon_id), false, float(registration.get("weight", 1.0)), int(registration.get("min_item_level", 1)), int(registration.get("max_item_level", 3)), loot_path)
		var result := Publisher.retire(weapon_id, data_root)
		if not result.get("valid", false):
			return _publish_result(false, "Couldn't remove %s: %s" % [label, _error_text(result)])
		_delete_draft_file(weapon_id)
		message = "%s was removed from the game. Its files are kept; tick Show removed to restore it." % label
	elif has_saved_draft(weapon_id):
		_delete_draft_file(weapon_id)
		message = "Deleted the draft %s." % label
	else:
		message = "Discarded the unsaved weapon."
	_dirty = false
	draft = {}
	reload_entries()
	if entries.is_empty():
		new_weapon()
	else:
		select_entry(str(entries[0]["id"]))
	return _publish_result(true, message)

## Drops the lab draft of a published weapon and reloads what's in the game.
func discard_draft() -> Dictionary:
	var weapon_id := str(draft.get("weapon_id", ""))
	_delete_draft_file(weapon_id)
	_dirty = false
	draft = {}
	reload_entries()
	select_entry(weapon_id)
	return _publish_result(true, "Discarded the draft; showing revision %d from the game." % published_revision)

func restore_weapon() -> Dictionary:
	var weapon_id := str(draft.get("weapon_id", ""))
	var result := Publisher.restore_retired(weapon_id, data_root)
	if not result.get("valid", false):
		return _publish_result(false, "Couldn't restore: %s" % _error_text(result))
	reload_entries()
	select_entry(weapon_id)
	return _publish_result(true, "%s is back in the game as revision %d. Loot drops are off until you turn them on." % [str(draft.get("label", weapon_id)), published_revision])

func set_show_removed(on: bool) -> void:
	show_removed = on
	if removed_check != null:
		removed_check.set_pressed_no_signal(on)
	reload_entries()

func _delete_draft_file(weapon_id: String) -> void:
	if weapon_id.is_empty():
		return
	var path := ProjectSettings.globalize_path(draft_root.path_join(DRAFT_PREFIX + weapon_id + ".json"))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _publish_result(ok: bool, message: String) -> Dictionary:
	_set_status(message, GOOD if ok else BAD)
	return {"ok": ok, "message": message}

# ---------- control sync ----------

func _mark_dirty() -> void:
	if _loading:
		return
	_dirty = true
	_refresh_meta()

func _on_name_changed(text: String) -> void:
	if _loading:
		return
	draft["label"] = text.strip_edges()
	if not is_published() and (str(draft.get("weapon_id", "")).is_empty() or id_edit.has_meta("auto")):
		var auto_id := Art.slug(text)
		_loading = true
		id_edit.text = auto_id
		_loading = false
		id_edit.set_meta("auto", true)
		draft["weapon_id"] = auto_id
	page_title.text = str(draft["label"]).to_upper() if not str(draft["label"]).is_empty() else "NEW WEAPON"
	_mark_dirty()

func _on_id_changed(text: String) -> void:
	if _loading:
		return
	id_edit.remove_meta("auto")
	draft["weapon_id"] = Art.slug(text)
	_mark_dirty()

func _sync_from_controls() -> void:
	if draft.is_empty() or name_edit == null:
		return
	draft["label"] = name_edit.text.strip_edges()
	if not is_published():
		draft["weapon_id"] = Art.slug(id_edit.text)
	draft["description"] = description_edit.text.strip_edges()
	draft["behavior_id"] = str(BEHAVIORS[maxi(0, behavior_picker.selected)][0])
	draft["base_stats"] = {"attack_damage": float(base_damage_spin.value), "attacks_per_second": float(base_rate_spin.value)}
	set_modifier("attack_damage", "flat", float(damage_spin.value))
	set_modifier("attacks_per_second", "increased", float(rate_spin.value) / 100.0)
	set_modifier("projectile_speed", "increased", float(speed_spin.value) / 100.0)
	var art: Dictionary = draft["art"]
	art["grip"] = [float(placement_spins["grip_x"].value), float(placement_spins["grip_y"].value)]
	art["world_scale"] = float(placement_spins["world_scale"].value)
	art["rotation_degrees"] = float(placement_spins["rotation_degrees"].value)
	art["hand_offset"] = [float(placement_spins["offset_x"].value), float(placement_spins["offset_y"].value)]
	art["facing"] = "left" if facing_picker.selected == 1 else "right"
	draft["lab"]["cutout_method"] = cutout_method()
	draft["lab"]["tolerance"] = float(tolerance_spin.value)
	if not swing_spins.is_empty():
		draft["swing"] = current_swing()
	if effects_panel != null:
		draft["effects"] = effects_panel.get_effects()

func _apply_draft_to_controls() -> void:
	_loading = true
	if not draft.has("lab"):
		draft["lab"] = {"cutout_method": "auto", "tolerance": 38.0}
	var label := str(draft.get("label", ""))
	page_title.text = label.to_upper() if not label.is_empty() else "NEW WEAPON"
	name_edit.text = label
	id_edit.text = str(draft.get("weapon_id", ""))
	id_edit.editable = not is_published()
	id_edit.remove_meta("auto")
	if str(draft.get("weapon_id", "")).is_empty():
		id_edit.set_meta("auto", true)
	description_edit.text = str(draft.get("description", ""))
	var behavior_index := 0
	for index in range(BEHAVIORS.size()):
		if BEHAVIORS[index][0] == str(draft.get("behavior_id", "weapon.standard")):
			behavior_index = index
	behavior_picker.select(behavior_index)
	var base := base_stats_of(draft)
	base_damage_spin.value = float(base.attack_damage)
	base_rate_spin.value = float(base.attacks_per_second)
	damage_spin.value = modifier_value("attack_damage")
	rate_spin.value = modifier_value("attacks_per_second") * 100.0
	speed_spin.value = modifier_value("projectile_speed") * 100.0
	var method := str(draft["lab"].get("cutout_method", "auto"))
	for index in range(CUTOUT_METHODS.size()):
		if CUTOUT_METHODS[index][0] == method:
			method_picker.select(index)
	tolerance_spin.value = float(draft["lab"].get("tolerance", 38.0))
	tolerance_row.visible = method == "solid"
	_populate_sources()
	_select_source_in_picker(selected_source())
	_apply_placement_controls()
	_apply_swing_controls(draft.get("swing", {}))
	if effects_panel != null:
		effects_panel.set_effects(draft.get("effects", []) if draft.get("effects") is Array else [], str(draft.get("weapon_id", "")))
	_refresh_clip_section()
	var registration := LootRegistration.registration_for(str(draft.get("weapon_id", "")), loot_path)
	loot_check.button_pressed = bool(registration.get("enabled", false)) and is_published()
	loot_weight.value = float(registration.get("weight", 1.0))
	loot_check.disabled = not is_published()
	loot_weight.editable = is_published()
	_loading = false
	_refresh_source_preview()
	_refresh_art_previews()
	_refresh_resolved()
	_refresh_meta()
	_update_buttons()
	_set_art_status(_art_idle_status())

func _apply_placement_controls() -> void:
	var was_loading := _loading
	_loading = true
	var art: Dictionary = draft.get("art", {})
	var grip: Array = art.get("grip", [0.5, 0.75])
	var offset: Array = art.get("hand_offset", [0.0, 0.0])
	placement_spins["grip_x"].value = float(grip[0])
	placement_spins["grip_y"].value = float(grip[1])
	placement_spins["world_scale"].value = float(art.get("world_scale", 1.0))
	placement_spins["rotation_degrees"].value = float(art.get("rotation_degrees", 0.0))
	placement_spins["offset_x"].value = float(offset[0])
	placement_spins["offset_y"].value = float(offset[1])
	facing_picker.select(1 if str(art.get("facing", "right")) == "left" else 0)
	_loading = was_loading
	if world_preview != null:
		world_preview.queue_redraw()

func _refresh_meta() -> void:
	if page_meta == null:
		return
	var parts: Array[String] = []
	var weapon_id := str(draft.get("weapon_id", ""))
	parts.append("id: %s" % (weapon_id if not weapon_id.is_empty() else "(from name)"))
	if is_published():
		parts.append("in game as revision %d" % published_revision)
	elif is_removed():
		parts.append("removed from the game (was revision %d)" % int(retired_index().get(weapon_id, {}).get("revision", 0)))
	else:
		parts.append("not in the game yet")
	if _dirty:
		parts.append("unsaved edits")
	page_meta.text = "   ·   ".join(parts)
	publish_button.text = "Restore to game" if is_removed() else ("Publish update (r%d)" % (published_revision + 1) if is_published() else "Add to game")
	if remove_button != null:
		remove_button.visible = not is_removed()
		remove_button.text = "Remove" if is_published() else "Delete draft"

func _refresh_resolved() -> void:
	if resolved_label == null or _loading:
		return
	_sync_from_controls()
	var base := base_stats_of(draft)
	var base_damage := float(base.attack_damage)
	var base_rate := float(base.attacks_per_second)
	base_dps_label.text = "%.1f" % (base_damage * base_rate)
	var stats := resolved_stats()
	var rate := float(stats.attacks_per_second)
	var capped: Array[String] = []
	if base_damage + damage_spin.value > base_damage * Resolver.CAPS.attack_damage + 0.001:
		capped.append("damage")
	if rate_spin.value / 100.0 > Resolver.CAPS.attacks_per_second - 1.0 + 0.0001:
		capped.append("attack speed")
	var text := "In game: %s damage   ·   %.2f attacks / s   ·   %.1f DPS" % [_fmt(float(stats.attack_damage)), rate, float(stats.attack_damage) * rate]
	if not capped.is_empty():
		text += "\nCapped: %s (item bonuses cap at +%d%% of base damage, +%d%% attack speed)." % [", ".join(capped), roundi((Resolver.CAPS.attack_damage - 1.0) * 100.0), roundi((Resolver.CAPS.attacks_per_second - 1.0) * 100.0)]
	resolved_label.text = text
	_refresh_swing_note()

func _idle_status() -> String:
	if not Art.is_complete(str(draft.get("art", {}).get("job_id", ""))) and not is_published():
		return "Step 1: pick or import the weapon image and cut it out."
	if is_published():
		return "Edit anything, test it in the arena, then Publish update to ship a new revision."
	return "Ready: test it in the arena, then Add to game."

func _art_idle_status() -> String:
	var job_id := str(draft.get("art", {}).get("job_id", ""))
	if Art.is_complete(job_id):
		return "Prepared art: %s" % job_id
	if is_published():
		return "Using the published art. Prepare new art to replace it."
	return "No prepared art yet."

func _update_buttons() -> void:
	if prepare_button == null:
		return
	prepare_button.disabled = busy
	cancel_button.visible = busy
	publish_button.disabled = busy
	test_button.disabled = busy

func _set_status(text: String, color: Color = MUTED) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)

func _set_art_status(text: String, color: Color = MUTED) -> void:
	if art_status != null:
		art_status.text = text
		art_status.add_theme_color_override("font_color", color)

func _error_text(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	if not diagnostics.is_empty():
		var first: Dictionary = diagnostics[0]
		return "%s (%s)" % [str(first.get("message", "invalid")), str(first.get("path", ""))]
	return str(result.get("error", "invalid"))

func _fmt(value: float) -> String:
	return str(roundi(value)) if absf(value - roundf(value)) < 0.05 else "%.1f" % value

# ---------- index tiles ----------

func _render_tiles() -> void:
	if tile_list == null:
		return
	for child in tile_list.get_children():
		child.queue_free()
	tiles.clear()
	var filter := search.text.strip_edges().to_lower() if search != null else ""
	for entry in entries:
		if not filter.is_empty() and not str(entry["label"]).to_lower().contains(filter) and not str(entry["id"]).to_lower().contains(filter):
			continue
		var tile := Button.new()
		tile.toggle_mode = true
		tile.button_group = tile_group
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tile.custom_minimum_size = Vector2(0, 52)
		tile.icon = Art.load_texture(str(entry["icon"]))
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 40)
		var tag := "r%d" % int(entry["revision"]) if int(entry["revision"]) > 0 else "draft"
		if int(entry["revision"]) > 0 and bool(entry["draft"]):
			tag += " + draft"
		if bool(entry.get("removed", false)):
			tag = "removed (r%d)" % int(entry["revision"])
			tile.modulate = Color(1, 1, 1, 0.55)
		tile.text = "%s\n%s" % [str(entry["label"]), tag]
		tile.clip_text = true
		var weapon_id := str(entry["id"])
		tile.pressed.connect(func() -> void: select_entry(weapon_id))
		tile_list.add_child(tile)
		tiles[weapon_id] = tile
	count_label.text = "%d weapon%s in the game" % [_published_count(), "" if _published_count() == 1 else "s"]
	_sync_tiles()

func _published_count() -> int:
	var count := 0
	for entry in entries:
		if int(entry["revision"]) > 0 and not bool(entry.get("removed", false)):
			count += 1
	return count

func _sync_tiles() -> void:
	for weapon_id in tiles:
		tiles[weapon_id].set_pressed_no_signal(weapon_id == selected_id)

# ---------- sources ----------

func _populate_sources() -> void:
	source_picker.clear()
	var sources := Art.list_sources()
	var current := selected_source()
	if not current.is_empty() and not sources.has(current):
		sources.append(current)
	if sources.is_empty():
		source_picker.add_item("No images yet: use Import image")
		source_picker.set_item_disabled(0, true)
		return
	for path in sources:
		var index := source_picker.item_count
		source_picker.add_item(path.get_file())
		source_picker.set_item_metadata(index, path)

func _select_source_in_picker(path: String) -> void:
	for index in range(source_picker.item_count):
		if str(source_picker.get_item_metadata(index)) == path:
			source_picker.select(index)
			return
	source_picker.select(-1)

func _refresh_source_preview() -> void:
	source_preview.texture = Art.load_texture(Art.absolute_source(selected_source())) if not selected_source().is_empty() else null

func _refresh_art_previews() -> void:
	world_preview.texture = current_world_texture()
	icon_preview.texture = current_icon_texture()
	swing_texture = world_preview.texture
	world_preview.queue_redraw()

## Clicking the world sprite preview sets the grip there.
func _on_world_preview_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var rect := _preview_image_rect(world_preview)
	if rect.size.x <= 0.0 or not rect.has_point(Vector2(event.position)):
		return
	var local_point: Vector2 = event.position
	var grip: Vector2 = (local_point - rect.position) / rect.size
	if effects_panel != null and effects_panel.picking_anchor:
		effects_panel.set_selected_anchor(grip)
		return
	placement_spins["grip_x"].value = snappedf(clampf(grip.x, 0.0, 1.0), 0.01)
	placement_spins["grip_y"].value = snappedf(clampf(grip.y, 0.0, 1.0), 0.01)

func _preview_image_rect(preview: TextureRect) -> Rect2:
	if preview.texture == null:
		return Rect2()
	var texture_size := Vector2(preview.texture.get_size())
	var scale := minf(preview.size.x / texture_size.x, preview.size.y / texture_size.y)
	var drawn := texture_size * scale
	return Rect2((preview.size - drawn) * 0.5, drawn)

func _draw_grip_marker() -> void:
	var rect := _preview_image_rect(world_preview)
	if rect.size.x <= 0.0:
		return
	var grip: Array = draft.get("art", {}).get("grip", [0.5, 0.75])
	var point := rect.position + rect.size * Vector2(float(grip[0]), float(grip[1]))
	world_preview.draw_circle(point, 6.0, Color(0, 0, 0, 0.6))
	world_preview.draw_arc(point, 6.0, 0.0, TAU, 20, AMBER, 2.0)
	world_preview.draw_line(point - Vector2(10, 0), point + Vector2(10, 0), AMBER, 1.0)
	world_preview.draw_line(point - Vector2(0, 10), point + Vector2(0, 10), AMBER, 1.0)

# ---------- build ----------

func _build() -> void:
	ui = CanvasLayer.new()
	ui.name = "LabUI"
	add_child(ui)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	ui.add_child(root)
	var background := ColorRect.new()
	background.color = Color("15181b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var book := PanelContainer.new()
	book.name = "Book"
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.offset_left = 16
	book.offset_top = 16
	book.offset_right = -16
	book.offset_bottom = -16
	book.add_theme_stylebox_override("panel", _box(PLATE, EDGE, 1, 6, 0))
	root.add_child(book)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	book.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	body.add_child(_build_index())
	body.add_child(_build_page())
	column.add_child(_build_footer())
	import_dialog = FileDialog.new()
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.use_native_dialog = true
	import_dialog.title = "Import a weapon image"
	import_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	import_dialog.file_selected.connect(import_image)
	root.add_child(import_dialog)
	remove_dialog = ConfirmationDialog.new()
	remove_dialog.name = "RemoveDialog"
	remove_dialog.cancel_button_text = "Cancel"
	remove_dialog.confirmed.connect(func() -> void: remove_weapon())
	discard_draft_button = remove_dialog.add_button("Discard draft only", true, "discard_draft")
	remove_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard_draft":
			remove_dialog.hide()
			discard_draft())
	root.add_child(remove_dialog)
	clip_importer = ClipImporterScript.new()
	clip_importer.name = "ClipImporter"
	clip_importer.visible = false
	clip_importer.comfy = comfy
	clip_importer.saved.connect(_on_clip_saved)
	root.add_child(clip_importer)

func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 12, [0, 0, 0, 1]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var title := Label.new()
	title.text = "WEAPON LAB"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", AMBER)
	row.add_child(title)
	var tag := Label.new()
	tag.text = "DEV TOOL"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	count_label = Label.new()
	count_label.add_theme_color_override("font_color", MUTED)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count_label)
	var back := _button("Back to title  (Esc)")
	back.name = "Back"
	back.pressed.connect(return_to_title)
	row.add_child(back)
	return bar

func _build_index() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 0, 0, 12, [0, 0, 1, 0]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var new_button := _button("+  New weapon")
	new_button.name = "NewWeapon"
	new_button.add_theme_color_override("font_color", AMBER)
	new_button.pressed.connect(new_weapon)
	column.add_child(new_button)
	search = LineEdit.new()
	search.placeholder_text = "Find a weapon"
	search.text_changed.connect(func(_text: String) -> void: _render_tiles())
	column.add_child(search)
	removed_check = CheckBox.new()
	removed_check.name = "ShowRemoved"
	removed_check.text = "Show removed"
	removed_check.add_theme_font_size_override("font_size", 13)
	removed_check.tooltip_text = "List weapons you removed from the game so you can restore them."
	removed_check.toggled.connect(set_show_removed)
	column.add_child(removed_check)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	tile_list = VBoxContainer.new()
	tile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_list.add_theme_constant_override("separation", 4)
	scroll.add_child(tile_list)
	return panel

func _build_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	page_title = Label.new()
	page_title.add_theme_font_size_override("font_size", 24)
	page_title.add_theme_color_override("font_color", INK)
	column.add_child(page_title)
	page_meta = Label.new()
	page_meta.add_theme_font_size_override("font_size", 13)
	page_meta.add_theme_color_override("font_color", MUTED)
	column.add_child(page_meta)
	var sections := HBoxContainer.new()
	sections.add_theme_constant_override("separation", 14)
	column.add_child(sections)
	sections.add_child(_build_art_section())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_child(right)
	right.add_child(_build_details_section())
	right.add_child(_build_placement_section())
	column.add_child(_build_swing_section())
	column.add_child(_build_effects_section())
	column.add_child(_build_clip_section())
	return scroll

# ---------- swing ----------

## The swing values in the editor. {} when they match the built-in default,
## so weapons that never touch the swing publish exactly as before.
func current_swing() -> Dictionary:
	if swing_spins.is_empty():
		return draft.get("swing", {})
	var values := {"preset": str(swing_preset.get_item_metadata(maxi(0, swing_preset.selected)))}
	for key in WeaponSwing.ORDER:
		values[key] = float(swing_spins[key].value)
	return {} if WeaponSwing.is_default(values) else WeaponSwing.normalize(values)

## Always the full values (used by previews and the arena).
func current_swing_for_game() -> Dictionary:
	var swing := current_swing()
	return swing if not swing.is_empty() else WeaponSwing.normalize(WeaponSwing.DEFAULT)

func apply_swing(swing: Dictionary) -> void:
	draft["swing"] = {} if swing.is_empty() or WeaponSwing.is_default(swing) else WeaponSwing.normalize(swing)
	_mark_dirty()

func apply_swing_preset(preset_id: String) -> void:
	_apply_swing_controls(WeaponSwing.preset(preset_id))
	draft["swing"] = current_swing()
	swing_time = 0.0
	_mark_dirty()

func _apply_swing_controls(swing: Variant) -> void:
	if swing_spins.is_empty():
		return
	var was_loading := _loading
	_loading = true
	var values := WeaponSwing.normalize(swing if swing is Dictionary and not swing.is_empty() else WeaponSwing.DEFAULT)
	if not (swing is Dictionary) or swing.is_empty():
		values["preset"] = "default"
	for key in WeaponSwing.ORDER:
		swing_spins[key].value = float(values[key])
	var preset_id := str(values.get("preset", "custom"))
	var index := swing_preset.item_count - 1
	for item in range(swing_preset.item_count):
		if str(swing_preset.get_item_metadata(item)) == preset_id:
			index = item
	swing_preset.select(index)
	_loading = was_loading
	_refresh_swing_note()

func _on_swing_spin_changed() -> void:
	if _loading:
		return
	# Hand edits turn the preset into "Custom".
	swing_preset.select(swing_preset.item_count - 1)
	draft["swing"] = current_swing()
	_mark_dirty()
	_refresh_swing_note()

func _refresh_swing_note() -> void:
	if swing_note == null:
		return
	var swing := current_swing_for_game()
	var duration := float(swing.duration)
	var text := "Plays %.2f s per attack." % duration
	if str(BEHAVIORS[maxi(0, behavior_picker.selected)][0]) == "weapon.melee":
		var hit := float(resolved_stats().attack_interval) * MELEE_STRIKE_FRACTION
		text += "  Melee damage lands %.2f s in (red line)%s." % [hit, "" if hit <= duration else ", after the swing ends. Lengthen it or slow the strike"]
	var interval := float(resolved_stats().attack_interval)
	if str(BEHAVIORS[maxi(0, behavior_picker.selected)][0]) == "weapon.melee":
		var hit_progress := interval * MELEE_STRIKE_FRACTION / maxf(0.01, duration)
		if hit_progress < float(swing.windup_time):
			text += "  The hit lands during the wind-up, before the strike starts: lower the attack speed or shorten the wind-up."
	if duration > interval:
		text += "  Longer than the %.2f s between attacks, so swings will cut each other off." % interval
	swing_note.text = text
	_refresh_swing_why()

## Shows the reasoning behind research presets while they're selected.
func _refresh_swing_why() -> void:
	if swing_why == null:
		return
	var preset_id := str(swing_preset.get_item_metadata(maxi(0, swing_preset.selected)))
	var entry: Dictionary = WeaponSwing.RESEARCH_PRESETS.get(preset_id, {})
	swing_why.visible = not entry.is_empty()
	swing_speed_button.visible = false
	if entry.is_empty():
		return
	swing_why.text = "Why these numbers: " + str(entry["notes"])
	var recommended := float(entry.get("recommended_attacks_per_second", 0.0))
	if recommended > 0.0 and absf(float(base_rate_spin.value) - recommended) > 0.006:
		swing_speed_button.text = "Set base attacks / s to %.2f (what this swing is timed for)" % recommended
		swing_speed_button.set_meta("rate", recommended)
		swing_speed_button.visible = true

func _draw_swing_preview() -> void:
	var rect := Rect2(Vector2.ZERO, swing_preview.size)
	swing_preview.draw_rect(rect, Color("15181b"), true)
	var swing := current_swing_for_game()
	var duration := maxf(0.01, float(swing.duration))
	var cycle := duration
	for raw in current_effects():
		var effect := WeaponEffects.normalize(raw)
		cycle = maxf(cycle, WeaponEffects.trigger_seconds(effect, swing, duration, hit_seconds()) + WeaponEffects.play_length(effect))
	cycle += 0.35
	var progress := clampf(fmod(swing_time, cycle) / duration, 0.0, 1.0)
	var stage := Rect2(0, 0, rect.size.x * 0.5, rect.size.y)
	var graph := Rect2(rect.size.x * 0.5 + 10.0, 12.0, rect.size.x * 0.5 - 22.0, rect.size.y - 36.0)
	var hand := stage.position + Vector2(stage.size.x * 0.42, stage.size.y * 0.58)
	# Hero stand-in: a body silhouette facing right with the hand marked.
	swing_preview.draw_rect(Rect2(hand + Vector2(-44, -46), Vector2(30, 92)), Color("2b3238"), true)
	swing_preview.draw_circle(hand + Vector2(-29, -60), 13.0, Color("2b3238"))
	var texture := swing_texture
	if texture != null:
		for ghost in range(6):
			var ghost_pose: Dictionary = WeaponSwing.sample(swing, float(ghost) / 5.0)
			_draw_swing_weapon(texture, hand, ghost_pose, Color(1, 1, 1, 0.12))
		_draw_swing_weapon(texture, hand, WeaponSwing.sample(swing, progress), Color.WHITE)
		_draw_preview_effects(texture, hand, swing, duration, fmod(swing_time, cycle))
	else:
		swing_preview.draw_string(ThemeDB.fallback_font, stage.position + Vector2(12, 22), "Prepare art to preview the weapon", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	swing_preview.draw_circle(hand, 4.0, AMBER)
	# Angle curve over the swing.
	swing_preview.draw_rect(graph, Color("1b2024"), true)
	var low := -180.0
	var high := 180.0
	for key in ["windup_angle", "strike_angle", "settle_angle"]:
		low = minf(low, float(swing[key]))
		high = maxf(high, float(swing[key]))
	var zero_y := graph.position.y + graph.size.y * (high / (high - low))
	swing_preview.draw_line(Vector2(graph.position.x, zero_y), Vector2(graph.end.x, zero_y), Color("3a434b"), 1.0)
	var points := PackedVector2Array()
	for step in range(61):
		var t := float(step) / 60.0
		var angle := float(WeaponSwing.sample(swing, t).angle)
		points.append(Vector2(graph.position.x + graph.size.x * t, graph.position.y + graph.size.y * ((high - angle) / (high - low))))
	swing_preview.draw_polyline(points, AMBER, 2.0, true)
	for key in ["windup_time", "strike_time"]:
		var x := graph.position.x + graph.size.x * float(swing[key])
		swing_preview.draw_line(Vector2(x, graph.position.y), Vector2(x, graph.end.y), Color("50606b"), 1.0)
	if str(BEHAVIORS[maxi(0, behavior_picker.selected)][0]) == "weapon.melee":
		var hit := float(resolved_stats().attack_interval) * MELEE_STRIKE_FRACTION / duration
		if hit <= 1.0:
			var hit_x := graph.position.x + graph.size.x * hit
			swing_preview.draw_line(Vector2(hit_x, graph.position.y), Vector2(hit_x, graph.end.y), BAD, 2.0)
	for raw in current_effects():
		var effect := WeaponEffects.normalize(raw)
		var at := clampf(WeaponEffects.trigger_seconds(effect, swing, duration, hit_seconds()) / duration, 0.0, 1.0)
		var marker_x := graph.position.x + graph.size.x * at
		swing_preview.draw_colored_polygon(PackedVector2Array([Vector2(marker_x - 5, graph.end.y), Vector2(marker_x + 5, graph.end.y), Vector2(marker_x, graph.end.y - 9)]), Color("66d9c4"))
	var cursor_x := graph.position.x + graph.size.x * progress
	swing_preview.draw_line(Vector2(cursor_x, graph.position.y), Vector2(cursor_x, graph.end.y), INK, 1.0)
	var font := ThemeDB.fallback_font
	swing_preview.draw_string(font, Vector2(graph.position.x, graph.end.y + 16), "wind-up", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	swing_preview.draw_string(font, Vector2(graph.position.x + graph.size.x * float(swing.windup_time) + 4, graph.end.y + 16), "strike", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	swing_preview.draw_string(font, Vector2(graph.position.x + graph.size.x * float(swing.strike_time) + 4, graph.end.y + 16), "settle", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	swing_preview.draw_string(font, Vector2(graph.position.x + 4, graph.position.y + 12), "angle %d° .. %d°" % [roundi(high), roundi(low)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

## Draws the weapon the way the hero holds it (facing right), posed by the swing.
func _draw_swing_weapon(texture: Texture2D, hand: Vector2, pose: Dictionary, tint: Color) -> void:
	var art: Dictionary = draft.get("art", {})
	var size := Vector2(texture.get_size())
	var game_scale := float(art.get("world_scale", 1.0)) * 96.0 / maxf(1.0, maxf(size.x, size.y))
	var preview_scale := game_scale * 1.1
	var ratio := preview_scale / maxf(0.0001, game_scale)
	var art_sign := -1.0 if str(art.get("facing", "right")) == "left" else 1.0
	var grip: Array = art.get("grip", [0.5, 0.75])
	var hand_offset: Array = art.get("hand_offset", [0.0, 0.0])
	var offset: Vector2 = pose.offset
	var origin := hand + (Vector2(float(hand_offset[0]), float(hand_offset[1])) + offset) * ratio
	var rotation := deg_to_rad(float(art.get("rotation_degrees", 0.0)) - float(pose.angle))
	swing_preview.draw_set_transform(origin, rotation, Vector2(preview_scale * art_sign, preview_scale))
	swing_preview.draw_texture(texture, -Vector2(float(grip[0]) * size.x, float(grip[1]) * size.y), tint)
	swing_preview.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- effects ----------

func current_effects() -> Array:
	return effects_panel.get_effects() if effects_panel != null else draft.get("effects", [])

## Seconds after the attack starts when damage lands (melee) or the shot fires (ranged).
func hit_seconds() -> float:
	if str(BEHAVIORS[maxi(0, behavior_picker.selected)][0]) != "weapon.melee":
		return 0.0
	return float(resolved_stats().attack_interval) * MELEE_STRIKE_FRACTION

func _effect_texture(effect: Dictionary) -> Texture2D:
	var path := WeaponEffects.sheet_path(effect)
	if not _effect_textures.has(path):
		_effect_textures[path] = WeaponEffects.load_sheet(path)
	return _effect_textures[path]

func _build_effects_section() -> Control:
	var section := _section("5  EFFECTS")
	var column: VBoxContainer = section.get_meta("body")
	var intro := Label.new()
	intro.text = "Flipbooks that play during the attack: trails, sparks, glows, muzzle flashes. Each one fires at a moment in the swing and plays at an anchor point on the weapon. They show in the swing preview above and in the arena."
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	effects_panel = EffectsPanelScript.new()
	effects_panel.name = "EffectsPanel"
	effects_panel.changed.connect(func() -> void:
		draft["effects"] = effects_panel.get_effects()
		_mark_dirty())
	effects_panel.pick_anchor_requested.connect(func() -> void: _set_status("Click the world sprite in section 1 to place the effect."))
	column.add_child(effects_panel)
	return section

## Where an effect sits in the swing preview: the weapon's transform at `pose`.
func _weapon_transform(texture: Texture2D, hand: Vector2, pose: Dictionary) -> Transform2D:
	var art: Dictionary = draft.get("art", {})
	var size := Vector2(texture.get_size())
	var game_scale := float(art.get("world_scale", 1.0)) * 96.0 / maxf(1.0, maxf(size.x, size.y))
	var preview_scale := game_scale * 1.1
	var art_sign := -1.0 if str(art.get("facing", "right")) == "left" else 1.0
	var hand_offset: Array = art.get("hand_offset", [0.0, 0.0])
	var offset: Vector2 = pose.offset
	var origin := hand + (Vector2(float(hand_offset[0]), float(hand_offset[1])) + offset) * 1.1
	var rotation := deg_to_rad(float(art.get("rotation_degrees", 0.0)) - float(pose.angle))
	return Transform2D(rotation, Vector2(preview_scale * art_sign, preview_scale), 0.0, origin)

func _draw_preview_effects(texture: Texture2D, hand: Vector2, swing: Dictionary, duration: float, time: float) -> void:
	var art: Dictionary = draft.get("art", {})
	var grip: Array = art.get("grip", [0.5, 0.75])
	var size := Vector2(texture.get_size())
	for raw in current_effects():
		var effect := WeaponEffects.normalize(raw)
		var sheet := _effect_texture(raw)
		if sheet == null:
			continue
		var start := WeaponEffects.trigger_seconds(effect, swing, duration, hit_seconds())
		var length := WeaponEffects.play_length(effect)
		if time < start or time >= start + length:
			continue
		var pose_time := time if bool(effect.follow) else start
		var transform := _weapon_transform(texture, hand, WeaponSwing.sample(swing, pose_time / duration))
		var anchor: Array = effect.anchor
		var point := transform * (Vector2(float(anchor[0]) * size.x, float(anchor[1]) * size.y) - Vector2(float(grip[0]) * size.x, float(grip[1]) * size.y))
		var offset: Array = effect.offset
		point += Vector2(float(offset[0]), float(offset[1])) * 1.1
		var frame := clampi(int((time - start) * float(effect.fps)), 0, int(effect.frame_count) - 1)
		var cell := WeaponEffects.frame_rect(effect, Vector2(sheet.get_size()), frame)
		var fit := float(effect.size) * 1.1 / maxf(1.0, maxf(cell.size.x, cell.size.y))
		var angle := (transform.get_rotation() if bool(effect.align) else 0.0) + deg_to_rad(float(effect.rotation))
		swing_preview.draw_set_transform(point, angle, Vector2(fit, fit))
		swing_preview.draw_texture_rect_region(sheet, Rect2(-cell.size * 0.5, cell.size), cell, Color(1, 1, 1, float(effect.opacity)))
		swing_preview.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _build_swing_section() -> Control:
	var section := _section("4  SWING")
	var column: VBoxContainer = section.get_meta("body")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	swing_preset = OptionButton.new()
	swing_preset.name = "SwingPreset"
	for preset_id in WeaponSwing.PRESET_ORDER:
		swing_preset.add_item(str(WeaponSwing.preset_label(preset_id)))
		swing_preset.set_item_metadata(swing_preset.item_count - 1, preset_id)
	swing_preset.add_item("Custom")
	swing_preset.set_item_metadata(swing_preset.item_count - 1, "custom")
	swing_preset.item_selected.connect(func(index: int) -> void:
		var preset_id := str(swing_preset.get_item_metadata(index))
		if preset_id != "custom":
			apply_swing_preset(preset_id))
	top.add_child(_field("Preset", swing_preset))
	var replay := _button("Replay", true)
	replay.pressed.connect(func() -> void: swing_time = 0.0)
	top.add_child(replay)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for key in WeaponSwing.ORDER:
		var param: Dictionary = WeaponSwing.PARAMS[key]
		var label := Label.new()
		label.text = str(param["label"])
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED)
		grid.add_child(label)
		var spin := _spin(float(param["min"]), float(param["max"]), float(param["step"]))
		if str(key).ends_with("_angle"):
			spin.min_value = -WeaponSwing.ANGLE_LIMIT
			spin.max_value = WeaponSwing.ANGLE_LIMIT
		spin.suffix = str(param["suffix"])
		spin.tooltip_text = str(SWING_TIPS.get(key, ""))
		label.tooltip_text = spin.tooltip_text
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		spin.custom_minimum_size = Vector2(104, 0)
		spin.value_changed.connect(func(_value: float) -> void: _on_swing_spin_changed())
		grid.add_child(spin)
		swing_spins[key] = spin
	swing_preview = Control.new()
	swing_preview.name = "SwingPreview"
	swing_preview.custom_minimum_size = Vector2(420, 200)
	swing_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swing_preview.clip_contents = true
	swing_preview.draw.connect(_draw_swing_preview)
	body.add_child(swing_preview)
	swing_why = Label.new()
	swing_why.name = "SwingWhy"
	swing_why.add_theme_font_size_override("font_size", 12)
	swing_why.add_theme_color_override("font_color", INK)
	swing_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	swing_why.visible = false
	column.add_child(swing_why)
	swing_speed_button = _button("", true)
	swing_speed_button.name = "SwingSpeed"
	swing_speed_button.visible = false
	swing_speed_button.pressed.connect(func() -> void:
		base_rate_spin.value = float(swing_speed_button.get_meta("rate", DEFAULT_BASE_RATE))
		_refresh_swing_note())
	column.add_child(swing_speed_button)
	swing_note = Label.new()
	swing_note.add_theme_font_size_override("font_size", 12)
	swing_note.add_theme_color_override("font_color", MUTED)
	swing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(swing_note)
	var hint := Label.new()
	hint.text = "Ends are fractions of the swing (0-1). Test in arena to see it on the hero; use Loop attack and slow motion there, and the Swing tab to tweak it live."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	return section

func _build_art_section() -> Control:
	var section := _section("1  ART")
	section.custom_minimum_size = Vector2(400, 0)
	var column: VBoxContainer = section.get_meta("body")
	var source_row := HBoxContainer.new()
	source_picker = OptionButton.new()
	source_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_picker.fit_to_longest_item = false
	source_picker.item_selected.connect(func(index: int) -> void:
		if not _loading:
			set_source(str(source_picker.get_item_metadata(index))))
	source_row.add_child(source_picker)
	var import_button := _button("Import image...")
	import_button.name = "Import"
	import_button.tooltip_text = "Copies an image from anywhere into art/ui-items/Weapons."
	import_button.pressed.connect(open_import_dialog)
	source_row.add_child(import_button)
	column.add_child(source_row)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 8)
	column.add_child(previews)
	source_preview = _preview("Source", Vector2(180, 150))
	previews.add_child(source_preview.get_parent().get_parent())
	world_preview = _preview("World sprite (click to set grip)", Vector2(120, 150))
	world_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	world_preview.gui_input.connect(_on_world_preview_input)
	world_preview.draw.connect(_draw_grip_marker)
	previews.add_child(world_preview.get_parent().get_parent())
	icon_preview = _preview("Icon", Vector2(72, 72))
	previews.add_child(icon_preview.get_parent().get_parent())
	method_picker = OptionButton.new()
	for method in CUTOUT_METHODS:
		method_picker.add_item(str(method[1]))
	method_picker.item_selected.connect(func(index: int) -> void:
		tolerance_row.visible = CUTOUT_METHODS[index][0] == "solid"
		if not _loading:
			draft["lab"]["cutout_method"] = CUTOUT_METHODS[index][0]
			_mark_dirty())
	column.add_child(_field("Cutout", method_picker))
	tolerance_spin = _spin(5.0, 120.0, 1.0)
	tolerance_spin.tooltip_text = "How different from the backdrop colour a pixel must be to stay."
	tolerance_row = _field("Tolerance", tolerance_spin)
	column.add_child(tolerance_row)
	var comfy_row := HBoxContainer.new()
	comfy_url = LineEdit.new()
	comfy_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comfy_url.tooltip_text = "Local ComfyUI server with the Trellis 2 nodes (Trellis2RemoveBackground)."
	comfy_url.text_submitted.connect(func(_text: String) -> void: check_comfy())
	comfy_row.add_child(comfy_url)
	var check := _button("Check", true)
	check.pressed.connect(check_comfy)
	comfy_row.add_child(check)
	column.add_child(_field("ComfyUI", comfy_row))
	comfy_status = Label.new()
	comfy_status.add_theme_font_size_override("font_size", 12)
	comfy_status.add_theme_color_override("font_color", MUTED)
	comfy_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comfy_status.text = "Trellis 2 cutouts need ComfyUI running. Solid background works offline."
	column.add_child(comfy_status)
	var action_row := HBoxContainer.new()
	prepare_button = _button("Cut out & prepare")
	prepare_button.name = "Prepare"
	prepare_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amber(prepare_button)
	prepare_button.pressed.connect(prepare_art)
	action_row.add_child(prepare_button)
	cancel_button = _button("Cancel", true)
	cancel_button.visible = false
	cancel_button.pressed.connect(func() -> void: comfy.cancel())
	action_row.add_child(cancel_button)
	column.add_child(action_row)
	art_status = Label.new()
	art_status.name = "ArtStatus"
	art_status.add_theme_font_size_override("font_size", 12)
	art_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(art_status)
	return section

func _build_details_section() -> Control:
	var section := _section("2  DETAILS & STATS")
	var column: VBoxContainer = section.get_meta("body")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Weapon name"
	name_edit.text_changed.connect(_on_name_changed)
	column.add_child(_field("Name", name_edit))
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "made from the name"
	id_edit.tooltip_text = "Permanent catalog id. Locked once the weapon is in the game."
	id_edit.text_changed.connect(_on_id_changed)
	column.add_child(_field("Id", id_edit))
	description_edit = TextEdit.new()
	description_edit.placeholder_text = "Item description"
	description_edit.custom_minimum_size = Vector2(0, 54)
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_edit.text_changed.connect(func() -> void: _mark_dirty())
	column.add_child(_field("Description", description_edit))
	behavior_picker = OptionButton.new()
	for behavior in BEHAVIORS:
		behavior_picker.add_item(str(behavior[1]))
	behavior_picker.item_selected.connect(func(_index: int) -> void:
		_mark_dirty()
		_refresh_resolved())
	column.add_child(_field("Behavior", behavior_picker))
	var base_grid := GridContainer.new()
	base_grid.columns = 3
	base_grid.add_theme_constant_override("h_separation", 8)
	base_damage_spin = _stat_spin(base_grid, "Base damage", 0.5, 1000.0, 0.5, "Damage per hit before bonuses and research. The old global default is %s." % _fmt(DEFAULT_BASE_DAMAGE))
	base_rate_spin = _stat_spin(base_grid, "Base attacks / s", 0.05, 20.0, 0.01, "Attacks per second before bonuses and research. The old global default is %.2f (one every %.1f s)." % [DEFAULT_BASE_RATE, BalanceData.WEAPON_INTERVAL])
	var dps_box := VBoxContainer.new()
	dps_box.add_theme_constant_override("separation", 2)
	dps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dps_caption := Label.new()
	dps_caption.text = "Base DPS"
	dps_caption.add_theme_font_size_override("font_size", 12)
	dps_caption.add_theme_color_override("font_color", MUTED)
	dps_box.add_child(dps_caption)
	base_dps_label = Label.new()
	base_dps_label.add_theme_font_size_override("font_size", 18)
	dps_box.add_child(base_dps_label)
	base_grid.add_child(dps_box)
	column.add_child(base_grid)
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 8)
	damage_spin = _stat_spin(stats, "Bonus damage", 0.0, 100.0, 0.5, "Flat damage added to the base damage (item bonus; capped at +50% of base).")
	rate_spin = _stat_spin(stats, "Attack speed %", 0.0, 200.0, 1.0, "Increased attacks per second.")
	speed_spin = _stat_spin(stats, "Projectile speed %", 0.0, 200.0, 1.0, "Saved on the weapon. The encounter currently fires every shot at the base speed.")
	column.add_child(stats)
	resolved_label = Label.new()
	resolved_label.add_theme_font_size_override("font_size", 13)
	resolved_label.add_theme_color_override("font_color", AMBER)
	resolved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(resolved_label)
	var loot_row := HBoxContainer.new()
	loot_check = CheckBox.new()
	loot_check.text = "Drops as loot"
	loot_check.tooltip_text = "Registers the weapon in the foundry loot table (item levels 1-3)."
	loot_check.toggled.connect(func(_on: bool) -> void: save_loot_setting())
	loot_row.add_child(loot_check)
	var weight_label := Label.new()
	weight_label.text = "weight"
	weight_label.add_theme_color_override("font_color", MUTED)
	loot_row.add_child(weight_label)
	loot_weight = _spin(0.1, 1000.0, 0.1)
	loot_weight.value_changed.connect(func(_value: float) -> void:
		if loot_check.button_pressed:
			save_loot_setting())
	loot_row.add_child(loot_weight)
	column.add_child(loot_row)
	return section

func _build_placement_section() -> Control:
	var section := _section("3  PLACEMENT")
	var column: VBoxContainer = section.get_meta("body")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	column.add_child(grid)
	_placement_spin(grid, "grip_x", "Grip X", 0.0, 1.0, 0.01)
	_placement_spin(grid, "grip_y", "Grip Y", 0.0, 1.0, 0.01)
	_placement_spin(grid, "world_scale", "Scale", 0.1, 4.0, 0.05)
	_placement_spin(grid, "rotation_degrees", "Rotation", -180.0, 180.0, 1.0)
	_placement_spin(grid, "offset_x", "Hand X", -256.0, 256.0, 1.0)
	_placement_spin(grid, "offset_y", "Hand Y", -256.0, 256.0, 1.0)
	var facing_label := Label.new()
	facing_label.text = "Art faces"
	facing_label.add_theme_color_override("font_color", MUTED)
	facing_label.add_theme_font_size_override("font_size", 13)
	grid.add_child(facing_label)
	facing_picker = OptionButton.new()
	facing_picker.add_item("right")
	facing_picker.add_item("left")
	facing_picker.item_selected.connect(func(_index: int) -> void: _mark_dirty())
	grid.add_child(facing_picker)
	var hint := Label.new()
	hint.text = "Tip: fine-tune placement in the arena by dragging the weapon while the hero holds it."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	return section

func _build_footer() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PLATE_2, EDGE, 0, 0, 10, [0, 1, 0, 0]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_label)
	remove_button = _button("Remove", true)
	remove_button.name = "Remove"
	remove_button.add_theme_color_override("font_color", BAD)
	remove_button.add_theme_color_override("font_hover_color", BAD)
	remove_button.pressed.connect(request_remove)
	row.add_child(remove_button)
	var save := _button("Save draft", true)
	save.name = "SaveDraft"
	save.pressed.connect(_on_save_pressed)
	row.add_child(save)
	test_button = _button("Test in arena")
	test_button.name = "TestInArena"
	test_button.pressed.connect(open_arena)
	row.add_child(test_button)
	publish_button = _button("Add to game")
	publish_button.name = "Publish"
	_amber(publish_button)
	publish_button.pressed.connect(_on_publish_pressed)
	row.add_child(publish_button)
	return bar

func _section(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("1b2024"), EDGE, 1, 4, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", AMBER)
	column.add_child(heading)
	panel.set_meta("body", column)
	return panel

func _field(caption: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _preview(caption: String, size: Vector2) -> TextureRect:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("2b3238"), EDGE, 1, 3, 4))
	box.add_child(frame)
	var image := TextureRect.new()
	image.custom_minimum_size = size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(image)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	label.custom_minimum_size = Vector2(size.x, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return image

func _stat_spin(grid: GridContainer, caption: String, minimum: float, maximum: float, step: float, tooltip: String) -> SpinBox:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)
	var spin := _spin(minimum, maximum, step)
	spin.tooltip_text = tooltip
	spin.value_changed.connect(func(_value: float) -> void:
		_mark_dirty()
		_refresh_resolved())
	box.add_child(spin)
	grid.add_child(box)
	return spin

func _placement_spin(grid: GridContainer, key: String, caption: String, minimum: float, maximum: float, step: float) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	grid.add_child(label)
	var spin := _spin(minimum, maximum, step)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(_value: float) -> void:
		if _loading:
			return
		_sync_from_controls()
		_mark_dirty()
		world_preview.queue_redraw())
	grid.add_child(spin)
	placement_spins[key] = spin

func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.custom_minimum_size = Vector2(96, 0)
	return spin

func _button(text: String, ghost: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	if ghost:
		button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0), EDGE))
	return button

func _amber(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(AMBER_DEEP, AMBER))
	button.add_theme_stylebox_override("hover", _button_box(AMBER, Color("f7bb58")))
	button.add_theme_color_override("font_color", Color("15181b"))
	button.add_theme_color_override("font_hover_color", Color("15181b"))

func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _box(fill, border, 1, 3, 0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _theme() -> Theme:
	var theme: Theme = IndustrialThemeScript.create()
	theme.default_font_size = 15
	for type_name in ["Label", "Button", "LineEdit", "OptionButton", "PanelContainer", "CheckBox", "TextEdit"]:
		theme.set_font_size("font_size", type_name, 15)
	theme.set_constant("separation", "BoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	var button := _button_box(Color("26313a"), Color("50606b"))
	theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate()
	hover.bg_color = Color("34434d")
	hover.border_color = AMBER
	theme.set_stylebox("hover", "Button", hover)
	var pressed := button.duplicate()
	pressed.bg_color = Color("3a3322")
	pressed.border_color = AMBER
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_color("font_pressed_color", "Button", INK)
	var disabled := button.duplicate()
	disabled.bg_color = Color("1b2026")
	disabled.border_color = Color("323942")
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 2, 4, 0))
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(style_name, "OptionButton", theme.get_stylebox(style_name, "Button"))
	var field := _box(Color("15181b"), EDGE, 1, 3, 0)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), AMBER, 2, 3, 0))
	theme.set_stylebox("read_only", "LineEdit", _box(Color("1d2125"), Color("323942"), 1, 3, 0))
	theme.set_stylebox("normal", "TextEdit", field)
	theme.set_stylebox("focus", "TextEdit", _box(Color(0, 0, 0, 0), AMBER, 2, 3, 0))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "CheckBox", INK)
	return theme

func _box(fill: Color, border: Color, border_width: int, radius: int, padding: float, borders: Array = []) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	if borders.size() == 4:
		style.border_width_left = int(borders[0]) * maxi(1, border_width)
		style.border_width_top = int(borders[1]) * maxi(1, border_width)
		style.border_width_right = int(borders[2]) * maxi(1, border_width)
		style.border_width_bottom = int(borders[3]) * maxi(1, border_width)
	else:
		style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

# ---------- attack clip ----------

func current_clip() -> Dictionary:
	var clip: Variant = draft.get("attack_clip", {})
	return clip if WeaponClip.is_set(clip) else {}

func attack_interval() -> float:
	return float(resolved_stats().attack_interval)

## Opens the clip importer for a new clip.
func open_clip_importer() -> void:
	_sync_from_controls()
	clip_importer.start(str(draft.get("weapon_id", "")), hit_seconds(), attack_interval())

## Reopens the importer on the weapon's current clip project.
func edit_clip() -> bool:
	var project := str(current_clip().get("project", ""))
	if project.is_empty():
		_set_status("This clip has no importer project to edit (it was made elsewhere). Import it again instead.", BAD)
		return false
	_sync_from_controls()
	return clip_importer.load_project(project, str(draft.get("weapon_id", "")), hit_seconds(), attack_interval())

func remove_clip() -> void:
	draft["attack_clip"] = {}
	_mark_dirty()
	_refresh_clip_section()
	_set_status("Removed the attack clip. The hero uses its normal attack with this weapon again.")

func _on_clip_saved(clip: Dictionary) -> void:
	draft["attack_clip"] = clip.duplicate(true)
	_mark_dirty()
	_refresh_clip_section()
	var attacks := WeaponClip.attack_ranges(clip).size()
	_set_status("Attack clip saved: %d frames, %d attack%s. Try it with Test in arena." % [int(clip.frame_count), attacks, "" if attacks == 1 else "s (the hero alternates between them)"], GOOD)

func _clip_texture(clip: Dictionary) -> Texture2D:
	var path := WeaponClip.sheet_path(clip)
	if not _clip_textures.has(path):
		_clip_textures[path] = WeaponClip.load_sheet(clip)
	return _clip_textures[path]

func _build_clip_section() -> Control:
	var section := _section("6  ATTACK CLIP")
	var column: VBoxContainer = section.get_meta("body")
	var intro := Label.new()
	intro.text = "A drawn attack animation for this weapon, from a pose sheet (like a ChatGPT animation sheet), frame images, or a video. It can show the whole hero swinging (replacing the hero's attack while this weapon is equipped) or just the weapon. One clip can hold a combo: the hero alternates between its attacks."
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("0f1215"), EDGE, 1, 3, 0))
	row.add_child(frame)
	clip_preview = Control.new()
	clip_preview.name = "ClipPreview"
	clip_preview.custom_minimum_size = Vector2(220, 200)
	clip_preview.draw.connect(_draw_clip_preview)
	frame.add_child(clip_preview)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	clip_summary = Label.new()
	clip_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clip_summary.add_theme_font_size_override("font_size", 13)
	side.add_child(clip_summary)
	var buttons := HBoxContainer.new()
	side.add_child(buttons)
	var import_button := _button("Import clip...")
	import_button.name = "ImportClip"
	import_button.tooltip_text = "Open the clip importer: slice a pose sheet, cut out every frame, line them up, and set the hit frame."
	import_button.pressed.connect(open_clip_importer)
	buttons.add_child(import_button)
	clip_edit_button = _button("Edit clip...")
	clip_edit_button.tooltip_text = "Reopen this clip in the importer."
	clip_edit_button.pressed.connect(func() -> void: edit_clip())
	buttons.add_child(clip_edit_button)
	clip_remove_button = _button("Remove clip", true)
	clip_remove_button.pressed.connect(remove_clip)
	buttons.add_child(clip_remove_button)
	return section

func _refresh_clip_section() -> void:
	if clip_summary == null:
		return
	var clip := current_clip()
	clip_edit_button.disabled = clip.is_empty() or str(clip.get("project", "")).is_empty()
	clip_remove_button.disabled = clip.is_empty()
	if clip.is_empty():
		clip_summary.text = "No clip. The hero uses its normal attack and the swing above."
		clip_summary.add_theme_color_override("font_color", MUTED)
	else:
		var normalized := WeaponClip.normalize(clip)
		var lines: Array = ["%s: %s, %d frames%s." % [str(normalized.label), str(WeaponClip.MODE_LABELS.get(str(normalized.mode), "")).to_lower(), int(normalized.frame_count), "" if str(clip.get("source", "")).is_empty() else " (not published yet)"]]
		var interval := attack_interval()
		for index in range(WeaponClip.attack_ranges(normalized).size()):
			var line := WeaponClip.timeline(normalized, index, hit_seconds())
			var text := "Attack %d: %s" % [index + 1, WeaponClip.describe_attack(normalized, index, hit_seconds())]
			if float(line.length) > interval + 0.001:
				text += ". Longer than the %.2f s between attacks: the next attack cuts it off." % interval
			lines.append(text)
		if str(normalized.mode) == "hero":
			lines.append("While it plays the held weapon is hidden (effects still show).")
		clip_summary.text = "\n".join(lines)
		clip_summary.add_theme_color_override("font_color", INK)
	clip_preview.queue_redraw()

## Loops the clip's combo in the preview box.
func _draw_clip_preview() -> void:
	var rect := Rect2(Vector2.ZERO, clip_preview.size)
	var clip := current_clip()
	var texture := _clip_texture(clip) if not clip.is_empty() else null
	if texture == null:
		clip_preview.draw_string(ThemeDB.fallback_font, Vector2(12, rect.size.y * 0.5), "No clip", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		return
	var normalized := WeaponClip.normalize(clip)
	var lines: Array = []
	var total := 0.0
	for index in range(WeaponClip.attack_ranges(normalized).size()):
		var line := WeaponClip.timeline(normalized, index, hit_seconds())
		lines.append(line)
		total += maxf(float(line.length), attack_interval())
	var t := fmod(clip_time, maxf(0.05, total))
	var frame := -1
	var number := 0
	for line in lines:
		var span := maxf(float(line.length), attack_interval())
		if t < span:
			frame = WeaponClip.frame_at(line, t)
			break
		t -= span
		number += 1
	var cell: Array = normalized.cell
	var cell_size := Vector2(float(cell[0]), float(cell[1]))
	var fit := minf((rect.size.x - 12.0) / cell_size.x, (rect.size.y - 24.0) / cell_size.y)
	var origin := Vector2((rect.size.x - cell_size.x * fit) * 0.5, 4.0)
	var anchor: Array = normalized.anchor
	var ground := origin.y + float(anchor[1]) * fit
	clip_preview.draw_line(Vector2(8, ground), Vector2(rect.size.x - 8, ground), Color(EDGE, 0.9), 1.0)
	if frame < 0:
		frame = int(lines[mini(number, lines.size() - 1)].frames[0]) if not lines.is_empty() else 0
	clip_preview.draw_texture_rect_region(texture, Rect2(origin, cell_size * fit), WeaponClip.frame_rect(normalized, frame))
	clip_preview.draw_string(ThemeDB.fallback_font, Vector2(8, rect.size.y - 6), "attack %d  frame %d" % [mini(number, lines.size() - 1) + 1, frame + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
