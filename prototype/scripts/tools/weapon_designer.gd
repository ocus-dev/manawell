class_name WeaponDesigner
extends Control

const Store = preload("res://scripts/tools/weapon_designer_store.gd")
const Publisher = preload("res://scripts/model/weapon_publisher.gd")
const Catalog = preload("res://scripts/model/weapon_catalog.gd")
const Definitions = preload("res://scripts/model/item_definitions.gd")
const Resolver = preload("res://scripts/model/hero_stat_resolver.gd")
const ThemeScript = preload("res://scripts/ui/industrial_theme.gd")

var draft: Dictionary = {}
var fields := {}
var affixes: Array[Dictionary] = []
var validation_label: Label
var job_label: Label
var preview_label: RichTextLabel
var draft_list: ItemList
var job_list: ItemList
var source_path: LineEdit
var description_edit: TextEdit

func _ready() -> void:
    theme = ThemeScript.create()
    draft = Store.default_draft("draft.new_weapon")
    _build()
    _apply_draft_to_controls()
    _refresh()

func _build() -> void:
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var margin := MarginContainer.new()
    for edge in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 18)
    scroll.add_child(margin)
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 14)
    margin.add_child(columns)
    var editor := VBoxContainer.new()
    editor.custom_minimum_size.x = 520
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(editor)
    editor.add_child(_heading("WEAPON AUTHORING", 20))
    source_path = _line(editor, "Source image", "source")
    source_path.placeholder_text = "repository path or prepared source"
    editor.add_child(_heading("CROP", 14))
    _spin(editor, "Crop X", "crop_x", 0, 10000, 1)
    _spin(editor, "Crop Y", "crop_y", 0, 10000, 1)
    _spin(editor, "Crop width", "crop_w", 0, 10000, 1)
    _spin(editor, "Crop height", "crop_h", 0, 10000, 1)
    _line(editor, "Weapon name", "label")
    description_edit = TextEdit.new()
    description_edit.placeholder_text = "Plain-text description"
    description_edit.custom_minimum_size.y = 74
    description_edit.text_changed.connect(func(): draft.description = description_edit.text; _refresh())
    editor.add_child(_label("DESCRIPTION"))
    editor.add_child(description_edit)
    _option(editor, "Supported behavior", "behavior_id", Catalog.SUPPORTED_BEHAVIOR_IDS)
    editor.add_child(_heading("BASE STATS", 14))
    _stat_control(editor, "attack_damage", "Attack damage", "flat", 0.0)
    _stat_control(editor, "attacks_per_second", "Attacks / sec", "increased", 0.0)
    _stat_control(editor, "projectile_speed", "Projectile speed", "increased", 0.0)
    _option(editor, "Rarity", "rarity", ["common", "magic", "rare", "epic"])
    _spin(editor, "Item level", "item_level", 1, 99, 1)
    editor.add_child(_heading("EXPLICIT AFFIXES", 14))
    for index in range(3):
        _affix_control(editor, index)
    editor.add_child(_heading("GRIP / WORLD SCALE", 14))
    _spin(editor, "Grip X", "grip_x", 0.0, 1.0, 0.01)
    _spin(editor, "Grip Y", "grip_y", 0.0, 1.0, 0.01)
    _spin(editor, "World scale", "world_scale", 0.1, 4.0, 0.05)
    _option(editor, "Facing", "facing", ["right", "left"])
    var actions := HBoxContainer.new()
    editor.add_child(actions)
    var save := Button.new()
    save.text = "Save draft"
    save.pressed.connect(_save_draft)
    actions.add_child(save)
    var prepare := Button.new()
    prepare.text = "Prepare art"
    prepare.pressed.connect(_start_job)
    actions.add_child(prepare)
    var add_button := Button.new()
    add_button.text = "Add to game"
    add_button.pressed.connect(_publish)
    actions.add_child(add_button)
    validation_label = _label("")
    editor.add_child(validation_label)
    var side := VBoxContainer.new()
    side.custom_minimum_size.x = 320
    side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(side)
    side.add_child(_heading("PREVIEW", 20))
    preview_label = RichTextLabel.new()
    preview_label.bbcode_enabled = true
    preview_label.custom_minimum_size.y = 190
    side.add_child(preview_label)
    side.add_child(_heading("DRAFTS", 14))
    draft_list = ItemList.new()
    draft_list.custom_minimum_size.y = 100
    side.add_child(draft_list)
    var reopen := Button.new()
    reopen.text = "Reopen selected draft"
    reopen.pressed.connect(_reopen_draft)
    side.add_child(reopen)
    side.add_child(_heading("JOBS", 14))
    job_list = ItemList.new()
    job_list.custom_minimum_size.y = 130
    side.add_child(job_list)
    var resume := Button.new()
    resume.text = "Resume selected job"
    resume.pressed.connect(_resume_job)
    side.add_child(resume)
    job_label = _label("No running job selected.")
    side.add_child(job_label)

