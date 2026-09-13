extends Node2D

const RunStateScript = preload("res://data/run_state.gd")
const BalanceData = preload("res://data/balance.gd")
const ScheduleScript = preload("res://data/schedule.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const FIXED_STEP: float = 1.0 / 60.0
const GROUND_Y: float = 540.0
const MACHINE_X: float = 640.0

@onready var hero: SideViewHero = $Hero

var paused := false
var started := false
var status_text := "READY - movement shell"
var pause_button: Button
var run_state: RefCounted = RunStateScript.new()
var enemies: Array[Node] = []
var projectiles: Array[Node] = []
var spawned_kinds: Array[int] = []
var spawn_clock: float = 0.0
var next_enemy_id: int = 1
var weapon_clock: float = 0.0
var dash_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var pulse_cooldown_remaining: float = 0.0
var next_wave_index: int = 0
var presentation_time: float = 0.0
var machine_flash_remaining: float = 0.0
var pulse_feedback_remaining: float = 0.0
var last_machine_integrity: float = BalanceData.MACHINE_INTEGRITY

func _ready() -> void:
	_build_controls()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause_game"):
		set_experiment_paused(not paused)
	if paused:
		return
	simulate_step(FIXED_STEP)

func simulate_step(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or paused:
		return
	var remaining := delta
	while remaining > 0.0:
		var step := minf(FIXED_STEP, remaining)
		_simulation_step(step)
		remaining -= step

func _simulation_step(delta: float) -> void:
	if run_state.phase != RunStateScript.Phase.EXTRACTING and run_state.phase != RunStateScript.Phase.SEALING:
		return
	if hero == null:
		hero = get_node_or_null("Hero") as SideViewHero
	if hero == null:
		return
	var left_strength := Input.get_action_strength("move_left")
	var right_strength := Input.get_action_strength("move_right")
	var signed_input := SideViewHero.normalized_horizontal_input(left_strength, right_strength)
	if dash_remaining > 0.0:
		hero.simulate_tick(delta, float(dash_direction))
		dash_remaining = maxf(0.0, dash_remaining - delta)
	else:
		hero.simulate_tick(delta, signed_input)
	if not is_zero_approx(signed_input):
		last_input_direction = 1 if signed_input > 0.0 else -1
	if Input.is_action_just_pressed("dash"):
		try_dash(0)
	if Input.is_action_just_pressed("pulse"):
		try_pulse()
	if Input.is_action_just_pressed("harvest"):
		if run_state.phase == RunStateScript.Phase.EXTRACTING:
			request_harvest()
		elif run_state.phase == RunStateScript.Phase.READY:
			start_run()
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	pulse_cooldown_remaining = maxf(0.0, pulse_cooldown_remaining - delta)
	_spawn_due_waves(delta)
	_simulate_enemies(delta)
	_simulate_projectiles(delta)
	_simulate_weapon(delta)
	run_state.advance(delta)
	if run_state.machine_integrity < last_machine_integrity:
		machine_flash_remaining = 0.16
	last_machine_integrity = run_state.machine_integrity
	machine_flash_remaining = maxf(0.0, machine_flash_remaining - delta)
	pulse_feedback_remaining = maxf(0.0, pulse_feedback_remaining - delta)
	queue_redraw()

var dash_direction: int = 1
var last_input_direction: int = 1

func start_run() -> bool:
	if not run_state.start("side-view-%d" % Time.get_ticks_msec()):
		return false
	if hero == null:
		hero = get_node_or_null("Hero") as SideViewHero
	started = true
	status_text = "EXTRACTING - protect the harvester"
	return true

func request_harvest() -> bool:
	var harvested: bool = run_state.request_harvest()
	if harvested:
		status_text = "SEALING - payout locked: %d" % run_state.locked_payout
	return harvested

func apply_enemy_damage(target: int, amount: float) -> bool:
	if target == RunStateScript.DamageTarget.HERO and dash_remaining > 0.0:
		return false
	return run_state.apply_damage(target, amount)

func set_experiment_paused(should_pause: bool) -> void:
	paused = should_pause
	run_state.set_paused(should_pause)
	if pause_button != null:
		pause_button.text = "RESUME" if paused else "PAUSE"

func try_dash(direction: int = 0) -> bool:
	if paused or dash_cooldown_remaining > 0.0 or dash_remaining > 0.0 or run_state.phase != RunStateScript.Phase.EXTRACTING:
		return false
	dash_direction = direction if direction != 0 else last_input_direction
	if dash_direction == 0:
		dash_direction = hero.last_facing
	dash_remaining = BalanceData.DASH_DURATION
	dash_cooldown_remaining = BalanceData.DASH_COOLDOWN
	return true

func try_pulse() -> int:
	if paused or pulse_cooldown_remaining > 0.0 or run_state.phase != RunStateScript.Phase.EXTRACTING:
		return 0
	pulse_cooldown_remaining = BalanceData.PULSE_COOLDOWN
	pulse_feedback_remaining = 0.28
	var hit_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and absf(enemy.position.x - hero.position.x) <= BalanceData.PULSE_RADIUS * SPATIAL_PIXELS_PER_UNIT:
			if enemy.take_damage(BalanceData.PULSE_DAMAGE):
				hit_count += 1
	return hit_count

func spawn_enemy(kind: int, side: int) -> Node:
	if enemies.size() >= BalanceData.MAX_LIVE_ENEMIES:
		return null
	var enemy: Node = EnemyScript.new()
	enemy.setup(kind, next_enemy_id, side, self)
	next_enemy_id += 1
	enemy.position = Vector2(40.0 if side < 0 else 1240.0, GROUND_Y - 40.0)
	add_child(enemy)
	enemies.append(enemy)
	if not spawned_kinds.has(kind):
		spawned_kinds.append(kind)
	return enemy

func spawn_hostile_projectile(origin_x: float, target_x: float, damage: float) -> void:
	var projectile: Node = ProjectileScript.new()
	projectile.setup(self, origin_x, target_x, damage, BalanceData.RANGED_PROJECTILE_SPEED, BalanceData.RANGED_PROJECTILE_LIFETIME, true)
	add_child(projectile)
	projectiles.append(projectile)

func spawn_friendly_projectile(origin_x: float, target_x: float) -> void:
	var projectile: Node = ProjectileScript.new()
	projectile.setup(self, origin_x, target_x, BalanceData.WEAPON_DAMAGE, BalanceData.WEAPON_PROJECTILE_SPEED, BalanceData.WEAPON_PROJECTILE_LIFETIME, false)
	add_child(projectile)
	projectiles.append(projectile)

func closest_live_enemy() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := absf(enemy.position.x - hero.position.x)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (nearest == null or enemy.enemy_id < nearest.enemy_id)):
			nearest = enemy
			nearest_distance = distance
	return nearest if nearest_distance <= BalanceData.WEAPON_RANGE * SPATIAL_PIXELS_PER_UNIT else null

func closest_live_enemy_between(origin_x: float, target_x: float) -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	var low := minf(origin_x, target_x)
	var high := maxf(origin_x, target_x)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.position.x < low or enemy.position.x > high:
			continue
		var distance := absf(enemy.position.x - origin_x)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and (nearest == null or enemy.enemy_id < nearest.enemy_id)):
			nearest = enemy
			nearest_distance = distance
	return nearest

