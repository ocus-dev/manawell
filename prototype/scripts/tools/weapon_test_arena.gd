extends "res://scripts/tools/monster_test_arena.gd"

## Weapon test mode of the Monster Test Arena, used by the Weapon Lab.
##
## The hero stands in the arena holding the weapon under test and attacks
## monsters with the game's own rules (ranged shots at the nearest monster in
## WEAPON_RANGE, or melee swings with the encounter's reach, wind-up and
## single-target strike). The hero is invincible. The test dummy stays in the
## middle as the breakers' target, just like in the monster arena.
##
## Placement (grip, scale, rotation, hand offset, facing) is edited live on the
## right-hand panel or by dragging the weapon, and sent back to the lab via
## `placement_changed`. Animation tools: swing on demand, loop the attack, and
## slow motion.

signal exit_requested
signal placement_changed(pivot: Dictionary)
signal swing_changed(swing: Dictionary)

const HeroScript = preload("res://scripts/game/player.gd")
const WeaponSwing = preload("res://scripts/model/weapon_swing.gd")
const WeaponClipScript = preload("res://scripts/model/weapon_clip.gd")

const HERO_START_X := 500.0
const MELEE_REACH_UNITS: float = 1.5
const MELEE_STRIKE_FRACTION: float = 0.4
const SHOT_LIFETIME: float = BalanceData.WEAPON_PROJECTILE_LIFETIME
const NUMBER_LIFETIME := 1.0
const SPEEDS := [1.0, 0.5, 0.25, 0.1]
const WEAPON_HIT_COLOR := Color("fff1c7")

var weapon_hero: Node2D
var weapon_label := "Weapon"
var weapon_texture: Texture2D
var weapon_pivot: Dictionary = {"coordinate_space": "normalized", "origin": "top_left", "grip": [0.5, 0.75], "facing": "right", "world_scale": 1.0, "rotation_degrees": 0.0, "hand_offset": [0.0, 0.0]}
var weapon_behavior_id := "weapon.standard"
var weapon_swing: Dictionary = WeaponSwing.normalize(WeaponSwing.DEFAULT)
var weapon_effects: Array = []
var weapon_clip: Dictionary = {}
var _swing_spins: Dictionary = {}
var _swing_preset: OptionButton
var weapon_interval: float = BalanceData.WEAPON_INTERVAL
var projectile_speed: float = BalanceData.WEAPON_PROJECTILE_SPEED

var auto_attack := true
var monsters_invincible := true
var loop_attack := false
var speed_index := 0
var weapon_clock := 0.0
var loop_clock := 0.0
var melee_phase := ""
var melee_remaining := 0.0
var melee_target: Node
var melee_facing := 1
var melee_committed := false
var shots: Array[Dictionary] = []
var hit_numbers: Array[Dictionary] = []

# Damage dealt meter.
var dealt_total := 0.0
var dealt_hits := 0
var dealt_log: Array[Vector2] = []
var kills := 0
var swings := 0

var shots_layer: Node2D
var numbers_layer: Node2D
var _dragging := false
var _drag_delta := Vector2.ZERO
var _numbers_rng := RandomNumberGenerator.new()
var _pivot_spins: Dictionary = {}
var _facing_picker: OptionButton
var _syncing_controls := false
var _weapon_title: Label
var _weapon_stats_label: Label
var _dealt_labels: Dictionary = {}
var _toggle_auto: CheckBox
var _toggle_invincible: CheckBox
var _toggle_loop: CheckBox
var _speed_picker: OptionButton

func _ready() -> void:
	super._ready()
	weapon_hero = HeroScript.new()
	weapon_hero.name = "Hero"
	weapon_hero.position = Vector2(HERO_START_X, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID))
	weapon_hero.z_index = 3
	add_child(weapon_hero)
	hero = weapon_hero
	shots_layer = Node2D.new()
	shots_layer.name = "WeaponShots"
	shots_layer.z_index = 4
	shots_layer.draw.connect(_draw_shots)
	add_child(shots_layer)
	numbers_layer = Node2D.new()
	numbers_layer.name = "WeaponNumbers"
	numbers_layer.z_as_relative = false
	numbers_layer.z_index = 21
	numbers_layer.draw.connect(_draw_numbers)
	add_child(numbers_layer)
	_numbers_rng.seed = 11
	_apply_weapon_visual()
	_sync_controls()
	_refresh_weapon_readout()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## Loads the weapon under test.
