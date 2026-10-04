extends SceneTree

## Dev Encyclopedia > Weapons. Saves only into a throwaway copy of the
## published weapons (res://data/weapon_encyclopedia_test, removed afterwards).

const EditsScript = preload("res://scripts/model/weapon_stat_edits.gd")
const PublisherScript = preload("res://scripts/model/weapon_publisher.gd")
const CatalogScript = preload("res://scripts/model/weapon_catalog.gd")
const StoreScript = preload("res://scripts/tools/weapon_designer_store.gd")
const AccountStateScript = preload("res://scripts/model/account_state.gd")
const ItemDefinitionsScript = preload("res://scripts/model/item_definitions.gd")
const EncyclopediaScript = preload("res://scripts/tools/monster_encyclopedia.gd")
const MonsterStatsScript = preload("res://scripts/model/monster_stats.gd")
const TestCheckScript = preload("res://tests/test_check.gd")

## Published asset paths must be res:// paths, like the publisher tests.
const DATA := "res://data/weapon_encyclopedia_test"
const ASSETS := "res://assets/weapon_encyclopedia_test"
const DRAFTS := DATA + "/drafts"
const LOOT := DATA + "/weapon_registrations.json"
const LootOddsScript = preload("res://scripts/model/loot_odds.gd")
const Generator = preload("res://scripts/model/loot_generator.gd")
const RegistrationScript = preload("res://scripts/model/weapon_loot_registration.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not TestCheckScript.check(condition, message):
		failures += 1

func _run() -> void:
	_wipe_temp()
	_copy_published()
	_check_model()
	_check_save()
	_check_account_follows_new_numbers()
	_check_drops()
	_check_creature_drops()
	await _check_page()
	await _check_live_encounter()
	_wipe_temp()
	if failures == 0:
		print("PASS weapon encyclopedia: logbook, stat edits, caps, save as next revision, lab draft sync, owned copies follow, drop rates and odds, per-creature PRD drops, drop orb, live encounter")
		quit(0)
	else:
		push_error("weapon encyclopedia checks failed: %d" % failures)
		quit(1)

func _model() -> RefCounted:
	return EditsScript.new(DATA, ASSETS, DRAFTS, LOOT)

func _check_model() -> void:
	var model := _model()
	var ids: Array = model.ids()
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/index.json")).get("weapons", {})
	check(ids.size() == published.size() and ids.size() > 0, "lists every published weapon")
	var weapon_id: String = ids[0]
	var saved_damage: float = model.published_stat(weapon_id, "base_damage")
	check(saved_damage > 0.0, "base damage read from the revision")
	check(not model.is_modified(weapon_id), "starts unmodified")
	check(is_equal_approx(model.set_stat(weapon_id, "base_damage", 99999.0), 1000.0), "base damage clamps to the catalog limit")
	check(is_equal_approx(model.set_stat(weapon_id, "base_damage", 12.3), 12.5), "base damage snaps to 0.5")
	check(model.is_modified(weapon_id) and model.modified_ids() == [weapon_id], "edit marks the weapon")
	model.set_stat(weapon_id, "base_damage", saved_damage)
	check(not model.is_modified(weapon_id), "setting the saved value clears the mark")

	model.set_stat(weapon_id, "bonus_damage", 4.0)
	model.set_stat(weapon_id, "attack_speed", 20.0)
	model.set_stat(weapon_id, "projectile_speed", 0.0)
	var patch: Dictionary = model.revision_patch(weapon_id)
	var bonus := _modifier(patch.base_modifiers, "attack_damage", "flat")
	var speed := _modifier(patch.base_modifiers, "attacks_per_second", "increased")
	check(not bonus.is_empty() and is_equal_approx(float(bonus.value), 4.0), "bonus damage becomes a flat modifier")
	check(not speed.is_empty() and is_equal_approx(float(speed.value), 0.2), "attack speed % is stored as a fraction")
	check(_modifier(patch.base_modifiers, "projectile_speed", "increased").is_empty(), "a zero bonus is left out")
	check(CatalogScript._validate_modifiers(patch.base_modifiers, "test").valid, "patched modifiers validate")
	model.set_stat(weapon_id, "attack_speed", 0.0)
	check(_modifier(model.revision_patch(weapon_id).base_modifiers, "attacks_per_second", "increased").is_empty(), "attack speed back to 0 removes it")

	model.revert(weapon_id)
	model.set_stat(weapon_id, "base_damage", 20.0)
	model.set_stat(weapon_id, "base_rate", 2.0)
	model.set_stat(weapon_id, "bonus_damage", 0.0)
	model.set_stat(weapon_id, "attack_speed", 0.0)
	var numbers: Dictionary = model.resolved(weapon_id)
	var explicit_free: bool = model.recipe(weapon_id).get("explicit_modifiers", []).is_empty()
	if explicit_free:
		check(is_equal_approx(float(numbers.attack_damage), 20.0), "resolved damage uses the new base")
		check(is_equal_approx(float(numbers.attacks_per_second), 2.0), "resolved rate uses the new base")
		check(is_equal_approx(float(numbers.dps), 40.0), "dps = damage x rate")
	model.set_stat(weapon_id, "bonus_damage", 50.0)
	numbers = model.resolved(weapon_id)
	check(numbers.capped.has("damage"), "bonus over +50% is reported as capped")
	check(float(numbers.attack_damage) <= 30.0 + 0.001, "capped damage stays at 1.5x base")
	model.set_behavior(weapon_id, "weapon.lance")
	check(model.behavior(weapon_id) == "weapon.lance", "behaviour edit")
	model.set_behavior(weapon_id, "weapon.nope")
	check(model.behavior(weapon_id) == "weapon.lance", "unknown behaviour ignored")
	model.revert_all()
	check(model.modified_ids().is_empty(), "revert all")

func _check_save() -> void:
	var model := _model()
	var weapon_id := "sword" if model.has_weapon("sword") else str(model.ids()[0])
	var before: int = model.revision_number(weapon_id)
	var old_recipe_id := str(model.recipe(weapon_id).get("recipe_id", ""))
	var draft := StoreScript.default_draft("lab." + weapon_id)
	draft["weapon_id"] = weapon_id
	draft["label"] = "Lab draft"
	check(StoreScript.save_draft(draft, DRAFTS).valid, "fixture lab draft saved")

	model.set_stat(weapon_id, "base_damage", 17.5)
	model.set_stat(weapon_id, "base_rate", 1.25)
	model.set_stat(weapon_id, "bonus_damage", 2.0)
	model.set_behavior(weapon_id, "weapon.melee")
	var result: Dictionary = model.save()
	check(result.ok and result.saved == [weapon_id], "save publishes the edited weapon %s" % str(result.errors))
	check(not model.is_modified(weapon_id), "save clears the edit")
	check(model.revision_number(weapon_id) == before + 1, "saved as the next revision")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "/index.json"))
	var revision: Dictionary = index.weapons[weapon_id]
	check(is_equal_approx(float(revision.base_stats.attack_damage), 17.5) and is_equal_approx(float(revision.base_stats.attacks_per_second), 1.25), "index has the new base stats")
	check(str(revision.behavior_id) == "weapon.melee", "index has the new behaviour")
	check(CatalogScript.validate_revision(revision, false).valid, "new revision validates")
	check(FileAccess.file_exists(DATA + "/%s/%d/definition.json" % [weapon_id, before + 1]), "revision folder written")
	check(FileAccess.file_exists(DATA + "/%s/%d/recipe.json" % [weapon_id, before]), "old revision kept")
	check(FileAccess.file_exists(str(revision.assets.icon)) and str(revision.assets.icon).begins_with(ASSETS), "art copied to the new revision")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "/%s/%d/recipe.json" % [weapon_id, before + 1]))
	check(str(recipe.recipe_id).ends_with(".r%d" % (before + 1)) and not str(recipe.recipe_id).contains(".r%d.r" % before), "recipe id counts up without stacking (%s -> %s)" % [old_recipe_id, recipe.recipe_id])
	for key in ["pivot", "effects", "attack_clip", "weapon_type", "hand_fit"]:
		var old_definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "/%s/%d/definition.json" % [weapon_id, before]))
		if old_definition.has(key):
			check(PublisherScript._values_equal(old_definition[key], revision.get(key)), "%s carries over" % key)
	var synced := StoreScript.load_draft("lab." + weapon_id, DRAFTS)
	check(is_equal_approx(float(synced.base_stats.attack_damage), 17.5) and str(synced.behavior_id) == "weapon.melee", "lab draft gets the same numbers")
	check(model.save().saved.is_empty(), "nothing to save twice")
	var bad: Dictionary = PublisherScript.publish_stats_revision(weapon_id, {"pivot": {}}, DATA, ASSETS)
	check(not bad.valid, "stats publish refuses other fields")