func retry() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	enemies.clear()
	projectiles.clear()
	run_state.reset()
	spawn_clock = 0.0
	next_enemy_id = 1
	next_wave_index = 0
	spawned_kinds.clear()
	weapon_clock = 0.0
	dash_remaining = 0.0
	dash_cooldown_remaining = 0.0
	pulse_cooldown_remaining = 0.0
	presentation_time = 0.0
	machine_flash_remaining = 0.0
	pulse_feedback_remaining = 0.0
	last_machine_integrity = BalanceData.MACHINE_INTEGRITY
	hero.position = Vector2(320.0, GROUND_Y - 40.0)
	hero.last_facing = 1
	paused = false
	started = false
	status_text = "READY - clean encounter"

func _spawn_due_waves(delta: float) -> void:
	spawn_clock += delta
	while next_wave_index < ScheduleScript.WAVES.size() and spawn_clock >= ScheduleScript.WAVES[next_wave_index].time:
		var wave: Dictionary = ScheduleScript.WAVES[next_wave_index]
		spawn_enemy(wave.kind, wave.side)
		next_wave_index += 1

func _simulate_enemies(delta: float) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.simulate_tick(delta)
	for index in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[index]) or enemies[index].dead:
			enemies.remove_at(index)

func _simulate_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.simulate_tick(delta)
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]) or projectiles[index].is_queued_for_deletion():
			projectiles.remove_at(index)