## `stats`: {"attack_damage", "attack_interval", "projectile_speed"} (resolved game values).
func configure_weapon(label: String, texture: Texture2D, pivot: Dictionary, behavior_id: String, stats: Dictionary, swing: Dictionary = {}, effects: Array = [], attack_clip: Dictionary = {}) -> void:
	weapon_effects = effects.duplicate(true)
	weapon_clip = attack_clip.duplicate(true)
	weapon_swing = WeaponSwing.normalize(swing if not swing.is_empty() else WeaponSwing.DEFAULT)
	if swing.is_empty():
		weapon_swing["preset"] = "default"
	weapon_label = label
	weapon_texture = texture
	weapon_pivot = _normalized_pivot(pivot)
	weapon_behavior_id = behavior_id
	weapon_damage = maxf(0.0, float(stats.get("attack_damage", BalanceData.WEAPON_DAMAGE)))
	weapon_interval = maxf(0.05, float(stats.get("attack_interval", BalanceData.WEAPON_INTERVAL)))
	projectile_speed = maxf(1.0, float(stats.get("projectile_speed", BalanceData.WEAPON_PROJECTILE_SPEED)))
	weapon_clock = 0.0
	_cancel_melee()
	_apply_weapon_visual()
	_apply_weapon_effects()
	_sync_controls()
	_sync_swing_controls()
	_refresh_weapon_readout()

func _apply_weapon_effects() -> void:
	if weapon_hero != null:
		weapon_hero.configure_held_weapon_effects(weapon_effects, weapon_interval * MELEE_STRIKE_FRACTION if is_melee() else 0.0)
		weapon_hero.configure_attack_clip(weapon_clip, weapon_interval * MELEE_STRIKE_FRACTION if is_melee() else 0.0, weapon_interval)

## Longest attack in the weapon's clip (0 without one).
func clip_attack_length() -> float:
	if not WeaponClipScript.is_set(weapon_clip):
		return 0.0
	var clip := WeaponClipScript.normalize(weapon_clip)
	var longest := 0.0
	for index in range(WeaponClipScript.attack_ranges(clip).size()):
		longest = maxf(longest, float(WeaponClipScript.timeline(clip, index, weapon_interval * MELEE_STRIKE_FRACTION if is_melee() else 0.0).length))
	return longest

func is_melee() -> bool:
	return weapon_behavior_id == "weapon.melee"

func current_pivot() -> Dictionary:
	return weapon_pivot.duplicate(true)

func set_pivot(pivot: Dictionary, notify: bool = true) -> void:
	weapon_pivot = _normalized_pivot(pivot)
	_apply_weapon_visual()
	_sync_controls()
	if notify:
		placement_changed.emit(current_pivot())

func _normalized_pivot(pivot: Dictionary) -> Dictionary:
	var grip: Array = pivot.get("grip", [0.5, 0.75])
	var offset: Array = pivot.get("hand_offset", [0.0, 0.0])
	return {
		"coordinate_space": "normalized",
		"origin": "top_left",
		"grip": [clampf(float(grip[0]), 0.0, 1.0), clampf(float(grip[1]), 0.0, 1.0)],
		"facing": "left" if str(pivot.get("facing", "right")) == "left" else "right",
		"world_scale": clampf(float(pivot.get("world_scale", 1.0)), 0.1, 4.0),
		"rotation_degrees": clampf(float(pivot.get("rotation_degrees", 0.0)), -180.0, 180.0),
		"hand_offset": [clampf(float(offset[0]), -256.0, 256.0), clampf(float(offset[1]), -256.0, 256.0)],
	}

func current_swing() -> Dictionary:
	return {} if WeaponSwing.is_default(weapon_swing) else weapon_swing.duplicate(true)

func set_swing(swing: Dictionary, notify: bool = true) -> void:
	weapon_swing = WeaponSwing.normalize(swing if not swing.is_empty() else WeaponSwing.DEFAULT)
	_apply_weapon_visual()
	_sync_swing_controls()
	if notify:
		swing_changed.emit(current_swing())

