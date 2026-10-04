extends Node2D

## Monster Test Arena: a dev sandbox for trying Monster Encyclopedia changes.
##
## An invincible test dummy stands in the middle of the arena. Monsters use
## their real AI (DefenseEnemy) and real stats (MonsterStats), and every hit
## they land shows up as a floating damage number plus a running damage meter.
## Add and remove monsters from the panel, with the keyboard, or by clicking
## the arena. Every monster in the encyclopedia can be spawned: the three
## built-ins and any creature added in the Creature Lab (each fights with its
## archetype's AI, its own art and its own stats). The Monster Encyclopedia (F9) edits stats live while you watch.
##
## This node implements the slice of the encounter controller API that
## DefenseEnemy, DefenseProjectile and the encyclopedia call. The dummy plays
## both the hero (pursuers, ranged) and the harvester (breakers).

const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const EnvironmentScript = preload("res://scripts/game/side_view_environment_visual.gd")
const CombatGeometryScript = preload("res://data/combat_geometry.gd")
const ArenaLayoutScript = preload("res://data/arena_layout.gd")
const BalanceData = preload("res://data/balance.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const MonsterEncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const DummyScript = preload("res://scripts/tools/monster_test_dummy.gd")
const VisualConfigScript = preload("res://scripts/game/side_view_visual_config.gd")
const CreatureRegistryScript = preload("res://scripts/model/creature_registry.gd")
const IndustrialThemeScript = preload("res://scripts/ui/industrial_theme.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const SPATIAL_PIXELS_PER_UNIT: float = 32.0
const FIXED_STEP: float = 1.0 / 60.0
const GROUND_Y: float = 652.0
const DUMMY_X: float = 640.0
## Breakers attack the harvester in the real game. Here the dummy is the target.
const MACHINE_X: float = DUMMY_X
const LEFT_SPAWN_X: float = ArenaLayoutScript.LEFT_BOUND + 24.0
const RIGHT_SPAWN_X: float = ArenaLayoutScript.RIGHT_BOUND - 24.0
const MAX_MONSTERS: int = BalanceData.MAX_LIVE_ENEMIES
const DPS_WINDOW := 5.0
const MAX_SURGE_LEVEL := 6
const REMOVE_PICK_RADIUS := 64.0

const AMBER := Color("f0a836")
const INK := Color("ece6da")
const MUTED := Color("9ba4ac")
const PLATE := Color(0.125, 0.145, 0.165, 0.92)
const EDGE := Color("434c55")

enum SpawnSide { RIGHT, LEFT, BOTH }

## Stand-in for RunState: enemies and projectiles only read `paused`.
class ArenaState:
	extends RefCounted
	var paused := false

	func set_paused(value: bool) -> void:
		paused = value

var run_state := ArenaState.new()
## The dummy doubles as `hero` for DefenseEnemy / DefenseProjectile.
var hero: Node2D
var dummy: Node2D
var environment_visual: Node2D
var enemies: Array[Node] = []
var projectiles: Array[Node] = []
var next_enemy_id: int = 1
var spawn_side: int = SpawnSide.RIGHT
var _alternate_left := false
var surge_level: int = 0
## Monster id the left mouse button places ("" = off).
var place_id := ""
## Spawner order (number keys 1-9 follow it).
var spawn_ids: Array[String] = []
## Read by the encyclopedia's "hits to kill" readout.
var weapon_damage: float = BalanceData.WEAPON_DAMAGE
## The encyclopedia clears this after it closes.
var pending_pause := false
var monster_encyclopedia: CanvasLayer

# Damage meter.
var elapsed := 0.0
var meter_started_at := 0.0
var hit_log: Array[Vector2] = [] # x = time, y = amount
var total_damage := 0.0
var total_hits := 0
var largest_hit := 0.0
var damage_by_monster: Dictionary = {}
var hits_by_monster: Dictionary = {}
var _active_source := ""
var _last_hit_target := 0
var _active_source_x := NAN

# UI.
var ui_layer: CanvasLayer
var count_labels: Dictionary = {}
var spawn_rows: Dictionary = {}
var spawn_list: VBoxContainer
var spawn_scroll: ScrollContainer
var spawn_search: LineEdit
var meter_rows: Dictionary = {}
var meter_list: VBoxContainer
var meter_labels: Dictionary = {}
var total_label: Label
var dps_label: Label
var hits_label: Label
var largest_label: Label
var status_label: Label
var pause_button: Button
var side_picker: OptionButton
var place_picker: OptionButton
var surge_picker: OptionButton

func _ready() -> void:
	environment_visual = EnvironmentScript.new()
	environment_visual.name = "EnvironmentVisual"
	add_child(environment_visual)
	dummy = DummyScript.new()
	dummy.name = "TestDummy"
	dummy.position = Vector2(DUMMY_X, ArenaLayoutScript.hero_support_y(ArenaLayoutScript.FLOOR_ID))
	dummy.z_index = 1
	add_child(dummy)
	hero = dummy
	_build_ui()
	refresh_monster_list()
	monster_encyclopedia = MonsterEncyclopediaScript.new()
	monster_encyclopedia.name = "MonsterEncyclopedia"
	monster_encyclopedia.controller = self
	add_child(monster_encyclopedia)
	monster_encyclopedia.closed.connect(refresh_monster_list)
	reset_meter()
	_refresh_ui()

func _physics_process(_delta: float) -> void:
	if not run_state.paused:
		simulate_step(FIXED_STEP)

func _process(_delta: float) -> void:
	_refresh_ui()

## Advances the arena by `delta` seconds in fixed steps. Tests call this directly.
func simulate_step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or run_state.paused:
		return
	var remaining := delta
	while remaining > 0.0:
		var step := minf(FIXED_STEP, remaining)
		elapsed += step
		_simulate_enemies(step)
		_simulate_projectiles(step)
		dummy.tick(step)
		_simulate_extra(step)
		remaining -= step
	_trim_hit_log()

## Subclasses (the weapon test arena) advance their own systems here.
func _simulate_extra(_step: float) -> void:
	pass

# ---------- monsters ----------

## Adds a built-in monster of `kind` (DefenseEnemy.EnemyKind). `side` is -1
## (left) or 1 (right); 0 uses the spawn-side setting. `x` overrides the
## spawn point.
func spawn_monster(kind: int, side: int = 0, x: float = NAN) -> Node:
	return spawn_creature(MonsterStatsScript.id_for_kind(kind), side, x)

## Adds any encyclopedia monster by id: a built-in ("pursuer") or a Creature
## Lab creature ("shell_walker_stage_0"), which fights with its archetype's
## AI and its own art and stats.
func spawn_creature(monster_id: String, side: int = 0, x: float = NAN) -> Node:
	var entry := MonsterStatsScript.monster(monster_id)
	if entry.is_empty():
		_set_status("Unknown monster \"%s\"." % monster_id)
		return null
	_prune()
	if enemies.size() >= MAX_MONSTERS:
		_set_status("Monster limit reached (%d)." % MAX_MONSTERS)
		return null
	if side == 0:
		side = _next_spawn_side()
	side = -1 if side < 0 else 1
	var spawn_x := x if is_finite(x) else (LEFT_SPAWN_X if side < 0 else RIGHT_SPAWN_X)
	spawn_x = clampf(spawn_x, ArenaLayoutScript.LEFT_BOUND, ArenaLayoutScript.RIGHT_BOUND)
	var enemy: Node = EnemyScript.new()
	if bool(entry.get("custom", false)):
		enemy.monster_override = monster_id
	enemy.setup(int(entry["kind"]), next_enemy_id, side, self, surge_multiplier())
	next_enemy_id += 1
	enemy.position = Vector2(spawn_x, GROUND_Y - ArenaLayoutScript.HERO_FEET_OFFSET)
	enemy.z_index = 2
	add_child(enemy)
	enemies.append(enemy)
	return enemy

## Removes the most recently added monster of `kind`. Returns true if one went.
func remove_monster_of_kind(kind: int) -> bool:
	_prune()
	for index in range(enemies.size() - 1, -1, -1):
		if enemies[index].enemy_kind == kind:
			remove_monster(enemies[index])
			return true
	return false

## Removes the most recently added monster with this id. True if one went.
func remove_monster_of_id(monster_id: String) -> bool:
	_prune()
	for index in range(enemies.size() - 1, -1, -1):
		if enemies[index].monster_id() == monster_id:
			remove_monster(enemies[index])
			return true
	return false

func monster_count_of(monster_id: String) -> int:
	_prune()
	var count := 0
	for enemy in enemies:
		if enemy.monster_id() == monster_id:
			count += 1
	return count

func remove_monster(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemies.erase(enemy)
	enemy.dead = true
	enemy.queue_free()

func clear_monsters() -> void:
	for enemy in enemies.duplicate():
		remove_monster(enemy)
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

func monster_count(kind: int = -1) -> int:
	_prune()
	if kind < 0:
		return enemies.size()
	var count := 0
	for enemy in enemies:
		if enemy.enemy_kind == kind:
			count += 1
	return count

func monster_near(point: Vector2, radius: float = REMOVE_PICK_RADIUS) -> Node:
	var best: Node = null
	var best_distance := radius
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var center := CombatGeometryScript.body_center(enemy.monster_id(), enemy.position)
		var distance := center.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best

func surge_multiplier() -> float:
	return BalanceData.multiplier_for(surge_level)

func set_surge_level(level: int) -> void:
	surge_level = clampi(level, 0, MAX_SURGE_LEVEL)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.damage_multiplier = surge_multiplier()
			enemy.refresh_stats()
	if surge_picker != null:
		surge_picker.select(surge_level)

func set_spawn_side(value: int) -> void:
	spawn_side = clampi(value, SpawnSide.RIGHT, SpawnSide.BOTH)
	if side_picker != null:
		side_picker.select(spawn_side)

func _next_spawn_side() -> int:
	match spawn_side:
		SpawnSide.LEFT:
			return -1
		SpawnSide.BOTH:
			_alternate_left = not _alternate_left
			return -1 if _alternate_left else 1
	return 1

func _prune() -> void:
	for index in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[index]) or enemies[index].dead:
			enemies.remove_at(index)

func _simulate_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead:
			_active_source = enemy.monster_id()
			_active_source_x = enemy.position.x
			enemy.simulate_tick(delta)
	_active_source = ""
	_active_source_x = NAN
	_prune()

func _simulate_projectiles(delta: float) -> void:
	for projectile in projectiles.duplicate():
		if is_instance_valid(projectile):
			_active_source = str(projectile.get_meta("monster_id", ""))
			_active_source_x = projectile.position.x
			projectile.simulate_tick(delta)
	_active_source = ""
	_active_source_x = NAN
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]) or projectiles[index].is_queued_for_deletion():
			projectiles.remove_at(index)

