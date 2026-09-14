class_name ObjectiveState
extends RefCounted

const OBJECTIVES := ["clear_waves", "kill_count", "defeat_boss", "extract"]
const RNG_MODULUS := 2147483647

var objective: String = "clear_waves"
var required_kills: int = 0
var count_monsters: Array[String] = []
var boss_spawn_id: String = ""
var minimum_completed_surges: int = 0
var progress: int = 0
var credited_ids: Dictionary = {}
var completed: bool = false
var completion_count: int = 0
var spawn_interval: float = 0.0
var max_alive: int = 0
var spawn_pool: Array[Dictionary] = []
var spawn_timer: float = 0.0
var rng_state: int = 1

func configure(completion: Dictionary, spawning: Dictionary = {}, seed: int = 1) -> void:
	objective = str(completion.get("objective", "clear_waves"))
	required_kills = int(completion.get("required_kills", 0))
	count_monsters.clear()
	for monster_id in completion.get("count_monsters", []):
		count_monsters.append(str(monster_id))
	boss_spawn_id = str(completion.get("boss_spawn_id", ""))
	minimum_completed_surges = int(completion.get("minimum_completed_surges", 0))
	progress = 0
	credited_ids.clear()
	completed = false
	completion_count = 0
	spawn_interval = float(spawning.get("interval_seconds", 0.0))
	max_alive = int(spawning.get("max_alive", 0))
	spawn_pool.clear()
	var total_weight := 0.0
	for entry in spawning.get("pool", []):
		var normalized := {"monster_id": str(entry.get("monster_id", "")), "weight": float(entry.get("weight", 0.0))}
		spawn_pool.append(normalized)
		total_weight += normalized.weight
	if total_weight > 0.0:
		for entry in spawn_pool:
			entry["cumulative_weight"] = total_weight
			entry["normalized_weight"] = float(entry.weight) / total_weight
	_set_seed(seed)

func reset_for_retry() -> void:
	var completion := {"objective": objective, "required_kills": required_kills, "count_monsters": count_monsters, "boss_spawn_id": boss_spawn_id, "minimum_completed_surges": minimum_completed_surges}
	var spawning := {"interval_seconds": spawn_interval, "max_alive": max_alive, "pool": spawn_pool}
	configure(completion, spawning, rng_state)

func credit_death(death_id: int, monster_id: String, player_credited: bool = true, nonsummoned: bool = true, role: String = "") -> bool:
	if completed or objective != "kill_count" or not player_credited or not nonsummoned or role == "boss" or death_id <= 0 or credited_ids.has(death_id) or not count_monsters.has(monster_id):
		return false
	credited_ids[death_id] = true
	progress += 1
	if progress >= required_kills:
		_complete()
	return true

func record_boss_defeat(spawn_id: String, player_credited: bool = true, nonsummoned: bool = true) -> bool:
	if completed or objective != "defeat_boss" or not player_credited or not nonsummoned or spawn_id.is_empty() or spawn_id != boss_spawn_id:
		return false
	_complete()
	return true

func complete_waves() -> bool:
	if completed or objective != "clear_waves":
		return false
	_complete()
	return true

func extraction_satisfied(completed_surges: int) -> bool:
	return objective == "extract" and completed_surges >= minimum_completed_surges

func advance_spawner(delta: float, alive_count: int) -> String:
	if completed or objective != "kill_count" or spawn_interval <= 0.0 or not is_finite(delta) or delta < 0.0:
		return ""
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return ""
	spawn_timer = fmod(spawn_timer, spawn_interval)
	if alive_count >= max_alive:
		return ""
	return _choose_weighted_monster()

func objective_view() -> Dictionary:
	var remaining := maxi(0, required_kills - progress) if objective == "kill_count" else 0
	return {"objective": objective, "progress": progress, "required": required_kills, "remaining": remaining, "completed": completed, "credited_ids": credited_ids.keys(), "boss_spawn_id": boss_spawn_id, "minimum_completed_surges": minimum_completed_surges}

func to_snapshot() -> Dictionary:
	var ids: Array[int] = []
	for death_id in credited_ids.keys():
		ids.append(int(death_id))
	ids.sort()
	return {"objective": objective, "progress": progress, "credited_ids": ids, "completed": completed, "completion_count": completion_count, "spawn_timer": spawn_timer, "rng_state": rng_state}

func restore_snapshot(snapshot: Dictionary) -> void:
	progress = maxi(0, int(snapshot.get("progress", 0)))
	credited_ids.clear()
	for death_id in snapshot.get("credited_ids", []):
		credited_ids[int(death_id)] = true
	completed = bool(snapshot.get("completed", false))
	completion_count = int(snapshot.get("completion_count", 0))
	spawn_timer = maxf(0.0, float(snapshot.get("spawn_timer", 0.0)))
	_set_seed(int(snapshot.get("rng_state", rng_state)))

func _complete() -> void:
	if completed:
		return
	completed = true
	completion_count += 1

func _set_seed(seed: int) -> void:
	rng_state = absi(seed) % RNG_MODULUS
	if rng_state == 0:
		rng_state = 1

func _next_random() -> float:
	rng_state = int((rng_state * 48271) % RNG_MODULUS)
	return float(rng_state) / float(RNG_MODULUS)

func _choose_weighted_monster() -> String:
	if spawn_pool.is_empty():
		return ""
	var roll := _next_random()
	var cumulative := 0.0
	for entry in spawn_pool:
		cumulative += float(entry.get("normalized_weight", 0.0))
		if roll < cumulative:
			return str(entry.get("monster_id", ""))
	return str(spawn_pool.back().get("monster_id", ""))
