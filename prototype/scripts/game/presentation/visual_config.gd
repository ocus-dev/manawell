extends RefCounted

var lamp_halos_enabled := true
var drill_light_enabled := true
var muzzle_flashes_enabled := true
var steam_enabled := true
var dust_enabled := true
var sparks_enabled := true
var intensity := 1.0
var particle_density := 1.0

func is_effect_enabled(effect_id: String) -> bool:
	match effect_id:
		"lamp_halos":
			return lamp_halos_enabled
		"drill_light":
			return drill_light_enabled
		"muzzle_flashes":
			return muzzle_flashes_enabled
		"steam":
			return steam_enabled
		"dust":
			return dust_enabled
		"sparks":
			return sparks_enabled
	return false

func set_effect(effect_id: String, enabled: bool) -> void:
	match effect_id:
		"lamp_halos":
			lamp_halos_enabled = enabled
		"drill_light":
			drill_light_enabled = enabled
		"muzzle_flashes":
			muzzle_flashes_enabled = enabled
		"steam":
			steam_enabled = enabled
		"dust":
			dust_enabled = enabled
		"sparks":
			sparks_enabled = enabled

func solo(effect_id: String) -> void:
	lamp_halos_enabled = effect_id == "lamp_halos"
	drill_light_enabled = effect_id == "drill_light"
	muzzle_flashes_enabled = effect_id == "muzzle_flashes"
	steam_enabled = effect_id == "steam"
	dust_enabled = effect_id == "dust"
	sparks_enabled = effect_id == "sparks"

func enable_all() -> void:
	lamp_halos_enabled = true
	drill_light_enabled = true
	muzzle_flashes_enabled = true
	steam_enabled = true
	dust_enabled = true
	sparks_enabled = true

func copy() -> RefCounted:
	var next: RefCounted = get_script().new()
	next.lamp_halos_enabled = lamp_halos_enabled
	next.drill_light_enabled = drill_light_enabled
	next.muzzle_flashes_enabled = muzzle_flashes_enabled
	next.steam_enabled = steam_enabled
	next.dust_enabled = dust_enabled
	next.sparks_enabled = sparks_enabled
	next.intensity = intensity
	next.particle_density = particle_density
	return next
