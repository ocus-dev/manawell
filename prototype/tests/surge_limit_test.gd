extends SceneTree

## Surge limit and the drill panel: surges climb one at a time on the normal
## timer, hold at the limit, and pick back up naturally when it is raised.

const RunStateScript = preload("res://scripts/model/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_run_state()
	_test_account_round_trip()
	await _test_controller()
	print("surge_limit: ok")
	quit(0)

func _advance(run: RefCounted, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.25, left)
		run.advance(step)
		left -= step

func _test_run_state() -> void:
	var run: RefCounted = RunStateScript.new()
	assert(run.start("run-1", "well_1", "hero_1", "standard", 2.0))
	# No limit: climbs every surge duration.
	_advance(run, BalanceData.SURGE_DURATION * 3.0 + 1.0)
	assert(run.completed_surges == 3)
	assert(not run.at_surge_limit())
	assert(is_equal_approx(run.mana_per_second(), 2.0 * BalanceData.multiplier_for(3)))
	# Limit 2 while at 3 drops back to 2.
	run.set_surge_limit(2)
	assert(run.completed_surges == 2 and run.at_surge_limit())
	assert(is_equal_approx(run.multiplier, BalanceData.multiplier_for(2)))
	_advance(run, BalanceData.SURGE_DURATION * 5.0)
	assert(run.completed_surges == 2, "holds at the limit")
	assert(run.seconds_to_next_surge() == 0.0)
	# Raising the limit continues naturally: no jump, next surge a full timer away.
	run.set_surge_limit(5)
	assert(run.completed_surges == 2)
	assert(is_equal_approx(run.seconds_to_next_surge(), BalanceData.SURGE_DURATION))
	_advance(run, BalanceData.SURGE_DURATION - 1.0)
	assert(run.completed_surges == 2)
	_advance(run, 2.0)
	assert(run.completed_surges == 3)
	_advance(run, BalanceData.SURGE_DURATION * 10.0)
	assert(run.completed_surges == 5)
	# Clearing the limit lets it climb again.
	run.set_surge_limit(0)
	_advance(run, BalanceData.SURGE_DURATION + 0.5)
	assert(run.completed_surges == 6)
	# A limit set from the start climbs 1, 2 then holds.
	var fresh: RefCounted = RunStateScript.new()
	assert(fresh.start("run-2", "well_1", "hero_1", "standard", 2.0))
	fresh.set_surge_limit(2)
	_advance(fresh, BalanceData.SURGE_DURATION * 1.0 + 0.5)
	assert(fresh.completed_surges == 1)
	_advance(fresh, BalanceData.SURGE_DURATION * 4.0)
	assert(fresh.completed_surges == 2)

func _test_account_round_trip() -> void:
	var account: RefCounted = AccountStateScript.new()
	account.set_surge_limit("well_1", 7)
	var payload: Dictionary = account.to_save_payload()
	var loaded: RefCounted = AccountStateScript.new()
	loaded.from_save_payload(payload)
	assert(loaded.get_surge_limit("well_1") == 7)
	assert(loaded.get_surge_limit("well_2") == 0)
	loaded.set_surge_limit("well_1", 0)
	assert(not loaded.to_save_payload()["surge_limits"].has("well_1"))

func _test_controller() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.selected_well_id = "well_1"
	controller.set_surge_limit(3)
	assert(controller.start_run())
	assert(controller.run_state.surge_limit == 3, "saved limit applies to a new run")
	# Advance the run clock directly (no enemies needed for the surge rules).
	for i in range(int(BalanceData.SURGE_DURATION * 6.0 / 0.5)):
		controller.run_state.advance(0.5)
	print("surges=", controller.run_state.completed_surges, " phase=", controller.run_state.phase)
	assert(controller.run_state.completed_surges == 3)
	controller._update_hud()
	# Clicking the drill opens its panel.
	var rect: Rect2 = controller.drill_rect()
	assert(rect.size.x > 0.0 and rect.size.y > 0.0)
	var click: Vector2 = controller.get_canvas_transform() * rect.get_center()
	assert(controller.handle_world_click(click))
	assert(controller.drill_panel_open)
	var drill: Dictionary = controller.drill_view()
	assert(drill.open and drill.running)
	assert(is_equal_approx(float(drill.mana_per_second), controller.run_state.extraction_rate * controller.run_state.multiplier))
	assert(int(drill.surge_limit) == 3)
	var panel = controller.encounter_hud.combat.drill_panel
	assert(panel.visible)
	assert(panel.rate_label.text.ends_with("mana/s"))
	# The + button raises the limit on the run and the saved setting.
	panel.plus_button.emit_signal("pressed")
	assert(controller.run_state.surge_limit == 4)
	assert(controller.account_state.get_surge_limit("well_1") == 4)
	# Clicking away from the drill does nothing; clicking it again closes.
	assert(not controller.handle_world_click(controller.get_canvas_transform() * (rect.end + Vector2(400, -300))))
	assert(controller.handle_world_click(click))
	assert(not controller.drill_panel_open)
	assert(not panel.visible)
	# The HUD surge box reads the limit.
	var pressure = controller.encounter_hud.combat.pressure_widget
	assert(pressure.multiplier_label.text.begins_with("SURGE 3 / 4"))
	controller.queue_free()
	await process_frame
