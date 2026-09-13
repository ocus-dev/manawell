extends PopupPanel

signal hero_selected(hero_id: String, well_id: String)
signal guard_recall_requested(well_id: String)

var well_id := ""
var heading: Label
var income: Label
var guard: OptionButton
var status: Label
var snapshot: Array = []

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	heading = Label.new()
	content.add_child(heading)
	income = Label.new()
	income.add_theme_font_size_override("font_size", 22)
	content.add_child(income)
	guard = OptionButton.new()
	guard.item_selected.connect(func(index: int):
		var id := str(guard.get_item_metadata(index))
		if id.is_empty():
			guard_recall_requested.emit(well_id)
		else:
			hero_selected.emit(id, well_id))
	content.add_child(guard)
	status = Label.new()
	content.add_child(status)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(hide)
	content.add_child(close)

func configure(well: Dictionary, heroes: Array) -> void:
	well_id = str(well.id)
	heading.text = str(well.get("label", well_id))
	income.text = "%.1f mana / hour" % (float(well.get("passive_rate_per_minute", 0.0)) * 60.0)
	var current := str(well.get("guard", {}).get("id", ""))
	var next: Array = [well_id, current, heroes.duplicate(true)]
	if next != snapshot:
		snapshot = next
		guard.clear()
		guard.add_item("Guard: Unstaffed")
		guard.set_item_metadata(0, "")
		guard.select(0)
		for hero in heroes:
			var id := str(hero.id)
			guard.add_item(str(hero.label))
			var index := guard.item_count - 1
			guard.set_item_metadata(index, id)
			guard.set_item_disabled(index, id != current and not bool(hero.get("available_for_guard", false)))
			if id == current:
				guard.select(index)
	guard.disabled = not bool(well.get("available", false))
	status.text = "" if not guard.disabled else "Commission this well to assign a guard." if not bool(well.get("commissioned", false)) else "Production paused during extraction."
	status.visible = not status.text.is_empty()
