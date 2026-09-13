extends SceneTree

const TestCheckScript = preload("res://tests/test_check.gd")
const CatalogScript = preload("res://scripts/model/research_catalog.gd")
const ResolverScript = preload("res://scripts/model/research_resolver.gd")

func _init() -> void:
	assert(TestCheckScript.check(CatalogScript.validate().valid, "research catalog validates"))
	var zero := ResolverScript.resolve_harvest(2.0, {})
	assert(TestCheckScript.check(is_equal_approx(zero.mean_output_per_second, 2.0), "rank-zero harvest parity"))
	var harvest := ResolverScript.resolve_harvest(2.0, {"harvest.amount": 2, "harvest.cadence": 1})
	assert(TestCheckScript.check(is_equal_approx(harvest.mean_output_per_second, 3.45), "harvest formula"))
	var standard := ResolverScript.resolve_weapon({})
	var fan := ResolverScript.resolve_weapon({"weapon.shots": 1}, "weapon.fan")
	var lance := ResolverScript.resolve_weapon({"weapon.damage": 2, "weapon.velocity": 2}, "weapon.lance")
	assert(TestCheckScript.check(standard.projectile_count == 1 and is_equal_approx(standard.damage, 10.0), "rank-zero weapon parity"))
	assert(TestCheckScript.check(fan.projectile_count == 3 and is_equal_approx(fan.damage, 6.5), "fan mode"))
	assert(TestCheckScript.check(lance.pierce_count == 1 and is_equal_approx(lance.attacks_per_second, 1.4166666), "lance mode"))
	assert(TestCheckScript.check(not ResolverScript.validate_ranks({"weapon.shots": 3}).valid, "rank bounds"))
	print("research_resolver: catalog=valid formulas=verified modes=exclusive bounds=verified")
	quit()
