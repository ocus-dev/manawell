extends RefCounted
## Discrete, seeded combat model for simulator experiments only.
## This is an attack-window model: it does not claim movement or collision fidelity.

const DEFAULT_ENEMIES := {
	"pursuer": {"hp": 20.0, "damage": 8.0, "attack_interval": 1.0, "attack_target": "hero"},
	"breaker": {"hp": 50.0, "damage": 12.0, "attack_interval": 1.0, "attack_target": "machine"},
	"ranged": {"hp": 25.0, "damage": 8.0, "attack_interval": 2.0, "attack_target": "hero"},
	"boss": {"hp": 240.0, "damage": 18.0, "attack_interval": 3.0, "attack_target": "hero"},
}

func step_external(state: Dictionary, enemies: Array, dt: float) -> Array:
	# The campaign/extraction director owns spawning and completion in this mode.
	state.enemies = enemies
	state.kill_events = []
	for foe in enemies:
		if not foe.has("id"):
			foe.id = state.next_enemy_id
			state.next_enemy_id += 1
			foe.attack_interval = foe.interval
			foe.attack_clock = foe.interval + float(state.scenario.assumptions.get("contact_delay", 3.0))
			foe.attack_target = "machine" if foe.kind == "breaker" and bool(state.scenario.get("is_well", false)) else "hero"
	state.time += dt
	_advance_projectiles(state, dt)
	_advance_hero_attacks(state, dt)
	_advance_enemy_attacks(state, dt)
	return state.kill_events

func begin(scenario_overrides: Dictionary, player_stats: Dictionary, seed: int = 1) -> Dictionary:
	var scenario := _defaults().merged(scenario_overrides, true)
	var state := {"seed": seed, "rng": RandomNumberGenerator.new(), "scenario": scenario,
		"player": _player_defaults().merged(player_stats, true), "time": 0.0, "phase": "combat",
		"wave_index": 0, "waves_spawned": 0, "enemies": [], "projectiles": [], "next_enemy_id": 1,
		"attack_clock": 0.0, "pulse_clock": 0.0, "sealing_remaining": 0.0,
		"hero_health": float(player_stats.get("hero_health", 100.0)),
		"machine_integrity": float(player_stats.get("machine_integrity", 150.0)),
		"incoming_hero_damage": 0.0, "incoming_machine_damage": 0.0, "kills": 0,
		"attacks_fired": 0, "pulses_fired": 0, "hit_count": 0}
	state.rng.seed = seed
	return state

func step(state: Dictionary, dt: float) -> Dictionary:
	if dt <= 0.0 or state.phase in ["completed", "failed"]: return snapshot(state)
	state.time += dt
	if state.phase == "combat":
		_spawn_wave_if_needed(state)
		_advance_projectiles(state, dt)
		_advance_hero_attacks(state, dt)
		_advance_enemy_attacks(state, dt)
		if state.phase == "combat" and state.wave_index >= _waves(state).size() and state.enemies.is_empty() and state.projectiles.is_empty():
			var seal := float(state.scenario.get("sealing_seconds", 0.0))
			if seal > 0.0: state.phase = "sealing"; state.sealing_remaining = seal
			else: state.phase = "completed"
	elif state.phase == "sealing":
		_advance_sealing(state, dt)
		if state.sealing_remaining <= 0.000001: state.phase = "completed"
	if state.hero_health <= 0.0 or state.machine_integrity <= 0.0: state.phase = "failed"
	return snapshot(state)

func simulate(scenario_overrides: Dictionary, player_stats: Dictionary, seed: int = 1) -> Dictionary:
	var state := begin(scenario_overrides, player_stats, seed)
	var tick := maxf(0.001, float(state.scenario.get("tick_seconds", 0.1)))
	var horizon := maxf(0.0, float(state.scenario.get("horizon_seconds", 300.0)))
	while state.phase not in ["completed", "failed"] and state.time < horizon: step(state, minf(tick, horizon - state.time))
	var result := snapshot(state)
	result["censored"] = state.phase not in ["completed", "failed"]
	return result

func snapshot(state: Dictionary) -> Dictionary:
	return {"time": state.time, "phase": state.phase, "alive_enemies": state.enemies.size(),
		"incoming_hero_damage": state.incoming_hero_damage, "incoming_machine_damage": state.incoming_machine_damage,
		"kills": state.kills, "attacks_fired": state.attacks_fired, "pulses_fired": state.pulses_fired,
		"hit_count": state.hit_count, "wave_index": state.wave_index, "waves_spawned": state.waves_spawned,
		"hero_health": state.hero_health, "machine_integrity": state.machine_integrity,
		"assumptions": state.scenario.get("assumptions", {})}

func _defaults() -> Dictionary:
	return {"waves": [["pursuer"]], "enemy_stats": {}, "stage_hp_multiplier": 1.0,
		"stage_damage_multiplier": 1.0, "wave_expansion": 1, "tick_seconds": 0.1, "horizon_seconds": 300.0,
		"sealing_seconds": 0.0, "assumptions": {"travel_seconds": 0.0, "targeting": "front", "avoidance": 0.0, "damage_uptime": 1.0}}

func _player_defaults() -> Dictionary:
	return {"damage": 10.0, "attack_interval": 0.6, "projectile_count": 1, "hero_health": 100.0, "machine_integrity": 150.0,
		"pulse_enabled": true, "pulse_damage": 15.0, "pulse_cooldown": 8.0}

func _waves(state: Dictionary) -> Array: return state.scenario.get("waves", [])