func _simulate_weapon(delta: float) -> void:
	weapon_clock += delta
	while weapon_clock >= BalanceData.WEAPON_INTERVAL:
		weapon_clock -= BalanceData.WEAPON_INTERVAL
		var target := closest_live_enemy()
		if target != null:
			spawn_friendly_projectile(hero.position.x, target.position.x)

func _build_controls() -> void:
	var controls := CanvasLayer.new()
	controls.name = "Controls"
	add_child(controls)
	var title := Label.new()
	title.position = Vector2(48, 34)
	title.text = "TEL0S // SIDE-VIEW DEFENSE"
	title.add_theme_color_override("font_color", Color("d7e4e6"))
	title.add_theme_font_size_override("font_size", 24)
	controls.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(50, 68)
	subtitle.text = "S03 VISUAL SLICE  /  FIXED CAMERA  /  1280 x 720"
	subtitle.add_theme_color_override("font_color", Color("71929a"))
	subtitle.add_theme_font_size_override("font_size", 13)
	controls.add_child(subtitle)
	var legend := Label.new()
	legend.position = Vector2(48, 646)
	legend.text = "A / D or ARROWS MOVE   |   SPACE DASH   |   Q PULSE   |   E START / HARVEST   |   ESC PAUSE"
	legend.add_theme_color_override("font_color", Color("a7bcc0"))
	legend.add_theme_font_size_override("font_size", 14)
	controls.add_child(legend)
	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(48, 104)
	status.add_theme_color_override("font_color", Color("66d9c4"))
	status.add_theme_font_size_override("font_size", 16)
	controls.add_child(status)
	var start_button := Button.new()
	start_button.text = "START / HARVEST"
	start_button.position = Vector2(950, 40)
	start_button.size = Vector2(140, 36)
	start_button.pressed.connect(_on_start_pressed)
	controls.add_child(start_button)
	var retry_button := Button.new()
	retry_button.text = "RETRY"
	retry_button.position = Vector2(1100, 40)
	retry_button.size = Vector2(80, 36)
	retry_button.pressed.connect(_on_retry_pressed)
	controls.add_child(retry_button)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.position = Vector2(950, 84)
	pause_button.size = Vector2(230, 34)
	pause_button.pressed.connect(_on_pause_pressed)
	controls.add_child(pause_button)
	_update_status(status)

func _process(_delta: float) -> void:
	presentation_time += _delta
	if not paused:
		queue_redraw()
	var status := get_node("Controls/Status") as Label
	_update_status(status)

func _update_status(status: Label) -> void:
	if status == null:
		return
	if run_state.phase == RunStateScript.Phase.SUCCESS:
		status_text = "SUCCESS - payout locked: %d" % run_state.locked_payout
	elif run_state.phase == RunStateScript.Phase.FAILED:
		status_text = "FAILED - %s" % run_state.terminal_reason
	var payout_text := "PAYOUT %d" % run_state.locked_payout if run_state.phase == RunStateScript.Phase.SEALING or run_state.phase == RunStateScript.Phase.SUCCESS else "TANK %.1f" % run_state.tank_base
	status.text = ("PAUSED  /  " if paused else "") + status_text + "   //   HERO X %d   FACING %s   HP %.0f   MACHINE %.0f   %s" % [roundi(hero.position.x), ">" if hero.last_facing > 0 else "<", run_state.hero_health, run_state.machine_integrity, payout_text]

func _on_start_pressed() -> void:
	if run_state.phase == RunStateScript.Phase.READY:
		start_run()
	elif run_state.phase == RunStateScript.Phase.EXTRACTING:
		request_harvest()

func _on_retry_pressed() -> void:
	retry()