func _check_account_follows_new_numbers() -> void:
	var account := AccountStateScript.new()
	var weapon_id := ""
	for id in account.published_weapons:
		weapon_id = id
		break
	if weapon_id.is_empty():
		check(false, "a published weapon to grant")
		return
	check(account.grant_published_weapon(weapon_id), "grant a published weapon")
	var instance_id := ""
	for id in account.item_instances:
		if str(account.item_instances[id].get("base_id", "")) == weapon_id:
			instance_id = id
	var saved_base: Dictionary = ItemDefinitionsScript.base_for(weapon_id)
	var patch := {"base_stats": {"attack_damage": 22.0, "attacks_per_second": 1.5}, "base_modifiers": [{"stat": "attack_damage", "operation": "flat", "family": "designer.base.attack_damage", "value": 3.0}], "behavior_id": "weapon.melee"}
	account.apply_weapon_patch(weapon_id, patch)
	var instance: Dictionary = account.item_instances[instance_id]
	check(is_equal_approx(float(instance.implicit_modifiers[0].value), 3.0), "owned copy gets the new bonus")
	check(ItemDefinitionsScript.new().validate_instance(instance, ItemDefinitionsScript.runtime_bases(), ItemDefinitionsScript.PRODUCTION_AFFIXES).valid, "owned copy still validates")
	check(is_equal_approx(float(ItemDefinitionsScript.base_for(weapon_id).base_stats.attack_damage), 22.0), "registered base has the new base stats")
	check(str(account.published_weapons[weapon_id].revision.behavior_id) == "weapon.melee", "publication has the new behaviour")
	# An old save (old bonus) still loads once the weapon was re-tuned.
	var stale := instance.duplicate(true)
	stale["implicit_modifiers"][0]["value"] = 9.0
	var payload := account.to_save_payload()
	payload["item_instances"] = [stale]
	payload["hero_kits"] = {}
	var validation: Dictionary = AccountStateScript.validate_save_payload(payload)
	check(validation.valid, "save with an older bonus still validates (%s)" % str(validation.get("error", "")))
	ItemDefinitionsScript.register_runtime_base(weapon_id, saved_base)