# ---------- controller API used by DefenseEnemy / DefenseProjectile ----------

## Every monster hit lands here. The dummy is invincible: we only record it.
func apply_enemy_damage(target: int, amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0:
		return false
	_last_hit_target = target
	record_hit(amount, _active_source, _active_source_x)
	return true

func record_hit(amount: float, monster_id: String = "", from_x: float = NAN) -> void:
	total_damage += amount
	total_hits += 1
	largest_hit = maxf(largest_hit, amount)
	hit_log.append(Vector2(elapsed, amount))
	if not monster_id.is_empty():
		damage_by_monster[monster_id] = float(damage_by_monster.get(monster_id, 0.0)) + amount
		hits_by_monster[monster_id] = int(hits_by_monster.get(monster_id, 0)) + 1
	_show_monster_hit(amount, monster_id, from_x)

## Where a monster hit is displayed. The weapon arena shows hero hits on the hero.
func _show_monster_hit(amount: float, monster_id: String, from_x: float) -> void:
	dummy.show_hit(amount, monster_id, from_x)

func spawn_hostile_projectile(origin_x: float, target_x: float, damage: float, source_enemy: Node = null, target_y: float = INF) -> void:
	var projectile: Node = ProjectileScript.new()
	var facing := 1
	var origin := Vector2(origin_x, GROUND_Y - 58.0)
	if source_enemy != null and is_instance_valid(source_enemy):
		facing = -source_enemy.side
		origin = CombatGeometryScript.muzzle_position("ranged", source_enemy.position, facing)
		projectile.source_enemy_id = source_enemy.enemy_id
		projectile.set_meta("monster_id", source_enemy.monster_id())
	var aim_y := target_y if is_finite(target_y) else CombatGeometryScript.body_center("hero", hero.position).y
	var shooter: String = source_enemy.monster_id() if source_enemy != null and is_instance_valid(source_enemy) else "ranged"
	projectile.setup(self, origin, Vector2(target_x, aim_y), damage, MonsterStatsScript.get_stat(shooter, "projectile_speed"), BalanceData.RANGED_PROJECTILE_LIFETIME, true, facing)
	projectile.z_index = 3
	add_child(projectile)
	projectiles.append(projectile)

func is_hero_on_segment(start_position: Vector2, end_position: Vector2) -> bool:
	return CombatGeometryScript.segment_fraction_against_rect(start_position, end_position, CombatGeometryScript.hurtbox_rect("hero", hero.position)) >= 0.0

## No friendly projectiles exist here, but DefenseProjectile expects this.
func closest_live_enemy_between(_start_position: Vector2, _end_position: Vector2) -> Node:
	return null

func enqueue_enemy_death(enemy: Node) -> void:
	remove_monster(enemy)

## Called by the encyclopedia after every edit.
func apply_monster_stats() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.refresh_stats()
	_set_status("Stats updated on %d monster%s." % [monster_count(), "" if monster_count() == 1 else "s"])

func set_experiment_paused(should_pause: bool) -> void:
	run_state.set_paused(should_pause)
	if pause_button != null:
		pause_button.text = "Resume  (Space)" if should_pause else "Pause  (Space)"

func toggle_pause() -> void:
	set_experiment_paused(not run_state.paused)

func open_encyclopedia() -> void:
	if monster_encyclopedia != null:
		monster_encyclopedia.open()

func return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)