func _apply_weapon_visual() -> void:
	if weapon_hero == null:
		return
	weapon_hero.configure_held_weapon_swing(current_swing())
	if weapon_texture == null:
		weapon_hero.clear_held_weapon()
		return
	var grip: Array = weapon_pivot["grip"]
	var offset: Array = weapon_pivot["hand_offset"]
	weapon_hero.configure_held_weapon(weapon_texture, Vector2(float(grip[0]), float(grip[1])), str(weapon_pivot["facing"]), float(weapon_pivot["world_scale"]), float(weapon_pivot["rotation_degrees"]), Vector2(float(offset[0]), float(offset[1])))

# ---------- simulation ----------

func _simulate_extra(step: float) -> void:
	if weapon_hero == null:
		return
	var input := 0.0
	if _key_held("move_left", [KEY_A, KEY_LEFT]):
		input -= 1.0
	if _key_held("move_right", [KEY_D, KEY_RIGHT]):
		input += 1.0
	weapon_hero.simulate_motion(step, input, 0, false)
	if auto_attack:
		_simulate_weapon(step)
	else:
		_advance_melee(step)
	if loop_attack:
		loop_clock += step
		# Leave a short gap after each swing so the loop reads clearly.
		var loop_period := maxf(weapon_interval, maxf(float(weapon_swing.duration), clip_attack_length()) + 0.25)
		if loop_clock >= loop_period:
			loop_clock = fmod(loop_clock, loop_period)
			play_swing()
	_simulate_shots(step)
	for index in range(hit_numbers.size() - 1, -1, -1):
		hit_numbers[index]["age"] = float(hit_numbers[index]["age"]) + step
		if float(hit_numbers[index]["age"]) >= NUMBER_LIFETIME:
			hit_numbers.remove_at(index)
	while not dealt_log.is_empty() and dealt_log[0].x < elapsed - DPS_WINDOW:
		dealt_log.pop_front()
	shots_layer.queue_redraw()
	numbers_layer.queue_redraw()

func _key_held(action: String, keys: Array) -> bool:
	if monster_encyclopedia != null and monster_encyclopedia.is_open():
		return false
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true
	for key in keys:
		if Input.is_key_pressed(key):
			return true
	return false

func _simulate_weapon(step: float) -> void:
	weapon_clock += step
	if is_melee():
		if melee_phase.is_empty():
			while weapon_clock >= weapon_interval:
				weapon_clock -= weapon_interval
				var target := closest_melee_target(weapon_hero.last_facing)
				if target != null:
					_begin_melee(target)
					break
		_advance_melee(step)
		return
	while weapon_clock >= weapon_interval:
		weapon_clock -= weapon_interval
		var target := closest_ranged_target()
		if target != null:
			play_swing()
			fire_shot(target)

## Plays the hero's attack animation (and the held-weapon swing) without dealing damage.
func play_swing() -> void:
	if weapon_hero != null and weapon_hero.visual != null:
		weapon_hero.visual.play_attack()
		swings += 1

func closest_ranged_target() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	var origin := CombatGeometryScript.body_center("hero", weapon_hero.position)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := CombatGeometryScript.body_center(enemy.monster_id(), enemy.position).distance_to(origin)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest if nearest_distance <= BalanceData.WEAPON_RANGE * SPATIAL_PIXELS_PER_UNIT else null

func melee_target_in_reach(target: Node, facing: int) -> bool:
	if target == null or not is_instance_valid(target) or target.dead:
		return false
	var center := CombatGeometryScript.body_center("hero", weapon_hero.position)
	var reach := MELEE_REACH_UNITS * SPATIAL_PIXELS_PER_UNIT
	var reach_rect := Rect2(center.x if facing > 0 else center.x - reach, center.y - 48.0, reach, 96.0)
	return CombatGeometryScript.hurtbox_rect(target.monster_id(), target.position).intersects(reach_rect)

func closest_melee_target(facing: int) -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for enemy in enemies:
		if not melee_target_in_reach(enemy, facing):
			continue
		var distance := absf(enemy.position.x - weapon_hero.position.x)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _begin_melee(target: Node) -> void:
	melee_phase = "windup"
	melee_remaining = weapon_interval * MELEE_STRIKE_FRACTION
	melee_target = target
	melee_facing = weapon_hero.last_facing
	melee_committed = false
	play_swing()