func _spawn_wave_if_needed(state: Dictionary) -> void:
	if not state.enemies.is_empty() or not state.projectiles.is_empty() or state.wave_index >= _waves(state).size(): return
	var authored = _waves(state)[state.wave_index]
	var expansion := maxi(1, int(state.scenario.get("wave_expansion", 1)))
	for _copy in range(expansion):
		for entry in authored: state.enemies.append(_enemy_spec(entry, state))
	state.wave_index += 1; state.waves_spawned += 1

func _enemy_spec(entry, state: Dictionary) -> Dictionary:
	var kind := str(entry) if not entry is Dictionary else str(entry.get("kind", "pursuer"))
	var spec: Dictionary = DEFAULT_ENEMIES.get(kind, DEFAULT_ENEMIES["pursuer"]).duplicate(true)
	if state.scenario.enemy_stats is Dictionary and state.scenario.enemy_stats.has(kind): spec.merge(state.scenario.enemy_stats[kind], true)
	if entry is Dictionary: spec.merge(entry, true)
	spec.hp = float(spec.get("hp", 1.0)) * float(state.scenario.get("stage_hp_multiplier", 1.0))
	spec.damage = float(spec.get("damage", 0.0)) * float(state.scenario.get("stage_damage_multiplier", 1.0))
	spec.max_hp = spec.hp; spec.attack_clock = float(spec.get("attack_interval", 1.0)); spec.id = state.next_enemy_id; state.next_enemy_id += 1
	return spec

func _advance_hero_attacks(state: Dictionary, dt: float) -> void:
	var interval := maxf(0.0001, float(state.player.get("attack_interval", 0.6)))
	state.attack_clock += dt
	while state.attack_clock + 0.000001 >= interval:
		state.attack_clock -= interval; state.attacks_fired += 1
		if state.rng.randf() > float(state.scenario.assumptions.get("hero_uptime", 1.0)):
			continue
		var count := maxi(1, int(state.player.get("projectile_count", 1)))
		for _shot in range(count):
			if state.enemies.is_empty(): break
			var target_index := _target_index(state)
			if _shot > 0:
				if _shot >= state.enemies.size() or state.rng.randf() > float(state.scenario.assumptions.get("fan_coverage", 1.0)):
					continue
				target_index = (target_index + _shot) % state.enemies.size()
			state.projectiles.append({"target_id": state.enemies[target_index].id, "damage": float(state.player.get("damage", 10.0)), "remaining": maxf(0.0, float(state.scenario.assumptions.get("travel_seconds", 0.0)))})
			state.hit_count += 1
	if bool(state.player.get("pulse_enabled", true)):
		state.pulse_clock += dt
		var cooldown := maxf(0.0001, float(state.player.get("pulse_cooldown", 8.0)))
		while state.pulse_clock >= cooldown:
			state.pulse_clock -= cooldown; state.pulses_fired += 1
			if state.rng.randf() <= float(state.scenario.assumptions.get("pulse_use", 1.0)):
				for enemy in state.enemies: enemy.hp -= float(state.player.get("pulse_damage", 15.0))
				_cleanup_dead(state)

func _advance_projectiles(state: Dictionary, dt: float) -> void:
	for projectile in state.projectiles.duplicate():
		projectile.remaining -= dt
		if projectile.remaining > 0.0: continue
		state.projectiles.erase(projectile)
		var target = null
		for enemy in state.enemies:
			if enemy.id == projectile.target_id: target = enemy; break
		if target == null and bool(state.scenario.get("retarget_on_arrival", false)) and not state.enemies.is_empty(): target = state.enemies[_target_index(state)]
		if target != null: target.hp -= float(projectile.damage)
	_cleanup_dead(state)

func _advance_enemy_attacks(state: Dictionary, dt: float) -> void:
	var avoidance := clampf(float(state.scenario.assumptions.get("avoidance", 0.0)), 0.0, 1.0)
	var uptime := clampf(float(state.scenario.assumptions.get("damage_uptime", 1.0)), 0.0, 1.0)
	for enemy in state.enemies:
		enemy.attack_clock -= dt
		var interval := maxf(0.0001, float(enemy.get("attack_interval", 1.0)))
		while enemy.attack_clock <= 0.0:
			enemy.attack_clock += interval
			if state.scenario.assumptions.has("contact_chance") and state.rng.randf() > float(state.scenario.assumptions.contact_chance):
				continue
			var damage := float(enemy.damage) * (1.0 - avoidance) * uptime
			if str(enemy.get("attack_target", "hero")) == "machine": state.machine_integrity -= damage; state.incoming_machine_damage += damage
			else: state.hero_health -= damage; state.incoming_hero_damage += damage
			if state.hero_health <= 0.0 or state.machine_integrity <= 0.0: return

func _advance_sealing(state: Dictionary, dt: float) -> void:
	state.sealing_remaining -= dt
	var danger := float(state.scenario.get("sealing_danger_per_second", 0.0)) * dt
	state.hero_health -= danger; state.incoming_hero_damage += danger

func _target_index(state: Dictionary) -> int:
	var mode := str(state.scenario.assumptions.get("targeting", "front"))
	if mode == "lowest_hp":
		var best := 0
		for i in range(1, state.enemies.size()):
			if state.enemies[i].hp < state.enemies[best].hp: best = i
		return best
	if mode == "random": return state.rng.randi_range(0, state.enemies.size() - 1)
	return 0

func _cleanup_dead(state: Dictionary) -> void:
	for enemy in state.enemies.duplicate():
		if enemy.hp <= 0.0:
			state.enemies.erase(enemy); state.kills += 1
			if state.has("kill_events"):
				state.kill_events.append({"id": enemy.id, "kind": enemy.get("kind", "pursuer")})