func _check_drops() -> void:
	var model := _model()
	var ids: Array = model.ids()
	var weapon_id: String = ids[0]
	# Odds math: 9 gear bases x 100 + weapon weight x 100.
	var table := {weapon_id: {"enabled": true, "weight": 1.0, "min_item_level": 1, "max_item_level": 3}}
	check(is_equal_approx(LootOddsScript.share(weapon_id, table, 1), 0.1), "weight 1 = a tenth of item drops next to 9 gear items")
	check(is_equal_approx(LootOddsScript.per_kill(weapon_id, table, 1), 0.002), "per kill = 2% x share")
	check(is_equal_approx(LootOddsScript.per_kill(weapon_id, table, 1, "boss"), 0.025), "boss levels roll 25%")
	table[weapon_id].min_item_level = 2
	check(LootOddsScript.share(weapon_id, table, 1) == 0.0, "outside its item levels it can't drop")
	check(is_equal_approx(LootOddsScript.at_least_once(0.5, 2.0), 0.75), "at least once")
	check(absf(LootOddsScript.tries_for(0.5) - 1.0) < 0.001, "median tries")
	var levels: Array = LootOddsScript.levels()
	check(not levels.is_empty() and float(levels[0].kills) > 0.0, "levels with monsters list an estimated kill count")

	# Edits and save.
	var saved: Dictionary = model.published_drop(weapon_id)
	model.set_drop(weapon_id, "enabled", not bool(saved.enabled))
	check(model.is_drop_modified(weapon_id) and model.is_modified(weapon_id), "drop toggle is an edit")
	model.set_drop(weapon_id, "enabled", bool(saved.enabled))
	check(not model.is_modified(weapon_id), "toggling back clears it")
	model.set_drop(weapon_id, "enabled", true)
	model.set_drop(weapon_id, "weight", 2.345)
	check(is_equal_approx(float(model.drop(weapon_id).weight), 2.35), "weight snaps to 0.01")
	model.set_drop(weapon_id, "max_item_level", 1)
	model.set_drop(weapon_id, "min_item_level", 2)
	check(int(model.drop(weapon_id).max_item_level) == 2, "item levels stay ordered")
	var overrides: Dictionary = model.loot_overrides()
	check(overrides.has(weapon_id) and bool(overrides[weapon_id].enabled), "unsaved drops become loot overrides")
	var result: Dictionary = model.save()
	check(result.ok and result.saved.has(weapon_id), "drop-only save works %s" % str(result.errors))
	var registration: Dictionary = RegistrationScript.registration_for(weapon_id, LOOT)
	check(bool(registration.enabled) and is_equal_approx(float(registration.weight), 2.35) and int(registration.min_item_level) == 2, "registration saved")
	check(int(registration.revision) == model.revision_number(weapon_id), "registration points at the current revision")
	check(RegistrationScript.validate_document(RegistrationScript.load_document(LOOT)).valid, "registration file validates")
	# Saving new stats moves the registration along to the new revision.
	model.set_stat(weapon_id, "base_damage", 21.0)
	model.save()
	registration = RegistrationScript.registration_for(weapon_id, LOOT)
	check(int(registration.revision) == model.revision_number(weapon_id), "stats save keeps the loot registration on the new revision")
	var pool: Array = RegistrationScript.snapshot_for(RegistrationScript.TABLE_ID, 2, LOOT, DATA + "/index.json").pool
	var found := false
	for entry in pool:
		if str(entry.weapon_id) == weapon_id and int(entry.revision) == model.revision_number(weapon_id):
			found = true
	check(found, "the weapon drops at its current revision")
	# A registration left on an old revision still drops (the current one).
	var stale: Dictionary = RegistrationScript.load_document(LOOT)
	stale.tables[RegistrationScript.TABLE_ID].weapons[weapon_id].revision = 1
	_write(LOOT, JSON.stringify(stale))
	pool = RegistrationScript.snapshot_for(RegistrationScript.TABLE_ID, 2, LOOT, DATA + "/index.json").pool
	check(pool.any(func(entry: Dictionary) -> bool: return str(entry.weapon_id) == weapon_id), "stale registration revision still drops the current weapon")