func _advance_melee(step: float) -> void:
	if melee_phase.is_empty():
		return
	melee_remaining = maxf(0.0, melee_remaining - step)
	if melee_phase == "windup" and is_zero_approx(melee_remaining):
		if not melee_committed:
			melee_committed = true
			if melee_target_in_reach(melee_target, melee_facing):
				damage_monster(melee_target, weapon_damage)
		melee_phase = "recovery"
		melee_remaining = weapon_interval * (1.0 - MELEE_STRIKE_FRACTION)
	elif melee_phase == "recovery" and is_zero_approx(melee_remaining):
		_cancel_melee()

func _cancel_melee() -> void:
	melee_phase = ""
	melee_remaining = 0.0
	melee_target = null
	melee_committed = false

func fire_shot(target: Node) -> void:
	var origin := CombatGeometryScript.muzzle_position("hero", weapon_hero.position, weapon_hero.last_facing)
	var aim := CombatGeometryScript.body_center(target.monster_id(), target.position)
	var direction := (aim - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2(float(weapon_hero.last_facing), 0.0)
	shots.append({"position": origin, "velocity": direction * projectile_speed * SPATIAL_PIXELS_PER_UNIT, "life": SHOT_LIFETIME, "damage": weapon_damage})

func _simulate_shots(step: float) -> void:
	for index in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[index]
		shot["life"] = float(shot["life"]) - step
		if float(shot["life"]) <= 0.0:
			shots.remove_at(index)
			continue
		var start: Vector2 = shot["position"]
		var finish: Vector2 = start + Vector2(shot["velocity"]) * step
		var hit: Node = null
		var best := INF
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			var fraction := CombatGeometryScript.segment_fraction_against_rect(start, finish, CombatGeometryScript.hurtbox_rect(enemy.monster_id(), enemy.position))
			if fraction >= 0.0 and fraction < best:
				best = fraction
				hit = enemy
		if hit != null:
			damage_monster(hit, float(shot["damage"]))
			shots.remove_at(index)
			continue
		shot["position"] = finish

## Applies weapon damage to a monster, records it, and shows the number.
func damage_monster(enemy: Node, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.dead or amount <= 0.0:
		return
	dealt_total += amount
	dealt_hits += 1
	dealt_log.append(Vector2(elapsed, amount))
	var top: float = enemy.visual.visible_top_local_y() if enemy.visual != null else -60.0
	hit_numbers.append({"position": enemy.position + Vector2(_numbers_rng.randf_range(-16.0, 16.0), top - 18.0), "amount": amount, "age": 0.0, "color": WEAPON_HIT_COLOR})
	if monsters_invincible:
		enemy.health = enemy.max_health
		enemy.queue_redraw()
		return
	var died: bool = amount >= float(enemy.health)
	enemy.take_damage(amount)
	if is_instance_valid(enemy):
		# The weapon arena draws its own numbers; hide the enemy's small "-N".
		enemy.damage_feedback_remaining = 0.0
	if died:
		kills += 1

func dealt_per_second() -> float:
	var window := minf(DPS_WINDOW, elapsed - meter_started_at)
	if window <= 0.0:
		return 0.0
	var sum := 0.0
	for hit in dealt_log:
		if hit.x >= elapsed - DPS_WINDOW:
			sum += hit.y
	return sum / maxf(window, 1.0)

func reset_meter() -> void:
	super.reset_meter()
	dealt_total = 0.0
	dealt_hits = 0
	dealt_log.clear()
	kills = 0
	hit_numbers.clear()

## Monster hits on the hero show over the hero; breaker hits stay on the dummy.
func _show_monster_hit(amount: float, monster_id: String, from_x: float) -> void:
	if _last_hit_target == 0 and weapon_hero != null:
		hit_numbers.append({"position": weapon_hero.position + Vector2(_numbers_rng.randf_range(-18.0, 18.0), -104.0), "amount": amount, "age": 0.0, "color": dummy.color_for(monster_id)})
		return
	super._show_monster_hit(amount, monster_id, from_x)

func set_speed_index(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[speed_index]
	if _speed_picker != null:
		_speed_picker.select(speed_index)

func flip_facing() -> void:
	if weapon_hero == null:
		return
	weapon_hero.last_facing = -weapon_hero.last_facing
	weapon_hero.visual.set_facing(weapon_hero.last_facing)
	weapon_hero._update_held_weapon_transform()

func return_to_title() -> void:
	Engine.time_scale = 1.0
	if exit_requested.get_connections().is_empty():
		super.return_to_title()
	else:
		exit_requested.emit()

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if monster_encyclopedia != null and monster_encyclopedia.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				play_swing()
				get_viewport().set_input_as_handled()
				return
			KEY_F:
				flip_facing()
				get_viewport().set_input_as_handled()
				return
			KEY_T:
				set_speed_index((speed_index + 1) % SPEEDS.size())
				get_viewport().set_input_as_handled()
				return
			KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT:
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and weapon_hero != null and weapon_texture != null:
			var point := get_global_mouse_position()
			if weapon_hero.held_weapon_world_rect().grow(4.0).has_point(point):
				_dragging = true
				var socket: Node2D = weapon_hero.weapon_socket
				_drag_delta = socket.to_local(point) - weapon_hero.held_weapon.position
				get_viewport().set_input_as_handled()
				return
		elif not event.pressed and _dragging:
			_dragging = false
			placement_changed.emit(current_pivot())
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _dragging:
		var socket: Node2D = weapon_hero.weapon_socket
		var desired := socket.to_local(get_global_mouse_position()) - _drag_delta
		var offset: Vector2 = desired - weapon_hero.held_weapon_base_position()
		if weapon_hero.last_facing < 0:
			offset.x *= -1.0
		weapon_pivot["hand_offset"] = [clampf(roundf(offset.x), -256.0, 256.0), clampf(roundf(offset.y), -256.0, 256.0)]
		_apply_weapon_visual()
		_sync_controls()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

# ---------- drawing ----------

func _draw_shots() -> void:
	for shot in shots:
		var velocity: Vector2 = shot["velocity"]
		var aim := velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT
		var shot_position: Vector2 = shot["position"]
		shots_layer.draw_line(shot_position - aim * 10.0, shot_position + aim * 10.0, Color("66d9c4"), 4.0)

func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	for entry in hit_numbers:
		var t := clampf(float(entry["age"]) / NUMBER_LIFETIME, 0.0, 1.0)
		var alpha := 1.0 if t < 0.6 else clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		var rise := (1.0 - pow(1.0 - t, 2.0)) * 48.0
		var pop := 1.0 + 0.35 * clampf(1.0 - float(entry["age"]) / 0.12, 0.0, 1.0)
		var size := int(round(20.0 * pop))
		var amount := float(entry["amount"])
		var text := str(roundi(amount)) if absf(amount - roundf(amount)) < 0.05 else "%.1f" % amount
		var anchor: Vector2 = Vector2(entry["position"]) + Vector2(-50.0, -rise)
		var color: Color = entry["color"]
		numbers_layer.draw_string_outline(font, anchor, text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, size, 5, Color(0, 0, 0, 0.85 * alpha))
		numbers_layer.draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, size, Color(color.r, color.g, color.b, alpha))

# ---------- UI ----------

func _hint_text() -> String:
	return "A / D move   ·   F flip   ·   E swing   ·   T slow motion   ·   Drag the weapon to place it   ·   1 / 2 / 3 add monsters   ·   Space pause   ·   F9 encyclopedia   ·   Esc back"

func _back_button_text() -> String:
	return "Back to Weapon Lab  (Esc)"

func _refresh_ui() -> void:
	super._refresh_ui()
	if _dealt_labels.is_empty():
		return
	_dealt_labels["total"].text = _fmt(dealt_total)
	_dealt_labels["dps"].text = _fmt(dealt_per_second())
	_dealt_labels["hits"].text = str(dealt_hits)
	_dealt_labels["kills"].text = str(kills)

func _refresh_weapon_readout() -> void:
	if _weapon_title == null:
		return
	_weapon_title.text = weapon_label.to_upper()
	var kind := "Melee" if is_melee() else "Ranged"
	var rate := 1.0 / weapon_interval if weapon_interval > 0.0 else 0.0
	_weapon_stats_label.text = "%s   ·   %s dmg   ·   %.2f / s   ·   %s DPS" % [kind, _fmt(weapon_damage), rate, _fmt(weapon_damage * rate)]

## The right-hand panel: weapon readout, damage dealt, toggles, placement.
func _build_meter() -> Control:
	var panel := _panel("WeaponPanel")
	panel.custom_minimum_size = Vector2(300, 0)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -316
	panel.offset_right = -16
	panel.offset_top = 16
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	_weapon_title = Label.new()
	_weapon_title.add_theme_font_size_override("font_size", 18)
	_weapon_title.add_theme_color_override("font_color", AMBER)
	_weapon_title.clip_text = true
	column.add_child(_weapon_title)
	_weapon_stats_label = Label.new()
	_weapon_stats_label.add_theme_font_size_override("font_size", 12)
	_weapon_stats_label.add_theme_color_override("font_color", MUTED)
	column.add_child(_weapon_stats_label)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	_dealt_labels["total"] = _mini_stat(grid, "Dealt")
	_dealt_labels["dps"] = _mini_stat(grid, "DPS")
	_dealt_labels["hits"] = _mini_stat(grid, "Hits")
	_dealt_labels["kills"] = _mini_stat(grid, "Kills")
	var reset := _button("Reset meter  (R)")
	reset.pressed.connect(reset_meter)
	column.add_child(reset)
	column.add_child(HSeparator.new())
	_toggle_auto = _check("Auto-attack", auto_attack, func(on: bool) -> void: auto_attack = on)
	column.add_child(_toggle_auto)
	_toggle_invincible = _check("Monsters can't die", monsters_invincible, func(on: bool) -> void: monsters_invincible = on)
	column.add_child(_toggle_invincible)
	_toggle_loop = _check("Loop attack animation", loop_attack, func(on: bool) -> void:
		loop_attack = on
		loop_clock = 1000.0)
	column.add_child(_toggle_loop)
	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 6)
	var swing := _button("Swing  (E)")
	swing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swing.pressed.connect(play_swing)
	anim_row.add_child(swing)
	_speed_picker = _picker(["Speed 1x", "Speed 0.5x", "Speed 0.25x", "Speed 0.1x"])
	_speed_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_picker.item_selected.connect(set_speed_index)
	anim_row.add_child(_speed_picker)
	column.add_child(anim_row)
	var tabs := TabContainer.new()
	tabs.name = "WeaponTabs"
	tabs.custom_minimum_size = Vector2(0, 318)
	tabs.add_theme_font_size_override("font_size", 13)
	column.add_child(tabs)
	var placement_page := VBoxContainer.new()
	placement_page.name = "Placement"
	placement_page.add_theme_constant_override("separation", 4)
	tabs.add_child(placement_page)
	var placement := GridContainer.new()
	placement.columns = 2
	placement.add_theme_constant_override("h_separation", 8)
	placement.add_theme_constant_override("v_separation", 2)
	placement_page.add_child(placement)
	_pivot_spin(placement, "grip_x", "Grip X", 0.0, 1.0, 0.01)
	_pivot_spin(placement, "grip_y", "Grip Y", 0.0, 1.0, 0.01)
	_pivot_spin(placement, "world_scale", "Scale", 0.1, 4.0, 0.05)
	_pivot_spin(placement, "rotation_degrees", "Rotation", -180.0, 180.0, 1.0)
	_pivot_spin(placement, "offset_x", "Hand offset X", -256.0, 256.0, 1.0)
	_pivot_spin(placement, "offset_y", "Hand offset Y", -256.0, 256.0, 1.0)
	var facing_label := Label.new()
	facing_label.text = "Art faces"
	facing_label.add_theme_font_size_override("font_size", 13)
	facing_label.add_theme_color_override("font_color", MUTED)
	placement.add_child(facing_label)
	_facing_picker = _picker(["right", "left"])
	_facing_picker.item_selected.connect(func(index: int) -> void:
		if _syncing_controls:
			return
		weapon_pivot["facing"] = "left" if index == 1 else "right"
		_apply_weapon_visual()
		placement_changed.emit(current_pivot()))
	placement.add_child(_facing_picker)
	var reset_placement := _button("Reset hand offset")
	reset_placement.pressed.connect(func() -> void:
		weapon_pivot["hand_offset"] = [0.0, 0.0]
		_apply_weapon_visual()
		_sync_controls()
		placement_changed.emit(current_pivot()))
	placement_page.add_child(reset_placement)
	tabs.add_child(_build_swing_tab())
	return panel

func _build_swing_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Swing"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4)
	scroll.add_child(page)
	_swing_preset = _picker([])
	for preset_id in WeaponSwing.PRESET_ORDER:
		_swing_preset.add_item(str(WeaponSwing.preset_label(preset_id)))
		_swing_preset.set_item_metadata(_swing_preset.item_count - 1, preset_id)
	_swing_preset.add_item("Custom")
	_swing_preset.set_item_metadata(_swing_preset.item_count - 1, "custom")
	_swing_preset.item_selected.connect(func(index: int) -> void:
		if _syncing_controls:
			return
		var preset_id := str(_swing_preset.get_item_metadata(index))
		if preset_id != "custom":
			set_swing(WeaponSwing.preset(preset_id))
			play_swing())
	page.add_child(_swing_preset)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	page.add_child(grid)
	for key in WeaponSwing.ORDER:
		var param: Dictionary = WeaponSwing.PARAMS[key]
		var label := Label.new()
		label.text = str(param["label"])
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED)
		grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = -WeaponSwing.ANGLE_LIMIT if str(key).ends_with("_angle") else float(param["min"])
		spin.max_value = WeaponSwing.ANGLE_LIMIT if str(key).ends_with("_angle") else float(param["max"])
		spin.step = float(param["step"])
		spin.suffix = str(param["suffix"])
		spin.custom_minimum_size = Vector2(120, 0)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.get_line_edit().add_theme_font_size_override("font_size", 13)
		var swing_key: String = key
		spin.value_changed.connect(func(value: float) -> void:
			if _syncing_controls:
				return
			weapon_swing[swing_key] = value
			weapon_swing["preset"] = "custom"
			weapon_swing = WeaponSwing.normalize(weapon_swing)
			_apply_weapon_visual()
			_syncing_controls = true
			_swing_preset.select(_swing_preset.item_count - 1)
			_syncing_controls = false
			swing_changed.emit(current_swing()))
		grid.add_child(spin)
		_swing_spins[key] = spin
	_sync_swing_controls()
	return scroll

