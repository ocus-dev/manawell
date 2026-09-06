extends SceneTree

const ProductionScript = preload("res://scripts/model/production.gd")

func _init() -> void:
	_test_baseline_and_guard_rates()
	_test_sequential_settlement_and_pause()
	_test_mutation_order_and_active_site()
	_test_offline_helpers()
	quit(0)

func _test_baseline_and_guard_rates() -> void:
	var production: RefCounted = ProductionScript.new()
	var commissioned: Dictionary = {"well_1": true}
	var assignments: Dictionary = {"hero_1": {"role": "guard", "well_id": "well_1"}}
	var result: Dictionary = production.settle(100.0, commissioned, assignments, {})
	assert(result["total"] == 0.0)
	result = production.settle(160.0, commissioned, assignments, {})
	assert(is_equal_approx(result["rates"]["well_1"], 0.4))
	assert(is_equal_approx(result["total"], 24.0))
	assignments["hero_1"] = {"role": "reserve", "well_id": ""}
	assignments["hero_2"] = {"role": "guard", "well_id": "well_1"}
	result = production.settle(220.0, commissioned, assignments, {})
	assert(is_equal_approx(result["rates"]["well_1"], 0.5))
	assert(is_equal_approx(result["total"], 30.0))

func _test_sequential_settlement_and_pause() -> void:
	var production: RefCounted = ProductionScript.new()
	var commissioned: Dictionary = {"well_1": true}
	var assignments: Dictionary = {"hero_1": {"role": "guard", "well_id": "well_1"}}
	production.settle(100.0, commissioned, assignments, {})
	var first_half: Dictionary = production.settle(130.0, commissioned, assignments, {})
	var paused: Dictionary = production.settle(130.0, commissioned, assignments, {})
	var second_half: Dictionary = production.settle(160.0, commissioned, assignments, {})
	assert(is_equal_approx(first_half["total"] + paused["total"] + second_half["total"], 24.0))
	var backwards: Dictionary = production.settle(120.0, commissioned, assignments, {})
	assert(backwards["elapsed"] == 0.0)
	assert(production.settlement_cursor == 160.0)

func _test_mutation_order_and_active_site() -> void:
	var production: RefCounted = ProductionScript.new()
	var commissioned: Dictionary = {"well_1": true, "well_2": true}
	var assignments: Dictionary = {
		"hero_1": {"role": "guard", "well_id": "well_1"},
		"hero_2": {"role": "guard", "well_id": "well_2"},
	}
	production.settle(0.0, commissioned, assignments, {})
	var before_change: Dictionary = production.settle(10.0, commissioned, assignments, {})
	assert(is_equal_approx(before_change["total"], 14.0))
	var active: Dictionary = production.settle(20.0, commissioned, assignments, {}, "well_1")
	assert(not active["rates"].has("well_1"))
	assert(is_equal_approx(active["total"], 10.0))
	var pumped: Dictionary = production.settle(30.0, commissioned, assignments, {"pump_1": true}, "well_1")
	assert(is_equal_approx(pumped["total"], 12.5))

func _test_offline_helpers() -> void:
	var rates: Dictionary = {"well_1": 0.4}
	assert(ProductionScript.offline_elapsed(100.0, 40.0) == 60.0)
	assert(ProductionScript.offline_elapsed(40.0, 100.0) == 0.0)
	assert(ProductionScript.offline_elapsed(90000.0, 0.0) == 86400.0)
	var result: Dictionary = ProductionScript.offline_settlement(100.0, 40.0, rates)
	assert(is_equal_approx(result["total"], 24.0))
