extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")

func _init() -> void:
	var scene: Control = load("res://scenes/research_tuning.tscn").instantiate()
	root.add_child(scene)
	call_deferred("_run", scene)

func _run(scene: Control) -> void:
	assert(TestCheckScript.check(scene.preset_id == "standard", "tuning starts isolated"))
	scene.select_preset("fan")
	assert(TestCheckScript.check(scene.preset_id == "fan" and scene.readout.text.contains("3 projectile"), "fan preset readout"))
	scene.select_preset("lance")
	assert(TestCheckScript.check(scene.readout.text.contains("1 pierce"), "lance preset readout"))
	print("research_tuning: isolated=verified presets=standard/fan/lance/harvest verified")
	quit()