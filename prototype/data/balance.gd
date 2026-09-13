class_name Balance
extends RefCounted

const ARENA_SIZE: float = 28.0
const HERO_HEALTH: float = 100.0
const MACHINE_INTEGRITY: float = 150.0
const WELL_1_BASE_OUTPUT: float = 2.0
const WELL_2_BASE_OUTPUT: float = 4.0
const WELL_3_BASE_OUTPUT: float = 5.0
const SEALING_DURATION: float = 2.0
const SURGE_DURATION: float = 20.0
const MAX_LIVE_ENEMIES: int = 60
const WEAPON_DAMAGE: float = 10.0
const WEAPON_INTERVAL: float = 0.6
const WEAPON_RANGE: float = 12.0
const WEAPON_PROJECTILE_SPEED: float = 18.0
const WEAPON_PROJECTILE_LIFETIME: float = 3.0
const DAMAGE_UPGRADE_COST: int = 40
const DAMAGE_UPGRADE_BONUS: float = 5.0
const PUMP_UPGRADE_COST: int = 60
const PUMP_OUTPUT_MULTIPLIER: float = 1.25
const SPREAD_UPGRADE_COST: int = 100
const SPREAD_ANGLE_DEGREES: float = 12.0
const LIVE_ENEMY_LIMIT: int = 60
const PURSUER_HEALTH: float = 20.0
const PURSUER_SPEED: float = 2.5
const PURSUER_DAMAGE: float = 8.0
const PURSUER_RANGE: float = 1.2
const BREAKER_HEALTH: float = 50.0
const BREAKER_SPEED: float = 1.5
const BREAKER_DAMAGE: float = 12.0
const BREAKER_RANGE: float = 1.8
const MELEE_ATTACK_INTERVAL: float = 1.0
const RANGED_HEALTH: float = 25.0
const RANGED_SPEED: float = 2.0
const RANGED_DAMAGE: float = 8.0
const RANGED_STOP_RANGE: float = 8.0
const RANGED_ATTACK_INTERVAL: float = 2.0
const RANGED_WINDUP: float = 0.6
const RANGED_PROJECTILE_SPEED: float = 8.0
const RANGED_PROJECTILE_LIFETIME: float = 3.0
const DASH_DURATION: float = 0.2
const DASH_SPEED: float = 15.0
const DASH_COOLDOWN: float = 4.0
const HERO_HORIZONTAL_SPEED: float = 192.0
const HERO_GRAVITY: float = 1200.0
const HERO_JUMP_VELOCITY: float = -600.0
const HERO_JUMP_RELEASE_VELOCITY: float = -240.0
const HERO_TERMINAL_VELOCITY: float = 900.0
const HERO_COYOTE_TIME: float = 0.10
const HERO_JUMP_BUFFER_TIME: float = 0.10
const PULSE_DAMAGE: float = 15.0
const PULSE_RADIUS: float = 4.0
const PULSE_COOLDOWN: float = 8.0

static func multiplier_for(completed_surges: int) -> float:
	if completed_surges <= 0:
		return 1.0
	if completed_surges == 1:
		return 1.25
	if completed_surges == 2:
		return 1.5
	if completed_surges == 3:
		return 2.0
	if completed_surges == 4:
		return 2.5
	return 2.5 + (completed_surges - 4) * 0.5