# ---------- damage meter ----------

func reset_meter() -> void:
	meter_started_at = elapsed
	hit_log.clear()
	total_damage = 0.0
	total_hits = 0
	largest_hit = 0.0
	damage_by_monster.clear()
	hits_by_monster.clear()
	if dummy != null:
		dummy.clear_numbers()

## Damage per second over the last DPS_WINDOW seconds of unpaused time.
func damage_per_second() -> float:
	var window := minf(DPS_WINDOW, elapsed - meter_started_at)
	if window <= 0.0:
		return 0.0
	var cutoff := elapsed - DPS_WINDOW
	var sum := 0.0
	for hit in hit_log:
		if hit.x >= cutoff:
			sum += hit.y
	return sum / maxf(window, 1.0)

func _trim_hit_log() -> void:
	var cutoff := elapsed - DPS_WINDOW
	while not hit_log.is_empty() and hit_log[0].x < cutoff:
		hit_log.pop_front()

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if monster_encyclopedia != null and monster_encyclopedia.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var index := key - KEY_1
		if index >= 0 and index < mini(9, spawn_ids.size()):
			if event.shift_pressed:
				remove_monster_of_id(spawn_ids[index])
			else:
				spawn_creature(spawn_ids[index])
		elif key == KEY_SPACE:
			toggle_pause()
		elif key == KEY_DELETE or key == KEY_BACKSPACE:
			clear_monsters()
		elif key == KEY_R:
			reset_meter()
		elif key == KEY_ESCAPE:
			return_to_title()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var point := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var target := monster_near(point)
			if target != null:
				remove_monster(target)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not place_id.is_empty():
			var side := 1 if point.x >= DUMMY_X else -1
			spawn_creature(place_id, side, point.x)
			get_viewport().set_input_as_handled()

