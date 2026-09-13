extends Control

const ResolverScript = preload("res://scripts/model/research_resolver.gd")

var preset_id := "standard"
var readout: Label
var presets := {
	"standard": {"ranks": {}, "mode": "weapon.standard"},
	"fan": {"ranks": {"weapon.damage": 1, "weapon.shots": 1, "weapon.rate": 1, "weapon.velocity": 1}, "mode": "weapon.fan"},
	"lance": {"ranks": {"weapon.damage": 2, "weapon.velocity": 2, "weapon.rate": 1}, "mode": "weapon.lance"},
	"fast_cycle": {"ranks": {"harvest.cadence": 3}, "mode": "weapon.standard"},
	"large_cycle": {"ranks": {"harvest.amount": 3}, "mode": "weapon.standard"},
}

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var heading := Label.new()
	heading.text = "RESEARCH TUNING // ISOLATED PROFILE"
	layout.add_child(heading)
	var buttons := HBoxContainer.new()
	for id in presets:
		var button := Button.new()
		button.text = str(id).replace("_", " ").capitalize()
		button.pressed.connect(select_preset.bind(id))
		buttons.add_child(button)
	layout.add_child(buttons)
	readout = Label.new()
	readout.name = "MeasuredReadout"
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(readout)
	select_preset("standard")

func select_preset(next_id: String) -> void:
	if not presets.has(next_id):
		return
	preset_id = next_id
	var preset: Dictionary = presets[next_id]
	var weapon: Dictionary = ResolverScript.resolve_weapon(preset.ranks, preset.mode)
	var harvest: Dictionary = ResolverScript.resolve_harvest(2.0, preset.ranks)
	readout.text = "Preset: %s\nExpected weapon: %.2f damage/projectile, %d projectile(s), %.2f attacks/sec, %.2f speed, %d pierce\nExpected harvest: %.2f mana/cycle, %.2f cycles/sec, %.2f mana/sec\nMeasured values are populated by the shared campaign controller when this scene is used for a live capture." % [preset_id, float(weapon.damage), int(weapon.projectile_count), float(weapon.attacks_per_second), float(weapon.projectile_speed), int(weapon.pierce_count), float(harvest.cycle_amount), 1.0 / float(harvest.cycle_interval), float(harvest.mean_output_per_second)]