func _sync_swing_controls() -> void:
	if _swing_spins.is_empty():
		return
	var was := _syncing_controls
	_syncing_controls = true
	for key in WeaponSwing.ORDER:
		_swing_spins[key].value = float(weapon_swing[key])
	var preset_id := str(weapon_swing.get("preset", "custom"))
	var index := _swing_preset.item_count - 1
	for item in range(_swing_preset.item_count):
		if str(_swing_preset.get_item_metadata(item)) == preset_id:
			index = item
	_swing_preset.select(index)
	_syncing_controls = was

func _mini_stat(grid: GridContainer, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)
	var value := Label.new()
	value.text = "0"
	value.add_theme_font_size_override("font_size", 16)
	box.add_child(value)
	grid.add_child(box)
	return value

func _check(text: String, on: bool, action: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 14)
	box.toggled.connect(action)
	return box

func _pivot_spin(grid: GridContainer, key: String, caption: String, minimum: float, maximum: float, step: float) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	grid.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.custom_minimum_size = Vector2(120, 0)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.get_line_edit().add_theme_font_size_override("font_size", 13)
	spin.value_changed.connect(func(value: float) -> void: _on_pivot_spin(key, value))
	grid.add_child(spin)
	_pivot_spins[key] = spin

func _on_pivot_spin(key: String, value: float) -> void:
	if _syncing_controls:
		return
	match key:
		"grip_x":
			weapon_pivot["grip"] = [value, float(weapon_pivot["grip"][1])]
		"grip_y":
			weapon_pivot["grip"] = [float(weapon_pivot["grip"][0]), value]
		"offset_x":
			weapon_pivot["hand_offset"] = [value, float(weapon_pivot["hand_offset"][1])]
		"offset_y":
			weapon_pivot["hand_offset"] = [float(weapon_pivot["hand_offset"][0]), value]
		_:
			weapon_pivot[key] = value
	_apply_weapon_visual()
	placement_changed.emit(current_pivot())

func _sync_controls() -> void:
	if _pivot_spins.is_empty():
		return
	_syncing_controls = true
	_pivot_spins["grip_x"].value = float(weapon_pivot["grip"][0])
	_pivot_spins["grip_y"].value = float(weapon_pivot["grip"][1])
	_pivot_spins["world_scale"].value = float(weapon_pivot["world_scale"])
	_pivot_spins["rotation_degrees"].value = float(weapon_pivot["rotation_degrees"])
	_pivot_spins["offset_x"].value = float(weapon_pivot["hand_offset"][0])
	_pivot_spins["offset_y"].value = float(weapon_pivot["hand_offset"][1])
	_facing_picker.select(1 if weapon_pivot["facing"] == "left" else 0)
	_syncing_controls = false
