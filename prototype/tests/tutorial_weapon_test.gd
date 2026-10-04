extends SceneTree

## The tutorial equips the gun (and keeps a single copy of it).

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var weapon_id: String = controller.TUTORIAL_WEAPON_ID
	assert(controller.account_state.published_weapons.has(weapon_id), "tutorial gun is published")
	assert(controller.start_tutorial())
	var hero_id: String = controller.account_state.get_active_hero_id()
	var equipped: String = controller.account_state.hero_kits[hero_id].weapon
	assert(str(controller.account_state.item_instances[equipped].weapon_id) == weapon_id, "gun is equipped")
	assert(controller.weapon_behavior_id != "weapon.melee", "gun fires shots")
	assert(controller.hero.held_weapon.texture != null, "hero holds the gun")
	# A second tutorial reuses the same gun instead of granting another copy.
	var count: int = controller.account_state.item_instances.size()
	controller.run_state.abandon()
	controller.return_to_operations()
	assert(controller.start_tutorial())
	assert(controller.account_state.item_instances.size() == count)
	# The gun actually shoots in the tutorial.
	controller.spawn_friendly_volley(controller.hero.position.x, controller.hero.position.x + 300.0)
	assert(controller.projectiles.size() >= 1)
	print("PASS tutorial weapon: gun equipped, held, fires, one copy")
	quit(0)
