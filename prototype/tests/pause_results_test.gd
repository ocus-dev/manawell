extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const RouterScript = preload("res://scripts/ui/presentation_router.gd")
const RunStateScript = preload("res://scripts/model/run_state.gd")

var resumes: int = 0
var settings: int = 0
var abandons: int = 0
var returns: int = 0
var retries: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var router: Control = RouterScript.new()
	root.add_child(router)
	router.resume_requested.connect(_on_resume)
	router.settings_requested.connect(_on_settings)
	router.abandon_requested.connect(_on_abandon)
	router.return_requested.connect(_on_return)
	router.retry_requested.connect(_on_retry)
	var combat := {"at_risk_payout": 17, "paused": true}
	router.show_pause(combat)
	assert(TestCheckScript.check(router.mode == "pause", "pause mode is active"))
	assert(TestCheckScript.check(router.get_node("PausePanel").visible, "pause panel is visible"))
	assert(TestCheckScript.check(not router.get_node("ResultPanel").visible, "result panel is hidden during pause"))
	var pause_panel = router.get_node("PausePanel")
	pause_panel.request_abandon()
	pause_panel.get_node("PauseContent/AbandonConfirmation/ConfirmationContent/CancelAbandon").emit_signal("pressed")
	assert(TestCheckScript.check(abandons == 0, "cancel preserves the tank"))
	pause_panel.request_abandon()
	pause_panel.get_node("PauseContent/AbandonConfirmation/ConfirmationContent/ConfirmAbandon").emit_signal("pressed")
	assert(TestCheckScript.check(abandons == 1, "confirm abandons once"))
	pause_panel.request_abandon()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	pause_panel._input(escape)
	assert(TestCheckScript.check(abandons == 1 and pause_panel.confirmation.visible == false, "Escape closes child confirmation first"))
	pause_panel._input(escape)
	assert(TestCheckScript.check(resumes == 1, "Escape resumes only after child modal closes"))
	var success := {"outcome": "Harvest secured", "amount_label": "23 mana banked", "terminal_reason": "sealed", "completed_surges": 2, "can_retry": true, "passive_rate_per_minute": 91.0}
	router.show_results(success)
	assert(TestCheckScript.check(router.mode == "results", "results mode is active"))
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/Outcome").text == "Harvest secured", "success outcome is explicit"))
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/Amount").text == "23 mana banked", "result uses run reward"))
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/Cause").text == "Cause: Defense completed", "success cause is readable"))
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/RetrySameExpedition").disabled == false, "retry is available for terminal run"))
	router.get_node("ResultPanel/ResultContent/ReturnToOperations").emit_signal("pressed")
	assert(TestCheckScript.check(returns == 1 and retries == 0 and router.mode == "hidden", "return does not retry"))
	var failure := {"outcome": "Extraction lost", "amount_label": "0 mana lost", "terminal_reason": "machine_destroyed", "completed_surges": 1, "can_retry": true, "passive_rate_per_minute": 91.0}
	router.show_results(failure)
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/Amount").text == "0 mana lost", "failure does not use passive income delta"))
	assert(TestCheckScript.check(router.get_node("ResultPanel/ResultContent/Cause").text == "Cause: Harvester destroyed", "failure cause is readable"))
	router.get_node("ResultPanel/ResultContent/RetrySameExpedition").emit_signal("pressed")
	assert(TestCheckScript.check(retries == 1 and returns == 1, "retry is a distinct command"))
	assert(TestCheckScript.check(not router.get_node("PausePanel").visible and not router.get_node("ResultPanel").visible, "router never leaves two terminal overlays visible"))
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	controller.request_start_or_harvest()
	controller.tick(1.0)
	controller.request_start_or_harvest()
	controller.tick(2.0)
	assert(TestCheckScript.check(controller.run_state.phase == RunStateScript.Phase.SUCCESS, "controller reaches terminal success"))
	controller.return_to_operations()
	assert(TestCheckScript.check(controller.run_state.phase == RunStateScript.Phase.READY, "return command prepares without retrying"))
	controller.queue_free()
	print("pause_results: pause=verified confirmation=verified escape-order=verified outcomes=run-derived router=exclusive")
	quit(0)

func _on_resume() -> void:
	resumes += 1

func _on_settings() -> void:
	settings += 1

func _on_abandon() -> void:
	abandons += 1

func _on_return() -> void:
	returns += 1

func _on_retry() -> void:
	retries += 1
