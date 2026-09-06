extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const InteractionProbeScript = preload("res://tests/interaction_probe.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	controller.account_state.roster_heroes["hero_2"] = true
	controller.account_state.hero_assignments["hero_1"] = {"role": "reserve", "well_id": ""}
	controller.account_state.hero_assignments["hero_2"] = {"role": "active", "well_id": ""}
	controller.account_state.commissioned_wells["well_1"] = true
	controller._update_hud()
	await _settle()

	var hud: Control = controller.encounter_hud
	var card: Control = hud.operations.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_1")
	var assign_button: Button = card.get_node("WellCardContent/GuardSlot/HeroSlotContent/GuardAction")
	assert(InteractionProbeScript.assert_interactable(assign_button, "Assign guard button"))
	assert(InteractionProbeScript.hover_and_click(self, assign_button, "Assign guard button"))
	await _settle()
	assert(TestCheckScript.check(hud.operations.hero_picker.visible, "Assign guard click opens picker"))

	var hero_action: Button = hud.operations.hero_picker.get_node("PickerContent/HeroRows/HeroRow_hero_1/HeroRowContent/HeroAction")
	assert(TestCheckScript.check(not hero_action.disabled, "reserve hero can be assigned"))
	var active_action: Button = hud.operations.hero_picker.get_node("PickerContent/HeroRows/HeroRow_hero_2/HeroRowContent/HeroAction")
	assert(TestCheckScript.check(active_action.disabled, "active expedition hero cannot be assigned as guard"))
	assert(TestCheckScript.check(active_action.text == "Active hero", "active hero explains guard restriction"))
	assert(InteractionProbeScript.assert_interactable(hero_action, "Hero 1 Assign button"))
	assert(InteractionProbeScript.hover_and_click(self, hero_action, "Hero 1 Assign button"))
	await _settle()
	assert(TestCheckScript.check(controller.account_state.get_guard_for_well("well_1") == "hero_1", "pointer assignment updates guard"))
	assert(TestCheckScript.check(not hud.operations.hero_picker.visible, "successful assignment closes picker"))
	print("guard_interaction: pointer=open+assign=verified")
	controller.queue_free()
	quit(0)

func _settle() -> void:
	for frame in range(6):
		await process_frame
