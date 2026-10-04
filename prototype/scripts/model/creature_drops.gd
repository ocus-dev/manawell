class_name CreatureDrops
extends RefCounted

## Per-creature weapon drops with a pseudo-random distribution (PRD), the way
## Dota 2 smooths its chances. A loot weapon can set its own chance per kill for
## each creature (and for zone bosses) in its loot registration:
##   "monster_chances": {"pursuer": 2.0, "breaker": 5.0, "ranged": 3.0, "boss": 25.0}  (percent)
## A weapon with any chance above 0 drops only this way (it leaves the shared
## 2% item roll).
##
## PRD: a kill's real chance is C x N, where N counts the kills of that creature
## since this weapon last dropped from it. C is picked so the long-run rate is
## the listed chance: the first try is lower, every miss raises the next, and
## the drop is certain by kill ceil(1 / C). The miss counts ("streaks") live on
## the account, so they carry from run to run.

const LootGeneratorScript = preload("res://scripts/model/loot_generator.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")

const BOSS_KEY := "boss"
## Rolls are drawn out of this many (1 in a million precision).
const ROLL_SCALE := 1000000

static var _c_cache: Dictionary = {}

## Creature keys in display order: the encyclopedia monsters, then zone bosses.
static func keys() -> Array[String]:
	var result: Array[String] = MonsterStatsScript.monster_ids()
	result.append(BOSS_KEY)
	return result

static func label(key: String) -> String:
	if key == BOSS_KEY:
		return "Zone boss"
	return str(MonsterStatsScript.monster(key).get("name", key))

## A registration's chances as {key: percent}, every key present (0 = never).
static func chances_of(entry: Dictionary) -> Dictionary:
	var saved: Variant = entry.get("monster_chances", {})
	var result := {}
	for key in keys():
		result[key] = clampf(float(saved.get(key, 0.0)), 0.0, 100.0) if saved is Dictionary else 0.0
	return result

static func is_per_creature(entry: Dictionary) -> bool:
	var saved: Variant = entry.get("monster_chances", {})
	if not saved is Dictionary:
		return false
	for key in saved:
		if float(saved[key]) > 0.0:
			return true
	return false

## The PRD constant for a listed chance (0-1).
static func prd_c(chance: float) -> float:
	if chance <= 0.0:
		return 0.0
	if chance >= 1.0:
		return 1.0
	var cache_key := snappedf(chance, 0.000001)
	if _c_cache.has(cache_key):
		return float(_c_cache[cache_key])
	var low := 0.0
	var high := chance
	for _i in range(64):
		var c := (low + high) / 2.0
		if _rate_for(c) > chance:
			high = c
		else:
			low = c
	var result := (low + high) / 2.0
	_c_cache[cache_key] = result
	return result

## Long-run success rate for a PRD constant: 1 / expected tries.
static func _rate_for(c: float) -> float:
	var miss_so_far := 1.0
	var expected := 0.0
	var tries := 1
	while true:
		var chance := minf(1.0, c * tries)
		expected += tries * miss_so_far * chance
		miss_so_far *= 1.0 - chance
		if chance >= 1.0 or miss_so_far < 1e-12:
			break
		tries += 1
	return 1.0 / expected if expected > 0.0 else 0.0

## The kill by which the drop is certain under PRD.
static func certain_by(chance: float) -> int:
	var c := prd_c(chance)
	return int(ceil(1.0 / c)) if c > 0.0 else 0

static func streak_key(weapon_id: String, key: String) -> String:
	return "%s|%s" % [weapon_id, key]

## Rolls every per-creature weapon in `pool` for one kill of `key`. Returns
## {"rng_state", "entry"} where entry is the first weapon that dropped ({} if
## none). `streaks` ({weapon|creature: misses}) is updated in place.
static func roll(pool: Array, key: String, streaks: Dictionary, rng_state: int) -> Dictionary:
	var state := rng_state
	var entries: Array = pool.filter(func(entry: Variant) -> bool: return entry is Dictionary and is_per_creature(entry))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("weapon_id", "")) < str(b.get("weapon_id", "")))
	for entry in entries:
		var chance := float(chances_of(entry).get(key, 0.0)) / 100.0
		if chance <= 0.0:
			continue
		var streak := streak_key(str(entry.weapon_id), key)
		var tries := int(streaks.get(streak, 0)) + 1
		var draw: Array = LootGeneratorScript._draw_bounded(state, ROLL_SCALE)
		state = int(draw[0])
		if float(draw[1]) < minf(1.0, prd_c(chance) * tries) * ROLL_SCALE:
			streaks[streak] = 0
			return {"rng_state": state, "entry": entry}
		streaks[streak] = tries
	return {"rng_state": state, "entry": {}}

## Makes the dropped weapon's inventory instance (same shape as a shared-roll drop).
static func instance_for(entry: Dictionary, input: Dictionary, rng_state: int) -> Dictionary:
	return LootGeneratorScript._generate_published_instance(entry, input, rng_state)