func _on_pause_pressed() -> void:
	set_experiment_paused(not paused)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color("091116"), true)
	for index in range(9):
		var x := 80.0 + index * 145.0
		draw_line(Vector2(x, 180), Vector2(x + 70, 110), Color("172d33"), 4.0)
		draw_line(Vector2(x + 70, 110), Vector2(x + 120, 180), Color("172d33"), 4.0)
		draw_rect(Rect2(x + 30, 180, 22, 250), Color("102127"), true)
		if index % 2 == 0:
			draw_rect(Rect2(x + 2, 205, 14, 78), Color("334a4d"), true)
	for stack in range(6):
		var stack_x := 105.0 + stack * 215.0
		draw_rect(Rect2(stack_x, 350.0 - stack % 2 * 28.0, 54.0, 190.0 + stack % 2 * 28.0), Color("1a3035"), true)
		draw_rect(Rect2(stack_x + 9.0, 365.0 - stack % 2 * 28.0, 36.0, 8.0), Color("c38a43"), true)
		draw_line(Vector2(stack_x + 27.0, 342.0 - stack % 2 * 28.0), Vector2(stack_x + 27.0, 320.0 - stack % 2 * 28.0), Color("536b6c"), 3.0)
	draw_line(Vector2(0, GROUND_Y), Vector2(LOGICAL_SIZE.x, GROUND_Y), Color("5f7778"), 3.0)
	draw_rect(Rect2(0, GROUND_Y + 3, LOGICAL_SIZE.x, 180), Color("101d21"), true)
	for tile in range(40):
		draw_line(Vector2(tile * 34.0, GROUND_Y + 18), Vector2(tile * 34.0 + 20, GROUND_Y + 18), Color("314347"), 2.0)
	var machine_color := Color("f0a04b") if machine_flash_remaining > 0.0 else Color("b56d38")
	draw_rect(Rect2(MACHINE_X - 112, GROUND_Y - 165, 224, 165), Color("263f44"), true)
	draw_rect(Rect2(MACHINE_X - 91, GROUND_Y - 137, 182, 137), Color("172b31"), true)
	draw_rect(Rect2(MACHINE_X - 122, GROUND_Y - 18, 244, 18), Color("425a5a"), true)
	draw_circle(Vector2(MACHINE_X, GROUND_Y - 62), 47.0, machine_color)
	draw_circle(Vector2(MACHINE_X, GROUND_Y - 62), 28.0, Color("102027"))
	draw_arc(Vector2(MACHINE_X, GROUND_Y - 62), 55.0, presentation_time, presentation_time + PI * 1.6, 32, Color("66d9c4"), 5.0)
	draw_line(Vector2(MACHINE_X - 75, GROUND_Y - 111), Vector2(MACHINE_X + 75, GROUND_Y - 111), Color("c38a43"), 4.0)
	draw_circle(Vector2(MACHINE_X + cos(presentation_time * 1.8) * 34.0, GROUND_Y - 62 + sin(presentation_time * 1.8) * 34.0), 5.0, Color("f0c56b"))
	draw_line(Vector2(MACHINE_X - 120, GROUND_Y + 8), Vector2(MACHINE_X + 120, GROUND_Y + 8), Color("c38a43"), 6.0)
	if run_state.phase == RunStateScript.Phase.EXTRACTING:
		draw_arc(Vector2(MACHINE_X, GROUND_Y - 62), 63.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(run_state.tank_base / 20.0, 0.0, 1.0), 32, Color("66d9c4"), 3.0)
	if pulse_feedback_remaining > 0.0:
		var pulse_size := 220.0 * (1.0 - pulse_feedback_remaining / 0.28)
		draw_arc(hero.position, pulse_size, 0.0, TAU, 48, Color(0.4, 0.85, 0.77, pulse_feedback_remaining / 0.28), 5.0)
	draw_string(ThemeDB.fallback_font, Vector2(MACHINE_X - 72, GROUND_Y - 165), "HARVESTER / SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a7bcc0"))
	draw_string(ThemeDB.fallback_font, Vector2(96, GROUND_Y + 58), "LEFT ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("59777b"))
	draw_string(ThemeDB.fallback_font, Vector2(1080, GROUND_Y + 58), "RIGHT ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("59777b"))
