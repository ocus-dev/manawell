class_name WeaponSwing
extends RefCounted

## Per-weapon attack motion for the held weapon: how it rotates and shifts
## around the grip while the hero attacks. Stored on a published revision as
## "swing" and edited in the Weapon Lab's swing editor.
##
## The motion has three phases over `duration` seconds:
##   rest -> wind-up   (0 .. windup_time)       rotate to windup_angle, shift windup_push
##   wind-up -> strike (windup_time .. strike_time) rotate to strike_angle, shift strike_push / strike_lift
##   strike -> settle  (strike_time .. 1)       return to settle_angle (usually 0) and no shift
## Angles are degrees relative to the weapon's placed rotation, mirrored with
## the hero's facing; positive turns the same way as the default strike (75).
## Pushes are pixels along the facing direction (negative pulls back toward the
## hero); lift is pixels up. `snap` shapes the strike phase: positive (up to 1)
## starts fast and eases out (a whip); negative (down to -1) starts slow and
## accelerates into the end (a heavy, gravity-driven chop).
##
## Revisions without "swing" use DEFAULT, which reproduces the original
## hard-coded held-weapon swing exactly.

const PARAMS := {
	"duration": {"label": "Duration", "min": 0.08, "max": 2.0, "step": 0.01, "suffix": "s"},
	"windup_angle": {"label": "Wind-up angle", "min": -180.0, "max": 180.0, "step": 1.0, "suffix": "°"},
	"strike_angle": {"label": "Strike angle", "min": -180.0, "max": 180.0, "step": 1.0, "suffix": "°"},
	"settle_angle": {"label": "Settle angle", "min": -180.0, "max": 180.0, "step": 1.0, "suffix": "°"},
	"windup_time": {"label": "Wind-up ends", "min": 0.0, "max": 0.95, "step": 0.01, "suffix": ""},
	"strike_time": {"label": "Strike ends", "min": 0.05, "max": 1.0, "step": 0.01, "suffix": ""},
	"windup_push": {"label": "Wind-up push", "min": -96.0, "max": 96.0, "step": 1.0, "suffix": "px"},
	"strike_push": {"label": "Strike push", "min": -96.0, "max": 96.0, "step": 1.0, "suffix": "px"},
	"strike_lift": {"label": "Strike lift", "min": -96.0, "max": 96.0, "step": 1.0, "suffix": "px"},
	"snap": {"label": "Snap", "min": -1.0, "max": 1.0, "step": 0.05, "suffix": ""},
}
const ORDER := ["duration", "windup_angle", "strike_angle", "settle_angle", "windup_time", "strike_time", "windup_push", "strike_push", "strike_lift", "snap"]

const DEFAULT := {"preset": "default", "duration": 0.34, "windup_angle": -25.0, "strike_angle": 75.0, "settle_angle": 0.0, "windup_time": 0.25, "strike_time": 0.6, "windup_push": 0.0, "strike_push": 0.0, "strike_lift": 0.0, "snap": 0.0}

