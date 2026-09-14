extends SceneTree
const Combat = preload("res://simulation/experiments/combat_model.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _init() -> void:
	var model := Combat.new()
	var player := {"damage": 10.0, "attack_interval": 1.0, "projectile_count": 1, "pulse_enabled": false, "hero_health": 100.0, "machine_integrity": 150.0}
	var one := model.simulate({"waves": [[{"kind": "pursuer", "hp": 10.0}]], "horizon_seconds": 2.0}, player, 7)
	check(one.kills == 1 and one.attacks_fired == 1, "one-shot threshold uses actual cadence")
	var two := model.simulate({"waves": [[{"kind": "pursuer", "hp": 11.0}]], "horizon_seconds": 2.1}, player, 7)
	check(two.kills == 1 and two.attacks_fired == 2, "two-shot threshold uses projectile damage")
	var cooldown := model.simulate({"waves": [[{"kind": "pursuer", "hp": 100.0}]], "horizon_seconds": 8.0}, {"damage": 1.0, "attack_interval": 1.0, "pulse_damage": 15.0, "pulse_cooldown": 4.0, "pulse_enabled": true}, 2)
	check(cooldown.pulses_fired == 2, "pulse fires on cooldown, not continuously")
	var waves := model.simulate({"waves": [[{"kind": "pursuer", "hp": 1.0}], [{"kind": "breaker", "hp": 1.0}]], "horizon_seconds": 4.0}, player, 3)
	check(waves.phase == "completed" and waves.wave_index == 2 and waves.kills == 2, "authored waves complete sequentially")
	var scaled := model.simulate({"waves": [[{"kind": "pursuer", "hp": 10.0}]], "stage_hp_multiplier": 2.0, "horizon_seconds": 2.0}, player, 4)
	check(scaled.kills == 0, "stage HP scaling does not auto-scale player stats")
	var boss := model.simulate({"waves": [["boss"]], "enemy_stats": {"boss": {"hp": 25.0, "damage": 7.0, "attack_interval": 2.0}}, "horizon_seconds": 3.1}, {"damage": 10.0, "attack_interval": 1.0, "pulse_enabled": false}, 5)
	check(boss.kills == 1 and is_equal_approx(boss.incoming_hero_damage, 7.0), "boss uses configured interval and damage")
	var fine := model.simulate({"waves": [[{"kind": "pursuer", "hp": 25.0}]], "tick_seconds": 0.1, "horizon_seconds": 10.0}, player, 9)
	var coarse := model.simulate({"waves": [[{"kind": "pursuer", "hp": 25.0}]], "tick_seconds": 0.5, "horizon_seconds": 10.0}, player, 9)
	check(fine.kills == coarse.kills and fine.phase == coarse.phase and absf(fine.time - coarse.time) <= 0.5, "timestep sensitivity is bounded for cadence events")
	var replay_a := model.simulate({"waves": [["pursuer", "ranged"]], "assumptions": {"targeting": "random"}}, {"damage": 3.0, "attack_interval": 0.7}, 99)
	var replay_b := model.simulate({"waves": [["pursuer", "ranged"]], "assumptions": {"targeting": "random"}}, {"damage": 3.0, "attack_interval": 0.7}, 99)
	check(JSON.stringify(replay_a) == JSON.stringify(replay_b), "random targeting is seeded and reproducible")
	print("combat_model_experiments: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