func _check_creature_drops() -> void:
	const CreatureDropsScript = preload("res://scripts/model/creature_drops.gd")
	# PRD constants (Dota 2 table: 25% -> C 0.0847, certain by try 12).
	check(absf(CreatureDropsScript.prd_c(0.25) - 0.0847) < 0.0005, "PRD constant for 25% (%s)" % str(CreatureDropsScript.prd_c(0.25)))
	check(CreatureDropsScript.certain_by(0.25) == 12, "25% is certain by try 12")
	check(CreatureDropsScript.prd_c(1.0) == 1.0 and CreatureDropsScript.prd_c(0.0) == 0.0, "edge constants")
	# Long-run rate matches the listed chance, and droughts are capped.
	var entry := {"weapon_id": "w", "monster_chances": {"pursuer": 10.0}}
	var streaks := {}
	var state := 12345
	var drops := 0
	var longest := 0
	var dry := 0
	for _i in range(20000):
		var rolled: Dictionary = CreatureDropsScript.roll([entry], "pursuer", streaks, state)
		state = int(rolled.rng_state)
		if not rolled.entry.is_empty():
			drops += 1
			dry = 0
		else:
			dry += 1
			longest = maxi(longest, dry)
	check(absf(drops / 20000.0 - 0.10) < 0.01, "PRD averages the listed 10% (%s)" % str(drops / 20000.0))
	check(longest < CreatureDropsScript.certain_by(0.10), "no dry streak reaches the certain-by kill (%d)" % longest)
	check(CreatureDropsScript.roll([entry], "breaker", {}, 1).entry.is_empty(), "0% creatures never drop it")
	check(int(streaks.get("w|pursuer", -1)) >= 0, "streaks are kept per weapon and creature")
	# Per-creature weapons leave the shared roll.
	var table := {"a": {"enabled": true, "weight": 1.0, "min_item_level": 1, "max_item_level": 3, "chances": {"pursuer": 5.0}}}
	check(LootOddsScript.share("a", table, 1) == 0.0, "per-creature weapon is not in the shared roll")
	check(is_equal_approx(LootOddsScript.creature_per_run({"pursuer": 50.0}, {"pursuer": 2.0}), 0.75), "per-run odds from creature kills")
	# Model + registration round trip.
	var model := _model()
	var weapon_id: String = model.ids()[0]
	model.set_drop(weapon_id, "enabled", true)
	model.set_drop(weapon_id, "chance:breaker", 7.5)
	model.set_drop(weapon_id, "chance:boss", 40.0)
	model.set_drop(weapon_id, "chance:dragon", 5.0)
	check(model.is_per_creature(weapon_id) and not model.drop(weapon_id).chances.has("dragon"), "creature chances edit; unknown creatures ignored")
	check(model.loot_overrides()[weapon_id].monster_chances.breaker == 7.5, "overrides carry creature chances")
	check(model.save().ok, "save creature chances")
	var registration: Dictionary = RegistrationScript.registration_for(weapon_id, LOOT)
	check(is_equal_approx(float(registration.monster_chances.breaker), 7.5) and not registration.monster_chances.has("pursuer"), "registration keeps only chances above 0")
	check(RegistrationScript.validate_document(RegistrationScript.load_document(LOOT)).valid, "registration with chances validates")
	# A Lab-style update (no chances passed) keeps them.
	RegistrationScript.update_weapon(weapon_id, model.revision(weapon_id), true, 2.0, 1, 3, LOOT, RegistrationScript.TABLE_ID, DATA)
	check(RegistrationScript.registration_for(weapon_id, LOOT).has("monster_chances"), "Weapon Lab updates keep creature chances")
	var pool: Array = RegistrationScript.snapshot_for(RegistrationScript.TABLE_ID, 1, LOOT, DATA + "/index.json").pool
	check(pool.any(func(e: Dictionary) -> bool: return str(e.weapon_id) == weapon_id and e.has("monster_chances")), "loot pool carries creature chances")
	# The shared generator skips it.
	for seed in range(1, 300):
		var shared: Dictionary = Generator.generate({"eligible": true, "occurrence_kind": "ordinary", "drop_bonus": 0.0, "item_level": 1, "inventory_count": 0, "inventory_capacity": 100, "run_id": "creature-test", "enemy_id": seed, "node_id": "act_01_node_01", "development_drop_percent": 100.0, "published_pool": pool}, seed)
		if shared.get("generated", false) and str(shared.instance.base_id) == weapon_id:
			check(false, "shared roll must not drop a per-creature weapon")
			break
	# Account keeps streaks across saves.
	var account := AccountStateScript.new()
	account.loot_streaks = {"w|pursuer": 4}
	var restored := AccountStateScript.new()
	restored.from_save_payload(account.to_save_payload())
	check(int(restored.loot_streaks.get("w|pursuer", 0)) == 4, "streaks survive a save")
	model.set_drop(weapon_id, "chance:breaker", 0.0)
	model.set_drop(weapon_id, "chance:boss", 0.0)
	model.save()