# ---------- UI ----------

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _refresh_ui() -> void:
	for id in spawn_ids:
		var alive := monster_count_of(id)
		if count_labels.has(id):
			count_labels[id].text = str(alive)
		if meter_labels.has(id):
			meter_labels[id].text = "%s dmg  /  %d hits" % [_fmt(float(damage_by_monster.get(id, 0.0))), int(hits_by_monster.get(id, 0))]
		# Built-ins always have a meter row; creatures once they're around.
		if meter_rows.has(id):
			meter_rows[id].visible = MonsterStatsScript.DEFAULTS.has(id) or alive > 0 or hits_by_monster.has(id)
	if total_label == null:
		return
	total_label.text = _fmt(total_damage)
	dps_label.text = _fmt(damage_per_second())
	hits_label.text = str(total_hits)
	largest_label.text = _fmt(largest_hit)

func _fmt(value: float) -> String:
	return str(roundi(value)) if absf(value - roundf(value)) < 0.05 else "%.1f" % value

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "ArenaUI"
	ui_layer.layer = 10
	add_child(ui_layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	ui_layer.add_child(root)
	root.add_child(_build_spawner())
	root.add_child(_build_meter())
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = _hint_text()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -30
	hint.offset_bottom = -8
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func _hint_text() -> String:
	return "1 - 9 add   ·   Shift + number remove   ·   Right-click a monster to remove it   ·   Space pause   ·   R reset meter   ·   F9 encyclopedia   ·   Esc back"

func _back_button_text() -> String:
	return "Back to title  (Esc)"

func _build_spawner() -> Control:
	var panel := _panel("Spawner")
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(370, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "MONSTER TEST ARENA"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", AMBER)
	column.add_child(title)
	spawn_search = LineEdit.new()
	spawn_search.name = "FindMonster"
	spawn_search.placeholder_text = "Find a monster"
	spawn_search.clear_button_enabled = true
	spawn_search.text_changed.connect(func(_text: String) -> void: _filter_spawn_rows())
	column.add_child(spawn_search)
	spawn_scroll = ScrollContainer.new()
	spawn_scroll.name = "MonsterList"
	spawn_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(spawn_scroll)
	spawn_list = VBoxContainer.new()
	spawn_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_list.add_theme_constant_override("separation", 4)
	spawn_scroll.add_child(spawn_list)
	column.add_child(HSeparator.new())
	side_picker = _picker(["Right side", "Left side", "Both sides"])
	side_picker.item_selected.connect(set_spawn_side)
	column.add_child(_labeled("Spawn from", side_picker))
	place_picker = _picker(["Off"])
	place_picker.item_selected.connect(func(index: int) -> void:
		place_id = "" if index <= 0 else str(place_picker.get_item_metadata(index)))
	column.add_child(_labeled("Click to place", place_picker))
	var surge_names: Array = []
	for level in range(MAX_SURGE_LEVEL + 1):
		surge_names.append("%d  (x%s)" % [level, _fmt_multiplier(BalanceData.multiplier_for(level))])
	surge_picker = _picker(surge_names)
	surge_picker.item_selected.connect(set_surge_level)
	column.add_child(_labeled("Surge level", surge_picker))
	column.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	pause_button = _button("Pause  (Space)")
	pause_button.name = "Pause"
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(toggle_pause)
	actions.add_child(pause_button)
	var clear := _button("Clear all")
	clear.name = "ClearAll"
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(clear_monsters)
	actions.add_child(clear)
	column.add_child(actions)
	var encyclopedia := _button("Open encyclopedia  (F9)")
	encyclopedia.name = "Encyclopedia"
	encyclopedia.add_theme_color_override("font_color", AMBER)
	encyclopedia.pressed.connect(open_encyclopedia)
	column.add_child(encyclopedia)
	var back := _button(_back_button_text())
	back.name = "Back"
	back.pressed.connect(return_to_title)
	column.add_child(back)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(300, 0)
	column.add_child(status_label)
	return panel

func _build_meter() -> Control:
	var panel := _panel("Meter")
	panel.custom_minimum_size = Vector2(290, 0)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -306
	panel.offset_right = -16
	panel.offset_top = 16
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := Label.new()
	title.text = "DAMAGE TAKEN"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", AMBER)
	column.add_child(title)
	var caption := Label.new()
	caption.text = "The dummy is invincible. Nothing is lost."
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", MUTED)
	column.add_child(caption)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	column.add_child(grid)
	total_label = _stat_row(grid, "Total damage")
	dps_label = _stat_row(grid, "DPS (last %ds)" % int(DPS_WINDOW))
	hits_label = _stat_row(grid, "Hits")
	largest_label = _stat_row(grid, "Largest hit")
	column.add_child(HSeparator.new())
	meter_list = VBoxContainer.new()
	meter_list.name = "PerMonster"
	meter_list.add_theme_constant_override("separation", 2)
	column.add_child(meter_list)
	var reset := _button("Reset meter  (R)")
	reset.name = "ResetMeter"
	reset.pressed.connect(reset_meter)
	column.add_child(reset)
	return panel

## (Re)builds the spawner rows, the click-to-place list and the per-monster
## meter rows from the encyclopedia: the built-ins, then every Creature Lab
## creature. Runs at start and whenever the encyclopedia closes.
func refresh_monster_list() -> void:
	if spawn_list == null:
		return
	var monsters := MonsterStatsScript.monsters()
	spawn_ids.clear()
	for entry in monsters:
		spawn_ids.append(str(entry["id"]))
	for child in spawn_list.get_children():
		spawn_list.remove_child(child)
		child.queue_free()
	spawn_rows.clear()
	count_labels.clear()
	var headings := 0
	var family := "\u0000"
	for index in range(monsters.size()):
		var entry: Dictionary = monsters[index]
		var this_family := str(entry.get("family", ""))
		if this_family != family:
			family = this_family
			headings += 1
			var heading := Label.new()
			heading.name = "Family_" + (family if not family.is_empty() else "other")
			heading.text = CreatureRegistryScript.family_label(family).to_upper() if not family.is_empty() else "OTHER"
			heading.set_meta("family", family)
			heading.add_theme_font_size_override("font_size", 12)
			heading.add_theme_color_override("font_color", MUTED)
			spawn_list.add_child(heading)
		var row := _build_spawn_row(entry, index)
		spawn_rows[str(entry["id"])] = row
		spawn_list.add_child(row)
	# Tall enough for every row, up to a scroll box.
	spawn_scroll.custom_minimum_size = Vector2(0, minf(40.0 * monsters.size() + 22.0 * headings, 290.0))
	spawn_search.visible = monsters.size() > 4
	var previous := place_id
	place_picker.clear()
	place_picker.add_item("Off")
	place_picker.set_item_metadata(0, "")
	place_id = ""
	for entry in monsters:
		place_picker.add_item(str(entry["name"]))
		place_picker.set_item_metadata(place_picker.item_count - 1, str(entry["id"]))
		if str(entry["id"]) == previous:
			place_picker.select(place_picker.item_count - 1)
			place_id = previous
	if place_id.is_empty():
		place_picker.select(0)
	if meter_list != null:
		for child in meter_list.get_children():
			meter_list.remove_child(child)
			child.queue_free()
		meter_rows.clear()
		meter_labels.clear()
		for entry in monsters:
			var id := str(entry["id"])
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			var name_label := Label.new()
			name_label.text = str(entry["name"])
			name_label.clip_text = true
			name_label.add_theme_color_override("font_color", DummyScript.color_for(id))
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(name_label)
			var value := Label.new()
			value.add_theme_font_size_override("font_size", 14)
			meter_labels[id] = value
			line.add_child(value)
			meter_rows[id] = line
			meter_list.add_child(line)
	_filter_spawn_rows()
	_refresh_ui()

func _build_spawn_row(entry: Dictionary, index: int) -> Control:
	var id := str(entry["id"])
	var row := HBoxContainer.new()
	row.name = "Row_" + id
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = "%s · %s" % [entry.get("role", ""), entry.get("target", "")]
	var swatch := ColorRect.new()
	swatch.color = DummyScript.color_for(id)
	swatch.custom_minimum_size = Vector2(6, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = true
	icon.texture = _monster_icon(id)
	row.add_child(icon)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = ("%d  %s" % [index + 1, entry["name"]]) if index < 9 else "    %s" % entry["name"]
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var count := Label.new()
	count.name = "Count"
	count.custom_minimum_size = Vector2(26, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_color_override("font_color", AMBER)
	count_labels[id] = count
	row.add_child(count)
	var minus := _button("-")
	minus.name = "Remove"
	minus.custom_minimum_size = Vector2(32, 0)
	minus.tooltip_text = "Remove the newest %s" % entry["name"]
	minus.pressed.connect(func() -> void: remove_monster_of_id(id))
	row.add_child(minus)
	var plus := _button("+")
	plus.name = "Add"
	plus.custom_minimum_size = Vector2(32, 0)
	plus.tooltip_text = "Add a %s (Shift: add 5)" % entry["name"]
	plus.pressed.connect(func() -> void:
		for _i in range(5 if Input.is_key_pressed(KEY_SHIFT) else 1):
			spawn_creature(id))
	row.add_child(plus)
	return row

func _filter_spawn_rows() -> void:
	var query := spawn_search.text.strip_edges().to_lower() if spawn_search != null else ""
	for id in spawn_rows:
		var entry := MonsterStatsScript.monster(id)
		var haystack := ("%s %s %s %s %s %s" % [id, entry.get("name", ""), entry.get("role", ""), entry.get("target", ""), entry.get("family", ""), entry.get("legacy_name", "")]).to_lower()
		spawn_rows[id].visible = query.is_empty() or haystack.contains(query)
	if spawn_list == null:
		return
	var families := {}
	for id in spawn_rows:
		if spawn_rows[id].visible:
			families[str(MonsterStatsScript.monster(id).get("family", ""))] = true
	for child in spawn_list.get_children():
		if child is Label and child.has_meta("family"):
			child.visible = families.has(str(child.get_meta("family")))

## The monster's still picture cropped to its visible bounds.
func _monster_icon(monster_id: String) -> Texture2D:
	var asset := VisualConfigScript.asset_for(monster_id)
	if asset.is_empty() or asset.get("texture") == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = asset["texture"]
	atlas.region = asset["visible_bounds"]
	return atlas

func _stat_row(grid: GridContainer, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 16)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value)
	return value

func _labeled(caption: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 14)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# Keep Space/Enter free for the arena shortcuts.
	button.focus_mode = Control.FOCUS_NONE
	return button

func _picker(items: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for item in items:
		picker.add_item(str(item))
	return picker

func _fmt_multiplier(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")

func _theme() -> Theme:
	var theme: Theme = IndustrialThemeScript.create()
	theme.default_font_size = 15
	for type_name in ["Label", "Button", "OptionButton"]:
		theme.set_font_size("font_size", type_name, 15)
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		for type_name in ["Button", "OptionButton"]:
			var style: StyleBox = theme.get_stylebox(style_name, type_name)
			if style is StyleBoxFlat:
				var compact := (style as StyleBoxFlat).duplicate()
				compact.content_margin_left = 10
				compact.content_margin_right = 10
				compact.content_margin_top = 5
				compact.content_margin_bottom = 5
				theme.set_stylebox(style_name, type_name, compact)
	var hover: StyleBoxFlat = theme.get_stylebox("hover", "Button")
	hover.border_color = AMBER
	theme.set_color("font_color", "Label", INK)
	return theme
