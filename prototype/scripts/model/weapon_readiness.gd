class_name WeaponReadiness
extends RefCounted

## Works out what a weapon still needs before it looks right in the game: art,
## an attack animation that shows this weapon, and publishing.
##
## check(info) takes:
##   has_art          bool   a cut-out world sprite exists
##   weapon_type      String ("" = none)
##   type_label       String
##   behavior_id      String  "weapon.melee", "weapon.standard"... ("" = unknown)
##   clip_source      "type" | "own" | "none"
##   clip             Dictionary  the animation it actually plays ({} = none)
##   grip             Array  [x, y] normalized
##   hand_offset      Array  [x, y]
##   published        int    revision in the game (0 = not in the game)
##   removed          bool
##   has_changes      bool   the draft differs from the published revision
## and returns {state, title, detail, items: [{key, status, text}]}:
##   state   "art" | "animation" | "publish" | "check" | "ready"
##   status  "ok" | "warn" | "need"

const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")
const WeaponTypesScript = preload("res://scripts/model/weapon_types.gd")

const TITLES := {
	"art": "Needs art",
	"animation": "Needs an attack animation",
	"publish": "Not in the game yet",
	"check": "Almost ready",
	"ready": "In the game and animated",
}

static func check(info: Dictionary) -> Dictionary:
	var items: Array = []
	var type_label := str(info.get("type_label", ""))
	var weapon_type := str(info.get("weapon_type", ""))
	# Art.
	if bool(info.get("has_art", false)):
		items.append(_item("art", "ok", "Art is cut out."))
	else:
		items.append(_item("art", "need", "No weapon art yet. Import an image and press Cut out & prepare."))
	# Grip.
	var grip: Array = info.get("grip", [0.5, 0.75])
	var offset: Array = info.get("hand_offset", [0.0, 0.0])
	var default_grip := is_equal_approx(float(grip[0]), 0.5) and is_equal_approx(float(grip[1]), 0.75) and is_zero_approx(float(offset[0])) and is_zero_approx(float(offset[1]))
	if bool(info.get("has_art", false)):
		if default_grip:
			items.append(_item("grip", "warn", "The grip is still the default spot. Click the handle on the world sprite, or drag the weapon in the arena."))
		else:
			items.append(_item("grip", "ok", "The grip is set."))
	# Type.
	if weapon_type.is_empty():
		items.append(_item("type", "warn", "No weapon type. Pick one so it can share that type's attack animation."))
	elif info.has("behavior_id") and WeaponTypesScript.behavior_mismatch(weapon_type, str(info.behavior_id)):
		if WeaponTypesScript.default_behavior(weapon_type) == "weapon.melee":
			items.append(_item("type", "warn", "A %s set to a ranged Behavior shoots bolts instead of swinging. Set Behavior to Melee." % type_label.to_lower()))
		else:
			items.append(_item("type", "warn", "A %s set to Melee swings instead of shooting. Set Behavior to Ranged." % type_label.to_lower()))
	else:
		items.append(_item("type", "ok", "Type: %s." % type_label))
	# Animation.
	items.append(_animation_item(info))
	# In the game.
	if bool(info.get("removed", false)):
		items.append(_item("publish", "need", "Removed from the game. Press Restore to game to bring it back."))
	elif int(info.get("published", 0)) <= 0:
		items.append(_item("publish", "need", "Not in the game yet. Press Add to game."))
	elif bool(info.get("has_changes", false)):
		items.append(_item("publish", "need", "In the game as revision %d, but these edits aren't. Press Publish update." % int(info.published)))
	else:
		items.append(_item("publish", "ok", "In the game (revision %d)." % int(info.published)))
	var state := "ready"
	for key_state in [["art", "art"], ["animation", "animation"], ["publish", "publish"]]:
		if _status_of(items, str(key_state[0])) == "need":
			state = str(key_state[1])
			break
	if state == "ready":
		for item in items:
			if str(item.status) != "ok":
				state = "check"
				break
	var detail := ""
	for item in items:
		if str(item.status) != "ok":
			detail = str(item.text)
			break
	return {"state": state, "title": str(TITLES[state]), "detail": detail, "items": items}

## Whether the attack shows this weapon moving, and what to do if not.
static func _animation_item(info: Dictionary) -> Dictionary:
	var source := str(info.get("clip_source", "type"))
	var clip: Variant = info.get("clip", {})
	var type_label := str(info.get("type_label", ""))
	if source == "none":
		return _item("animation", "need", "Uses the hero's normal attack (the weapon only tilts in the hand). Make an attack animation, or use the type's default.")
	if not WeaponClipScript.is_set(clip):
		if source == "own":
			return _item("animation", "need", "Set to its own animation, but none is made yet. Make animation... in section 4.")
		if str(info.get("weapon_type", "")).is_empty():
			return _item("animation", "need", "No animation: pick a weapon type to use its default, or make one for this weapon.")
		return _item("animation", "need", "There's no %s default animation yet. Make one in section 4 and save it as the %s default." % [type_label, type_label])
	var normalized := WeaponClipScript.normalize(clip)
	var mode := str(normalized.get("mode", "hero"))
	var owner := "its own animation" if source == "own" else "the %s default" % type_label
	match mode:
		"hero_weapon":
			return _item("animation", "ok", "Animated with %s: the hero's body, holding this weapon's art." % owner)
		"weapon":
			return _item("animation", "ok", "Animated with %s (weapon frames)." % owner)
	# "hero": the frames have a weapon painted into them.
	if source == "own":
		return _item("animation", "ok", "Animated with its own animation (the hero and weapon drawn together).")
	return _item("animation", "warn", "The %s default has a weapon painted into the hero frames, so this weapon's art won't show while attacking. Check the preview; if it looks wrong, give it its own animation or remake the default as \"Hero body + each weapon's own art\"." % type_label)

static func _item(key: String, status: String, text: String) -> Dictionary:
	return {"key": key, "status": status, "text": text}

static func _status_of(items: Array, key: String) -> String:
	for item in items:
		if str(item.key) == key:
			return str(item.status)
	return "ok"