func _check_page() -> void:
	var tool: CanvasLayer = EncyclopediaScript.new()
	root.add_child(tool)
	await process_frame
	var page: Control = tool.weapons_page
	check(page != null, "encyclopedia has a weapons page")
	page.model = _model()
	tool.open_weapons()
	check(tool.is_open() and page.visible and not tool.monster_body.visible, "weapons tab shows the logbook")
	check(tool.tab_buttons.has("weapons") and tool.tab_buttons["weapons"].button_pressed, "weapons tab button pressed")
	var ids: Array = page.model.ids()
	check(page.tiles.size() == ids.size(), "one tile per weapon")
	var weapon_id: String = ids[ids.size() - 1]
	page.select_weapon(weapon_id)
	check(page.selected_id == weapon_id and page.tiles[weapon_id].button_pressed, "select a weapon")
	check(page.picture.texture != null, "picture shows the weapon art")
	check(page.tiles[weapon_id].find_child("Icon", true, false).texture != null, "tile shows the icon")
	check(page.name_label.text == page.model.label(weapon_id), "name shown")
	check(page.matchup_box.get_child_count() == MonsterStatsScript.monster_ids().size(), "a card per monster")
	page.rows["base_damage"].spin.value = 40.0
	check(is_equal_approx(page.model.get_stat(weapon_id, "base_damage"), 40.0), "spin edits the stat")
	check(page.tiles[weapon_id].get_node("Edited").visible, "tile marked edited")
	check(page.count_label.text.contains("1 unsaved"), "count shows unsaved")
	check(not page.rows["base_damage"].undo.disabled, "Saved button enabled after edit")
	page.rows["base_damage"].undo.pressed.emit()
	check(not page.model.is_modified(weapon_id), "Saved button restores the saved value")
	page.search.text = "zzzz-no-weapon"
	page.search.text_changed.emit(page.search.text)
	check(page.empty_label.visible, "search with no hits says so")
	page.search.text = ""
	page.search.text_changed.emit("")
	check(page.orb_caption.text.ends_with(page.model.label(weapon_id)), "drop orb preview names the weapon")
	check(page.orb_preview.texture != null, "drop orb preview shows the weapon icon")
	check(page.drop_now_button.disabled, "Drop one now is off outside a run")
	page.drop_check.toggled.emit(true)
	check(page.model.drop(weapon_id).enabled and page.drop_odds_box.get_child_count() == 4, "drop toggle shows the odds")
	check(page.drop_levels_grid.get_child_count() >= 10, "per-level odds table")
	page.drop_rows.weight.spin.value = 3.0
	check(is_equal_approx(float(page.model.drop(weapon_id).weight), 3.0), "weight spin edits the drop weight")
	check(page.creature_cards.size() == 4, "a card per creature plus the zone boss")
	check(page.creature_texture("pursuer") != null and page.creature_texture("boss") != null, "creature cards show sprites")
	page.creature_cards.ranged.spin.value = 12.0
	check(page.model.is_per_creature(weapon_id) and page.drop_odds_box.get_child_count() == 3, "a creature chance switches the odds to per-creature")
	check(page.creature_cards.ranged.wait.text.contains("sure by kill"), "card shows the PRD worst case")
	page.creature_cards.ranged.spin.value = 0.0
	page.drop_check.toggled.emit(false)
	check(page.drop_odds_box.get_child_count() == 0, "no odds when it doesn't drop")
	page.set_stat("bonus_damage", 1.5)
	var result: Dictionary = page.save()
	check(result.ok and result.saved == [weapon_id], "page save publishes into the temp data")
	check(page.status_label.text.begins_with("Saved:"), "status reports the save")
	tool.show_tab("monsters")
	check(tool.monster_body.visible and not page.visible, "back to monsters")
	tool.close()
	tool.queue_free()
	await process_frame