const PRESETS := {
	"default": {"label": "Default swing", "values": DEFAULT},
	"slash": {"label": "Slash", "values": {"duration": 0.3, "windup_angle": -45.0, "strike_angle": 110.0, "settle_angle": 0.0, "windup_time": 0.22, "strike_time": 0.5, "windup_push": -4.0, "strike_push": 6.0, "strike_lift": 0.0, "snap": 0.7}},
	"overhead": {"label": "Overhead smash", "values": {"duration": 0.48, "windup_angle": -120.0, "strike_angle": 95.0, "settle_angle": 10.0, "windup_time": 0.4, "strike_time": 0.62, "windup_push": -6.0, "strike_push": 10.0, "strike_lift": -6.0, "snap": 0.85}},
	"thrust": {"label": "Thrust / stab", "values": {"duration": 0.28, "windup_angle": -8.0, "strike_angle": 0.0, "settle_angle": 0.0, "windup_time": 0.3, "strike_time": 0.55, "windup_push": -14.0, "strike_push": 30.0, "strike_lift": 0.0, "snap": 0.9}},
	"spin": {"label": "Spin", "values": {"duration": 0.5, "windup_angle": -30.0, "strike_angle": 330.0, "settle_angle": 360.0, "windup_time": 0.15, "strike_time": 0.8, "windup_push": 0.0, "strike_push": 0.0, "strike_lift": 0.0, "snap": 0.3}},
	"recoil": {"label": "Gun recoil", "values": {"duration": 0.18, "windup_angle": 0.0, "strike_angle": -18.0, "settle_angle": 0.0, "windup_time": 0.02, "strike_time": 0.2, "windup_push": 0.0, "strike_push": -9.0, "strike_lift": -2.0, "snap": 1.0}},
	"none": {"label": "No motion", "values": {"duration": 0.34, "windup_angle": 0.0, "strike_angle": 0.0, "settle_angle": 0.0, "windup_time": 0.25, "strike_time": 0.6, "windup_push": 0.0, "strike_push": 0.0, "strike_lift": 0.0, "snap": 0.0}},
}
## Research-based presets. Numbers come from how real cuts move (see the
## README "Swing editor" notes) fitted to the game's rule that melee damage
## lands at 40% of the attack interval.
const RESEARCH_PRESETS := {
	"test_sword": {
		"label": "Test swing sword",
		"recommended_attacks_per_second": 1.67,
		"values": {"duration": 0.5, "windup_angle": -50.0, "strike_angle": 125.0, "settle_angle": 0.0, "windup_time": 0.24, "strike_time": 0.6, "windup_push": -4.0, "strike_push": 8.0, "strike_lift": 0.0, "snap": 0.0},
		"notes": "One-handed cut, built for the default 1.67 attacks/s (hit lands 0.24 s in).\n- Chamber: a short 0.12 s coil to -50° (real light attacks wind up only 0.1-0.2 s).\n- Cut: 175° of travel in 0.18 s. Damage lands 2/3 of the way through the strike, where real cuts reach top speed just before impact; the blade is at about +67° there.\n- Follow-through: it keeps going about 58° past the hit (real blades carry 30-60° past contact) before slowing.\n- Push: -4 px back on the chamber and +8 px forward on the cut, because the hands and body step into a real cut.\n- Snap 0: steady speed through the cut; the settle phase does the slowing down. Recovers by 0.5 s, before the next attack at 0.6 s.",
	},
	"test_axe": {
		"label": "Test swing ax",
		"recommended_attacks_per_second": 1.0,
		"values": {"duration": 0.8, "windup_angle": -150.0, "strike_angle": 95.0, "settle_angle": 0.0, "windup_time": 0.35, "strike_time": 0.5, "windup_push": -6.0, "strike_push": 6.0, "strike_lift": -8.0, "snap": -0.6},
		"notes": "Two-handed overhead chop, built for a heavy weapon at 1.0 attacks/s (hit lands 0.4 s in). At the default 1.67/s the hit would land during the wind-up.\n- Raise: 0.28 s up to -150°, straight overhead behind the head (real axe technique raises it directly overhead, not over the shoulder; heavy attacks get a longer, readable wind-up).\n- Chop: 245° down in only 0.12 s, ending exactly on the hit at +95°.\n- Snap -0.6: the head accelerates into the target, because the axe's weight and the sliding top hand do the work. That's the opposite of the sword's steady cut.\n- Lift -8 px and push +6 px: the head drops and drives forward into the target.\n- No extra follow-through: an axe bites in and stops. Then a slow 0.4 s recovery back to rest.",
	},
}

const PRESET_ORDER := ["default", "test_sword", "test_axe", "slash", "overhead", "thrust", "spin", "recoil", "none"]

## Spin needs to go past 180, so the angle limits are wider than PARAMS show in the UI.
const ANGLE_LIMIT := 720.0

static func has_preset(preset_id: String) -> bool:
	return PRESETS.has(preset_id) or RESEARCH_PRESETS.has(preset_id)

static func preset_entry(preset_id: String) -> Dictionary:
	if RESEARCH_PRESETS.has(preset_id):
		return RESEARCH_PRESETS[preset_id]
	return PRESETS.get(preset_id, {})

static func preset_label(preset_id: String) -> String:
	return str(preset_entry(preset_id).get("label", preset_id))

