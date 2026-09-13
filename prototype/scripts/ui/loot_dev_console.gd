extends CanvasLayer

var controller: Node
var panel: PanelContainer
var command: LineEdit
var feedback: Label
var indicator: Label
var was_paused := false

func _ready() -> void:
    layer = 120
    panel = PanelContainer.new()
    panel.position = Vector2(24, 90)
    panel.custom_minimum_size = Vector2(560, 170)
    var box := VBoxContainer.new()
    panel.add_child(box)
    var help := Label.new()
    help.text = "DEVELOPMENT CONSOLE · F8 / Escape to close\nenable_all_levels\ndrop_rate 100 · drop_rate 10 · drop_rate reset"
    box.add_child(help)
    command = LineEdit.new()
    command.placeholder_text = "drop_rate 100"
    command.text_submitted.connect(_submit)
    box.add_child(command)
    feedback = Label.new()
    feedback.text = "Session override only. Collected test items save normally."
    box.add_child(feedback)
    add_child(panel)
    panel.hide()
    indicator = Label.new()
    indicator.position = Vector2(24, 68)
    indicator.add_theme_color_override("font_color", Color("ffd36c"))
    indicator.add_theme_color_override("font_outline_color", Color.BLACK)
    indicator.add_theme_constant_override("outline_size", 4)
    add_child(indicator)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F8 or (panel.visible and event.keycode == KEY_ESCAPE):
            if panel.visible:
                panel.hide()
                controller.run_state.paused = was_paused
            else:
                was_paused = controller.run_state.paused
                controller.run_state.paused = true
                for field in ["move_left_held", "move_right_held", "move_down_held", "jump_held", "pending_jump", "pending_dash", "pending_pulse", "pending_harvest", "pending_pause"]:
                    controller.set(field, false)
                panel.show()
                command.grab_focus()
            get_viewport().set_input_as_handled()

func _submit(value: String) -> void:
    feedback.text = controller.execute_loot_command(value)
    indicator.text = "DEV LOOT: %s%% per kill · F8" % str(controller.development_drop_percent) if controller.development_drop_percent >= 0 else ""
    command.clear()
