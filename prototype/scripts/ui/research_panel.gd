extends PanelContainer

signal purchase_requested(id: String, expected_rank: int, expected_cost: int)
signal equipment_requested(id: String)

var state: Dictionary = {}
var selected_id := "harvest.amount"
var group := "harvester"
var track_buttons := {}
var equipment_buttons := {}
var tabs := {}
var workspace: BoxContainer
var title: Label
var description: Label
var preview: Label
var reason: Label
var wallet: Label
var buy: Button
var details: VBoxContainer

func label(text: String, font_size: int = 14) -> Label:
    var result := Label.new()
    result.text = text
    result.add_theme_font_size_override("font_size", font_size)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return result

func _ready() -> void:
    name = "ResearchRegion"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    add_child(content)
    content.add_child(label("RESEARCH", 22))
    wallet = label("", 14)
    content.add_child(wallet)
    var tab_row := HBoxContainer.new()
    content.add_child(tab_row)
    for key in ["harvester", "weapons"]:
        var button := Button.new()
        button.text = "Harvester engineering" if key == "harvester" else "Weapons engineering"
        button.toggle_mode = true
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size.y = 40
        button.pressed.connect(_select_group.bind(key))
        tabs[key] = button
        tab_row.add_child(button)
    workspace = BoxContainer.new()
    workspace.add_theme_constant_override("separation", 20)
    content.add_child(workspace)
    var tracks := VBoxContainer.new()
    tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tracks.size_flags_stretch_ratio = 1.0
    workspace.add_child(tracks)
    for id in ["harvest.amount", "harvest.cadence", "weapon.damage", "weapon.rate", "weapon.shots", "weapon.velocity"]:
        var button := Button.new()
        button.name = "Track_" + id.replace(".", "_")
        button.custom_minimum_size = Vector2(220, 66)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.toggle_mode = true
        button.pressed.connect(_select_track.bind(id))
        tracks.add_child(button)
        track_buttons[id] = button
    details = VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.size_flags_stretch_ratio = 1.4
    details.add_theme_constant_override("separation", 10)
    workspace.add_child(details)
    title = label("", 20)
    description = label("")
    preview = label("", 14)
    reason = label("", 13)
    buy = Button.new()
    buy.name = "PurchaseResearch"
    buy.custom_minimum_size.y = 42
    buy.pressed.connect(_purchase)
    for control in [title, description, preview, reason, buy]:
        details.add_child(control)
    content.add_child(HSeparator.new())
    content.add_child(label("EQUIPPED SPECIALIZATION / switch freely between runs", 13))
    var equipment := HBoxContainer.new()
    content.add_child(equipment)
    for id in ["harvest.standard", "harvest.rapid_seal", "harvest.deep_draw", "weapon.standard", "weapon.fan", "weapon.lance"]:
        var button := Button.new()
        button.custom_minimum_size.y = 54
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_equip.bind(id))
        equipment.add_child(button)
        equipment_buttons[id] = button
    resized.connect(_layout)
    _layout()
    refresh(state)

func _layout() -> void:
    if workspace != null:
        workspace.vertical = size.x < 700

func _select_group(value: String) -> void:
    group = value
    selected_id = "harvest.amount" if value == "harvester" else "weapon.damage"
    refresh(state)

func _select_track(id: String) -> void:
    selected_id = id
    refresh(state)

func selected_track() -> Dictionary:
    for track in state.get("tracks", []):
        if track.id == selected_id:
            return track
    return {}

func refresh(value: Dictionary) -> void:
    state = value.duplicate(true)
    if buy == null:
        return
    wallet.text = "%d mana available  ·  Permanent, account-wide research" % int(state.get("banked_mana", 0))
    for key in tabs:
        tabs[key].set_pressed_no_signal(key == group)
    for track in state.get("tracks", []):
        var button: Button = track_buttons[track.id]
        button.visible = track.group == group
        button.set_pressed_no_signal(track.id == selected_id)
        var rank := int(track.rank)
        var maximum := int(track.max_rank)
        var progress := ""
        for i in range(maximum):
            progress += "● " if i < rank else "○ "
        button.text = "%s   %d/%d\n%s" % [track.label, rank, maximum, progress]
        button.tooltip_text = "Inspect %s" % track.label
    var track := selected_track()
    if not track.is_empty():
        title.text = str(track.label)
        var rank := int(track.rank)
        var maximum := int(track.max_rank)
        var node: Dictionary = track.nodes[mini(rank, maximum - 1)]
        description.text = "%s\nRank %d / %d" % [node.effect, rank, maximum]
        reason.text = "Fully researched." if rank == maximum else str(node.availability_reason)
        buy.disabled = rank == maximum or not bool(node.available)
        buy.text = "Fully researched" if rank == maximum else "Research rank %d  ·  %d mana" % [rank + 1, int(node.cost)]
        preview.text = str(track.get("comparison", ""))
    for choice in state.get("equipment_choices", []):
        var button: Button = equipment_buttons[choice.id]
        button.visible = str(choice.id).begins_with("harvest.") == (group == "harvester")
        button.disabled = not bool(choice.available) or bool(choice.equipped)
        button.text = str(choice.label) + "\n" + ("Equipped" if choice.equipped else "Equip" if choice.available else "Locked")
        button.tooltip_text = str(choice.reason) + "\n" + str(choice.get("effect", ""))

func _purchase() -> void:
    var track := selected_track()
    if track.is_empty() or buy.disabled:
        return
    var rank := int(track.rank)
    var node: Dictionary = track.nodes[rank]
    # Stop double submission until authoritative state arrives; never destroy controls.
    buy.disabled = true
    purchase_requested.emit(selected_id, rank, int(node.cost))

func _equip(id: String) -> void:
    equipment_requested.emit(id)
