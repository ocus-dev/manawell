extends PanelContainer

signal item_inspected(id: String)
signal equip_requested(hero_id: String, slot: String, instance_id: String)
signal unequip_requested(hero_id: String, slot: String)
signal lock_toggled(instance_id: String, locked: bool)
signal discard_requested(instance_id: String, confirmed_name: String)

var state: Dictionary = {}
var selected_id := ""
var selected_hero_id := ""
var category := "all"
var sort_mode := "recent"
var query := ""
var buttons := {}
var filters := {}
var grid: GridContainer
var summary: Label
var search: LineEdit
var sort_select: OptionButton
var equipment_pane
var detail_pane
var empty_label: Label
var grid_scroll: ScrollContainer
var _records: Array[Dictionary] = []
var _signature := ""

func _label(value: String, font_size: int = 14) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _ready() -> void:
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    add_child(content)
    var heading := HBoxContainer.new()
    var title := _label("EQUIPMENT & INVENTORY", 20)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    heading.add_child(title)
    summary = _label("")
    summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    heading.add_child(summary)
    content.add_child(heading)
    var workspace := HBoxContainer.new()
    workspace.name = "InventoryWorkspace"
    workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
    workspace.add_theme_constant_override("separation", 10)
    content.add_child(workspace)
    equipment_pane = preload("res://scripts/ui/inventory_equipment_pane.gd").new()
    equipment_pane.custom_minimum_size.x = 240
    equipment_pane.hero_selected.connect(func(id: String): selected_hero_id = id; _refresh_panes())
    equipment_pane.item_selected.connect(_inspect)
    equipment_pane.unequip_requested.connect(func(hero_id: String, slot: String): unequip_requested.emit(hero_id, slot))
    workspace.add_child(equipment_pane)
    var stash := VBoxContainer.new()
    stash.name = "SharedInventory"
    stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stash.add_theme_constant_override("separation", 8)
    workspace.add_child(stash)
    var toolbar := HBoxContainer.new()
    search = LineEdit.new()
    search.placeholder_text = "Search items"
    search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search.text_changed.connect(func(value: String): query = value.strip_edges().to_lower(); _refresh_grid())
    toolbar.add_child(search)
    sort_select = OptionButton.new()
    for label in ["Recent", "Name", "Item level", "Rarity"]:
        sort_select.add_item(label)
    sort_select.item_selected.connect(func(index: int): sort_mode = ["recent", "name", "level", "rarity"][index]; _refresh_grid())
    toolbar.add_child(sort_select)
    stash.add_child(toolbar)
    var filter_row := HBoxContainer.new()
    for key in ["all", "weapon", "hero", "harvester"]:
        var button := Button.new()
        button.text = {"all": "All", "weapon": "Weapons", "hero": "Chassis", "harvester": "Utility"}[key]
        button.toggle_mode = true
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_filter.bind(key))
        filters[key] = button
        filter_row.add_child(button)
    stash.add_child(filter_row)
    grid_scroll = ScrollContainer.new()
    grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    grid_scroll.custom_minimum_size.y = 160
    stash.add_child(grid_scroll)
    grid = GridContainer.new()
    grid.columns = 5
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    grid_scroll.add_child(grid)
    empty_label = _label("No items yet. Defeat monsters to find equipment.")
    stash.add_child(empty_label)
    var help := _label("Select to compare · New: ●  Equipped: E  Locked: L", 12)
    stash.add_child(help)
    detail_pane = preload("res://scripts/ui/inventory_detail_pane.gd").new()
    detail_pane.custom_minimum_size.x = 282
    detail_pane.equip_requested.connect(func(hero_id: String, slot: String, id: String): equip_requested.emit(hero_id, slot, id))
    detail_pane.lock_toggled.connect(func(id: String, locked: bool): lock_toggled.emit(id, locked))
    detail_pane.discard_requested.connect(func(id: String, name_value: String): discard_requested.emit(id, name_value))
    workspace.add_child(detail_pane)
    grid_scroll.resized.connect(_layout)
    refresh(state)

func _layout() -> void:
    if grid != null:
        grid.columns = maxi(1, int((grid_scroll.size.x - 16) / 78))

func _filter(value: String) -> void:
    category = value
    _refresh_grid()

func _inspect(id: String) -> void:
    selected_id = id
    _refresh_grid()
    _refresh_panes()
    var record := _selected_record()
    if not record.is_empty():
        item_inspected.emit(str(record.get("instance_id", id)))

func _instance_records() -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    for item in state.get("items", []):
        for instance in item.get("instances", []):
            var record: Dictionary = instance.duplicate(true)
            record.merge({"label": item.get("label", record.get("base_id", "")), "glyph": item.get("glyph", "?"), "category": item.get("category", "all"), "description": item.get("description", "")})
            for hero in state.get("heroes", []):
                for slot in ["weapon", "hero", "harvester"]:
                    if str(hero.get("kit", {}).get(slot, "")) == str(record.get("instance_id", "")):
                        record["equipped_by"] = str(hero.get("label", hero.get("id", "")))
                        record["equipped_hero_id"] = str(hero.get("id", ""))
                        record["equipped_slot"] = slot
            records.append(record)
    return records

