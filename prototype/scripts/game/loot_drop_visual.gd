extends Node2D

# Cosmetic only: ownership is committed by the monster reward transaction.
# Drawn placeholders avoid texture imports and can be replaced with final sprites.
var controller: Node
var origin := Vector2.ZERO
var elapsed := 0.0
var slot := "weapon"
var rarity := "common"
var item_name := "Item"
var tint := Color("d5dbe0")
var caption: Label
var item_texture: Texture2D

func setup(owner_controller: Node, drop_position: Vector2, instance: Dictionary) -> void:
    controller = owner_controller
    origin = drop_position + Vector2(0, -24)
    position = origin
    rarity = str(instance.get("rarity", "common"))
    # definition_for covers the fixed items and weapons published from the Weapon Lab.
    var base: Dictionary = preload("res://scripts/model/item_catalog.gd").definition_for(str(instance.get("base_id", "")))
    slot = str(base.get("category", "weapon"))
    item_name = str(base.get("label", "Item"))
    item_texture = preload("res://scripts/ui/item_icons.gd").texture(str(instance.get("base_id", "")))
    tint = tint_for(rarity)
    z_index = 80
    add_to_group("loot_drop_visuals")
    caption = Label.new()
    caption.position = Vector2(-150, -57)
    caption.size = Vector2(300, 40)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caption.add_theme_font_size_override("font_size", 14)
    caption.add_theme_color_override("font_color", tint)
    caption.add_theme_color_override("font_outline_color", Color("10161e"))
    caption.add_theme_constant_override("outline_size", 5)
    caption.text = "%s %s" % [rarity.capitalize(), item_name]
    add_child(caption)

func _process(delta: float) -> void:
    if not is_instance_valid(controller):
        queue_free()
        return
    if controller.run_state.paused:
        return
    advance(delta)

func advance(delta: float) -> void:
    elapsed += delta
    var target: Vector2 = origin
    if is_instance_valid(controller.hero):
        target = controller.hero.position + Vector2(0, -42)
    if elapsed < 0.65:
        position = origin + Vector2(0, -sin(elapsed / 0.65 * PI) * 34)
    elif elapsed < 1.15:
        var t := clampf((elapsed - 0.65) / 0.5, 0, 1)
        position = origin.lerp(target, t * t)
    else:
        position = target + Vector2(0, -(elapsed - 1.15) * 22)
        caption.text = "Collected · %s" % item_name
        modulate.a = clampf((2.15 - elapsed) / 0.65, 0, 1)
    queue_redraw()
    if elapsed >= 2.15:
        queue_free()

const TINTS := {"common": Color("d5dbe0"), "magic": Color("69baff"), "rare": Color("ffd36c"), "epic": Color("c693ff")}

static func tint_for(item_rarity: String) -> Color:
    return TINTS.get(item_rarity, Color.WHITE)

func _draw() -> void:
    draw_orb(self, tint, item_texture, slot, elapsed >= 1.15)

## The drop orb, shared with the Dev Encyclopedia's preview: a rarity-tinted
## ring with the item's icon (or a drawn silhouette), a tick once collected.
static func draw_orb(canvas: CanvasItem, tint: Color, item_texture: Texture2D, slot: String, collected: bool = false, center: Vector2 = Vector2.ZERO) -> void:
    canvas.draw_circle(center, 22, Color(tint, 0.14))
    canvas.draw_arc(center, 20, 0, TAU, 32, Color(tint, 0.8), 2, true)
    if collected:
        canvas.draw_polyline(PackedVector2Array([center + Vector2(-8, 0), center + Vector2(-2, 6), center + Vector2(10, -7)]), tint, 3, true)
        return
    # Distinct silhouettes: gun, chest plate, six-toothed machine component.
    if item_texture != null:
        canvas.draw_texture_rect(item_texture, Rect2(center + Vector2(-28, -28), Vector2(56, 56)), false)
        return
    if slot == "weapon":
        canvas.draw_rect(Rect2(center + Vector2(-15, -8), Vector2(25, 12)), tint)
        canvas.draw_rect(Rect2(center + Vector2(9, -6), Vector2(9, 5)), tint)
        canvas.draw_rect(Rect2(center + Vector2(-8, 4), Vector2(7, 10)), tint)
        canvas.draw_line(center + Vector2(-11, -3), center + Vector2(5, -3), Color("18232d"), 3)
    elif slot == "hero":
        var points := PackedVector2Array()
        for point in [Vector2(-16,-12), Vector2(-6,-16), Vector2(0,-9), Vector2(6,-16), Vector2(16,-12), Vector2(12,0), Vector2(9,14), Vector2(-9,14), Vector2(-12,0)]:
            points.append(center + point)
        canvas.draw_colored_polygon(points, tint)
        canvas.draw_line(center + Vector2(0,-5), center + Vector2(0,9), Color("18232d"), 3)
    else:
        for i in range(6):
            var direction := Vector2.from_angle(i * TAU / 6)
            canvas.draw_line(center + direction * 8, center + direction * 17, tint, 7)
        canvas.draw_circle(center, 12, tint)
        canvas.draw_circle(center, 5, Color("18232d"))
