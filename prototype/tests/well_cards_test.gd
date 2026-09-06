extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")

var destination_ids: Array[String] = []
var guard_picker_ids: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fresh: Control = _preview("fresh_account")
	var locked = fresh.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_2")
	assert(TestCheckScript.check(locked.get_node("WellCardContent/WellState").text == "Locked", "locked variant is labeled"))
	assert(TestCheckScript.check(locked.get_node("WellCardContent/PrepareButton").disabled, "locked well cannot prepare"))

	var available: Control = _preview("one_well_commissioned")
	var available_card = available.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_2")
	assert(TestCheckScript.check(available_card.get_node("WellCardContent/WellState").text == "Available", "available variant is labeled"))
	assert(TestCheckScript.check(not available_card.get_node("WellCardContent/PrepareButton").disabled, "available well can prepare"))

	var guarded_card = available.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_1")
	assert(TestCheckScript.check(guarded_card.get_node("WellCardContent/GuardSlot/HeroSlotContent/HeroCopy/HeroName").text == "Hero 2", "guard belongs to its well card"))
	assert(TestCheckScript.check(guarded_card.get_node("WellCardContent/GuardSlot/HeroSlotContent/HeroCopy/HeroRole").text == "Guard", "guard is not labeled active"))
	guarded_card.request_guard_picker()
	assert(TestCheckScript.check(guard_picker_ids == ["well_1"], "guard picker intent includes the well ID"))

	var empty: Control = _preview("both_commissioned")
	var empty_card = empty.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_2")
	assert(TestCheckScript.check(empty_card.get_node("WellCardContent/GuardSlot/HeroSlotContent/HeroCopy/HeroName").text == "Assign guard", "empty commissioned slot offers assignment"))

	var active: Control = _preview("extracting")
	var active_card = active.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_1")
	assert(TestCheckScript.check(active_card.get_node("WellCardContent/WellState").text == "Extracting", "active variant is labeled"))
	assert(TestCheckScript.check(active_card.get_node("WellCardContent/ActivityLabel").text.begins_with("You are here"), "active operator is activity information"))
	assert(TestCheckScript.check(active_card.get_node("WellCardContent/GuardSlot").visible == false, "active card does not show a guard slot"))

	var selected: Control = _preview("one_well_commissioned")
	var selected_card = selected.get_node("OperationsScroll/OuterMargin/OperationsContent/OperationsWorkspace/WellsResearchRegion/WellsRegion/WellsContent/WellCardsPlaceholder/WellCard_well_1")
	var selected_button = selected_card.prepare_button
	selected_card.refresh(selected.view_state.operations.wells[0])
	assert(TestCheckScript.check(selected_card.prepare_button == selected_button, "refresh preserves card controls and focus target"))
	assert(TestCheckScript.check(selected_card.prepare_button.text == "Selected destination", "refresh preserves selected destination"))
	selected_card.request_prepare()
	assert(TestCheckScript.check(destination_ids == ["well_1"], "prepare emits exactly one destination ID"))
	print("well_cards: states=locked+available+empty+guarded+active intents=well_ids")
	quit(0)

func _preview(fixture_id: String) -> Control:
	destination_ids.clear()
	guard_picker_ids.clear()
	var preview: Control = load("res://scenes/ui/operations_preview.tscn").instantiate()
	preview.fixture_id = fixture_id
	preview.destination_requested.connect(func(well_id: String): destination_ids.append(well_id))
	preview.guard_picker_requested.connect(func(well_id: String): guard_picker_ids.append(well_id))
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(1280, 720)
	return preview