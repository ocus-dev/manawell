extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const UiPreviewFixturesScript = preload("res://scripts/ui/ui_preview_fixtures.gd")
const CombatPreviewScript = preload("res://scripts/ui/combat_preview.gd")

var harvest_count: int = 0
var ability_ids: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview: Control = CombatPreviewScript.new()
	root.add_child(preview)
	preview.harvest_requested.connect(_on_harvest_requested)
	preview.ability_requested.connect(_on_ability_requested)
	var extracting: Dictionary = UiPreviewFixturesScript.make("extracting").view_state.duplicate(true)
	extracting.combat.abilities = {"dash_cooldown_remaining": 2.0, "pulse_cooldown_remaining": 0.0}
	extracting.combat.active = true
	preview.size = Vector2(1280, 720)
	preview.configure(extracting)
	assert(TestCheckScript.check(preview.get_node("SurvivalWidget").find_child("Hero", true, false).text == "Hero", "hero health remains visible"))
	assert(TestCheckScript.check(preview.get_node("SurvivalWidget").find_child("Harvester", true, false).text == "Harvester", "harvester health remains visible"))
	assert(TestCheckScript.check(preview.get_node("PressureWidget/PressureContent/NextSurge").text.begins_with("Next surge:"), "pressure uses next-surge label"))
	assert(TestCheckScript.check(preview.get_node("ExtractionWidget/ExtractionContent/AtRisk").text.begins_with("At risk:"), "at-risk payout is explicit"))
	assert(TestCheckScript.check(preview.get_node("ExtractionWidget/ExtractionContent/Harvest").text == "Harvest [E]", "harvest action is visible"))
	assert(TestCheckScript.check(preview.get_node("AbilityBar/AbilityContent/Dash").disabled, "dash cooldown disables dash"))
	assert(TestCheckScript.check(not preview.get_node("AbilityBar/AbilityContent/Pulse").disabled, "ready pulse remains available"))
	preview.get_node("AbilityBar/AbilityContent/Pulse").emit_signal("pressed")
	assert(TestCheckScript.check(ability_ids == ["pulse"], "ability emits stable ID"))
	preview.size = Vector2(1920, 1080)
	assert(TestCheckScript.check(preview.get_node("SurvivalWidget").global_position.x >= 0.0, "survival remains in viewport at large target"))
	var sealing: Dictionary = UiPreviewFixturesScript.make("sealing").view_state
	preview.configure(sealing)
	var sealing_button: Button = preview.get_node("ExtractionWidget/ExtractionContent/Harvest")
	assert(TestCheckScript.check(sealing_button.disabled, "sealing disables repeat harvest"))
	assert(TestCheckScript.check(sealing_button.text.begins_with("Sealing..."), "sealing shows remaining defense time"))
	assert(TestCheckScript.check(preview.get_node("ExtractionWidget/ExtractionContent/AtRisk").text != "At risk: 0 mana", "sealing keeps locked payout visible"))
	var paused: Dictionary = UiPreviewFixturesScript.make("paused_recovery").view_state
	var paused_surge: String = "Next surge: %.1fs · paused" % float(paused.combat.next_surge_seconds)
	preview.configure(paused)
	assert(TestCheckScript.check(preview.get_node("PressureWidget/PressureContent/NextSurge").text == paused_surge, "paused pressure timer is state-derived"))
	assert(TestCheckScript.check(preview.get_node("CombatWallet").find_child("Pause", true, false).text == "Resume", "paused combat exposes resume"))
	assert(TestCheckScript.check(harvest_count == 0, "preview configuration does not dispatch harvest"))
	print("combat_widgets: survival=verified pressure=truthful extraction=sealing-safe abilities=verified targets=1280x720+1920x1080")
	quit(0)

func _on_harvest_requested() -> void:
	harvest_count += 1

func _on_ability_requested(ability_id: String) -> void:
	ability_ids.append(ability_id)
