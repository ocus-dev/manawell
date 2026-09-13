class_name ResearchResolver
extends RefCounted

const BalanceData = preload("res://data/balance.gd")
const ResearchCatalogScript = preload("res://scripts/model/research_catalog.gd")

static func rank(ranks: Dictionary, track_id: String) -> int:
	return maxi(0, int(ranks.get(track_id, 0)))

static func resolve_harvest(base_output: float, ranks: Dictionary, loadout_output_multiplier: float = 1.0, specialization_id: String = "") -> Dictionary:
	var amount_rank := rank(ranks, "harvest.amount")
	var cadence_rank := rank(ranks, "harvest.cadence")
	var cycle_interval := 1.0 / (1.0 + 0.15 * cadence_rank)
	var specialization_output := 1.25 if specialization_id == "harvest.deep_draw" else 1.0
	var pressure_multiplier := 1.15 if specialization_id == "harvest.deep_draw" else 1.0
	var sealing_multiplier := 0.8 if specialization_id == "harvest.rapid_seal" else 1.0
	var cycle_amount := base_output * (1.0 + 0.25 * amount_rank) * loadout_output_multiplier * specialization_output
	return {"cycle_interval": cycle_interval, "cycle_amount": cycle_amount, "mean_output_per_second": cycle_amount / cycle_interval, "sealing_multiplier": sealing_multiplier, "pressure_multiplier": pressure_multiplier}

static func resolve_weapon(ranks: Dictionary, mode_id: String = "weapon.standard") -> Dictionary:
	var damage_rank := rank(ranks, "weapon.damage")
	var rate_rank := rank(ranks, "weapon.rate")
	var velocity_rank := rank(ranks, "weapon.velocity")
	var shots_rank := rank(ranks, "weapon.shots")
	var count := 1
	var mode_damage := 1.0
	var mode_rate := 1.0
	var pierce := 0
	if mode_id == "weapon.fan":
		count = 5 if shots_rank >= 2 else 3 if shots_rank >= 1 else 1
		mode_damage = 0.50 if count == 5 else 0.65 if count == 3 else 1.0
	elif mode_id == "weapon.lance":
		pierce = 1
		mode_rate = 0.85
	var damage := (BalanceData.WEAPON_DAMAGE + 5.0 * damage_rank) * mode_damage
	var attacks_per_second := (1.0 + 0.15 * rate_rank) * mode_rate / BalanceData.WEAPON_INTERVAL
	return {"damage": damage, "projectile_count": count, "attack_interval": 1.0 / attacks_per_second, "attacks_per_second": attacks_per_second, "projectile_speed": BalanceData.WEAPON_PROJECTILE_SPEED * (1.0 + 0.25 * velocity_rank), "pierce_count": pierce, "mode_damage_multiplier": mode_damage}

static func validate_ranks(ranks: Dictionary) -> Dictionary:
	for track_id in ranks:
		if not ResearchCatalogScript.TRACKS.has(track_id) or not (ranks[track_id] is int) or int(ranks[track_id]) < 0 or int(ranks[track_id]) > int(ResearchCatalogScript.TRACKS[track_id].max_rank):
			return {"valid": false, "error": "invalid research rank: %s" % track_id}
	return {"valid": true}
