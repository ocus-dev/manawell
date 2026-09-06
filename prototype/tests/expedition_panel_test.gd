extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const ExpeditionPanelScript = preload("res://scripts/ui/expedition_panel.gd")

var starts: int = 0
var selected_loadouts: Array[String] = []
var hero_changes: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel: Control = ExpeditionPanelScript.new()
	root.add_child(panel)
	panel.start_requested.connect(_on_start_requested)
	panel.loadout_requested.connect(_on_loadout_requested)
	panel.change_hero_requested.connect(_on_change_hero_requested)
	panel.configure({
		"active_hero_id": "hero_1",
		"active_hero_label": "Mara",
		"capability_summary": "Ready for active expeditions.",
		"destination_id": "well_2",
		"destination_label": "Deep Well",
		"base_extraction_rate": 2.5,
		"threat_summary": "Threat interval x1.20 · damage x1.40",
		"loadouts": [
			{"id": "standard", "label": "Standard", "summary": "Balanced extraction.", "selected": true, "available": true, "availability_reason": "Ready."},
			{"id": "overdrive", "label": "Overdrive", "summary": "Higher output, higher pressure.", "selected": false, "available": false, "availability_reason": "Commission Well 2 to unlock this loadout."},
			{"id": "fortified", "label": "Fortified", "summary": "More integrity, slower output.", "selected": false, "available": true, "availability_reason": "Ready."},
		],
		"start_available": true,
		"start_disabled_reason": "",
		"guard_warning": "Starting here recalls Sol and stops this well's passive income.",
	})
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/ControlledHero/HeroCopy/HeroName").text == "Mara", "active hero is displayed"))
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/Destination").text == "Deep Well", "destination summary uses player-facing label"))
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/GuardWarning").visible, "guard warning is visible"))
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/LoadoutChoices/Loadout_overdrive").disabled, "locked loadout is disabled"))
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/LoadoutChoices/Loadout_overdrive").tooltip_text == "Commission Well 2 to unlock this loadout.", "locked loadout explains why"))
	panel.select_loadout("fortified")
	assert(TestCheckScript.check(selected_loadouts == ["fortified"], "loadout selection emits its stable ID"))
	assert(TestCheckScript.check(starts == 0, "loadout selection does not start extraction"))
	panel.request_start()
	assert(TestCheckScript.check(starts == 1, "start button intent emits once"))
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_E
	key_event.pressed = true
	panel._input(key_event)
	assert(TestCheckScript.check(starts == 2, "E shortcut emits one additional start intent"))
	panel.get_node("ExpeditionPanelContent/ControlledHero/ChangeHero").emit_signal("pressed")
	assert(TestCheckScript.check(hero_changes == 1, "change hero emits intent"))
	panel.configure({"active_hero_label": "No hero selected", "capability_summary": "No expedition hero selected.", "loadouts": [], "start_available": false, "start_disabled_reason": "Choose an expedition hero first.", "guard_warning": ""})
	assert(TestCheckScript.check(panel.get_node("ExpeditionPanelContent/StartDisabledReason").text == "Choose an expedition hero first.", "disabled start explains missing hero"))
	panel.request_start()
	assert(TestCheckScript.check(starts == 2, "disabled start rejects command"))
	print("expedition_panel: hero=verified loadouts=definition-shaped launch=button+E guarded-warning=verified")
	quit(0)

func _on_start_requested() -> void:
	starts += 1

func _on_loadout_requested(loadout_id: String) -> void:
	selected_loadouts.append(loadout_id)

func _on_change_hero_requested() -> void:
	hero_changes += 1
