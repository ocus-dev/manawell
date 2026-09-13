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
	await _record_layout(preview, Vector2(1280, 720))
	assert(TestCheckScript.check(preview.get_node("SurvivalWidget").find_child("Hero", true, false).text == "Hero", "hero health remains visible"))
	assert(TestCheckScript.check(preview.get_node("SurvivalWidget").find_child("Harvester", true, false).text == "Harvester", "harvester health remains visible"))
	assert(TestCheckScript.check(preview.get_node("PressureWidget/PressureContent/NextSurge").text.begins_with("Next surge:"), "pressure uses next-surge label"))
	assert(TestCheckScript.check(preview.get_node("ExtractionWidget/ExtractionContent/AtRisk").text.begins_with("At risk:"), "at-risk payout is explicit"))
	assert(TestCheckScript.check(preview.get_node("ExtractionWidget/ExtractionContent/Harvest").text == "Harvest [E]", "harvest action is visible"))
	var dash = preview.get_node("AbilityBar/AbilityContent/Dash")
	var pulse = preview.get_node("AbilityBar/AbilityContent/Pulse")
	assert(TestCheckScript.check(dash.text.is_empty() and pulse.text.is_empty(), "ability slots have no permanent text"))
	assert(TestCheckScript.check(dash.custom_minimum_size == Vector2(44, 44), "ability targets stay 44px square"))
	assert(TestCheckScript.check(dash.find_child("KeyBadge", true, false).text == "Space", "dash badge follows current action binding"))
	assert(TestCheckScript.check(pulse.find_child("KeyBadge", true, false).text == "Q", "pulse badge follows current action binding"))
	assert(TestCheckScript.check(dash.tooltip_text.contains("Dash (Space)"), "dash tooltip exposes name and binding"))
	assert(TestCheckScript.check(dash.disabled and dash.find_child("Cooldown", true, false).text == "2.0", "dash cooldown uses compact remaining label"))
	assert(TestCheckScript.check(not pulse.disabled and pulse.find_child("Cooldown", true, false).text.is_empty(), "ready pulse has no cooldown label"))
	pulse.emit_signal("pressed")
	assert(TestCheckScript.check(ability_ids == ["pulse"], "ability emits stable ID"))
	preview.size = Vector2(1920, 1080)
	await _record_layout(preview, Vector2(1920, 1080))
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

func _record_layout(preview: Control, viewport_size: Vector2) -> void:
	root.size = Vector2i(viewport_size)
	preview.size = viewport_size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var widgets := [preview.get_node("SurvivalWidget"), preview.get_node("PressureWidget"), preview.get_node("CombatWallet"), preview.get_node("ExtractionWidget")]
	for widget in widgets:
		var bounds: Rect2 = widget.get_global_rect()
		print("combat_bounds ", widget.name, " ", bounds)
		assert(TestCheckScript.check(viewport_rect.encloses(bounds), widget.name + " stays inside viewport"))
	assert(TestCheckScript.check(widgets[0].get_global_rect().end.y <= 64.0, "survival stays in top reserved band"))
	assert(TestCheckScript.check(widgets[1].get_global_rect().end.y <= 64.0, "pressure stays in top reserved band"))
	assert(TestCheckScript.check(widgets[3].get_global_rect().position.y >= viewport_size.y - 136.0, "extraction stays in bottom reserved band"))
	if "--capture-layout" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var suffix := str(int(viewport_size.x))
		root.get_texture().get_image().save_png("res://../work/reviews/combat-hud-" + suffix + ".png")

func _on_harvest_requested() -> void:
	harvest_count += 1

func _on_ability_requested(ability_id: String) -> void:
	ability_ids.append(ability_id)
