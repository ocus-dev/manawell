class_name HarvesterLoadout
extends RefCounted

const STANDARD: String = "standard"
const OVERDRIVE: String = "overdrive"
const FORTIFIED: String = "fortified"
const IDS: Array[String] = [STANDARD, OVERDRIVE, FORTIFIED]

static func is_known(loadout_id: String) -> bool:
	return IDS.has(loadout_id)

static func is_available(loadout_id: String, well_2_commissioned: bool) -> bool:
	return loadout_id == STANDARD or (well_2_commissioned and is_known(loadout_id))

static func modifiers(loadout_id: String) -> Dictionary:
	match loadout_id:
		OVERDRIVE:
			return {"extraction_multiplier": 1.25, "pressure_time_scale": 1.25, "machine_integrity_multiplier": 1.0}
		FORTIFIED:
			return {"extraction_multiplier": 1.0, "pressure_time_scale": 1.0, "machine_integrity_multiplier": 1.5}
		_:
			return {"extraction_multiplier": 1.0, "pressure_time_scale": 1.0, "machine_integrity_multiplier": 1.0}

static func label(loadout_id: String) -> String:
	match loadout_id:
		OVERDRIVE:
			return "Overdrive"
		FORTIFIED:
			return "Fortified"
		_:
			return "Standard"

static func summary(loadout_id: String) -> String:
	match loadout_id:
		OVERDRIVE:
			return "Overdrive: +25% active extraction; pressure advances 25% faster. Passive rates unchanged."
		FORTIFIED:
			return "Fortified: +50% machine integrity; output and pressure unchanged. Passive rates unchanged."
		_:
			return "Standard: baseline active output and machine integrity. Passive rates unchanged."