func _check_live_encounter() -> void:
	var controller: Node = load("res://scenes/main.tscn").instantiate()
	controller.persistence_enabled = false
	root.add_child(controller)
	await process_frame
	var account: RefCounted = controller.account_state
	var weapon_id := ""
	for id in account.published_weapons:
		weapon_id = id
		break
	if weapon_id.is_empty():
		check(false, "a published weapon for the live check")
		controller.queue_free()
		return
	var saved_base: Dictionary = ItemDefinitionsScript.base_for(weapon_id)
	account.grant_published_weapon(weapon_id)
	var instance_id := ""
	for id in account.item_instances:
		if str(account.item_instances[id].get("base_id", "")) == weapon_id:
			instance_id = id
	var hero_id: String = account.get_active_hero_id()
	check(account.equip_instance(hero_id, "weapon", instance_id), "equip the weapon")
	controller.run_state.selected_hero_id = hero_id
	controller._configure_weapon_loadout(hero_id)
	var tool: CanvasLayer = controller.monster_encyclopedia
	var page: Control = tool.weapons_page
	page.model = EditsScript.new()
	tool.open_weapons(weapon_id)
	check(page.selected_id == weapon_id, "opens at the equipped weapon")
	page.set_stat("bonus_damage", 0.0)
	page.set_stat("attack_speed", 0.0)
	page.set_stat("base_damage", 30.0)
	check(is_equal_approx(float(controller.weapon_damage), 30.0), "live edit reaches the hero's damage (%s)" % str(controller.weapon_damage))
	page.set_stat("base_rate", 2.5)
	check(is_equal_approx(float(controller.weapon_interval), 0.4), "live edit reaches the attack interval (%s)" % str(controller.weapon_interval))
	page.set_drop("enabled", true)
	page.set_drop("min_item_level", 1)
	page.set_drop("weight", 7.0)
	var in_pool := false
	for entry in controller.frozen_loot_registration.get("pool", []):
		if str(entry.weapon_id) == weapon_id and is_equal_approx(float(entry.weight), 7.0):
			in_pool = true
	check(in_pool, "unsaved drop settings reach the running level's loot pool")
	# A 100% pursuer chance drops the weapon on the next pursuer kill.
	page.set_drop("chance:pursuer", 100.0)
	var before: int = account.item_instances.size()
	controller.run_state.run_id = "encyclopedia-live-test"
	var victim: Node = controller.spawn_enemy(0, 1)
	controller._roll_enemy_reward(victim)
	var dropped := false
	for id in account.item_instances:
		if str(id).begins_with("loot:") and str(account.item_instances[id].get("base_id", "")) == weapon_id:
			dropped = true
	check(dropped and account.item_instances.size() > before, "a pursuer kill drops the weapon at 100%")
	check(int(account.loot_streaks.get("%s|pursuer" % weapon_id, -1)) == 0, "the streak resets after a drop")
	# Drop one now: same orb and inventory path as a monster drop.
	check(not page.drop_now_button.disabled, "Drop one now is on in a run")
	var count_before: int = account.item_instances.size()
	var message: String = page.drop_now()
	check(account.item_instances.size() == count_before + 1, "drop now adds the weapon (%s)" % message)
	var orb_found := false
	for node in controller.get_children():
		if node.is_in_group("loot_drop_visuals") and str(node.caption.text).ends_with(str(account.published_weapons[weapon_id].revision.get("label", ""))):
			orb_found = true
	check(orb_found, "drop now shows the drop orb with the weapon's name")
	page.revert_selected()
	check(not page.model.is_modified(weapon_id), "revert in a run")
	tool.close()
	page.model.revert_all()
	ItemDefinitionsScript.register_runtime_base(weapon_id, saved_base)
	controller.queue_free()
	await process_frame