static func preset(preset_id: String) -> Dictionary:
	var entry: Dictionary = preset_entry(preset_id) if has_preset(preset_id) else PRESETS["default"]
	var values: Dictionary = entry["values"].duplicate(true)
	values["preset"] = preset_id if has_preset(preset_id) else "default"
	return normalize(values)

## Fills missing values from DEFAULT and clamps everything into range.
static func normalize(swing: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if swing is Dictionary:
		for key in ORDER:
			var value: Variant = swing.get(key, null)
			if (value is int or value is float) and is_finite(float(value)):
				result[key] = float(value)
		result["preset"] = str(swing.get("preset", "custom"))
	for key in ORDER:
		var limits: Dictionary = PARAMS[key]
		var low := float(limits["min"])
		var high := float(limits["max"])
		if key.ends_with("_angle"):
			low = -ANGLE_LIMIT
			high = ANGLE_LIMIT
		result[key] = clampf(float(result[key]), low, high)
	result["strike_time"] = maxf(float(result["strike_time"]), float(result["windup_time"]) + 0.01)
	result["strike_time"] = minf(float(result["strike_time"]), 1.0)
	return result

static func validate(swing: Variant) -> Dictionary:
	if not swing is Dictionary:
		return {"valid": false, "error": "swing must be an object"}
	for key in swing:
		if key != "preset" and not PARAMS.has(key):
			return {"valid": false, "error": "unknown swing value: %s" % key}
		if key == "preset":
			if not swing[key] is String:
				return {"valid": false, "error": "swing preset must be a string"}
			continue
		var value: Variant = swing[key]
		if not (value is int or value is float) or not is_finite(float(value)):
			return {"valid": false, "error": "swing %s must be a number" % key}
		var limits: Dictionary = PARAMS[key]
		var low := -ANGLE_LIMIT if str(key).ends_with("_angle") else float(limits["min"])
		var high := ANGLE_LIMIT if str(key).ends_with("_angle") else float(limits["max"])
		if float(value) < low or float(value) > high:
			return {"valid": false, "error": "swing %s is out of range" % key}
	if float(swing.get("strike_time", DEFAULT.strike_time)) <= float(swing.get("windup_time", DEFAULT.windup_time)):
		return {"valid": false, "error": "swing strike must end after the wind-up"}
	return {"valid": true}

static func is_default(swing: Variant) -> bool:
	var normalized := normalize(swing)
	for key in ORDER:
		if not is_equal_approx(float(normalized[key]), float(DEFAULT[key])):
			return false
	return true

## Pose at `progress` (0..1 of the duration), for a weapon facing right.
## Returns {"angle": degrees, "offset": Vector2 pixels (x forward, y down)}.
static func sample(swing: Dictionary, progress: float) -> Dictionary:
	var s := normalize(swing)
	var t := clampf(progress, 0.0, 1.0)
	var windup_time := float(s.windup_time)
	var strike_time := float(s.strike_time)
	var angle := 0.0
	var offset := Vector2.ZERO
	var windup_offset := Vector2(float(s.windup_push), 0.0)
	var strike_offset := Vector2(float(s.strike_push), -float(s.strike_lift))
	if t < windup_time and windup_time > 0.0:
		var k := t / windup_time
		angle = lerpf(0.0, float(s.windup_angle), k)
		offset = Vector2.ZERO.lerp(windup_offset, k)
	elif t < strike_time:
		var k := (t - windup_time) / maxf(0.0001, strike_time - windup_time)
		var snap := float(s.snap)
		if snap >= 0.0:
			k = lerpf(k, 1.0 - pow(1.0 - k, 3.0), snap)
		else:
			k = lerpf(k, pow(k, 3.0), -snap)
		angle = lerpf(float(s.windup_angle), float(s.strike_angle), k)
		offset = windup_offset.lerp(strike_offset, k)
	else:
		var k := (t - strike_time) / maxf(0.0001, 1.0 - strike_time) if strike_time < 1.0 else 1.0
		angle = lerpf(float(s.strike_angle), float(s.settle_angle), k)
		offset = strike_offset.lerp(Vector2.ZERO, k)
	return {"angle": angle, "offset": offset}

static func duration_of(swing: Variant) -> float:
	return float(normalize(swing).duration)