func _selected_record() -> Dictionary:
    if selected_id.is_empty():
        return {}
    for record in _records:
        if str(record.get("instance_id", "")) == selected_id or (str(record.get("instance_id", "")).begins_with("legacy:") and str(record.get("base_id", "")) == selected_id):
            return record
    return {}

func _sort_records(records: Array[Dictionary]) -> void:
    records.sort_custom(func(left: Dictionary, right: Dictionary):
        if sort_mode == "name" and left.get("label", "") != right.get("label", ""):
            return str(left.get("label", "")) < str(right.get("label", ""))
        if sort_mode == "level" and left.get("item_level", 0) != right.get("item_level", 0):
            return int(left.get("item_level", 0)) > int(right.get("item_level", 0))
        if sort_mode == "rarity":
            var ranks := {"common": 0, "magic": 1, "rare": 2, "epic": 3}
            if ranks.get(left.get("rarity", ""), 0) != ranks.get(right.get("rarity", ""), 0):
                return ranks.get(left.get("rarity", ""), 0) > ranks.get(right.get("rarity", ""), 0)
        return str(left.get("instance_id", "")) > str(right.get("instance_id", "")))

func _make_item_button(record: Dictionary) -> Button:
    var id := str(record.get("instance_id", ""))
    var button := Button.new()
    button.name = "Item_" + id.replace(".", "_").replace(":", "_")
    button.custom_minimum_size = Vector2(72, 76)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.icon = preload("res://scripts/ui/item_icons.gd").texture(str(record.get("base_id", "")))
    button.expand_icon = true
    button.add_theme_constant_override("icon_max_width", 56)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
    button.add_theme_font_size_override("font_size", 11)
    button.toggle_mode = true
    var selected_key := str(record.get("base_id", "")) if id.begins_with("legacy:") else id
    button.pressed.connect(_inspect.bind(selected_key))
    grid.add_child(button)
    buttons[id] = button
    var base_id := str(record.get("base_id", ""))
    if not buttons.has(base_id):
        buttons[base_id] = button
    return button

func _refresh_grid() -> void:
    if grid == null:
        return
    for key in filters:
        filters[key].set_pressed_no_signal(key == category)
    var records := _records.duplicate()
    _sort_records(records)
    var live := {}
    var count := 0
    for record in records:
        var id := str(record.get("instance_id", ""))
        live[id] = true
        var button: Button = buttons.get(id)
        if button == null:
            button = _make_item_button(record)
        grid.move_child(button, grid.get_child_count() - 1)
        button.visible = (category == "all" or record.get("category", "") == category) and (query.is_empty() or (str(record.get("label", "")) + " " + str(record.get("rarity", ""))).to_lower().contains(query))
        if button.visible:
            count += 1
        button.set_pressed_no_signal(str(_selected_record().get("instance_id", "")) == id)
        var markers := ""
        if not bool(record.get("inspected", true)):
            markers += "● "
        if not str(record.get("equipped_by", "")).is_empty():
            markers += "E "
        if bool(record.get("locked", false)):
            markers += "L "
        button.text = "%sLv %d" % [markers, int(record.get("item_level", 1))]
        button.tooltip_text = "%s · %s · Level %d\n%s" % [record.get("label", "Item"), str(record.get("rarity", "common")).capitalize(), int(record.get("item_level", 1)), record.get("description", "")]
        var color: Color = {"common": Color("75848d"), "magic": Color("65aaff"), "rare": Color("e6c36a"), "epic": Color("c18cff")}.get(record.get("rarity", "common"), Color("75848d"))
        for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
            var style := StyleBoxFlat.new()
            style.bg_color = Color("243441") if style_name.contains("pressed") else Color("17232c")
            style.border_color = Color.WHITE if style_name == "focus" else color
            style.set_border_width_all(2 if style_name != "normal" else 1)
            style.set_corner_radius_all(4)
            button.add_theme_stylebox_override(style_name, style)
    for child in grid.get_children():
        var found := false
        for id in live:
            if buttons.get(id) == child:
                found = true
                break
        if not found:
            child.visible = false
    empty_label.visible = count == 0
    empty_label.text = "No items yet. Defeat monsters to find equipment." if _records.is_empty() else "No items match these filters."
    _layout()

func _refresh_panes() -> void:
    var record := _selected_record()
    equipment_pane.refresh(state, _records, selected_hero_id, record)
    detail_pane.refresh(state, _records, selected_hero_id, record)

func refresh(value: Dictionary) -> void:
    state = value.duplicate(true)
    if summary == null:
        return
    var signature := JSON.stringify(state)
    if signature == _signature:
        return
    _signature = signature
    var heroes: Array = state.get("heroes", [])
    var valid_hero := false
    for hero in heroes:
        if str(hero.get("id", "")) == selected_hero_id:
            valid_hero = true
    if not valid_hero:
        selected_hero_id = str(state.get("selected_hero_id", ""))
        if selected_hero_id.is_empty() and not heroes.is_empty():
            selected_hero_id = str(heroes[0].get("id", ""))
    _records = _instance_records()
    if not selected_id.is_empty() and _selected_record().is_empty():
        selected_id = ""
    summary.text = "%d / %d items · %d new" % [int(state.get("stored_count", 0)), int(state.get("capacity", 100)), int(state.get("new_count", 0))]
    _refresh_grid()
    _refresh_panes()

func request_discard() -> void:
    detail_pane.request_discard()
