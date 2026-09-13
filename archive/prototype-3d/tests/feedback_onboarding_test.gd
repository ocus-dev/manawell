extends SceneTree

const RunStateScript = preload("res://scripts/model/run_state.gd")

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	_test_guidance_and_outcomes()
	_test_developer_sealing_setting()
	quit(0)

func _test_guidance_and_outcomes() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	get_root().add_child(controller)
	assert(controller.developer_setting_button == null)
	assert(controller.status_label.text.contains("Move with WASD"))
	controller.request_start_or_harvest()
	assert(controller.status_label.text.contains("TANK AT RISK"))
	controller.tick(1.0)
	controller.request_start_or_harvest()
	assert(controller.run_state.phase == RunStateScript.Phase.SEALING)
	assert(controller.status_label.text.contains("SEALING DANGER"))
	assert(controller.reason_label.text.contains("not safe yet"))
	controller.tick(1.0)
	assert(controller.run_state.phase == RunStateScript.Phase.SEALING)
	assert(controller.status_label.text.contains("SEALING DANGER"))
	controller.tick(1.0)
	assert(controller.run_state.phase == RunStateScript.Phase.SUCCESS)
	assert(controller.status_label.text.contains("BANKED"))
	assert(controller.reason_label.text.contains("SUCCESS"))

	controller.retry()
	controller.run_state.apply_damage(RunStateScript.DamageTarget.MACHINE, 150.0)
	assert(controller.run_state.phase == RunStateScript.Phase.FAILED)
	controller.tick(0.0)
	assert(controller.status_label.text.contains("FAILED"))
	assert(controller.reason_label.text.contains("destroyed"))
	controller.free()

func _test_developer_sealing_setting() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.developer_mode = true
	controller.persistence_enabled = false
	controller.sealing_duration_setting = 0.0
	get_root().add_child(controller)
	assert(controller.developer_setting_button != null)
	controller.request_start_or_harvest()
	controller.request_start_or_harvest()
	assert(controller.run_state.sealing_duration == 0.0)
	controller.tick(0.0)
	assert(controller.run_state.phase == RunStateScript.Phase.SUCCESS)
	controller.free()