# ---------- fixtures ----------

func _modifier(modifiers: Array, stat: String, operation: String) -> Dictionary:
	for modifier in modifiers:
		if str(modifier.get("stat", "")) == stat and str(modifier.get("operation", "")) == operation:
			return modifier
	return {}

## Copies index.json and each published revision's definition/recipe.
func _copy_published() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA))
	if FileAccess.file_exists("res://data/loot/weapon_registrations.json"):
		_write(LOOT, FileAccess.get_file_as_string("res://data/loot/weapon_registrations.json"))
	var text := FileAccess.get_file_as_string("res://data/weapons/index.json")
	_write(DATA + "/index.json", text)
	var index: Dictionary = JSON.parse_string(text)
	for weapon_id in index.get("weapons", {}):
		var number := int(index.weapons[weapon_id].get("revision", 1))
		for name in ["definition.json", "recipe.json"]:
			var source := "res://data/weapons/%s/%d/%s" % [weapon_id, number, name]
			if FileAccess.file_exists(source):
				var target := DATA + "/%s/%d/%s" % [weapon_id, number, name]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
				_write(target, FileAccess.get_file_as_string(source))

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _wipe_temp() -> void:
	_wipe(ProjectSettings.globalize_path(DATA))
	_wipe(ProjectSettings.globalize_path(ASSETS))

func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	directory.include_hidden = true
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_wipe(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