func _refresh() -> void:
    if validation_label == null:
        return
    var result := Store.validate_authored(draft)
    validation_label.text = "VALID" if result.valid else _diagnostic_text(result)
    validation_label.add_theme_color_override("font_color", Color("75d5a5") if result.valid else Color("f09a9a"))
    preview_label.text = _preview_text()
    draft_list.clear()
    for draft_id in Store.list_drafts():
        draft_list.add_item(draft_id)
    job_list.clear()
    for job_id in Store.list_job_receipts():
        job_list.add_item(job_id)

func _preview_text() -> String:
    var instance := {"instance_id": "designer-preview", "base_id": "core.heavy_breech", "rarity": "common", "item_level": int(draft.get("item_level", 1)), "implicit_modifiers": draft.get("base_modifiers", []).duplicate(true), "explicit_modifiers": draft.get("explicit_modifiers", []).duplicate(true)}
    var resolved := Resolver.resolve({}, {"designer-preview": instance}, {"weapon": "designer-preview"})
    return "[b]%s[/b]\n%s\n\nAttack: %.2f\nAttacks / sec: %.2f\nProjectile speed: %.2f\n\nIcon: %s\nEquipped-stat preview uses HeroStatResolver." % [draft.get("label", "New weapon"), draft.get("description", ""), resolved.stats.attack_damage, resolved.stats.attacks_per_second, resolved.stats.projectile_speed, str(draft.get("art", {}).get("icon", "prepared icon pending"))]

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
    var receipt := {"job_id": job_id, "draft_id": draft.draft_id, "status": "starting", "stage": "snapshot", "progress": 0.0, "failure": "", "source": source_path.text, "created_at": Time.get_datetime_string_from_system(true)}
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
    var process_id := OS.create_process("powershell", PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", runner, "start", "--job-id", job_id, "--source", source_path.text, "--root", ProjectSettings.globalize_path("res://../art/weapons/runs")]))
    receipt.status = "running" if process_id > 0 else "blocked"
    receipt.failure = "" if process_id > 0 else "worker could not be launched"
    Store.save_job_receipt(receipt)
    job_label.text = "Job %s: %s. The editor remains responsive; reopen to resume." % [job_id, receipt.status]
    _refresh()

func _publish() -> void:
    _sync_art()
    var job_id := str(draft.get("art", {}).get("job_id", ""))
    var receipt := Store.load_job_receipt(job_id)
    if job_id.is_empty() or receipt.get("status", "") != "complete":
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
        var process_id := OS.create_process("powershell", PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", runner, "resume", "--job-id", job_id, "--root", ProjectSettings.globalize_path("res://../art/weapons/runs")]))
        if process_id > 0:
            receipt.status = "running"
            receipt.failure = ""
            Store.save_job_receipt(receipt)
    job_label.text = "Job %s: %s, stage %s, %.0f%%\n%s" % [job_id, receipt.get("status", "unknown"), receipt.get("stage", "unknown"), float(receipt.get("progress", 0.0)) * 100.0, receipt.get("failure", "No failure details.")]

func _sync_art() -> void:
    draft.art.source = source_path.text
    draft.art.crop = [float(fields.get("crop_x", 0.0)), float(fields.get("crop_y", 0.0)), float(fields.get("crop_w", 0.0)), float(fields.get("crop_h", 0.0))]
    draft.art.grip = [float(fields.get("grip_x", 0.5)), float(fields.get("grip_y", 0.75))]
    draft.art.world_scale = float(fields.get("world_scale", 1.0))

func _apply_draft_to_controls() -> void:
    if source_path == null:
        return
    source_path.text = str(draft.get("art", {}).get("source", ""))
    description_edit.text = str(draft.get("description", ""))
    for key in ["label"]:
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

func _line(parent: Control, title: String, key: String) -> LineEdit:
    parent.add_child(_label(title.to_upper()))
    var line := LineEdit.new()
    parent.add_child(line)
    fields[key] = line
    line.text_changed.connect(func(value: String): draft[key] = value; _refresh())
    return line

func _option(parent: Control, title: String, key: String, values: Array) -> OptionButton:
    parent.add_child(_label(title.to_upper()))
    var option := OptionButton.new()
    for value in values:
        option.add_item(value)
    option.select(maxi(0, values.find(draft.get(key, values[0]))))
    parent.add_child(option)
    fields[key] = option
    option.item_selected.connect(func(index: int): draft[key] = option.get_item_text(index); _refresh())
    return option

func _spin(parent: Control, title: String, key: String, minimum: float, maximum: float, step: float) -> SpinBox:
    parent.add_child(_label(title.to_upper()))
    var spin := SpinBox.new()
    spin.min_value = minimum; spin.max_value = maximum; spin.step = step
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