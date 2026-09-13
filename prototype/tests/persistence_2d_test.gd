extends SceneTree

const BalanceData = preload("res://data/balance.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const EnemyScript = preload("res://scripts/game/melee_enemy.gd")
const SaveStoreScript = preload("res://scripts/model/save_store.gd")
const SnapshotScript = preload("res://scripts/model/run_snapshot.gd")

const LIVE_PATH := "user://card55-2d.json"
const TEMP_PATH := "user://card55-2d.tmp"
const BACKUP_PATH := "user://card55-2d.bak"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(controller)
	controller.persistence_enabled = false
	controller.account_state = AccountStateScript.new()
	assert(controller.start_run())
	controller.hero.position.x = 900.0
	controller.hero.last_facing = -1
	var saved_enemy: Node = controller.spawn_enemy(EnemyScript.EnemyKind.BREAKER, 1)
	saved_enemy.position.x = 760.0
	controller.try_dash(-1)
	controller.spawn_friendly_projectile(900.0, 700.0)
	controller.simulate_step(1.0 / 60.0)
	var snapshot: Dictionary = controller._capture_snapshot()
	var saved_hero_x: float = snapshot["actors"][0]["position"][0]
	assert(snapshot["actors"][0]["position"].size() == 2)
	assert(snapshot["projectiles"][0]["velocity"].size() == 2)
	assert(snapshot.has("director"))
	var encoded: Dictionary = SnapshotScript.encode(snapshot)
	assert(encoded["valid"], str(encoded.get("error", "")))
	var decoded: Dictionary = SnapshotScript.decode(encoded["payload"])
	assert(decoded["valid"], str(decoded.get("error", "")))
	var store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	assert(store.save_account(controller.account_state, 100.0, snapshot))
	var loaded_store: RefCounted = SaveStoreScript.new(LIVE_PATH, TEMP_PATH, BACKUP_PATH)
	loaded_store.load_account()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(restored)
	restored.persistence_enabled = true
	restored.save_store = loaded_store
	restored._restore_saved_snapshot()
	assert(restored.run_state.paused)
	assert(is_equal_approx(restored.hero.position.x, saved_hero_x))
	assert(restored.hero.last_facing == -1)
	assert(restored.enemies.size() == 1)
	assert(restored.projectiles.size() == 1)
	assert(restored.assignment_notice.contains("Encounter restored"))
	controller.queue_free()
	restored.queue_free()
	_cleanup()
	print("2D persistence checks passed")
	quit(0)

func _cleanup() -> void:
	for path in [LIVE_PATH, TEMP_PATH, BACKUP_PATH, LIVE_PATH + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
